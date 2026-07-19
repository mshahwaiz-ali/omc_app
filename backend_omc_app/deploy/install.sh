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
apt_install_missing git curl ca-certificates gnupg build-essential pkg-config python3 python3-dev python3-pip python3-venv python3-setuptools pipx mariadb-server mariadb-client redis-server nginx supervisor libffi-dev libssl-dev libmariadb-dev libjpeg-dev zlib1g-dev liblcms2-dev libwebp-dev libtiff-dev libxrender1 libxext6 fontconfig xfonts-75dpi xfonts-base

current_node=""
have node && current_node="$(node -p 'process.versions.node.split(`.`)[0]')"
if [[ "$current_node" != "$NODE_MAJOR" ]]; then
  info "installing Node.js ${NODE_MAJOR}.x"
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | "${SUDO[@]}" bash -
  apt_install_missing nodejs
fi
have yarn || "${SUDO[@]}" npm install -g yarn

have uv || run_as_bench_user bash -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh'
if [[ -z "$PYTHON_BIN" ]]; then
  run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; uv python install "$1"' bash "$PYTHON_VERSION"
  PYTHON_BIN="$(run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; uv python find "$1"' bash "$PYTHON_VERSION")"
fi
[[ -x "$PYTHON_BIN" ]] || die "managed Python not found: $PYTHON_BIN"
"$PYTHON_BIN" --version

run_as_bench_user python3 -m pipx ensurepath || true
run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; command -v bench >/dev/null || python3 -m pipx install frappe-bench'
"${SUDO[@]}" systemctl enable --now mariadb redis-server nginx supervisor

healthy_bench(){ [[ -d "$1/apps/frappe" && -d "$1/sites" && -x "$1/env/bin/python" && -f "$1/sites/apps.txt" ]]; }
if healthy_bench "$BENCH_DIR"; then
  ok "healthy Bench preserved: $BENCH_DIR"
elif [[ -e "$BENCH_DIR" && -n "$(find "$BENCH_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  die "Bench path is non-empty and unhealthy: $BENCH_DIR"
else
  parent="$(dirname "$BENCH_DIR")"
  stage="$parent/.$(basename "$BENCH_DIR").installing.$(date +%s)"
  "${SUDO[@]}" install -d -o "$BENCH_USER" -g "$BENCH_USER" "$parent"
  trap '[[ -n "${stage:-}" && -d "$stage" ]] && rm -rf "$stage"' EXIT
  run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; bench init --no-procfile --no-backups --frappe-branch "$1" --python "$2" "$3"' bash "$FRAPPE_BRANCH" "$PYTHON_BIN" "$stage"
  healthy_bench "$stage" || die "Bench initialization failed: $stage"
  [[ ! -e "$BENCH_DIR" ]] || die "target appeared during install: $BENCH_DIR"
  mv "$stage" "$BENCH_DIR"
  trap - EXIT
fi

healthy_bench "$BENCH_DIR" || die "runtime Bench validation failed: $BENCH_DIR"
bench_cmd ./env/bin/python --version
bench_cmd ./env/bin/python -c 'import frappe; print(frappe.__version__)'
run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; bench --version; node --version; npm --version; yarn --version'
"${SUDO[@]}" systemctl is-active --quiet mariadb || die 'MariaDB inactive'
"${SUDO[@]}" systemctl is-active --quiet redis-server || die 'Redis inactive'
"${SUDO[@]}" systemctl is-active --quiet nginx || die 'Nginx inactive'
"${SUDO[@]}" systemctl is-active --quiet supervisor || die 'Supervisor inactive'
have wkhtmltopdf || warn 'wkhtmltopdf unavailable; PDF print generation remains disabled'
ok 'production dependencies and runtime Bench are ready; no site or database was created'
