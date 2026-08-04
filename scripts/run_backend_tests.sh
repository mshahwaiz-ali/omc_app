#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bench_root="$repo_root/backend_omc_app/frappe-bench"
test_log="$(mktemp)"
trap 'rm -f "$test_log"' EXIT

cd "$bench_root"

bench_command="$(command -v bench || true)"
if [[ -z "$bench_command" ]]; then
  echo "bench is not available on PATH." >&2
  exit 127
fi

set +o errexit
"$bench_command" --site omc.local run-tests --app omc_app --skip-test-records \
  2>&1 | tee "$test_log"
bench_status=${PIPESTATUS[0]}
set -o errexit

if [[ $bench_status -ne 0 ]]; then
  exit "$bench_status"
fi

if grep -Eq '(^|[[:space:]])(FAILED|ERROR)([[:space:]]|$)' "$test_log"; then
  echo "Backend tests reported FAILED or ERROR even though bench exited successfully." >&2
  exit 1
fi

if ! grep -Eq '^OK( \([^)]*\))?$' "$test_log"; then
  echo "Backend tests did not emit a successful unittest summary." >&2
  exit 1
fi
