#!/usr/bin/env bash
#
# generate-migration.sh
# Generate new database migration from schema changes using Prisma
#
# Usage:
#   generate-migration.sh <description> <environment> [options]
#
# Arguments:
#   description - Brief description of schema changes
#   environment - Environment name (dev, staging, production)
#
# Options:
#   --name <name> - Custom migration name
#   --force - Force generation even if no changes
#   --preview - Show what would be generated without creating files
#
# Environment Variables:
#   CLAUDE_DB_CWD - Working directory
#   <ENV>_DATABASE_URL - Database connection string
#
# Example:
#   export DEV_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_dev"
#   ./generate-migration.sh "add user profiles" dev
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
    log_error "Usage: generate-migration.sh <description> <environment> [options]"
    exit 1
fi

DESCRIPTION="$1"
ENVIRONMENT="$2"
shift 2

# Parse options
CUSTOM_NAME=""
FORCE_GENERATION=false
PREVIEW_MODE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --name)
            CUSTOM_NAME="$2"
            shift 2
            ;;
        --force)
            FORCE_GENERATION=true
            shift
            ;;
        --preview)
            PREVIEW_MODE=true
            shift
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
log_info "Description: $DESCRIPTION"

if [ "$PREVIEW_MODE" = true ]; then
    log_info "Preview mode: No files will be created"
fi

# Check if Prisma schema exists
if [ ! -f "prisma/schema.prisma" ]; then
    log_error "Prisma schema not found: prisma/schema.prisma"
    log_error "Initialize Prisma first: npx prisma init"
    exit 1
fi

log_info "Prisma schema found: prisma/schema.prisma"

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

# Get database URL environment variable name
# Format: DEV_DATABASE_URL, STAGING_DATABASE_URL, PROD_DATABASE_URL
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
export DATABASE_URL="$DATABASE_URL"
log_info "Connection string found: $DATABASE_URL_ENV"

# Check migration status to see if there are changes
log_section "Detecting Schema Changes"
echo ""

# Create a temporary file for prisma migrate diff output
DIFF_OUTPUT=$(mktemp)
trap 'rm -f $DIFF_OUTPUT' EXIT

# Check for schema differences
if npx prisma migrate diff \
    --from-schema-datamodel prisma/schema.prisma \
    --to-schema-datasource prisma/schema.prisma \
    --script > "$DIFF_OUTPUT" 2>&1; then

    # Check if diff output is empty
    if [ ! -s "$DIFF_OUTPUT" ] && [ "$FORCE_GENERATION" = false ]; then
        log_info "No schema changes detected"
        echo ""
        log_info "Your Prisma schema matches the database state exactly."
        echo ""
        echo "Options:"
        echo "  1. Modify prisma/schema.prisma and try again"
        echo "  2. Force empty migration: --force flag"
        echo "  3. Check schema diff: npx prisma migrate diff"
        echo ""
        exit 2
    fi
else
    # Diff command failed, might mean database not in sync
    log_warn "Could not compare schema (may indicate first migration or schema drift)"
fi

# Preview mode: show what would be generated
if [ "$PREVIEW_MODE" = true ]; then
    log_section "Migration Preview"
    echo ""

    # Generate preview of migration
    # Note: Prisma doesn't have a true "preview" mode, so we show the diff
    if [ -s "$DIFF_OUTPUT" ]; then
        echo "SQL Preview:"
        echo "────────────────────────────────────────"
        cat "$DIFF_OUTPUT"
        echo "────────────────────────────────────────"
    else
        log_warn "No SQL changes detected"
    fi

    # Generate migration name preview
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    if [ -n "$CUSTOM_NAME" ]; then
        MIGRATION_NAME="${TIMESTAMP}_${CUSTOM_NAME}"
    else
        # Convert description to slug
        SLUG=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')
        MIGRATION_NAME="${TIMESTAMP}_${SLUG}"
    fi

    echo ""
    log_info "Migration would be named: $MIGRATION_NAME"
    echo ""
    log_warn "This is a preview only. No migration files created."
    echo ""
    echo "To create this migration:"
    echo "  /faber-db:generate-migration \"$DESCRIPTION\""
    echo ""
    exit 0
fi

# Generate migration
log_section "Generating Migration"
echo ""

if [ -n "$CUSTOM_NAME" ]; then
    log_info "Using custom name: $CUSTOM_NAME"
    MIGRATION_NAME="$CUSTOM_NAME"
else
    # Prisma will auto-generate name from description
    MIGRATION_NAME="$DESCRIPTION"
fi

# Create migration based on environment
# Development: Use 'prisma migrate dev' (interactive, applies migration)
# Production: Use 'prisma migrate dev --create-only' (non-interactive, doesn't apply)

if [[ "$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "test" ]]; then
    # Development mode: create and apply
    log_info "Development mode: Creating and applying migration"

    if [ "$FORCE_GENERATION" = true ]; then
        log_warn "Forcing migration generation (even if no changes)"
        # Create empty migration
        if npx prisma migrate dev --name "$MIGRATION_NAME" --create-only 2>&1 | tee /tmp/prisma-generate.log; then
            log_info "Empty migration created (use --force to add custom SQL)"
        else
            log_error "Migration generation failed"
            cat /tmp/prisma-generate.log
            rm -f /tmp/prisma-generate.log
            exit 1
        fi
    else
        # Normal generation
        if npx prisma migrate dev --name "$MIGRATION_NAME" 2>&1 | tee /tmp/prisma-generate.log; then
            log_info "Migration generated and applied"
        else
            EXIT_CODE=$?
            log_error "Migration generation failed"
            cat /tmp/prisma-generate.log
            rm -f /tmp/prisma-generate.log
            exit $EXIT_CODE
        fi
    fi
else
    # Production environments: create only (don't apply yet)
    log_info "Production mode: Creating migration only (not applying)"
    log_warn "Migration will be applied with: /faber-db:migrate $ENVIRONMENT"

    if npx prisma migrate dev --name "$MIGRATION_NAME" --create-only 2>&1 | tee /tmp/prisma-generate.log; then
        log_info "Migration created (not yet applied)"
    else
        EXIT_CODE=$?
        log_error "Migration generation failed"
        cat /tmp/prisma-generate.log
        rm -f /tmp/prisma-generate.log
        exit $EXIT_CODE
    fi
fi

rm -f /tmp/prisma-generate.log

# Find the generated migration directory
LATEST_MIGRATION=$(find prisma/migrations -maxdepth 1 -type d -name "*_*" | sort | tail -n 1)

if [ -n "$LATEST_MIGRATION" ]; then
    MIGRATION_FILE="$LATEST_MIGRATION/migration.sql"

    log_info "Migration created: $(basename "$LATEST_MIGRATION")"
    echo ""
    echo "Migration file: $MIGRATION_FILE"
    echo ""

    # Show SQL preview
    if [ -f "$MIGRATION_FILE" ]; then
        echo "SQL Preview:"
        echo "────────────────────────────────────────"
        cat "$MIGRATION_FILE"
        echo "────────────────────────────────────────"
    else
        log_warn "Migration file is empty (use --force to add custom SQL)"
    fi
else
    log_warn "Could not locate generated migration directory"
fi

echo ""
log_info "Migration generation complete"

# Generate Prisma Client
log_section "Updating Prisma Client"
if npx prisma generate > /dev/null 2>&1; then
    log_info "Prisma Client updated"
else
    log_warn "Failed to update Prisma Client (non-critical)"
    log_warn "You may need to run: npx prisma generate"
fi

echo ""
log_info "Next steps:"
if [[ "$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "test" ]]; then
    echo "  1. Review migration SQL in generated file"
    echo "  2. Test application: npm test"
    echo "  3. Commit migration: git add prisma/migrations"
else
    echo "  1. Review migration SQL in generated file"
    echo "  2. Commit migration: git add prisma/migrations"
    echo "  3. Apply to $ENVIRONMENT: /faber-db:migrate $ENVIRONMENT"
fi

exit 0
