# Backtick Sparkle Integration Plan

## Purpose

This document defines the design and rollout plan for adopting `Sparkle` as the direct-download update mechanism for Backtick.

It is intentionally design-only. It does not authorize runtime code changes by itself. The goal is to lock the updater contract before implementation starts so release work can proceed without reopening product, signing, or distribution-lane questions.

This plan is updated against the merged direct-download release lane and MCP helper baseline as of April 6, 2026.

## Baseline

Current repo state already has:

- deterministic direct-lane release verification through `scripts/run_h6_verification.sh`
- signed archive/notarization packaging through `scripts/archive_signed_release.sh`
- release metadata and artifact validation helpers under `scripts/**`
- explicit `Release` and `DevSigned` lane planning in `docs/Public-Launch-Hardening-Plan.md`
- GitHub Release based manual distribution with versioned DMG artifacts
- a bundled `BacktickMCP` helper that now ships inside release builds
- MCP surface/version observability through `backtick_status`

Current repo state does not yet have:

- a shipped updater framework
- an appcast feed
- Sparkle key management
- release automation that publishes update metadata and update archives
- a direct-lane policy for how update prompts should appear in a quiet `LSUIElement` utility app
- a post-update contract for telling MCP clients when they need a fresh session

## Source Constraints

This design follows two already-locked repo constraints:

- direct download is the primary release lane
- Mac App Store distribution is not part of the intended shipping plan

It also follows the current official Sparkle documentation baseline:

- Sparkle expects a `SUFeedURL`-based appcast feed
- Sparkle publishing expects signed update items and recommends using `generate_appcast`
- EdDSA signing keys are part of the Sparkle publishing contract

## Product Decision

Backtick should adopt `Sparkle` for the direct-download lane.

Backtick is being optimized for direct distribution, not Mac App Store release. The updater contract should therefore optimize for the direct-download lane instead of preserving dormant App Store separation work.

For the first implementation, Backtick should keep a single app target and gate updater behavior by build configuration instead of introducing a target split only for updater wiring.

This means the updater contract is:

- direct lane:
  - `Sparkle`
  - appcast feed over HTTPS
  - notarized and signed update archive

## Design Goals

- preserve Backtick's quiet, low-surprise utility behavior
- reuse the existing `H1` release lane instead of inventing a parallel packaging path
- keep storefront choice separate from update delivery
- avoid making license checks part of update transport
- minimize runtime and maintenance overhead
- keep update ownership concentrated behind one app-owned seam
- update the bundled `BacktickMCP` helper atomically with the app

## Non-Goals

- no Sparkle runtime code in this design phase
- no launch-time updater UI redesign
- no commerce/provider rewrite
- no delta-update optimization in the first slice unless it falls out of the standard Sparkle toolchain with low risk
- no custom update preferences pane in the first slice
- no attempt to hot-reload already-running MCP client sessions
- no Mac App Store compatibility work in this updater lane

## Architecture

### Direct-Download Update Model

The direct-download release lane should publish two end-user artifacts:

- a storefront-friendly primary download artifact
  - existing direction remains versioned `DMG`
- a Sparkle update artifact
  - preferred as a notarized update archive generated from the same signed app payload used by the release lane

The app should not treat the storefront download artifact and the updater artifact as the same operational concern.

- storefront artifact:
  - what a new customer downloads manually
- updater artifact:
  - what existing installs consume through Sparkle

This keeps the updater independent from whether the commerce layer remains Gumroad, moves to Lemon Squeezy, or changes later.

### Runtime Boundary

When implementation begins, Sparkle wiring should sit behind one app-owned update boundary in the app target.

Expected responsibilities:

- expose a minimal `Check for Updates…` action from the status item menu
- configure Sparkle only in the direct lane
- keep the rest of the app ignorant of appcast details, signing keys, and publishing URLs
- keep Settings free of a large updater surface in the first slice

Preferred ownership:

- app target owns Sparkle framework integration and menu wiring
- release scripts own archive generation and appcast publishing inputs
- config files own feed URLs and updater enablement

Concrete first-slice boundary:

- add one `UpdateCoordinator` service in `PromptCue/Services/**`
- have `AppCoordinator` own the status-item menu action only
- do not spread Sparkle types through unrelated view or settings code

### MCP Helper Update Contract

Backtick's updater contract is not app-only. The bundled `BacktickMCP` helper is part of the shipped surface and must move in lockstep with the app.

This means:

- the Sparkle update artifact must be produced from the same signed app payload that already contains the release helper
- app updates and helper updates are atomic from the user's point of view
- post-update verification must continue to prove that the shipped helper exposes the expected tool surface
- the app should offer lightweight post-update guidance that existing Claude Code / Codex sessions may need a fresh session to pick up the new Backtick MCP surface

This deliberately does not attempt impossible runtime guarantees:

- Sparkle should not try to hot-reload already-running third-party MCP sessions
- the product should instead make surface freshness observable through `backtick_status`

### Feed And Signing Contract

The update feed contract should be frozen before implementation:

- transport:
  - static HTTPS hosting
- feed:
  - one canonical appcast URL per direct-release channel
- signing:
  - Sparkle EdDSA private key stays off-repo
  - public verification material is embedded only where Sparkle requires it
- versioning:
  - appcast items map to the same marketing version and build number used by the signed release lane

Preferred first-slice publishing contract:

- appcast:
  - static XML hosted on GitHub Pages
- update archive:
  - GitHub Release asset generated from the signed release payload
- release notes:
  - GitHub Release notes linked from the appcast item
- channels:
  - one stable direct-download feed only in v1

## Release Flow

Sparkle should extend the current `H1` release lane, not replace it.

Target flow:

1. generate project deterministically
2. build and archive the `Release` lane
3. sign, notarize, and staple the app as today
4. export the signed app into the deterministic release folder
5. create the manual-download artifact
6. create the Sparkle update archive from the same signed app payload
7. generate or update the appcast with Sparkle tooling
8. publish appcast, release notes, and update archive to the updater host
9. run Sparkle-aware release validation in addition to existing `H6` checks

Operational detail for the first slice:

- keep the existing versioned DMG as the storefront/manual install artifact
- derive the Sparkle update archive from `EXPORTED_APP_PATH` after notarization and stapling
- upload both artifacts in the same GitHub release
- record appcast URL, update archive URL, and Sparkle-related signature data in `release-metadata.json`

This preserves one release truth:

- one signed app payload
- multiple distribution surfaces derived from it

## UX Policy

Backtick is a background utility app. The updater policy should stay conservative.

Default UX policy for first implementation:

- automatic update checks:
  - yes
- silent automatic install:
  - no
- user-visible surface:
  - one explicit `Check for Updates…` action in the status item menu
- prompt style:
  - standard Sparkle updater prompt, no custom in-app chrome in the first slice

Rationale:

- background polling that only checks feed metadata is acceptable
- silent install behavior is higher surprise in a utility app with floating panels
- custom updater UI adds polish scope without helping the release contract
- keeping the trigger in the status item matches Backtick's `LSUIElement` utility shape better than growing a dedicated updater settings surface

## Config And Lane Policy

The following lane rules should be frozen now:

- `Debug`
  - Sparkle off
- `DevSigned`
  - Sparkle off by default in v1
- `Release`
  - Sparkle on for the direct lane

Config needs when implementation begins:

- one direct-lane feed URL input
- one updater enable/disable lane switch

Implementation policy for the first slice:

- keep one app target
- allow Sparkle integration to exist behind compile/runtime gating for direct-distribution lanes
- do not spend implementation effort preserving a dormant App Store updater lane

## Verification

Sparkle-specific verification should be added on top of existing `H6`, not instead of it.

Required verification for implementation:

- appcast generation succeeds from the signed release artifact
- the published update archive matches the signed and notarized app payload
- a clean older direct build discovers the new update through Sparkle
- applying the update preserves:
  - local database
  - screenshot bookmark state
  - settings
- release validation fails clearly if feed URL, Sparkle signing inputs, or appcast generation inputs are missing
- the updated app still ships a working `BacktickMCP` helper with the expected surface
- `backtick_status` on the updated helper reports the expected app build and MCP surface version

Required manual smoke:

- install an older direct build on a clean machine
- receive update prompt from the published appcast
- apply update and verify first launch from the updated app
- repeat with a quarantined manual DMG install
- verify a previously connected MCP client can see the new helper surface after starting a fresh session

## Rollout Phases

### `SP0`: Design Lock

Deliverables:

- this document
- references from implementation and release docs

Exit criteria:

- direct-lane versus App Store updater policy is no longer ambiguous

### `SP1`: Release-Lane Preparation

Scope:

- freeze GitHub Release assets as the update archive source
- freeze GitHub Pages as the appcast host
- freeze Sparkle key ownership and secret storage
- freeze update archive format
- freeze GitHub Release notes as the first release-notes source

Exit criteria:

- release lane has a clear post-notarization handoff into Sparkle publishing

### `SP2`: Runtime Integration

Scope:

- add Sparkle dependency in the direct lane
- add one update coordinator boundary
- add one user-visible `Check for Updates…` action

Exit criteria:

- direct build can discover a published update from the appcast

### `SP3`: Release Automation

Scope:

- create Sparkle archive and appcast in release automation
- record published update metadata in the release record
- verify the shipped helper surface from the signed update payload

Exit criteria:

- one command path can produce a manual artifact and a Sparkle-ready update payload from the same signed app

### `SP4`: Validation And Launch Readiness

Scope:

- update-from-previous-version smoke
- quarantine smoke
- clean-machine smoke

Exit criteria:

- updater is no longer a release-time manual hack

## Open Decisions

None for the first implementation slice. The contract is:

1. appcast XML is hosted on GitHub Pages
2. `DevSigned` does not use a separate non-production feed in v1
3. Mac App Store separation is out of scope because direct distribution is the intended shipping path

## Risks

- release automation may look complete before update publishing is truly reproducible
- utility-app UX can become noisy if updater prompts are over-customized or over-eager
- tying update access to storefront auth too early can overcomplicate a problem Sparkle does not need to solve in v1
- MCP users may think the updater failed if their existing client session keeps an older tool surface until they start a new session

## Recommended Next Step

Do not start runtime integration first.

The next implementation step should be `SP1`: freeze the static appcast host, Sparkle key ownership, archive format, MCP helper verification contract, and release-record fields so the updater contract is release-first rather than UI-first.
