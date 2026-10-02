#!/usr/bin/env bash
# Back up the PostgreSQL database to a compressed, verified dump.
# Usage: backup.sh [--k8s] [--restore FILE]
# Retention: BACKUP_RETENTION_DAYS (default 7)
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BACKUP_DIR="${BACKUP_DIR:-$REPO_ROOT/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
NAMESPACE="${NAMESPACE:-ecommerce}"
K8S=false
RESTORE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --k8s) K8S=true; shift ;;
    --restore) RESTORE="$2"; shift 2 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done
mkdir -p "$BACKUP_DIR"
if ! $K8S; then load_env; fi
DB_USER="${POSTGRES_USER:-shop}"; DB_NAME="${POSTGRES_DB:-shop}"

db_exec() {
  if $K8S; then kubectl -n "$NAMESPACE" exec -i deploy/postgres -- "$@"
  else compose exec -T db "$@"; fi
}

if [[ -n "$RESTORE" ]]; then
  [[ -f "$RESTORE" ]] || die "Backup file not found: $RESTORE"
  gzip -t "$RESTORE" || die "Backup file is corrupt"
  log "Restoring $RESTORE into database '$DB_NAME'"
  gunzip -c "$RESTORE" | db_exec psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1
  log "Restore complete"; exit 0
fi

OUT="$BACKUP_DIR/${DB_NAME}_$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
log "Dumping database '$DB_NAME' to $OUT"
db_exec pg_dump -U "$DB_USER" --clean --if-exists "$DB_NAME" | gzip > "$OUT"
gzip -t "$OUT" || { rm -f "$OUT"; die "Backup verification failed"; }
[[ -s "$OUT" ]] || { rm -f "$OUT"; die "Backup is empty"; }
chmod 600 "$OUT"
log "Backup OK ($(du -h "$OUT" | cut -f1))"

find "$BACKUP_DIR" -name '*.sql.gz' -type f -mtime +"$RETENTION_DAYS" -print -delete | sed 's/^/pruned old backup: /'
