#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

load_config
setup_log install
need_sudo

FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"
NODE_MAJOR="${NODE_MAJOR:-20}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
BENCH_USER="${BENCH_USER:-$(id -un)}"
BENCH_DIR="${BENCH_DIR:-/home/$BENCH_USER/frappe-bench}"
APP_SOURCE_DIR="${APP_SOURCE_DIR:-$BACKEND_DIR/frappe-bench/apps/omc_app}"
PYTHON_BIN="${PYTHON_BIN:-}"

[[ "$BENCH_DIR" = /* ]] || die "BENCH_DIR must be an absolute path: $BENCH_DIR"
[[ "$APP_SOURCE_DIR" = /* ]] || die "APP_SOURCE_DIR must be an absolute path: $APP_SOURCE_DIR"
[[ "$(readlink -