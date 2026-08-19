#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-quick}"
case "$MODE" in
  quick|full) ;;
  *)
    echo "Usage: bash scripts/run_flutter_validation.sh [quick|full]" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_DIR="$REPO_ROOT/omc_app"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not available on PATH." >&2
  exit 127
fi

if [[ ! -f "$FLUTTER_DIR/pubspec.yaml" ]]; then
  echo "Flutter project not found at: $FLUTTER_DIR" >&2
  exit 1
fi

cd "$FLUTTER_DIR"

echo "== Flutter validation ($MODE) =="
flutter --version

echo
echo "== Static analysis =="
flutter analyze

focused_tests=(
  "test/app/accessibility_design_contract_test.dart"
  "test/app/p2_closeout_contract_test.dart"
  "test/app/p3_polish_contract_test.dart"
  "test/app/p3_closeout_contract_test.dart"
)

echo
echo "== Focused architecture / polish contracts =="
for test_file in "${focused_tests[@]}"; do
  if [[ ! -f "$test_file" ]]; then
    echo "Required focused test is missing: $test_file" >&2
    exit 1
  fi
  echo "-- $test_file"
  flutter test "$test_file"
done

if [[ "$MODE" == "full" ]]; then
  echo
echo "== Full Flutter test suite =="
  flutter test
fi

echo
echo "Flutter validation completed successfully ($MODE)."
