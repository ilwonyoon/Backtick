#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PROJECT_PATH="${PROJECT_ROOT}/PromptCue.xcodeproj"
SCHEME="PromptCue"
CONFIGURATION="Debug"
BUILD_ROOT="${PROMPTCUE_DEV_BUILD_ROOT:-/tmp/PromptCue-dev}"
SOURCE_PACKAGES_DIR=""
SKIP_XCODEGEN=0
SKIP_BUILD=0
KILL_RUNNING=1

print_usage() {
  cat <<'EOF'
Usage: scripts/run_debug_app.sh [options]

Build Prompt Cue into a fixed derived data path and launch that exact app bundle.
This keeps local runs reproducible and avoids piling up one app bundle per checkout.

Options:
  --configuration NAME   Xcode build configuration to run (default: Debug)
  --build-root PATH      Fixed derived data root to reuse across runs
                         (default: /tmp/PromptCue-dev or $PROMPTCUE_DEV_BUILD_ROOT)
  --project PATH         Xcode project path (default: PromptCue.xcodeproj in repo root)
  --scheme NAME          Xcode scheme to build (default: PromptCue)
  --skip-xcodegen        Reuse the existing project instead of regenerating it
  --skip-build           Launch the existing built app without rebuilding
  --no-kill              Do not stop running Prompt Cue processes before launch
  --help                 Show this help
EOF
}

fail() {
  echo "run_debug_app: $*" >&2
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

wait_for_launch() {
  local app_executable="$1/Contents/MacOS/Prompt Cue"
  local pid=""

  for _ in $(seq 1 20); do
    pid="$(
      ps -axo pid=,args= \
        | awk -v target="${app_executable}" 'index($0, target) { print $1; exit }'
    )"
    if [[ -n "${pid}" ]]; then
      printf '%s\n' "${pid}"
      return 0
    fi
    sleep 0.25
  done

  fail "launched app process was not detected: ${app_executable}"
}

kill_running_apps() {
  pkill -f '/Prompt Cue.app/Contents/MacOS/Prompt Cue' >/dev/null 2>&1 || true

  for _ in $(seq 1 20); do
    if ! pgrep -f '/Prompt Cue.app/Contents/MacOS/Prompt Cue' >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done

  fail "running Prompt Cue processes did not exit"
}

build_requires_unsigned_code_signing() {
  case "$1" in
    Debug|Release)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
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
    --project)
      [[ $# -ge 2 ]] || fail "--project requires a value"
      PROJECT_PATH="$2"
      shift 2
      ;;
    --scheme)
      [[ $# -ge 2 ]] || fail "--scheme requires a value"
      SCHEME="$2"
      shift 2
      ;;
    --skip-xcodegen)
      SKIP_XCODEGEN=1
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --no-kill)
      KILL_RUNNING=0
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

PROJECT_PATH="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "${PROJECT_PATH}")"
BUILD_ROOT="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "${BUILD_ROOT}")"
SOURCE_PACKAGES_DIR="${BUILD_ROOT}/SourcePackages"
APP_PATH="${BUILD_ROOT}/Build/Products/${CONFIGURATION}/Prompt Cue.app"

[[ -e "${PROJECT_PATH}" ]] || fail "project path does not exist: ${PROJECT_PATH}"

if [[ "${SKIP_XCODEGEN}" -eq 0 ]]; then
  command -v xcodegen >/dev/null 2>&1 || fail "xcodegen is not installed"
  run xcodegen generate
fi

if [[ "${KILL_RUNNING}" -eq 1 ]]; then
  # Kill old Prompt Cue processes first so Launch Services cannot reactivate a stale bundle.
  kill_running_apps
fi

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  mkdir -p "${BUILD_ROOT}"

  XCODEBUILD_CMD=(
    xcodebuild
    -project "${PROJECT_PATH}"
    -scheme "${SCHEME}"
    -configuration "${CONFIGURATION}"
    -derivedDataPath "${BUILD_ROOT}"
    -clonedSourcePackagesDirPath "${SOURCE_PACKAGES_DIR}"
    COMPILER_INDEX_STORE_ENABLE=NO
    build
  )

  if build_requires_unsigned_code_signing "${CONFIGURATION}"; then
    XCODEBUILD_CMD+=(CODE_SIGNING_ALLOWED=NO)
  fi

  run "${XCODEBUILD_CMD[@]}"
fi

[[ -d "${APP_PATH}" ]] || fail "app bundle is missing: ${APP_PATH}"

run open -na "${APP_PATH}"

APP_PID="$(wait_for_launch "${APP_PATH}")"

echo "Launched: ${APP_PATH} (pid: ${APP_PID})"
