#!/usr/bin/env bash
#
# restore-backup.sh
# Restore database from backup file
#
# Usage:
#   restore-backup.sh <environment> <backup_file>
#
# Arguments:
#   environment - Environment name (dev, staging, production)
#   backup_file - Backup file path to restore from
#
# Environment Variables:
#   CLAUDE_DB_CWD - Working directory
#   <ENV>_DATABASE_URL - Database connection string
#
# Example:
#   export DEV_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_dev"
#   ./restore-backup.sh dev backup-20250124-140000.sql.gz
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_section() {
    echo -e "${BLUE}$*${NC}"
}

# Parse arguments
if [ $# -lt 2 ]; then
    log_error "Usage: restore-backup.sh <environment> <backup_file>"
    exit 1
fi

ENVIRONMENT="$1"
BACKUP_FILE="$2"

# Set working directory
if [ -n "${CLAUDE_DB_CWD:-}" ]; then
    cd "$CLAUDE_DB_CWD" || {
        log_error "Failed to change to directory: $CLAUDE_DB_CWD"
        exit 1
    }
fi

PROJECT_ROOT=$(pwd)
log_info "Working directory: $PROJECT_ROOT"
log_info "Environment: $ENVIRONMENT"
log_info "Backup file: $BACKUP_FILE"

# Verify backup file exists
if [ ! -f "$BACKUP_FILE" ] && [ ! -d "$BACKUP_FILE" ]; then
    log_error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Get database URL
ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')
if [ "$ENV_UPPER" = "PRODUCTION" ]; then
    ENV_UPPER="PROD"
fi
DATABASE_URL_ENV="${ENV_UPPER}_DATABASE_URL"

if [ -z "${!DATABASE_URL_ENV:-}" ]; then
    log_error "Environment variable $DATABASE_URL_ENV is not set"
    exit 1
fi

DATABASE_URL="${!DATABASE_URL_ENV}"
log_info "Connection string found: $DATABASE_URL_ENV"

# Parse database type
if [[ "$DATABASE_URL" =~ ^postgresql:// ]] || [[ "$DATABASE_URL" =~ ^postgres:// ]]; then
    DB_TYPE="postgresql"
elif [[ "$DATABASE_URL" =~ ^mysql:// ]]; then
    DB_TYPE="mysql"
elif [[ "$DATABASE_URL" =~ ^sqlite:// ]]; then
    DB_TYPE="sqlite"
else
    log_error "Unsupported database type"
    exit 1
fi

log_info "Database type: $DB_TYPE"

# Detect backup format
if [[ "$BACKUP_FILE" == *.gz ]]; then
    COMPRESSED=true
    log_info "Backup is compressed (gzip)"
else
    COMPRESSED=false
fi

# Restore based on database type
log_section "Restoring Backup"
log_warn "This will REPLACE the current database with backup data"
START_TIME=$(date +%s)

case "$DB_TYPE" in
    "postgresql")
        # Check if psql is available
        if ! command -v psql &> /dev/null; then
            log_error "psql not found - PostgreSQL client required"
            exit 4
        fi

        # Parse database name from URL
        DB_NAME=$(echo "$DATABASE_URL" | sed -n 's#.*/\([^?]*\).*#\1#p')
        log_info "Database: $DB_NAME"

        # Drop and recreate database
        log_warn "Dropping and recreating database: $DB_NAME"

        # Get connection string without database name for admin operations
        ADMIN_URL=$(echo "$DATABASE_URL" | sed "s#/$DB_NAME#/postgres#")

        # Drop database
        if psql "$ADMIN_URL" -c "DROP DATABASE IF EXISTS \"$DB_NAME\"" 2>&1 | tee /tmp/restore.log; then
            log_info "Database dropped"
        else
            log_warn "Could not drop database (may not exist yet)"
        fi

        # Create database
        if psql "$ADMIN_URL" -c "CREATE DATABASE \"$DB_NAME\"" 2>&1 | tee -a /tmp/restore.log; then
            log_info "Database created"
        else
            log_error "Failed to create database"
            cat /tmp/restore.log
            rm -f /tmp/restore.log
            exit 1
        fi

        # Restore from backup
        log_info "Restoring data from backup..."

        if [ "$COMPRESSED" = true ]; then
            if gunzip -c "$BACKUP_FILE" | psql "$DATABASE_URL" 2>&1 | tee -a /tmp/restore.log; then
                log_info "Backup restored successfully"
            else
                EXIT_CODE=$?
                log_error "Restore failed"
                cat /tmp/restore.log
                rm -f /tmp/restore.log
                exit $EXIT_CODE
            fi
        else
            if psql "$DATABASE_URL" -f "$BACKUP_FILE" 2>&1 | tee -a /tmp/restore.log; then
                log_info "Backup restored successfully"
            else
                EXIT_CODE=$?
                log_error "Restore failed"
                cat /tmp/restore.log
                rm -f /tmp/restore.log
                exit $EXIT_CODE
            fi
        fi

        rm -f /tmp/restore.log
        ;;

    "mysql")
        # Check if mysql is available
        if ! command -v mysql &> /dev/null; then
            log_error "mysql not found - MySQL client required"
            exit 4
        fi

        # Parse MySQL connection details
        DB_USER=$(echo "$DATABASE_URL" | sed -n 's#mysql://\([^:]*\):.*#\1#p')
        DB_PASS=$(echo "$DATABASE_URL" | sed -n 's#mysql://[^:]*:\([^@]*\)@.*#\1#p')
        DB_HOST=$(echo "$DATABASE_URL" | sed -n 's#mysql://[^@]*@\([^:/]*\).*#\1#p')
        DB_PORT=$(echo "$DATABASE_URL" | sed -n 's#mysql://[^:]*:[^@]*@[^:]*:\([^/]*\)/.*#\1#p')
        DB_NAME=$(echo "$DATABASE_URL" | sed -n 's#.*/\([^?]*\).*#\1#p')

        if [ -z "$DB_PORT" ]; then
            DB_PORT="3306"
        fi

        log_info "Database: $DB_NAME"

        # Drop and recreate database
        log_warn "Dropping and recreating database: $DB_NAME"

        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
            -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; CREATE DATABASE \`$DB_NAME\`;" 2>&1 | tee /tmp/restore.log

        # Restore from backup
        log_info "Restoring data from backup..."

        if [ "$COMPRESSED" = true ]; then
            if gunzip -c "$BACKUP_FILE" | mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>&1 | tee -a /tmp/restore.log; then
                log_info "Backup restored successfully"
            else
                EXIT_CODE=$?
                log_error "Restore failed"
                cat /tmp/restore.log
                rm -f /tmp/restore.log
                exit $EXIT_CODE
            fi
        else
            if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$BACKUP_FILE" 2>&1 | tee -a /tmp/restore.log; then
                log_info "Backup restored successfully"
            else
                EXIT_CODE=$?
                log_error "Restore failed"
                cat /tmp/restore.log
                rm -f /tmp/restore.log
                exit $EXIT_CODE
            fi
        fi

        rm -f /tmp/restore.log
        ;;

    "sqlite")
        # Parse SQLite file path
        DB_FILE=$(echo "$DATABASE_URL" | sed 's#sqlite://##')
        log_info "SQLite file: $DB_FILE"

        # Backup current database if it exists
        if [ -f "$DB_FILE" ]; then
            TEMP_BACKUP="${DB_FILE}.pre-restore-$(date +%s)"
            log_info "Backing up current database to: $TEMP_BACKUP"
            cp "$DB_FILE" "$TEMP_BACKUP"
        fi

        # Remove current database
        rm -f "$DB_FILE"

        # Restore from backup
        log_info "Restoring data from backup..."

        if [ "$COMPRESSED" = true ]; then
            if gunzip -c "$BACKUP_FILE" > "$DB_FILE"; then
                log_info "Backup restored successfully"
            else
                EXIT_CODE=$?
                log_error "Restore failed"
                # Restore from temp backup
                if [ -f "$TEMP_BACKUP" ]; then
                    mv "$TEMP_BACKUP" "$DB_FILE"
                    log_info "Restored from temporary backup"
                fi
                exit $EXIT_CODE
            fi
        else
            if cp "$BACKUP_FILE" "$DB_FILE"; then
                log_info "Backup restored successfully"
            else
                EXIT_CODE=$?
                log_error "Restore failed"
                # Restore from temp backup
                if [ -f "$TEMP_BACKUP" ]; then
                    mv "$TEMP_BACKUP" "$DB_FILE"
                    log_info "Restored from temporary backup"
                fi
                exit $EXIT_CODE
            fi
        fi

        # Clean up temp backup
        rm -f "$TEMP_BACKUP"
        ;;
esac

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Verify restoration
log_section "Verifying Restoration"

case "$DB_TYPE" in
    "postgresql"|"mysql")
        # Test connection
        if psql "$DATABASE_URL" -c "SELECT 1" &>/dev/null || mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1" &>/dev/null; then
            log_info "Database connection: healthy"
        else
            log_error "Database connection failed after restore"
            exit 5
        fi
        ;;
    "sqlite")
        if [ -f "$DB_FILE" ] && sqlite3 "$DB_FILE" "SELECT 1" &>/dev/null; then
            log_info "Database connection: healthy"
        else
            log_error "Database verification failed after restore"
            exit 5
        fi
        ;;
esac

# Regenerate Prisma Client if schema exists
if [ -f "prisma/schema.prisma" ]; then
    log_section "Regenerating Prisma Client"
    if npx prisma generate > /dev/null 2>&1; then
        log_info "Prisma Client regenerated"
    else
        log_warn "Failed to regenerate Prisma Client (non-critical)"
        log_warn "Run manually: npx prisma generate"
    fi
fi

echo ""
log_info "Restore complete"
log_info "Duration: ${DURATION} seconds"
log_info "Database: Ready for use"

exit 0
