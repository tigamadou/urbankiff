FROM alpine:latest

# Install necessary tools
RUN apk add --no-cache \
    postgresql-client \
    curl \
    tar \
    gzip \
    bash \
    jq \
    dcron \
    netcat-openbsd \
    && rm -rf /var/cache/apk/*

# Install MinIO client (mc) - latest version
RUN wget https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc && \
    mc --version

# Create backup user
RUN addgroup -g 1000 backup && \
    adduser -D -s /bin/bash -u 1000 -G backup backup

# Create backup directories
RUN mkdir -p /backups /logs /scripts && \
    chown -R backup:backup /backups /logs /scripts

# Give backup user cron permissions
RUN mkdir -p /var/spool/cron/crontabs && \
    chown -R backup:backup /var/spool/cron/crontabs && \
    chmod 755 /var/spool/cron/crontabs && \
    chmod 4755 /usr/bin/crontab

# Fix su command permissions
RUN chmod 4755 /bin/su

# Copy backup scripts
COPY backup.sh /scripts/
COPY entrypoint.sh /scripts/
COPY manage.sh /scripts/

# Make scripts executable
RUN chmod +x /scripts/*.sh

# Set working directory
WORKDIR /backups

# Switch to backup user (will be handled in entrypoint)
# USER backup

# Create a startup script that will be run as backup user
RUN echo '#!/bin/bash' > /startup.sh && \
    echo 'if [[ "${TEST_MODE:-false}" == "true" ]]; then' >> /startup.sh && \
    echo '    echo "TEST MODE: Running backup every minute"' >> /startup.sh && \
    echo '    while true; do' >> /startup.sh && \
    echo '        /scripts/backup.sh' >> /startup.sh && \
    echo '        sleep 60' >> /startup.sh && \
    echo '    done' >> /startup.sh && \
    echo 'else' >> /startup.sh && \
    echo '    echo "Starting cron daemon..."' >> /startup.sh && \
    echo '    crond -f' >> /startup.sh && \
    echo 'fi' >> /startup.sh && \
    chmod +x /startup.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pg_isready -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB || exit 1

# Default command
CMD ["/scripts/entrypoint.sh"]
