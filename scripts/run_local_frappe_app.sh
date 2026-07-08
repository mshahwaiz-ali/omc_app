#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper. Prefer scripts/run_dev_local.sh for new local runs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run_dev_local.sh" "$@"
