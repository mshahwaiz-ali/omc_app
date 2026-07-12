#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; source "$SCRIPT_DIR/lib/common.sh"
SITE="${1:-}"; need_sudo; load_config; BENCH_USER="${BENCH_USER:-$USER}"; BENCH_DIR="${BENCH_DIR:-$BACKEND_DIR/frappe-bench}"; SITE="${SITE:-${SITE_NAME:-}}"; [[ -n "$SITE" ]] || die 'Usage: ./verify.sh SITE'
check(){ local n="$1"; shift; "$@" >/dev/null 2>&1 && ok "$n" || die "$n failed"; }
check Bench test -d "$BENCH_DIR/apps/frappe"; check Site test -f "$BENCH_DIR/sites/$SITE/site_config.json"; check frappe bench_cmd ./env/bin/python -c 'import frappe'; check omc_app bench_cmd ./env/bin/python -c 'import omc_app'; check editable bench_cmd ./env/bin/pip show omc_app
normalize_apps_txt; check apps.txt grep -qxF omc_app "$BENCH_DIR/sites/apps.txt"; check installed-apps bench_cmd bench --site "$SITE" list-apps
check migration bench_cmd bench --site "$SITE" migrate; check scheduler bench_cmd bench --site "$SITE" doctor
check Redis bash -c "ss -ltn | grep -Eq ':11000|:13000'"; check Workers "${SUDO[@]}" supervisorctl status
check Assets test -d "$BENCH_DIR/sites/assets/frappe/dist"; check Nginx "${SUDO[@]}" nginx -t; check nginx-active "${SUDO[@]}" systemctl is-active nginx
check HTTP curl -fsS --max-time 15 "http://127.0.0.1/api/method/ping"; ! curl -fsS "http://127.0.0.1/login" | grep -Eo '(website|login|frappe-web)\.bundle\.[^" ]+\.(css|js)' | while read -r a; do curl -fsS "http://127.0.0.1/assets/frappe/dist/$a" >/dev/null || exit 1; done || die 'asset URL returned 404'
ok 'deployment verification complete'
