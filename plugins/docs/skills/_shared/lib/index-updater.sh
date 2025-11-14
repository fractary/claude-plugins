#!/usr/bin/env bash
# Index Updater - Automatically update README.md index files
# Usage: index-updater.sh <doc_directory> <doc_type> <index_template> [title]
# Example: index-updater.sh docs/architecture/ADR adr templates/README.md.template "Architecture Decision Records"

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(dirname "$SCRIPT_DIR")"

# Extract frontmatter field from markdown file
extract_frontmatter_field() {
    local file="$1"
    local field="$2"

    if [[ ! -f "$file" ]]; then
        echo ""
        return 1
    fi

    # Extract YAML frontmatter between --- markers
    local in_frontmatter=false
    local value=""

    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            if $in_frontmatter; then
                # End of frontmatter
                break
            else
                # Start of frontmatter
                in_frontmatter=true
                continue
            fi
        fi

        if $in_frontmatter && [[ "$line" =~ ^${field}:\ * ]]; then
            # Extract value after field name
            value="${line#*: }"
            # Remove quotes if present
            value="${value#\"}"
            value="${value%\"}"
            break
        fi
    done < "$file"

    echo "$value"
}

# Extract first heading content (for description)
extract_first_heading() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo ""
        return 1
    fi

    # Skip frontmatter and find first # heading
    local in_frontmatter=false
    local frontmatter_ended=false

    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            if $in_frontmatter; then
                frontmatter_ended=true
                in_frontmatter=false
                continue
            else
                in_frontmatter=true
                continue
            fi
        fi

        if $frontmatter_ended && [[ "$line" =~ ^#\ +(.+)$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return 0
        fi
    done < "$file"

    echo ""
}

# Scan directory and collect document metadata
collect_documents() {
    local directory="$1"

    if [[ ! -d "$directory" ]]; then
        echo "[]"
        return 0
    fi

    local documents_json="["
    local first=true

    # Find all markdown files except README.md
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")

        # Skip README.md itself
        [[ "$filename" == "README.md" ]] && continue

        # Extract metadata from frontmatter
        local title=$(extract_frontmatter_field "$file" "title")
        local status=$(extract_frontmatter_field "$file" "status")
        local date=$(extract_frontmatter_field "$file" "date")
        local description=$(extract_frontmatter_field "$file" "description")

        # Fallback to first heading if no title in frontmatter
        if [[ -z "$title" ]]; then
            title=$(extract_first_heading "$file")
        fi

        # Default values
        [[ -z "$title" ]] && title="$filename"
        [[ -z "$status" ]] && status="unknown"
        [[ -z "$date" ]] && date="unknown"
        [[ -z "$description" ]] && description=""

        # Build JSON entry
        if ! $first; then
            documents_json+=","
        fi
        first=false

        documents_json+=$(cat <<EOF
{
  "filename": "$filename",
  "path": "./$filename",
  "title": "$title",
  "status": "$status",
  "date": "$date",
  "description": "$description"
}
EOF
)

    done < <(find "$directory" -maxdepth 1 -type f -name "*.md" | sort)

    documents_json+="]"

    echo "$documents_json"
}

# Generate index content
generate_index_content() {
    local doc_type="$1"
    local title="$2"
    local documents_json="$3"

    # Generate markdown list from documents
    local doc_list=""
    local count=0

    # Parse JSON array and create markdown list
    count=$(echo "$documents_json" | jq 'length')

    if [[ $count -eq 0 ]]; then
        doc_list="*No documents yet. Create your first $doc_type document to get started.*"
    else
        local i=0
        while [[ $i -lt $count ]]; do
            local doc_title=$(echo "$documents_json" | jq -r ".[$i].title")
            local doc_path=$(echo "$documents_json" | jq -r ".[$i].path")
            local doc_status=$(echo "$documents_json" | jq -r ".[$i].status")
            local doc_description=$(echo "$documents_json" | jq -r ".[$i].description")

            doc_list+="- [**$doc_title**]($doc_path)"

            if [[ -n "$doc_description" && "$doc_description" != "null" ]]; then
                doc_list+=" - $doc_description"
            fi

            if [[ "$doc_status" != "unknown" && "$doc_status" != "null" ]]; then
                doc_list+=" *(Status: $doc_status)*"
            fi

            doc_list+=$'\n'

            ((i++))
        done
    fi

    # Generate index content
    cat <<EOF
# $title

## Overview

This directory contains $count $doc_type document(s).

## Documents

$doc_list

## Contributing

To add a new $doc_type document:
1. Use the appropriate skill command to generate the document
2. Follow the standard template and include all required sections
3. Ensure frontmatter is complete with title, status, and date
4. The index will automatically update after document creation

---

*This index is automatically generated. Do not edit manually.*
*Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# Update index file with atomic write
update_index() {
    local doc_directory="$1"
    local doc_type="$2"
    local index_template="${3:-}"
    local title="${4:-${doc_type^} Documentation}"

    echo "📚 Updating index for: $doc_directory"

    # Collect all documents in directory
    local documents_json
    documents_json=$(collect_documents "$doc_directory")

    local count
    count=$(echo "$documents_json" | jq 'length')
    echo "   Found $count document(s)"

    # Generate index content
    local index_content
    if [[ -n "$index_template" && -f "$index_template" ]]; then
        # Use template if provided (future enhancement)
        echo "   Using template: $index_template"
        index_content=$(generate_index_content "$doc_type" "$title" "$documents_json")
    else
        # Generate default index
        index_content=$(generate_index_content "$doc_type" "$title" "$documents_json")
    fi

    # Atomic write to README.md
    local index_file="$doc_directory/README.md"
    local temp_file="$index_file.tmp.$$"

    echo "$index_content" > "$temp_file"

    # Move atomically (handles concurrent access)
    mv -f "$temp_file" "$index_file"

    echo "   ✅ Index updated: $index_file"

    return 0
}

# Main execution
main() {
    if [[ $# -lt 2 ]]; then
        cat >&2 <<EOF
Usage: $0 <doc_directory> <doc_type> [index_template] [title]

Description:
  Automatically generate or update README.md index for a documentation directory.

Arguments:
  doc_directory  - Directory containing documentation files
  doc_type       - Type of documents (adr, guide, schema, etc.)
  index_template - Optional: Path to custom README template
  title          - Optional: Title for the index (default: "{Type} Documentation")

Example:
  $0 docs/architecture/ADR adr "" "Architecture Decision Records"
  $0 docs/guides guide templates/guide-index.md.template

Features:
  - Scans directory for all .md files except README.md
  - Extracts metadata from frontmatter (title, status, date)
  - Generates sorted list with links
  - Updates README.md atomically (safe for concurrent access)

EOF
        return 1
    fi

    update_index "$@"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
