# Backtick DMG Launch Checklist

## Purpose

This is the operator checklist for shipping a direct-download DMG launch candidate for `Backtick`.

Use this only after the intended ship changes are already merged and the branch is frozen. This checklist is the release-execution layer on top of:

- `docs/Engineering-Preflight.md`
- `docs/Public-Launch-Hardening-Plan.md`
- `scripts/run_h6_verification.sh`
- `scripts/archive_signed_release.sh`

## Release Owner Preconditions

- [ ] ship from `main`, not a long-lived feature branch
- [ ] git worktree is clean
- [ ] marketing version and build number are final
- [ ] `Config/Local.xcconfig` has valid release credentials:
  - `PROMPTCUE_RELEASE_SIGNING_SHA1` or `PROMPTCUE_RELEASE_SIGNING_IDENTITY`
  - `PROMPTCUE_RELEASE_TEAM_ID`
  - `PROMPTCUE_RELEASE_NOTARY_PROFILE`
- [ ] `security find-identity -v -p codesigning` shows a valid `Developer ID Application` identity
- [ ] release owner has decided the artifact name and DMG volume name if the defaults should be overridden

## Ship-Candidate Freeze

- [ ] confirm no last-minute product copy, entitlement, or signing changes are still pending
- [ ] confirm known launch blockers are either fixed or consciously deferred
- [ ] confirm the current release scope does not depend on Sparkle, MAS-only behavior, or ChatGPT mobile verification

## Preflight Gate

Run these before producing the final DMG:

```bash
xcodegen generate
swift test
xcodebuild -project PromptCue.xcodeproj -scheme PromptCue -configuration Debug CODE_SIGNING_ALLOWED=NO build
scripts/run_h6_verification.sh --require-signed
```

- [ ] all four commands pass
- [ ] `scripts/run_h6_verification.sh --require-signed` completes without credential fallback or manual patching
- [ ] helper smoke passes from a temp directory with no source checkout dependency

## Build The DMG

Preferred command:

```bash
scripts/archive_signed_release.sh \
  --package-format dmg \
  --output-root build/signed-release
```

Optional overrides:

```bash
scripts/archive_signed_release.sh \
  --package-format dmg \
  --artifact-basename Backtick \
  --volume-name Backtick \
  --output-root build/signed-release
```

- [ ] archive step succeeds
- [ ] notarization returns `Accepted`
- [ ] stapling succeeds
- [ ] Gatekeeper assessment succeeds
- [ ] final DMG exists under `build/signed-release/`

## Required Artifacts

Confirm these files exist in `build/signed-release/`:

- [ ] final `.dmg`
- [ ] `.sha256.txt`
- [ ] `release-metadata.json`
- [ ] `release-validation.txt`
- [ ] `notary-log.json`
- [ ] `gatekeeper.log`
- [ ] exported `.app`
- [ ] `.xcarchive`

## Artifact Inspection

- [ ] `codesign --verify --deep --strict --verbose=4 <AppPath>` passes
- [ ] `codesign --verify --strict --verbose=4 <HelperPath>` passes
- [ ] `spctl --assess --type execute --verbose=4 <AppPath>` passes
- [ ] `xcrun stapler validate <AppPath>` passes
- [ ] `file <HelperPath>` matches the intended architecture policy
- [ ] `lipo -info <HelperPath>` matches the intended architecture policy
- [ ] `shasum -a 256 <DMGPath>` matches the generated checksum file
- [ ] `release-metadata.json` records the expected version, build, git SHA, and notarization result

Helper path:

```text
Prompt Cue.app/Contents/Helpers/BacktickMCP
```

## Manual DMG Smoke

Run these from the produced DMG, not from a local Debug build:

- [ ] mount the final DMG
- [ ] copy the app to `/Applications` or a clean temp install location
- [ ] launch the quarantined app copy for the first time
- [ ] confirm there is no unidentified-developer, damaged-app, or missing-helper failure
- [ ] confirm the app opens as an `LSUIElement` utility instead of a normal dock-first app
- [ ] confirm the bundled helper runs from the installed app:

```bash
env -i HOME="$HOME" PATH="$PATH" TMPDIR="${TMPDIR:-/tmp}" LANG=C LC_ALL=C \
  "/Applications/Prompt Cue.app/Contents/Helpers/BacktickMCP" --help
```

## Product Smoke

Minimum user-facing smoke on the installed DMG build:

- [ ] quick capture opens
- [ ] stack panel opens
- [ ] capture save works
- [ ] clipboard copy works
- [ ] screenshot-folder connect state is understandable
- [ ] MCP Settings loads without crashing
- [ ] at least one shipped stdio connector shows the expected `Configured` or `Connected` state

These are not launch blockers for the DMG unless explicitly re-opened:

- ChatGPT iPhone/iPad custom MCP
- Sparkle/updater integration
- Mac App Store lane behavior

## Gumroad Upload Packet

- [ ] upload the final DMG, not an intermediate zip or unsigned export
- [ ] record the SHA-256 alongside the upload
- [ ] attach version/build/git SHA from `release-metadata.json`
- [ ] prepare short release notes from the actual merged scope
- [ ] keep rollback access to the previous shipped DMG

## Launch Decision

Ship only if all of these are true:

- [ ] automated preflight is green
- [ ] signed DMG lane is green
- [ ] manual DMG smoke is green
- [ ] product smoke is green
- [ ] artifact metadata and checksum are recorded
- [ ] Gumroad upload packet is ready

If any blocking item fails, stop and fix the release lane or product regression first. Do not hand-edit the artifact after notarization just to get a DMG out.
