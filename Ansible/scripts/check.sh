#!/bin/bash

# Optimized deployment verification script
# Hardcoded values for quick Ansible testing

set -o pipefail

# Hardcoded configuration
readonly HOST="localhost"
readonly DB_USER="root"
readonly DB_PASS="your_password_here"
readonly DB_NAME="testdb"
readonly BACKUP_DIR="/tmp/backups"
readonly TIMEOUT=5

# Colors for output
readonly GREEN="\033[0;32m"
readonly RED="\033[0;31m"
readonly NC="\033[0m"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1

# Utility functions
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_failure() { echo -e "${RED}✗${NC} $1"; }

# Check HTTP service
check_http() {
    if curl -f -s --max-time "$TIMEOUT" "http://$HOST" >/dev/null 2>&1; then
        log_success "HTTP service accessible"
        return 0
    fi
    log_failure "HTTP service not accessible"
    return 1
}

# Check HTTPS service
check_https() {
    if curl -f -s --max-time "$TIMEOUT" -k "https://$HOST" >/dev/null 2>&1; then
        log_success "HTTPS service accessible"
        return 0
    fi
    log_failure "HTTPS service not accessible"
    return 1
}

# Check database connection
check_database() {
    if command -v mysql >/dev/null 2>&1 && \
       mysql -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1;" >/dev/null 2>&1; then
        log_success "Database connection successful"
        return 0
    fi
    log_failure "Database connection failed"
    return 1
}

# Test backup
test_backup() {
    local backup_file="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql"
    mkdir -p "$BACKUP_DIR" || return 1
    
    if mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$backup_file" 2>/dev/null && \
       [ -s "$backup_file" ]; then
        log_success "Backup successful"
        echo "$backup_file"
        return 0
    fi
    log_failure "Backup failed"
    return 1
}

# Test restore
test_restore() {
    local backup_file="$1"
    local test_db="test_restore_$(date +%Y%m%d_%H%M%S)"
    
    [ -z "$backup_file" ] && { log_failure "No backup file provided"; return 1; }
    
    if mysql -u "$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE $test_db;" >/dev/null 2>&1 && \
       mysql -u "$DB_USER" -p"$DB_PASS" "$test_db" < "$backup_file" >/dev/null 2>&1; then
        mysql -u "$DB_USER" -p"$DB_PASS" -e "DROP DATABASE $test_db;" >/dev/null 2>&1
        log_success "Restore successful"
        return 0
    fi
    mysql -u "$DB_USER" -p"$DB_PASS" -e "DROP DATABASE IF EXISTS $test_db;" >/dev/null 2>&1
    log_failure "Restore failed"
    return 1
}

# Main execution
main() {
    echo "Starting verification on $HOST..."
    
    local exit_code=$EXIT_SUCCESS
    
    check_http || exit_code=$EXIT_FAILURE
    check_https || exit_code=$EXIT_FAILURE
    check_database || exit_code=$EXIT_FAILURE
    
    local backup_file
    backup_file=$(test_backup) || exit_code=$EXIT_FAILURE
    
    [ -n "$backup_file" ] && { test_restore "$backup_file" || exit_code=$EXIT_FAILURE; }
    
    echo "Verification completed!"
    return $exit_code
}

main "$@"
