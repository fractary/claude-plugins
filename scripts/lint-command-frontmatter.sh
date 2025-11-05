#!/usr/bin/env bash
set -uo pipefail

# Frontmatter Linter for Claude Plugin Command Files
#
# Validates frontmatter in command files to catch common errors:
# - Leading slashes in name field
# - Missing required fields
# - Invalid name patterns
#
# Usage: ./scripts/lint-command-frontmatter.sh [path]
#   path: Optional path to check (defaults to all plugins/*/commands/*.md files)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
total_files=0
files_with_errors=0
total_errors=0

# Parse command line arguments
search_path="${1:-.}"

echo -e "${BLUE}=== Frontmatter Linter ===${NC}"
echo ""

# Function to extract frontmatter from a file
extract_frontmatter() {
    local file="$1"

    # Check if file starts with ---
    if ! head -n 1 "$file" | grep -q '^---$'; then
        return 1
    fi

    # Extract content between first and second ---
    awk '/^---$/{if(++count==2) exit; if(count==1) next} count==1' "$file"
}

# Function to validate a single command file
validate_file() {
    local file="$1"
    local errors=()
    local warnings=()

    ((total_files++))

    # Extract frontmatter
    if ! frontmatter=$(extract_frontmatter "$file"); then
        errors+=("Missing or invalid frontmatter structure (must start with ---)")
    else
        # Extract name field
        name=$(echo "$frontmatter" | grep -E '^name:' | sed 's/^name:[[:space:]]*//' | tr -d '"' | tr -d "'")

        # Extract description field
        description=$(echo "$frontmatter" | grep -E '^description:' | sed 's/^description:[[:space:]]*//')

        # Validate name field exists
        if [ -z "$name" ]; then
            errors+=("Missing required field: name")
        else
            # Check for leading slash in name
            if [[ "$name" =~ ^/ ]]; then
                errors+=("Name field has leading slash: '$name' (should be '${name#/}')")
            fi

            # Check name follows pattern: plugin-name:command-name
            if ! [[ "$name" =~ ^[a-z0-9-]+:[a-z0-9-]+$ ]]; then
                warnings+=("Name field doesn't follow expected pattern 'plugin-name:command-name': '$name'")
            fi
        fi

        # Validate description field exists
        if [ -z "$description" ]; then
            warnings+=("Missing recommended field: description")
        fi

        # Check for examples field (recommended but not required)
        if ! echo "$frontmatter" | grep -q -E '^examples:'; then
            # Don't warn - examples are truly optional
            :
        fi
    fi

    # Report errors and warnings
    if [ ${#errors[@]} -gt 0 ] || [ ${#warnings[@]} -gt 0 ]; then
        ((files_with_errors++))

        echo -e "${YELLOW}File: $file${NC}"

        if [ ${#errors[@]} -gt 0 ]; then
            for error in "${errors[@]}"; do
                echo -e "  ${RED}✗ ERROR: $error${NC}"
                ((total_errors++))
            done
        fi

        if [ ${#warnings[@]} -gt 0 ]; then
            for warning in "${warnings[@]}"; do
                echo -e "  ${YELLOW}⚠ WARNING: $warning${NC}"
            done
        fi

        echo ""
    fi
}

# Find and validate all command files
if [ -d "$search_path" ]; then
    # Search for command files in the given path
    while IFS= read -r -d '' file; do
        validate_file "$file"
    done < <(find "$search_path" -type f -path "*/commands/*.md" -print0 2>/dev/null | sort -z)
else
    # Single file
    if [ -f "$search_path" ]; then
        validate_file "$search_path"
    else
        echo -e "${RED}Error: Path not found: $search_path${NC}"
        exit 1
    fi
fi

# Summary
echo -e "${BLUE}=== Summary ===${NC}"
echo "Files checked: $total_files"
echo "Files with issues: $files_with_errors"
echo "Total errors: $total_errors"
echo ""

if [ $total_errors -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Found $total_errors error(s) that must be fixed${NC}"
    exit 1
fi
