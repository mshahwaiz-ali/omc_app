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
BENCH_USER="${BENCH_USER:-$(id -un)}"
BENCH_DIR="${BENCH_DIR:-/home/$BENCH_USER/frappe-bench}"
APP_SOURCE_DIR="${APP_SOURCE_DIR:-$BACKEND_DIR/frappe-bench/apps/omc_app}"

[[ "$BENCH_DIR" = /* ]] || die "BENCH_DIR must be an absolute path: $BENCH_DIR"
[[ "$APP_SOURCE_DIR" = /* ]] || die "APP_SOURCE_DIR must be an absolute path: $APP_SOURCE_DIR"
[[ "$(readlink -m "$BENCH_DIR")" != "$(readlink -m "$APP_SOURCE_DIR")" ]] || die 'BENCH_DIR and APP_SOURCE_DIR must be different paths'
[[ -f /etc/os-release ]] || die '/etc/os-release is missing'

source /etc/os-release
[[ "${ID:-}" == ubuntu ]] || die 'this production installer supports Ubuntu only'
[[ "${VERSION_ID:-}" == 24.04 ]] || warn "designed and tested for Ubuntu 24.04; detected ${VERSION_ID:-unknown}"
id "$BENCH_USER" >/dev/null 2>&1 || die "deployment user does not exist: $BENCH_USER"
validate_app "$APP_SOURCE_DIR"

info "deployment user: $BENCH_USER"
info "runtime Bench: $BENCH_DIR"
info "OMC app source: $APP_SOURCE_DIR"
info "Node.js major version: $NODE_MAJOR"

export DEBIAN_FRONTEND=noninteractive
"${SUDO[@]}" apt-get update
apt_install_missing \
  git curl ca-certificates gnupg build-essential pkg-config \
  python3 python3-dev python3-pip python3-venv python3-setuptools pipx \
  mariadb-server mariadb-client redis-server nginx supervisor \
  libffi-dev libssl-dev libmariadb-dev libjpeg-dev zlib1g-dev \
  liblcms2-dev libwebp-dev libtiff-dev libxrender1 libxext6 \
  fontconfig xfonts-75dpi xfonts-base wkhtmltopdf

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

if [[ -d "$BENCH_DIR/apps/frappe" && -d "$BENCH_DIR/sites" ]]; then
  ok "healthy Bench preserved: $BENCH_DIR"
elif [[ -e "$BENCH_DIR" && -n "$(find "$BENCH_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  die "Bench path is non-empty and not healthy; inspect manually: $BENCH_DIR"
else
  "${SUDO[@]}" install -d -o "$BENCH_USER" -g "$BENCH_USER" "$(dirname "$BENCH_DIR")"
  run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; bench init --frappe-branch "$1" "$2"' bash "$FRAPPE_BRANCH" "$BENCH_DIR"
fi

ok 'production prerequisites and runtime Bench are ready; no site or database was created'
