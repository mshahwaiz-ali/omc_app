#!/usr/bin/env bash
set -Eeuo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; source "$D/lib/common.sh"
A="${1:-menu}"; [[ $# -gt 0 ]] && shift || true; SITE=""; APP=""; NOB=0
while (($#)); do case "$1" in --site) SITE="$2"; shift 2;; --app) APP="$2"; shift 2;; --no-backup) NOB=1; shift;; *) die "unknown option: $1";; esac; done
load_config; setup_log "site-$A"; need_sudo
BENCH_USER="${BENCH_USER:-$(id -un)}"; BENCH_DIR="${BENCH_DIR:-$BACKEND_DIR/frappe-bench}"; APP_SOURCE_DIR="${APP_SOURCE_DIR:-$BENCH_DIR/apps/omc_app}"
[[ -d "$BENCH_DIR/apps/frappe" && -x "$BENCH_DIR/env/bin/python" ]] || die "invalid Bench: $BENCH_DIR"
bench_cmd bench --version >/dev/null; bench_cmd ./env/bin/python -c 'import frappe' >/dev/null
ask_site(){ [[ -n "$SITE" ]] || read -r -p 'Site name: ' SITE; [[ -n "$SITE" && "$SITE" != */* && "$SITE" != *' '* ]] || die 'invalid site name'; }
choose_app(){ [[ -n "$APP" ]] && return; mapfile -t APPS < <(find "$BENCH_DIR/apps" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | grep -v '^frappe$'); ((${#APPS[@]})) || { APP=""; return; }; printf 'Available apps:\n'; i=1; for x in "${APPS[@]}"; do printf '  %d) %s\n' "$i" "$x"; ((i++)); done; read -r -p 'Choose app number [1]: ' n; n="${n:-1}"; [[ "$n" =~ ^[0-9]+$ ]] && ((n>=1 && n<=${#APPS[@]})) || die 'invalid app selection'; APP="${APPS[n-1]}"; }
prod(){ bench_cmd bench setup supervisor; bench_cmd bench setup nginx; [[ -f "$BENCH_DIR/config/supervisor.conf" && -f "$BENCH_DIR/config/nginx.conf" ]] || die 'production configs missing'; "${SUDO[@]}" ln -sfn "$BENCH_DIR/config/supervisor.conf" /etc/supervisor/conf.d/frappe-bench.conf; "${SUDO[@]}" ln -sfn "$BENCH_DIR/config/nginx.conf" /etc/nginx/conf.d/frappe-bench.conf; "${SUDO[@]}" nginx -t; "${SUDO[@]}" supervisorctl reread; "${SUDO[@]}" supervisorctl update; "${SUDO[@]}" systemctl reload nginx; }
post(){ bench_cmd bench --site "$SITE" migrate; bench_cmd bench --site "$SITE" clear-cache; bench_cmd bench --site "$SITE" enable-scheduler; bench_cmd bench use "$SITE"; bench_cmd bench build; prod; }
new(){ ask_site; choose_app; site_exists "$SITE" && die "site exists: $SITE"; [[ "$APP" == omc_app ]] && ensure_custom_app; args=(bench new-site "$SITE" --mariadb-user-host-login-scope localhost); [[ -n "$APP" ]] && args+=(--install-app "$APP"); bench_cmd "${args[@]}"; post; ok "site created: $SITE"; }
status(){ found=0; while IFS= read -r x; do [[ -f "$x/site_config.json" ]] || continue; found=1; s="$(basename "$x")"; printf '\nSite: %s\n' "$s"; bench_cmd bench --site "$s" list-apps || true; done < <(find "$BENCH_DIR/sites" -mindepth 1 -maxdepth 1 -type d 2>/dev/null); ((found)) || warn 'no sites created yet'; "${SUDO[@]}" systemctl is-active nginx mariadb redis-server supervisor || true; }
clean(){ ask_site; site_exists "$SITE" || die "site missing: $SITE"; read -r -p "Type CLEANUP $SITE to continue: " x; [[ "$x" == "CLEANUP $SITE" ]] || die cancelled; ((NOB)) || bench_cmd bench --site "$SITE" backup --with-files; bench_cmd bench drop-site "$SITE" --force; }
menu(){ printf '1) Create site\n2) Show status\n3) Configure production\n'; read -r -p 'Choose [1-3]: ' x; case "$x" in 1) new;; 2) status;; 3) ask_site; prod;; *) die 'invalid selection';; esac; }
case "$A" in menu) menu;; new) new;; status) status;; install-app) ask_site; choose_app; [[ -n "$APP" ]] || die 'no installable apps found'; bench_cmd bench --site "$SITE" install-app "$APP";; migrate) ask_site; bench_cmd bench --site "$SITE" migrate;; production) ask_site; prod;; drop|cleanup) clean;; *) die 'actions: new|status|install-app|migrate|production|cleanup';; esac
