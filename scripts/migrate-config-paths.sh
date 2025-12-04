#!/usr/bin/env bash
#
# migrate-config-paths.sh - Migrate plugin configs from old nested paths to standard flat structure
#
# This script migrates plugin configurations from the old nested pattern:
#   .fractary/plugins/{plugin}/config/config.json
# To the standard flat pattern:
#   .fractary/plugins/{plugin}/config.json
#
# Usage:
#   ./migrate-config-paths.sh [--dry-run] [--force] [project_root]
#
# Options:
#   --dry-run     Show what would be migrated without making changes
#   --force       Overwrite existing configs at new locations (default: skip)
#   project_root  Path to project root (default: current directory)
#
# Exit codes:
#   0 - Success (or no migration needed)
#   1 - Error during migration
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=false
FORCE=false
PROJECT_ROOT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--force] [project_root]"
            echo ""
            echo "Migrate plugin configs from nested to flat structure:"
            echo "  From: .fractary/plugins/{plugin}/config/config.json"
            echo "  To:   .fractary/plugins/{plugin}/config.json"
            echo ""
            echo "Options:"
            echo "  --dry-run     Show what would be migrated without making changes"
            echo "  --force       Overwrite existing configs at new locations"
            echo "  project_root  Path to project root (default: current directory)"
            exit 0
            ;;
        *)
            PROJECT_ROOT="$1"
            shift
            ;;
    esac
done

# Determine project root
if [[ -z "$PROJECT_ROOT" ]]; then
    # Try git root first
    if git rev-parse --show-toplevel &>/dev/null; then
        PROJECT_ROOT=$(git rev-parse --show-toplevel)
    else
        PROJECT_ROOT=$(pwd)
    fi
fi

# Ensure project root exists
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo -e "${RED}Error: Project root does not exist: $PROJECT_ROOT${NC}"
    exit 1
fi

FRACTARY_DIR="$PROJECT_ROOT/.fractary/plugins"

# Check if .fractary/plugins exists
if [[ ! -d "$FRACTARY_DIR" ]]; then
    echo -e "${BLUE}No .fractary/plugins directory found. Nothing to migrate.${NC}"
    exit 0
fi

echo -e "${BLUE}Plugin Config Path Migration${NC}"
echo "Project root: $PROJECT_ROOT"
echo "Plugins dir: $FRACTARY_DIR"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}Mode: DRY RUN (no changes will be made)${NC}"
fi
echo ""

# Track migration results
MIGRATED=0
SKIPPED=0
ERRORS=0

# Find all plugins with old nested config structure
for plugin_dir in "$FRACTARY_DIR"/*/; do
    plugin_name=$(basename "$plugin_dir")
    old_config="$plugin_dir/config/config.json"
    new_config="$plugin_dir/config.json"

    # Check for old nested config pattern
    if [[ -f "$old_config" ]]; then
        echo -e "${YELLOW}Found old config: $old_config${NC}"

        # Check if new config already exists
        if [[ -f "$new_config" ]]; then
            if [[ "$FORCE" == true ]]; then
                echo -e "  ${YELLOW}New config exists, will overwrite (--force)${NC}"
            else
                echo -e "  ${YELLOW}New config already exists, skipping (use --force to overwrite)${NC}"
                ((SKIPPED++))
                continue
            fi
        fi

        if [[ "$DRY_RUN" == true ]]; then
            echo -e "  ${BLUE}Would migrate: $old_config -> $new_config${NC}"
            ((MIGRATED++))
        else
            # Create backup of old config
            backup_file="${old_config}.backup.$(date +%Y%m%d%H%M%S)"
            if cp "$old_config" "$backup_file" 2>/dev/null; then
                echo -e "  ${GREEN}Backup created: $backup_file${NC}"
            fi

            # Copy to new location
            if cp "$old_config" "$new_config" 2>/dev/null; then
                echo -e "  ${GREEN}Migrated: $old_config -> $new_config${NC}"

                # Remove old config directory if empty after migration
                if rmdir "$plugin_dir/config" 2>/dev/null; then
                    echo -e "  ${GREEN}Removed empty config directory${NC}"
                else
                    echo -e "  ${YELLOW}Note: Old config directory not empty, keeping it${NC}"
                fi

                ((MIGRATED++))
            else
                echo -e "  ${RED}Error: Failed to migrate config${NC}"
                ((ERRORS++))
            fi
        fi
    fi

    # Also check for other known old patterns
    # helm-cloud monitoring.toml in config/ subdirectory
    old_monitoring="$plugin_dir/config/monitoring.toml"
    new_monitoring="$plugin_dir/monitoring.toml"

    if [[ -f "$old_monitoring" ]]; then
        echo -e "${YELLOW}Found old monitoring config: $old_monitoring${NC}"

        if [[ -f "$new_monitoring" ]]; then
            if [[ "$FORCE" == true ]]; then
                echo -e "  ${YELLOW}New config exists, will overwrite (--force)${NC}"
            else
                echo -e "  ${YELLOW}New config already exists, skipping${NC}"
                ((SKIPPED++))
                continue
            fi
        fi

        if [[ "$DRY_RUN" == true ]]; then
            echo -e "  ${BLUE}Would migrate: $old_monitoring -> $new_monitoring${NC}"
            ((MIGRATED++))
        else
            if cp "$old_monitoring" "$new_monitoring" 2>/dev/null; then
                echo -e "  ${GREEN}Migrated: $old_monitoring -> $new_monitoring${NC}"
                ((MIGRATED++))
            else
                echo -e "  ${RED}Error: Failed to migrate monitoring config${NC}"
                ((ERRORS++))
            fi
        fi
    fi
done

# Summary
echo ""
echo -e "${BLUE}Migration Summary${NC}"
echo "  Migrated: $MIGRATED"
echo "  Skipped:  $SKIPPED"
echo "  Errors:   $ERRORS"

if [[ "$DRY_RUN" == true ]] && [[ "$MIGRATED" -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Run without --dry-run to apply migrations${NC}"
fi

if [[ "$ERRORS" -gt 0 ]]; then
    exit 1
fi

exit 0
