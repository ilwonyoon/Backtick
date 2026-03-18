#!/usr/bin/env bash

set -euo pipefail

export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

HELPER_PATH=""
HOST="127.0.0.1"
PORT="8944"
PUBLIC_BASE_URL="https://backtick.test"
OUTPUT_ROOT="${PROJECT_ROOT}/build/chatgpt-mcp-stress"
KEEP_ARTIFACTS=0
TIMEOUT_SECONDS=15
REFRESH_CYCLES=5
ACCESS_TOKEN_TTL=""

RUN_DIR=""
SERVER_PID=""
RESPONSE_BODY=""
RESPONSE_STATUS=""
RESPONSE_HEADERS=""

usage() {
  cat <<'EOF'
Usage: scripts/run_chatgpt_mcp_stress.sh --helper-path <path> [options]

Run a deterministic local stress lane for Backtick's experimental ChatGPT OAuth MCP helper.
This covers:
  - OAuth discovery metadata
  - dynamic client registration
  - authorization code issue + exchange
  - protected /mcp call with bearer token
  - missing bearer rejection
  - authorization code reuse rejection
  - invalid refresh token rejection
  - helper restart with persisted OAuth state
  - refresh token reuse after helper restart

Options:
  --helper-path PATH      Path to the BacktickMCP helper binary
  --host HOST             HTTP host to bind (default: 127.0.0.1)
  --port PORT             HTTP port to bind (default: 8944)
  --public-base-url URL   Public HTTPS base URL advertised in OAuth metadata
                          (default: https://backtick.test)
  --output-root PATH      Root folder for logs and temporary artifacts
                          (default: build/chatgpt-mcp-stress)
  --keep-artifacts        Keep temp DB/state/logs after the script exits
  --timeout SECONDS       Seconds to wait for helper startup (default: 15)
  --refresh-cycles COUNT Number of repeated refresh + /mcp validation cycles
                          to run after the first restart check (default: 5)
  --access-token-ttl SEC  Override OAuth access token lifetime in seconds for
                          deterministic expiry testing
  --help                  Show this message
EOF
}

fail() {
  echo "run_chatgpt_mcp_stress: $*" >&2
  exit 1
}

json_get() {
  local body="$1"
  local path="$2"

  BODY="${body}" python3 - "$path" <<'PY'
import json
import os
import sys

path = [part for part in sys.argv[1].split(".") if part]
data = json.loads(os.environ["BODY"])
current = data
for part in path:
    if isinstance(current, list):
        current = current[int(part)]
    else:
        current = current[part]

if isinstance(current, (dict, list)):
    print(json.dumps(current, separators=(",", ":")))
elif current is None:
    print("")
else:
    print(current)
PY
}

url_query_value() {
  local url="$1"
  local key="$2"

  URL_VALUE="${url}" python3 - "$key" <<'PY'
import os
import sys
import urllib.parse

url = os.environ["URL_VALUE"]
key = sys.argv[1]
query = urllib.parse.urlparse(url).query
values = urllib.parse.parse_qs(query).get(key, [])
print(values[0] if values else "")
PY
}

http_request() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local content_type="${4:-}"
  local authorization="${5:-}"

  local response=""
  local -a curl_args=(-sS -X "${method}" "${url}" -w $'\nHTTPSTATUS:%{http_code}')

  if [[ -n "${content_type}" ]]; then
    curl_args+=(-H "Content-Type: ${content_type}")
  fi
  if [[ -n "${authorization}" ]]; then
    curl_args+=(-H "Authorization: ${authorization}")
  fi
  if [[ -n "${body}" ]]; then
    curl_args+=(--data "${body}")
  fi

  if ! response="$(curl "${curl_args[@]}")"; then
    RESPONSE_STATUS=""
    RESPONSE_BODY=""
    return 1
  fi
  RESPONSE_STATUS="${response##*$'\n'HTTPSTATUS:}"
  RESPONSE_BODY="${response%$'\n'HTTPSTATUS:*}"
}

http_request_headers() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local content_type="${4:-}"

  local -a curl_args=(-sS -o /dev/null -D - -X "${method}" "${url}")

  if [[ -n "${content_type}" ]]; then
    curl_args+=(-H "Content-Type: ${content_type}")
  fi
  if [[ -n "${body}" ]]; then
    curl_args+=(--data "${body}")
  fi

  if ! RESPONSE_HEADERS="$(curl "${curl_args[@]}")"; then
    RESPONSE_HEADERS=""
    RESPONSE_STATUS=""
    return 1
  fi
  RESPONSE_STATUS="$(
    printf '%s' "${RESPONSE_HEADERS}" \
      | awk 'toupper($1) ~ /^HTTP/ { print $2; exit }'
  )"
}

assert_status() {
  local expected="$1"
  local context="$2"

  if [[ "${RESPONSE_STATUS}" != "${expected}" ]]; then
    printf 'run_chatgpt_mcp_stress: %s failed, expected %s got %s\n' "${context}" "${expected}" "${RESPONSE_STATUS}" >&2
    if [[ -n "${RESPONSE_BODY}" ]]; then
      printf 'response body: %s\n' "${RESPONSE_BODY}" >&2
    fi
    if [[ -n "${RESPONSE_HEADERS}" ]]; then
      printf 'response headers:\n%s\n' "${RESPONSE_HEADERS}" >&2
    fi
    exit 1
  fi
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local context="$3"

  if [[ "${expected}" != "${actual}" ]]; then
    fail "${context}: expected '${expected}', got '${actual}'"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local context="$3"

  if [[ "${haystack}" != *"${needle}"* ]]; then
    fail "${context}: expected to find '${needle}'"
  fi
}

cleanup() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" >/dev/null 2>&1 || true
  fi

  if [[ ${KEEP_ARTIFACTS} -ne 1 && -n "${RUN_DIR}" && -d "${RUN_DIR}" ]]; then
    rm -rf "${RUN_DIR}"
  fi
}

trap cleanup EXIT

start_helper() {
  local db_path="$1"
  local attachments_path="$2"
  local oauth_state_path="$3"
  local stdout_log="$4"
  local stderr_log="$5"
  local -a helper_args=(
    --transport http
    --host "${HOST}"
    --port "${PORT}"
    --auth-mode oauth
    --public-base-url "${PUBLIC_BASE_URL}"
    --oauth-state-path "${oauth_state_path}"
    --database-path "${db_path}"
    --attachments-path "${attachments_path}"
  )

  mkdir -p "$(dirname "${oauth_state_path}")"

  if [[ -n "${ACCESS_TOKEN_TTL}" ]]; then
    helper_args+=(--access-token-ttl "${ACCESS_TOKEN_TTL}")
  fi

  "${HELPER_PATH}" "${helper_args[@]}" >"${stdout_log}" 2>"${stderr_log}" &

  SERVER_PID=$!
}

wait_for_health() {
  local deadline=$((SECONDS + TIMEOUT_SECONDS))
  local url="http://${HOST}:${PORT}/health"

  while (( SECONDS < deadline )); do
    if curl -sS -o /dev/null "${url}" 2>/dev/null; then
      http_request GET "${url}"
      if [[ "${RESPONSE_STATUS}" == "200" ]]; then
        return 0
      fi
    fi
    sleep 1
  done

  fail "helper did not become healthy within ${TIMEOUT_SECONDS}s"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --helper-path)
      [[ $# -ge 2 ]] || fail "--helper-path requires a value"
      HELPER_PATH="$2"
      shift 2
      ;;
    --host)
      [[ $# -ge 2 ]] || fail "--host requires a value"
      HOST="$2"
      shift 2
      ;;
    --port)
      [[ $# -ge 2 ]] || fail "--port requires a value"
      PORT="$2"
      shift 2
      ;;
    --public-base-url)
      [[ $# -ge 2 ]] || fail "--public-base-url requires a value"
      PUBLIC_BASE_URL="$2"
      shift 2
      ;;
    --output-root)
      [[ $# -ge 2 ]] || fail "--output-root requires a value"
      OUTPUT_ROOT="$2"
      shift 2
      ;;
    --keep-artifacts)
      KEEP_ARTIFACTS=1
      shift
      ;;
    --timeout)
      [[ $# -ge 2 ]] || fail "--timeout requires a value"
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --refresh-cycles)
      [[ $# -ge 2 ]] || fail "--refresh-cycles requires a value"
      REFRESH_CYCLES="$2"
      shift 2
      ;;
    --access-token-ttl)
      [[ $# -ge 2 ]] || fail "--access-token-ttl requires a value"
      ACCESS_TOKEN_TTL="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument '$1'"
      ;;
  esac
done

[[ -n "${HELPER_PATH}" ]] || {
  usage >&2
  exit 1
}
[[ -x "${HELPER_PATH}" ]] || fail "helper is not executable: ${HELPER_PATH}"
[[ "${PUBLIC_BASE_URL}" == https://* ]] || fail "--public-base-url must be HTTPS"
[[ "${REFRESH_CYCLES}" =~ ^[0-9]+$ ]] || fail "--refresh-cycles must be numeric"
if [[ -n "${ACCESS_TOKEN_TTL}" ]]; then
  [[ "${ACCESS_TOKEN_TTL}" =~ ^[0-9]+([.][0-9]+)?$ ]] || fail "--access-token-ttl must be numeric"
fi

HELP_OUTPUT="$("${HELPER_PATH}" --help 2>&1 || true)"
assert_contains "${HELP_OUTPUT}" "--oauth-state-path" "helper support for isolated OAuth state overrides"

timestamp="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="${OUTPUT_ROOT}/${timestamp}"
mkdir -p "${RUN_DIR}"

DB_PATH="${RUN_DIR}/PromptCue.sqlite"
ATTACHMENTS_PATH="${RUN_DIR}/Attachments"
mkdir -p "${ATTACHMENTS_PATH}"
OAUTH_STATE_PATH="${RUN_DIR}/oauth-state.json"
STDOUT_LOG="${RUN_DIR}/helper.stdout.log"
STDERR_LOG="${RUN_DIR}/helper.stderr.log"

BASE_URL="http://${HOST}:${PORT}"
CODE_CHALLENGE="C4o_XQvR65ONsuHQv0djlsMDYgPVB63jJiXd_a4GETw"
CODE_VERIFIER="backtick-verifier"
REDIRECT_URI="https://chat.openai.com/aip/callback"

echo "run_chatgpt_mcp_stress: run_dir=${RUN_DIR}"
echo "run_chatgpt_mcp_stress: helper=${HELPER_PATH}"
echo "run_chatgpt_mcp_stress: base_url=${BASE_URL}"
echo "run_chatgpt_mcp_stress: public_base_url=${PUBLIC_BASE_URL}"
echo "run_chatgpt_mcp_stress: refresh_cycles=${REFRESH_CYCLES}"
echo "run_chatgpt_mcp_stress: access_token_ttl=${ACCESS_TOKEN_TTL:-default}"

start_helper "${DB_PATH}" "${ATTACHMENTS_PATH}" "${OAUTH_STATE_PATH}" "${STDOUT_LOG}" "${STDERR_LOG}"
wait_for_health

http_request GET "${BASE_URL}/.well-known/oauth-protected-resource"
assert_status "200" "protected resource metadata"
assert_equals "${PUBLIC_BASE_URL}" "$(json_get "${RESPONSE_BODY}" authorization_servers.0)" "authorization server metadata URL"
assert_contains "$(json_get "${RESPONSE_BODY}" scopes_supported)" "offline_access" "protected resource scopes"

http_request GET "${BASE_URL}/.well-known/openid-configuration"
assert_status "200" "openid configuration"
assert_equals "${PUBLIC_BASE_URL}" "$(json_get "${RESPONSE_BODY}" issuer)" "openid issuer"
assert_equals "${PUBLIC_BASE_URL}/oauth/token" "$(json_get "${RESPONSE_BODY}" token_endpoint)" "openid token endpoint"

REGISTRATION_BODY='{"client_name":"ChatGPT","redirect_uris":["https://chat.openai.com/aip/callback"],"token_endpoint_auth_method":"none"}'
http_request POST "${BASE_URL}/oauth/register" "${REGISTRATION_BODY}" "application/json"
assert_status "201" "dynamic client registration"
CLIENT_ID="$(json_get "${RESPONSE_BODY}" client_id)"
[[ -n "${CLIENT_ID}" ]] || fail "client registration did not return client_id"

AUTH_PATH="/oauth/authorize?client_id=${CLIENT_ID}&redirect_uri=https%3A%2F%2Fchat.openai.com%2Faip%2Fcallback&response_type=code&scope=backtick.mcp&state=stress123&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256"
http_request GET "${BASE_URL}${AUTH_PATH}"
assert_status "200" "authorization page"
assert_contains "${RESPONSE_BODY}" "Allow ChatGPT to use Backtick?" "authorization page title"

AUTHORIZE_FORM="client_id=${CLIENT_ID}&redirect_uri=https%3A%2F%2Fchat.openai.com%2Faip%2Fcallback&response_type=code&scope=backtick.mcp&state=stress123&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256&decision=approve"
http_request_headers POST "${BASE_URL}/oauth/authorize" "${AUTHORIZE_FORM}" "application/x-www-form-urlencoded"
assert_status "302" "authorization approval"
REDIRECT_LOCATION="$(
  printf '%s' "${RESPONSE_HEADERS}" \
    | awk 'tolower($1) == "location:" { sub(/\r$/, "", $2); print $2; exit }'
)"
[[ -n "${REDIRECT_LOCATION}" ]] || fail "authorization approval did not return a redirect location"
AUTHORIZATION_CODE="$(url_query_value "${REDIRECT_LOCATION}" "code")"
[[ -n "${AUTHORIZATION_CODE}" ]] || fail "redirect location did not include an authorization code"

TOKEN_FORM="grant_type=authorization_code&code=${AUTHORIZATION_CODE}&client_id=${CLIENT_ID}&redirect_uri=https%3A%2F%2Fchat.openai.com%2Faip%2Fcallback&code_verifier=${CODE_VERIFIER}"
http_request POST "${BASE_URL}/oauth/token" "${TOKEN_FORM}" "application/x-www-form-urlencoded"
assert_status "200" "authorization code exchange"
ACCESS_TOKEN="$(json_get "${RESPONSE_BODY}" access_token)"
REFRESH_TOKEN="$(json_get "${RESPONSE_BODY}" refresh_token)"
[[ -n "${ACCESS_TOKEN}" ]] || fail "token exchange did not return an access token"
[[ -n "${REFRESH_TOKEN}" ]] || fail "token exchange did not return a refresh token"

MCP_INITIALIZE_BODY='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"stress-script","version":"0.1.0"}}}'
http_request POST "${BASE_URL}/mcp" "${MCP_INITIALIZE_BODY}" "application/json"
assert_status "401" "protected MCP endpoint without bearer token"

http_request POST "${BASE_URL}/mcp" "${MCP_INITIALIZE_BODY}" "application/json" "Bearer ${ACCESS_TOKEN}"
assert_status "200" "protected MCP endpoint with bearer token"

if [[ -n "${ACCESS_TOKEN_TTL}" ]]; then
  python3 - "${ACCESS_TOKEN_TTL}" <<'PY'
import sys
import time

time.sleep(float(sys.argv[1]) + 0.2)
PY

  http_request POST "${BASE_URL}/mcp" "${MCP_INITIALIZE_BODY}" "application/json" "Bearer ${ACCESS_TOKEN}"
  assert_status "401" "expired access token rejection"
fi

http_request POST "${BASE_URL}/oauth/token" "${TOKEN_FORM}" "application/x-www-form-urlencoded"
assert_status "400" "authorization code reuse rejection"
assert_equals "invalid_grant" "$(json_get "${RESPONSE_BODY}" error)" "authorization code reuse error code"

INVALID_REFRESH_FORM="grant_type=refresh_token&refresh_token=stale-refresh-token&client_id=${CLIENT_ID}"
http_request POST "${BASE_URL}/oauth/token" "${INVALID_REFRESH_FORM}" "application/x-www-form-urlencoded"
assert_status "400" "invalid refresh token rejection"
assert_equals "invalid_grant" "$(json_get "${RESPONSE_BODY}" error)" "invalid refresh token error code"

REFRESH_FORM="grant_type=refresh_token&refresh_token=${REFRESH_TOKEN}&client_id=${CLIENT_ID}"
http_request POST "${BASE_URL}/oauth/token" "${REFRESH_FORM}" "application/x-www-form-urlencoded"
assert_status "200" "refresh token exchange"
REFRESHED_ACCESS_TOKEN="$(json_get "${RESPONSE_BODY}" access_token)"
assert_equals "${REFRESH_TOKEN}" "$(json_get "${RESPONSE_BODY}" refresh_token)" "refresh token should remain stable"
[[ -n "${REFRESHED_ACCESS_TOKEN}" ]] || fail "refresh token exchange did not return a new access token"

if kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
  kill "${SERVER_PID}" >/dev/null 2>&1 || true
  wait "${SERVER_PID}" >/dev/null 2>&1 || true
  SERVER_PID=""
fi

start_helper "${DB_PATH}" "${ATTACHMENTS_PATH}" "${OAUTH_STATE_PATH}" "${STDOUT_LOG}" "${STDERR_LOG}"
wait_for_health

http_request POST "${BASE_URL}/oauth/token" "${REFRESH_FORM}" "application/x-www-form-urlencoded"
assert_status "200" "refresh token exchange after helper restart"
RESTART_ACCESS_TOKEN="$(json_get "${RESPONSE_BODY}" access_token)"
[[ -n "${RESTART_ACCESS_TOKEN}" ]] || fail "refresh token exchange after restart did not return an access token"

http_request POST "${BASE_URL}/mcp" "${MCP_INITIALIZE_BODY}" "application/json" "Bearer ${RESTART_ACCESS_TOKEN}"
assert_status "200" "protected MCP endpoint after helper restart"

CURRENT_ACCESS_TOKEN="${RESTART_ACCESS_TOKEN}"
for (( cycle=1; cycle<=REFRESH_CYCLES; cycle++ )); do
  http_request POST "${BASE_URL}/oauth/token" "${REFRESH_FORM}" "application/x-www-form-urlencoded"
  assert_status "200" "repeated refresh token exchange cycle ${cycle}"
  CURRENT_ACCESS_TOKEN="$(json_get "${RESPONSE_BODY}" access_token)"
  [[ -n "${CURRENT_ACCESS_TOKEN}" ]] || fail "refresh cycle ${cycle} did not return an access token"
  assert_equals "${REFRESH_TOKEN}" "$(json_get "${RESPONSE_BODY}" refresh_token)" "refresh token stability in cycle ${cycle}"

  http_request POST "${BASE_URL}/mcp" "${MCP_INITIALIZE_BODY}" "application/json" "Bearer ${CURRENT_ACCESS_TOKEN}"
  assert_status "200" "protected MCP endpoint after refresh cycle ${cycle}"

  if (( cycle < REFRESH_CYCLES && cycle % 2 == 0 )); then
    if kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
      kill "${SERVER_PID}" >/dev/null 2>&1 || true
      wait "${SERVER_PID}" >/dev/null 2>&1 || true
      SERVER_PID=""
    fi

    start_helper "${DB_PATH}" "${ATTACHMENTS_PATH}" "${OAUTH_STATE_PATH}" "${STDOUT_LOG}" "${STDERR_LOG}"
    wait_for_health
  fi
done

[[ -f "${OAUTH_STATE_PATH}" ]] || fail "OAuth state file was not persisted"

echo "run_chatgpt_mcp_stress: success"
echo "run_chatgpt_mcp_stress: verified discovery, grant issue, grant reuse rejection, invalid refresh rejection, missing bearer rejection, restart persistence, and repeated refresh stability"
echo "run_chatgpt_mcp_stress: logs=${RUN_DIR}"
