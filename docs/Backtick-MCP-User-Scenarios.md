# Backtick MCP User Scenarios

## Purpose

This document exists to validate whether the intended `Backtick MCP` behavior is actually aligned with the product goal.

If these scenarios feel wrong, the MCP plan is wrong.

The standard to judge against is:

- capture stays frictionless
- raw notes remain the source of truth
- MCP turns raw captures into execution units
- Stack and MCP stay consistent about what is still actionable and what has already entered execution history

## State Semantics Lock

In these scenarios, `copied` means:

- the raw note has actually entered execution history

That includes both:

- a human copying the note or export payload and sending it to an LLM
- MCP using the note in a real execution payload for an agent run

That does not include:

- reading a note
- viewing a work item
- AI regrouping without execution handoff
- creating a work item without sending it anywhere

And always:

- `copied != done`
- `copied` means `used in a real execution flow`
- `done` means `resolved`

## Success Scenarios

### S1. Fast capture still feels unchanged

User situation:

- a developer is coding with an AI agent running in the background
- they notice three issues in quick succession

Flow:

1. the user opens capture
2. enters three short raw notes one by one
3. closes capture without organizing anything

Expected result:

- every note is stored as a raw capture
- the user is not forced to classify, label, or route anything
- Stack shows the new raw notes as active items
- MCP does not interfere with capture speed or impose structure at capture time

This scenario matters because:

- MCP must not turn capture into a mini task manager

### S2. Raw notes and execution map can coexist

User situation:

- the user has a pile of related notes about one settings bug

Flow:

1. the user opens Stack and sees the raw notes individually
2. the user opens MCP and sees a work item derived from those notes
3. the user expands the MCP card

Expected result:

- Stack still shows the underlying raw notes
- MCP shows one execution-oriented work item
- the MCP card reveals which raw notes it came from
- the user can move between the derived work item and the source notes without losing traceability

This scenario matters because:

- MCP is an additive execution surface, not a destructive replacement for Stack

### S3. Manual grouping creates a real execution unit

User situation:

- the user sees four raw notes that clearly belong to one coding task

Flow:

1. the user multi-selects those notes in Stack
2. the user chooses `Create Work Item`
3. the user gives the work item a title and optional summary

Expected result:

- one work item is created
- the work item references all selected source notes
- the source notes remain intact
- the new work item appears in the `open` lane of MCP
- the user can understand the coding task faster from the work item than from the raw pile alone

This scenario matters because:

- MCP must create a better execution unit, not just another label layer

### S4. Work item status shows progress without rewriting history

User situation:

- the user has started working on a bug grouped into one work item

Flow:

1. the user moves the work item from `open` to `in_progress`
2. later, the user marks it `done`

Expected result:

- the work item status changes independently of the raw notes
- raw notes are still viewable as source material
- marking the work item `done` does not delete raw notes
- the user can still inspect what evidence created the work item

This scenario matters because:

- execution state belongs to the work item layer, not to the raw capture itself

### S5. Actual execution handoff updates Stack and MCP consistently

User situation:

- the user wants to send one work item to an AI agent

Flow:

1. the user opens a work item
2. chooses export or bundle creation
3. sends that payload to an agent

Expected result:

- the export uses the work item as the execution unit
- the source raw notes are marked as `copied` only when the actual send/copy/run start happens
- Stack moves those raw notes out of the active action list into history semantics
- MCP reflects that the work item has entered execution flow

This scenario matters because:

- the human-visible Stack state and the AI execution state must stay aligned
- MCP execution and human copy must mean the same state transition

### S6. Reading is not treated as execution

User situation:

- the user is reviewing MCP but is not ready to send anything yet

Flow:

1. the user opens MCP
2. clicks through a few work items
3. inspects source notes
4. closes the app without exporting

Expected result:

- nothing is marked copied just because it was viewed
- Stack active items remain active
- MCP still shows the work items as not yet handed off

This scenario matters because:

- reading, inspecting, and thinking must remain distinct from execution

### S7. AI regrouping helps, but the user still trusts the system

User situation:

- the user has many raw notes across one repo and wants help reorganizing them

Flow:

1. the user asks AI to regroup related notes
2. the system proposes several work items
3. the user reviews the proposed grouping

Expected result:

- AI creates derived work items rather than mutating raw notes
- each work item points back to its sources
- the user can accept, edit, or dismiss the result
- the user never feels that the original evidence disappeared

This scenario matters because:

- MCP should feel like execution-oriented reorganization, not semantic vandalism

## Failure Scenarios

### F1. AI groups notes incorrectly

Failure shape:

- the AI combines unrelated raw notes into one work item

Correct system behavior:

- raw notes are still preserved
- the user can inspect the source mapping and see the mistake
- the user can split, dismiss, or recreate the work item
- the system never overwrites the raw notes to match the bad grouping

### F2. Context hints point to the wrong repo or branch

Failure shape:

- a capture was taken while the user had the wrong terminal or editor in focus

Correct system behavior:

- context is treated as a hint, not truth
- the user can still group the note into the correct work item manually
- the system does not hard-lock the note to the wrong repo or branch

### F3. A work item is viewed, but not actually executed

Failure shape:

- the system treats opening or previewing a work item as if it had already been sent to an agent

Correct system behavior:

- no copied marker is applied on read
- no source note leaves the active stack until real handoff occurs
- execution history changes only on actual copy/send/run start or bundle creation that begins a real run

### F4. Copied is mistaken for done

Failure shape:

- the user exports a work item, but the system assumes the task is finished

Correct system behavior:

- copied means `entered execution history`
- done means `resolved`
- the work item may remain `open` or `in_progress` after export until the user or system explicitly closes it

### F4A. MCP execution is treated differently from human copy

Failure shape:

- a human manually copying a note marks it copied
- MCP sending the same note into a real agent run does not mark it copied, or marks it in a different state model

Correct system behavior:

- both flows produce the same raw-note state transition
- Stack does not distinguish “human executed” vs “MCP executed” as separate action-history semantics
- the difference can exist in event metadata, but not in whether the note entered execution history

### F5. One raw note needs to support more than one work item

Failure shape:

- a single raw note is relevant to multiple execution units

Correct system behavior:

- the source mapping can support one-to-many relationships where needed
- the note is not destroyed or forced into only one interpretation
- relation type clarifies whether the note is primary, supporting, or duplicate evidence

### F6. MCP degrades the current app even when disabled

Failure shape:

- MCP work lands in `main`, but capture or Stack gets slower or more confusing even with MCP off

Correct system behavior:

- MCP remains behind an explicit feature flag during rollout
- when MCP is disabled, capture and Stack keep their current behavior
- every MCP slice proves non-regression before merge

### F7. Execution starts, but the task stalls or fails

Failure shape:

- a work item is exported to an agent
- the source notes are marked copied
- the coding task stalls, fails, or is abandoned
- the work disappears from the user’s active mental model because the raw notes already moved to history semantics

Correct system behavior:

- the work item remains visible in MCP as still actionable
- copied source notes remain traceable from the work item
- the user has an explicit way to move the work item back to `open` or otherwise keep it in `in_progress`
- the system does not assume that export equals resolution

### F8. New raw notes make an existing work item stale

Failure shape:

- the user captures new raw notes that clearly relate to an existing work item
- the older work item summary is now incomplete or misleading

Correct system behavior:

- the system does not silently rewrite the existing work item
- the user can review and attach the new notes intentionally
- MCP can surface that new related source material may exist
- the user never loses trust in what evidence currently backs the work item

### F9. Duplicate work items represent the same real task

Failure shape:

- the user or AI creates two separate work items that are really the same execution unit

Correct system behavior:

- MCP makes duplicate or overlapping work items visible enough to notice
- the user can merge, dismiss, or keep them intentionally
- the system should not silently hide one duplicate and destroy traceability

### F10. Partial export marks too many source notes as copied

Failure shape:

- a work item has several source notes
- the user exports only part of the work item or edits the outgoing bundle
- the system marks every linked source note as copied anyway

Correct system behavior:

- only the notes actually included in the executed payload receive copied events
- source mapping and execution history remain distinct concepts
- the user can still see which source notes have not actually entered execution flow

## Phase Gate Scenarios

These scenarios define what each MCP phase must prove before it should merge.

### MCP0 gate

- S1 must still hold
- F6 must not occur

### MCP1 gate

- S1 must still hold
- persistence for derived objects exists without changing current Stack behavior
- F6 must not occur

### MCP2 gate

- S2 and S6 must hold
- MCP can be opened without changing Stack semantics

### MCP3 gate

- S3 and S4 must hold
- F1, F2, and F9 must be recoverable by the user

### MCP4 gate

- S5 must hold
- F3, F4, F7, and F10 must not occur

### MCP5 gate

- S7 must hold
- F1, F2, F5, F8, and F9 must remain recoverable without losing trust in raw-note traceability

## What Good Looks Like

If Backtick MCP is implemented correctly, the user should feel:

- capture is still instant
- the raw pile is still available when needed
- the execution map is easier to act on than the raw pile
- already-sent work is visibly different from still-pending work
- AI and human are looking at nearly the same unit of work

If the user instead feels:

- they have to organize while capturing
- raw notes disappeared into AI summaries
- copied and done are confusing
- Stack and MCP disagree about what is still actionable
- old work items silently drift away from new evidence

then the implementation is off-spec.
