#!/usr/bin/env bash
set -Eeuo pipefail

# Start or refresh an existing OMC Frappe production deployment.
#
# This script is intentionally runtime-only. It does not:
# - install packages;
# - create or recreate a Bench;
# - create or recreate a site or database;
# - install the OMC app;
# - run migrations or build assets;
# - modify Nginx or Supervisor configuration;
# - delete files or runtime data.
#
# BENCH_DIR may be overridden when the deployed Bench lives elsewhere:
#   BENCH_DIR=/path/to/frappe-bench ./production.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BENCH_DIR="$(cd "$SCRIPT_DIR/../frappe-bench" && pwd)"
BENCH_DIR="${BENCH_DIR:-$DEFAULT_BENCH_DIR}"

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  SUDO=()
elif command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
else
  printf 'ERROR: sudo is required when production.sh is not run as root.\n' >&2
  exit 1
fi

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '\n==> %s\n' "$*"
}

[[ -d "$BENCH_DIR" ]] || fail "Bench directory not found: $BENCH_DIR"
[[ -d "$BENCH_DIR/sites" ]] || fail "Not a runnable Bench directory: $BENCH_DIR/sites is missing"
[[ -f "$BENCH_DIR/sites/apps.txt" ]] || fail "Bench apps list is missing: $BENCH_DIR/sites/apps.txt"
[[ -x "$BENCH_DIR/env/bin/python" ]] || fail "Bench Python is missing: $BENCH_DIR/env/bin/python"

command -v supervisorctl >/dev/null 2>&1 || fail "supervisorctl is not installed"
command -v systemctl >/dev/null 2>&1 || fail "systemctl is not installed"
command -v nginx >/dev/null 2>&1 || fail "nginx is not installed"

info "Using Bench: $BENCH_DIR"

info "Ensuring the Supervisor service is running"
if ! "${SUDO[@]}" systemctl is-active --quiet supervisor; then
  "${SUDO[@]}" systemctl start supervisor
fi

info "Refreshing Supervisor configuration"
"${SUDO[@]}" supervisorctl reread
"${SUDO[@]}" supervisorctl update

info "Starting or restarting Frappe production processes"
SUPERVISOR_STATUS="$("${SUDO[@]}" supervisorctl status 2>&1 || true)"
printf '%s\n' "$SUPERVISOR_STATUS"

if grep -qE '^[^[:space:]]+[[:space:]]+RUNNING([[:space:]]|$)' <<<"$SUPERVISOR_STATUS"; then
  "${SUDO[@]}" supervisorctl restart all
else
  "${SUDO[@]}" supervisorctl start all
fi

info "Validating Nginx configuration"
"${SUDO[@]}" nginx -t

info "Starting or reloading Nginx"
if "${SUDO[@]}" systemctl is-active --quiet nginx; then
  "${SUDO[@]}" systemctl reload nginx
else
  "${SUDO[@]}" systemctl start nginx
fi

info "Checking Redis availability"
if command -v redis-cli >/dev/null 2>&1; then
  REDIS_REPLY="$(redis-cli ping 2>/dev/null || true)"
  [[ "$REDIS_REPLY" == "PONG" ]] || fail "Redis did not answer PONG"
  printf 'Redis: %s\n' "$REDIS_REPLY"
else
  printf 'Redis check skipped: redis-cli is not installed.\n'
fi

info "Final Supervisor status"
"${SUDO[@]}" supervisorctl status

info "Final Nginx status"
"${SUDO[@]}" systemctl is-active nginx

printf '\nOMC Frappe production services are active.\n'
