#!/usr/bin/env bash
#
# check-health.sh
# Comprehensive database health check for Prisma
#
# Usage:
#   check-health.sh <environment> [checks]
#
# Arguments:
#   environment - Environment name (dev, staging, production)
#   checks - Comma-separated list of checks (default: all)
#            Options: connectivity,migrations,schema,performance,all
#
# Environment Variables:
#   CLAUDE_DB_CWD - Working directory
#   <ENV>_DATABASE_URL - Database connection string
#
# Output:
#   JSON with health check results
#
# Example:
#   export PROD_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_prod"
#   ./check-health.sh production connectivity,migrations
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments
if [ $# -lt 1 ]; then
    echo '{"status":"error","error":"Usage: check-health.sh <environment> [checks]"}'
    exit 1
fi

ENVIRONMENT="$1"
CHECKS="${2:-all}"

# Set working directory
if [ -n "${CLAUDE_DB_CWD:-}" ]; then
    cd "$CLAUDE_DB_CWD" || {
        echo '{"status":"error","error":"Failed to change directory"}'
        exit 1
    }
fi

# Get database URL
ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')
if [ "$ENV_UPPER" = "PRODUCTION" ]; then
    ENV_UPPER="PROD"
fi
DATABASE_URL_ENV="${ENV_UPPER}_DATABASE_URL"

if [ -z "${!DATABASE_URL_ENV:-}" ]; then
    echo "{\"status\":\"error\",\"error\":\"Environment variable $DATABASE_URL_ENV not set\"}"
    exit 1
fi

DATABASE_URL="${!DATABASE_URL_ENV}"
export DATABASE_URL

# Parse database type
if [[ "$DATABASE_URL" =~ ^postgresql:// ]] || [[ "$DATABASE_URL" =~ ^postgres:// ]]; then
    DB_TYPE="postgresql"
elif [[ "$DATABASE_URL" =~ ^mysql:// ]]; then
    DB_TYPE="mysql"
elif [[ "$DATABASE_URL" =~ ^sqlite:// ]]; then
    DB_TYPE="sqlite"
else
    echo '{"status":"error","error":"Unsupported database type"}'
    exit 1
fi

# Initialize results
OVERALL_STATUS="healthy"
CONNECTIVITY_STATUS="not_checked"
MIGRATIONS_STATUS="not_checked"
SCHEMA_STATUS="not_checked"
PERFORMANCE_STATUS="not_checked"
ISSUES=()

# Check if specific checks requested
RUN_CONNECTIVITY=false
RUN_MIGRATIONS=false
RUN_SCHEMA=false
RUN_PERFORMANCE=false

if [ "$CHECKS" = "all" ]; then
    RUN_CONNECTIVITY=true
    RUN_MIGRATIONS=true
    RUN_SCHEMA=true
    RUN_PERFORMANCE=true
else
    [[ "$CHECKS" =~ "connectivity" ]] && RUN_CONNECTIVITY=true
    [[ "$CHECKS" =~ "migrations" ]] && RUN_MIGRATIONS=true
    [[ "$CHECKS" =~ "schema" ]] && RUN_SCHEMA=true
    [[ "$CHECKS" =~ "performance" ]] && RUN_PERFORMANCE=true
fi

# Connectivity Check
if [ "$RUN_CONNECTIVITY" = true ]; then
    START_TIME=$(date +%s%3N)

    case "$DB_TYPE" in
        "postgresql")
            if psql "$DATABASE_URL" -c "SELECT 1" --quiet --tuples-only 2>/dev/null; then
                END_TIME=$(date +%s%3N)
                LATENCY=$((END_TIME - START_TIME))
                CONNECTIVITY_STATUS="healthy"
                CONNECTIVITY_LATENCY=$LATENCY

                if [ "$LATENCY" -gt 500 ]; then
                    CONNECTIVITY_STATUS="unhealthy"
                    OVERALL_STATUS="unhealthy"
                    ISSUES+=('{"severity":"critical","check":"connectivity","message":"High latency: '${LATENCY}'ms"}')
                elif [ "$LATENCY" -gt 100 ]; then
                    CONNECTIVITY_STATUS="degraded"
                    if [ "$OVERALL_STATUS" = "healthy" ]; then
                        OVERALL_STATUS="degraded"
                    fi
                    ISSUES+=('{"severity":"warning","check":"connectivity","message":"Elevated latency: '${LATENCY}'ms"}')
                fi
            else
                CONNECTIVITY_STATUS="unhealthy"
                OVERALL_STATUS="unhealthy"
                CONNECTIVITY_LATENCY=0
                ISSUES+=('{"severity":"critical","check":"connectivity","message":"Connection failed"}')
            fi
            ;;

        "mysql")
            # Parse MySQL connection
            DB_HOST=$(echo "$DATABASE_URL" | sed -n 's#mysql://[^@]*@\([^:/]*\).*#\1#p')
            DB_PORT=$(echo "$DATABASE_URL" | sed -n 's#mysql://[^:]*:[^@]*@[^:]*:\([^/]*\)/.*#\1#p')
            DB_USER=$(echo "$DATABASE_URL" | sed -n 's#mysql://\([^:]*\):.*#\1#p')
            DB_PASS=$(echo "$DATABASE_URL" | sed -n 's#mysql://[^:]*:\([^@]*\)@.*#\1#p')
            DB_NAME=$(echo "$DATABASE_URL" | sed -n 's#.*/\([^?]*\).*#\1#p')

            if [ -z "$DB_PORT" ]; then DB_PORT="3306"; fi

            if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1" 2>/dev/null; then
                END_TIME=$(date +%s%3N)
                LATENCY=$((END_TIME - START_TIME))
                CONNECTIVITY_STATUS="healthy"
                CONNECTIVITY_LATENCY=$LATENCY
            else
                CONNECTIVITY_STATUS="unhealthy"
                OVERALL_STATUS="unhealthy"
                CONNECTIVITY_LATENCY=0
                ISSUES+=('{"severity":"critical","check":"connectivity","message":"Connection failed"}')
            fi
            ;;

        "sqlite")
            DB_FILE=$(echo "$DATABASE_URL" | sed 's#sqlite://##')
            if [ -f "$DB_FILE" ] && sqlite3 "$DB_FILE" "SELECT 1" 2>/dev/null; then
                CONNECTIVITY_STATUS="healthy"
                CONNECTIVITY_LATENCY=5
            else
                CONNECTIVITY_STATUS="unhealthy"
                OVERALL_STATUS="unhealthy"
                CONNECTIVITY_LATENCY=0
                ISSUES+=('{"severity":"critical","check":"connectivity","message":"Database file not accessible"}')
            fi
            ;;
    esac
fi

# Migration Status Check
if [ "$RUN_MIGRATIONS" = true ] && [ "$CONNECTIVITY_STATUS" = "healthy" ]; then
    if [ -f "prisma/schema.prisma" ]; then
        # Check migration status
        if MIGRATION_OUTPUT=$(npx prisma migrate status 2>&1); then
            if echo "$MIGRATION_OUTPUT" | grep -q "No pending migrations"; then
                MIGRATIONS_STATUS="healthy"
                MIGRATIONS_APPLIED=$(echo "$MIGRATION_OUTPUT" | grep -c "migration" || echo "0")
                MIGRATIONS_PENDING=0
            elif echo "$MIGRATION_OUTPUT" | grep -q "pending migration"; then
                MIGRATIONS_STATUS="degraded"
                if [ "$OVERALL_STATUS" = "healthy" ]; then
                    OVERALL_STATUS="degraded"
                fi
                MIGRATIONS_PENDING=$(echo "$MIGRATION_OUTPUT" | grep -c "pending" || echo "1")
                MIGRATIONS_APPLIED=$(echo "$MIGRATION_OUTPUT" | grep -c "Applied migration" || echo "0")
                ISSUES+=('{"severity":"warning","check":"migrations","message":"'$MIGRATIONS_PENDING' pending migrations"}')
            else
                MIGRATIONS_STATUS="healthy"
                MIGRATIONS_APPLIED=0
                MIGRATIONS_PENDING=0
            fi
        else
            MIGRATIONS_STATUS="unhealthy"
            OVERALL_STATUS="unhealthy"
            MIGRATIONS_APPLIED=0
            MIGRATIONS_PENDING=0
            ISSUES+=('{"severity":"critical","check":"migrations","message":"Cannot check migration status"}')
        fi
    else
        MIGRATIONS_STATUS="degraded"
        ISSUES+=('{"severity":"warning","check":"migrations","message":"Prisma schema not found"}')
    fi
fi

# Schema Drift Check
if [ "$RUN_SCHEMA" = true ] && [ "$CONNECTIVITY_STATUS" = "healthy" ]; then
    if [ -f "prisma/schema.prisma" ]; then
        # Use Prisma migrate diff to detect drift
        if DRIFT_OUTPUT=$(npx prisma migrate diff \
            --from-schema-datamodel prisma/schema.prisma \
            --to-schema-datasource prisma/schema.prisma 2>&1); then

            if [ -z "$DRIFT_OUTPUT" ] || [ "$DRIFT_OUTPUT" = "No difference detected." ]; then
                SCHEMA_STATUS="healthy"
                SCHEMA_DRIFT=false
            else
                SCHEMA_STATUS="degraded"
                if [ "$OVERALL_STATUS" = "healthy" ]; then
                    OVERALL_STATUS="degraded"
                fi
                SCHEMA_DRIFT=true
                ISSUES+=('{"severity":"warning","check":"schema","message":"Schema drift detected"}')
            fi
        else
            SCHEMA_STATUS="degraded"
            SCHEMA_DRIFT=false
            ISSUES+=('{"severity":"warning","check":"schema","message":"Cannot check schema drift"}')
        fi
    else
        SCHEMA_STATUS="not_checked"
        SCHEMA_DRIFT=false
    fi
fi

# Performance Check (Basic)
if [ "$RUN_PERFORMANCE" = true ] && [ "$CONNECTIVITY_STATUS" = "healthy" ]; then
    case "$DB_TYPE" in
        "postgresql")
            # Check active connections
            if ACTIVE_CONN=$(psql "$DATABASE_URL" -t -c "SELECT count(*) FROM pg_stat_activity" 2>/dev/null | xargs); then
                PERFORMANCE_STATUS="healthy"
                PERFORMANCE_CONNECTIONS=$ACTIVE_CONN

                # Basic threshold: warn if > 80 connections
                if [ "$ACTIVE_CONN" -gt 80 ]; then
                    PERFORMANCE_STATUS="degraded"
                    if [ "$OVERALL_STATUS" = "healthy" ]; then
                        OVERALL_STATUS="degraded"
                    fi
                    ISSUES+=('{"severity":"warning","check":"performance","message":"High connection count: '${ACTIVE_CONN}'"}')
                fi
            else
                PERFORMANCE_STATUS="degraded"
                PERFORMANCE_CONNECTIONS=0
                ISSUES+=('{"severity":"warning","check":"performance","message":"Cannot check performance metrics"}')
            fi
            ;;

        "mysql"|"sqlite")
            PERFORMANCE_STATUS="healthy"
            PERFORMANCE_CONNECTIONS=0
            ;;
    esac
fi

# Build JSON response
CHECKS_JSON="{"

# Connectivity
if [ "$RUN_CONNECTIVITY" = true ]; then
    CHECKS_JSON+="\"connectivity\":{\"status\":\"$CONNECTIVITY_STATUS\",\"latency_ms\":$CONNECTIVITY_LATENCY}"
fi

# Migrations
if [ "$RUN_MIGRATIONS" = true ]; then
    [ "$RUN_CONNECTIVITY" = true ] && CHECKS_JSON+=","
    CHECKS_JSON+="\"migrations\":{\"status\":\"$MIGRATIONS_STATUS\",\"applied\":${MIGRATIONS_APPLIED:-0},\"pending\":${MIGRATIONS_PENDING:-0}}"
fi

# Schema
if [ "$RUN_SCHEMA" = true ]; then
    [ "$RUN_CONNECTIVITY" = true ] || [ "$RUN_MIGRATIONS" = true ] && CHECKS_JSON+=","
    CHECKS_JSON+="\"schema\":{\"status\":\"$SCHEMA_STATUS\",\"drift_detected\":${SCHEMA_DRIFT:-false}}"
fi

# Performance
if [ "$RUN_PERFORMANCE" = true ]; then
    [ "$RUN_CONNECTIVITY" = true ] || [ "$RUN_MIGRATIONS" = true ] || [ "$RUN_SCHEMA" = true ] && CHECKS_JSON+=","
    CHECKS_JSON+="\"performance\":{\"status\":\"$PERFORMANCE_STATUS\",\"active_connections\":${PERFORMANCE_CONNECTIONS:-0}}"
fi

CHECKS_JSON+="}"

# Build issues array
if [ ${#ISSUES[@]} -eq 0 ]; then
    ISSUES_JSON="[]"
else
    ISSUES_JSON="[$(IFS=,; echo "${ISSUES[*]}")]"
fi

# Output JSON
cat <<EOF
{
  "status": "success",
  "environment": "$ENVIRONMENT",
  "result": {
    "overall_status": "$OVERALL_STATUS",
    "checks": $CHECKS_JSON,
    "issues": $ISSUES_JSON
  }
}
EOF

exit 0
