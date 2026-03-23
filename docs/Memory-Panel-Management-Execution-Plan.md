# Memory Panel Management Execution Plan

## Objective

Add explicit Memory-panel management for durable documents so users can:

- delete a single document from the Memory panel
- delete an entire project from the Memory panel
- create a new durable document manually by pasting content into the app

This slice should stay aligned with Backtick Memory's existing storage contract:

- durable docs remain reviewed project documents, not transient Stack notes
- deletion remains soft-delete via `supersededByID`, not hard row removal
- direct user creation must not silently violate the current structured-markdown validation rules

## Status And Follow-Up

The original management slice has been implemented and the split-shell refactor has now been redirected onto the stable path.

Current state:

- pane sizing and divider behavior are now owned by a system-managed three-column `NavigationSplitView`
- the earlier `GeometryReader + HStack + custom divider` shell is gone
- the abandoned `NSSplitViewController` experiment should stay dead unless the shell itself regresses again
- pane content stays in SwiftUI end-to-end
- `New Document` now lives in a dedicated footer region below the document list
- document-delete confirmation is shared across list and detail actions so selection repair stays aligned

Remaining follow-up should stay narrow:

- finish runtime QA on resize behavior and footer behavior
- keep visual polish scoped to pane internals
- only consider AppKit list views if dense SwiftUI rows still shimmer during hover / selection changes

## Current Split-Shell Architecture

Memory no longer uses the earlier custom `GeometryReader + HStack + overlay divider` shell.

- `MemoryViewerView` now uses a three-column `NavigationSplitView`
- the system split container owns the project sidebar, document list, and detail pane
- pane sizing and resize behavior come from the system split container instead of custom width math
- `MemoryWindowController` owns only the window, refresh toolbar item, and frame persistence
- the project and document columns expose explicit width bounds through `PanelMetrics`
- the detail pane enforces its own minimum readable width
- `New Document` is a dedicated pane footer action, not a selectable list row
- root/pane ownership is intentional:
  - `MemoryViewerView` owns the new-document sheet and shared selection-sync path
  - project pane owns project delete confirmation
  - document pane owns the footer action and list interactions
  - detail pane owns save / edit chrome and the storage-error surface

This keeps the window toolbar in AppKit, keeps the sheet and pane presentation in SwiftUI, and moves the resize-sensitive shell to a system-managed split container. The panel should now behave more like Apple Notes / Finder / Mail and be less fragile during future polish passes.

## Why This Slice Exists

Current state:

- the storage layer already supports `deleteDocument`
- MCP already exposes `delete_document`
- the Memory panel has no user-facing delete action for documents or projects
- the Memory panel has no user-facing path to create a durable document directly
- clearing an existing document in the editor does not remove it from Memory; the document remains because deletion is a separate contract

That leaves the panel read-heavy and edit-heavy, but not management-complete.

## Source Files

Primary implementation files:

- `PromptCue/UI/Memory/MemoryViewerModel.swift`
- `PromptCue/UI/Memory/MemoryViewerView.swift`
- `PromptCue/Services/ProjectDocumentStore.swift`
- `PromptCue/UI/WindowControllers/MemoryWindowController.swift`
- `PromptCueTests/MemoryViewerModelTests.swift`

Reference behavior already in place:

- `PromptCue/Services/ProjectDocumentStore.swift`
- `Sources/BacktickMCPServer/BacktickMCPServerSession.swift`

## Product Contract

### Document Deletion

- Users must be able to delete the currently selected document from the Memory panel.
- Deletion must require confirmation.
- Deletion should remove the document from the active Memory list by marking it superseded, matching existing storage behavior.
- After deletion, selection should move predictably:
  - next document in the same project if available
  - otherwise first remaining document in the same project
  - otherwise first remaining project
  - otherwise empty state

### Project Deletion

- Users must be able to delete all active documents for a selected project from the Memory panel.
- Project deletion must require stronger confirmation than single-document deletion.
- Project deletion should only affect active documents in that project.
- Superseded historical rows may remain in the database; they should stay hidden from the viewer.

### Direct Document Creation

- Users must be able to create a new durable document directly inside the Memory panel.
- Users must be able to paste clipboard text into the creation flow.
- New document creation should support:
  - `project`
  - `topic`
  - `documentType`
  - `content`
- The create flow must not force users to memorize the durable markdown contract.

### Empty-Editor Behavior

- If a user clears an existing document and tries to save, the panel should treat that as probable delete intent.
- Saving whitespace-only content should not fail as a confusing no-op.
- Instead, the panel should present a delete confirmation path for the current document.

## UX Proposal

### Toolbar And Row Actions

- Add a document-level destructive action in the detail header controls:
  - `Delete Document…`
- Add a project-level destructive action from the project list row context menu:
  - `Delete Project…`
- Optionally add a document-list row context menu mirror for `Delete Document…` if the implementation stays small
- Add a document-pane footer action:
  - `New Document`

### New Document Flow

- Present a lightweight sheet from `New Document`
- Default values:
  - `project`: currently selected project if one exists
  - `documentType`: `discussion`
  - `topic`: empty
  - `content`: starter template
- Add `Paste Clipboard` inside the sheet
- If the clipboard contains text:
  - paste it into the editor
  - preserve the user's ability to edit before saving

### Starter Template

The new-document sheet should start from a valid durable template instead of a blank text box. Recommended default:

```md
## Overview

Paste or write the durable context here.

## Details

Add the key supporting details here.
```

This keeps the create flow aligned with current validation without forcing users to hand-author headers first.

### Raw Paste Handling

- If pasted text already fits the durable shape, save it as edited by the user.
- If pasted text is raw plain text, the sheet should still let the user save after placing it into the template.
- Avoid automatic summarization or AI compression in this flow.
- This is manual Memory authoring, not automatic review/save conversion.

## Implementation Plan

### Phase M1: Model Management Actions

Add explicit model actions in `MemoryViewerModel`:

- `deleteSelectedDocument()`
- `deleteProject(_:)`
- `createDocument(project:topic:documentType:content:)`
- optional helper: `prepareNewDocumentDraft(fromClipboard:)`

Selection rules should be centralized in the model so the view stays thin.

### Phase M2: Detail-Panel Delete UX

In `MemoryViewerView`:

- add a destructive button to `MemoryDetailPane`
- show a confirmation alert before delete
- when editing, if save is pressed with only whitespace, route to the same delete confirmation flow

This keeps delete intent explicit and makes the “clear everything” case understandable.

### Phase M3: Project Delete UX

In `MemoryProjectListPane`:

- add a context menu per project row
- expose `Delete Project…`
- show project-scoped confirmation text that includes the project name and active document count

Project delete should not require a separate management window.

### Phase M4: New Document Sheet

Add a creation sheet owned by `MemoryViewerView` and backed by `MemoryViewerModel`:

- text fields for project and topic
- picker for `documentType`
- multiline editor for content
- `Paste Clipboard`
- `Create`
- `Cancel`

On success:

- refresh the list
- select the newly created document
- exit the sheet

### Phase M5: Test Coverage

Extend `PromptCueTests/MemoryViewerModelTests.swift` for:

- deleting the selected document updates selection correctly
- deleting the last document in a project moves selection to another project or empty state
- deleting a project removes all active docs for that project from the viewer
- creating a document selects it and places it under the expected project
- saving empty content from an edited document maps into delete-intent handling at the model/view boundary

If view-state branching becomes non-trivial, add focused UI-state tests only where they materially de-risk behavior.

### Phase M6: Split-Shell Refactor

Status: complete.

Replace the earlier custom shell with a system-managed three-column split:

- use `NavigationSplitView`
- configure the three columns:
  - project sidebar
  - document content list
  - detail pane
- move column sizing and resize behavior into the system split container
- keep project/document width bounds explicit in `PanelMetrics`
- let the document and detail panes own only pane-local content, not divider chrome

This phase should remove the need for custom width math in `MemoryViewerView`.

### Phase M7: Pane Boundary Cleanup

Status: complete.

After the split shell is in place:

- reduce `MemoryViewerView` to pane content and pane-local actions
- keep pane backgrounds owned by the pane root, not by the divider layer
- move `New Document` into a dedicated footer region below the document list
- avoid sharing selectable-row primitives with pane footer actions

### Phase M8: Post-Refactor Polish

Status: remaining follow-up.

Only after the split shell is stable:

- tighten typography and spacing
- verify hover / selection rendering no longer shimmers during dense-list polish
- decide whether the left / middle list panes should remain SwiftUI lists or move to AppKit list views for further stability

## Open Decisions To Lock During Implementation

1. Should `Delete Project…` live only in the project-row context menu, or also in the main toolbar?
2. Should `Paste Clipboard` open the new-document sheet with prefilled content, or should there be a separate `Paste as New Document` toolbar button?
3. For very short pasted content that still fails durable validation, should the sheet show inline validation only, or should it expand the starter template automatically on first paste?

Recommended answers:

1. Keep project delete in the row context menu only.
2. Keep one `New Document` footer action in the document pane and include `Paste Clipboard` inside the sheet.
3. Start with the valid starter template plus inline validation messaging; avoid hidden content mutation after paste.

## Risks

- Project deletion can feel too destructive if confirmation copy is weak.
- Selection bugs after deletion can make the panel feel unstable.
- Manual paste-create can feel broken if validation errors are surfaced too late.
- Over-designing the creation flow would push Memory toward note-app behavior; keep the sheet minimal.
- If dense SwiftUI row rendering still visibly shimmers under hover or selection changes, the next structural step should be AppKit list views for the left and middle panes.

## Verification

Minimum verification for this slice:

- `swift test --filter MemoryViewerModelTests`
- `xcodegen generate`
- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO test -only-testing:PromptCueTests/MemoryViewerModelTests`
- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO build`

Optional app-surface verification after the main logic is green:

- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO build`

## Expected Outcome

After this slice:

- Memory panel users can delete documents without dropping to MCP or direct database edits
- Memory panel users can remove obsolete projects from the active list
- Memory panel users can create durable docs by pasting content directly into the app
- clearing all content in an edited document no longer feels like a broken save path
- Memory pane resizing is system-owned and visually stable
- divider grab targets no longer require visible custom chrome
- `New Document` behaves like a pane footer action instead of a malformed list row

After the remaining polish follow-up:

- future spacing / typography polish should stop breaking pane structure
- any remaining shimmer decisions can be made independently from pane sizing and divider behavior

## Suggested Follow-Up Order

From the current refactored state:

1. Do a manual Memory-panel smoke pass focused on pane resize, divider feel, and `New Document` footer behavior.
2. Tighten typography and spacing only inside pane-local content.
3. Re-check hover and selection shimmer after any density change.
4. If shimmer remains unacceptable, prototype AppKit list views for the left and middle panes without changing split-shell ownership.

## Definition Of Done

- A selected Memory document can be deleted from the panel with confirmation.
- A selected project can be removed from the active Memory list with confirmation.
- A user can create a durable document manually from pasted text inside the panel.
- New documents are selected immediately after creation.
- Deletion leaves selection in a predictable state.
- Saving whitespace-only content from an edited document does not silently leave a stale doc behind.
- `PromptCueTests/MemoryViewerModelTests.swift` covers the new model behaviors.
- Pane resizing is owned by the system split container instead of custom SwiftUI width math.
- `New Document` is implemented as a dedicated pane footer action.

## Handoff Prompt

Paste this into the next session after moving into the worktree if the remaining post-refactor polish still needs to be finished:

```text
Work in /Users/ilwonyoon/Documents/PromptCue-memory-panel on branch feat/memory-panel-management.

Continue the post-refactor Memory panel polish described in docs/Memory-Panel-Management-Execution-Plan.md.

Scope:
- validate the system-managed Memory split-shell behavior
- keep `New Document` as a dedicated footer action
- tighten pane-internal spacing and typography without reintroducing shell regressions
- investigate remaining dense-list shimmer only if it is still visible at runtime

Constraints:
- keep PromptCue / PromptCueCore code-facing names unchanged
- preserve the current durable document storage contract
- use ProjectDocumentStore soft-delete behavior, not hard delete
- keep the UI minimal and consistent with the existing Memory panel
- keep pane sizing and divider ownership in the system split container

Verification:
- swift test --filter MemoryViewerModelTests
- xcodegen generate
- xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO build
- xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO test -only-testing:PromptCueTests/MemoryViewerModelTests

Before editing, read:
- docs/Memory-Panel-Management-Execution-Plan.md
- PromptCue/UI/Memory/MemoryViewerView.swift
- PromptCue/UI/WindowControllers/MemoryWindowController.swift
```
