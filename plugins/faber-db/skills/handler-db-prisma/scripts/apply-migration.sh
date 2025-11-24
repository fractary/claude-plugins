#!/usr/bin/env bash
#
# apply-migration.sh
# Apply database migrations using Prisma
#
# Usage:
#   apply-migration.sh <environment> <mode> <database_url_env>
#
# Arguments:
#   environment - Environment name (dev, staging, production)
#   mode - Migration mode (dev, deploy)
#   database_url_env - Environment variable name for DATABASE_URL
#
# Environment Variables:
#   CLAUDE_DB_CWD - Working directory
#   <database_url_env> - Database connection string
#
# Example:
#   export PROD_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_prod"
#   ./apply-migration.sh production deploy PROD_DATABASE_URL
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

# Validate arguments
if [ $# -lt 3 ]; then
    log_error "Usage: apply-migration.sh <environment> <mode> <database_url_env>"
    log_error "  mode: dev | deploy"
    exit 1
fi

ENVIRONMENT="$1"
MODE="$2"
DATABASE_URL_ENV="$3"

# Validate mode
if [[ "$MODE" != "dev" && "$MODE" != "deploy" ]]; then
    log_error "Invalid mode: $MODE (must be 'dev' or 'deploy')"
    exit 1
fi

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
log_info "Migration mode: $MODE"

# Get database URL from environment variable
if [ -z "${!DATABASE_URL_ENV:-}" ]; then
    log_error "Environment variable $DATABASE_URL_ENV is not set"
    log_error "Set it with: export $DATABASE_URL_ENV=\"postgresql://...\""
    exit 1
fi

DATABASE_URL="${!DATABASE_URL_ENV}"
log_info "Connection string found: $DATABASE_URL_ENV"

# Set DATABASE_URL for Prisma
export DATABASE_URL="$DATABASE_URL"

# Check if Prisma CLI is available
if ! command -v npx &> /dev/null; then
    log_error "npx not found - Node.js is required"
    exit 1
fi

if ! npx prisma --version &> /dev/null; then
    log_error "Prisma CLI not found"
    log_error "Install with: npm install -D prisma @prisma/client"
    exit 1
fi

PRISMA_VERSION=$(npx prisma --version | grep 'prisma' | head -n1 | awk '{print $3}')
log_info "Prisma CLI version: $PRISMA_VERSION"

# Check if prisma directory exists
if [ ! -d "prisma" ]; then
    log_error "prisma/ directory not found"
    log_error "Initialize with: npx prisma init"
    exit 1
fi

# Check if schema file exists
if [ ! -f "prisma/schema.prisma" ]; then
    log_error "prisma/schema.prisma not found"
    exit 1
fi

log_info "Prisma schema found: prisma/schema.prisma"

# Check migration status before applying
log_section "Checking Migration Status"
if npx prisma migrate status 2>&1 | tee /tmp/prisma-status.log; then
    # Parse status output
    if grep -q "No pending migrations" /tmp/prisma-status.log; then
        log_info "No pending migrations to apply"
        echo ""
        log_info "All migrations are up to date"
        rm -f /tmp/prisma-status.log
        exit 0
    elif grep -q "pending migration" /tmp/prisma-status.log; then
        PENDING_COUNT=$(grep -c "migration" /tmp/prisma-status.log || echo "unknown")
        log_warn "Found pending migrations"
    fi
else
    log_warn "Could not check migration status (may be normal for first migration)"
fi

rm -f /tmp/prisma-status.log
echo ""

# Apply migrations based on mode
log_section "Applying Migrations"

case "$MODE" in
    "dev")
        log_info "Using development mode: prisma migrate dev"
        log_warn "This mode is interactive and may prompt for input"
        echo ""

        # Run prisma migrate dev
        if npx prisma migrate dev 2>&1 | tee /tmp/prisma-migrate.log; then
            log_info "Migrations applied successfully (dev mode)"
        else
            EXIT_CODE=$?
            log_error "Migration failed in dev mode"
            cat /tmp/prisma-migrate.log
            rm -f /tmp/prisma-migrate.log
            exit $EXIT_CODE
        fi
        ;;

    "deploy")
        log_info "Using production mode: prisma migrate deploy"
        log_info "This mode is non-interactive and only applies committed migrations"
        echo ""

        # Run prisma migrate deploy
        if npx prisma migrate deploy 2>&1 | tee /tmp/prisma-migrate.log; then
            log_info "Migrations applied successfully (deploy mode)"

            # Parse output to count migrations applied
            if grep -q "migration" /tmp/prisma-migrate.log; then
                APPLIED_COUNT=$(grep -c "Applied migration" /tmp/prisma-migrate.log || echo "0")
                if [ "$APPLIED_COUNT" -gt 0 ]; then
                    log_info "Applied $APPLIED_COUNT migration(s)"
                fi
            fi
        else
            EXIT_CODE=$?
            log_error "Migration failed in deploy mode"
            cat /tmp/prisma-migrate.log
            rm -f /tmp/prisma-migrate.log
            exit $EXIT_CODE
        fi
        ;;
esac

rm -f /tmp/prisma-migrate.log
echo ""

# Verify migrations applied
log_section "Verifying Migrations"
if npx prisma migrate status 2>&1 | grep -q "No pending migrations"; then
    log_info "All migrations applied successfully"
else
    log_warn "Some migrations may still be pending"
    log_warn "Run status check: /faber-db:status $ENVIRONMENT"
fi

# Generate Prisma Client (important for application to use new schema)
log_section "Generating Prisma Client"
if npx prisma generate > /dev/null 2>&1; then
    log_info "Prisma Client generated"
else
    log_warn "Failed to generate Prisma Client (non-critical)"
    log_warn "You may need to run: npx prisma generate"
fi

echo ""
log_info "Migration deployment complete"
log_info "Environment: $ENVIRONMENT"
log_info "Mode: $MODE"
log_info "Status: ✓ Success"

exit 0
