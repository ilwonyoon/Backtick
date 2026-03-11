# Connector Settings Action-First Plan

Date: 2026-03-11
Status: proposed UX reset for MCP connector setup

## Product Framing

`Settings > Connectors` is not a diagnostics dashboard.

It is a phase router for people who already use Claude Code and want Backtick to work there without understanding MCP internals.

If a user opens the screen and still asks "what am I supposed to do here?", the design has failed.

## Assumptions

- the target user already wants to use Claude Code
- the target user does not need to learn what MCP is
- the target user should not need to understand config formats, helper binaries, repo paths, or launch commands before they can make progress
- the default screen should optimize for Claude Code first

Implication:

- non-Claude flows must not complicate the default information architecture

## Non-Goals

- teaching users how to choose between Claude Code and other clients
- teaching users Claude Code from scratch
- exposing raw helper or config implementation detail on the default surface
- treating "copied a command" as a completed setup action

## Success Bar

The screen should pass these tests:

1. Three-second test: within three seconds, the user can name the one button they should press next.
2. Grandparent test: an 80-year-old vibe coder can finish setup without learning new infrastructure vocabulary.
3. Single-CTA test: every default-state card has exactly one dominant CTA.
4. No-riddle test: the screen never says something is wrong unless it also tells the user what to do next.

## Core UX Rule

The main screen shows only:

- what phase the user is in
- the one action they should take now

Everything else moves behind the next click.

## User Phases

### Phase A: Needs Setup

Definition:

- Claude Code is the intended client
- Backtick is not connected yet

Default card content:

- title: `Connect Backtick to Claude Code`
- supporting line: `Set up takes one terminal command.`
- primary CTA: `Set Up`

What `Set Up` does:

- opens a guided setup sheet
- shows the command
- explains exactly what to do with it
- offers manual fallback only after the primary path

What should not appear on the main screen:

- `Copy Setup Command`
- config snippets
- raw config paths
- `Backtick is not in this config yet`

Reason:

- those are implementation details, not user decisions

### Phase B: Needs Verification

Definition:

- Backtick appears to be connected
- the user has not confirmed that it works locally yet

Default card content:

- title: `Verify the connection`
- supporting line: `Confirm that Claude Code can talk to Backtick.`
- primary CTA: `Verify`

What `Verify` does:

- runs the current connection test
- returns either to `Healthy` or `Needs Repair`

What should not appear on the main screen:

- `Run Test`
- low-level server wording
- launch command detail

Reason:

- the user intent is verification, not "running a server test"

### Phase C: Needs Repair

Definition:

- setup is incomplete
- verification failed
- Claude Code CLI/path/config state is inconsistent
- bundled helper or launch state is blocking progress

Default card content:

- title: `Fix the connection`
- supporting line: one sentence that points to the action, not the diagnosis
- primary CTA: `Fix`

What `Fix` does:

- opens a guided repair sheet
- shows the exact recommended next step
- exposes diagnostics only after the repair path starts

Examples of acceptable supporting lines:

- `Backtick needs one repair step before Claude Code can use it.`
- `The connection check failed. Follow the fix steps, then verify again.`

Examples of unacceptable supporting lines:

- `Backtick is not in this config yet`
- `Launch command unavailable`
- `CLI not found`

Reason:

- these describe system state but do not tell the user what to do

### Phase D: Healthy

Definition:

- setup completed
- latest verification succeeded

Default card content:

- title: `Backtick is ready`
- supporting line: optional and quiet
- primary CTA: none, or a low-emphasis `Details`

What belongs here:

- confidence
- optional entry to monitoring details

What does not belong here:

- another loud button
- success chips
- raw status clutter

Reason:

- healthy state should feel finished, not like another workflow start

## Special Handling: Claude Code Missing

This is the first implementation gate.

If `Claude Code CLI` is missing, the default Connectors surface should collapse to one card only:

- title: `Install Claude Code`
- supporting line: one sentence only
- primary CTA: `Install Claude Code`

What this CTA does:

- opens an install sheet
- tells the user, in order:
1. open the install guide
2. install Claude Code
3. return here

What must not appear in this gate:

- the top-level `Backtick MCP` server card
- Codex alongside Claude Code
- setup commands
- config files
- troubleshooting disclosures

Reason:

- until Claude Code exists, everything else is noise
- the user should not be asked to compare install, setup, verify, and repair at the same time

## Surface Model

### 1. Main Connectors Screen

The main screen is a router, not a workspace.

It should contain only:

- client name
- phase title
- one action-helping sentence
- one primary CTA

It should not contain:

- a top-level `Backtick MCP` server card
- bundled-helper copy
- repository path
- launch command
- config snippet
- config file paths
- passive warning text
- chips that look interactive but are not

Important:

- if Backtick server health matters, it should surface only when it changes the current Claude action

### 2. Setup Sheet

This is where implementation detail becomes acceptable.

Required structure:

1. `Copy the command`
2. `Paste it into Terminal and press Return`
3. `Come back here and press Verify`

Allowed elements:

- `Copy Setup Command`
- `Open Config File`
- `Copy Config Snippet`
- `Manual Setup`
- install/docs fallback

### 3. Repair Sheet

This is where diagnosis becomes acceptable.

Required structure:

- problem summary in plain language
- recommended next action first
- optional technical detail second
- clear route back to `Verify`

Allowed elements:

- last failure detail
- config reveal
- docs link
- command/snippet only if the repair actually requires them

### 4. Details Sheet

This is optional and quiet.

Allowed content:

- latest successful verification
- current config location
- Claude automation note
- manual setup reference

This surface is for reassurance and inspection, not for primary setup.

## CTA Language Rules

Allowed primary CTA labels:

- `Set Up`
- `Verify`
- `Fix`
- `Details`

Disallowed primary CTA labels:

- `Copy Setup Command`
- `Run Test`
- `Open Config`
- `Open Docs`
- `Copy Launch Command`

Reason:

- primary buttons must name the user goal, not the implementation step

## Default Copy Rules

Keep only text that changes the next action.

Good default copy:

- `Set up takes one terminal command.`
- `Confirm that Claude Code can talk to Backtick.`
- `Backtick needs one repair step before Claude Code can use it.`
- `Backtick is ready.`

Bad default copy:

- `Backtick is not in this config yet`
- `Backtick is already built into this app`
- `Local server OK`
- any sentence that explains mechanics before the user has chosen an action

Rule:

- if removing a sentence does not stop the user from completing the next action, remove it

## State Mapping

The UI should collapse implementation states into user phases.

Suggested mapping:

- no configured Claude scope -> `Needs Setup`
- configured Claude scope plus no successful verification -> `Needs Verification`
- any blocking failure or inconsistent environment -> `Needs Repair`
- successful verification -> `Healthy`

Important:

- raw states such as helper source, CLI path, config presence, and server launch detail should not appear directly on the default surface
- they only matter insofar as they determine the current user phase

## Implementation Implications

The next implementation pass should do the following:

- remove the standalone `Backtick MCP` summary card from the default surface
- make Claude Code the first-class default card
- move all command, snippet, and path content behind `Set Up`, `Fix`, or `Details`
- replace passive warnings with guided sheets
- rename technical actions to user-goal actions
- ensure healthy state is visually quiet

If Codex remains supported:

- it must not dilute the Claude-first default flow
- it should follow the same phase model
- it should not force the user to compare two clients on first read

## Acceptance Criteria

The design passes when a user can open `Settings > Connectors` and immediately answer:

1. Am I trying to set up, verify, fix, or just confirm a healthy state?
2. What is the one button I should click right now?
3. If that button opens another surface, are the next steps explicit and ordered?

The design fails when:

- the user sees multiple plausible next actions on the same card
- the user has to interpret diagnostic copy before acting
- the user can copy a command without being told what to do with it
- the default surface behaves like an MCP reference page instead of a guided flow
