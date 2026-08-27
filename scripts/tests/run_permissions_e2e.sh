#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
FLUTTER_APP_DIR="$REPO_ROOT/omc_app"
BENCH_DIR="$REPO_ROOT/backend_omc_app/frappe-bench"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
BENCH_BIN="${BENCH_BIN:-bench}"
CHROMEDRIVER_BIN="${CHROMEDRIVER_BIN:-chromedriver}"
SITE="${OMC_E2E_SITE:-omc-prod.local}"
API_BASE_URL="${OMC_API_BASE_URL:-http://omc-prod.local:8000}"
API_BASE_URL="${API_BASE_URL%/}"
AUTH_WEB_PORT="${E2E_AUTH_WEB_PORT:-5007}"
ISOLATION_WEB_PORT="${E2E_ISOLATION_WEB_PORT:-5008}"
DRIVER_PORT="${E2E_DRIVER_PORT:-4444}"
HEADLESS="${E2E_HEADLESS:-true}"
INVALID_PASSWORD="${E2E_INVALID_PASSWORD:-__OMC_E2E_INTENTIONALLY_INVALID_PASSWORD__}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

source "$SCRIPT_DIR/e2e_web_runtime.sh"
e2e_configure_web_runtime "$API_BASE_URL" "$SCRIPT_DIR" || \
  fail "Unable to configure the local Chrome E2E runtime."

required_env() {
  local name="$1"
  [ -n "${!name:-}" ] || fail "$name is required."
}

required_env E2E_USERNAME
required_env E2E_PASSWORD
required_env E2E_OTHER_USERNAME
required_env E2E_OTHER_PASSWORD
required_env E2E_SERVICE_TITLE

[ "$E2E_USERNAME" != "$E2E_OTHER_USERNAME" ] || fail "E2E_OTHER_USERNAME must be a different customer."
[ "$INVALID_PASSWORD" != "$E2E_PASSWORD" ] || fail "E2E_INVALID_PASSWORD must differ from E2E_PASSWORD."
[ -d "$FLUTTER_APP_DIR" ] || fail "Flutter app folder not found: $FLUTTER_APP_DIR"
[ -d "$BENCH_DIR" ] || fail "Frappe bench folder not found: $BENCH_DIR"
command -v "$FLUTTER_BIN" >/dev/null 2>&1 || fail "Flutter executable not found: $FLUTTER_BIN"
command -v "$BENCH_BIN" >/dev/null 2>&1 || fail "Bench executable not found: $BENCH_BIN"
curl "${E2E_API_CURL_ARGS[@]}" "$API_BASE_URL/api/method/ping" >/dev/null 2>&1 || \
  fail "OMC backend ping failed at $API_BASE_URL."

case "$HEADLESS" in
  true|false) ;;
  *) fail "E2E_HEADLESS must be true or false." ;;
esac
case "${SITE,,}" in
  localhost|*.local) ;;
  *) fail "Phase 4 control actor is restricted to a local site; got $SITE." ;;
esac

control_env=(
  OMC_E2E_CONTROL=1
  "E2E_USERNAME=$E2E_USERNAME"
  "E2E_OTHER_USERNAME=$E2E_OTHER_USERNAME"
  "E2E_SERVICE_TITLE=$E2E_SERVICE_TITLE"
)

run_control() {
  local method="$1"
  (
    cd -- "$BENCH_DIR"
    env "${control_env[@]}" "$BENCH_BIN" --site "$SITE" execute "$method"
  )
}

extract_marker() {
  local output="$1"
  local marker="$2"
  printf '%s\n' "$output" | \
    sed -n "s/.*${marker}=\([A-Za-z0-9._-]*\).*/\1/p" | tail -n 1
}

echo "=== PERMISSIONS E2E PREFLIGHT ==="
preflight_output="$(run_control omc_app.e2e_security_control.preflight)"
printf '%s\n' "$preflight_output"
request_id="$(extract_marker "$preflight_output" OMC_E2E_REQUEST_ID)"
task_id="$(extract_marker "$preflight_output" OMC_E2E_TASK_ID)"
[ -n "$request_id" ] || fail "Permissions preflight did not return a request marker."
[ -n "$task_id" ] || fail "Permissions preflight did not return a task marker."

driver_started=false
driver_log=""
driver_pid=""
cleanup() {
  if [ "$driver_started" = true ] && [ -n "$driver_pid" ]; then
    kill "$driver_pid" >/dev/null 2>&1 || true
    wait "$driver_pid" >/dev/null 2>&1 || true
  fi
  [ -z "$driver_log" ] || rm -f -- "$driver_log"
}
trap cleanup EXIT INT TERM

if ! curl -fsS --max-time 2 "http://127.0.0.1:$DRIVER_PORT/status" >/dev/null 2>&1; then
  command -v "$CHROMEDRIVER_BIN" >/dev/null 2>&1 || fail \
    "ChromeDriver is not running and was not found as $CHROMEDRIVER_BIN."
  driver_log="$(mktemp "${TMPDIR:-/tmp}/omc-permissions-e2e-chromedriver.XXXXXX.log")"
  "$CHROMEDRIVER_BIN" --port="$DRIVER_PORT" >"$driver_log" 2>&1 &
  driver_pid="$!"
  driver_started=true
  for _ in $(seq 1 50); do
    if curl -fsS --max-time 1 "http://127.0.0.1:$DRIVER_PORT/status" >/dev/null 2>&1; then
      break
    fi
    if ! kill -0 "$driver_pid" >/dev/null 2>&1; then
      fail "ChromeDriver exited before becoming ready. See: $driver_log"
    fi
    sleep 0.1
  done
  curl -fsS --max-time 2 "http://127.0.0.1:$DRIVER_PORT/status" >/dev/null 2>&1 || \
    fail "ChromeDriver did not become ready on port $DRIVER_PORT."
fi

headless_flag="--headless"
[ "$HEADLESS" = true ] || headless_flag="--no-headless"

run_flutter() {
  local target="$1"
  local web_port="$2"
  (
    cd -- "$FLUTTER_APP_DIR"
    "$FLUTTER_BIN" drive \
      --device-id=web-server \
      --browser-name=chrome \
      --driver=test_driver/e2e_test.dart \
      --target="$target" \
      --web-hostname="$E2E_WEB_BIND_HOST" \
      --web-port="$web_port" \
      --web-launch-url="http://$E2E_WEB_ORIGIN_HOST:$web_port/" \
      --driver-port="$DRIVER_PORT" \
      "$headless_flag" \
      "${E2E_CHROME_ARGS[@]}" \
      --dart-define=OMC_ENV=development \
      --dart-define=OMC_API_BASE_URL="$API_BASE_URL" \
      --dart-define=OMC_LINK_BASE_URL="http://$E2E_WEB_ORIGIN_HOST:$web_port" \
      --dart-define=OMC_USE_MOCK_AUTH=false \
      --dart-define=OMC_USE_SERVICE_PREVIEW=false \
      --dart-define=OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK=false \
      --dart-define=OMC_E2E_AUDIT=true \
      --dart-define="E2E_USERNAME=$E2E_USERNAME" \
      --dart-define="E2E_PASSWORD=$E2E_PASSWORD" \
      --dart-define="E2E_OTHER_USERNAME=$E2E_OTHER_USERNAME" \
      --dart-define="E2E_OTHER_PASSWORD=$E2E_OTHER_PASSWORD" \
      --dart-define="E2E_INVALID_PASSWORD=$INVALID_PASSWORD" \
      --dart-define="E2E_SERVICE_TITLE=$E2E_SERVICE_TITLE" \
      --dart-define="E2E_REQUEST_ID=$request_id" \
      --dart-define="E2E_TASK_ID=$task_id"
  )
}

echo "=== PERMISSIONS E2E LEG A: AUTH NEGATIVE + RECOVERY ==="
run_flutter integration_test/e2e/auth_negative_test.dart "$AUTH_WEB_PORT"

echo "=== PERMISSIONS E2E LEG B: CROSS-CUSTOMER + INTERNAL-SURFACE ISOLATION ==="
run_flutter integration_test/e2e/cross_customer_isolation_test.dart "$ISOLATION_WEB_PORT"

echo "=== PERMISSIONS E2E BACKEND: TERMINAL + EXACTLY-ONCE INVARIANTS ==="
invariant_output="$(run_control omc_app.e2e_security_control.assert_terminal_and_idempotency)"
printf '%s\n' "$invariant_output"
assert_request="$(extract_marker "$invariant_output" OMC_E2E_REQUEST_ID)"
assert_task="$(extract_marker "$invariant_output" OMC_E2E_TASK_ID)"
[ "$assert_request" = "$request_id" ] || fail "Invariant actor changed request identity."
[ "$assert_task" = "$task_id" ] || fail "Invariant actor changed Task identity."

echo "=== PERMISSIONS E2E COMPLETE ==="
echo "Request protected: $request_id"
echo "Task protected: $task_id"
