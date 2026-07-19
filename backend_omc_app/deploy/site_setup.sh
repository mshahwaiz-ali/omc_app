#!/usr/bin/env bash
set -Eeuo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; source "$D/lib/common.sh"
ACTION="${1:-status}"; [[ $# -gt 0 ]] && shift || true
SITE=""; APP=""; NO_BACKUP=0
while (($#)); do
  case "$1" in
    --site) [[ $# -ge 2 ]] || die '--site requires a value'; SITE="$2"; shift 2 ;;
    --app) [[ $# -ge 2 ]] || die '--app requires a value'; APP="$2"; shift 2 ;;
    --no-backup) NO_BACKUP=1; shift ;;