#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
SKIP_ANDROID="${E2E_SKIP_ANDROID:-false}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

required_env() {
  local name="$1"
  [ -n "${!name:-}" ] || fail "$name is required by the full release gate."
}

for name in \
  E2E_USERNAME \
  E2E_PASSWORD \
  E2E_SERVICE_TITLE \
  E2E_FINANCE_USER \
  E2E_INVOICE_ITEM_CODE \
  E2E_PAYMENT_ACCOUNT \
  E2E_INTERNAL_USERNAME \
  E2E_INTERNAL_PASSWORD \
  E2E_OTHER_USERNAME \
  E2E_OTHER_PASSWORD; do
  required_env "$name"
done

case "$SKIP_ANDROID" in
  true|false) ;;
  *) fail "E2E_SKIP_ANDROID must be true or false." ;;
esac

if [ "$SKIP_ANDROID" = false ]; then
  required_env E2E_ANDROID_DEVICE_ID
  required_env OMC_ANDROID_API_BASE_URL
fi

run_stage() {
  local label="$1"
  local script="$2"
  echo
  echo "================================================================"
  echo "=== $label ==="
  echo "================================================================"
  bash "$script"
}

run_stage \
  "RELEASE GATE 0/5: STATIC + BACKEND REGRESSION" \
  "$SCRIPT_DIR/run_e2e_static_checks.sh"

run_stage \
  "RELEASE GATE 1/5: REAL CUSTOMER CHROME SMOKE" \
  "$SCRIPT_DIR/run_flutter_e2e.sh"

run_stage \
  "RELEASE GATE 2/5: FULL CUSTOMER PAYMENT-FIRST JOURNEY" \
  "$SCRIPT_DIR/run_customer_e2e.sh"

run_stage \
  "RELEASE GATE 3/5: INTERNAL ERP WORKFLOW + CUSTOMER COMPLETION" \
  "$SCRIPT_DIR/run_internal_e2e.sh"

run_stage \
  "RELEASE GATE 4/5: PERMISSIONS + NEGATIVE + TERMINAL INVARIANTS" \
  "$SCRIPT_DIR/run_permissions_e2e.sh"

if [ "$SKIP_ANDROID" = false ]; then
  run_stage \
    "RELEASE GATE 5/5: PHYSICAL ANDROID" \
    "$SCRIPT_DIR/run_android_e2e.sh"
else
  echo
  echo "================================================================"
  echo "=== RELEASE GATE 5/5: PHYSICAL ANDROID EXPLICITLY SKIPPED ==="
  echo "================================================================"
  echo "Chrome/core regression may be evaluated, but this is not a full device release gate."
fi

echo
echo "================================================================"
if [ "$SKIP_ANDROID" = false ]; then
  echo "=== FINAL: FULL OMC RELEASE GATE PASS ==="
else
  echo "=== FINAL: CORE OMC RELEASE GATE PASS (ANDROID SKIPPED) ==="
fi
echo "================================================================"
echo "Repository: $REPO_ROOT"
