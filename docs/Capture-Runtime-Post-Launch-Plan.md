# Backtick Capture Runtime Post-Launch Plan

## Purpose

This document defines the first post-launch capture-runtime improvement lane.

The goal is not broad cleanup. The goal is to make `Capture` feel instant again
under real typing, IME composition, and screenshot-attach load without reopening
launch risk before the first signed DMG ships.

This plan exists because:

- `Capture` is the most latency-sensitive surface in the product
- recent regressions proved that launch review and correctness hardening can
  accidentally re-open capture hot paths
- current launch policy now treats capture as `bugfix-only` until the first DMG
- larger structural performance work therefore needs its own post-launch lane

## Authority And Relationship To Other Docs

This is a child plan under:

- `docs/Execution-PRD.md`
- `docs/Implementation-Plan.md`
- `docs/Performance-Remediation-Plan.md`
- `docs/Master-Board.md`

If this document conflicts with the product contract, `Execution-PRD.md` wins.
If it conflicts with the launch freeze rules, the launch docs win until the
first DMG ship candidate is accepted.

## Product Contract To Preserve

Do not regress these capture rules:

- Capture opens instantly
- typing feels immediate
- IME composition remains correct
- screenshot attach remains explicit and privacy-safe
- Capture stays a frictionless dump surface, not a richer editor
- AppKit remains the runtime owner of live editor behavior

## Current Diagnosis

### Typing Path

Current `main` still pays too much work on each edit:

- `textDidChange` runs draft sync, inline-tag refresh, and height/resize logic
  in sequence:
  [CapturePanelRuntimeViewController.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/UI/Capture/CapturePanelRuntimeViewController.swift#L848)
- inline-tag refresh reparses the whole editor text and rebuilds highlight /
  completion state from scratch:
  [CapturePanelRuntimeViewController.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/UI/Capture/CapturePanelRuntimeViewController.swift#L587)
  [CaptureTag.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/Sources/PromptCueCore/CaptureTag.swift#L166)
- selection-only changes can re-enter the same refresh path:
  [CapturePanelRuntimeViewController.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/UI/Capture/CapturePanelRuntimeViewController.swift#L889)
- layout measurement still reconfigures the text container, calls
  `ensureLayout`, and walks rendered lines on the main thread:
  [CaptureEditorRuntimeHostView.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/UI/Capture/CaptureEditorRuntimeHostView.swift#L383)
  [CaptureEditorRuntimeHostView.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/UI/Capture/CaptureEditorRuntimeHostView.swift#L471)
- inline-tag highlight presentation still mutates temporary layout attributes
  for every accepted range change:
  [CaptureEditorRuntimeHostView.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/UI/Capture/CaptureEditorRuntimeHostView.swift#L522)
- ghost completion still computes caret and draw rects through the text system
  during rendering:
  [CueTextEditor.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/UI/Components/CueTextEditor.swift#L196)
  [CueTextEditor.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/UI/Components/CueTextEditor.swift#L375)

### Screenshot Path

Current screenshot attach is correct enough for launch, but the architecture is
still more timer-driven than it should be:

- approved folder is the only file source of truth:
  [ScreenshotDirectoryResolver.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/Services/ScreenshotDirectoryResolver.swift#L26)
  [RecentScreenshotLocator.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/Services/RecentScreenshotLocator.swift#L149)
- clipboard is a separate fast path:
  [RecentClipboardImageMonitor.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/Services/RecentClipboardImageMonitor.swift#L49)
- the coordinator still mixes sync signal probes, async scans, settle polling,
  and preview caching in one state machine:
  [RecentScreenshotCoordinator.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/Services/RecentScreenshotCoordinator.swift#L113)
  [RecentScreenshotCoordinator.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/Services/RecentScreenshotCoordinator.swift#L275)
  [RecentScreenshotCoordinator.swift](/tmp/promptcue-capture-postlaunch-nYnzWi/PromptCue/Services/RecentScreenshotCoordinator.swift#L755)

## Design Direction

The post-launch redesign should split into three runtime concerns:

1. `editor semantics`
   - inline tags
   - completion state
   - suggestion selection
   - draft-sync policy

2. `editor geometry`
   - line measurement
   - preferred height
   - scroll / viewport behavior
   - rendering-only highlight and ghost presentation

3. `screenshot pipeline`
   - clipboard fast path
   - approved-folder file path
   - signal -> readable -> cached preview phases
   - submit-time attachment import

The redesign should make each concern measurable on its own.

## Locked Architecture Rules

### Rule 1: Keep AppKit As The Live Editor Owner

Do not move live capture editing back into `AppModel` or a SwiftUI-driven editor
loop. `CaptureEditorRuntimeHostView` and `WrappingCueTextView` remain the live
runtime owners for focus, IME, layout, and drawing.

### Rule 2: Move Lexical Tag Work Into An Incremental Core Engine

`CaptureTag` parsing and completion logic should move behind a dedicated
incremental engine in `PromptCueCore`.

Target shape:

- input:
  - prior editor state
  - text delta
  - selection delta
- output:
  - canonical inline-tag ranges
  - committed tag set
  - current completion context
  - whether presentation actually needs updating

This lets the controller consume state diffs instead of reparsing the whole
document on every edit.

### Rule 3: Separate Semantic Refresh From Geometry Refresh

The current controller still lets one text edit fan out into both semantic work
and live measurement. The post-launch design should make those two lanes
independent:

- semantic lane:
  - tags
  - completion
  - draft sync
- geometry lane:
  - line count
  - visible height
  - panel resize

Changing one must not automatically recompute the other.

### Rule 4: Keep Clipboard As The Best-Effort Fast Path

Do not collapse screenshot capture into file-only detection.

`cmd + shift + ctrl + 4` should remain the fastest screenshot route:

- clipboard image detection stays separate
- if clipboard already has a fresh image, bypass most file arbitration
- file detection remains the fallback path for `cmd + shift + 4/5`

### Rule 5: Keep Approved-Folder-Only Privacy

Do not reintroduce system-folder or temp-folder scanning as runtime truth.

The file path remains:

- `user-approved screenshot folder only`

The system screenshot location may be used:

- for onboarding suggestion
- for mismatch diagnostics

It must not quietly become the monitored runtime source again.

## Phase Plan

### Phase C0: Instrumentation Reset

Goal:

- restore capture-specific benchmarks that match the real user complaint

Tasks:

- add committed benchmarks for:
  - plain typing
  - inline-tag typing
  - IME composition / commit
  - `hotkey -> focused editor`
  - `Enter -> panel close`
- keep reusing accepted screenshot and resize benchmarks from
  `Performance-Remediation-Plan.md`
- add one live capture trace harness, similar in spirit to
  `scripts/record_stack_open_trace.sh`

Exit criteria:

- capture regressions can no longer ship with only stack/open benchmarks green

### Phase C1: Incremental Tag And Completion Engine

Goal:

- remove whole-document semantic work from the common typing path

Tasks:

- create an incremental editor-state engine in `PromptCueCore`
- feed it edit and selection deltas instead of whole-string refreshes
- only emit tag-highlight and completion updates when semantic state changes
- preserve the current canonical tag contract

Likely owners:

- `Sources/PromptCueCore/CaptureTag.swift`
- new `PromptCueCore` editor-state helper(s)
- `CapturePanelRuntimeViewController.swift`

Exit criteria:

- plain typing does not run whole-document tag extraction
- selection-only changes do not rebuild semantic state unless needed

### Phase C2: Geometry Pipeline Simplification

Goal:

- make multiline growth cheaper and more predictable

Tasks:

- keep `CaptureEditorRuntimeHostView` as the only layout owner
- introduce cached measurement strategy by:
  - width bucket
  - text length bucket
  - line-count reuse where safe
- preserve current IME correctness guards
- keep highlight presentation draw-only and decouple it from full text-storage
  rewrites

Likely owners:

- `CaptureEditorRuntimeHostView.swift`
- `CaptureEditorLayoutCalculator.swift`
- `CueTextEditor.swift`

Exit criteria:

- geometry updates are coalesced and measured separately from semantic refresh
- no reintroduction of marked-text corruption

### Phase C3: Screenshot Pipeline Phase Machine

Goal:

- replace settle polling and repeated rescans with an event-driven pipeline

Tasks:

- refactor screenshot coordinator into explicit phases:
  - `noSignal`
  - `signalSeen`
  - `readableSourceReady`
  - `previewCached`
- replace repeating settle timer with:
  - event-driven debounce
  - one-shot grace state
- keep clipboard as a preferred fast path
- maintain a small rolling candidate index for the approved folder instead of
  rescanning the whole directory each time
- unify transient cache and decode-cache lifecycle around session expiration

Likely owners:

- `RecentScreenshotCoordinator.swift`
- `RecentScreenshotLocator.swift`
- `RecentScreenshotDirectoryObserver.swift`
- `TransientScreenshotCache.swift`

Exit criteria:

- screenshot attach no longer depends on timer-driven refresh loops
- capture open does not regress the accepted open-latency benchmark

### Phase C4: Live Product Proof

Goal:

- prove the redesign against real user-facing timings, not synthetic numbers only

Tasks:

- rerun committed capture benchmarks
- run live traces for:
  - `hotkey -> focused editor`
  - `Enter -> panel close`
- rerun screenshot benchmarks
- keep stack first-frame proof in the loop to avoid shifting cost from capture
  into stack or startup

Exit criteria:

- redesign is only accepted if it is measurably fast enough for the actual
  product path

## Measurement Contract

Reuse existing accepted metrics as hard non-regression guardrails:

- `prepareForCaptureSession()` return latency:
  accepted `0.50 ms`
- preview image warm-cache path:
  accepted `2.36 ms`
- preferred-height callback guard:
  accepted `0.26 ms`
- same-frame panel resize guard:
  accepted `0.40 ms`

Reference:

- [Performance-Remediation-Plan.md](/tmp/promptcue-capture-postlaunch-nYnzWi/docs/Performance-Remediation-Plan.md#L253)

Add new capture-only metrics before landing structural changes:

- plain-text keystroke avg / p95
- inline-tag keystroke avg / p95
- IME composition commit avg / p95
- `hotkey -> focused editor`
- `Enter -> panel close`

Do not accept a structural rewrite without both:

- benchmark proof
- live capture trace proof

## Verification Commands To Reuse

- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS='$(inherited) -DPROMPTCUE_RUN_PERF_BENCHMARKS' test -only-testing:PromptCueTests/RecentScreenshotCoordinatorPerformanceTests`
- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS='$(inherited) -DPROMPTCUE_RUN_PERF_BENCHMARKS' test -only-testing:PromptCueTests/CapturePreviewImagePerformanceTests`
- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS='$(inherited) -DPROMPTCUE_RUN_PERF_BENCHMARKS' test -only-testing:PromptCueTests/CapturePanelResizePerformanceTests`
- `scripts/record_stack_open_trace.sh --app <Prompt Cue.app>`

Post-launch follow-up should add parallel capture trace commands beside these,
not replace them.

## Non-Goals

This lane is not for:

- visual polish
- richer capture UI
- broader stack refactors
- reintroducing hidden system-folder scanning
- moving live editing out of AppKit

## Acceptance Rule

This lane is complete only when:

1. capture typing, IME, and screenshot attach each have stable proof metrics
2. the redesign improves the user-visible capture path, not just microbenchmarks
3. existing accepted screenshot/open/resize metrics stay green
4. the resulting runtime is simpler than today’s controller-driven state fan-out
