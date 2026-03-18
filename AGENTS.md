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

- `docs/Execution-PRD.md` — product requirements
- `docs/Implementation-Plan.md` — Capture + Stack (Hot) build plan
- `docs/Master-Board.md` — overall status board
- `docs/Engineering-Preflight.md` — pre-launch checklist
- `docs/MCP-Platform-Expansion-Research.md` — **MCP + Warm Memory execution plan** (tool descriptions, client behavioral design, project/topic classification, phasing)

**Doc routing rule:** Before starting a task, check which doc applies:
- Capture / Stack / UI / design system → `Implementation-Plan.md`
- MCP tools / tool descriptions / Warm Memory / Memory panel / cross-platform AI behavior → `MCP-Platform-Expansion-Research.md` (start from the **Implementation Plan** section at the bottom)
- Overall status / what's done / what's next → `Master-Board.md`

## Execution Default

Preferred default for broad or decomposable work:

- one master agent coordinates
- worker agents own disjoint files or tracks
- master reviews and integrates sequentially

Single-agent is preferred when:

- the task is one file or one tightly coupled change
- the task is mostly analysis or quick cleanup
- parallel work would create merge risk or overhead

Use multi-agent only when it improves one or more of:

- delivery speed
- review quality
- conflict isolation
- verification coverage

## Model Routing Rule

Use usage-aware model routing by default:

- default model: `GPT-5.3-Codex-Spark`
- upgrade to `Codex high` only for short, high-leverage slices:
  - complex architecture decisions with high regression risk
  - deeply coupled runtime/build/release failures where Spark stalls
  - security/signing/notarization blockers that require maximal reasoning depth
- after the blocking slice is resolved, return immediately to `GPT-5.3-Codex-Spark`

Execution protocol:

- before starting a substantial task, state recommended model in one line: `Model: Spark` or `Model: High`
- if escalation is needed mid-task, state it explicitly: `Escalate to High for this slice only`
- once resolved, state downgrade explicitly: `Back to Spark`

Budget guardrail:

- avoid running entire tasks in `Codex high`
- keep `Codex high` time-boxed to blocker resolution, then continue implementation and verification on Spark

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
