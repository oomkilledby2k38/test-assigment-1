#!/bin/bash
# Простой скрипт резервного копирования PostgreSQL из Docker
# Использование: ./backup.sh
# Cron: 0 2 * * * /path/to/backup.sh

set -e

BACKUP_DIR="/opt/backups"
RETENTION_DAYS=7
CONTAINER_NAME="postgres"
DB_USER="devops"
DB_NAME="flask"

mkdir -p "$BACKUP_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup..."

# Create backup from Docker container
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/postgres_${TIMESTAMP}.sql.gz"

if docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup created: $BACKUP_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Size: $(du -h "$BACKUP_FILE" | cut -f1)"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Backup failed"
    exit 1
fi

# Cleanup old backups
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning old backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "postgres_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup completed successfully"
