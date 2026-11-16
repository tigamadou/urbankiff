#!/bin/bash

# Entrypoint script for backup service
# Handles startup and scheduling of backups

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $timestamp: $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $timestamp: $message"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $timestamp: $message"
            ;;
    esac
}

# Configuration
BACKUP_DIR="/backups"
LOG_DIR="/logs"
SCHEDULE=${BACKUP_SCHEDULE:-"0 0 * * 1"}  # Default: Every Monday at 12 AM
RETENTION_DAYS=${RETENTION_DAYS:-30}

# For testing: if TEST_MODE is enabled, run every minute
if [[ "${TEST_MODE:-false}" == "true" ]]; then
    SCHEDULE="* * * * *"  # Every minute
    log "INFO" "TEST MODE ENABLED: Running backup every minute"
fi

# Check if we should run backup immediately
if [[ "${RUN_BACKUP_NOW:-false}" == "true" ]]; then
    log "INFO" "Running backup immediately as requested"
    su -c "/scripts/backup.sh" backup
    exit $?
fi

# Check if we should run in cron mode
if [[ "${CRON_MODE:-true}" == "true" ]]; then
    log "INFO" "Starting backup service in cron mode"
    log "INFO" "Backup schedule: $SCHEDULE"
    log "INFO" "Retention days: $RETENTION_DAYS"
    
    # Create necessary directories
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
    chown -R backup:backup "$BACKUP_DIR" "$LOG_DIR"
    
    # Create cron directory
    mkdir -p /var/spool/cron/crontabs
    chown -R backup:backup /var/spool/cron/crontabs
    
    # Install cron job as root
    echo "$SCHEDULE /scripts/backup.sh >> $LOG_DIR/cron.log 2>&1" | crontab -u backup -
    
    # Switch to backup user and start cron daemon
    log "INFO" "Switching to backup user and starting cron daemon..."
    exec su -c "/startup.sh" backup
else
    log "INFO" "Starting backup service in manual mode"
    log "INFO" "Use RUN_BACKUP_NOW=true to run backup immediately"
    log "INFO" "Use CRON_MODE=false to disable automatic scheduling"
    
    # Keep container running
    tail -f /dev/null
fi
