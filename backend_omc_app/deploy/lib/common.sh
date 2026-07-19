#!/usr/bin/env bash
set -Eeuo pipefail
T="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; BACKEND_DIR="$(cd "$T/.." && pwd)"; REPO_DIR="$(cd "$BACKEND_DIR/.." && pwd)"; CONFIG_DIR="$T/config"; SECRETS_DIR="$T/.secrets"; LOG_DIR="$T/logs"; BACKUP_DIR="$T/backups"
mkdir -p "$SECRETS_DIR" "$LOG_DIR" "$BACKUP_DIR"; chmod 700 "$SECRETS_DIR" 2>/dev/null || true
info(){ printf '[INFO] %s\n' "$*"; }; ok(){ printf '[OK] %s\n' "$*"; }; warn(){ printf '[WARN] %s\n' "$*" >&2; }; die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }; have(){ command -v "$1" >/dev/null 2>&1; }
need_sudo(){ if ((EUID==0)); then SUDO=(); else have sudo || die 'sudo is required'; sudo -n true 2>/dev/null || die 'passwordless sudo is required'; SUDO=(sudo -n); fi; }
load_env(){ [[ -f "$1" ]] || return 0; set -a; source "$1"; set +a; }; load_config(){ load_env "$CONFIG_DIR/production.env"; load_env "$SECRETS_DIR/production.env"; }
random_secret(){ openssl rand -base64 48 | tr -d '\n' | tr '/+' '_-' | cut -c1-48; }; setup_log(){ local f="$LOG_DIR/$1-$(date +%Y%m%d-%H%M%S).log"; touch "$f"; exec > >(tee -a "$f") 2>&1; info "log: $f"; }
wait_for_apt_lock(){ local t="${APT_LOCK_TIMEOUT_SECONDS:-300}" e=0; while "${SUDO[@]}" fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do ((e==0)) && warn "package manager busy; waiting up to ${t}s"; ((e>=t)) && die "apt/dpkg lock busy for ${t}s"; sleep 5; e=$((e+5)); done; }
apt_run(){ wait_for_apt_lock; "${SUDO[@]}" apt-get -o DPkg::Lock::Timeout=60 "$@"; }; apt_install_missing(){ local p; local -a m=(); for p in "$@"; do dpkg -s "$p" >/dev/null 2>&1 || m+=("$p"); done; ((${#m[@]})) && apt_run install -y "${m[@]}" || info 'requested packages already installed'; }
run_as_bench_user(){ local u="${BENCH_USER:-$(id -un)}"; [[ "$u" == "$(id -un)" ]] && "$@" || "${SUDO[@]}" -H -u "$u" -- "$@"; }
bench_cmd(){ local d="${BENCH_DIR:?BENCH_DIR not set}" u="${BENCH_USER:-$(id -un)}"; [[ -d "$d" ]] || die "Bench directory missing: $d"; if [[ "$u" == "$(id -un)" ]]; then (cd "$d" && PATH="$HOME/.local/bin:$PATH" "$@"); else "${SUDO[@]}" -H -u "$u" bash -lc 'cd "$1"; shift; export PATH="$HOME/.local/bin:$PATH"; exec "$@"' bash "$d" "$@"; fi; }
validate_app(){ local d="$1"; [[ -f "$d/pyproject.toml" && -f "$d/omc_app/__init__.py" && -f "$d/omc_app/hooks.py" && -f "$d/omc_app/modules.txt" ]] || die "invalid OMC app: $d"; }
normalize_apps_txt(){ local f="${BENCH_DIR}/sites/apps.txt" tmp; tmp="$(mktemp)"; find "${BENCH_DIR}/apps" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -u > "$tmp"; grep -qx frappe "$tmp" || printf 'frappe\n' >> "$tmp"; grep -qx omc_app "$tmp" || printf 'omc_app\n' >> "$tmp"; sort -u "$tmp" > "$f"; rm -f "$tmp"; }
ensure_custom_app(){ local s="${APP_SOURCE_DIR:?APP_SOURCE_DIR not set}" d="${BENCH_DIR}/apps/omc_app"; validate_app "$s"; if [[ "$(readlink -f "$s")" != "$(readlink -f "$d")" ]]; then rm -rf "$d"; cp -a "$s" "$d"; fi; validate_app "$d"; bench_cmd ./env/bin/pip install -e apps/omc_app; normalize_apps_txt; }
ensure_db_admin(){ local f="$SECRETS_DIR/production.env"; umask 077; if [[ -z "${FRAPPE_DB_ADMIN_PASSWORD:-}" ]]; then FRAPPE_DB_ADMIN_PASSWORD="$(random_secret)"; printf 'FRAPPE_DB_ADMIN_PASSWORD=%q\n' "$FRAPPE_DB_ADMIN_PASSWORD" >> "$f"; chmod 600 "$f"; fi; "${SUDO[@]}" mariadb <<SQL
CREATE USER IF NOT EXISTS 'frappe_admin'@'localhost' IDENTIFIED BY '${FRAPPE_DB_ADMIN_PASSWORD}';
ALTER USER 'frappe_admin'@'localhost' IDENTIFIED BY '${FRAPPE_DB_ADMIN_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'frappe_admin'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
}
site_exists(){ [[ -d "$BENCH_DIR/sites/$1" ]]; }
