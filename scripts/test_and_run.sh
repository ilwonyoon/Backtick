#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUILD_ROOT="${PROMPTCUE_DEV_BUILD_ROOT:-/tmp/PromptCue-dev}"
CONFIGURATION="Debug"
RUN_APP_TESTS=0
SKIP_XCODEGEN=0

print_usage() {
  cat <<'EOF'
Usage: scripts/test_and_run.sh [options]

Run the fast verification path before launching Prompt Cue from the fixed build root.

Default flow:
  1. xcodegen generate
  2. swift test
  3. build and launch via scripts/run_debug_app.sh

Options:
  --configuration NAME   Xcode build configuration to run (default: Debug)
  --build-root PATH      Fixed derived data root to reuse across runs
                         (default: /tmp/PromptCue-dev or $PROMPTCUE_DEV_BUILD_ROOT)
  --app-tests            Also run xcodebuild test before launching
  --skip-xcodegen        Reuse the existing project instead of regenerating it
  --help                 Show this help
EOF
}

fail() {
  echo "test_and_run: $*" >&2
  exit 1
}

run() {
  printf '+'
  for arg in "$@"; do
    printf ' %q' "${arg}"
  done
  printf '\n'
  "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      [[ $# -ge 2 ]] || fail "--configuration requires a value"
      CONFIGURATION="$2"
      shift 2
      ;;
    --build-root)
      [[ $# -ge 2 ]] || fail "--build-root requires a value"
      BUILD_ROOT="$2"
      shift 2
      ;;
    --app-tests)
      RUN_APP_TESTS=1
      shift
      ;;
    --skip-xcodegen)
      SKIP_XCODEGEN=1
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

cd "${PROJECT_ROOT}"

BUILD_ROOT="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "${BUILD_ROOT}")"
SOURCE_PACKAGES_DIR="${BUILD_ROOT}/SourcePackages"

if [[ "${SKIP_XCODEGEN}" -eq 0 ]]; then
  command -v xcodegen >/dev/null 2>&1 || fail "xcodegen is not installed"
  run xcodegen generate
fi

run swift test

if [[ "${RUN_APP_TESTS}" -eq 1 ]]; then
  run \
    xcodebuild \
    -project PromptCue.xcodeproj \
    -scheme PromptCue \
    -derivedDataPath "${BUILD_ROOT}" \
    -clonedSourcePackagesDirPath "${SOURCE_PACKAGES_DIR}" \
    COMPILER_INDEX_STORE_ENABLE=NO \
    CODE_SIGNING_ALLOWED=NO \
    test
fi

RUN_CMD=(
  "${PROJECT_ROOT}/scripts/run_debug_app.sh"
  --build-root "${BUILD_ROOT}"
  --configuration "${CONFIGURATION}"
)

if [[ "${SKIP_XCODEGEN}" -eq 1 ]]; then
  RUN_CMD+=(--skip-xcodegen)
fi

run "${RUN_CMD[@]}"
