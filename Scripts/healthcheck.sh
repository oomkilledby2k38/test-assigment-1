#!/bin/bash
# Простой healthcheck для Docker контейнеров
# Использование: ./healthcheck.sh
# Cron: */10 * * * * /path/to/healthcheck.sh

set -e

APP_URL="http://localhost:5000"
LOG_FILE="/var/log/healthcheck.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Check Flask app container
if ! docker ps | grep -q flask-app; then
    log "ERROR: Flask container not running"
    exit 1
fi

# Check PostgreSQL container
if ! docker ps | grep -q postgres; then
    log "ERROR: PostgreSQL container not running"
    exit 1
fi

# Check Nginx container (if on VM2)
if docker ps | grep -q nginx; then
    log "INFO: Nginx container running"
fi

# Check HTTP response
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$APP_URL" || echo "000")
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
    log "OK: HTTP $HTTP_CODE"
else
    log "ERROR: HTTP $HTTP_CODE - App not responding"
    exit 1
fi

# Check disk space
DISK_USAGE=$(df / --output=pcent | tail -1 | tr -d ' %')
if (( DISK_USAGE > 80 )); then
    log "WARNING: Disk usage ${DISK_USAGE}%"
fi

log "Healthcheck passed ✓"
