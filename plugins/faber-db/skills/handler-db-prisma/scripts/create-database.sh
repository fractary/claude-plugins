#!/usr/bin/env bash
#
# create-database.sh
# Initialize database using Prisma
#
# Usage:
#   create-database.sh <database_name> <database_url_env>
#
# Environment Variables:
#   CLAUDE_DB_CWD - Working directory
#   <database_url_env> - Database connection string (e.g., DEV_DATABASE_URL)
#
# Example:
#   export DEV_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_dev"
#   ./create-database.sh myapp_dev DEV_DATABASE_URL
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source config loader
# shellcheck source=/dev/null
source "$PLUGIN_ROOT/scripts/utils/config-loader.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Validate arguments
if [ $# -lt 2 ]; then
    log_error "Usage: create-database.sh <database_name> <database_url_env>"
    exit 1
fi

DATABASE_NAME="$1"
DATABASE_URL_ENV="$2"

# Set working directory if CLAUDE_DB_CWD is set
if [ -n "${CLAUDE_DB_CWD:-}" ]; then
    cd "$CLAUDE_DB_CWD" || {
        log_error "Failed to change to directory: $CLAUDE_DB_CWD"
        exit 1
    }
fi

PROJECT_ROOT=$(pwd)
log_info "Working directory: $PROJECT_ROOT"

# Get database URL from environment variable
if [ -z "${!DATABASE_URL_ENV:-}" ]; then
    log_error "Environment variable $DATABASE_URL_ENV is not set"
    log_error "Set it with: export $DATABASE_URL_ENV=\"postgresql://user:password@localhost:5432/$DATABASE_NAME\""
    exit 1
fi

DATABASE_URL="${!DATABASE_URL_ENV}"
log_info "Connection string found: $DATABASE_URL_ENV"

# Check if Prisma CLI is available
if ! command -v npx &> /dev/null; then
    log_error "npx not found - Node.js is required"
    log_error "Install Node.js from: https://nodejs.org/"
    exit 1
fi

# Check if Prisma is installed
if ! npx prisma --version &> /dev/null; then
    log_error "Prisma CLI not found"
    log_error "Install with: npm install -D prisma @prisma/client"
    exit 1
fi

PRISMA_VERSION=$(npx prisma --version | grep 'prisma' | head -n1 | awk '{print $3}')
log_info "Prisma CLI found: version $PRISMA_VERSION"

# Check if prisma directory exists
if [ ! -d "prisma" ]; then
    log_warn "prisma/ directory not found - initializing Prisma"

    # Initialize Prisma
    export DATABASE_URL="$DATABASE_URL"
    npx prisma init --datasource-provider postgresql

    log_info "Prisma initialized"
fi

# Check if schema file exists
if [ ! -f "prisma/schema.prisma" ]; then
    log_error "prisma/schema.prisma not found even after init"
    exit 1
fi

log_info "Prisma schema found: prisma/schema.prisma"

# Update DATABASE_URL in schema if needed
# (Prisma init creates .env, but we use environment variables)
if [ -f ".env" ]; then
    # Update .env file with correct DATABASE_URL
    if grep -q "^DATABASE_URL=" .env; then
        sed -i.bak "s|^DATABASE_URL=.*|DATABASE_URL=\"$DATABASE_URL\"|" .env
        rm -f .env.bak
        log_info "Updated DATABASE_URL in .env"
    else
        echo "DATABASE_URL=\"$DATABASE_URL\"" >> .env
        log_info "Added DATABASE_URL to .env"
    fi
else
    echo "DATABASE_URL=\"$DATABASE_URL\"" > .env
    log_info "Created .env with DATABASE_URL"
fi

# Set DATABASE_URL for Prisma commands
export DATABASE_URL="$DATABASE_URL"

# Check if database already exists by trying to connect
log_info "Checking if database exists..."

if npx prisma db pull --force 2>/dev/null; then
    log_warn "Database $DATABASE_NAME already exists"
    log_warn "Using existing database"

    # Check migration status
    if npx prisma migrate status 2>/dev/null | grep -q "No pending migrations"; then
        log_info "No pending migrations"
    else
        log_warn "There are pending migrations"
    fi
else
    log_info "Database doesn't exist - will be created by first migration"
fi

# Check if migrations directory exists
if [ ! -d "prisma/migrations" ]; then
    log_info "No migrations found - creating initial migration"

    # Create initial migration
    # Use --create-only to avoid applying immediately (gives user chance to review)
    # For dev environment, we can apply immediately
    if npx prisma migrate dev --name init 2>&1 | tee /tmp/prisma-migrate.log; then
        log_info "Initial migration created and applied"
    else
        # Check if error was because of existing database
        if grep -q "already exists" /tmp/prisma-migrate.log; then
            log_warn "Database already exists with schema"
            log_warn "Baselining existing database"

            # Baseline the existing database
            MIGRATION_DIR=$(find prisma/migrations -maxdepth 1 -type d -name "*_init" | head -n1)
            if [ -n "$MIGRATION_DIR" ]; then
                npx prisma migrate resolve --applied "$(basename "$MIGRATION_DIR")"
                log_info "Database baselined successfully"
            fi
        else
            log_error "Migration failed"
            cat /tmp/prisma-migrate.log
            exit 1
        fi
    fi

    rm -f /tmp/prisma-migrate.log
else
    log_info "Migrations directory exists: prisma/migrations"

    # Check migration status
    if npx prisma migrate status 2>&1 | grep -q "No pending migrations"; then
        log_info "All migrations applied"
    else
        log_warn "There are pending migrations"
        log_warn "Run /faber-db:migrate dev to apply them"
    fi
fi

# Generate Prisma Client
log_info "Generating Prisma Client..."
if npx prisma generate; then
    log_info "Prisma Client generated"
else
    log_error "Failed to generate Prisma Client"
    exit 1
fi

# Verify migration table exists
log_info "Verifying migration table..."
if npx prisma db execute --stdin <<< "SELECT COUNT(*) FROM _prisma_migrations;" >/dev/null 2>&1; then
    MIGRATION_COUNT=$(npx prisma db execute --stdin <<< "SELECT COUNT(*) FROM _prisma_migrations;" 2>/dev/null | tail -n1)
    log_info "Migration table verified: $_prisma_migrations ($MIGRATION_COUNT migrations)"
else
    log_warn "Could not verify migration table (may not exist yet)"
fi

# Success
echo ""
log_info "Database initialization complete!"
log_info "Database: $DATABASE_NAME"
log_info "Schema: prisma/schema.prisma"
log_info "Migrations: prisma/migrations/"
log_info "Status: Ready for development"

exit 0
