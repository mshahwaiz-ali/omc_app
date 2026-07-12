#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; source "$SCRIPT_DIR/lib/common.sh"
ACTION=start; SITE=""; BACKGROUND=0
while (($#)); do case "$1" in --background) BACKGROUND=1; shift;; --stop) ACTION=stop; shift;; --restart) ACTION=restart; shift;; --status) ACTION=status; shift;; --logs) ACTION=logs; shift;; --site) SITE="$2"; shift 2;; -h|--help) echo 'Usage: ./start.sh [--background|--stop|--restart|--status|--logs] [--site SITE]'; exit;; *) die "Unknown option $1";; esac; done
load_mode_config local; BENCH_DIR="${BENCH_DIR:-$HOME/frappe-bench}"; SITE="${SITE:-${SITE_NAME:-omc.local}}"; PIDFILE="$STATE_DIR/dev-bench.pid"; DEVLOG="$LOG_DIR/dev-bench.log"
echo 'This script is for development only. For production use ./deploy.sh.'
stop_dev(){ if [[ -f "$PIDFILE" ]]; then local p; p="$(cat "$PIDFILE")"; kill "$p" 2>/dev/null || true; sleep 2; kill -9 "$p" 2>/dev/null || true; rm -f "$PIDFILE"; fi; pkill -f "$BENCH_DIR.*bench start" 2>/dev/null || true; }
status_dev(){ [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null && echo "running pid $(cat "$PIDFILE")" || echo 'stopped'; }
start_dev(){ site_exists "$SITE" || die "Site not found: $SITE"; bench_cmd bench use "$SITE"; if ((BACKGROUND)); then (cd "$BENCH_DIR" && nohup bench start >> "$DEVLOG" 2>&1 & echo $! > "$PIDFILE"); ok "started in background: http://$SITE:8000"; else (cd "$BENCH_DIR" && exec bench start); fi; }
case "$ACTION" in start) start_dev;; stop) stop_dev;; restart) stop_dev; BACKGROUND=1; start_dev;; status) status_dev;; logs) touch "$DEVLOG"; tail -n 150 -f "$DEVLOG";; esac
