#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

SRC_APPS_DIR="$ROOT_DIR/frappe-bench/apps"
DEST_APPS_DIR="$SCRIPT_DIR"

EXCLUDE_APPS=(
  "frappe"
  "erpnext"
  "payments"
  "hrms"
)

info() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

is_excluded_app() {
  local app="$1"
  local excluded=""

  for excluded in "${EXCLUDE_APPS[@]}"; do
    [[ "$app" == "$excluded" ]] && return 0
  done

  return 1
}

is_custom_frappe_app() {
  local app_dir="$1"
  local app_name=""

  [[ -d "$app_dir" ]] || return 1

  app_name="$(basename "$app_dir")"

  is_excluded_app "$app_name" && return 1

  # Frappe app usually has pyproject.toml/setup.py and a package folder.
  [[ -f "$app_dir/pyproject.toml" || -f "$app_dir/setup.py" ]] || return 1
  [[ -d "$app_dir/$app_name" ]] || return 1

  return 0
}

command -v rsync >/dev/null 2>&1 || die "rsync is required. Install with: sudo apt install rsync"

[[ -d "$SRC_APPS_DIR" ]] || die "Source apps folder not found: $SRC_APPS_DIR"
[[ -d "$DEST_APPS_DIR" ]] || die "Destination apps folder not found: $DEST_APPS_DIR"

info "Source apps:      $SRC_APPS_DIR"
info "Destination apps: $DEST_APPS_DIR"

synced_count=0

for src_app_dir in "$SRC_APPS_DIR"/*; do
  [[ -d "$src_app_dir" ]] || continue

  app_name="$(basename "$src_app_dir")"

  if ! is_custom_frappe_app "$src_app_dir"; then
    warn "Skipping: $app_name"
    continue
  fi

  dest_app_dir="$DEST_APPS_DIR/$app_name"

  info "Syncing custom app: $app_name"
  info "  From: $src_app_dir"
  info "  To:   $dest_app_dir"

  mkdir -p "$dest_app_dir"

  rsync -av --delete \
    --exclude='.git/' \
    --exclude='.venv/' \
    --exclude='env/' \
    --exclude='node_modules/' \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='*.pyo' \
    --exclude='.pytest_cache/' \
    --exclude='.mypy_cache/' \
    --exclude='.ruff_cache/' \
    --exclude='dist/' \
    --exclude='build/' \
    "$src_app_dir/" "$dest_app_dir/"

  synced_count=$((synced_count + 1))
done

ok "Sync complete. Custom apps synced: $synced_count"

if [[ -d "$ROOT_DIR/.git" ]]; then
  info "Root repo Git status for apps folder:"
  git -C "$ROOT_DIR" status --short -- apps
elif [[ -d "$DEST_APPS_DIR/.git" ]]; then
  info "Apps repo Git status:"
  git -C "$DEST_APPS_DIR" status --short
else
  warn "No Git repo found in $ROOT_DIR or $DEST_APPS_DIR."
fi
