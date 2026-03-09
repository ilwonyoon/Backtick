# Recent Terminal Target Execution Plan

## Purpose

This document defines a low-friction execution-target experiment for Prompt Cue.

The goal is not to make users choose a terminal during capture. The goal is to quietly remember the most likely terminal target at capture time, then use that information later from the stack.

This slice is designed to preserve Prompt Cue's core contract:

- capture stays fast
- users are not asked to classify during capture
- execution targeting remains a suggestion, not a hard binding

## Locked Product Decisions

- Capture remains zero-extra-step. Users do not select a target during capture.
- Prompt Cue may attach a hidden `suggested target` to a saved card.
- The suggested target is a soft default, not a guaranteed routing contract.
- For this debugging phase, Prompt Cue shows the captured target metadata in both:
  - the capture panel
  - the stack card
- The debug surface is temporary. The long-term presentation is intentionally undecided.
- The first implementation scope is limited to:
  - `Terminal.app`
  - `iTerm2`
- `Cursor`, `Antigravity`, and generic focused input fields are out of scope for v1.
- Actual `Send` actions are not required for this first slice. The first goal is to prove that target capture is accurate enough to be useful.
- Prompt Cue auto-selects the recent terminal by default during capture.
- During this debugging phase, users may override that default from capture or stack to validate later send ergonomics.

## Why This Direction

Prompt Cue should not ask the user to route a card while capturing it.

That would add friction to the one flow that must remain near-zero effort.

Instead, Prompt Cue should opportunistically remember the most recent viable terminal context and expose it later where the user already makes export decisions: the stack.

This also handles the real-world case where multiple terminals are open. Prompt Cue does not need to perfectly understand the user's entire workspace. It only needs to attach a useful recent default often enough to reduce later friction.

## Scope

### In Scope

- track the most recently active supported terminal app
- snapshot basic terminal target metadata
- attach recent target metadata to saved cards automatically
- persist that metadata with the card
- show debug target metadata in capture and stack surfaces
- verify freshness rules and persistence

### Out Of Scope

- terminal targeting syntax such as `@terminal`
- real send-to-terminal execution
- generic input-field targeting
- repo grouping and repo-specific review modes
- file-level context extraction
- error parsing from terminal output

## Supported Targets

### v1

- `Terminal.app`
- `iTerm2`

### Deferred

- `Cursor`
- `Antigravity`
- `Warp`
- generic focused app windows
- non-terminal text fields

## Suggested Target Model

Each card may store an optional suggested target object.

Suggested fields:

- `appName`
- `bundleIdentifier`
- `windowTitle`
- `sessionIdentifier`
- `capturedAt`
- `confidence`

Notes:

- `sessionIdentifier` is optional because app scripting coverage differs by target app.
- `confidence` starts simple:
  - `high` when Prompt Cue got a fresh snapshot from a supported app
  - `none` when no recent supported target exists

This metadata is not capture syntax. It is independent from the note body itself.

## Tracker Architecture

Prompt Cue needs a background tracker that watches app activation rather than trying to guess the target after the capture panel is already visible.

### Reason

If Prompt Cue waits until the capture panel opens, the frontmost app is already Prompt Cue.

So the tracker must observe the last external active app before Prompt Cue becomes key.

### Source

Use:

- `NSWorkspace.didActivateApplicationNotification`

### Tracker Rules

- ignore Prompt Cue itself
- only create target snapshots for supported apps
- replace the cached target whenever a supported app becomes active
- store the time of observation
- keep the latest snapshot in memory for fast card attachment

## Terminal Snapshot Strategy

When a supported terminal becomes active, Prompt Cue captures the smallest useful target snapshot it can.

### Required Fields

- app name
- bundle identifier
- timestamp

### Preferred Fields

- front window title
- tab/session title if cheaply available
- current working directory
- repo root
- repo name
- branch

The first useful milestone is:

- recent terminal detection
- cwd-to-repo enrichment
- just-enough project labeling for later grouping

## Capture Attach Rule

When the user saves a card:

- Prompt Cue checks the cached recent target snapshot
- if the snapshot is from a supported target and still fresh, attach it
- otherwise save the card without a suggested target

### Freshness Rule

Initial freshness window:

- `60 seconds`

Rationale:

- short enough to reduce stale assumptions
- long enough to survive a quick glance at another app before capture

### Failure Rule

If target resolution fails:

- the card still saves
- the target metadata remains empty
- capture flow must not be blocked

## Debug Visibility

The long-term user-facing presentation is deliberately not locked yet.

For this implementation slice, target metadata should be visible in two places to validate detection quality.

### Capture Origin Surface

- show a compact origin pill above the editor while a draft is active
- use:
  - app icon
  - short workspace label
  - optional short branch suffix when it adds signal
- the pill is for human recognition, not full raw metadata
- its background should read like a quiet selected context capsule
- it must stay visually subordinate to the editor text
- clicking the pill opens a separate chooser panel

### Capture Origin Chooser

- the chooser appears above capture, not overlapping it
- align it to the visible capture search surface, not the outer window bounds
- keep about `16px` visible gap between the capture surface and chooser surface
- match the capture surface width and shell styling
- the capture panel itself must not move when the chooser opens or closes
- rows need clear hover affordance
- keyboard control must work while capture remains active:
  - `↑` / `↓` move highlight
  - mouse hover updates the same highlight state
  - `Tab` or `Enter` commits the highlighted row and closes the chooser
  - `Esc` closes the chooser without changing the selected target

### Stack Debug Surface

- show a small origin pill or subtle metadata row on each card that has a suggested target
- if no target exists, show nothing
- keep the line visually subordinate to the card body
- stack may also expose a chooser popover for manual reassignment

Example:

- `Terminal icon + auth-service`

These debug surfaces are temporary instrumentation, not final UX.

## Future Send Flow

This slice exists to support a later stack-side send action.

Planned future behavior:

- user hovers or opens actions on a stack card
- Prompt Cue offers `Send`
- if a suggested target exists and still looks valid, it becomes the default option
- the user may still choose another target

That future flow depends on the suggested target metadata but is not required for the current implementation.

## Data And Ownership

### PromptCueCore

Own in shared code:

- suggested target model
- card model updates
- pure formatting helpers for debug labels if useful

### App Target

Own in app code:

- workspace activation tracking
- terminal-specific target snapshotting
- capture-time attachment
- capture/stack origin label rendering
- chooser popovers for manual reassignment during validation

## Human-Facing Validation UI

The first user-facing version should optimize for fast recognition, not raw debug verbosity.

### Primary Label Rule

Show a short `workspace label` with the terminal app icon.

Preferred derivation:

1. `repoName`
2. `repoName/worktree-leaf` when the working directory differs meaningfully from the repo root
3. cwd leaf
4. window title
5. app name

Examples:

- `Terminal + auth-service`
- `iTerm2 + frontend`
- `Terminal + auth-service/login`

### What To Hide From The Main UI

Do not show these inline by default:

- full cwd
- raw tty
- long window titles
- full branch names unless needed for a secondary chooser detail

Those remain available for:

- tooltips
- chooser secondary text
- AI/system metadata

### Capture Surface

- Show the origin pill above the input row, aligned with the input leading edge
- Keep the style subtle and compact
- Clicking the pill opens a popover with the currently open terminal targets
- The popover may also offer `Automatic recent terminal` to revert any manual override

### Stack Surface

- Show the same origin pill below the card body
- Clicking the pill opens a popover with currently open terminal targets
- Selecting a target rewrites the card's stored suggested target metadata

### Chooser Popover

- Use app icon + short workspace label as the primary row label
- Use app name and short branch or window/session detail as the secondary line
- Keep the list short and focused on current open terminal windows
- Prefer correctness over cleverness; if there is ambiguity, let the user choose

## Verification Plan

### Automated

- card model round-trip with optional suggested target
- persistence migration for cards with and without target metadata
- freshness rule tests
- save-path tests confirming:
  - fresh target attaches
  - stale target does not attach
  - unsupported app target does not attach

### Runtime

Validate these flows manually:

1. activate `Terminal.app`, capture a card, confirm the capture debug line and stack debug line match
2. activate `iTerm2`, capture a card, confirm the capture debug line and stack debug line match
3. activate a non-terminal app, capture a card, confirm no target metadata attaches
4. wait beyond the freshness window, capture again, confirm the target does not attach
5. relaunch the app and confirm the stored card still shows the same debug target in stack

## Success Criteria

- capture remains as fast as before
- cards save normally even when target detection fails
- most captures taken immediately after a terminal interaction receive the expected target
- debug rendering in capture and stack gives enough signal to evaluate whether the model is worth keeping

## Follow-Up Decision After Validation

Once the debug slice is verified, make one product decision:

1. keep suggested target hidden and only use it for `Send`
2. expose a subtle persistent badge in stack
3. expand the model to include repo and branch context

That decision should be based on observed accuracy, not theory.
