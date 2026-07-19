#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

ACTION="${1:-status}"
[[ $# -gt 0 ]] && shift || true
SITE=""
NO_BACKUP=0
while (($#)); do
  case "$1" in
    --site) [[ $# -ge 2 ]] || die '--site requires a value'; SITE="$2"; shift 2 ;;
    --no-backup) NO_BACKUP=1; shift ;;
    *) die "unknown option: $1" ;;
  esac
done

load_config
setup_log "site-$ACTION"
need_sudo
BENCH_USER="${BENCH_USER:-$(id -un)}"
BENCH_DIR="${BENCH_DIR:-$BACKEND_DIR/frappe-bench}"
APP_SOURCE_DIR="${APP_SOURCE_DIR:-$BENCH_DIR/apps/omc_app}"
SITE="${SITE:-${SITE_NAME:-}}"

[[ -d "$BENCH_DIR/apps/frappe" ]] || die "Frappe Bench missing: $BENCH_DIR"
[[ -x "$BENCH_DIR/env/bin/python" ]] || die "Bench Python missing: $BENCH_DIR/env/bin/python"
[[ -n "$SITE" ]] || die 'provide --site or configure SITE_NAME'
bench_cmd bench --version >/dev/null
bench_cmd ./env/bin/python -c 'import frappe' >/dev/null

setup_production(){
  bench_cmd bench setup supervisor
  bench_cmd bench setup nginx
  [[ -f "$BENCH_DIR/config/supervisor.conf" ]] || die 'Supervisor config was not generated'
  [[ -f "$BENCH_DIR/config/nginx.conf" ]] || die 'Nginx config was not generated'
  "${SUDO[@]}" ln -sfn "$BENCH_DIR/config/supervisor.conf" /etc/supervisor/conf.d/frappe-bench.conf
  "${SUDO[@]}" ln -sfn "$BENCH_DIR/config/nginx.conf" /etc/nginx/conf.d/frappe-bench.conf
  "${SUDO[@]}" nginx -t
  "${SUDO[@]}" supervisorctl reread
  "${SUDO[@]}" supervisorctl update
  "${SUDO[@]}" systemctl reload nginx
}

post_site(){
  ensure_custom_app
  bench_cmd bench --site "$SITE" migrate
  bench_cmd bench --site "$SITE" clear-cache
  bench_cmd bench --site "$SITE" enable-scheduler
  bench_cmd bench use "$SITE"
  bench_cmd bench build
  setup_production
}

new_site(){
  site_exists "$SITE" && die "site already exists: $SITE"
  ensure_db_admin
  ensure_custom_app
  local admin
  admin="$(random_secret)"
  bench_cmd bench new-site "$SITE" --admin-password "$admin" --db-root-username frappe_admin --db-root-password "$FRAPPE_DB_ADMIN_PASSWORD" --mariadb-user-host-login-scope localhost
  bench_cmd bench --site "$SITE" install-app omc_app
  post_site
  printf '[IMPORTANT] Administrator password: %s\n' "$admin"
}

cleanup(){
  site_exists "$SITE" || die "site does not exist: $SITE"
  read -r -p "Type CLEANUP $SITE to continue: " answer
  [[ "$answer" == "CLEANUP $SITE" ]] || die 'cleanup cancelled'
  ((NO_BACKUP)) || bench_cmd bench --site "$SITE" backup --with-files
  ensure_db_admin
  bench_cmd bench drop-site "$SITE" --force --db-root-username frappe_admin --db-root-password "$FRAPPE_DB_ADMIN_PASSWORD"
}

status(){
  if site_exists "$SITE"; then
    bench_cmd bench --site "$SITE" list-apps
  else
    warn "site does not exist: $SITE"
  fi
  "${SUDO[@]}" supervisorctl status || true
  "${SUDO[@]}" systemctl is-active nginx mariadb redis-server supervisor || true
}

case "$ACTION" in
  new) new_site ;;
  install-app) site_exists "$SITE" || die "site does not exist: $SITE"; ensure_custom_app; bench_cmd bench --site "$SITE" install-app omc_app ;;
  migrate) site_exists "$SITE" || die "site does not exist: $SITE"; ensure_custom_app; bench_cmd bench --site "$SITE" migrate ;;
  drop|cleanup) cleanup ;;
  status) status ;;
  production) site_exists "$SITE" || die "site does not exist: $SITE"; setup_production ;;
  *) die 'actions: new|install-app|migrate|drop|cleanup|status|production' ;;
esac
