#!/bin/bash

# Management script for backup service
# Run this from the project root directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    echo "Backup Service Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build     Build the backup service image"
    echo "  start     Start the backup service"
    echo "  stop      Stop the backup service"
    echo "  restart   Restart the backup service"
    echo "  logs      Show backup service logs"
    echo "  backup    Run backup immediately"
    echo "  status    Show backup service status"
    echo "  clean     Clean old backups and logs"
    echo "  test-on   Enable test mode (runs every minute)"
    echo "  test-off  Disable test mode (runs weekly)"
    echo "  shell     Access backup service shell"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build     # Build the backup service"
    echo "  $0 backup    # Run backup immediately"
    echo "  $0 logs      # View backup logs"
    echo "  $0 shell     # Access backup service shell"
}

build_service() {
    echo -e "${BLUE}Building backup service...${NC}"
    cd "$PROJECT_ROOT"
    docker-compose build backup
    echo -e "${GREEN}Backup service built successfully${NC}"
}

start_service() {
    echo -e "${BLUE}Starting backup service...${NC}"
    cd "$PROJECT_ROOT"
    docker-compose up -d backup
    echo -e "${GREEN}Backup service started${NC}"
}

stop_service() {
    echo -e "${BLUE}Stopping backup service...${NC}"
    cd "$PROJECT_ROOT"
    docker-compose stop backup
    echo -e "${GREEN}Backup service stopped${NC}"
}

restart_service() {
    echo -e "${BLUE}Restarting backup service...${NC}"
    cd "$PROJECT_ROOT"
    docker-compose restart backup
    echo -e "${GREEN}Backup service restarted${NC}"
}

show_logs() {
    echo -e "${BLUE}Showing backup service logs...${NC}"
    cd "$PROJECT_ROOT"
    docker-compose logs -f backup
}

run_backup() {
    echo -e "${BLUE}Running backup immediately...${NC}"
    cd "$PROJECT_ROOT"
    docker-compose exec -e RUN_BACKUP_NOW=true backup /scripts/backup.sh
}

show_status() {
    echo -e "${BLUE}Backup Service Status${NC}"
    echo "========================"
    
    cd "$PROJECT_ROOT"
    
    # Check if service is running
    if docker-compose ps backup | grep -q "Up"; then
        echo -e "${GREEN}✓ Service is running${NC}"
    else
        echo -e "${RED}✗ Service is not running${NC}"
    fi
    
    # Show recent backups
    echo ""
    echo "Recent backups:"
    if [ -d "./backups" ]; then
        ls -la ./backups/ 2>/dev/null || echo "No backups found"
    else
        echo "Backups directory not found"
    fi
    
    # Show recent logs
    echo ""
    echo "Recent logs:"
    if [ -d "./backups/logs" ]; then
        ls -la ./backups/logs/ 2>/dev/null || echo "No logs found"
    else
        echo "Logs directory not found"
    fi
    
    # Show cron status
    echo ""
    echo "Cron status:"
    docker-compose exec backup crontab -l 2>/dev/null || echo "Cron not accessible"
}

clean_backups() {
    echo -e "${BLUE}Cleaning old backups and logs...${NC}"
    cd "$PROJECT_ROOT"
    
    # Clean old backups (older than 30 days)
    if [ -d "./backups" ]; then
        find ./backups -name "*.sql.gz" -mtime +30 -delete 2>/dev/null || true
        find ./backups -name "*.tar.gz" -mtime +30 -delete 2>/dev/null || true
    fi
    
    # Clean old logs (older than 30 days)
    if [ -d "./backups/logs" ]; then
        find ./backups/logs -name "*.log" -mtime +30 -delete 2>/dev/null || true
    fi
    
    echo -e "${GREEN}Cleanup completed${NC}"
}

enable_test_mode() {
    echo -e "${BLUE}Enabling test mode (backup every minute)...${NC}"
    cd "$PROJECT_ROOT"
    
    # Update docker-compose.yml to enable test mode
    if sed -i.bak 's/TEST_MODE=false/TEST_MODE=true/g' docker-compose.yml 2>/dev/null || \
       sed -i.bak 's/- TEST_MODE=false  # Disable test mode/- TEST_MODE=true  # Enable test mode (runs every minute) - DISABLE FOR PRODUCTION/g' docker-compose.yml 2>/dev/null; then
        echo -e "${GREEN}✓ Test mode enabled in docker-compose.yml${NC}"
    else
        echo -e "${YELLOW}⚠ Could not update docker-compose.yml automatically${NC}"
        echo "Please manually set TEST_MODE=true in docker-compose.yml"
    fi
    
    # Restart the backup service to apply changes
    echo -e "${BLUE}Restarting backup service to apply test mode...${NC}"
    docker-compose restart backup
    
    echo -e "${GREEN}Test mode enabled! Backups will run every minute.${NC}"
    echo -e "${YELLOW}⚠ Remember to disable test mode for production!${NC}"
}

disable_test_mode() {
    echo -e "${BLUE}Disabling test mode (backup weekly)...${NC}"
    cd "$PROJECT_ROOT"
    
    # Update docker-compose.yml to disable test mode
    if sed -i.bak 's/TEST_MODE=true  # Enable test mode (runs every minute) - DISABLE FOR PRODUCTION/- TEST_MODE=false  # Disable test mode/g' docker-compose.yml 2>/dev/null || \
       sed -e 's/TEST_MODE=true/TEST_MODE=false/g' docker-compose.yml 2>/dev/null; then
        echo -e "${GREEN}✓ Test mode disabled in docker-compose.yml${NC}"
    else
        echo -e "${YELLOW}⚠ Could not update docker-compose.yml automatically${NC}"
        echo "Please manually set TEST_MODE=false in docker-compose.yml"
    fi
    
    # Restart the backup service to apply changes
    echo -e "${BLUE}Restarting backup service to apply normal schedule...${NC}"
    docker-compose restart backup
    
    echo -e "${GREEN}Test mode disabled! Backups will run weekly on Monday at 12 AM.${NC}"
}

access_shell() {
    echo -e "${BLUE}Accessing backup service shell...${NC}"
    cd "$PROJECT_ROOT"
    docker-compose exec backup /bin/bash
}

# Main script logic
case "${1:-help}" in
    build)
        build_service
        ;;
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    logs)
        show_logs
        ;;
    backup)
        run_backup
        ;;
    status)
        show_status
        ;;
    clean)
        clean_backups
        ;;
    test-on)
        enable_test_mode
        ;;
    test-off)
        disable_test_mode
        ;;
    shell)
        access_shell
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
