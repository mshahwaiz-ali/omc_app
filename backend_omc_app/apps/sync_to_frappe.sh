#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC="$BACKEND_DIR/apps/omc_app/"
DST="$BACKEND_DIR/frappe-bench/apps/omc_app/"

echo "Sync FROM repo app TO Frappe bench app"
echo "SRC: $SRC"
echo "DST: $DST"

if [ ! -d "$SRC" ]; then
  echo "ERROR: Source app folder not found: $SRC"
  exit 1
fi

mkdir -p "$DST"

rsync -a --delete \
  --exclude ".git/" \
  --exclude "__pycache__/" \
  --exclude "*.pyc" \
  --exclude ".pytest_cache/" \
  --exclude ".mypy_cache/" \
  "$SRC" "$DST"

echo "Done: Repo omc_app synced to Frappe bench omc_app."
