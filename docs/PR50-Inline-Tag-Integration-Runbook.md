# PR #50 Inline Tag Integration Runbook

## Purpose

Integrate PR `#50` (`feat/inline-tags-mcp-context`) onto current `main` without regressing the capture selector, keyboard ownership, theme-sensitive editor colors, or recent suggested-target fixes.

This runbook exists because `#50` is a broad feature PR, not a one-click merge:

- GitHub merge state: `CONFLICTING`
- scope: `29` files
- direct conflicts observed in local merge simulation:
  - `PromptCue/UI/Capture/CaptureEditorRuntimeHostView.swift`
  - `docs/Master-Board.md`

## Current Baseline

Treat current `main` as the only valid integration baseline.

Recent baseline-sensitive landings that must survive this integration:

- `25cc8a6` restore rich suggested-target resolution
- `b1db1e5` selector v2 replacement
- `2a105fd` theme sync and target-label fixes
- `bdc5c64` merge PR `#49` settings polish

## Scope

PR `#50` is intended to land these behaviors:

- inline `#tag` parsing and tinting in Capture
- inline tag autocomplete and ghost completion
- structured tag metadata persistence through models, storage, cloud sync, and MCP payloads
- inline tag rendering on Stack surfaces
- canonical tag hardening and legacy polluted-tag cleanup

This integration must not redesign:

- suggested-target selector visuals
- capture keyboard ownership
- recent-target provider lifecycle
- menu-bar icon theme behavior
- screenshot onboarding behavior

## Ownership

Master-owned:

- `PromptCue/UI/Capture/CaptureEditorRuntimeHostView.swift`
- `PromptCue/App/AppModel+CaptureSession.swift`
- `PromptCue/App/AppModel.swift`
- `PromptCue.xcodeproj/project.pbxproj`
- `docs/Master-Board.md`
- final integration and verification

Track A: Core / persistence / MCP

- `Sources/PromptCueCore/**`
- `PromptCue/Services/CardStore.swift`
- `PromptCue/Services/PromptCueDatabase.swift`
- `PromptCue/Services/CloudSyncEngine.swift`
- `PromptCue/Services/StackExecutionService.swift`
- `PromptCue/Services/StackGroupService.swift`
- `PromptCue/Services/StackReadService.swift`
- `PromptCue/Services/StackWriteService.swift`
- `Sources/BacktickMCPServer/**`
- `Tests/BacktickMCPServerTests/**`
- `Tests/PromptCueCoreTests/**`
- `PromptCueTests/StorageServicesTests.swift`

Track B: Capture / stack UI

- `PromptCue/UI/Capture/CaptureInlineTagSuggestionView.swift`
- `PromptCue/UI/Capture/CapturePanelRuntimeViewController.swift`
- `PromptCue/UI/Components/CueTextEditor.swift`
- `PromptCue/UI/Views/CaptureCardView.swift`
- `PromptCue/UI/Views/CardStackView.swift`
- `PromptCue/UI/Views/InteractiveDetectedTextView.swift`
- `PromptCueTests/CapturePanelRuntimeViewControllerTests.swift`

## Conflict Policy

### CaptureEditorRuntimeHostView

Keep current `main` behavior for:

- theme-driven text, placeholder, and insertion colors
- current keyboard-safe focus path

Port from `#50` only:

- inline completion presentation
- inline tag highlight rendering

Do not re-open selector or keyboard experiments while resolving this file.

### Master Board

Keep both:

- current selector-v2 completion note
- inline tag hardening / rollout note

### project.pbxproj

Accept the merged file only after regenerating with `xcodegen generate`.

## Merge Sequence

1. Work in `../PromptCue-inline-tags` on `feat/inline-tags-mcp-context`
2. `git fetch origin --prune`
3. `git merge origin/main`
4. Resolve conflicts using the policy above
5. Run verification gates
6. Push the updated PR branch
7. Merge PR `#50` with `Create a merge commit`

## Verification Gates

Required before pushing the PR branch:

- `xcodegen generate`
- `swift test`
- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO test -only-testing:PromptCueTests/CapturePanelRuntimeViewControllerTests -only-testing:PromptCueTests/StorageServicesTests -only-testing:PromptCueTests/AppModelSuggestedTargetTests -only-testing:PromptCueTests/CueTextEditorMetricsTests -quiet`
- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- `scripts/qa_capture_input.sh --app <built app path> --draft-file <tmp draft> --out-dir <tmp out> --wait 2.5`

## Manual QA

- capture typing still works with no keyboard regressions
- suggested-target selector still has:
  - no default outline stroke
  - one active-looking row only
  - working arrow / tab / enter / escape behavior
- theme switching still updates capture text and placeholder colors
- inline `#tag` tinting, autocomplete, and ghost completion feel correct
- terminal / IDE suggested-target detail still favors useful repo / branch context
- tags persist from capture into stack and MCP payloads

## Abort Conditions

Stop and split the work if any of these appear:

- selector visuals regress again
- capture keyboard ownership changes are required
- `RecentSuggestedAppTargetTracker` lifecycle needs to change
- cloud-sync default policy or signing policy gets pulled into scope

If one of these happens, do not continue pushing the same PR as one integration block.
