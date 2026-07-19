#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

load_config
setup_log production
need_sudo

BENCH_DIR="${BENCH_DIR:-}"
SITE_NAME="${SITE_NAME:-}"

[[ -n "$BENCH_DIR" ]] || die "BENCH_DIR is not set in deploy/config/production.env"
[[ -d "$BENCH_DIR" ]] || die "bench directory not found: $BENCH_DIR"
[[ -d "$BENCH_DIR/sites" ]] || die "not a runnable