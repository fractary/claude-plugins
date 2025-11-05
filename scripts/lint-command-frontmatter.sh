#!/usr/bin/env bash
set -uo pipefail

# Frontmatter Linter for Claude Plugin Command Files
#
# Validates frontmatter in command files to catch common errors:
# - Leading slashes in name field
# - Missing required fields
# - Invalid name patterns
#
# Usage: ./scripts/lint-command-frontmatter.sh [OPTIONS] [path]
#   path: Optional path to check (defaults to all plugins/*/commands/*.md files)
#
# Options:
#   --verbose    Show detailed output including files that pass
#   --quiet      Only show summary, no file-by-file output
#   --fix        Automatically fix issues where possible
#   --help       Show this help message

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
files_fixed=0

# Flags
verbose=false
quiet=false
fix=false

# Function to show help
show_help() {
    cat << EOF
Frontmatter Linter for Claude Plugin Command Files

Usage: $0 [OPTIONS] [path]

Arguments:
  path          Path to check (directory or file)
                Defaults to current directory
                Searches for */commands/*.md files in directories

Options:
  --verbose     Show detailed output including files that pass
  --quiet       Only show summary, no file-by-file output
  --fix         Automatically fix issues where possible (leading slashes)
  --help        Show this help message

Examples:
  $0                                    # Check all plugins
  $0 plugins/faber-cloud/               # Check specific plugin
  $0 --verbose plugins/                 # Verbose output
  $0 --fix plugins/                     # Auto-fix issues
  $0 plugins/repo/commands/commit.md    # Check single file

Exit codes:
  0   All checks passed
  1   Found one or more errors

Validates:
  ✗ Missing frontmatter structure
  ✗ Missing required 'name' field
  ✗ Leading slashes in 'name' field (can auto-fix with --fix)
  ⚠ Invalid name pattern (not plugin-name:command-name)
  ⚠ Missing recommended 'description' field

EOF
    exit 0
}

# Parse command line arguments
search_path="."
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            verbose=true
            shift
            ;;
        --quiet)
            quiet=true
            shift
            ;;
        --fix)
            fix=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        -*)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            search_path="$1"
            shift
            ;;
    esac
done

# Don't show header in quiet mode
if [ "$quiet" = false ]; then
    echo -e "${BLUE}=== Frontmatter Linter ===${NC}"
    echo ""
fi

# Function to extract frontmatter from a file
extract_frontmatter() {
    local file="$1"

    # Check if file starts with ---
    if ! head -n 1 "$file" | grep -q '^---$'; then
        return 1
    fi

    # Extract content between first and second ---
    # This handles multi-line YAML values properly
    awk '/^---$/{if(++count==2) exit; if(count==1) next} count==1' "$file"
}

# Function to extract YAML field value (handles multi-line)
extract_yaml_field() {
    local frontmatter="$1"
    local field="$2"

    # Use awk to properly handle multi-line YAML values
    echo "$frontmatter" | awk -v field="$field" '
        BEGIN { in_field=0; value="" }
        $0 ~ "^" field ":" {
            in_field=1
            # Extract value after colon
            sub("^" field ":[[:space:]]*", "")
            # Handle quoted values
            gsub(/^["'\'']|["'\'']$/, "")
            # Handle > or | for multiline
            if ($0 == ">" || $0 == "|") {
                next
            }
            value=$0
            next
        }
        in_field && /^[a-zA-Z-]+:/ {
            # Next field started
            in_field=0
        }
        in_field && /^[[:space:]]/ {
            # Continuation line
            gsub(/^[[:space:]]+/, " ")
            value=value $0
        }
        in_field && /^$/ {
            # Empty line might end multiline
            in_field=0
        }
        END { print value }
    '
}

# Function to fix leading slash in file
fix_leading_slash() {
    local file="$1"
    local old_name="$2"
    local new_name="${old_name#/}"

    # Create a temporary file
    local temp_file=$(mktemp)

    # Replace the name in frontmatter
    sed "s|^name: $old_name|name: $new_name|" "$file" > "$temp_file"

    # Replace original file
    mv "$temp_file" "$file"

    ((files_fixed++))
}

# Function to validate a single command file
validate_file() {
    local file="$1"
    local errors=()
    local warnings=()
    local fixed=false

    ((total_files++))

    # Extract frontmatter
    if ! frontmatter=$(extract_frontmatter "$file"); then
        errors+=("Missing or invalid frontmatter structure (must start with ---)")
    else
        # Extract name field (handles multi-line)
        name=$(extract_yaml_field "$frontmatter" "name")
        name=$(echo "$name" | xargs)  # Trim whitespace

        # Extract description field (handles multi-line)
        description=$(extract_yaml_field "$frontmatter" "description")

        # Validate name field exists
        if [ -z "$name" ]; then
            errors+=("Missing required field: name")
        else
            # Check for leading slash in name
            if [[ "$name" =~ ^/ ]]; then
                if [ "$fix" = true ]; then
                    fix_leading_slash "$file" "$name"
                    fixed=true
                    if [ "$verbose" = true ]; then
                        errors+=("Name field had leading slash: '$name' → FIXED to '${name#/}'")
                    fi
                else
                    errors+=("Name field has leading slash: '$name' (should be '${name#/}')")
                fi
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

    # Report errors and warnings (unless quiet mode)
    if [ "$quiet" = false ]; then
        if [ ${#errors[@]} -gt 0 ] || [ ${#warnings[@]} -gt 0 ]; then
            ((files_with_errors++))

            echo -e "${YELLOW}File: $file${NC}"

            if [ ${#errors[@]} -gt 0 ]; then
                for error in "${errors[@]}"; do
                    if [ "$fixed" = true ]; then
                        echo -e "  ${GREEN}✓ FIXED: $error${NC}"
                    else
                        echo -e "  ${RED}✗ ERROR: $error${NC}"
                        ((total_errors++))
                    fi
                done
            fi

            if [ ${#warnings[@]} -gt 0 ]; then
                for warning in "${warnings[@]}"; do
                    echo -e "  ${YELLOW}⚠ WARNING: $warning${NC}"
                done
            fi

            echo ""
        elif [ "$verbose" = true ]; then
            echo -e "${GREEN}✓ $file${NC}"
        fi
    else
        # In quiet mode, still count errors
        if [ ${#errors[@]} -gt 0 ] && [ "$fixed" = false ]; then
            ((files_with_errors++))
            ((total_errors+=${#errors[@]}))
        fi
    fi
}

# Find and validate all command files
if [ -d "$search_path" ]; then
    # Search for command files in the given path (excluding .archive directories)
    while IFS= read -r -d '' file; do
        validate_file "$file"
    done < <(find "$search_path" -path "*/.archive" -prune -o -type f -path "*/commands/*.md" -print0 2>/dev/null | sort -z)
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
if [ "$fix" = true ] && [ $files_fixed -gt 0 ]; then
    echo "Files fixed: $files_fixed"
fi
echo "Total errors: $total_errors"
echo ""

if [ $total_errors -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Found $total_errors error(s) that must be fixed${NC}"
    if [ "$fix" = false ]; then
        echo -e "${YELLOW}Tip: Run with --fix to automatically fix some issues${NC}"
    fi
    exit 1
fi
