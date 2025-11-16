#!/bin/bash
# Redis Backup Script with S3 Upload
# Usage: ./backup-redis.sh
# Cron: 0 3 * * * /path/to/backup-redis.sh >> /var/log/redis-backup.log 2>&1

set -euo pipefail

# Configuration from .env or environment
REDIS_CONTAINER="${REDIS_CONTAINER:-n8n-redis}"
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
BACKUP_FILE="${BACKUP_DIR}/redis_dump_${TIMESTAMP}.rdb"
BACKUP_FILE_GZ="${BACKUP_FILE}.gz"

log_info "Starting Redis backup"

# Check if Redis container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${REDIS_CONTAINER}$"; then
    log_error "Redis container '$REDIS_CONTAINER' is not running!"
    exit 1
fi

# Trigger Redis BGSAVE (background save)
log_info "Triggering Redis BGSAVE..."
if docker exec "$REDIS_CONTAINER" redis-cli --no-auth-warning -a "${REDIS_PASSWORD:-}" BGSAVE; then
    log_info "BGSAVE triggered successfully"
else
    log_error "BGSAVE failed!"
    exit 1
fi

# Wait for BGSAVE to complete
log_info "Waiting for BGSAVE to complete..."
MAX_WAIT=60  # seconds
WAIT_COUNT=0

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    LASTSAVE=$(docker exec "$REDIS_CONTAINER" redis-cli --no-auth-warning -a "${REDIS_PASSWORD:-}" LASTSAVE)
    sleep 2
    CURRENT_SAVE=$(docker exec "$REDIS_CONTAINER" redis-cli --no-auth-warning -a "${REDIS_PASSWORD:-}" LASTSAVE)
    
    if [ "$LASTSAVE" != "$CURRENT_SAVE" ]; then
        log_info "BGSAVE completed"
        break
    fi
    
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    log_error "BGSAVE did not complete within ${MAX_WAIT} seconds"
    exit 1
fi

# Copy dump.rdb from container
log_info "Copying dump.rdb from container..."
if docker cp "${REDIS_CONTAINER}:/data/dump.rdb" "$BACKUP_FILE"; then
    log_info "dump.rdb copied successfully"
else
    log_error "Failed to copy dump.rdb"
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
    log_info "Uploading backup to S3: s3://${S3_BUCKET}/redis/"
    
    if command -v aws &> /dev/null; then
        if aws s3 cp "$BACKUP_FILE_GZ" "s3://${S3_BUCKET}/redis/$(basename "$BACKUP_FILE_GZ")" --region "$S3_REGION"; then
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
find "$BACKUP_DIR" -name "redis_dump_*.rdb.gz" -type f -mtime +"$BACKUP_RETENTION_DAYS" -delete
OLD_BACKUPS_DELETED=$(find "$BACKUP_DIR" -name "redis_dump_*.rdb.gz" -type f -mtime +"$BACKUP_RETENTION_DAYS" | wc -l)
log_info "Deleted $OLD_BACKUPS_DELETED old backup(s)"

# Clean up old backups (S3)
if [ -n "$S3_BUCKET" ] && command -v aws &> /dev/null; then
    log_info "Cleaning up S3 backups older than $BACKUP_RETENTION_DAYS days..."
    
    CUTOFF_DATE=$(date -d "$BACKUP_RETENTION_DAYS days ago" +%Y-%m-%d)
    
    aws s3 ls "s3://${S3_BUCKET}/redis/" --region "$S3_REGION" | \
        awk '{print $4}' | \
        while read -r file; do
            FILE_DATE=$(echo "$file" | grep -oP '\d{8}' | head -1)
            if [ -n "$FILE_DATE" ]; then
                FILE_DATE_FORMATTED=$(date -d "${FILE_DATE:0:4}-${FILE_DATE:4:2}-${FILE_DATE:6:2}" +%Y-%m-%d)
                if [[ "$FILE_DATE_FORMATTED" < "$CUTOFF_DATE" ]]; then
                    log_info "Deleting old S3 backup: $file"
                    aws s3 rm "s3://${S3_BUCKET}/redis/$file" --region "$S3_REGION"
                fi
            fi
        done
fi

# Summary
log_info "Backup completed successfully!"
log_info "Local backup: $BACKUP_FILE_GZ"
if [ -n "$S3_BUCKET" ]; then
    log_info "S3 backup: s3://${S3_BUCKET}/redis/$(basename "$BACKUP_FILE_GZ")"
fi

# Send notification (optional)
if command -v mail &> /dev/null && [ -n "${ADMIN_EMAIL:-}" ]; then
    echo "Redis backup completed: $(basename "$BACKUP_FILE_GZ") ($BACKUP_SIZE)" | \
        mail -s "[SUCCESS] Redis Backup - $(date +%Y-%m-%d)" "$ADMIN_EMAIL"
fi

exit 0
