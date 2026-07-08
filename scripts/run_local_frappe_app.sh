#!/usr/bin/env bash
set -euo pipefail

# Runs the Flutter app in development mode against the local Frappe bench only.
# No production/staging backend is used by this script.
#
# Defaults match the current local OMC setup:
#   BENCH_DIR: ~/data_drive/app_omc/backend_omc_app/frappe-bench
#   SITE_NAME: omc.local
#   API_BASE_URL: http://127.0.0.1:8000
#   WEB_PORT: 5001
#
# Override when needed, for example:
#   WEB_PORT=5000 ./scripts/run_local_frappe_app.sh
#   SITE_NAME=other.local ./scripts/run_local_frappe_app.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_APP_DIR="$REPO_ROOT/omc_app"

BENCH_DIR="${BENCH_DIR:-$HOME/data_drive/app_omc/backend_omc_app/frappe-bench}"
SITE_NAME="${SITE_NAME:-omc.local}"
API_HOST="${API_HOST:-127.0.0.1}"
API_PORT="${API_PORT:-8000}"
WEB_PORT="${WEB_PORT:-5001}"
API_BASE_URL="${API_BASE_URL:-http://${API_HOST}:${API_PORT}}"

ORIGINS="[\"http://localhost:${WEB_PORT}\",\"http://127.0.0.1:${WEB_PORT}\"]"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v flutter >/dev/null 2>&1 || fail "flutter command not found. Open this from your normal Flutter terminal."
[ -d "$FLUTTER_APP_DIR" ] || fail "Flutter app folder not found: $FLUTTER_APP_DIR"
[ -d "$BENCH_DIR" ] || fail "Bench folder not found: $BENCH_DIR"
[ -d "$BENCH_DIR/sites/$SITE_NAME" ] || fail "Frappe site not found: $BENCH_DIR/sites/$SITE_NAME"

cd "$BENCH_DIR"

if command -v bench >/dev/null 2>&1; then
  echo "Using local Frappe site: $SITE_NAME"
  bench use "$SITE_NAME" >/dev/null
  bench --site "$SITE_NAME" set-config allow_cors "$ORIGINS" >/dev/null
else
  fail "bench command not found. Activate/open the terminal where bench works."
fi

echo "Checking local backend: $API_BASE_URL"
if ! curl -fsS --max-time 3 "$API_BASE_URL/api/method/ping" >/dev/null; then
  cat <<EOF

Local Frappe backend is not reachable at $API_BASE_URL.
Start it in another terminal first:

  cd "$BENCH_DIR"
  bench start

Then run this script again.
EOF
  exit 1
fi

cd "$FLUTTER_APP_DIR"

cat <<EOF

Starting Flutter local-dev app
  Backend: $API_BASE_URL
  Site:    $SITE_NAME
  Web:     http://localhost:$WEB_PORT

This forces development mode and local backend only.
EOF

exec flutter run -d chrome \
  --web-port="$WEB_PORT" \
  --dart-define=OMC_ENV=development \
  --dart-define=OMC_API_BASE_URL="$API_BASE_URL" \
  --dart-define=OMC_USE_MOCK_AUTH=false \
  --dart-define=OMC_USE_SERVICE_PREVIEW=false \
  --dart-define=OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK=false
