#!/usr/bin/env bash
set -Eeuo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$(cd "$TOOLKIT_DIR/.." && pwd)"
REPO_DIR="$(cd "$BACKEND_DIR/.." && pwd)"
CONFIG_DIR="$TOOLKIT_DIR/config"
SECRETS_DIR="$TOOLKIT_DIR/.secrets"
LOG_DIR="$TOOLKIT_DIR/logs"
BACKUP_DIR="$TOOLKIT_DIR/backups"

mkdir -p "$SECRETS_DIR" "$LOG_DIR" "$BACKUP_DIR"
chmod 700 "$SECRETS_DIR" 2>/dev/null || true

info(){ printf '[INFO] %s\n' "$*"; }
ok(){ printf '[OK] %s\n' "$*"; }
warn(){ printf '[WARN] %s\n' "$*" >&2; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

need_sudo(){
  if ((EUID == 0)); then
    SUDO=()
    return 0
  fi
  have sudo || die 'sudo is required'
  sudo -n true 2>/dev/null || die 'passwordless sudo is required for unattended deployment; configure sudoers before running this script'
  SUDO=(sudo -n)
}

load_env(){ [[ -f "$1" ]] || return 0; set -a; source "$1"; set +a; }
load_config(){ load_env "$CONFIG_DIR/production.env"; load_env "$SECRETS_DIR/production.env"; }
random_secret(){ openssl rand -base64 48 | tr -d '\n' | tr '/+' '_-' | cut -c1-48; }
setup_log(){ local f="$LOG_DIR/$1-$(date +%Y%m%d-%H%M%S).log"; touch "$f"; exec > >(tee -a "$f") 2>&1; info "log: $f"; }

wait_for_apt_lock(){
  local timeout="${APT_LOCK_TIMEOUT_SECONDS:-300}" elapsed=0 interval=5 holder=""
  while "${SUDO[@]}" fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
    if ((elapsed == 0)); then
      holder="$("${SUDO[@]}" fuser -v /var/lib/dpkg/lock-frontend 2>&1 || true)"
      warn "package manager is busy; waiting up to ${timeout}s for the apt/dpkg lock"
      [[ -n "$holder" ]] && printf '%s\n' "$holder" >&2
    fi
    ((elapsed >= timeout)) && die "apt/dpkg lock remained busy for ${timeout}s; allow unattended upgrades to finish, then rerun"
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  ((elapsed > 0)) && ok "apt/dpkg lock released after ${elapsed}s"
  return 0
}

apt_run(){ wait_for_apt_lock; "${SUDO[@]}" apt-get -o DPkg::Lock::Timeout=60 "$@"; }
apt_install_missing(){
  local p
  local -a missing=()
  for p in "$@"; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done
  if ((${#missing[@]})); then apt_run install -y "${missing[@]}"; else info 'requested packages already installed'; fi
}

run_as_bench_user(){
  local u="${BENCH_USER:-$(id -un)}"
  if [[ "$u" == "$(id -un)" ]]; then "$@"; else "${SUDO[@]}" -H -u "$u" -- "$@"; fi
}

bench_cmd(){
  local d="${BENCH_DIR:?BENCH_DIR not set}" u="${BENCH_USER:-$(id -un)}"
  [[ -d "$d" ]] || die "Bench directory missing: $d"
  if [[ "$u" == "$(id -un)" ]]; then
    (cd "$d" && PATH="$HOME/.local/bin:$PATH" "$@")
  else
    "${SUDO[@]}" -H -u "$u" bash -lc 'cd "$1"; shift; export PATH="$HOME/.local/bin:$PATH"; exec "$@"' bash "$d" "$@"
  fi
}

validate_app(){ local d="$1"; [[ -f "$d/pyproject.toml" ]] || die "missing $d/pyproject.toml"; [[ -f "$d/omc_app/__init__.py" ]] || die "missing omc_app/__init__.py"; [[ -f "$d/omc_app/hooks.py" ]] || die "missing omc_app/hooks.py"; [[ -f "$d/omc_app/modules.txt" ]] || die "missing omc_app/modules.txt"; }
normalize_apps_txt(){ local f="${BENCH_DIR}/sites/apps.txt" tmp; mkdir -p "$(dirname "$f")"; tmp="$(mktemp)"; { [[ -f "$f" ]] && tr -d '\r' < "$f" | sed 's/frappeomc_app/frappe\nomc_app/g' || true; printf 'frappe\nomc_app\n'; } | awk 'NF && !seen[$0]++' > "$tmp"; awk 'NF{print}' "$tmp" > "$tmp.clean"; printf '\n' >> "$tmp.clean"; mv "$tmp.clean" "$f"; rm -f "$tmp"; }
ensure_custom_app(){ local src="${APP_SOURCE_DIR:?APP_SOURCE_DIR not set}" dst="${BENCH_DIR}/apps/omc_app" stamp; validate_app "$src"; if [[ -e "$dst" ]]; then if [[ "$(readlink -f "$src")" == "$(readlink -f "$dst")" ]]; then info 'custom app already linked'; else validate_app "$dst" || { stamp="$(date +%s)"; mv "$dst" "${dst}.failed.${stamp}"; cp -a "$src" "$dst"; }; fi; else cp -a "$src" "$dst"; fi; validate_app "$dst"; bench_cmd ./env/bin/pip install -e apps/omc_app; normalize_apps_txt; }
ensure_db_admin(){ local f="$SECRETS_DIR/production.env"; umask 077; if [[ -z "${FRAPPE_DB_ADMIN_PASSWORD:-}" ]]; then FRAPPE_DB_ADMIN_PASSWORD="$(random_secret)"; printf 'FRAPPE_DB_ADMIN_PASSWORD=%q\n' "$FRAPPE_DB_ADMIN_PASSWORD" >> "$f"; chmod 600 "$f"; fi; "${SUDO[@]}" mariadb <<SQL
CREATE USER IF NOT EXISTS 'frappe_admin'@'localhost' IDENTIFIED BY '${FRAPPE_DB_ADMIN_PASSWORD}';
ALTER USER 'frappe_admin'@'localhost' IDENTIFIED BY '${FRAPPE_DB_ADMIN_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'frappe_admin'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
mariadb -u frappe_admin -p"$FRAPPE_DB_ADMIN_PASSWORD" -h localhost -e 'SELECT 1' >/dev/null || die 'frappe_admin authentication failed'; }
site_exists(){ [[ -d "$BENCH_DIR/sites/$1" ]]; }
