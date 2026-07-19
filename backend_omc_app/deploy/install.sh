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
PYTHON_BIN="${PYTHON_BIN:-python${PYTHON_VERSION}}"

[[ "$BENCH_DIR" = /* ]] || die "BENCH_DIR must be an absolute path: $BENCH_DIR"
[[ "$APP_SOURCE_DIR" = /* ]] || die "APP_SOURCE_DIR must be an absolute path: $APP_SOURCE_DIR"
[[ "$(readlink -m "$BENCH_DIR")" != "$(readlink -m "$APP_SOURCE_DIR")" ]] || die 'BENCH_DIR and APP_SOURCE_DIR must be different paths'
[[ -f /etc/os-release ]] || die '/etc/os-release is missing'

source /etc/os-release
[[ "${ID:-}" == ubuntu ]] || die 'this production installer supports Ubuntu only'
case "${VERSION_ID:-}" in
  24.04|26.04) ;;
  *) warn "tested on Ubuntu 24.04 and 26.04; detected ${VERSION_ID:-unknown}" ;;
esac

id "$BENCH_USER" >/dev/null 2>&1 || die "deployment user does not exist: $BENCH_USER"
validate_app "$APP_SOURCE_DIR"

info "deployment user: $BENCH_USER"
info "runtime Bench: $BENCH_DIR"
info "OMC app source: $APP_SOURCE_DIR"
info "Node.js major version: $NODE_MAJOR"
info "Python version: $PYTHON_VERSION"

export DEBIAN_FRONTEND=noninteractive
apt_run update
apt_install_missing \
  git curl ca-certificates gnupg build-essential pkg-config \
  python3 python3-dev python3-pip python3-venv python3-setuptools pipx \
  mariadb-server mariadb-client redis-server nginx supervisor \
  libffi-dev libssl-dev libmariadb-dev libjpeg-dev zlib1g-dev \
  liblcms2-dev libwebp-dev libtiff-dev libxrender1 libxext6 \
  fontconfig xfonts-75dpi xfonts-base

if ! have "$PYTHON_BIN"; then
  if apt-cache show "python${PYTHON_VERSION}" >/dev/null 2>&1; then
    apt_install_missing "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv"
  else
    die "Python ${PYTHON_VERSION} is required for Frappe v15 but is unavailable from configured Ubuntu repositories"
  fi
fi

"$PYTHON_BIN" --version

current_node_major=""
if have node; then
  current_node_major="$(node -p 'process.versions.node.split(`.`)[0]')"
fi
if [[ "$current_node_major" != "$NODE_MAJOR" ]]; then
  info "installing Node.js ${NODE_MAJOR}.x"
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | "${SUDO[@]}" bash -
  apt_install_missing nodejs
fi

have yarn || "${SUDO[@]}" npm install -g yarn
have uv || run_as_bench_user bash -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh'
run_as_bench_user python3 -m pipx ensurepath || true
run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; command -v bench >/dev/null || python3 -m pipx install frappe-bench'

"${SUDO[@]}" systemctl enable --now mariadb redis-server nginx supervisor

healthy_bench(){
  [[ -d "$1/apps/frappe" && -d "$1/sites" && -x "$1/env/bin/python" && -f "$1/sites/apps.txt" ]]
}

if healthy_bench "$BENCH_DIR"; then
  ok "healthy Bench preserved: $BENCH_DIR"
elif [[ -e "$BENCH_DIR" && -n "$(find "$BENCH_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  die "Bench path is non-empty and not healthy; inspect manually: $BENCH_DIR"
else
  parent_dir="$(dirname "$BENCH_DIR")"
  bench_name="$(basename "$BENCH_DIR")"
  staging_dir="${parent_dir}/.${bench_name}.installing.$(date +%s)"
  "${SUDO[@]}" install -d -o "$BENCH_USER" -g "$BENCH_USER" "$parent_dir"
  trap '[[ -n "${staging_dir:-}" && -d "$staging_dir" ]] && rm -rf "$staging_dir"' EXIT
  run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; bench init --no-procfile --no-backups --frappe-branch "$1" --python "$2" "$3"' bash "$FRAPPE_BRANCH" "$PYTHON_BIN" "$staging_dir"
  healthy_bench "$staging_dir" || die "Bench initialization did not produce a healthy runtime: $staging_dir"
  [[ ! -e "$BENCH_DIR" ]] || die "target Bench path appeared during installation: $BENCH_DIR"
  mv "$staging_dir" "$BENCH_DIR"
  trap - EXIT
fi

healthy_bench "$BENCH_DIR" || die "runtime Bench validation failed: $BENCH_DIR"
bench_cmd ./env/bin/python --version
bench_cmd ./env/bin/python -c 'import frappe; print(frappe.__version__)'
run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; command -v bench; bench --version; node --version; npm --version; yarn --version'

"${SUDO[@]}" systemctl is-active --quiet mariadb || die 'MariaDB is not active'
"${SUDO[@]}" systemctl is-active --quiet redis-server || die 'Redis is not active'
"${SUDO[@]}" systemctl is-active --quiet nginx || die 'Nginx is not active'
"${SUDO[@]}" systemctl is-active --quiet supervisor || die 'Supervisor is not active'

if have wkhtmltopdf; then
  ok "wkhtmltopdf available: $(wkhtmltopdf --version 2>&1 | head -n1)"
else
  warn 'wkhtmltopdf is unavailable from this Ubuntu release; core Frappe installation is complete, but PDF print generation requires a separately supported wkhtmltopdf package'
fi

ok 'production dependencies and runtime Bench are ready; no site or database was created'
