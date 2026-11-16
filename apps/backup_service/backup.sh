#!/bin/bash

# Backup script for MinIO and PostgreSQL
# Runs inside Docker container with direct access to services

set -euo pipefail

# Configuration
BACKUP_DIR="/backups"
LOG_DIR="/logs"
RETENTION_DAYS=${RETENTION_DAYS:-30}
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/backup_${DATE}.log"

# Colors for output
RED='\033[0;31m'
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
            echo -e "${GREEN}[INFO]${NC} $timestamp: $message" | tee -a "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $timestamp: $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $timestamp: $message" | tee -a "$LOG_FILE"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $timestamp: $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Error handling
error_exit() {
    log "ERROR" "Backup failed: $1"
    exit 1
}

# Cleanup function
cleanup() {
    log "INFO" "Cleaning up old backups (older than $RETENTION_DAYS days)"
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$LOG_DIR" -name "*.log" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
}

# Check if required environment variables are set
check_environment() {
    log "INFO" "Checking environment variables..."
    
    # Check PostgreSQL environment
    if [[ -z "${POSTGRES_DB:-}" ]]; then
        error_exit "POSTGRES_DB environment variable is not set"
    fi
    if [[ -z "${POSTGRES_USER:-}" ]]; then
        error_exit "POSTGRES_USER environment variable is not set"
    fi
    if [[ -z "${POSTGRES_PASSWORD:-}" ]]; then
        error_exit "POSTGRES_PASSWORD environment variable is not set"
    fi
    if [[ -z "${POSTGRES_HOST:-}" ]]; then
        error_exit "POSTGRES_HOST environment variable is not set"
    fi
    
    # Check MinIO environment
    if [[ -z "${MINIO_ROOT_USER:-}" ]]; then
        error_exit "MINIO_ROOT_USER environment variable is not set"
    fi
    if [[ -z "${MINIO_ROOT_PASSWORD:-}" ]]; then
        error_exit "MINIO_ROOT_PASSWORD environment variable is not set"
    fi
    if [[ -z "${MINIO_ENDPOINT:-}" ]]; then
        error_exit "MINIO_ENDPOINT environment variable is not set"
    fi
    
    log "INFO" "Environment variables check passed"
}

# Test MinIO connection
test_minio_connection() {
    log "INFO" "Testing MinIO connection..."
    
    # Test if MinIO endpoint is reachable
    local host_port=$(echo "$MINIO_ENDPOINT" | sed 's|http://||')
    if ! nc -z $(echo "$host_port" | cut -d: -f1) $(echo "$host_port" | cut -d: -f2); then
        error_exit "MinIO endpoint $MINIO_ENDPOINT is not reachable"
    fi
    
    log "INFO" "MinIO connection test passed"
}

# Create necessary directories
create_directories() {
    log "INFO" "Creating backup directories..."
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
    log "INFO" "Directories created successfully"
}

# PostgreSQL backup function
backup_postgresql() {
    local backup_file="${BACKUP_DIR}/postgresql_${DATE}.sql.gz"
    
    log "INFO" "Starting PostgreSQL backup..."
    
    # Test connection first
    if ! pg_isready -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB"; then
        error_exit "Cannot connect to PostgreSQL database"
    fi
    
    # Set password for pg_dump
    export PGPASSWORD="$POSTGRES_PASSWORD"
    
    # Create backup using pg_dump
    if pg_dump \
        -h "$POSTGRES_HOST" \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        --verbose \
        --clean \
        --create \
        --if-exists \
        | gzip > "$backup_file"; then
        
        local size=$(du -h "$backup_file" | cut -f1)
        log "INFO" "PostgreSQL backup completed successfully: $backup_file (Size: $size)"
        
        # Verify backup file
        if [[ -s "$backup_file" ]]; then
            log "INFO" "PostgreSQL backup file verification passed"
        else
            error_exit "PostgreSQL backup file is empty or corrupted"
        fi
    else
        error_exit "PostgreSQL backup failed"
    fi
}

# MinIO backup function using mc client
backup_minio() {
    local backup_file="${BACKUP_DIR}/minio_${DATE}.tar.gz"
    local temp_dir="/tmp/minio_backup_${DATE}"
    
    log "INFO" "Starting MinIO backup..."
    
    # Create temporary directory
    mkdir -p "$temp_dir"
    
    # Debug MinIO endpoint
    log "INFO" "MinIO Endpoint: $MINIO_ENDPOINT"
    log "INFO" "MinIO User: $MINIO_ROOT_USER"
    
    # Configure MinIO client
    log "INFO" "Configuring MinIO client..."
    if ! mc alias set backup "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" --insecure; then
        error_exit "Failed to configure MinIO client"
    fi
    log "INFO" "MinIO client configured successfully"
    
    # List buckets
    log "INFO" "Available MinIO buckets:"
    if ! mc ls backup --insecure | tee -a "$LOG_FILE"; then
        error_exit "Failed to list MinIO buckets"
    fi
    
    # Download all buckets to temp directory
    log "INFO" "Downloading MinIO data..."
    if mc mirror backup "$temp_dir" --insecure; then
        log "INFO" "MinIO data downloaded successfully"
        
        # Create compressed archive
        if tar -czf "$backup_file" -C "$temp_dir" .; then
            local size=$(du -h "$backup_file" | cut -f1)
            log "INFO" "MinIO backup completed successfully: $backup_file (Size: $size)"
            
            # Verify backup file
            if [[ -s "$backup_file" ]]; then
                log "INFO" "MinIO backup file verification passed"
            else
                error_exit "MinIO backup file is empty or corrupted"
            fi
        else
            error_exit "MinIO backup compression failed"
        fi
    else
        error_exit "MinIO data download failed"
    fi
    
    # Cleanup temp directory
    rm -rf "$temp_dir"
}

# Verify backups function
verify_backups() {
    log "INFO" "Verifying backup integrity..."
    
    local postgres_backup="${BACKUP_DIR}/postgresql_${DATE}.sql.gz"
    local minio_backup="${BACKUP_DIR}/minio_${DATE}.tar.gz"
    
    # Check if backup files exist and have content
    if [[ ! -f "$postgres_backup" ]] || [[ ! -s "$postgres_backup" ]]; then
        error_exit "PostgreSQL backup file is missing or empty"
    fi
    
    if [[ ! -f "$minio_backup" ]] || [[ ! -s "$minio_backup" ]]; then
        error_exit "MinIO backup file is missing or empty"
    fi
    
    # Test PostgreSQL backup integrity
    log "INFO" "Testing PostgreSQL backup integrity..."
    if ! gunzip -t "$postgres_backup" 2>/dev/null; then
        error_exit "PostgreSQL backup file is corrupted"
    fi
    
    # Test MinIO backup integrity
    log "INFO" "Testing MinIO backup integrity..."
    if ! tar -tzf "$minio_backup" >/dev/null 2>&1; then
        error_exit "MinIO backup file is corrupted"
    fi
    
    log "INFO" "All backup integrity checks passed"
}

# Main backup function
main() {
    log "INFO" "=== Starting backup process ==="
    log "INFO" "Backup started at: $(date)"
    
    # Check environment
    check_environment
    
    # Test MinIO connection
    test_minio_connection
    
    # Create directories
    create_directories
    
    # Perform backups
    backup_postgresql
    backup_minio
    
    # Verify backups
    verify_backups
    
    # Cleanup old backups
    cleanup
    
    log "INFO" "=== Backup process completed successfully ==="
    log "INFO" "Backup completed at: $(date)"
    
    # Exit successfully
    exit 0
}

# Trap errors and cleanup
trap 'error_exit "Unexpected error occurred"' ERR
trap 'cleanup' EXIT

# Run main function
main "$@"
