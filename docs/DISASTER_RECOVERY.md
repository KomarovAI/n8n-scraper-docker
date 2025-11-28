# Disaster Recovery Guide

**Last Updated**: 2025-11-28  
**Version**: 1.0  
**Target Audience**: DevOps, SRE, System Administrators

---

## 🎯 Recovery Objectives

| Metric | Target | Notes |
|--------|--------|-------|
| **RTO** (Recovery Time Objective) | ≤ 2 hours | Time to restore full system |
| **RPO** (Recovery Point Objective) | ≤ 24 hours | Maximum data loss acceptable |
| **Backup Frequency** | Daily (automated) | PostgreSQL + volumes |
| **Backup Retention** | 30 days | Compliance requirement |

---

## 📦 Backup Procedures

### 1. PostgreSQL Database Backup

#### Manual Backup
```bash
# Full database backup with timestamp
docker-compose exec postgres pg_dump -U n8n_user n8n_db > backups/backup-$(date +%F).sql

# Verify backup
ls -lh backups/backup-$(date +%F).sql

# Compressed backup (recommended for large DBs)
docker-compose exec postgres pg_dump -U n8n_user n8n_db | gzip > backups/backup-$(date +%F).sql.gz
```

#### Automated Daily Backup (Cron)
```bash
# Add to crontab: sudo crontab -e
0 2 * * * cd /path/to/n8n-scraper-docker && docker-compose exec -T postgres pg_dump -U n8n_user n8n_db | gzip > backups/backup-$(date +\%F).sql.gz 2>&1 | logger -t n8n-backup

# Keep only last 30 days
0 3 * * * find /path/to/n8n-scraper-docker/backups -name "backup-*.sql.gz" -mtime +30 -delete
```

#### Schema-Only Backup (for migrations)
```bash
docker-compose exec postgres pg_dump -U n8n_user -s n8n_db > backups/schema-$(date +%F).sql
```

---

### 2. Docker Volumes Backup

#### Critical Volumes
```
postgres-data    → Database persistence
n8n-data         → n8n workflows + credentials
redis-data       → Cache + rate limiting state
ollama-data      → ML models (~4GB)
ml-models        → Trained classifiers
grafana-data     → Dashboards
prometheus-data  → Metrics (optional)
```

#### Backup All Volumes
```bash
#!/bin/bash
# scripts/backup-volumes.sh

BACKUP_DIR="./backups/volumes-$(date +%F)"
mkdir -p "$BACKUP_DIR"

VOLUMES=("postgres-data" "n8n-data" "redis-data" "ollama-data" "ml-models" "grafana-data")

for VOLUME in "${VOLUMES[@]}"; do
  echo "Backing up $VOLUME..."
  docker run --rm \
    -v "n8n-scraper-docker_$VOLUME:/data" \
    -v "$(pwd)/$BACKUP_DIR:/backup" \
    alpine tar czf "/backup/$VOLUME.tar.gz" -C /data .
done

echo "✅ All volumes backed up to $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
```

#### Quick n8n Workflows Backup (Most Important)
```bash
# Backup only n8n workflows + credentials
docker run --rm \
  -v n8n-scraper-docker_n8n-data:/data \
  -v "$(pwd)/backups":/backup \
  alpine tar czf /backup/n8n-critical-$(date +%F).tar.gz -C /data .

echo "✅ n8n workflows backed up"
```

---

## 🔄 Restore Procedures

### 1. PostgreSQL Restore

#### Full Database Restore
```bash
# Stop n8n to avoid conflicts
docker-compose stop n8n

# Drop and recreate database
docker-compose exec postgres psql -U n8n_user -c "DROP DATABASE n8n_db;"
docker-compose exec postgres psql -U n8n_user -c "CREATE DATABASE n8n_db;"

# Restore from backup
cat backups/backup-2025-11-28.sql | docker-compose exec -T postgres psql -U n8n_user n8n_db

# Or restore from compressed
gunzip -c backups/backup-2025-11-28.sql.gz | docker-compose exec -T postgres psql -U n8n_user n8n_db

# Restart n8n
docker-compose start n8n

# Verify
curl -sf http://localhost:5678/healthz && echo "✅ n8n restored successfully"
```

#### Partial Restore (Specific Tables)
```bash
# Restore only executions table
cat backups/backup-2025-11-28.sql | \
  docker-compose exec -T postgres psql -U n8n_user n8n_db \
  -c "\COPY execution_entity FROM stdin WITH (FORMAT csv, HEADER true);"
```

---

### 2. Docker Volumes Restore

#### Restore All Volumes
```bash
#!/bin/bash
# scripts/restore-volumes.sh

BACKUP_DATE="2025-11-28"  # Change to your backup date
BACKUP_DIR="./backups/volumes-$BACKUP_DATE"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "❌ Backup directory not found: $BACKUP_DIR"
  exit 1
fi

# Stop all services
docker-compose down

VOLUMES=("postgres-data" "n8n-data" "redis-data" "ollama-data" "ml-models" "grafana-data")

for VOLUME in "${VOLUMES[@]}"; do
  echo "Restoring $VOLUME..."
  
  # Remove old volume
  docker volume rm "n8n-scraper-docker_$VOLUME" 2>/dev/null || true
  
  # Create new volume
  docker volume create "n8n-scraper-docker_$VOLUME"
  
  # Restore from backup
  docker run --rm \
    -v "n8n-scraper-docker_$VOLUME:/data" \
    -v "$(pwd)/$BACKUP_DIR:/backup" \
    alpine sh -c "cd /data && tar xzf /backup/$VOLUME.tar.gz"
done

echo "✅ All volumes restored from $BACKUP_DIR"

# Start services
docker-compose up -d
```

#### Quick n8n Restore (Most Common)
```bash
# Stop n8n
docker-compose stop n8n

# Restore n8n data
docker run --rm \
  -v n8n-scraper-docker_n8n-data:/data \
  -v "$(pwd)/backups":/backup \
  alpine sh -c "cd /data && tar xzf /backup/n8n-critical-2025-11-28.tar.gz"

# Restart n8n
docker-compose start n8n

echo "✅ n8n workflows restored"
```

---

## 🚨 Emergency Recovery Checklist

### Scenario 1: Complete System Failure (Hardware/VM Loss)

**Time to Recovery**: ~1-2 hours

```bash
# 1. Provision new server (same specs)
sudo apt update && sudo apt install -y docker.io docker-compose git

# 2. Clone repository
git clone https://github.com/KomarovAI/n8n-scraper-docker.git
cd n8n-scraper-docker

# 3. Restore .env file (from secure backup location)
scp backup-server:/secure/backups/.env .

# 4. Restore volumes from backup
./scripts/restore-volumes.sh

# 5. Start services
docker-compose up -d

# 6. Verify all services
docker-compose ps
curl -sf http://localhost:5678/healthz && echo "✅ n8n OK"
curl -sf http://localhost:9090/-/healthy && echo "✅ Prometheus OK"
curl -sf http://localhost:3000 && echo "✅ Grafana OK"

# 7. Test workflows
# Login to n8n UI and manually trigger test workflow
```

---

### Scenario 2: Database Corruption

**Time to Recovery**: ~30 minutes

```bash
# 1. Stop n8n immediately
docker-compose stop n8n

# 2. Backup corrupted database (for forensics)
docker-compose exec postgres pg_dump -U n8n_user n8n_db > backups/corrupted-$(date +%F).sql || true

# 3. Restore from last good backup
gunzip -c backups/backup-2025-11-27.sql.gz | docker-compose exec -T postgres psql -U n8n_user n8n_db

# 4. Verify restore
docker-compose exec postgres psql -U n8n_user n8n_db -c "SELECT COUNT(*) FROM workflow_entity;"

# 5. Restart n8n
docker-compose start n8n

# 6. Check logs
docker-compose logs -f n8n
```

---

### Scenario 3: Accidental Data Deletion (n8n Workflows)

**Time to Recovery**: ~10 minutes

```bash
# 1. Stop n8n
docker-compose stop n8n

# 2. Restore n8n volume from backup
docker run --rm \
  -v n8n-scraper-docker_n8n-data:/data \
  -v "$(pwd)/backups":/backup \
  alpine sh -c "cd /data && tar xzf /backup/n8n-critical-2025-11-28.tar.gz"

# 3. Restart n8n
docker-compose start n8n

# 4. Verify in UI
open http://localhost:5678
```

---

## 📊 Backup Verification

### Weekly Backup Test (Recommended)

```bash
#!/bin/bash
# scripts/test-backup-restore.sh

echo "🧪 Testing backup restore (dry run)..."

# 1. Create test backup
BACKUP_FILE="backups/test-backup-$(date +%F).sql.gz"
docker-compose exec postgres pg_dump -U n8n_user n8n_db | gzip > "$BACKUP_FILE"

# 2. Verify backup file
if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ Backup file not created"
  exit 1
fi

SIZE=$(stat -c%s "$BACKUP_FILE")
if [ "$SIZE" -lt 1000 ]; then
  echo "❌ Backup file too small ($SIZE bytes)"
  exit 1
fi

echo "✅ Backup file created successfully ($SIZE bytes)"

# 3. Test restore (in temporary container)
docker run --rm \
  -e POSTGRES_PASSWORD=test \
  -v "$(pwd)/$BACKUP_FILE":/backup.sql.gz \
  postgres:16-alpine sh -c '
    initdb -D /tmp/testdb && \
    postgres -D /tmp/testdb & \
    sleep 5 && \
    createdb -U postgres testdb && \
    gunzip -c /backup.sql.gz | psql -U postgres testdb && \
    psql -U postgres testdb -c "SELECT COUNT(*) FROM workflow_entity;" && \
    echo "✅ Restore test successful"
  '

# 4. Cleanup test backup
rm "$BACKUP_FILE"

echo "✅ Backup verification complete"
```

---

## 🔒 Security Considerations

### Backup Encryption (Recommended for Production)

```bash
# Encrypt backup with GPG
docker-compose exec postgres pg_dump -U n8n_user n8n_db | \
  gzip | \
  gpg --symmetric --cipher-algo AES256 > backups/backup-$(date +%F).sql.gz.gpg

# Decrypt and restore
gpg --decrypt backups/backup-2025-11-28.sql.gz.gpg | \
  gunzip | \
  docker-compose exec -T postgres psql -U n8n_user n8n_db
```

### Off-Site Backup (Production Requirement)

```bash
# Upload to S3 (example)
aws s3 cp backups/backup-$(date +%F).sql.gz \
  s3://your-bucket/n8n-backups/ \
  --storage-class GLACIER

# Or rsync to remote server
rsync -avz backups/ backup-server:/secure/n8n-backups/
```

---

## 📝 Backup Monitoring

### Automated Backup Alerts

```bash
# Add to cron - send email if backup fails
0 2 * * * /path/to/scripts/backup-with-alert.sh || echo "Backup failed" | mail -s "n8n Backup Failed" admin@example.com
```

### Backup Status Check

```bash
# Check last backup age
LAST_BACKUP=$(ls -t backups/backup-*.sql.gz | head -1)
BACKUP_AGE=$(($(date +%s) - $(stat -c%Y "$LAST_BACKUP")))
BACKUP_AGE_HOURS=$((BACKUP_AGE / 3600))

if [ $BACKUP_AGE_HOURS -gt 48 ]; then
  echo "⚠️ Last backup is $BACKUP_AGE_HOURS hours old"
  exit 1
fi

echo "✅ Last backup: $LAST_BACKUP ($BACKUP_AGE_HOURS hours ago)"
```

---

## 📚 References

- [PostgreSQL Backup Documentation](https://www.postgresql.org/docs/current/backup.html)
- [Docker Volume Backup Best Practices](https://docs.docker.com/storage/volumes/#back-up-restore-or-migrate-data-volumes)
- [n8n Database Migration Guide](https://docs.n8n.io/hosting/installation/docker/#upgrading)

---

**Last Verified**: 2025-11-28  
**Maintainer**: DevOps Team  
**Review Cycle**: Quarterly
