#!/usr/bin/env bash

set -euo pipefail

if [[ "${CONFIGURATION:-}" != "DevSigned" ]]; then
  exit 0
fi

PROJECT_ROOT="${SRCROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOCAL_CONFIG_PATH="${PROJECT_ROOT}/Config/Local.xcconfig"
APP_PATH="${CODESIGNING_FOLDER_PATH:-${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "sign_dev_app: app bundle does not exist: ${APP_PATH}" >&2
  exit 1
fi

SIGNING_REFERENCE="${PROMPTCUE_DEV_SIGNING_SHA1:-}"
SIGNING_LABEL=""

if [[ -z "${SIGNING_REFERENCE}" && -f "${LOCAL_CONFIG_PATH}" ]]; then
  SIGNING_REFERENCE="$(
    awk -F '=' '
      /^[[:space:]]*PROMPTCUE_DEV_SIGNING_SHA1[[:space:]]*=/ {
        value=$2
        gsub(/[[:space:]]/, "", value)
        print value
        exit
      }
    ' "${LOCAL_CONFIG_PATH}"
  )"
fi

if [[ -n "${SIGNING_REFERENCE}" ]]; then
  SIGNING_LABEL="${SIGNING_REFERENCE}"
else
  SIGNING_LABEL="${PROMPTCUE_DEV_SIGNING_IDENTITY:-}"
  SIGNING_REFERENCE="${SIGNING_LABEL}"
fi

if [[ -z "${SIGNING_REFERENCE}" ]]; then
  SIGNING_REFERENCE="$(
    security find-identity -v -p codesigning \
      | awk '/Apple Development:/ && $0 !~ /REVOKED/ { print $2; exit }'
  )"
  SIGNING_LABEL="$(
    security find-identity -v -p codesigning \
      | awk -F '"' '/Apple Development:/ && $0 !~ /REVOKED/ { print $2; exit }'
  )"
fi

if [[ -z "${SIGNING_REFERENCE}" ]]; then
  echo "sign_dev_app: no valid Apple Development signing identity found." >&2
  echo "sign_dev_app: set PROMPTCUE_DEV_SIGNING_SHA1 in Config/Local.xcconfig." >&2
  exit 1
fi

if [[ -z "${SIGNING_LABEL}" ]]; then
  SIGNING_LABEL="${SIGNING_REFERENCE}"
fi

ENTITLEMENTS_PATH="${PROJECT_ROOT}/PromptCue/PromptCue.entitlements"

# Embed provisioning profile if available
PROFILE_PATH=""
for candidate in ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.provisionprofile; do
  if security cms -D -i "$candidate" 2>/dev/null | grep -q "${SIGNING_REFERENCE:-no-match}"; then
    PROFILE_PATH="$candidate"
    break
  fi
done

if [[ -n "${PROFILE_PATH}" ]]; then
  echo "sign_dev_app: embedding provisioning profile"
  cp "${PROFILE_PATH}" "${APP_PATH}/Contents/embedded.provisionprofile"
fi

# Sign inside-out: resource bundles, helper, dylibs, then main app

# Sign resource bundles
for bundle in "${APP_PATH}/Contents/Resources/"*.bundle; do
  if [[ -d "${bundle}" ]]; then
    echo "sign_dev_app: signing bundle $(basename "${bundle}")"
    /usr/bin/codesign --force --sign "${SIGNING_REFERENCE}" --timestamp "${bundle}"
  fi
done

# Sign helper
HELPER_PATH="${APP_PATH}/Contents/Helpers/BacktickMCP"
if [[ -f "${HELPER_PATH}" ]]; then
  echo "sign_dev_app: signing helper"
  /usr/bin/codesign --force --sign "${SIGNING_REFERENCE}" --options runtime --timestamp "${HELPER_PATH}"
fi

# Sign embedded dylibs
for dylib in "${APP_PATH}/Contents/MacOS/"*.dylib; do
  if [[ -f "${dylib}" ]]; then
    echo "sign_dev_app: signing dylib $(basename "${dylib}")"
    /usr/bin/codesign --force --sign "${SIGNING_REFERENCE}" --timestamp "${dylib}"
  fi
done

# Sign main app
echo "sign_dev_app: signing ${APP_PATH} with ${SIGNING_LABEL}"
/usr/bin/codesign --force --sign "${SIGNING_REFERENCE}" --entitlements "${ENTITLEMENTS_PATH}" --options runtime --timestamp "${APP_PATH}"
/usr/bin/codesign --verify --deep --strict "${APP_PATH}"
