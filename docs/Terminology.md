# Terminology System

Product-wide naming conventions for Backtick. Every user-facing label, copy, and documentation should follow this guide.

## Core Principle

> A term is good if someone who has never used the app understands it instantly.

No jargon. No metaphors that need explanation. Use words people already know.

## Product Vocabulary

### Places (user sees these as destinations)

| Internal name | User-facing name | What it is |
|---|---|---|
| Stack | **Stack** | Short-term prompt queue. Auto-expires. |
| Memory | **Memory** | Long-term project documents. Persists across sessions. |

### Objects (what lives inside each place)

| Place | Object term | Example header |
|---|---|---|
| Stack | **prompts** | `4 prompts` |
| Memory | **docs** | `3 docs` |

The distinction is intentional — different words signal different nature:
- **prompts** = short, disposable, use-and-discard
- **docs** = long, structured, accumulate over time

### States (how objects change)

| State | Label | Meaning |
|---|---|---|
| Default (uncopied) | _(no label)_ | Just a prompt. No special state needed. |
| After copy | **Copied** | User copied it. Moves to Copied section. |

Default state gets no label. Only label the exception, not the norm.

### Actions (verbs the user performs)

| Action | Verb | Context |
|---|---|---|
| Input a prompt | **Capture** | Cmd+` opens capture input |
| Copy prompts | **Copy** | Select and copy to clipboard |
| Save to Memory | **Save** | AI or user saves a doc to Memory |
| Retrieve from Memory | **Recall** | AI pulls relevant docs |

## Retired Terms

These terms should NOT appear in user-facing UI:

| Retired | Replacement | Reason |
|---|---|---|
| On Stage | _(no label)_ | Default state doesn't need a name |
| Off Stage | Copied | Describes the action that happened |
| Hot | _(internal only)_ | Temperature model stays in dev docs only |
| Warm | _(internal only)_ | Temperature model stays in dev docs only |
| Cards | prompts | "Cards" is an implementation detail |
| Artifacts | _(never use)_ | Requires explanation |

## Stack Panel Header

```
┌─────────────────────────────┐
│  4 prompts        [Copy ⊕] │
├─────────────────────────────┤
│  [prompt]                   │
│  [prompt]                   │
│  [prompt]                   │
│  [prompt]                   │
├─────────────────────────────┤
│  Copied  2           [▼]   │
│  ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄  │
└─────────────────────────────┘
```

- Top: count of uncopied prompts only
- Filter removed — unnecessary complexity
- Copied section: collapsible, with delete-all option
- Action feedback: `"3 Copied"` on copy action (already correct)

## Memory Panel Header (future)

```
┌─────────────────────────────┐
│  3 docs             [+ ⊕]  │
├─────────────────────────────┤
│  [doc: branding]            │
│  [doc: architecture]        │
│  [doc: pricing]             │
└─────────────────────────────┘
```

## Brand Line

> **Stack for today. Memory for everything else.**

## Rules for Adding New Terms

1. Can a first-time user guess what it means? If no, pick a different word.
2. Does it conflict with an existing term? Check this doc first.
3. Internal-only concepts (Hot/Warm/Cold, Card, Stage) stay in code and dev docs — never in UI.
4. When in doubt, use fewer words. A number alone beats a number with a label that needs explanation.
