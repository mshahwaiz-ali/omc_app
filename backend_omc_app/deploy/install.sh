#!/usr/bin/env bash
set -Eeuo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; source "$D/lib/common.sh"; load_config; setup_log install; need_sudo
F="${FRAPPE_BRANCH:-version-15}"; N="${NODE_MAJOR:-20}"; P="${PYTHON_VERSION:-3.12}"; U="${BENCH_USER:-$(id -un)}"
B="${BENCH_DIR:-$BACKEND_DIR/frappe-bench}"; A="${APP_SOURCE_DIR:-$B/apps/omc_app}"; S="${MIN_SWAP_MB:-2048}"; export NODE_OPTIONS="${