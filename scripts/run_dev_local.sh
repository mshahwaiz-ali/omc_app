#!/usr/bin/env bash
set -euo pipefail

# Runs the Flutter app in development mode against a detected local Frappe backend.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_APP_DIR="$REPO_ROOT/omc_app"

BENCH_DIR="${BENCH_DIR:-$HOME/data_drive/app_omc/backend_omc_app/frappe-bench}"
SITE_NAME="${SITE_NAME:-omc.local}"
WEB_HOST="${WEB_HOST:-localhost}"
API_HOST="${API_HOST:-$WEB_HOST}"
WEB_PORT="${WEB_PORT:-5001}"
PORTS=(${API_PORTS:-8000 8001 8002})

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v flutter >/dev/null 2>&1 || fail "flutter command not found. Open this from your normal Flutter terminal."
[ -d "$FLUTTER_APP_DIR" ] || fail "Flutter app folder not found: $FLUTTER_APP_DIR"

available_urls=()
for port in "${PORTS[@]}"; do
  url="http://${API_HOST}:${port}"
  if curl -fsS "$url/api/method/ping" >/dev/null 2>&1; then
    available_urls+=("$url")
  fi
done

if [ "${#available_urls[@]}" -eq 0 ]; then
  echo "No local Frappe backend found."
  echo
  echo "Checked:"
  for port in "${PORTS[@]}"; do
    echo "  - http://${API_HOST}:${port}/api/method/ping"
  done
  cat <<EOF

Run:
  cd "$BENCH_DIR"
  bench start

Then run this script again.
EOF
  exit 1
fi

if [ "${#available_urls[@]}" -eq 1 ]; then
  API_BASE_URL="${available_urls[0]}"
  echo "Detected local Frappe backend: $API_BASE_URL"
else
  echo "Detected local Frappe backends:"
  index=1
  for url in "${available_urls[@]}"; do
    echo "$index) $url  pong"
    index=$((index + 1))
  done

  while true; do
    read -r -p "Choose backend [1-${#available_urls[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] &&
      [ "$choice" -ge 1 ] &&
      [ "$choice" -le "${#available_urls[@]}" ]; then
      API_BASE_URL="${available_urls[$((choice - 1))]}"
      break
    fi
    echo "Please choose a number from 1 to ${#available_urls[@]}."
  done
fi

ORIGINS="[\"http://${WEB_HOST}:${WEB_PORT}\",\"http://localhost:${WEB_PORT}\",\"http://127.0.0.1:${WEB_PORT}\"]"
if [ -d "$BENCH_DIR/sites/$SITE_NAME" ] && command -v bench >/dev/null 2>&1; then
  echo "Setting CORS for local Frappe site: $SITE_NAME"
  (
    cd "$BENCH_DIR"
    bench use "$SITE_NAME" >/dev/null
    bench --site "$SITE_NAME" set-config allow_cors "$ORIGINS" --parse >/dev/null
    bench --site "$SITE_NAME" set-config allow_cors_credentials 1 --parse >/dev/null
  )
else
  cat <<EOF
Skipping automatic CORS setup.
Expected bench/site was not available:
  Bench: $BENCH_DIR
  Site:  $SITE_NAME
EOF
fi

cd "$FLUTTER_APP_DIR"

cat <<EOF

Starting Flutter development app
  Backend: $API_BASE_URL
  Web:     http://$WEB_HOST:$WEB_PORT
EOF

exec flutter run -d chrome \
  --web-hostname="$WEB_HOST" \
  --web-port="$WEB_PORT" \
  --dart-define=OMC_ENV=development \
  --dart-define=OMC_API_BASE_URL="$API_BASE_URL" \
  --dart-define=OMC_USE_MOCK_AUTH=false \
  --dart-define=OMC_USE_SERVICE_PREVIEW=false \
  --dart-define=OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK=false
