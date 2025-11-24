#!/usr/bin/env bash
#
# initialize-database.sh
# Create and initialize database infrastructure
#
# Usage:
#   initialize-database.sh <environment> [database_name]
#
# Environment Variables:
#   CLAUDE_DB_CWD - Working directory (for config loading)
#   <ENV>_DATABASE_URL - Database connection string (e.g., DEV_DATABASE_URL)
#
# Example:
#   export DEV_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_dev"
#   ./initialize-database.sh dev myapp_dev
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
if [ $# -lt 1 ]; then
    log_error "Usage: initialize-database.sh <environment> [database_name]"
    exit 1
fi

ENVIRONMENT="$1"
DATABASE_NAME="${2:-}"

# Banner
echo "═══════════════════════════════════════"
echo "  FABER-DB: Database Initialization"
echo "═══════════════════════════════════════"
echo ""

# Step 1: Load configuration
log_section "Step 1: Loading Configuration"
if ! load_config; then
    log_error "Failed to load configuration"
    exit 1
fi
log_info "Configuration loaded from: $CONFIG_FILE"
log_info "Provider: $DB_PROVIDER"
log_info "Hosting: $DB_HOSTING"
log_info "Migration Tool: $MIGRATION_TOOL"
echo ""

# Step 2: Validate environment
log_section "Step 2: Validating Environment"
if ! get_environment_config "$ENVIRONMENT"; then
    log_error "Environment '$ENVIRONMENT' not configured"
    exit 1
fi
log_info "Environment validated: $ENVIRONMENT"
log_info "Connection string variable: $ENV_CONNECTION_STRING_VAR"
log_info "Auto-migrate: $ENV_AUTO_MIGRATE"
log_info "Backup before migrate: $ENV_BACKUP_BEFORE"
log_info "Require approval: $ENV_REQUIRE_APPROVAL"
echo ""

# Step 3: Determine database name
log_section "Step 3: Determining Database Name"
if [ -z "$DATABASE_NAME" ]; then
    # Generate from project name + environment
    PROJECT_NAME=$(basename "$PROJECT_ROOT")
    DATABASE_NAME="${PROJECT_NAME}_${ENVIRONMENT}"
    log_info "Generated database name: $DATABASE_NAME"
else
    log_info "Using provided database name: $DATABASE_NAME"
fi
echo ""

# Step 4: Safety checks for protected environments
log_section "Step 4: Safety Checks"
if is_protected_environment "$ENVIRONMENT"; then
    log_warn "Environment '$ENVIRONMENT' is PROTECTED"

    if [ "$ENV_REQUIRE_APPROVAL" = "true" ]; then
        echo ""
        echo "═══════════════════════════════════════"
        echo "  ⚠️  PRODUCTION OPERATION"
        echo "═══════════════════════════════════════"
        echo ""
        echo "Operation: Create Database"
        echo "Environment: $ENVIRONMENT"
        echo "Database: $DATABASE_NAME"
        echo ""
        echo "This operation will create production database infrastructure."
        echo ""
        read -p "Proceed? (yes/no): " -r
        echo ""

        if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
            log_warn "Operation cancelled by user"
            exit 0
        fi

        log_info "Approval confirmed"
    fi
else
    log_info "Environment '$ENVIRONMENT' is not protected"
fi
echo ""

# Step 5: Check hosting type
log_section "Step 5: Infrastructure Check"
if [ "$DB_HOSTING" = "local" ] || [ "$DB_HOSTING" = "localhost" ]; then
    log_info "Hosting type: Local (no cloud provisioning needed)"
else
    log_info "Hosting type: Cloud ($DB_HOSTING)"
    log_warn "Cloud infrastructure provisioning not yet implemented in Phase 2"
    log_warn "Assuming infrastructure exists or using connection string directly"
    log_warn "Full cloud integration will be added in future phases"
fi
echo ""

# Step 6: Invoke migration tool handler
log_section "Step 6: Initializing Database"
log_info "Using migration tool: $MIGRATION_TOOL"

case "$MIGRATION_TOOL" in
    "prisma")
        HANDLER_SCRIPT="$PLUGIN_ROOT/skills/handler-db-prisma/scripts/create-database.sh"

        if [ ! -f "$HANDLER_SCRIPT" ]; then
            log_error "Prisma handler script not found: $HANDLER_SCRIPT"
            exit 1
        fi

        log_info "Invoking Prisma handler..."
        echo ""

        # Execute Prisma handler
        if bash "$HANDLER_SCRIPT" "$DATABASE_NAME" "$ENV_CONNECTION_STRING_VAR"; then
            log_info "Prisma handler completed successfully"
        else
            log_error "Prisma handler failed"
            exit 1
        fi
        ;;

    "typeorm"|"sequelize"|"knex")
        log_error "Migration tool '$MIGRATION_TOOL' not yet implemented"
        log_error "Currently only Prisma is supported in Phase 3"
        log_error "Support for $MIGRATION_TOOL will be added in future phases"
        exit 1
        ;;

    *)
        log_error "Unknown migration tool: $MIGRATION_TOOL"
        exit 1
        ;;
esac
echo ""

# Step 7: Verification
log_section "Step 7: Final Verification"
log_info "Database initialization complete"
log_info "Environment: $ENVIRONMENT"
log_info "Database: $DATABASE_NAME"
log_info "Status: Ready for development"
echo ""

# Step 8: Next steps
log_section "Next Steps"
echo "1. Define your database schema:"
echo "   - Edit: prisma/schema.prisma"
echo ""
echo "2. Generate migrations:"
echo "   /faber-db:generate-migration \"describe your changes\""
echo ""
echo "3. Apply migrations:"
echo "   /faber-db:migrate $ENVIRONMENT"
echo ""
echo "4. Check status:"
echo "   /faber-db:status $ENVIRONMENT"
echo ""
echo "═══════════════════════════════════════"
echo "  ✅ Database Initialization Complete"
echo "═══════════════════════════════════════"

exit 0
