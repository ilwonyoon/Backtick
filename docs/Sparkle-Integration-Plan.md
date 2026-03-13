# Sparkle Integration Plan

## Goal

Integrate Sparkle as a direct-download updater path for Backtick while keeping the App Store lane updater-disabled.

## Lane Contract

- `Release` (direct-download): Sparkle lane is enabled.
- `AppStore` (MAS compatibility): Sparkle lane is disabled.
- Runtime updater starts only when all required keys are present:
  - `BacktickEnableSparkleUpdates = true`
  - `SUFeedURL` is non-empty
  - `SUPublicEDKey` is non-empty

## H1/H6 Script Reuse Contract

- Reuse `scripts/archive_release_validation.sh` as the unsigned direct-lane shape validator.
  - Inject Sparkle build settings with deterministic defaults.
  - Validate Sparkle keys are present in the archived app metadata.
- Reuse `scripts/archive_signed_release.sh` as the signed/notarized direct lane.
  - Source Sparkle appcast URL + public key from `Config/Local.xcconfig` (or explicit flags).
  - Fail fast when Sparkle release config is missing.
- Keep `scripts/run_h6_verification.sh` flow intact by relying on the existing call to `archive_release_validation.sh`.

## Implementation Start Scope

1. Wire Sparkle package dependency and Info.plist keys via `project.yml`.
2. Add app runtime `SparkleUpdateController` and expose `Check for Updates…` only when Sparkle is configured.
3. Extend release scripts and metadata:
   - `archive_release_validation.sh`
   - `archive_signed_release.sh`
   - `validate_release_artifact.sh`
   - `write_release_metadata.sh`
4. Keep App Store lane explicitly updater-disabled in build config.
