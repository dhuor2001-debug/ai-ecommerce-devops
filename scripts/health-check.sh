#!/usr/bin/env bash
# Verify the application is healthy. Exit 0 = healthy, 1 = unhealthy.
# Usage: health-check.sh [-u BASE_URL] [-r RETRIES] [-i INTERVAL_SECONDS] [--system]
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BASE_URL="${BASE_URL:-http://localhost:8080}"
RETRIES=10
INTERVAL=3
SYSTEM=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u) BASE_URL="$2"; shift 2 ;;
    -r) RETRIES="$2"; shift 2 ;;
    -i) INTERVAL="$2"; shift 2 ;;
    --system) SYSTEM=true; shift ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done
require_cmd curl

check_endpoint() {
  local path="$1" expect="$2" code
  code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' "${BASE_URL}${path}" || echo 000)
  [[ "$code" == "$expect" ]]
}

for ((i = 1; i <= RETRIES; i++)); do
  if check_endpoint /health 200 && check_endpoint /ready 200 && check_endpoint /api/products 200; then
    log "Healthy: /health /ready /api/products all OK at ${BASE_URL}"
    RESULT=0; break
  fi
  warn "Attempt ${i}/${RETRIES} failed, retrying in ${INTERVAL}s"
  RESULT=1; sleep "$INTERVAL"
done

if $SYSTEM; then
  log "--- system checks ---"
  df -h "$REPO_ROOT" | tail -1 | awk '{print "disk used: "$5" of "$2}'
  awk '/MemAvailable/ {printf "memory available: %d MB\n", $2/1024}' /proc/meminfo
  uptime
  if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    docker ps --format 'container {{.Names}}: {{.Status}}'
  fi
fi

if [[ "${RESULT:-1}" -ne 0 ]]; then err "UNHEALTHY after ${RETRIES} attempts"; exit 1; fi
