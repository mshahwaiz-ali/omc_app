#!/usr/bin/env bash
set -Eeuo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; source "$D/lib/common.sh"; load_config; setup_log install; need_sudo
F="${FRAPPE_BRANCH:-version-15}"; N="${NODE_MAJOR:-20}"; P="${PYTHON_VERSION:-3.12}"; U="${BENCH_USER:-$(id -un)}"
B="${BENCH_DIR:-$BACKEND_DIR/frappe-bench}"; A="${APP_SOURCE_DIR:-$B/apps/omc_app}"; S="${MIN_SWAP_MB:-2048}"; export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=1536}"
[[ "$B" = /* && "$A" = /* ]] || die 'BENCH_DIR and APP_SOURCE_DIR must be absolute'; validate_app "$A"; id "$U" >/dev/null || die "missing user: $U"
info "runtime Bench: $B"; info "OMC app source: $A"; info "Node.js: $N; Python: $P"
export DEBIAN_FRONTEND=noninteractive; apt_run update
apt_install_missing git curl ca-certificates gnupg build-essential pkg-config python3 python3-dev python3-pip python3-venv python3-setuptools pipx mariadb-server mariadb-client redis-server nginx supervisor libffi-dev libssl-dev libmariadb-dev libjpeg-dev zlib1g-dev liblcms2-dev libwebp-dev libtiff-dev libxrender1 libxext6 fontconfig xfonts-75dpi xfonts-base
c=""; have node && c="$(node -p 'process.versions.node.split(`.`)[0]')"; [[ "$c" == "$N" ]] || { curl -fsSL "https://deb.nodesource.com/setup_${N}.x" | "${SUDO[@]}" bash -; apt_install_missing nodejs; }; have yarn || "${SUDO[@]}" npm i -g yarn
have uv || run_as_bench_user bash -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh'; run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; uv python install "$1"' bash "$P"
PY="$(run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; uv python find "$1"' bash "$P")"; [[ -x "$PY" ]] || die 'managed Python missing'
run_as_bench_user python3 -m pipx ensurepath || true; run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; command -v bench >/dev/null || python3 -m pipx install frappe-bench'
"${SUDO[@]}" systemctl enable --now mariadb redis-server nginx supervisor
m="$(free -m | awk '/^Swap:/{print $2}')"; if ((m+32<S)); then
  if "${SUDO[@]}" swapon --show=NAME --noheadings | grep -qx '/swapfile'; then warn "active /swapfile is smaller than requested (${m}MiB); preserving it"; else
    [[ ! -e /swapfile ]] || "${SUDO[@]}" rm -f /swapfile; "${SUDO[@]}" fallocate -l "${S}M" /swapfile || "${SUDO[@]}" dd if=/dev/zero of=/swapfile bs=1M count="$S" status=none
    "${SUDO[@]}" chmod 600 /swapfile; "${SUDO[@]}" mkswap /swapfile >/dev/null; "${SUDO[@]}" swapon /swapfile; grep -qF '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' | "${SUDO[@]}" tee -a /etc/fstab >/dev/null
  fi
fi
healthy(){ [[ -d "$1/apps/frappe" && -d "$1/sites" && -x "$1/env/bin/python" && -f "$1/sites/apps.txt" ]]; }
if ! healthy "$B"; then
  T="${B}.source.$(date +%s)"; [[ -d "$B" ]] || die "source Bench missing: $B"; mv "$B" "$T"; trap '[[ -d "$T" && ! -d "$B" ]] && mv "$T" "$B"' EXIT
  run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH" NODE_OPTIONS="$4"; printf "y\n" | bench init --no-procfile --no-backups --frappe-branch "$1" --python "$2" "$3"' bash "$F" "$PY" "$B" "$NODE_OPTIONS" || { rm -rf "$B"; die 'Bench initialization failed'; }
  cp -a "$T/apps/omc_app" "$B/apps/omc_app"; rm -rf "$T"; trap - EXIT
fi
healthy "$B" || die 'runtime Bench validation failed'; bench_cmd ./env/bin/pip install -e apps/omc_app; bench_cmd ./env/bin/python -c 'import frappe,omc_app; print(frappe.__version__)'
for x in mariadb redis-server nginx supervisor; do "${SUDO[@]}" systemctl is-active --quiet "$x" || die "$x inactive"; done
ok 'production dependencies and runtime Bench are ready; no site or database was created'
