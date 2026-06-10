#!/bin/bash
# ─── PostgreSQL Backup Script ────────────────────────────────────────────────
# Backs up the PostgreSQL database from the K8s pod and uploads to S3.
# Schedule: Daily at midnight via cron
# Cron entry: 0 0 * * * /bin/bash /home/ubuntu/app/scripts/backup.sh

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
BACKUP_DIR="/opt/backups/postgres"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="db_backup_${TIMESTAMP}.sql.gz"
S3_BUCKET="hudocafe-backups"
S3_PREFIX="postgres"
NAMESPACE="production"
RETENTION_DAYS=7

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[$(date +'%Y-%m-%dT%H:%M:%SZ')] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
err()  { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

# ── Ensure Backup Directory ───────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"

# ── Find PostgreSQL Pod ───────────────────────────────────────────────────────
POSTGRES_POD=$(kubectl get pod -n "$NAMESPACE" \
  -l app=postgres \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) || err "No postgres pod found in namespace $NAMESPACE"

log "Found postgres pod: $POSTGRES_POD"

# ── Dump Database ─────────────────────────────────────────────────────────────
log "Starting backup: $BACKUP_FILE"
kubectl exec -n "$NAMESPACE" "$POSTGRES_POD" \
  -- pg_dump -U app_user app_db \
  | gzip > "$BACKUP_DIR/$BACKUP_FILE"

BACKUP_SIZE=$(du -sh "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
log "Backup created: $BACKUP_DIR/$BACKUP_FILE (${BACKUP_SIZE})"

# ── Upload to S3 ──────────────────────────────────────────────────────────────
log "Uploading to S3: s3://$S3_BUCKET/$S3_PREFIX/$BACKUP_FILE"
aws s3 cp "$BACKUP_DIR/$BACKUP_FILE" \
  "s3://$S3_BUCKET/$S3_PREFIX/$BACKUP_FILE" \
  --region ap-south-1 \
  --sse AES256

log "Upload complete: s3://$S3_BUCKET/$S3_PREFIX/$BACKUP_FILE"

# ── Clean Local Old Backups ───────────────────────────────────────────────────
find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +"$RETENTION_DAYS" -delete
log "Cleaned local backups older than $RETENTION_DAYS days"

# ── S3 Lifecycle handles remote cleanup (30 days) ────────────────────────────
log "✅ Backup completed successfully: $BACKUP_FILE"
