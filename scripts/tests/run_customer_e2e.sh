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
SUBMIT_WEB_PORT="${E2E_WEB_PORT:-5003}"
VERIFY_WEB_PORT="${E2E_VERIFY_WEB_PORT:-5004}"
DRIVER_PORT="${E2E_DRIVER_PORT:-4444}"
HEADLESS="${E2E_HEADLESS:-true}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

required_env() {
  local name="$1"
  [ -n "${!name:-}" ] || fail "$name is required."
}

required_env E2E_USERNAME
required_env E2E_PASSWORD
required_env E2E_SERVICE_TITLE
required_env E2E_FINANCE_USER
required_env E2E_INVOICE_ITEM_CODE
required_env E2E_PAYMENT_ACCOUNT

[ -d "$FLUTTER_APP_DIR" ] || fail "Flutter app folder not found: $FLUTTER_APP_DIR"
[ -d "$BENCH_DIR" ] || fail "Frappe bench folder not found: $BENCH_DIR"
command -v "$FLUTTER_BIN" >/dev/null 2>&1 || fail "Flutter executable not found: $FLUTTER_BIN"
command -v "$BENCH_BIN" >/dev/null 2>&1 || fail "Bench executable not found: $BENCH_BIN"
curl -fsS --max-time 5 "$API_BASE_URL/api/method/ping" >/dev/null 2>&1 || \
  fail "OMC backend ping failed at $API_BASE_URL. Start the backend and verify OMC_API_BASE_URL."

case "$HEADLESS" in
  true|false) ;;
  *) fail "E2E_HEADLESS must be true or false." ;;
esac

case "${SITE,,}" in
  localhost|*.local) ;;
  *) fail "Phase 2 finance control is restricted to a local site; got $SITE." ;;
esac

echo "=== CUSTOMER E2E PREFLIGHT ==="
(
  cd -- "$BENCH_DIR"
  OMC_E2E_CONTROL=1 \
  E2E_USERNAME="$E2E_USERNAME" \
  E2E_SERVICE_TITLE="$E2E_SERVICE_TITLE" \
  E2E_FINANCE_USER="$E2E_FINANCE_USER" \
  E2E_INVOICE_ITEM_CODE="$E2E_INVOICE_ITEM_CODE" \
  E2E_PAYMENT_ACCOUNT="$E2E_PAYMENT_ACCOUNT" \
  "$BENCH_BIN" --site "$SITE" execute omc_app.e2e_control.preflight
)

driver_started=false
driver_log=""
driver_pid=""

cleanup() {
  if [ "$driver_started" = true ] && [ -n "$driver_pid" ]; then
    kill "$driver_pid" >/dev/null 2>&1 || true
    wait "$driver_pid" >/dev/null 2>&1 || true
  fi
  if [ -n "$driver_log" ]; then
    rm -f -- "$driver_log"
  fi
}
trap cleanup EXIT INT TERM

if ! curl -fsS --max-time 2 "http://127.0.0.1:$DRIVER_PORT/status" >/dev/null 2>&1; then
  command -v "$CHROMEDRIVER_BIN" >/dev/null 2>&1 || fail \
    "ChromeDriver is not running on port $DRIVER_PORT and was not found as $CHROMEDRIVER_BIN."
  driver_log="$(mktemp "${TMPDIR:-/tmp}/omc-customer-e2e-chromedriver.XXXXXX.log")"
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
    fail "ChromeDriver did not become ready on port $DRIVER_PORT. See: $driver_log"
fi

headless_flag="--headless"
if [ "$HEADLESS" = false ]; then
  headless_flag="--no-headless"
fi

run_flutter_leg() {
  local target="$1"
  local web_port="$2"
  local request_id="${3:-}"
  local payment_id="${4:-}"
  local marker_defines=()
  if [ -n "$request_id" ]; then
    marker_defines+=(--dart-define="E2E_REQUEST_ID=$request_id")
  fi
  if [ -n "$payment_id" ]; then
    marker_defines+=(--dart-define="E2E_PAYMENT_ID=$payment_id")
  fi

  (
    cd -- "$FLUTTER_APP_DIR"
    "$FLUTTER_BIN" drive \
      --device-id=chrome \
      --driver=test_driver/e2e_test.dart \
      --target="$target" \
      --web-hostname=localhost \
      --web-port="$web_port" \
      --driver-port="$DRIVER_PORT" \
      "$headless_flag" \
      --dart-define=OMC_ENV=development \
      --dart-define=OMC_API_BASE_URL="$API_BASE_URL" \
      --dart-define=OMC_LINK_BASE_URL="http://localhost:$web_port" \
      --dart-define=OMC_USE_MOCK_AUTH=false \
      --dart-define=OMC_USE_SERVICE_PREVIEW=false \
      --dart-define=OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK=false \
      --dart-define=OMC_E2E_AUDIT=true \
      --dart-define=OMC_E2E_FILE_PICKER=true \
      --dart-define="E2E_USERNAME=$E2E_USERNAME" \
      --dart-define="E2E_PASSWORD=$E2E_PASSWORD" \
      --dart-define="E2E_SERVICE_TITLE=$E2E_SERVICE_TITLE" \
      "${marker_defines[@]}"
  )
}

echo "=== CUSTOMER E2E LEG A: REQUEST + DOCUMENTS + RECEIPT ==="
run_flutter_leg \
  integration_test/e2e/customer_journey_submit_test.dart \
  "$SUBMIT_WEB_PORT"

echo "=== CUSTOMER E2E FINANCE: REVIEW + ERP SETTLEMENT + ACTIVATION ==="
set +e
settlement_output="$(
  cd -- "$BENCH_DIR"
  OMC_E2E_CONTROL=1 \
  E2E_USERNAME="$E2E_USERNAME" \
  E2E_SERVICE_TITLE="$E2E_SERVICE_TITLE" \
  E2E_FINANCE_USER="$E2E_FINANCE_USER" \
  E2E_INVOICE_ITEM_CODE="$E2E_INVOICE_ITEM_CODE" \
  E2E_PAYMENT_ACCOUNT="$E2E_PAYMENT_ACCOUNT" \
  "$BENCH_BIN" --site "$SITE" execute omc_app.e2e_control.settle_latest_customer_request 2>&1
)"
settlement_status=$?
set -e
printf '%s\n' "$settlement_output"
[ "$settlement_status" -eq 0 ] || fail "Authorized finance settlement step failed."

request_id="$(printf '%s\n' "$settlement_output" | \
  sed -n 's/.*OMC_E2E_REQUEST_ID=\([A-Za-z0-9._-]*\).*/\1/p' | tail -n 1)"
payment_id="$(printf '%s\n' "$settlement_output" | \
  sed -n 's/.*OMC_E2E_PAYMENT_ID=\([A-Za-z0-9._-]*\).*/\1/p' | tail -n 1)"
[ -n "$request_id" ] || fail "Finance settlement did not return an E2E request ID marker."
[ -n "$payment_id" ] || fail "Finance settlement did not return an E2E payment ID marker."

echo "=== CUSTOMER E2E LEG B: CUSTOMER SETTLEMENT + NOTIFICATION VERIFICATION ==="
run_flutter_leg \
  integration_test/e2e/customer_journey_verify_test.dart \
  "$VERIFY_WEB_PORT" \
  "$request_id" \
  "$payment_id"

echo "=== CUSTOMER E2E COMPLETE ==="
echo "Request verified: $request_id"
echo "Payment verified: $payment_id"
