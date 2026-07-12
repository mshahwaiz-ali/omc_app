#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$SCRIPT_DIR/frappe-bench"
LOG_DIR="$SCRIPT_DIR/logs"
PID_FILE="$LOG_DIR/bench-start.pid"
LOG_FILE="$LOG_DIR/bench-start.log"

PORTS=(8000 9000 11000 12000 13000)

info() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'HELP'
Usage:
  ./start.sh              Stop old local bench processes, then run bench start in foreground
  ./start.sh --background Stop old local bench processes, then run bench start in background
  ./start.sh --stop       Stop local bench processes
  ./start.sh --status     Show local bench status
HELP
}

is_bench_dir() {
  [[ -d "$BENCH_DIR/apps" && -d "$BENCH_DIR/sites" && -f "$BENCH_DIR/Procfile" ]]
}

load_node_env() {
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  export NVM_DIR="$HOME/.nvm"

  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    nvm use 22 >/dev/null 2>&1 || nvm use 24 >/dev/null 2>&1 || true
  fi
}

process_belongs_to_bench() {
  local pid="$1"
  local cwd=""
  local cmd=""

  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  [[ -d "/proc/$pid" ]] || return 1

  cwd="$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)"
  cmd="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)"

  [[ "$cwd" == "$BENCH_DIR"* || "$cmd" == *"$BENCH_DIR"* ]]
}

port_pids() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    ss -ltnp 2>/dev/null | awk -v suffix=":$port" '
      $4 ~ suffix "$" {
        line = $0
        while (match(line, /pid=[0-9]+/)) {
          print substr(line, RSTART + 4, RLENGTH - 4)
          line = substr(line, RSTART + RLENGTH)
        }
      }
    ' | sort -u
  elif command -v lsof >/dev/null 2>&1; then
    lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | sort -u
  fi
}

kill_bench_pid() {
  local pid="$1"
  local pgid=""

  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  [[ "$pid" != "$$" ]] || return 0

  if process_belongs_to_bench "$pid"; then
    pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
    if [[ -n "$pgid" && "$pgid" != "$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ' || true)" ]]; then
      kill -TERM "-$pgid" 2>/dev/null || true
    else
      kill -TERM "$pid" 2>/dev/null || true
    fi
  fi
}

stop_bench() {
  local pid=""
  local pids=""
  local port=""
  local proc=""
  local pid_file=""

  mkdir -p "$LOG_DIR"

  if [[ -f "$PID_FILE" ]]; then
    pid="$(tr -d '[:space:]' <"$PID_FILE" 2>/dev/null || true)"
    kill_bench_pid "$pid"
  fi

  if [[ -d "$BENCH_DIR/config/pids" ]]; then
    while IFS= read -r -d '' pid_file; do
      pid="$(tr -d '[:space:]' <"$pid_file" 2>/dev/null || true)"
      kill_bench_pid "$pid"
    done < <(find "$BENCH_DIR/config/pids" -type f -name '*.pid' -print0 2>/dev/null)
  fi

  while IFS= read -r -d '' proc; do
    pid="$(basename "$proc")"
    process_belongs_to_bench "$pid" && kill_bench_pid "$pid"
  done < <(find /proc -maxdepth 1 -type d -regex '/proc/[0-9]+' -print0 2>/dev/null)

  sleep 2

  for port in "${PORTS[@]}"; do
    pids="$(port_pids "$port" || true)"
    [[ -n "$pids" ]] || continue

    for pid in $pids; do
      if process_belongs_to_bench "$pid"; then
        warn "Force stopping bench process on port $port: PID $pid"
        kill -KILL "$pid" 2>/dev/null || true
      else
        warn "Port $port is used by unrelated PID $pid. Leaving it running."
      fi
    done
  done

  rm -f "$PID_FILE" 2>/dev/null || true
  rm -f "$BENCH_DIR"/config/pids/*.pid 2>/dev/null || true

  ok "Stopped old local bench processes."
}

status_bench() {
  local port=""
  local pids=""

  printf 'Bench: %s\n' "$BENCH_DIR"
  printf 'Sites:\n'
  find "$BENCH_DIR/sites" -mindepth 1 -maxdepth 1 -type d \
    ! -name assets ! -name archived \
    -exec test -f "{}/site_config.json" \; -print 2>/dev/null \
    | xargs -r -n1 basename \
    | sed 's/^/  - /'

  printf 'Ports:\n'
  for port in "${PORTS[@]}"; do
    pids="$(port_pids "$port" || true)"
    if [[ -z "$pids" ]]; then
      printf '  %s: free\n' "$port"
    else
      printf '  %s: %s\n' "$port" "$pids"
    fi
  done
}

ensure_current_site() {
  local site=""

  if [[ -d "$BENCH_DIR/sites/omc.local" ]]; then
    site="omc.local"
  else
    site="$(find "$BENCH_DIR/sites" -mindepth 1 -maxdepth 1 -type d \
      ! -name assets ! -name archived \
      -exec test -f "{}/site_config.json" \; -print 2>/dev/null \
      | xargs -r -n1 basename \
      | sort \
      | head -n 1)"
  fi

  [[ -n "$site" ]] || die "No Frappe site found. Create omc.local first."

  printf '%s\n' "$site" > "$BENCH_DIR/sites/currentsite.txt"
  ok "Current site set to $site"
}

start_foreground() {
  load_node_env
  is_bench_dir || die "$BENCH_DIR is not a valid bench directory"

  stop_bench
  ensure_current_site

  info "Starting bench in foreground..."
  info "Open: http://omc.local:8000"
  info "Stop: Ctrl+C"

  cd "$BENCH_DIR"
  bench start
}

start_background() {
  load_node_env
  is_bench_dir || die "$BENCH_DIR is not a valid bench directory"

  mkdir -p "$LOG_DIR"

  stop_bench
  ensure_current_site

  info "Starting bench in background..."
  cd "$BENCH_DIR"

  nohup setsid bench start >"$LOG_FILE" 2>&1 &
  printf '%s\n' "$!" >"$PID_FILE"

  ok "Bench started in background."
  info "PID: $(cat "$PID_FILE")"
  info "Log: $LOG_FILE"
  info "Open: http://omc.local:8000"
  info "Stop: ./start.sh --stop"
}

main() {
  case "${1:-}" in
    "")
      start_foreground
      ;;
    --background)
      start_background
      ;;
    --stop)
      is_bench_dir || die "$BENCH_DIR is not a valid bench directory"
      stop_bench
      ;;
    --status)
      is_bench_dir || die "$BENCH_DIR is not a valid bench directory"
      status_bench
      ;;
    --help|-h)
      usage
      ;;
    *)
      usage
      die "Unknown option: $1"
      ;;
  esac
}

main "$@"
