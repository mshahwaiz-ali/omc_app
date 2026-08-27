#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
FLUTTER_APP_DIR="$REPO_ROOT/omc_app"
BENCH_DIR="$REPO_ROOT/backend_omc_app/frappe-bench"
SITE="${OMC_E2E_SITE:-omc-prod.local}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DART_BIN="${DART_BIN:-dart}"
BENCH_BIN="${BENCH_BIN:-bench}"
RUN_BACKEND_SUITE="${E2E_RUN_BACKEND_SUITE:-true}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[ -d "$FLUTTER_APP_DIR" ] || fail "Flutter app folder not found: $FLUTTER_APP_DIR"
[ -d "$BENCH_DIR" ] || fail "Frappe bench folder not found: $BENCH_DIR"
command -v "$FLUTTER_BIN" >/dev/null 2>&1 || fail "Flutter executable not found: $FLUTTER_BIN"
command -v "$DART_BIN" >/dev/null 2>&1 || fail "Dart executable not found: $DART_BIN"
command -v "$BENCH_BIN" >/dev/null 2>&1 || fail "Bench executable not found: $BENCH_BIN"

case "$RUN_BACKEND_SUITE" in
  true|false) ;;
  *) fail "E2E_RUN_BACKEND_SUITE must be true or false." ;;
esac

echo "=== E2E STATIC: SHELL SYNTAX ==="
for script in \
  "$REPO_ROOT/scripts/tests/e2e_web_runtime.sh" \
  "$REPO_ROOT/scripts/tests/chrome_e2e_binary.sh" \
  "$REPO_ROOT/scripts/tests/run_flutter_e2e.sh" \
  "$REPO_ROOT/scripts/tests/run_customer_e2e.sh" \
  "$REPO_ROOT/scripts/tests/run_internal_e2e.sh" \
  "$REPO_ROOT/scripts/tests/run_permissions_e2e.sh" \
  "$REPO_ROOT/scripts/tests/run_android_e2e.sh" \
  "$REPO_ROOT/scripts/tests/run_e2e_static_checks.sh" \
  "$REPO_ROOT/scripts/tests/run_full_flutter.sh"; do
  [ -f "$script" ] || fail "Expected E2E script missing: $script"
  bash -n "$script"
done

echo "=== E2E STATIC: PYTHON CONTROL ACTORS ==="
PYTHON_BIN="$BENCH_DIR/env/bin/python"
[ -x "$PYTHON_BIN" ] || fail "Bench Python not found: $PYTHON_BIN"
"$PYTHON_BIN" -m py_compile \
  "$BENCH_DIR/apps/omc_app/omc_app/e2e_control.py" \
  "$BENCH_DIR/apps/omc_app/omc_app/e2e_internal_control.py" \
  "$BENCH_DIR/apps/omc_app/omc_app/e2e_security_control.py"

echo "=== E2E STATIC: DART FORMAT ==="
(
  cd -- "$FLUTTER_APP_DIR"
  "$DART_BIN" format --output=none --set-exit-if-changed lib test integration_test
)

echo "=== E2E STATIC: FLUTTER ANALYZE ==="
(
  cd -- "$FLUTTER_APP_DIR"
  "$FLUTTER_BIN" analyze
)

echo "=== E2E STATIC: FLUTTER UNIT/WIDGET SUITE ==="
(
  cd -- "$FLUTTER_APP_DIR"
  "$FLUTTER_BIN" test --reporter=expanded
)

echo "=== E2E STATIC: GIT WHITESPACE CHECK ==="
(
  cd -- "$REPO_ROOT"
  git diff --check
)

if [ "$RUN_BACKEND_SUITE" = true ]; then
  echo "=== E2E STATIC: BACKEND OMC SUITE ==="
  backend_log="$(mktemp "${TMPDIR:-/tmp}/omc-e2e-backend.XXXXXX.log")"
  if ! (
    cd -- "$BENCH_DIR"
    "$BENCH_BIN" --site "$SITE" run-tests --app omc_app --skip-test-records
  ) 2>&1 | tee "$backend_log"; then
    rm -f -- "$backend_log"
    fail "Backend OMC suite command failed."
  fi
  if grep -Eq '^(FAILED|FAILED \(|ERROR:)' "$backend_log"; then
    rm -f -- "$backend_log"
    fail "Backend OMC suite reported test failures despite a zero command exit."
  fi
  if ! grep -Eq '^OK( \(|$)' "$backend_log"; then
    rm -f -- "$backend_log"
    fail "Backend OMC suite did not report a final OK result."
  fi
  rm -f -- "$backend_log"
else
  echo "=== E2E STATIC: BACKEND OMC SUITE SKIPPED BY EXPLICIT FLAG ==="
fi

echo "=== E2E STATIC CHECKS COMPLETE ==="
