# MCP Polish Plan

## Purpose

Lock the next MCP and Memory polish direction for Backtick so the product language, save behavior, and durable document model stop drifting apart.

This plan exists because the current Warm Memory lane exposed three problems at once:

- terminology drift between product/UI/docs/MCP/internal concepts
- automatic save behavior that is too eager and too opaque
- saved content that often keeps the wrong level of detail or the wrong document shape

The goal of this slice is not to add more MCP surface area first. The goal is to make the existing Memory lane understandable, predictable, and reviewable.

## Draft Direction

### Product Vocabulary

Backtick should use one consistent product vocabulary:

- `Prompt`
- `Memory`

Meaning:

- `Prompt` = the short-lived active working surface for prompt staging and immediate next actions
- `Memory` = the durable reviewed surface for longer-lived project context

Backtick remains the product name. `Prompt` and `Memory` are the two user-facing surfaces.

### Deprecated Vocabulary

These terms should be treated as deprecated for product-facing language:

- `Stack`
- `Hot`
- `Warm`

They may exist temporarily in old docs or code, but they should stop being the source vocabulary for new product, MCP, and UX decisions.

### Internal Vocabulary Rule

The target is one shared vocabulary across product, docs, MCP, and internal architecture:

- prefer `Prompt`
- prefer `Memory`

Do not keep separate conceptual languages for users and for internal planning if they describe the same product surface. That split creates avoidable confusion.

Implementation detail:

- code symbol migration may still land in slices
- but the intended vocabulary should be singular from this point on

## Information Architecture

### Prompt

`Prompt` is the active, short-lived surface.

It covers:

- quick capture
- prompt staging
- short-lived execution context
- immediate export/copy/send behavior

`Capture` becomes an interaction or entry behavior inside the Prompt lane, not a separate top-level mental model.

### Memory

`Memory` is the durable, reviewed, project-context surface.

It covers:

- saved decisions
- plans
- background context
- reviewed discussion summaries

The Memory viewer should feel topic-first, not schema-first.

## Topic And Type Model

### User-Visible Rule

Users should primarily see:

- project
- topic
- document content

Users should not need to think in `discussion / decision / plan / reference` during normal browsing.

### Internal Rule

`documentType` remains an internal storage and behavior contract.

Its job is to help:

- save/review behavior
- update rules
- retrieval behavior
- proposal quality

It is not the primary user-facing navigation model.

### Topic Rule

`topic` is the subject of the document, not the shape of the document.

Good topics:

- `tax-2025`
- `launch-pricing`
- `memory-save-flow`
- `company-research-pipeline`

Bad topics:

- `decision`
- `reference`
- `warm-memory`
- other internal taxonomy or implementation jargon

### Topic Generation Rule

Do not over-constrain topic creation with a rigid fixed taxonomy.

The model should be allowed to propose topics from the actual conversation context, with these guardrails:

- reuse an existing topic if it is clearly the same subject
- prefer narrower subject names over broad buckets
- avoid internal jargon
- avoid near-duplicates

## Save Behavior

### Default Save Flow

The default Memory save flow is:

- `proposal`
- `review`
- `confirm`
- `write`

This applies even when the user says "save this."

The point is not to block saving. The point is to let the user confirm:

- what is being saved
- under which topic
- whether it is a new document or an update
- whether the preview is clean enough to keep

### Why Direct Save Is Not The Default

Long discussions are hard to classify correctly after the fact.

Failure modes already seen:

- the wrong topic gets chosen
- internal jargon leaks into topics
- `documentType` is technically valid but user-expectation-invalid
- one document mixes decisions, plans, exploration, and implementation noise
- the saved result becomes a polished report instead of useful future context

### Long-Thread Rule

Do not directly auto-split a long mixed thread into multiple final Memory docs by default.

If the boundaries are unclear:

- first propose what should be saved
- if needed, fall back to one reviewed Memory summary
- only extract multiple shaped documents after review

## Proactive Behavior

Backtick should proactively notice when a save might help.

Examples:

- a meaningful decision was reached
- a plan was settled
- a long discussion is wrapping up
- a repeated explanation is likely to be needed again

The desired behavior is:

- ask first
- do not save silently

Preferred wording:

- `이 내용을 Backtick Memory에 저장할까요?`
- `이 결정 백틱 메모리에 남겨둘까요?`

Do not say only:

- `메모리에 저장할까요?`

That wording collides with built-in model memory.

## Saved Content Quality

### Save This

Save durable project context such as:

- key decisions and why they were made
- active plans and next-step structure
- durable constraints
- project-specific background that future sessions will need
- reviewed summaries of explored options

### Do Not Save This

Do not save:

- coding-session logs
- file-by-file change logs
- shell transcripts
- test-command transcripts
- git-like execution history
- noisy implementation detail that changes day to day
- raw conversation transcripts
- taxonomy or jargon that only makes sense to the implementation

### Quality Standard

A good Memory document should help a future AI session resume work quickly.

It should not read like:

- a manual
- a changelog
- a terminal transcript
- a polished consulting report

It should read like:

- reviewed project context
- clear decisions
- active direction
- useful durable state

## MCP Contract Implications

The next MCP contract should reflect the review-first model.

### Keep

- `list_documents`
- `recall_document`
- `save_document`
- `update_document`

### Add

- `propose_document_saves`

`propose_document_saves` should be read-only and should return:

- proposed topic
- internal `documentType`
- create vs update recommendation
- why this is worth saving
- preview text
- warnings if the content is noisy or overmixed

### Behavior Rules

- recall before answer when durable context likely matters
- ask before write when a save is useful
- never silently auto-save
- use `update_document` for narrow changes
- treat topic as the main subject bucket, not internal schema

## UI Implications

### Memory Viewer

The Memory viewer should stay topic-first.

Primary visible structure:

- project
- topic list
- document body

`documentType` may still exist for filtering, badges, or diagnostics, but it should not dominate the IA.

### Save Review UI

The next minimum UI need is a save review step, not a fully automatic summarizer.

The user should be able to see:

- what Backtick plans to save
- where it plans to save it
- whether it is a new doc or an update
- whether technical noise should be removed first

## Migration Work

### Vocabulary Migration

Planned migration target:

- user-facing `Stack` -> `Prompt`
- old internal `Hot/Warm` references -> `Prompt/Memory`

This should be treated as one naming direction even if implementation lands in slices.

### Existing Memory Cleanup

Existing saved docs and examples that use broad or internal-jargon topics should be corrected over time.

Examples to avoid going forward:

- `warm-memory`
- type-like topics
- architecture-bucket topics that are really several separate subjects

## Next Slices

1. lock `Prompt / Memory` terminology in docs and MCP copy
2. define the exact `propose_document_saves` response shape
3. add proposal/review/confirm behavior to MCP instructions and prompts
4. add a lightweight save-review UI
5. add lint rules that flag noisy or overmixed save proposals
6. clean up existing example docs and eval fixtures to use better topic naming

## Success Criteria

This polish slice is successful when:

- Backtick consistently speaks in `Prompt / Memory`
- users are not asked to understand internal document types
- save behavior is proposal-first instead of silent or direct
- topics feel like real subjects, not internal categories
- saved docs stop accumulating technical/session noise
- future AI sessions can resume work from Memory without reading a transcript
