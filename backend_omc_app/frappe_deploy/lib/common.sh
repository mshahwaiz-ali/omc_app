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