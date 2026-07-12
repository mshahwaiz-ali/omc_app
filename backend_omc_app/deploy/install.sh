#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; source "$SCRIPT_DIR/lib/common.sh"
setup_log install; need_sudo; load_config
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"; NODE_MAJOR="${NODE_MAJOR:-18}"; BENCH_USER="${BENCH_USER:-$USER}"; BENCH_DIR="${BENCH_DIR:-$BACKEND_DIR/frappe-bench}"; APP_SOURCE_DIR="${APP_SOURCE_DIR:-$BACKEND_DIR/apps/omc_app}"
source /etc/os-release; [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || warn 'Designed and tested for Ubuntu 24.04'
"${SUDO[@]}" apt-get update
apt_install_missing git curl ca-certificates gnupg build-essential pkg-config python3 python3-dev python3-pip python3-venv python3-setuptools pipx mariadb-server mariadb-client redis-server nginx supervisor libffi-dev libssl-dev libmariadb-dev libjpeg-dev zlib1g-dev liblcms2-dev libwebp-dev libtiff-dev libxrender1 libxext6 fontconfig xfonts-75dpi xfonts-base wkhtmltopdf
if ! have node || [[ "$(node -p 'process.versions.node.split(`.`)[0]')" != "$NODE_MAJOR" ]]; then curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | "${SUDO[@]}" -E bash -; apt_install_missing nodejs; fi
have yarn || "${SUDO[@]}" npm install -g yarn
have uv || curl -LsSf https://astral.sh/uv/install.sh | sh
run_as_bench_user python3 -m pipx ensurepath || true
run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; command -v bench >/dev/null || python3 -m pipx install frappe-bench'
"${SUDO[@]}" systemctl enable --now mariadb redis-server nginx supervisor
if [[ -d "$BENCH_DIR/apps/frappe" ]]; then ok "healthy Bench preserved: $BENCH_DIR"; else
  if [[ -e "$BENCH_DIR" && -n "$(find "$BENCH_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then die "Bench path is non-empty and not healthy; inspect manually: $BENCH_DIR"; fi
  mkdir -p "$(dirname "$BENCH_DIR")"; run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; bench init --frappe-branch "$1" "$2"' bash "$FRAPPE_BRANCH" "$BENCH_DIR"
fi
validate_app "$APP_SOURCE_DIR"
ensure_db_admin
ok 'base installation complete; custom app source was validated and preserved'
