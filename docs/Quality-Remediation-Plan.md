# Prompt Cue Quality Remediation Plan

## Purpose

This document turns the latest quality audit into an execution plan.

The goal is not generic cleanup. The goal is to close the specific gaps that currently block Prompt Cue from feeling release-ready:

- unreachable MVP behavior
- fragile screenshot attachment ownership
- incomplete screenshot privacy model
- non-deterministic clipboard export
- design-system drift and reuse gaps
- weak automated coverage outside `PromptCueCore`

## Audit Baseline

The current audit found these primary gaps:

1. Multi-card selection and grouped export exist in model code but are not reachable in the UI.
2. Screenshot attachments are stored as external file paths instead of app-owned assets.
3. Screenshot folder access is still implicit instead of user-approved and bookmark-backed.
4. Clipboard export of image + text is not reliable across target apps.
5. Persistence failure is not surfaced clearly enough.
6. The design-system document, token layer, and production surfaces have drifted apart.
7. Automated coverage is concentrated in `PromptCueCore`; app-level critical flows are still manual.

## Remediation Principles

- Fix contract and ownership issues before polishing surface behavior.
- Move pure logic into `PromptCueCore` early when it reduces duplication or improves testability.
- Keep release-sensitive changes master-owned unless a track is explicitly opened.
- Prefer one finished vertical slice over half-finished parallel spikes.
- Do not treat design-system cleanup as cosmetic work only. It is part of stability because it controls drift.

## Parallel Execution Model

This plan assumes `master-managed multi-agent preferred, but optional`.

Parallel work starts only after shared contracts are frozen.

### Master-Owned Files

- `docs/Quality-Remediation-Plan.md`
- `docs/Implementation-Plan.md`
- `docs/Master-Board.md`
- `PromptCue/App/AppModel.swift`
- `PromptCue/App/AppCoordinator.swift`
- `PromptCue/App/PromptCueApp.swift`
- `PromptCue/App/AppDelegate.swift`
- shared contract files in `Sources/PromptCueCore/**` while contract changes are active

### Track Ownership After Contract Lock

- Track A, data ownership and attachment lifecycle:
  - `Sources/PromptCueCore/CaptureCard.swift`
  - `Sources/PromptCueCore/ScreenshotAttachment.swift`
  - `PromptCue/Services/CardStore.swift`
  - `PromptCue/Services/AttachmentStore.swift`
  - related tests
- Track B, stack export UX:
  - `PromptCue/Services/ClipboardFormatter.swift`
  - `PromptCue/UI/Views/CardStackView.swift`
  - `PromptCue/UI/Views/CaptureCardView.swift`
  - `PromptCue/UI/WindowControllers/StackPanelController.swift`
- Track C, screenshot access and settings:
  - `PromptCue/Services/ScreenshotDirectoryResolver.swift`
  - `PromptCue/Services/ScreenshotMonitor.swift`
  - `PromptCue/UI/Settings/PromptCueSettingsView.swift`
  - `PromptCue/UI/WindowControllers/SettingsWindowController.swift`
- Track D, design-system closure:
  - `docs/Design-System.md`
  - `docs/Design-System-Audit.md`
  - `PromptCue/UI/DesignSystem/**`
  - `PromptCue/UI/Components/GlassPanel.swift`
  - `PromptCue/UI/Components/SearchFieldSurface.swift`
  - `PromptCue/UI/Components/CardSurface.swift`

## Phase R0: Contract Lock

### Goal

Freeze the smallest shared contracts required for the later tracks.

### Tasks

| Task | Owner | Dependency | Parallelizable | Exit Criteria |
| --- | --- | --- | --- | --- |
| Replace raw screenshot path assumptions with an app-owned attachment contract | Master | None | No | `CaptureCard` can distinguish between attachment identity and source path |
| Define screenshot folder access contract and bookmark storage interface | Master | None | No | settings and monitor code can depend on one access model |
| Define multi-select export state contract and controller flow | Master | None | No | stack UI and controller can implement selection without reworking model shape |
| Record integration order and file ownership for remediation tracks | Master | None | No | worker tracks can start without file conflicts |

### Exit Criteria

- Contract names and storage shape are frozen.
- No worker track needs to guess at attachment identity or selection behavior.

## Phase R1: Data Integrity And Attachment Ownership

### Goal

Make screenshots durable, app-owned, and cleanup-safe.

### Tasks

| Task | Owner | Dependency | Parallelizable | Exit Criteria |
| --- | --- | --- | --- | --- |
| Add attachment store under Application Support | Track A | Phase R0 | Yes | app can import and read owned assets |
| Change save flow to import screenshots on submit instead of storing external path | Track A + Master wiring | Attachment store contract | No | saved cards survive source-file movement |
| Add DB migration for attachment metadata | Track A | Attachment contract | Yes | existing data can be read and new data can be written |
| Delete imported assets on card delete and TTL cleanup | Track A + Master wiring | Attachment store | No | expired or deleted cards do not leave orphaned assets |
| Surface persistence failure state instead of silent no-op | Track A + Master wiring | None | Yes | persistence failures are observable in logs and state |

### Exit Criteria

- Cards do not depend on the original screenshot file remaining in place.
- Delete and TTL cleanup remove owned assets.
- Storage failure is visible and testable.

## Phase R2: Selection And Clipboard Export Closure

### Goal

Make the stack panel satisfy the actual export contract in the PRD.

### Tasks

| Task | Owner | Dependency | Parallelizable | Exit Criteria |
| --- | --- | --- | --- | --- |
| Add reachable multi-select UI in stack panel | Track B | Phase R0 | Yes | user can select multiple cards intentionally |
| Implement grouped copy action without breaking single-click quick copy | Track B | selection contract | Yes | both fast path and grouped export path exist |
| Redesign pasteboard writing so image + text export is deterministic for supported targets | Track B | attachment ownership from Phase R1 | No | paste behavior is stable in target apps under test |
| Add copy/export smoke coverage for single-card and multi-card flows | Track B | above tasks | Yes | stack export no longer depends on ad hoc manual checking |

### Exit Criteria

- Multi-card export is reachable.
- Single-card copy remains frictionless.
- Image + text export behavior is documented and verified against target apps.

## Phase R3: Screenshot Access, Permissions, And Settings

### Goal

Replace implicit folder scanning with explicit, user-controlled screenshot access.

### Tasks

| Task | Owner | Dependency | Parallelizable | Exit Criteria |
| --- | --- | --- | --- | --- |
| Add screenshot folder picker in Settings | Track C | Phase R0 | Yes | user can choose the watched folder |
| Persist security-scoped bookmark and rehydrate on launch | Track C | folder access contract | Yes | folder access survives relaunch |
| Update screenshot monitor to use approved access path instead of fallback scanning | Track C | bookmark support | No | monitor behavior matches privacy model |
| Add reconnect / invalid bookmark state in Settings | Track C | bookmark support | Yes | failure mode is visible and recoverable |
| Keep default onboarding behavior sensible for the common Desktop case | Track C | folder picker | Yes | first-run experience is low-friction without hidden scanning |

### Exit Criteria

- Screenshot behavior is explicit and user-controlled.
- Folder access survives relaunch.
- The implementation is compatible with later MAS hardening.

## Phase R4: Design-System Reconciliation

### Goal

Make the design system real enough to constrain future work instead of merely documenting intent.

### Tasks

| Task | Owner | Dependency | Parallelizable | Exit Criteria |
| --- | --- | --- | --- | --- |
| Reconcile `docs/Design-System.md` with `PrimitiveTokens.swift` | Track D | None | Yes | documented scale matches shipped scale |
| Move stack backdrop and notification plate styling onto semantic tokens | Track D | None | Yes | production surfaces stop embedding raw visual math |
| Remove duplicated glass shell recipes where practical | Track D | semantic cleanup | Yes | shell behavior composes from shared components |
| Add AppKit bridge tokens for editor typography/color | Track D | None | Yes | `CueTextEditor` no longer relies on matching by convention |
| Refresh `Design-System-Audit.md` to match actual preview/gallery coverage | Track D | None | Yes | audit docs are trustworthy again |

### Exit Criteria

- Design doc and tokens do not contradict each other.
- Production surfaces consume reusable semantics instead of local one-off styling.

## Phase R5: Verification And Release Confidence

### Goal

Raise confidence in the real app surface, not just the core package.

### Tasks

| Task | Owner | Dependency | Parallelizable | Exit Criteria |
| --- | --- | --- | --- | --- |
| Add app-level smoke checklist for capture, screenshot attach, stack export, and restart | Master | R1-R3 | Yes | critical flows are manually repeatable |
| Add focused app tests or harness coverage for app-owned attachment lifecycle | Master + Track A | R1 | Yes | regressions are catchable before release |
| Add coverage for selection/export flow | Master + Track B | R2 | Yes | grouped export remains safe under iteration |
| Add coverage for bookmark resolution and invalid-folder recovery | Master + Track C | R3 | Yes | permission flow is not purely manual |
| Re-run full build/test/validator gate after each merged track | Master | every phase | No | integration stays green |

### Exit Criteria

- Core flows have repeatable verification.
- Release readiness is based on observed behavior, not optimism.

## Merge Order

1. Phase R0 contract lock
2. Track A, data integrity and attachment ownership
3. Track C, screenshot access and settings
4. Track B, selection and clipboard export
5. Track D, design-system reconciliation
6. Phase R5 verification pass

## Immediate Next Slice

The current slice status is:

1. Phase R0 contract lock: completed
2. Phase R1 attachment ownership: integrated
3. Phase R3 screenshot access and settings: integrated
4. Phase R2 selection and grouped export: in progress
5. Phase R4 design-system reconciliation: pending
6. Phase R5 app-level verification: started, but still too light

The next slice should finish the remaining parts of Phase R2 and expand Phase R5.

That means:

1. Verify grouped export against target apps that consume image + text differently
2. Add app-level tests around storage and export-sensitive services
3. Reconcile design-system docs and semantic usage before more surface polish
