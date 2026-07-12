#!/usr/bin/env bash
set -Eeuo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$TOOLKIT_DIR/config"
SECRETS_DIR="$TOOLKIT_DIR/.secrets"
STATE_DIR="$TOOLKIT_DIR/.state"
LOG_DIR="$TOOLKIT_DIR/logs"
BACKUP_DIR="$TOOLKIT_DIR/backups"

mkdir -p "$SECRETS_DIR/sites" "$STATE_DIR" "$LOG_DIR" "$BACKUP_DIR"
chmod 700 "$SECRETS_DIR" "$SECRETS_DIR/sites" 2>/dev/null || true

info(){ printf '[INFO] %s\n' "$*"; }
ok(){ printf '[OK] %s\n' "$*"; }
warn(){ printf '[WARN] %s\n' "$*" >&2; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
section(){ printf '\n==== %s ====\n' "$*"; }
confirm(){ local p d a; p="$1"; d="${2:-N}"; read -r -p "$p [$d]: " a; a="${a:-$d}"; [[ "$a" =~ ^[Yy]$ ]]; }
prompt(){ local __v p d x; __v="$1"; p="$2"; d="${3:-}"; read -r -p "$p${d:+ [$d]}: " x; printf -v "$__v" '%s' "${x:-$d}"; }
prompt_secret(){ local __v p x; __v="$1"; p="$2"; read -r -s -p "$p: " x; printf '\n'; printf -v "$__v" '%s' "$x"; }
random_secret(){ openssl rand -base64 36 | tr -d '\n' | tr '/+' '_-' | cut -c1-40; }
safe_name(){ printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '_'; }

load_env(){ local f; f="$1"; [[ -f "$f" ]] || return 0; set -a; source "$f"; set +a; }
load_mode_config(){ local mode; mode="$1"; load_env "$CONFIG_DIR/${mode}.env"; load_env "$SECRETS_DIR/${mode}.env"; }
state_file(){ printf '%s/%s.state' "$STATE_DIR" "$(safe_name "$1")"; }
step_done(){ local scope step f; scope="$1"; step="$2"; f="$(state_file "$scope")"; grep -Fxq "$step" "$f" 2>/dev/null; }
mark_done(){ local scope step f; scope="$1"; step="$2"; f="$(state_file "$scope")"; touch "$f"; grep -Fxq "$step" "$f" 2>/dev/null || printf '%s\n' "$step" >> "$f"; }
run_step(){ local scope step; scope="$1"; step="$2"; shift 2; if step_done "$scope" "$step"; then info "skip completed: $step"; return 0; fi; info "run: $step"; "$@"; mark_done "$scope" "$step"; }
reset_state(){ rm -f "$(state_file "$1")"; }
setup_log(){ local name file; name="$1"; file="$LOG_DIR/${name}-$(date +%Y%m%d-%H%M%S).log"; touch "$file"; exec > >(tee -a "$file") 2>&1; info "log: $file"; }

require_ubuntu_debian(){ [[ -r /etc/os-release ]] || die 'Cannot detect operating system.'; source /etc/os-release; case "${ID:-}" in ubuntu|debian) ;; *) die "Unsupported OS: ${ID:-unknown}. Use Ubuntu or Debian.";; esac; }
need_sudo(){
  if [[ $EUID -eq 0 ]]; then
    SUDO=()
    return 0
  fi
  have sudo || die 'sudo is required'
  if sudo -n true 2>/dev/null; then
    SUDO=(sudo)
    return 0
  fi
  sudo -v || die 'sudo authentication failed'
  SUDO=(sudo)
}
apt_install_missing(){ local p; local -a missing=(); for p in "$@"; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done; ((${#missing[@]}==0)) && { info 'all apt packages already installed'; return; }; "${SUDO[@]}" apt-get install -y "${missing[@]}"; }

run_as_bench_user(){ local user; user="${BENCH_USER:-$(id -un)}"; if [[ "$user" == "$(id -un)" ]]; then "$@"; else sudo -H -u "$user" -- "$@"; fi; }
bench_cmd(){ local bench_dir user; bench_dir="${BENCH_DIR:?BENCH_DIR not set}"; user="${BENCH_USER:-$(id -un)}"; if [[ "$user" == "$(id -un)" ]]; then (cd "$bench_dir" && "$@"); else sudo -H -u "$user" bash -c 'cd "$1"; shift; exec "$@"' bash "$bench_dir" "$@"; fi; }
site_exists(){ [[ -d "${BENCH_DIR:?}/sites/$1" ]]; }
site_secret_file(){ printf '%s/sites/%s.env' "$SECRETS_DIR" "$(safe_name "$1")"; }
write_secret_file(){ local file; file="$1"; shift; umask 077; : > "$file"; while (($#)); do printf '%s=%q\n' "$1" "$2" >> "$file"; shift 2; done; chmod 600 "$file"; }

schedule_secret_cleanup(){ local file hours; file="$1"; hours="${2:-24}"; if have systemd-run; then systemd-run --user --unit="frappe-secret-cleanup-$(date +%s)" --on-active="${hours}h" /bin/rm -f "$file" >/dev/null 2>&1 && { info "temporary credential note scheduled for deletion in ${hours}h"; return; }; fi; warn "automatic cleanup unavailable; delete manually: $file"; }
create_credential_note(){ local site env admin dbuser dbpass file; site="$1"; env="$2"; admin="$3"; dbuser="$4"; dbpass="$5"; file="$SECRETS_DIR/credentials-$(safe_name "$site").txt"; umask 077; cat > "$file" <<NOTE
Site: $site
Environment: $env
Administrator user: Administrator
Administrator password: $admin
Database user: $dbuser
Database password: $dbpass
Created: $(date -Is)
Delete this file after recording the credentials securely.
NOTE
chmod 600 "$file"; printf '%s' "$file"; }
cleanup_old_backups(){ local days; days="${BACKUP_RETENTION_DAYS:-14}"; find "$BACKUP_DIR" -type f -mtime "+$days" -delete 2>/dev/null || true; }
