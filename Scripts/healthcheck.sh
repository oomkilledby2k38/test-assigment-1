#!/bin/bash
# Простой healthcheck для Docker контейнеров
# Использование: ./healthcheck.sh
# Cron: */10 * * * * /path/to/healthcheck.sh

set -e

APP_URL="http://localhost:5000/register"
LOG_FILE="/var/log/healthcheck.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}


if ! docker ps | grep -q flask-app; then
    log "ERROR: Flask container not running"
    exit 1
else
    log "Application is running from Docker"
fi


if ! docker ps | grep -q postgres; then
    log "ERROR: PostgreSQL container not running"
    exit 1
else
   log "Postgres  is runnning via Docker"
fi



HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$APP_URL" || echo "000")
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
    log "OK: HTTP $HTTP_CODE"
else
    log "ERROR: HTTP $HTTP_CODE - App not responding"
    exit 1
fi


DISK_USAGE=$(df / --output=pcent | tail -1 | tr -d ' %')
if (( DISK_USAGE > 80 )); then
    log "WARNING: Disk usage ${DISK_USAGE}%"
else
    log "Everything is good with DISK_USAGE , Don't worry about that"
    log "Free space :" "$((100 - $DISK_USAGE))%"
fi

log "Healthcheck passed "