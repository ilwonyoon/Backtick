# Working With Apps PR Plan

## Goal

Ship only the `working with apps` slice as a focused PR on top of `main`.

This PR is for:

- recent terminal detection
- hidden suggested-target metadata on cards
- capture and stack origin selection for terminal context
- minimal persistence and keyboard support required for that flow

This PR is not for:

- Apple Notes export
- drag and drop experiments
- tag or priority work
- unrelated capture or stack redesign

## Merge Contract

When this PR is merged, `capture` and `stack` must continue to look and behave like `main`.

The feature is allowed to add a compact origin accessory and chooser surface, but it is not allowed to redefine the base visual system of either surface.

## Main Style Standard

### Capture

The capture panel standard comes from:

- [CaptureComposerView.swift](/Users/ilwonyoon/Documents/PromptCue-tag-priority-direct-send-to-apps/PromptCue/UI/Views/CaptureComposerView.swift)
- [SearchFieldSurface.swift](/Users/ilwonyoon/Documents/PromptCue-tag-priority-direct-send-to-apps/PromptCue/UI/Components/SearchFieldSurface.swift)
- [CapturePanelController.swift](/Users/ilwonyoon/Documents/PromptCue-tag-priority-direct-send-to-apps/PromptCue/UI/WindowControllers/CapturePanelController.swift)

Rules:

- Preserve the existing `SearchFieldSurface` shell.
- Preserve centered layout, outer padding, and quiet floating-panel behavior.
- Preserve the current editor hierarchy and placeholder tone.
- Do not replace the panel shadow model or add a second competing shell shadow.
- The origin control must read as an accessory, not as a second primary input.

### Stack

The stack standard comes from:

- [CardStackView.swift](/Users/ilwonyoon/Documents/PromptCue-tag-priority-direct-send-to-apps/PromptCue/UI/Views/CardStackView.swift)
- [CaptureCardView.swift](/Users/ilwonyoon/Documents/PromptCue-tag-priority-direct-send-to-apps/PromptCue/UI/Views/CaptureCardView.swift)
- [CardSurface.swift](/Users/ilwonyoon/Documents/PromptCue-tag-priority-direct-send-to-apps/PromptCue/UI/Components/CardSurface.swift)

Rules:

- Preserve the existing `CardSurface(style: .notification)` stack card treatment.
- Preserve the current right-side action column, card padding, and copied-stack behavior.
- The origin control must sit inside the card as secondary metadata.
- Do not introduce a new card shell, alternate shadow recipe, or extra chrome row that competes with card text.

## Shared Working-With-Apps Rules

- Use the same compact origin accessory in both capture and stack.
- Use the same terminal chooser row styling in both surfaces.
- Keep the entry point subtle and visually subordinate to the main text content.
- The feature must work without forcing the user to annotate capture text.
- Keyboard flow must remain intact:
  - capture: `Up` can enter chooser, `Up/Down` move, `Tab/Enter` select, `Esc` dismiss
  - stack: mouse-first is acceptable for v1, but visual language must match capture

## Data Scope

Allowed card metadata:

- `suggestedTarget`
  - bundle identifier
  - app name
  - window title
  - session identifier if available
  - cwd
  - repo root
  - repo name
  - branch
  - workspace label
  - confidence
  - captured timestamp

The metadata is machine-useful first. Human UI should only show the minimum needed identity.

## PR Checklist

- Remove Notes export from this branch before PR.
- Keep the diff focused on working-with-apps files.
- Confirm capture still uses the main shell shadow and stack still uses the main notification-card shadow.
- Confirm existing cards without suggested target still render correctly.
- Confirm chooser interaction does not move the capture panel.
- Confirm stack cards still copy/delete exactly as before.

## Verification

Minimum verification for this PR:

- `swift test`
- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO test`

If `xcodegen` is available in the merge environment, also run:

- `xcodegen generate`

## Known Polish Items To Finish Before PR

- Capture shell shadow parity with `main`
- Terminal chooser panel shadow parity with `main`
- Final capture/stack origin accessory weight tuning
