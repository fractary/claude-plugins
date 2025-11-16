#!/usr/bin/env bash
# Dual Format Generator - Generate both README.md and JSON files simultaneously
# Usage: dual-format-generator.sh <output_dir> <doc_type> <template_data_json>
# Example: dual-format-generator.sh docs/api/user-login api '{"title":"User Login","endpoint":"/api/auth/login"}'
#
# Automatically loads template.md from plugins/docs/types/{doc_type}/
# JSON file generation is optional (only for types that define dual-format schemas)

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(cd "$SHARED_DIR/../.." && pwd)"

# Source required libraries
source "$SHARED_DIR/lib/config-resolver.sh"

# Render template with Mustache-style variable substitution
render_template() {
    local template_file="$1"
    local data_json="$2"
    local output_file="$3"

    if [[ ! -f "$template_file" ]]; then
        echo "ERROR: Template file not found: $template_file" >&2
        return 1
    fi

    # Read template content
    local content
    content=$(cat "$template_file")

    # Extract all {{variables}} from template
    local vars=$(echo "$content" | grep -oP '\{\{[^}]+\}\}' | sort -u || true)

    # Replace each variable
    for var_with_braces in $vars; do
        local var=$(echo "$var_with_braces" | sed 's/{{//; s/}}//')

        # Get value from JSON (handle null gracefully)
        local value=$(echo "$data_json" | jq -r --arg var "$var" '.[$var] // ""')

        # Escape special chars for sed
        local escaped_value=$(echo "$value" | sed 's/[\/&]/\\&/g')

        # Replace in content
        content=$(echo "$content" | sed "s|{{$var}}|$escaped_value|g")
    done

    # Write rendered content
    echo "$content" > "$output_file"
}

# Validate markdown file
validate_markdown() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: Markdown file not found: $file" >&2
        return 1
    fi

    # Check for required frontmatter
    if ! head -n 1 "$file" | grep -q "^---$"; then
        echo "WARNING: Missing frontmatter in: $file" >&2
    fi

    # Check file is not empty
    if [[ ! -s "$file" ]]; then
        echo "ERROR: Generated markdown file is empty: $file" >&2
        return 1
    fi

    return 0
}

# Validate JSON file
validate_json() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: JSON file not found: $file" >&2
        return 1
    fi

    # Validate JSON syntax with jq
    if ! jq empty "$file" 2>/dev/null; then
        echo "ERROR: Invalid JSON syntax in: $file" >&2
        return 1
    fi

    # Check file is not empty
    if [[ ! -s "$file" ]]; then
        echo "ERROR: Generated JSON file is empty: $file" >&2
        return 1
    fi

    return 0
}

# Generate both formats simultaneously (enhanced with doc_type support)
generate_dual_format() {
    local output_dir="$1"
    local doc_type="$2"
    local template_data_json="$3"

    # Determine template paths from doc_type
    local type_dir="$PLUGIN_ROOT/types/$doc_type"
    local readme_template="$type_dir/template.md"

    if [[ ! -f "$readme_template" ]]; then
        echo "ERROR: Template not found for doc_type '$doc_type' at: $readme_template" >&2
        return 1
    fi

    # Create output directory if it doesn't exist
    mkdir -p "$output_dir"

    local readme_file="$output_dir/README.md"

    echo "📝 Generating documentation from type context..."
    echo "   Doc type: $doc_type"
    echo "   Output directory: $output_dir"

    # Add fractary_doc_type to template data if not present
    local enhanced_data
    enhanced_data=$(echo "$template_data_json" | jq --arg type "$doc_type" '. + {fractary_doc_type: $type}')

    # Generate README.md
    echo "   Rendering README.md from template..."
    if ! render_template "$readme_template" "$enhanced_data" "$readme_file"; then
        echo "ERROR: Failed to render README.md" >&2
        return 1
    fi

    # Validate README.md
    if ! validate_markdown "$readme_file"; then
        echo "ERROR: README.md validation failed" >&2
        return 1
    fi
    echo "   ✅ README.md generated and validated"

    # Check if this doc type supports dual-format (JSON companion file)
    # Types like 'api', 'dataset', 'etl' may have JSON schemas
    local json_file=""
    local json_generated=false

    # Determine JSON filename from doc_type or template data
    local json_filename=$(echo "$enhanced_data" | jq -r '.json_filename // ""')

    if [[ -n "$json_filename" && "$json_filename" != "null" ]]; then
        json_file="$output_dir/$json_filename"

        echo "   Generating companion JSON file: $json_filename"

        # Generate JSON file (just the structured data)
        echo "$enhanced_data" | jq '.' > "$json_file"

        # Validate JSON file
        if ! validate_json "$json_file"; then
            echo "ERROR: JSON validation failed" >&2
            return 1
        fi
        echo "   ✅ JSON file generated and validated"
        json_generated=true
    fi

    # Return file paths as JSON
    if $json_generated; then
        cat <<EOF
{
  "readme_path": "$readme_file",
  "json_path": "$json_file",
  "output_dir": "$output_dir",
  "doc_type": "$doc_type"
}
EOF
    else
        cat <<EOF
{
  "readme_path": "$readme_file",
  "output_dir": "$output_dir",
  "doc_type": "$doc_type"
}
EOF
    fi

    return 0
}

# Main execution
main() {
    if [[ $# -lt 3 ]]; then
        cat >&2 <<EOF
Usage: $0 <output_dir> <doc_type> <template_data_json>

Description:
  Generate documentation files from type-specific templates.
  Automatically loads template.md from plugins/docs/types/{doc_type}/.
  Optionally generates companion JSON file for dual-format types.

Arguments:
  output_dir         - Directory where files will be created
  doc_type           - Document type (api, adr, guide, dataset, etc.)
  template_data_json - JSON string containing template variables

Example:
  $0 docs/api/user-login api \\
     '{"title": "User Login", "endpoint": "/api/auth/login", "method": "POST"}'

  $0 docs/datasets/user-metrics dataset \\
     '{"title": "User Metrics", "source": "analytics", "format": "parquet"}'

Features:
  - Loads template from plugins/docs/types/{doc_type}/template.md
  - Automatically adds fractary_doc_type to frontmatter
  - Generates companion JSON file if json_filename is in template data
  - Validates both markdown structure and JSON syntax

Template Variables:
  All variables in template.md ({{variable}}) will be replaced with values
  from template_data_json. Common variables include:
  - title, description, status, version
  - Type-specific fields (endpoint, method, service for API)
  - json_filename (optional, triggers JSON companion file generation)

EOF
        return 1
    fi

    generate_dual_format "$@"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
