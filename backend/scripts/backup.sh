#!/bin/bash

# UrGood Database Backup Script
# Automated PostgreSQL backup with retention and monitoring

set -euo pipefail

# Configuration
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-urgood}"
POSTGRES_DB="${POSTGRES_DB:-urgood_production}"
BACKUP_DIR="/backups"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/urgood_backup_${TIMESTAMP}.sql"
LOG_FILE="${BACKUP_DIR}/backup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${2:-$NC}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "❌ ERROR: $1" "$RED"
    exit 1
}

# Success logging
success() {
    log "✅ $1" "$GREEN"
}

# Warning logging
warning() {
    log "⚠️ $1" "$YELLOW"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

log "🚀 Starting UrGood database backup..."

# Check if PostgreSQL is accessible
if ! pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
    error_exit "PostgreSQL is not accessible at ${POSTGRES_HOST}:${POSTGRES_PORT}"
fi

success "PostgreSQL connection verified"

# Create backup
log "📦 Creating backup: $BACKUP_FILE"

if pg_dump -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    --verbose \
    --no-password \
    --format=custom \
    --compress=9 \
    --no-privileges \
    --no-owner \
    --file="$BACKUP_FILE.custom" 2>>"$LOG_FILE"; then
    
    success "Custom format backup created: ${BACKUP_FILE}.custom"
else
    error_exit "Failed to create custom format backup"
fi

# Also create SQL format for easier inspection
if pg_dump -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    --verbose \
    --no-password \
    --format=plain \
    --no-privileges \
    --no-owner \
    --file="$BACKUP_FILE" 2>>"$LOG_FILE"; then
    
    success "SQL format backup created: $BACKUP_FILE"
else
    warning "Failed to create SQL format backup (custom format still available)"
fi

# Compress SQL backup
if [ -f "$BACKUP_FILE" ]; then
    gzip "$BACKUP_FILE"
    success "SQL backup compressed: ${BACKUP_FILE}.gz"
fi

# Verify backup integrity
log "🔍 Verifying backup integrity..."

if pg_restore --list "$BACKUP_FILE.custom" >/dev/null 2>&1; then
    success "Backup integrity verified"
else
    error_exit "Backup integrity check failed"
fi

# Get backup size
BACKUP_SIZE=$(du -h "$BACKUP_FILE.custom" | cut -f1)
success "Backup size: $BACKUP_SIZE"

# Create backup metadata
cat > "${BACKUP_FILE}.meta" << EOF
{
    "timestamp": "$TIMESTAMP",
    "database": "$POSTGRES_DB",
    "host": "$POSTGRES_HOST",
    "size": "$BACKUP_SIZE",
    "format": "custom",
    "compression": "9",
    "created_at": "$(date -Iseconds)",
    "retention_days": $RETENTION_DAYS
}
EOF

success "Backup metadata created"

# Clean up old backups
log "🧹 Cleaning up backups older than $RETENTION_DAYS days..."

DELETED_COUNT=0
while IFS= read -r -d '' file; do
    rm "$file"
    ((DELETED_COUNT++))
done < <(find "$BACKUP_DIR" -name "urgood_backup_*.sql*" -type f -mtime +$RETENTION_DAYS -print0 2>/dev/null || true)

while IFS= read -r -d '' file; do
    rm "$file"
    ((DELETED_COUNT++))
done < <(find "$BACKUP_DIR" -name "urgood_backup_*.custom" -type f -mtime +$RETENTION_DAYS -print0 2>/dev/null || true)

while IFS= read -r -d '' file; do
    rm "$file"
    ((DELETED_COUNT++))
done < <(find "$BACKUP_DIR" -name "urgood_backup_*.meta" -type f -mtime +$RETENTION_DAYS -print0 2>/dev/null || true)

if [ $DELETED_COUNT -gt 0 ]; then
    success "Deleted $DELETED_COUNT old backup files"
else
    log "No old backups to clean up"
fi

# Generate backup report
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -name "urgood_backup_*.custom" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

cat > "${BACKUP_DIR}/backup_report.json" << EOF
{
    "last_backup": {
        "timestamp": "$TIMESTAMP",
        "file": "$BACKUP_FILE.custom",
        "size": "$BACKUP_SIZE",
        "status": "success"
    },
    "summary": {
        "total_backups": $TOTAL_BACKUPS,
        "total_size": "$TOTAL_SIZE",
        "retention_days": $RETENTION_DAYS,
        "last_cleanup": "$(date -Iseconds)"
    }
}
EOF

# Health check - ensure we have recent backups
RECENT_BACKUPS=$(find "$BACKUP_DIR" -name "urgood_backup_*.custom" -type f -mtime -1 | wc -l)
if [ $RECENT_BACKUPS -eq 0 ]; then
    warning "No backups created in the last 24 hours"
fi

success "Backup completed successfully!"
log "📊 Total backups: $TOTAL_BACKUPS"
log "💾 Total backup size: $TOTAL_SIZE"
log "📅 Retention: $RETENTION_DAYS days"

# Optional: Send notification (webhook, email, etc.)
if [ -n "${BACKUP_WEBHOOK_URL:-}" ]; then
    curl -X POST "$BACKUP_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"status\": \"success\",
            \"database\": \"$POSTGRES_DB\",
            \"timestamp\": \"$TIMESTAMP\",
            \"size\": \"$BACKUP_SIZE\",
            \"total_backups\": $TOTAL_BACKUPS
        }" \
        --silent --show-error || warning "Failed to send backup notification"
fi

log "🎯 UrGood database backup process completed"
