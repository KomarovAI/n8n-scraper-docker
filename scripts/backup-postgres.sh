#!/bin/bash
# PostgreSQL Backup Script with S3 Upload
# Usage: ./backup-postgres.sh
# Cron: 0 2 * * * /path/to/backup-postgres.sh >> /var/log/postgres-backup.log 2>&1

set -euo pipefail

# Configuration from .env or environment
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-n8n-postgres}"
POSTGRES_USER="${POSTGRES_USER:-scraper_user}"
POSTGRES_DB="${POSTGRES_DB:-scraper_db}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
S3_BUCKET="${BACKUP_S3_BUCKET:-}"
S3_REGION="${BACKUP_S3_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Create backup directory if not exists
mkdir -p "$BACKUP_DIR"

# Generate backup filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/postgres_${POSTGRES_DB}_${TIMESTAMP}.sql"
BACKUP_FILE_GZ="${BACKUP_FILE}.gz"

log_info "Starting PostgreSQL backup for database: $POSTGRES_DB"

# Check if PostgreSQL container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
    log_error "PostgreSQL container '$POSTGRES_CONTAINER' is not running!"
    exit 1
fi

# Perform backup using pg_dump
log_info "Creating backup: $BACKUP_FILE"
if docker exec -t "$POSTGRES_CONTAINER" pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$BACKUP_FILE"; then
    log_info "Backup created successfully"
else
    log_error "Backup failed!"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Compress backup
log_info "Compressing backup..."
if gzip -9 "$BACKUP_FILE"; then
    log_info "Backup compressed: $BACKUP_FILE_GZ"
    BACKUP_SIZE=$(du -h "$BACKUP_FILE_GZ" | cut -f1)
    log_info "Backup size: $BACKUP_SIZE"
else
    log_error "Compression failed!"
    exit 1
fi

# Upload to S3 if configured
if [ -n "$S3_BUCKET" ]; then
    log_info "Uploading backup to S3: s3://${S3_BUCKET}/postgres/"
    
    if command -v aws &> /dev/null; then
        if aws s3 cp "$BACKUP_FILE_GZ" "s3://${S3_BUCKET}/postgres/$(basename "$BACKUP_FILE_GZ")" --region "$S3_REGION"; then
            log_info "Backup uploaded to S3 successfully"
        else
            log_warn "Failed to upload backup to S3"
        fi
    else
        log_warn "AWS CLI not installed, skipping S3 upload"
    fi
fi

# Clean up old backups (local)
log_info "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "postgres_*.sql.gz" -type f -mtime +"$BACKUP_RETENTION_DAYS" -delete
OLD_BACKUPS_DELETED=$(find "$BACKUP_DIR" -name "postgres_*.sql.gz" -type f -mtime +"$BACKUP_RETENTION_DAYS" | wc -l)
log_info "Deleted $OLD_BACKUPS_DELETED old backup(s)"

# Clean up old backups (S3)
if [ -n "$S3_BUCKET" ] && command -v aws &> /dev/null; then
    log_info "Cleaning up S3 backups older than $BACKUP_RETENTION_DAYS days..."
    
    CUTOFF_DATE=$(date -d "$BACKUP_RETENTION_DAYS days ago" +%Y-%m-%d)
    
    aws s3 ls "s3://${S3_BUCKET}/postgres/" --region "$S3_REGION" | \
        awk '{print $4}' | \
        while read -r file; do
            FILE_DATE=$(echo "$file" | grep -oP '\d{8}' | head -1)
            if [ -n "$FILE_DATE" ]; then
                FILE_DATE_FORMATTED=$(date -d "${FILE_DATE:0:4}-${FILE_DATE:4:2}-${FILE_DATE:6:2}" +%Y-%m-%d)
                if [[ "$FILE_DATE_FORMATTED" < "$CUTOFF_DATE" ]]; then
                    log_info "Deleting old S3 backup: $file"
                    aws s3 rm "s3://${S3_BUCKET}/postgres/$file" --region "$S3_REGION"
                fi
            fi
        done
fi

# Summary
log_info "Backup completed successfully!"
log_info "Local backup: $BACKUP_FILE_GZ"
if [ -n "$S3_BUCKET" ]; then
    log_info "S3 backup: s3://${S3_BUCKET}/postgres/$(basename "$BACKUP_FILE_GZ")"
fi

# Send notification (optional - requires mailutils or similar)
if command -v mail &> /dev/null && [ -n "${ADMIN_EMAIL:-}" ]; then
    echo "PostgreSQL backup completed: $(basename "$BACKUP_FILE_GZ") ($BACKUP_SIZE)" | \
        mail -s "[SUCCESS] PostgreSQL Backup - $(date +%Y-%m-%d)" "$ADMIN_EMAIL"
fi

exit 0
