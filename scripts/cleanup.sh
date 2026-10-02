#!/usr/bin/env bash
# Remove old backups, old logs and unused Docker resources.
# Usage: cleanup.sh [--dry-run] [--days N] [--docker-all]
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DRY=false; DAYS=14; DOCKER_ALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=true; shift ;;
    --days) DAYS="$2"; shift 2 ;;
    --docker-all) DOCKER_ALL=true; shift ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done
[[ "$DAYS" =~ ^[0-9]+$ ]] || die "--days must be a number"

prune_files() {
  local dir="$1" pattern="$2"
  [[ -d "$dir" ]] || return 0
  if $DRY; then find "$dir" -name "$pattern" -type f -mtime +"$DAYS" -print | sed 's/^/[dry-run] would delete: /'
  else find "$dir" -name "$pattern" -type f -mtime +"$DAYS" -print -delete | sed 's/^/deleted: /'; fi
}

log "Cleaning files older than ${DAYS} days (dry-run: $DRY)"
prune_files "$REPO_ROOT/backups" '*.sql.gz'
prune_files "$REPO_ROOT/logs" '*.log'
prune_files "$REPO_ROOT/logs" '*.log.*'

if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
  if $DRY; then log "[dry-run] would run: docker image prune -f ${DOCKER_ALL:+(and -a)}"
  else
    docker image prune -f >/dev/null
    $DOCKER_ALL && docker image prune -a -f --filter "until=${DAYS}d" >/dev/null
    docker builder prune -f --filter "until=${DAYS}d" >/dev/null || true
    log "Docker cleanup done"
  fi
else
  warn "Docker not available - skipping Docker cleanup"
fi
log "Cleanup complete"
