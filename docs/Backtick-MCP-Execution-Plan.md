# Backtick MCP Execution Plan

## Objective

Introduce `Backtick MCP` as an additive execution layer that reorganizes raw captures into shared work items without destroying the raw capture source of truth.

This lane is not a visual refresh of Stack. It is a structural product lane that adds:

- derived execution objects
- traceable mapping from raw notes to work items
- work item status and lifecycle
- a distinct execution surface that can later become the primary workspace

## Why This Is A Separate Lane

The current app already has the beginnings of the raw-note side of the model:

- `Sources/PromptCueCore/CaptureCard.swift`
  - raw text, timestamp, screenshot path, copied marker, stable identity
- `Sources/PromptCueCore/CaptureSuggestedTarget.swift`
  - repository, branch, working directory, app context, confidence
- `PromptCue/Services/CardStore.swift`
  - durable local storage for raw cards
- `PromptCue/App/AppModel.swift`
  - copied/history transition and selection/copy behavior
- `PromptCue/UI/Views/CardStackView.swift`
  - active vs copied partitioning in the existing Stack surface

What the codebase does not yet have is:

- a separate `WorkItem` model
- source mapping between raw notes and work items
- work-item status and progress transitions
- bundle/copy events tracked independently from raw note reads
- an execution-first UI surface separate from Stack

Because of that gap, `Backtick MCP` should not be merged into the current capture/stack work as an ad hoc extension. It should land as its own phased lane.

## Locked Rules For This Lane

1. Capture remains raw.
2. Stack remains the raw source and inspection surface during MCP rollout.
3. MCP starts as an additive surface, not a Stack replacement.
4. `CaptureCard` remains the code-facing raw-note entity in v1.
5. Work-item state must not be shoved into `CaptureCard`.
6. AI regrouping is deferred until the manual work-item path is stable.
7. MCP v1 remains local-first and does not widen the cloud-sync contract.
8. Every unfinished MCP surface must sit behind a feature flag.

## Terminology Lock

To avoid ambiguity between the user-facing concept and a future external MCP server:

- product-facing term:
  - `Backtick MCP`
- code-facing UI term for the in-app surface:
  - `Execution Map` or `Work Item Board`
- future external bridge term:
  - `Backtick MCP server` or `Backtick MCP tools`

Do not use one unqualified `MCP` name in code for both the UI surface and the external bridge.

## Copied Semantics Lock

For MCP planning, `copied` should be read as:

- `this raw note has entered execution history`

It does not mean only:

- `the user manually copied text to the clipboard`

The state transition is the same in both cases:

1. a human copies raw notes or an export payload and sends it to an LLM
2. MCP uses raw notes to create a real execution payload and sends it into an agent run

Both of those count as:

- `copied`

This means:

- human execution and MCP-mediated execution must produce the same raw-note state transition
- raw notes that actually entered execution should leave the pure active inbox semantics
- Stack and MCP must stay aligned about what has already been used in a real run

This does not count as `copied`:

- opening or reading a raw note
- opening or reading a work item
- AI regrouping or summarization without execution handoff
- creating a work item without exporting or sending it

Additional rules:

- `copied != done`
- `copied` means entered execution history
- `done` means the work is resolved
- if only part of a work item is actually executed, only the source notes included in that real payload become `copied`

Code-facing note:

- the existing `copied` and `lastCopiedAt` names are acceptable in v1
- user-facing labels may later evolve to wording like `Sent`, `Used`, or `Executed`, but the underlying state contract stays the same

## Scope Control

### What To Preserve In V1

- raw captures remain intact
- copied raw notes still move into history semantics
- Stack continues to exist beside MCP
- current capture flow stays frictionless

### What Not To Do In The First MCP Slices

- do not rename `CaptureCard` across the app
- do not replace `Cmd + 2` Stack behavior immediately
- do not add AI auto-grouping before manual work-item creation exists
- do not make capture-time classification mandatory
- do not thread MCP through cloud sync in the first landing slices
- do not add raw-note `done` or `archived` states before the work-item lifecycle is proven

## Proposed Data Model

### Existing Raw Note Baseline

For the first MCP phases, treat `CaptureCard` as the raw-note contract already in production.

That means:

- `text` remains the raw captured fragment
- `suggestedTarget` remains a grouping hint, not truth
- `lastCopiedAt` remains the current execution-history marker for both human copy and MCP execution handoff

### New Derived Objects

Add the following code-facing models in `PromptCueCore`:

1. `WorkItem`
   - `id`
   - `title`
   - `summary`
   - `repoName`
   - `branchName`
   - `status`
   - `createdAt`
   - `updatedAt`
   - `createdBy`
   - `difficultyHint`
   - `sourceNoteCount`

2. `WorkItemSource`
   - `workItemID`
   - `noteID`
   - `relationType`

3. `CopyEvent`
   - `id`
   - `noteID`
   - `sessionID`
   - `copiedAt`
   - `copiedVia`
   - `copiedBy`

### Persistence Additions

Add GRDB tables without disturbing the existing `cards` table:

- `work_items`
- `work_item_sources`
- `copy_events`

The first MCP persistence slices should be additive migrations only.

## Feature Flag Strategy

Use explicit flags so MCP work can merge to `main` before the full experience is complete.

Recommended initial flags:

- `PROMPTCUE_ENABLE_MCP`
  - enables MCP storage reads/writes and the UI entrypoint
- `PROMPTCUE_OPEN_MCP_ON_START`
  - opens the MCP surface for local QA

Do not gate the existing Stack or capture flow behind MCP flags.

## Phase Plan

### MCP0: Contract Lock

Goal:

- freeze terminology
- freeze data-model direction
- add the initial pure models and flags

Scope:

- docs
- `PromptCueCore` model types and status enums
- no production UI yet

Exit criteria:

- raw-vs-derived contract is explicit
- model names are stable enough for stores and UI to start

### MCP1: Persistence Lane

Goal:

- add durable storage for work items and source mappings

Scope:

- GRDB migrations
- stores/service layer
- no visible product UI required beyond debug verification

Exit criteria:

- work items can be written, read, updated, and linked to raw notes
- migration is additive and does not mutate existing raw-note behavior

### MCP2: Read-Only Board

Goal:

- render MCP as a separate execution surface

Scope:

- repo-grouped board
- `open`, `in_progress`, and `done` lanes
- source-count badge
- drill-down into source notes
- hidden behind feature flag and a controlled QA entrypoint

Exit criteria:

- a developer can open MCP and inspect derived work items without affecting Stack

### MCP3: Manual Work Item Creation

Goal:

- allow a user to create work items intentionally from raw notes

Scope:

- create a work item from selected Stack notes
- edit status manually
- preserve full traceability back to source notes

Exit criteria:

- the user can go from raw pile to explicit work items without AI involvement

### MCP4: Execution Handoff

Goal:

- connect work items to the existing execution/copy loop

Scope:

- export or bundle from a work item
- mark source raw notes as copied only on actual send/copy/run start
- record copy events separately from read behavior

Exit criteria:

- Stack and MCP stay consistent about what has actually entered execution history

### MCP5: AI Reorganization

Goal:

- let an agent propose or create work items from raw notes

Scope:

- regroup related notes
- suggest titles/summaries
- create or update work items through a controlled path

Exit criteria:

- AI uses the same work-item contract that the user sees

## File Ownership For MCP Work

Master-owned:

- `docs/Backtick-MCP-Execution-Plan.md`
- `docs/Implementation-Plan.md`
- `docs/Master-Board.md`
- `PromptCue/App/AppCoordinator.swift`
- `PromptCue/App/AppDelegate.swift`
- `PromptCue/App/PromptCueApp.swift`
- `project.yml`

Track A, pure contracts:

- `Sources/PromptCueCore/**`
- `Tests/PromptCueCoreTests/**`

Track B, persistence and services:

- `PromptCue/Services/**`

Track C, execution state orchestration:

- `PromptCue/App/AppModel.swift`
- `PromptCue/UI/WindowControllers/**`

Track D, execution-map UI:

- `PromptCue/UI/Views/**`
- `PromptCue/UI/Components/**`

Do not let multiple tracks edit the same migration or shared contract files at once.

## Merge Strategy

### Branch Role

- `main`
  - remains the clean merge target
- `backtick-mcp`
  - umbrella planning and integration branch
  - not the final long-lived PR branch for the whole effort

### Merge Rule

Do not hold all MCP work in one giant branch until the end.

Instead:

1. use `backtick-mcp` for the plan, spikes, and integration context
2. cut short-lived merge branches from the latest `origin/main`
3. land each MCP slice independently behind flags
4. refresh `backtick-mcp` from `origin/main` after each merged slice

Recommended slice branches:

- `backtick-mcp-contracts`
- `backtick-mcp-store`
- `backtick-mcp-board`
- `backtick-mcp-manual-grouping`
- `backtick-mcp-execution-handoff`
- `backtick-mcp-ai-reorg`

### Merge Order

1. `MCP0` contract lock
2. `MCP1` persistence lane
3. `MCP2` read-only board
4. `MCP3` manual work-item creation
5. `MCP4` execution handoff
6. `MCP5` AI reorganization

### Merge Guardrails

- every slice rebases on the latest `origin/main` before opening or merging the PR
- every slice keeps `main` releasable without MCP being enabled
- no slice may widen scope to “just finish MCP while we are here”
- if a slice is not reviewable in one pass, split it again
- contract and migration files land before parallel UI work

### Verification Per Slice

Minimum:

- `xcodegen generate`
- `swift test`

When app-target code changes:

- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO build`

When MCP UI becomes visible:

- manual QA with MCP disabled
- manual QA with MCP enabled
- regression check that Stack behavior remains unchanged

## Recommended First Landing Slice

Start with `MCP0 + the additive half of MCP1`, not with the board UI.

That first slice should include:

- this plan doc
- `PromptCueCore` work-item contracts
- placeholder feature flags
- additive GRDB migrations and store scaffolding

It should not include:

- user-facing MCP UI
- AI regrouping
- Stack replacement

## Exit Condition For Calling The Lane Successful

The lane is successful when:

- raw captures remain trustworthy source material
- work items are clearly separate derived objects
- Stack and MCP stay consistent about execution history
- the user can see and clear work items without losing raw-note traceability
- AI and human operators read and update the same execution unit
