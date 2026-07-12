#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; source "$SCRIPT_DIR/lib/common.sh"
MODE=local
while (($#)); do case "$1" in --mode) MODE="${2:?}"; shift 2;; --reset-state) reset_state "install-${MODE}"; shift;; -h|--help) echo 'Usage: ./install.sh --mode local|production [--reset-state]'; exit;; *) die "Unknown option: $1";; esac; done
[[ "$MODE" =~ ^(local|production)$ ]] || die 'Mode must be local or production.'
setup_log "install-$MODE"; require_ubuntu_debian; need_sudo
load_env "$CONFIG_DIR/installer.env"; load_mode_config "$MODE"
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"; NODE_MAJOR="${NODE_MAJOR:-22}"; BENCH_USER="${BENCH_USER:-$USER}"; BENCH_DIR="${BENCH_DIR:-$HOME/frappe-bench}"
SCOPE="install-$MODE"

install_packages(){ "${SUDO[@]}" apt-get update; apt_install_missing git curl ca-certificates gnupg build-essential pkg-config python3 python3-dev python3-pip python3-venv python3-setuptools pipx redis-server mariadb-server mariadb-client libffi-dev libssl-dev libmariadb-dev libjpeg-dev zlib1g-dev liblcms2-dev libwebp-dev libtiff-dev libxrender1 libxext6 fontconfig xfonts-75dpi xfonts-base wkhtmltopdf cron; [[ "$MODE" == production ]] && apt_install_missing nginx supervisor certbot python3-certbot-nginx ufw logrotate; }
create_user(){ [[ "$MODE" != production || "${CREATE_FRAPPE_USER:-yes}" != yes ]] && return; id "$BENCH_USER" >/dev/null 2>&1 || "${SUDO[@]}" useradd -m -s /bin/bash "$BENCH_USER"; "${SUDO[@]}" mkdir -p "$BENCH_DIR"; "${SUDO[@]}" chown -R "$BENCH_USER:$BENCH_USER" "$(dirname "$BENCH_DIR")"; }
install_node(){ if have node && [[ "$(node -p 'process.versions.node.split(`.`)[0]')" == "$NODE_MAJOR" ]]; then info "Node $NODE_MAJOR already installed"; return; fi; curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | "${SUDO[@]}" -E bash -; apt_install_missing nodejs; "${SUDO[@]}" corepack enable || true; have yarn || "${SUDO[@]}" npm install -g yarn; }
install_bench(){ if run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; command -v bench >/dev/null 2>&1'; then info 'bench already installed for configured user'; return; fi; run_as_bench_user bash -lc 'python3 -m pipx ensurepath; python3 -m pipx install frappe-bench'; run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; command -v bench >/dev/null' || die 'bench CLI installation failed'; }
configure_db(){ local cnf=/etc/mysql/mariadb.conf.d/60-frappe.cnf; if [[ ! -f "$cnf" ]]; then "${SUDO[@]}" tee "$cnf" >/dev/null <<DB
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
[mysql]
default-character-set = utf8mb4
DB
fi; "${SUDO[@]}" systemctl enable --now mariadb redis-server; "${SUDO[@]}" systemctl restart mariadb; sudo mariadb -e 'SELECT 1;' >/dev/null || warn 'Socket authentication failed; site_setup.sh will request MariaDB admin credentials.'; }
init_bench(){ [[ -d "$BENCH_DIR/apps/frappe" ]] && { info "bench already initialized: $BENCH_DIR"; return; }; if [[ -e "$BENCH_DIR" && -n "$(find "$BENCH_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then local q="${BENCH_DIR}.partial.$(date +%s)"; warn "quarantining partial bench directory to $q"; "${SUDO[@]}" mv "$BENCH_DIR" "$q"; fi; "${SUDO[@]}" mkdir -p "$(dirname "$BENCH_DIR")"; "${SUDO[@]}" chown -R "$BENCH_USER:$BENCH_USER" "$(dirname "$BENCH_DIR")"; run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; bench init --frappe-branch "$1" "$2"' bash "$FRAPPE_BRANCH" "$BENCH_DIR"; }

run_step "$SCOPE" packages install_packages
run_step "$SCOPE" user create_user
run_step "$SCOPE" node install_node
run_step "$SCOPE" bench-cli install_bench
run_step "$SCOPE" mariadb configure_db
run_step "$SCOPE" bench-init init_bench
BENCH_VERSION="$(run_as_bench_user bash -lc 'export PATH="$HOME/.local/bin:$PATH"; bench --version')"
section 'Environment summary'; printf 'Mode: %s\nBench user: %s\nBench: %s\nFrappe branch: %s\nNode: %s\nBench CLI: %s\n' "$MODE" "$BENCH_USER" "$BENCH_DIR" "$FRAPPE_BRANCH" "$(node -v)" "$BENCH_VERSION"
printf '\nInstallation complete.\n\nNext:\n./site_setup.sh new --mode %s\n' "$MODE"
