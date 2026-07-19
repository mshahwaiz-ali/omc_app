#!/usr/bin/env bash
set -Eeuo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; source "$D/lib/common.sh"; load_config; setup_log install; need_sudo
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"; NODE_MAJOR="${NODE_MAJOR:-20}"; PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
BENCH_USER="${BENCH_USER:-$(id -un)}"; BENCH_DIR="${BENCH_DIR:-/home/$BENCH_USER/frappe-bench}"
APP_SOURCE_DIR="${APP_SOURCE_DIR:-$BACKEND_DIR/frappe-bench/apps/omc_app}"; PYTHON_BIN="${PYTHON_BIN:-}"
MIN_SWAP_MB="${MIN_SWAP_MB:-2048}"; SWAPFILE_PATH="${SWAPFILE_PATH:-/swapfile}"; export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=1536}"
[[ "$BENCH_DIR" = /* && "$APP_SOURCE_DIR" = /* ]] || die 'BENCH_DIR and APP_SOURCE_DIR must be absolute'
source /etc/os-release; [[ "${ID:-}" == ubuntu ]] || die 'Ubuntu is required'; id "$BENCH_USER" >/dev/null || die "deployment user missing: $BENCH_USER"; validate_app "$APP_SOURCE_DIR"
info "deployment user: $BENCH_USER"; info "runtime Bench: $BENCH_DIR"; info "OMC app source: $APP_SOURCE_DIR"; info "Node.js: $NODE_MAJOR; Python: $PYTHON_VERSION"
export DEBIAN_FRONTEND=noninteractive
apt_run update
apt_install_missing git curl ca-certificates gnupg build-essential pkg-config python3 python3-dev python3-pip python3-venv python3-setuptools pipx mariadb-server mariadb-client redis-server nginx supervisor libffi-dev libssl-dev libmariadb-dev libjpeg-dev zlib1g-dev liblcms2-dev libwebp-dev libtiff-dev libxrender1 libxext6 fontconfig xfonts-75dpi xfonts-base
cur=""; have node && cur="$(node -p 'process.versions.node.split(`.`)[0]')"; if [[ "$cur" != "$NODE_MAJOR" ]]; then curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | "${SUDO[@]}" bash -; apt_install_missing nodejs; fi
have yarn || "${SUDO[@]}" npm install -g yarn
have uv || run_as_bench_user bash -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh'
run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; uv python install "$1"' bash "$PYTHON_VERSION"
[[ -n "$PYTHON_BIN" ]] || PYTHON_BIN="$(run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; uv python find "$1"' bash "$PYTHON_VERSION")"
[[ -x "$PYTHON_BIN" ]] || die "managed Python missing: $PYTHON_BIN"; "$PYTHON_BIN" --version
run_as_bench_user python3 -m pipx ensurepath || true
run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; command -v bench >/dev/null || python3 -m pipx install frappe-bench'
"${SUDO[@]}" systemctl enable --now mariadb redis-server nginx supervisor
swap_mb="$(free -m | awk '/^Swap:/{print $2}')"; if ((swap_mb < MIN_SWAP_MB)); then
  [[ ! -e "$SWAPFILE_PATH" ]] || "${SUDO[@]}" swapoff "$SWAPFILE_PATH" 2>/dev/null || true
  "${SUDO[@]}" rm -f "$SWAPFILE_PATH"; "${SUDO[@]}" fallocate -l "${MIN_SWAP_MB}M" "$SWAPFILE_PATH" || "${SUDO[@]}" dd if=/dev/zero of="$SWAPFILE_PATH" bs=1M count="$MIN_SWAP_MB" status=none
  "${SUDO[@]}" chmod 600 "$SWAPFILE_PATH"; "${SUDO[@]}" mkswap "$SWAPFILE_PATH" >/dev/null; "${SUDO[@]}" swapon "$SWAPFILE_PATH"; grep -qF "$SWAPFILE_PATH none swap sw 0 0" /etc/fstab || printf '%s\n' "$SWAPFILE_PATH none swap sw 0 0" | "${SUDO[@]}" tee -a /etc/fstab >/dev/null
fi
free -h
healthy(){ [[ -d "$1/apps/frappe" && -d "$1/sites" && -x "$1/env/bin/python" && -f "$1/sites/apps.txt" ]]; }
if healthy "$BENCH_DIR"; then ok "healthy Bench preserved: $BENCH_DIR"; elif [[ -e "$BENCH_DIR" && -n "$(find "$BENCH_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then die "unhealthy Bench exists: $BENCH_DIR"; else
  parent="$(dirname "$BENCH_DIR")"; stage="$parent/.$(basename "$BENCH_DIR").installing.$(date +%s)"; "${SUDO[@]}" install -d -o "$BENCH_USER" -g "$BENCH_USER" "$parent"; trap 'rm -rf "${stage:-}"' EXIT
  if ! printf 'y\n' | run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH" NODE_OPTIONS="$4"; bench init --no-procfile --no-backups --frappe-branch "$1" --python "$2" "$3"' bash "$FRAPPE_BRANCH" "$PYTHON_BIN" "$stage" "$NODE_OPTIONS"; then die "Bench initialization failed: $stage"; fi
  healthy "$stage" || die "Bench initialization incomplete: $stage"; mv "$stage" "$BENCH_DIR"; trap - EXIT
fi
healthy "$BENCH_DIR" || die 'runtime Bench validation failed'; bench_cmd ./env/bin/python --version; bench_cmd ./env/bin/python -c 'import frappe; print(frappe.__version__)'
for s in mariadb redis-server nginx supervisor; do "${SUDO[@]}" systemctl is-active --quiet "$s" || die "$s inactive"; done
have wkhtmltopdf || warn 'wkhtmltopdf unavailable; PDF print generation disabled'
ok 'production dependencies and runtime Bench are ready; no site or database was created'
