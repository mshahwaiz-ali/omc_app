#!/usr/bin/env bash
set -euo pipefail

# Required: E2E_USERNAME and E2E_PASSWORD for a valid approved customer.
# Optional: OMC_API_BASE_URL, OMC_E2E_RESOLVE_IP, E2E_CHROME_BINARY,
#           OMC_E2E_REAL_CHROME_BIN, FLUTTER_BIN, CHROMEDRIVER_BIN,
#           E2E_WEB_PORT, E2E_DRIVER_PORT, and E2E_HEADLESS (true or false).

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
FLUTTER_APP_DIR="$REPO_ROOT/omc_app"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
CHROMEDRIVER_BIN="${CHROMEDRIVER_BIN:-chromedriver}"
API_BASE_URL="${OMC_API_BASE_URL:-http://omc-prod.local:8000}"
API_BASE_URL="${API_BASE_URL%/}"
WEB_PORT="${E2E_WEB_PORT:-5002}"
DRIVER_PORT="${E2E_DRIVER_PORT:-4444}"
HEADLESS="${E2E_HEADLESS:-true}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

source "$SCRIPT_DIR/e2e_web_runtime.sh"
e2e_configure_web_runtime "$API_BASE_URL" "$SCRIPT_DIR" || \
  fail "Unable to configure the local Chrome E2E runtime."

[ -d "$FLUTTER_APP_DIR" ] || fail "Flutter app folder not found: $FLUTTER_APP_DIR"
[ -n "${E2E_USERNAME:-}" ] || fail "E2E_USERNAME is required."
[ -n "${E2E_PASSWORD:-}" ] || fail "E2E_PASSWORD is required."
command -v "$FLUTTER_BIN" >/dev/null 2>&1 || fail "Flutter executable not found: $FLUTTER_BIN"
curl "${E2E_API_CURL_ARGS[@]}" "$API_BASE_URL/api/method/ping" >/dev/null 2>&1 || \
  fail "OMC backend ping failed at $API_BASE_URL. Start the selected backend and verify the URL."

case "$HEADLESS" in
  true|false) ;;
  *) fail "E2E_HEADLESS must be true or false." ;;
esac

driver_started=false
driver_log=""
driver_pid=""

cleanup() {
  if [ "$driver_started" = true ] && [ -n "$driver_pid" ]; then
    kill "$driver_pid" >/dev/null 2>&1 || true
    wait "$driver_pid" >/dev/null 2>&1 || true
  fi
  if [ -n "$driver_log" ]; then
    rm -f -- "$driver_log"
  fi
}
trap cleanup EXIT INT TERM

if ! curl -fsS --max-time 2 "http://127.0.0.1:$DRIVER_PORT/status" >/dev/null 2>&1; then
  command -v "$CHROMEDRIVER_BIN" >/dev/null 2>&1 || fail \
    "ChromeDriver is not running on port $DRIVER_PORT and was not found as $CHROMEDRIVER_BIN."
  driver_log="$(mktemp "${TMPDIR:-/tmp}/omc-e2e-chromedriver.XXXXXX.log")"
  "$CHROMEDRIVER_BIN" --port="$DRIVER_PORT" >"$driver_log" 2>&1 &
  driver_pid="$!"
  driver_started=true

  for _ in $(seq 1 50); do
    if curl -fsS --max-time 1 "http://127.0.0.1:$DRIVER_PORT/status" >/dev/null 2>&1; then
      break
    fi
    if ! kill -0 "$driver_pid" >/dev/null 2>&1; then
      fail "ChromeDriver exited before becoming ready. See: $driver_log"
    fi
    sleep 0.1
  done
  curl -fsS --max-time 2 "http://127.0.0.1:$DRIVER_PORT/status" >/dev/null 2>&1 || \
    fail "ChromeDriver did not become ready on port $DRIVER_PORT. See: $driver_log"
fi

cd -- "$FLUTTER_APP_DIR"

headless_flag="--headless"
if [ "$HEADLESS" = false ]; then
  headless_flag="--no-headless"
fi

"$FLUTTER_BIN" drive \
  --device-id=web-server \
  --browser-name=chrome \
  --driver=test_driver/e2e_test.dart \
  --target=integration_test/e2e/smoke_test.dart \
  --web-hostname="$E2E_WEB_BIND_HOST" \
  --web-port="$WEB_PORT" \
  --web-launch-url="http://$E2E_WEB_ORIGIN_HOST:$WEB_PORT/" \
  --driver-port="$DRIVER_PORT" \
  "$headless_flag" \
  "${E2E_CHROME_ARGS[@]}" \
  --dart-define=OMC_ENV=development \
  --dart-define=OMC_API_BASE_URL="$API_BASE_URL" \
  --dart-define=OMC_LINK_BASE_URL="http://$E2E_WEB_ORIGIN_HOST:$WEB_PORT" \
  --dart-define=OMC_USE_MOCK_AUTH=false \
  --dart-define=OMC_USE_SERVICE_PREVIEW=false \
  --dart-define=OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK=false \
  --dart-define=OMC_E2E_AUDIT=true \
  --dart-define=E2E_USERNAME="$E2E_USERNAME" \
  --dart-define=E2E_PASSWORD="$E2E_PASSWORD"
