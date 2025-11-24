#!/usr/bin/env bash
#
# create-backup.sh
# Create database backup using native tools (pg_dump, mysqldump)
#
# Usage:
#   create-backup.sh <environment> <output_file> [options]
#
# Arguments:
#   environment - Environment name (dev, staging, production)
#   output_file - Output file path for backup
#
# Options:
#   --compression - Enable gzip compression
#   --format <fmt> - Backup format (sql, custom, directory)
#
# Environment Variables:
#   CLAUDE_DB_CWD - Working directory
#   <ENV>_DATABASE_URL - Database connection string
#
# Example:
#   export PROD_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_prod"
#   ./create-backup.sh production backup-20250124-140000.sql --compression
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    log_error "Usage: create-backup.sh <environment> <output_file> [options]"
    exit 1
fi

ENVIRONMENT="$1"
OUTPUT_FILE="$2"
shift 2

# Parse options
COMPRESSION=false
FORMAT="sql"

while [ $# -gt 0 ]; do
    case "$1" in
        --compression)
            COMPRESSION=true
            shift
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set working directory if CLAUDE_DB_CWD is set
if [ -n "${CLAUDE_DB_CWD:-}" ]; then
    cd "$CLAUDE_DB_CWD" || {
        log_error "Failed to change to directory: $CLAUDE_DB_CWD"
        exit 1
    }
fi

PROJECT_ROOT=$(pwd)
log_info "Working directory: $PROJECT_ROOT"
log_info "Environment: $ENVIRONMENT"
log_info "Output file: $OUTPUT_FILE"

# Get database URL environment variable name
ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')
if [ "$ENV_UPPER" = "PRODUCTION" ]; then
    ENV_UPPER="PROD"
fi
DATABASE_URL_ENV="${ENV_UPPER}_DATABASE_URL"

# Check if environment variable is set
if [ -z "${!DATABASE_URL_ENV:-}" ]; then
    log_error "Environment variable $DATABASE_URL_ENV is not set"
    log_error "Set it with: export $DATABASE_URL_ENV=\"postgresql://...\""
    exit 1
fi

DATABASE_URL="${!DATABASE_URL_ENV}"
log_info "Connection string found: $DATABASE_URL_ENV"

# Parse database type from URL
if [[ "$DATABASE_URL" =~ ^postgresql:// ]] || [[ "$DATABASE_URL" =~ ^postgres:// ]]; then
    DB_TYPE="postgresql"
elif [[ "$DATABASE_URL" =~ ^mysql:// ]]; then
    DB_TYPE="mysql"
elif [[ "$DATABASE_URL" =~ ^sqlite:// ]]; then
    DB_TYPE="sqlite"
else
    log_error "Unsupported database type in connection string"
    exit 1
fi

log_info "Database type: $DB_TYPE"

# Ensure backup directory exists
BACKUP_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$BACKUP_DIR"

# Check disk space
log_section "Checking Disk Space"
AVAILABLE_KB=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
AVAILABLE_GB=$((AVAILABLE_KB / 1024 / 1024))
log_info "Available space: ${AVAILABLE_GB} GB"

if [ "$AVAILABLE_GB" -lt 1 ]; then
    log_error "Insufficient disk space (less than 1 GB available)"
    log_error "Free up space or use compression: --compression"
    exit 2
fi

# Create backup based on database type
log_section "Creating Backup"
START_TIME=$(date +%s)

case "$DB_TYPE" in
    "postgresql")
        # Check if pg_dump is available
        if ! command -v pg_dump &> /dev/null; then
            log_error "pg_dump not found - PostgreSQL client required"
            log_error "Install: sudo apt-get install postgresql-client (Ubuntu/Debian)"
            log_error "Install: brew install postgresql (macOS)"
            exit 4
        fi

        PG_VERSION=$(pg_dump --version | awk '{print $3}')
        log_info "pg_dump version: $PG_VERSION"

        # Build pg_dump command
        if [ "$FORMAT" = "custom" ]; then
            # Custom format (compressed, not human-readable)
            OUTPUT_FILE="${OUTPUT_FILE%.sql}.dump"
            log_info "Using PostgreSQL custom format"

            if pg_dump -Fc --no-owner --no-acl -f "$OUTPUT_FILE" "$DATABASE_URL" 2>&1 | tee /tmp/backup.log; then
                log_info "Backup created: $OUTPUT_FILE"
            else
                EXIT_CODE=$?
                log_error "Backup failed"
                cat /tmp/backup.log
                rm -f /tmp/backup.log
                exit $EXIT_CODE
            fi
        elif [ "$FORMAT" = "directory" ]; then
            # Directory format (parallel dump)
            OUTPUT_FILE="${OUTPUT_FILE%.sql}"
            log_info "Using PostgreSQL directory format"

            if pg_dump -Fd -j 4 --no-owner --no-acl -f "$OUTPUT_FILE" "$DATABASE_URL" 2>&1 | tee /tmp/backup.log; then
                log_info "Backup created: $OUTPUT_FILE/"
            else
                EXIT_CODE=$?
                log_error "Backup failed"
                cat /tmp/backup.log
                rm -f /tmp/backup.log
                exit $EXIT_CODE
            fi
        else
            # SQL format (human-readable)
            log_info "Using SQL format"

            if [ "$COMPRESSION" = true ]; then
                OUTPUT_FILE="${OUTPUT_FILE}.gz"
                log_info "Compression enabled (gzip)"

                if pg_dump -Fp --no-owner --no-acl "$DATABASE_URL" 2>/tmp/backup-err.log | gzip > "$OUTPUT_FILE"; then
                    log_info "Backup created and compressed: $OUTPUT_FILE"
                else
                    EXIT_CODE=$?
                    log_error "Backup failed"
                    cat /tmp/backup-err.log
                    rm -f /tmp/backup-err.log
                    exit $EXIT_CODE
                fi
            else
                if pg_dump -Fp --no-owner --no-acl -f "$OUTPUT_FILE" "$DATABASE_URL" 2>&1 | tee /tmp/backup.log; then
                    log_info "Backup created: $OUTPUT_FILE"
                else
                    EXIT_CODE=$?
                    log_error "Backup failed"
                    cat /tmp/backup.log
                    rm -f /tmp/backup.log
                    exit $EXIT_CODE
                fi
            fi
        fi

        rm -f /tmp/backup.log /tmp/backup-err.log
        ;;

    "mysql")
        # Check if mysqldump is available
        if ! command -v mysqldump &> /dev/null; then
            log_error "mysqldump not found - MySQL client required"
            log_error "Install: sudo apt-get install mysql-client (Ubuntu/Debian)"
            log_error "Install: brew install mysql-client (macOS)"
            exit 4
        fi

        MYSQL_VERSION=$(mysqldump --version | awk '{print $6}')
        log_info "mysqldump version: $MYSQL_VERSION"

        # Parse MySQL connection details
        # Format: mysql://user:password@host:port/database
        DB_USER=$(echo "$DATABASE_URL" | sed -n 's#mysql://\([^:]*\):.*#\1#p')
        DB_PASS=$(echo "$DATABASE_URL" | sed -n 's#mysql://[^:]*:\([^@]*\)@.*#\1#p')
        DB_HOST=$(echo "$DATABASE_URL" | sed -n 's#mysql://[^@]*@\([^:/]*\).*#\1#p')
        DB_PORT=$(echo "$DATABASE_URL" | sed -n 's#mysql://[^:]*:[^@]*@[^:]*:\([^/]*\)/.*#\1#p')
        DB_NAME=$(echo "$DATABASE_URL" | sed -n 's#.*/\([^?]*\).*#\1#p')

        # Default port if not specified
        if [ -z "$DB_PORT" ]; then
            DB_PORT="3306"
        fi

        log_info "Database: $DB_NAME"

        if [ "$COMPRESSION" = true ]; then
            OUTPUT_FILE="${OUTPUT_FILE}.gz"
            log_info "Compression enabled (gzip)"

            if mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
                --single-transaction --routines --triggers "$DB_NAME" 2>/tmp/backup-err.log | gzip > "$OUTPUT_FILE"; then
                log_info "Backup created and compressed: $OUTPUT_FILE"
            else
                EXIT_CODE=$?
                log_error "Backup failed"
                cat /tmp/backup-err.log
                rm -f /tmp/backup-err.log
                exit $EXIT_CODE
            fi
        else
            if mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
                --single-transaction --routines --triggers -r "$OUTPUT_FILE" "$DB_NAME" 2>&1 | tee /tmp/backup.log; then
                log_info "Backup created: $OUTPUT_FILE"
            else
                EXIT_CODE=$?
                log_error "Backup failed"
                cat /tmp/backup.log
                rm -f /tmp/backup.log
                exit $EXIT_CODE
            fi
        fi

        rm -f /tmp/backup.log /tmp/backup-err.log
        ;;

    "sqlite")
        # Check if sqlite3 is available
        if ! command -v sqlite3 &> /dev/null; then
            log_error "sqlite3 not found"
            log_error "Install: sudo apt-get install sqlite3 (Ubuntu/Debian)"
            exit 4
        fi

        # Parse SQLite file path from URL
        DB_FILE=$(echo "$DATABASE_URL" | sed 's#sqlite://##')
        log_info "SQLite file: $DB_FILE"

        if [ ! -f "$DB_FILE" ]; then
            log_error "SQLite database file not found: $DB_FILE"
            exit 1
        fi

        # Use SQLite backup command
        if sqlite3 "$DB_FILE" ".backup '$OUTPUT_FILE'" 2>&1 | tee /tmp/backup.log; then
            log_info "Backup created: $OUTPUT_FILE"

            # Optionally compress
            if [ "$COMPRESSION" = true ]; then
                gzip "$OUTPUT_FILE"
                OUTPUT_FILE="${OUTPUT_FILE}.gz"
                log_info "Compressed: $OUTPUT_FILE"
            fi
        else
            EXIT_CODE=$?
            log_error "Backup failed"
            cat /tmp/backup.log
            rm -f /tmp/backup.log
            exit $EXIT_CODE
        fi

        rm -f /tmp/backup.log
        ;;
esac

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Verify backup file
log_section "Verifying Backup"

if [ ! -f "$OUTPUT_FILE" ] && [ ! -d "$OUTPUT_FILE" ]; then
    log_error "Backup file not created: $OUTPUT_FILE"
    exit 5
fi

if [ -f "$OUTPUT_FILE" ]; then
    FILE_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
    FILE_SIZE_MB=$((FILE_SIZE / 1024 / 1024))

    if [ "$FILE_SIZE" -lt 1024 ]; then
        log_warn "Backup file is suspiciously small (${FILE_SIZE} bytes)"
        log_warn "Verify backup is complete"
    else
        log_info "Backup size: ${FILE_SIZE_MB} MB"
    fi

    # Check if file is readable
    if [ -r "$OUTPUT_FILE" ]; then
        log_info "Backup file is readable"
    else
        log_error "Backup file is not readable"
        exit 5
    fi
elif [ -d "$OUTPUT_FILE" ]; then
    DIR_SIZE=$(du -sm "$OUTPUT_FILE" | awk '{print $1}')
    log_info "Backup directory size: ${DIR_SIZE} MB"
fi

echo ""
log_info "Backup creation complete"
log_info "Duration: ${DURATION} seconds"
log_info "Output: $OUTPUT_FILE"

exit 0
