#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
MIN_SWAP_MB="${MIN_SWAP_MB:-2048}"
SWAPFILE_PATH="${SWAPFILE_PATH:-/swapfile}"
NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=1536}"

[[ "$BENCH_DIR" = /* ]] || die "BENCH_DIR must be absolute: $BENCH_DIR"
[[ "$APP_SOURCE_DIR" = /* ]] || die "APP_SOURCE_DIR must be absolute: $APP_SOURCE_DIR"
[[ -f /etc/os-release ]] || die '/etc/os-release is missing'
source /etc/os-release
[[ "${ID:-}" == ubuntu ]] || die 'Ubuntu is required'
case "${VERSION_ID:-}" in 24.04|26.04) ;; *) warn "untested Ubuntu version: ${VERSION_ID:-unknown}" ;; esac
id "$BENCH_USER" >/dev/null 2>&1 || die "deployment user missing: $BENCH_USER"
validate_app "$APP_SOURCE_DIR"

info "deployment user: $BENCH_USER"
info "runtime Bench: $BENCH_DIR"
info "OMC app source: $APP_SOURCE_DIR"
info "Node.js major version: $NODE_MAJOR"
info "Python version: $PYTHON_VERSION"

export DEBIAN_FRONTEND=noninteractive
apt_run update
apt_install_missing git curl ca-certificates gnupg build-essential pkg-config python3 python3