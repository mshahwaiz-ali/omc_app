#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="$REPO_ROOT/backend_omc_app/frappe-bench/apps/omc_app/scripts/configuration.sh"

[[ -f "$TARGET" ]] || {
    echo "ERROR: OMC configuration script not found: $TARGET" >&2
    exit 1
}

exec bash "$TARGET" "$@"
