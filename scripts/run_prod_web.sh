#!/usr/bin/env bash
set -euo pipefail

# Runs the Flutter web app in production mode.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_APP_DIR="$REPO_ROOT/omc_app"

WEB_PORT="${WEB_PORT:-5001}"
API_BASE_URL="${API_BASE_URL:-https://erp.omchouse.com}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v flutter >/dev/null 2>&1 || fail "flutter command not found. Open this from your normal Flutter terminal."
[ -d "$FLUTTER_APP_DIR" ] || fail "Flutter app folder not found: $FLUTTER_APP_DIR"

if [[ "$API_BASE_URL" != https://* ]]; then
  cat <<EOF
WARNING: Production mode is using a non-HTTPS backend override:
  $API_BASE_URL

This is intended only for explicit testing overrides.
EOF
fi

cd "$FLUTTER_APP_DIR"

cat <<EOF

Starting Flutter production app
  Backend: $API_BASE_URL
  Web:     http://localhost:$WEB_PORT
EOF

exec flutter run -d chrome \
  --web-port="$WEB_PORT" \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL="$API_BASE_URL" \
  --dart-define=OMC_USE_MOCK_AUTH=false \
  --dart-define=OMC_USE_SERVICE_PREVIEW=false \
  --dart-define=OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK=false
