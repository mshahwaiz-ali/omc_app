#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
FLUTTER_APP_DIR="$REPO_ROOT/omc_app"
BENCH_DIR="$REPO_ROOT/backend_omc_app/frappe-bench"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
BENCH_BIN="${BENCH_BIN:-bench}"
SITE="${OMC_E2E_SITE:-omc-prod.local}"
ANDROID_DEVICE_ID="${E2E_ANDROID_DEVICE_ID:-}"
ANDROID_API_BASE_URL="${OMC_ANDROID_API_BASE_URL:-}"

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
required_env E2E_OTHER_USERNAME
required_env E2E_OTHER_PASSWORD
required_env E2E_INTERNAL_USERNAME
required_env E2E_INTERNAL_PASSWORD
required_env E2E_SERVICE_TITLE
[ -n "$ANDROID_DEVICE_ID" ] || fail "E2E_ANDROID_DEVICE_ID is required for the physical-device gate."
[ -n "$ANDROID_API_BASE_URL" ] || fail \
  "OMC_ANDROID_API_BASE_URL is required and must be reachable from the physical Android device."
ANDROID_API_BASE_URL="${ANDROID_API_BASE_URL%/}"

[ -d "$FLUTTER_APP_DIR" ] || fail "Flutter app folder not found: $FLUTTER_APP_DIR"
[ -d "$BENCH_DIR" ] || fail "Frappe bench folder not found: $BENCH_DIR"
command -v "$FLUTTER_BIN" >/dev/null 2>&1 || fail "Flutter executable not found: $FLUTTER_BIN"
command -v "$BENCH_BIN" >/dev/null 2>&1 || fail "Bench executable not found: $BENCH_BIN"

case "${SITE,,}" in
  localhost|*.local) ;;
  *) fail "Android E2E fixture lookup is restricted to a local site; got $SITE." ;;
esac

if ! "$FLUTTER_BIN" devices --machine | grep -Fq "\"id\":\"$ANDROID_DEVICE_ID\""; then
  echo "Available Flutter devices:" >&2
  "$FLUTTER_BIN" devices >&2 || true
  fail "Android device $ANDROID_DEVICE_ID is not currently available to Flutter."
fi

control_env=(
  OMC_E2E_CONTROL=1
  "E2E_USERNAME=$E2E_USERNAME"
  "E2E_OTHER_USERNAME=$E2E_OTHER_USERNAME"
  "E2E_SERVICE_TITLE=$E2E_SERVICE_TITLE"
)

echo "=== ANDROID E2E COMPLETED-CASE PREFLIGHT ==="
preflight_output="$(
  cd -- "$BENCH_DIR"
  env "${control_env[@]}" \
    "$BENCH_BIN" --site "$SITE" execute omc_app.e2e_security_control.preflight
)"
printf '%s\n' "$preflight_output"
request_id="$(printf '%s\n' "$preflight_output" | \
  sed -n 's/.*OMC_E2E_REQUEST_ID=\([A-Za-z0-9._-]*\).*/\1/p' | tail -n 1)"
task_id="$(printf '%s\n' "$preflight_output" | \
  sed -n 's/.*OMC_E2E_TASK_ID=\([A-Za-z0-9._-]*\).*/\1/p' | tail -n 1)"
[ -n "$request_id" ] || fail "Android preflight did not return a request marker."
[ -n "$task_id" ] || fail "Android preflight did not return a Task marker."

run_android_test() {
  local target="$1"
  shift
  (
    cd -- "$FLUTTER_APP_DIR"
    "$FLUTTER_BIN" test "$target" \
      -d "$ANDROID_DEVICE_ID" \
      --reporter=expanded \
      --dart-define=OMC_ENV=development \
      --dart-define="OMC_API_BASE_URL=$ANDROID_API_BASE_URL" \
      --dart-define="OMC_LINK_BASE_URL=$ANDROID_API_BASE_URL" \
      --dart-define=OMC_USE_MOCK_AUTH=false \
      --dart-define=OMC_USE_SERVICE_PREVIEW=false \
      --dart-define=OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK=false \
      --dart-define=OMC_E2E_AUDIT=true \
      --dart-define="E2E_SERVICE_TITLE=$E2E_SERVICE_TITLE" \
      --dart-define="E2E_REQUEST_ID=$request_id" \
      --dart-define="E2E_TASK_ID=$task_id" \
      "$@"
  )
}

echo "=== ANDROID LEG A: CUSTOMER REAL LOGIN + NAVIGATION + LOGOUT ==="
run_android_test \
  integration_test/e2e/smoke_test.dart \
  --dart-define="E2E_USERNAME=$E2E_USERNAME" \
  --dart-define="E2E_PASSWORD=$E2E_PASSWORD"

echo "=== ANDROID LEG B: CUSTOMER COMPLETED CASE PROJECTION ==="
run_android_test \
  integration_test/e2e/customer_completion_test.dart \
  --dart-define="E2E_USERNAME=$E2E_USERNAME" \
  --dart-define="E2E_PASSWORD=$E2E_PASSWORD"

echo "=== ANDROID LEG C: INTERNAL TASK VISIBILITY + READ-ONLY AUTHORITY ==="
run_android_test \
  integration_test/e2e/internal_workflow_test.dart \
  --dart-define="E2E_USERNAME=$E2E_INTERNAL_USERNAME" \
  --dart-define="E2E_PASSWORD=$E2E_INTERNAL_PASSWORD" \
  --dart-define="E2E_INTERNAL_USERNAME=$E2E_INTERNAL_USERNAME" \
  --dart-define="E2E_INTERNAL_PASSWORD=$E2E_INTERNAL_PASSWORD"

echo "=== ANDROID LEG D: SECOND-CUSTOMER ISOLATION ==="
run_android_test \
  integration_test/e2e/cross_customer_isolation_test.dart \
  --dart-define="E2E_USERNAME=$E2E_USERNAME" \
  --dart-define="E2E_PASSWORD=$E2E_PASSWORD" \
  --dart-define="E2E_OTHER_USERNAME=$E2E_OTHER_USERNAME" \
  --dart-define="E2E_OTHER_PASSWORD=$E2E_OTHER_PASSWORD"

echo "=== ANDROID PHYSICAL-DEVICE GATE COMPLETE ==="
echo "Device: $ANDROID_DEVICE_ID"
echo "Request verified: $request_id"
echo "Task verified: $task_id"
