#!/usr/bin/env bash

# Shared browser/runtime wiring for local Chrome E2E runners.
# The optional resolver keeps the configured API hostname unchanged while
# mapping it to a local IP inside curl and the E2E Chrome process only.
e2e_configure_web_runtime() {
  local api_base_url="$1"
  local script_dir="$2"
  local resolve_ip="${OMC_E2E_RESOLVE_IP:-}"
  local chrome_binary="${E2E_CHROME_BINARY:-}"
  local scheme="${api_base_url%%://*}"
  local authority="${api_base_url#*://}"
  authority="${authority%%/*}"
  local host="${authority%%:*}"
  local port
  if [[ "$authority" == *:* ]]; then
    port="${authority##*:}"
  elif [ "$scheme" = "https" ]; then
    port=443
  else
    port=80
  fi

  if [ -z "$host" ] || [ -z "$port" ]; then
    echo "ERROR: Could not derive API host/port from $api_base_url." >&2
    return 1
  fi

  E2E_API_CURL_ARGS=(-fsS --max-time 5)
  E2E_CHROME_ARGS=()
  E2E_WEB_BIND_HOST="${OMC_E2E_WEB_BIND_HOST:-0.0.0.0}"
  E2E_WEB_ORIGIN_HOST="$host"

  if [ -n "$resolve_ip" ]; then
    E2E_API_CURL_ARGS+=(--resolve "$host:$port:$resolve_ip")
    export OMC_E2E_RESOLVE_HOST="$host"
    if [ -z "$chrome_binary" ]; then
      chrome_binary="$script_dir/chrome_e2e_binary.sh"
    fi
  fi

  if [ -n "$chrome_binary" ]; then
    [ -x "$chrome_binary" ] || {
      echo "ERROR: E2E Chrome binary is not executable: $chrome_binary." >&2
      return 1
    }
    E2E_CHROME_ARGS+=(--chrome-binary="$chrome_binary")
  fi
}
