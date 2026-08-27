#!/usr/bin/env bash
set -euo pipefail

resolve_host="${OMC_E2E_RESOLVE_HOST:-}"
resolve_ip="${OMC_E2E_RESOLVE_IP:-}"
real_chrome="${OMC_E2E_REAL_CHROME_BIN:-google-chrome}"

[ -n "$resolve_host" ] || {
  echo "ERROR: OMC_E2E_RESOLVE_HOST is required by the E2E Chrome wrapper." >&2
  exit 1
}
[ -n "$resolve_ip" ] || {
  echo "ERROR: OMC_E2E_RESOLVE_IP is required by the E2E Chrome wrapper." >&2
  exit 1
}
command -v "$real_chrome" >/dev/null 2>&1 || {
  echo "ERROR: Real Chrome executable not found: $real_chrome." >&2
  exit 1
}

exec "$real_chrome" \
  "--host-resolver-rules=MAP $resolve_host $resolve_ip" \
  "$@"
