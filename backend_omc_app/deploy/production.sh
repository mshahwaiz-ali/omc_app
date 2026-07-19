#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

load_config
setup_log production
need_sudo

BENCH_DIR="${BENCH_DIR:-}"

[[ -n "$BENCH_DIR" ]] || die "BENCH_DIR is not set in deploy/config/production.env"
[[ -d "$BENCH_DIR" ]] || die "bench directory not found: $BENCH_DIR"
[[ -d "$BENCH_DIR/sites" ]] || die "not a runnable Bench directory (sites/ missing): $BENCH_DIR"
[[ -f "$BENCH_DIR/sites/apps.txt" ]] || die "Bench apps list missing: $BENCH_DIR/sites/apps.txt"

have supervisorctl || die "supervisorctl is not installed or not available in PATH"
have systemctl || die "systemctl is required"

info "bench: $BENCH_DIR"

supervisor_status="$(${SUDO[@]} supervisorctl status 2>&1 || true)"
printf '%s\n' "$supervisor_status"

if grep -qE '^[^[:space:]]+[[:space:]]+RUNNING([[:space:]]|$)' <<<"$supervisor_status"; then
  info "production processes are running; restarting Supervisor programs"
  "${SUDO[@]}" supervisorctl restart all
else
  info "production processes are stopped; starting Supervisor programs"
  "${SUDO[@]}" supervisorctl start all
fi

if "${SUDO[@]}" systemctl is-active --quiet nginx; then
  info "Nginx is running; reloading configuration"
  "${SUDO[@]}" nginx -t
  "${SUDO[@]}" systemctl reload nginx
else
  info "Nginx is stopped; validating configuration and starting it"
  "${SUDO[@]}" nginx -t
  "${SUDO[@]}" systemctl start nginx
fi

info "final Supervisor status"
"${SUDO[@]}" supervisorctl status

info "final Nginx status"
"${SUDO[@]}" systemctl is-active nginx

ok "Frappe production services are active"
