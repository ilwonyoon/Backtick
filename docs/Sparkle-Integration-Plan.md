# Backtick Sparkle Integration Plan

## Purpose

This document defines the design and rollout plan for adopting `Sparkle` as the direct-download update mechanism for Backtick.

It is intentionally design-only. It does not authorize runtime code changes by itself. The goal is to lock the updater contract before implementation starts so release work can proceed without reopening product, signing, or App Store lane questions.

This plan is written against the current repo baseline on `feat/system-inherit-theme-integration` as of March 13, 2026.

## Baseline

Current repo state already has:

- deterministic direct-lane release verification through `scripts/run_h6_verification.sh`
- signed archive/notarization packaging through `scripts/archive_signed_release.sh`
- release metadata and artifact validation helpers under `scripts/**`
- explicit `Release`, `DevSigned`, and `AppStore` lane planning in `docs/Public-Launch-Hardening-Plan.md`

Current repo state does not yet have:

- a shipped updater framework
- an appcast feed
- Sparkle key management
- release automation that publishes update metadata and update archives
- a direct-lane policy for how update prompts should appear in a quiet `LSUIElement` utility app

## Source Constraints

This design follows two already-locked repo constraints:

- direct download is the primary release lane
- App Store remains a separate compatibility lane and may not depend on `Sparkle`

It also follows the current official Sparkle documentation baseline:

- Sparkle expects a `SUFeedURL`-based appcast feed
- Sparkle publishing expects signed update items and recommends using `generate_appcast`
- EdDSA signing keys are part of the Sparkle publishing contract

## Product Decision

Backtick should adopt `Sparkle` for the direct-download lane only.

The App Store lane must not ship with Sparkle wired in. App Store builds use the App Store update path only.

This means the updater contract is:

- direct lane:
  - `Sparkle`
  - appcast feed over HTTPS
  - notarized and signed update archive
- App Store lane:
  - no Sparkle framework
  - no appcast feed assumptions in runtime
  - updates handled by Apple

## Design Goals

- preserve Backtick's quiet, low-surprise utility behavior
- reuse the existing `H1` release lane instead of inventing a parallel packaging path
- keep storefront choice separate from update delivery
- keep App Store compatibility explicit and non-accidental
- avoid making license checks part of update transport

## Non-Goals

- no Sparkle runtime code in this design phase
- no launch-time updater UI redesign
- no App Store rollout work
- no commerce/provider rewrite
- no delta-update optimization in the first slice unless it falls out of the standard Sparkle toolchain with low risk

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

- expose a minimal `Check for Updates…` action from an existing quiet surface such as the status item menu or Settings
- configure Sparkle only in the direct lane
- keep App Store builds free of updater assumptions
- keep the rest of the app ignorant of appcast details, signing keys, and publishing URLs

Preferred ownership:

- app target owns Sparkle framework integration and menu/Settings wiring
- release scripts own archive generation and appcast publishing inputs
- config files own lane-specific feed URLs and updater enablement

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
  - one explicit `Check for Updates…` action
- prompt style:
  - standard Sparkle updater prompt, no custom in-app chrome in the first slice

Rationale:

- background polling that only checks feed metadata is acceptable
- silent install behavior is higher surprise in a utility app with floating panels
- custom updater UI adds polish scope without helping the release contract

## Config And Lane Policy

The following lane rules should be frozen now:

- `Debug`
  - Sparkle off
- `DevSigned`
  - optional Sparkle smoke only if it helps validate updater wiring, but not a ship lane
- `Release`
  - Sparkle on for the direct lane
- `AppStore`
  - Sparkle off

Config needs when implementation begins:

- one direct-lane feed URL input
- one updater enable/disable lane switch
- no updater dependency in the App Store lane

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
- App Store configuration builds without Sparkle assumptions
- release validation fails clearly if feed URL, Sparkle signing inputs, or appcast generation inputs are missing

Required manual smoke:

- install an older direct build on a clean machine
- receive update prompt from the published appcast
- apply update and verify first launch from the updated app
- repeat with a quarantined manual DMG install

## Rollout Phases

### `SP0`: Design Lock

Deliverables:

- this document
- references from implementation and release docs

Exit criteria:

- direct-lane versus App Store updater policy is no longer ambiguous

### `SP1`: Release-Lane Preparation

Scope:

- decide update-host location
- freeze Sparkle key ownership and secret storage
- freeze update archive format
- freeze release notes source

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

Exit criteria:

- one command path can produce a manual artifact and a Sparkle-ready update payload from the same signed app

### `SP4`: Validation And Launch Readiness

Scope:

- update-from-previous-version smoke
- quarantine smoke
- clean-machine smoke
- App Store lane regression check

Exit criteria:

- updater is no longer a release-time manual hack

## Open Decisions

These are still open and should be resolved before implementation starts:

1. what exact host will serve the appcast and update archive
2. whether the first direct-launch updater should support one channel only or separate stable/beta feeds
3. whether delta updates are accepted in the first implementation or deferred
4. whether `DevSigned` should support updater smoke against a non-production feed
5. whether release notes live in repo, release metadata, or the publishing host

## Risks

- release automation may look complete before update publishing is truly reproducible
- App Store lane drift can reappear if Sparkle assumptions leak into shared runtime code
- utility-app UX can become noisy if updater prompts are over-customized or over-eager
- tying update access to storefront auth too early can overcomplicate a problem Sparkle does not need to solve in v1

## Recommended Next Step

Do not start runtime integration first.

The next implementation step should be `SP1`: freeze host, key ownership, archive format, and release-record fields so the updater contract is release-first rather than UI-first.
