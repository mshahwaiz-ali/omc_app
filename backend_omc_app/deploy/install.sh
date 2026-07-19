#!/usr/bin/env bash
set -Eeuo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; source "$D/lib/common.sh"; load_config; setup_log install; need_sudo
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"; NODE_MAJOR="${NODE_MAJOR:-20}"; PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
BENCH_USER="${BENCH_USER:-$(id -un)}"; BENCH_DIR="${BENCH_DIR:-$BACKEND_DIR/frappe-bench}"
APP_SOURCE_DIR="${APP_SOURCE_DIR:-$BENCH_DIR/apps/omc_app}"; PY