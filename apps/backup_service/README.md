# Docker Backup Service

A dedicated Docker service for automated backups of MinIO and PostgreSQL, integrated directly into your Docker Compose stack.

## 🚀 **Features**

- **Integrated Service**: Runs as part of your Docker Compose stack
- **Automatic Scheduling**: Built-in cron scheduling (default: every Monday at 12 AM GMT+1)
- **Secure Access**: Direct access to services within Docker network
- **Comprehensive Logging**: Detailed logs with colored output
- **Automatic Cleanup**: Removes old backups and logs automatically
- **Health Checks**: Built-in health monitoring
- **Easy Management**: Simple management script for all operations

## 🏗️ **Architecture**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │     MinIO       │    │  Backup Service │
│   Container     │◄──►│   Container     │◄──►│   Container     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Docker Volumes │
                    │  - backup_data  │
                    │  - backup_logs  │
                    └─────────────────┘
```

## 📋 **Prerequisites**

- Docker and Docker Compose
- PostgreSQL and MinIO containers running
- Environment variables properly configured

## 🚀 **Quick Start**

### **1. Build the Service**
```bash
make backup-build
# or
cd backup-service && ./manage.sh build
```

### **2. Start the Service**
```bash
make backup-start
# or
cd backup-service && ./manage.sh start
```

### **3. Check Status**
```bash
make backup-status
# or
cd backup-service && ./manage.sh status
```

## 🛠️ **Management Commands**

### **Using Makefile (Recommended)**
```bash
make backup-build      # Build the service
make backup-start      # Start the service
make backup-stop       # Stop the service
make backup-restart    # Restart the service
make backup-logs       # View logs
make backup-run        # Run backup immediately
make backup-status     # Check status
make backup-clean      # Clean old backups
make backup-test-on    # Enable test mode (every minute)
make backup-test-off   # Disable test mode (weekly)
```

### **Using Management Script**
```bash
cd backup-service
./manage.sh build      # Build the service
./manage.sh start      # Start the service
./manage.sh stop       # Stop the service
./manage.sh restart    # Restart the service
./manage.sh logs       # View logs
./manage.sh backup     # Run backup immediately
./manage.sh status     # Check status
./manage.sh clean      # Clean old backups
```

## ⚙️ **Configuration**

### **Environment Variables**

The backup service uses these environment variables from your `.env` file:

```bash
# PostgreSQL Configuration
POSTGRES_DB=your_database_name
POSTGRES_USER=your_database_user
POSTGRES_PASSWORD=your_database_password

# MinIO Configuration
MINIO_ROOT_USER=your_minio_user
MINIO_ROOT_PASSWORD=your_minio_password
```

### **Backup Configuration**

```yaml
# In docker-compose.yml
environment:
  - BACKUP_SCHEDULE=0 0 * * 1  # Every Monday at 12 AM GMT+1
  - RETENTION_DAYS=30           # Keep backups for 30 days
  - CRON_MODE=true              # Enable automatic scheduling
```

### **Customizing Schedule**

Modify the `BACKUP_SCHEDULE` environment variable:

```bash
# Every Monday at 12 AM
BACKUP_SCHEDULE="0 0 * * 1"

# Every Monday at 2 AM
BACKUP_SCHEDULE="0 2 * * 1"

# Every day at 6 AM
BACKUP_SCHEDULE="0 6 * * *"

# Every 6 hours
BACKUP_SCHEDULE="0 */6 * * *"
```

### **Test Mode**

For testing purposes, you can enable test mode which runs backups every minute:

```bash
# Enable test mode (runs every minute)
make backup-test-on

# Disable test mode (runs weekly)
make backup-test-off
```

**⚠️ Warning**: Test mode should only be used for testing. Remember to disable it for production!

## 📁 **File Structure**

```
backup-service/
├── Dockerfile          # Container definition
├── backup.sh           # Main backup script
├── entrypoint.sh       # Container startup script
├── manage.sh           # Management script
└── README.md           # This documentation
```

## 🔍 **Monitoring and Logs**

### **View Service Logs**
```bash
make backup-logs
# or
docker-compose logs -f backup
```

### **Check Service Status**
```bash
make backup-status
```

### **Access Container Shell**
```bash
docker-compose exec backup sh
```

### **View Cron Jobs**
```bash
docker-compose exec backup crontab -l
```

## 🧪 **Testing**

### **Run Backup Immediately**
```bash
make backup-run
```

### **Test Connection**
```bash
# Test PostgreSQL connection
docker-compose exec backup pg_isready -h postgresDB -U $POSTGRES_USER -d $POSTGRES_DB

# Test MinIO connection
docker-compose exec backup mc alias set test http://minio:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD --insecure
```

## 🔒 **Security Features**

- **Non-root User**: Runs as dedicated `backup` user
- **Network Isolation**: Only accessible within Docker network
- **Volume Mounts**: Secure volume mounting for data
- **Health Checks**: Built-in health monitoring
- **Error Handling**: Comprehensive error handling and logging

## 📊 **Backup Details**

### **PostgreSQL Backup**
- Full database dump using `pg_dump`
- Compressed with gzip
- Includes schema and data
- Clean and create statements for easy restoration

### **MinIO Backup**
- Downloads all buckets using MinIO client (`mc`)
- Creates compressed tar archive
- Preserves bucket structure
- Handles large files efficiently

### **Backup Files**
```
/backups/
├── postgresql_20241216_120000.sql.gz  # PostgreSQL backup
└── minio_20241216_120000.tar.gz       # MinIO backup

/logs/
├── backup_20241216_120000.log         # Backup log
└── cron.log                           # Cron output
```

## 🚨 **Troubleshooting**

### **Common Issues**

#### **1. Service Won't Start**
```bash
# Check logs
make backup-logs

# Check container status
docker-compose ps backup
```

#### **2. Backup Fails**
```bash
# Check environment variables
docker-compose exec backup env | grep -E "POSTGRES_|MINIO_"

# Test connections manually
docker-compose exec backup /scripts/backup.sh
```

#### **3. Cron Not Working**
```bash
# Check cron status
docker-compose exec backup crontab -l

# Check cron logs
docker-compose exec backup tail -f /logs/cron.log
```

### **Debug Mode**
```bash
# Run with debug output
docker-compose exec -e DEBUG=true backup /scripts/backup.sh
```

## 🔄 **Maintenance**

### **Clean Old Backups**
```bash
make backup-clean
```

### **Update Service**
```bash
make backup-stop
make backup-build
make backup-start
```

### **View Disk Usage**
```bash
# Check backup volume size
docker run --rm -v urbankiff_backup_data:/backups alpine du -sh /backups

# Check logs volume size
docker run --rm -v urbankiff_backup_logs:/logs alpine du -sh /logs
```

## 📈 **Performance Considerations**

- **Scheduling**: Runs during low-traffic hours (12 AM)
- **Compression**: Uses gzip for PostgreSQL, tar for MinIO
- **Cleanup**: Automatic removal of old backups
- **Health Checks**: Regular health monitoring
- **Resource Limits**: Lightweight Alpine-based container

## 🔗 **Integration**

### **With Existing Services**
- Automatically starts after PostgreSQL and MinIO
- Uses same network (`URBANKIFF`)
- Shares environment variables
- Health check integration

### **With Monitoring**
- Health check endpoint available
- Structured logging
- Error reporting
- Status monitoring

## 📚 **Advanced Usage**

### **Custom Backup Scripts**
```bash
# Mount custom scripts
volumes:
  - ./custom-scripts:/scripts/custom:ro
```

### **External Storage**
```bash
# Mount external storage
volumes:
  - /mnt/backups:/backups
  - /mnt/logs:/logs
```

### **Multiple Schedules**
```bash
# Run different backup types at different times
environment:
  - BACKUP_SCHEDULE="0 0 * * 1"      # Full backup on Monday
  - INCREMENTAL_SCHEDULE="0 6 * * *"  # Daily incremental
```

## 🆘 **Support**

For issues or questions:

1. Check the logs: `make backup-logs`
2. Verify configuration: `make backup-status`
3. Test connections manually
4. Check Docker Compose logs
5. Review environment variables

## 📄 **License**

This backup service is part of the Urbankiff project.
