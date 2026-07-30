#!/usr/bin/env bash
set -Eeuo pipefail

D="$(cd "$(dirname "$0")" && pwd)"
source "$D/lib/common.sh"

load_config
setup_log install
need_sudo

# Client-compatible runtime.
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-14}"
NODE_MAJOR="${NODE_MAJOR:-18}"
PYTHON_VERSION="${PYTHON_VERSION:-3.10}"
BENCH_USER="${BENCH_USER:-$(id -un)}"

BENCH_DIR="${BENCH_DIR:-$BACKEND_DIR/frappe-bench}"
APP_SOURCE_DIR="${APP_SOURCE_DIR:-$BENCH_DIR/apps/omc_app}"
MIN_SWAP_MB="${MIN_SWAP_MB:-2048}"

export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=1536}"

[[ "$BENCH_DIR" = /* ]] ||
    die "BENCH_DIR must be an absolute path"

[[ "$APP_SOURCE_DIR" = /* ]] ||
    die "APP_SOURCE_DIR must be an absolute path"

id "$BENCH_USER" >/dev/null 2>&1 ||
    die "Bench user does not exist: $BENCH_USER"

info "Frappe branch: $FRAPPE_BRANCH"
info "Bench directory: $BENCH_DIR"
info "OMC App source: $APP_SOURCE_DIR"
info "Node.js major: $NODE_MAJOR"
info "Python version: $PYTHON_VERSION"

export DEBIAN_FRONTEND=noninteractive

apt_run update

apt_install_missing \
    git \
    curl \
    ca-certificates \
    gnupg \
    build-essential \
    pkg-config \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    python3-setuptools \
    pipx \
    mariadb-server \
    mariadb-client \
    redis-server \
    nginx \
    supervisor \
    libffi-dev \
    libssl-dev \
    libmariadb-dev \
    libjpeg-dev \
    zlib1g-dev \
    liblcms2-dev \
    libwebp-dev \
    libtiff-dev \
    libxrender1 \
    libxext6 \
    fontconfig \
    xfonts-75dpi \
    xfonts-base

install_node_runtime() {
    local current_major=""

    if have node; then
        current_major="$(node -p 'process.versions.node.split(".")[0]')"
    fi

    if [[ "$current_major" != "$NODE_MAJOR" ]]; then
        info "Installing Node.js ${NODE_MAJOR}.x"

        curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" |
            "${SUDO[@]}" bash -

        apt_run install -y nodejs
    fi

    local installed_major
    installed_major="$(node -p 'process.versions.node.split(".")[0]')"

    [[ "$installed_major" == "$NODE_MAJOR" ]] ||
        die "Expected Node.js ${NODE_MAJOR}.x, found $(node --version)"

    if ! have yarn; then
        "${SUDO[@]}" npm install -g yarn@1.22.22
    fi

    [[ "$(yarn --version)" == 1.22.* ]] ||
        die "Expected Yarn 1.22.x, found $(yarn --version)"

    info "Node.js: $(node --version)"
    info "Yarn: $(yarn --version)"
}

find_uv() {
    local candidate

    if have uv; then
        command -v uv
        return 0
    fi

    for candidate in \
        "$HOME/.local/bin/uv" \
        "$HOME"/snap/code/*/.local/bin/uv \
        "$HOME"/snap/code/*/.local/share/../bin/uv
    do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

install_uv_for_bench_user() {
    local uv_path

    if uv_path="$(find_uv 2>/dev/null)"; then
        printf '%s\n' "$uv_path"
        return 0
    fi

    info "Installing uv for $BENCH_USER"

    run_as_bench_user bash -lc '
        curl -LsSf https://astral.sh/uv/install.sh | sh
    '

    if uv_path="$(find_uv 2>/dev/null)"; then
        printf '%s\n' "$uv_path"
        return 0
    fi

    uv_path="$(
        run_as_bench_user bash -lc '
            for candidate in \
                "$HOME/.local/bin/uv" \
                "$HOME"/snap/code/*/.local/bin/uv \
                "$HOME"/snap/code/*/.local/share/../bin/uv
            do
                if [[ -x "$candidate" ]]; then
                    printf "%s\n" "$candidate"
                    exit 0
                fi
            done
            exit 1
        '
    )" || die "uv installation completed but executable was not found"

    printf '%s\n' "$uv_path"
}

ensure_swap() {
    local current_swap

    current_swap="$(free -m | awk '/^Swap:/{print $2}')"

    if ((current_swap + 32 >= MIN_SWAP_MB)); then
        info "Swap requirement already satisfied: ${current_swap} MiB"
        return 0
    fi

    if "${SUDO[@]}" swapon --show=NAME --noheadings |
        grep -qx "/swapfile"
    then
        warn "Active /swapfile is smaller than requested; preserving it"
        return 0
    fi

    info "Creating ${MIN_SWAP_MB} MiB swap file"

    [[ ! -e /swapfile ]] ||
        "${SUDO[@]}" rm -f /swapfile

    "${SUDO[@]}" fallocate -l "${MIN_SWAP_MB}M" /swapfile ||
        "${SUDO[@]}" dd \
            if=/dev/zero \
            of=/swapfile \
            bs=1M \
            count="$MIN_SWAP_MB" \
            status=none

    "${SUDO[@]}" chmod 600 /swapfile
    "${SUDO[@]}" mkswap /swapfile >/dev/null
    "${SUDO[@]}" swapon /swapfile

    if ! grep -qF "/swapfile none swap sw 0 0" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" |
            "${SUDO[@]}" tee -a /etc/fstab >/dev/null
    fi
}

healthy_bench() {
    local bench="$1"

    [[ -d "$bench/apps/frappe" ]] &&
        [[ -d "$bench/sites" ]] &&
        [[ -x "$bench/env/bin/python" ]] &&
        [[ -f "$bench/sites/apps.txt" ]]
}

install_node_runtime
ensure_swap

UV_BIN="$(install_uv_for_bench_user)"
[[ -x "$UV_BIN" ]] ||
    die "uv executable is unavailable: $UV_BIN"

info "uv: $("$UV_BIN" --version)"

run_as_bench_user "$UV_BIN" python install "$PYTHON_VERSION"

PYTHON_BIN="$(
    run_as_bench_user "$UV_BIN" python find "$PYTHON_VERSION"
)"

[[ -x "$PYTHON_BIN" ]] ||
    die "Managed Python executable was not found"

[[ "$("$PYTHON_BIN" --version)" == "Python ${PYTHON_VERSION}"* ]] ||
    die "Incorrect Python selected: $("$PYTHON_BIN" --version)"

info "Managed Python: $("$PYTHON_BIN" --version)"
info "Managed Python path: $PYTHON_BIN"

run_as_bench_user python3 -m pipx ensurepath || true

run_as_bench_user bash -lc '
    export PATH="$HOME/.local/bin:$PATH"

    if ! command -v bench >/dev/null 2>&1; then
        python3 -m pipx install frappe-bench
    fi
'

"${SUDO[@]}" systemctl enable --now \
    mariadb \
    redis-server \
    nginx \
    supervisor

if ! healthy_bench "$BENCH_DIR"; then
    STAGING_DIR=""
    SOURCE_APP_AVAILABLE=0

    if [[ -d "$APP_SOURCE_DIR" ]]; then
        validate_app "$APP_SOURCE_DIR"
        STAGING_DIR="$(mktemp -d)"
        cp -a "$APP_SOURCE_DIR" "$STAGING_DIR/omc_app"
        SOURCE_APP_AVAILABLE=1
        info "OMC App staged before fresh Bench initialization"
    fi

    if [[ -e "$BENCH_DIR" ]]; then
        warn "Removing incomplete Bench directory: $BENCH_DIR"
        rm -rf -- "$BENCH_DIR"
    fi

    info "Initializing fresh Frappe v14 Bench"

    run_as_bench_user bash -lc '
        set -Eeuo pipefail

        export PATH="$HOME/.local/bin:$PATH"
        export NODE_OPTIONS="$4"

        bench init \
            --no-procfile \
            --no-backups \
            --frappe-branch "$1" \
            --python "$2" \
            "$3"
    ' bash \
        "$FRAPPE_BRANCH" \
        "$PYTHON_BIN" \
        "$BENCH_DIR" \
        "$NODE_OPTIONS" ||
    {
        rm -rf -- "$BENCH_DIR"
        [[ -z "$STAGING_DIR" ]] || rm -rf -- "$STAGING_DIR"
        die "Frappe Bench initialization failed"
    }

    if ((SOURCE_APP_AVAILABLE)); then
        rm -rf -- "$BENCH_DIR/apps/omc_app"
        cp -a "$STAGING_DIR/omc_app" "$BENCH_DIR/apps/omc_app"
        rm -rf -- "$STAGING_DIR"
        APP_SOURCE_DIR="$BENCH_DIR/apps/omc_app"

        info "OMC App restored into fresh Bench"
    else
        warn "OMC App source was not present; Bench-only installation completed"
    fi
fi

healthy_bench "$BENCH_DIR" ||
    die "Runtime Bench validation failed"

BENCH_PYTHON_VERSION="$("$BENCH_DIR/env/bin/python" --version)"

[[ "$BENCH_PYTHON_VERSION" == "Python ${PYTHON_VERSION}"* ]] ||
    die "Bench uses unexpected Python: $BENCH_PYTHON_VERSION"

FRAPPE_VERSION="$(
    cd "$BENCH_DIR"
    ./env/bin/python -c '
import frappe
print(getattr(frappe, "__version__", "unknown"))
'
)"

[[ "$FRAPPE_VERSION" == 14.* ]] ||
    die "Expected Frappe 14.x, found $FRAPPE_VERSION"

if [[ -d "$BENCH_DIR/apps/omc_app" ]]; then
    validate_app "$BENCH_DIR/apps/omc_app"

    BENCH_DIR="$BENCH_DIR" bench_cmd \
        ./env/bin/pip install -e apps/omc_app

    BENCH_DIR="$BENCH_DIR" bench_cmd \
        ./env/bin/python -c '
import frappe
import omc_app

print("Frappe:", frappe.__version__)
print("OMC App import: OK")
'
else
    warn "OMC App is not installed yet"
fi

for service in mariadb redis-server nginx supervisor; do
    "${SUDO[@]}" systemctl is-active --quiet "$service" ||
        die "$service is inactive"
done

ok "Frappe v14 production dependencies and runtime Bench are ready"
ok "No site or database was created"
