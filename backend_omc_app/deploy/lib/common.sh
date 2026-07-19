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
  if ((