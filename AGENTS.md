# Backtick Agent Guide

## Purpose

This repository defaults to fast, high-quality execution with explicit coordination. Use agents to improve speed, quality, or conflict isolation. Do not use agents by default when a task is small, tightly coupled, or faster to complete directly.

## Product Context

- Product: `Backtick`
- Shape: native macOS utility app
- App stack: `SwiftUI + AppKit hybrid`
- Distribution baseline: Gumroad-backed direct download first
- Compatibility lane: Mac App Store later
- Core shared logic: `PromptCueCore`

Brand note:

- user-facing product identity is `Backtick`
- current repo name, app target, and core module remain `PromptCue` / `PromptCueCore` for now
- treat those code-facing names as temporary technical identifiers, not product-direction cues

Source-of-truth docs:

- `docs/Execution-PRD.md`
- `docs/Implementation-Plan.md`
- `docs/Master-Board.md`
- `docs/Engineering-Preflight.md`

## Execution Default

Primary goal:

- maximize delivery speed
- do not compromise output quality
- use master/sub-agent splits only when they improve both or clearly improve one without harming the other

Preferred default for broad or decomposable work:

- one master agent coordinates
- worker agents own disjoint files or tracks
- master reviews and integrates sequentially

Master responsibilities:

- define the smallest useful outcome
- freeze contracts before parallel work starts
- assign the right model per subtask
- review worker output before integration
- run or coordinate final verification
- own the final user-facing summary

Single-agent is preferred when:

- the task is one file or one tightly coupled change
- the task is mostly analysis or quick cleanup
- parallel work would create merge risk or overhead

Use multi-agent only when it improves one or more of:

- delivery speed
- review quality
- conflict isolation
- verification coverage

Do not use multi-agent if it creates merge churn, duplicated reasoning, or weaker review than a single strong pass.

## Model Routing Rule

Use task-aware model routing by default.

Core rule:

- choose the most appropriate model for the task
- prefer the cheapest / fastest model that can complete the slice without quality loss
- do not force `Spark` when the subtask clearly needs stronger reasoning
- do not keep expensive models on trivial or bounded work

Main session rule:

- the main session uses the model already attached to the current conversation unless changed outside the repo
- do not pretend the main session changed models when it did not
- the master agent should treat the main session model as the integration and final-review lane by default

Sub-agent routing rule:

- assign models explicitly per worker when using sub-agents
- examples:
  - bounded read-only exploration, grep-heavy inspection, narrow UI nits, isolated mechanical edits:
    - `GPT-5.3-Codex-Spark` or another lightweight worker
  - coupled runtime issues, delicate architecture choices, regression-sensitive edits, final review on risky slices:
    - `gpt-5.4` or the strongest available model that fits the risk
  - tiny scoped tasks where a smaller worker is sufficient:
    - use a smaller/faster model if available and safe

Execution protocol:

- only mention model choice when it corresponds to a real assignment or escalation
- if a worker is assigned a non-default model, state it explicitly and say why
- if a blocker requires a stronger model, escalate for that slice only
- after the blocker is resolved, move subsequent work back to the cheapest model that preserves quality

Budget guardrail:

- avoid running entire tasks on the most expensive model when only part of the work needs it
- keep expensive-model usage time-boxed to the slices that genuinely benefit
- if a stronger model is used for a worker slice, the master should still verify the result before landing it

## Planning Rules

Before editing:

- identify the smallest useful outcome
- check source-of-truth docs first
- judge proposals against `Backtick` as an AI coding scratchpad / thought staging tool, not a note app
- preserve the core interaction model:
  - Capture = frictionless dump
  - Stack = execution queue
  - AI compression happens in Stack, not in Capture
- define ownership boundaries if more than one agent will edit
- freeze shared contracts before parallel implementation

If the task is substantial, keep a short live plan with:

- current step
- blocked dependencies
- next verification command

## File Ownership Guidance

Master-owned by default:

- app entrypoints
- dependency wiring
- release-sensitive config
- shared contract changes
- integration docs

Typical split:

- `Sources/PromptCueCore/**`
  - pure logic, formatting, domain rules, testable models
- `PromptCue/Services/**`
  - macOS integrations, persistence, hotkeys, screenshot access
- `PromptCue/UI/**`
  - views, panels, interaction behavior
- `docs/**`
  - product, planning, release, and process docs

Do not let two agents edit the same file unless the master explicitly opens that edit window.

## PromptCueCore Rule

Prefer `PromptCueCore` for:

- domain models
- TTL logic
- formatting rules
- pure transformation logic
- code that should be covered by `swift test`

Prefer app target code for:

- `AppKit`
- `SwiftUI`
- `NSPasteboard`
- panel controllers
- filesystem access
- security-scoped bookmarks
- launch-at-login

If logic starts in the app and is pure, move it into `PromptCueCore` early so tests cover real code instead of duplicated code.

## Verification Expectations

Minimum verification for relevant changes:

- `swift test`
- `xcodegen generate`

Add app-target verification when touching buildable app surfaces:

- `xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO build`

If you do not run a relevant verification step, say so explicitly and explain why.

## Release-Sensitive Areas

Treat these as high-risk and review carefully:

- signing and bundle identifiers
- entitlements and sandbox behavior
- screenshot folder access
- security-scoped bookmarks
- launch-at-login
- notarization
- DMG packaging
- Gumroad release artifacts
- App Store compatibility

Changes in these areas should usually stay master-owned or be reviewed by the master before integration.

## Context Discipline

- Keep context small
- Read only the files needed for the current step
- Prefer updating existing docs over creating overlapping docs
- Avoid speculative refactors during feature work
- Do not fan out agents unless contracts and ownership are clear

## UI Restraint Rule

- Preserve Backtick's minimal, less invasive, Spotlight-first, and quiet ambient behavior.
- Do not add verbose UI chrome, helper copy, subtitles, status rows, or redundant cues unless they resolve a real ambiguity, permission block, error, or destructive consequence.
- Keep Capture optimized for a frictionless dump, not drafting or organization.
- Keep Stack optimized as an execution queue where grouping, export, and AI compression can happen without polluting capture.
- Apply a subtraction test to capture UI changes: if the panel still works after removing a new element, keep it out.

## Output Standard

When finishing a task, report:

- what changed
- what was verified
- remaining risks or gaps

For multi-agent work, the master should also report:

- which tracks ran in parallel
- merge order
- any deferred conflicts or follow-up cleanup
