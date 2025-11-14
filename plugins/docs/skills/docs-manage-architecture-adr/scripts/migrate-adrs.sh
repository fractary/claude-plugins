#!/usr/bin/env bash
# ADR Migration Script - Migrate from 3-digit to 5-digit format
# Usage: migrate-adrs.sh [OPTIONS]

set -euo pipefail

# Default values
DRY_RUN=false
SOURCE_DIR="docs/architecture/adrs"
DEST_DIR="docs/architecture/ADR"
KEEP_OLD=false
USE_GIT=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Show usage
usage() {
    cat <<EOF
ADR Migration Script - Migrate from 3-digit to 5-digit format

Usage: $0 [OPTIONS]

Options:
  --dry-run          Show what would be changed without making changes
  --source PATH      Source directory (default: docs/architecture/adrs)
  --dest PATH        Destination directory (default: docs/architecture/ADR)
  --keep-old         Keep old directory after migration
  --no-git           Don't use git mv (use regular mv instead)
  --help             Show this help message

Examples:
  $0 --dry-run                    # Preview migration
  $0                              # Migrate with defaults
  $0 --keep-old                   # Migrate and keep old directory
  $0 --source docs/decisions      # Migrate from custom source

What gets migrated:
  - ADR filenames (3-digit → 5-digit)
  - File locations (adrs/ → ADR/)
  - Cross-references in markdown files
  - Frontmatter links
  - README.md index
  - Git history (if using git)

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --source)
                SOURCE_DIR="$2"
                shift 2
                ;;
            --dest)
                DEST_DIR="$2"
                shift 2
                ;;
            --keep-old)
                KEEP_OLD=true
                shift
                ;;
            --no-git)
                USE_GIT=false
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                print_color "$RED" "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check if we're in a git repository
check_git() {
    if $USE_GIT && ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_color "$YELLOW" "Warning: Not in a git repository. Using --no-git mode."
        USE_GIT=false
    fi
}

# Validate source directory exists
validate_source() {
    if [[ ! -d "$SOURCE_DIR" ]]; then
        print_color "$RED" "Error: Source directory not found: $SOURCE_DIR"
        exit 1
    fi

    local adr_count
    adr_count=$(find "$SOURCE_DIR" -maxdepth 1 -name "ADR-*.md" | wc -l)

    if [[ $adr_count -eq 0 ]]; then
        print_color "$YELLOW" "Warning: No ADR files found in $SOURCE_DIR"
        print_color "$YELLOW" "Nothing to migrate."
        exit 0
    fi

    print_color "$GREEN" "Found $adr_count ADR file(s) in $SOURCE_DIR"
}

# Create destination directory
create_dest() {
    if [[ ! -d "$DEST_DIR" ]]; then
        if $DRY_RUN; then
            print_color "$BLUE" "[DRY RUN] Would create directory: $DEST_DIR"
        else
            mkdir -p "$DEST_DIR"
            print_color "$GREEN" "Created directory: $DEST_DIR"
        fi
    fi
}

# Convert 3-digit number to 5-digit
convert_number() {
    local old_num=$1
    # Remove leading zeros for arithmetic, then format as 5-digit
    printf "%05d" $((10#$old_num))
}

# Migrate a single ADR file
migrate_file() {
    local source_file=$1
    local filename=$(basename "$source_file")

    # Check if filename matches ADR-NNN-title.md pattern
    if [[ "$filename" =~ ^ADR-([0-9]{3})-(.+)$ ]]; then
        local old_num="${BASH_REMATCH[1]}"
        local rest="${BASH_REMATCH[2]}"
        local new_num=$(convert_number "$old_num")
        local new_filename="ADR-${new_num}-${rest}"
        local dest_file="$DEST_DIR/$new_filename"

        if $DRY_RUN; then
            print_color "$BLUE" "[DRY RUN] Would rename: $filename → $new_filename"
        else
            if $USE_GIT; then
                git mv "$source_file" "$dest_file"
            else
                mv "$source_file" "$dest_file"
            fi
            print_color "$GREEN" "Migrated: $filename → $new_filename"
        fi

        # Return mapping for reference updates
        echo "$SOURCE_DIR/$filename:$DEST_DIR/$new_filename"
    else
        print_color "$YELLOW" "Skipping non-ADR file: $filename"
    fi
}

# Update cross-references in markdown files
update_references() {
    local mappings_file=$1

    if [[ ! -f "$mappings_file" ]]; then
        return 0
    fi

    print_color "$BLUE" "Updating cross-references..."

    # Find all markdown files
    local md_files
    md_files=$(find . -name "*.md" -type f 2>/dev/null || true)

    while IFS=: read -r old_path new_path; do
        local old_name=$(basename "$old_path")
        local new_name=$(basename "$new_path")

        # Extract numbers for reference patterns
        if [[ "$old_name" =~ ADR-([0-9]{3})- ]]; then
            local old_num="${BASH_REMATCH[1]}"
            local new_num=$(convert_number "$old_num")

            # Update references in all markdown files
            for md_file in $md_files; do
                if [[ -f "$md_file" ]]; then
                    if $DRY_RUN; then
                        if grep -q "$old_name\|$old_path\|ADR-$old_num" "$md_file" 2>/dev/null; then
                            print_color "$BLUE" "[DRY RUN] Would update references in: $md_file"
                        fi
                    else
                        # Update file paths
                        sed -i "s|$old_path|$new_path|g" "$md_file" 2>/dev/null || true
                        # Update filenames
                        sed -i "s|$old_name|$new_name|g" "$md_file" 2>/dev/null || true
                        # Update ADR number references
                        sed -i "s|ADR-$old_num\([^0-9]\)|ADR-$new_num\1|g" "$md_file" 2>/dev/null || true
                    fi
                fi
            done
        fi
    done < "$mappings_file"

    print_color "$GREEN" "Cross-references updated"
}

# Remove old directory if requested
cleanup_old() {
    if ! $KEEP_OLD && [[ -d "$SOURCE_DIR" ]]; then
        local remaining
        remaining=$(find "$SOURCE_DIR" -type f | wc -l)

        if [[ $remaining -eq 0 || $remaining -eq 1 ]]; then  # 1 might be README.md
            if $DRY_RUN; then
                print_color "$BLUE" "[DRY RUN] Would remove empty directory: $SOURCE_DIR"
            else
                rm -rf "$SOURCE_DIR"
                print_color "$GREEN" "Removed old directory: $SOURCE_DIR"
            fi
        else
            print_color "$YELLOW" "Warning: Old directory not empty ($remaining files). Not removing."
            print_color "$YELLOW" "Use --keep-old to suppress this message."
        fi
    fi
}

# Main migration function
main() {
    parse_args "$@"

    print_color "$BLUE" "=== ADR Migration Script ==="
    echo ""

    if $DRY_RUN; then
        print_color "$YELLOW" "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    print_color "$BLUE" "Configuration:"
    echo "  Source: $SOURCE_DIR"
    echo "  Destination: $DEST_DIR"
    echo "  Use Git: $USE_GIT"
    echo "  Keep Old: $KEEP_OLD"
    echo ""

    check_git
    validate_source
    create_dest

    # Create temporary file for mappings
    local mappings_file=$(mktemp)
    trap "rm -f $mappings_file" EXIT

    print_color "$BLUE" "Migrating ADR files..."

    # Migrate each ADR file
    while IFS= read -r file; do
        mapping=$(migrate_file "$file")
        if [[ -n "$mapping" ]]; then
            echo "$mapping" >> "$mappings_file"
        fi
    done < <(find "$SOURCE_DIR" -maxdepth 1 -name "ADR-*.md" -type f | sort)

    # Update cross-references
    if [[ -s "$mappings_file" ]]; then
        update_references "$mappings_file"
    fi

    # Cleanup
    cleanup_old

    echo ""
    if $DRY_RUN; then
        print_color "$YELLOW" "Dry run complete. Run without --dry-run to apply changes."
    else
        print_color "$GREEN" "✅ Migration complete!"
        print_color "$GREEN" "ADR files migrated to $DEST_DIR with 5-digit numbering."
        echo ""
        print_color "$BLUE" "Next steps:"
        echo "  1. Review migrated files in $DEST_DIR"
        echo "  2. Update .fractary/plugins/docs/config.json if needed"
        echo "  3. Run: git status (if using git)"
        echo "  4. Test ADR generation with new skill"
        echo "  5. Commit changes"
    fi
}

# Run main function
main "$@"
