#!/usr/bin/env bash
# Create Architecture Document - Script wrapper for creating architecture docs
# This script is executed outside LLM context for efficiency

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"

# Source shared libraries
source "$SKILL_ROOT/../_shared/scripts/slugify.sh"
source "$SKILL_ROOT/../_shared/lib/index-updater.sh"

# Usage information
usage() {
    cat <<EOF
Usage: $0 <doc_path> <template_file> <template_data_json> <auto_update_index>

Arguments:
  doc_path            - Directory where document will be created
  template_file       - Path to template file
  template_data_json  - JSON string with template variables
  auto_update_index   - "true" or "false" to update index after creation

Example:
  $0 docs/architecture \\
     templates/overview.md.template \\
     '{"title":"System Overview","overview":"..."}' \\
     true

EOF
}

# Simple Mustache-style template rendering
render_template() {
    local template_file="$1"
    local data_json="$2"

    local content
    content=$(cat "$template_file")

    # Replace simple variables {{key}}
    while IFS= read -r key; do
        local value
        value=$(echo "$data_json" | jq -r ".${key} // empty")

        if [[ -n "$value" && "$value" != "null" ]]; then
            # Escape special characters for sed
            value="${value//\\/\\\\}"
            value="${value//\//\\/}"
            value="${value//&/\\&}"

            # Replace {{key}} with value
            content=$(echo "$content" | sed "s|{{${key}}}|${value}|g")
        fi
    done < <(echo "$data_json" | jq -r 'keys[]')

    echo "$content"
}

# Main function
main() {
    if [[ $# -lt 4 ]]; then
        usage
        exit 1
    fi

    local doc_path="$1"
    local template_file="$2"
    local template_data="$3"
    local auto_update_index="$4"

    # Validate inputs
    if [[ ! -f "$template_file" ]]; then
        echo "ERROR: Template not found: $template_file" >&2
        exit 1
    fi

    # Extract key fields from JSON
    local title
    title=$(echo "$template_data" | jq -r '.title')

    local doc_type
    doc_type=$(echo "$template_data" | jq -r '.type // "overview"')

    local component_name
    component_name=$(echo "$template_data" | jq -r '.component_name // ""')

    # Generate filename
    local slug
    slug=$(slugify "$title")

    local filename
    case "$doc_type" in
        "component")
            if [[ -n "$component_name" ]]; then
                filename="${component_name}-architecture.md"
            else
                filename="architecture-${slug}.md"
            fi
            ;;
        "diagram")
            filename="${slug}-diagram.md"
            ;;
        *)
            filename="architecture-${slug}.md"
            ;;
    esac

    local file_path="$doc_path/$filename"

    # Create directory if needed
    mkdir -p "$doc_path"

    # Check if file exists
    if [[ -f "$file_path" ]]; then
        local overwrite
        overwrite=$(echo "$template_data" | jq -r '.overwrite // "false"')

        if [[ "$overwrite" != "true" ]]; then
            echo "ERROR: File already exists: $file_path" >&2
            echo "Set overwrite: true to replace" >&2
            exit 1
        fi
    fi

    # Render template
    echo "Rendering template..." >&2
    local rendered_content
    rendered_content=$(render_template "$template_file" "$template_data")

    # Write to file
    echo "$rendered_content" > "$file_path"
    echo "Created: $file_path" >&2

    # Update index if requested
    if [[ "$auto_update_index" == "true" ]]; then
        echo "Updating index..." >&2
        update_index "$doc_path" "architecture" "" "Architecture Documentation"
        echo "Index updated" >&2
    fi

    # Return result JSON
    cat <<EOF
{
  "success": true,
  "file_path": "$file_path",
  "filename": "$filename",
  "size_bytes": $(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null),
  "index_updated": $auto_update_index
}
EOF
}

# Run main
main "$@"
