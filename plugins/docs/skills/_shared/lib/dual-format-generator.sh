#!/usr/bin/env bash
# Dual Format Generator - Generate both README.md and JSON files simultaneously
# Usage: dual-format-generator.sh <output_dir> <readme_template> <json_template> <template_data_json>
# Example: dual-format-generator.sh docs/schema/user readme.md.template schema.json.template data.json

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(dirname "$SCRIPT_DIR")"

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

    # Simple variable substitution using jq for JSON data
    # This is a simplified Mustache-style renderer
    local content
    content=$(cat "$template_file")

    # Extract all variables from JSON data and substitute
    while IFS= read -r key; do
        local value
        value=$(echo "$data_json" | jq -r ".${key}")

        # Handle arrays (simple list rendering)
        if [[ "$value" == "["* ]]; then
            # For arrays, create comma-separated list
            value=$(echo "$value" | jq -r 'join(", ")')
        fi

        # Substitute {{key}} with value
        content="${content//\{\{${key}\}\}/$value}"
    done < <(echo "$data_json" | jq -r 'keys[]')

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

# Generate both formats simultaneously
generate_dual_format() {
    local output_dir="$1"
    local readme_template="$2"
    local json_template="$3"
    local template_data_json="$4"

    # Create output directory if it doesn't exist
    mkdir -p "$output_dir"

    local readme_file="$output_dir/README.md"
    local json_file="$output_dir/$(basename "$json_template" .template)"

    echo "📝 Generating dual-format documentation..."
    echo "   Output directory: $output_dir"

    # Generate README.md
    echo "   Rendering README.md..."
    if ! render_template "$readme_template" "$template_data_json" "$readme_file"; then
        echo "ERROR: Failed to render README.md" >&2
        return 1
    fi

    # Validate README.md
    if ! validate_markdown "$readme_file"; then
        echo "ERROR: README.md validation failed" >&2
        return 1
    fi
    echo "   ✅ README.md generated and validated"

    # Generate JSON file
    echo "   Rendering JSON file..."
    if ! render_template "$json_template" "$template_data_json" "$json_file"; then
        echo "ERROR: Failed to render JSON file" >&2
        return 1
    fi

    # Validate JSON file
    if ! validate_json "$json_file"; then
        echo "ERROR: JSON validation failed" >&2
        return 1
    fi
    echo "   ✅ JSON file generated and validated"

    # Return file paths as JSON
    cat <<EOF
{
  "readme_path": "$readme_file",
  "json_path": "$json_file",
  "output_dir": "$output_dir"
}
EOF

    return 0
}

# Main execution
main() {
    if [[ $# -lt 4 ]]; then
        cat >&2 <<EOF
Usage: $0 <output_dir> <readme_template> <json_template> <template_data_json>

Description:
  Generate both README.md and JSON files simultaneously from templates.

Arguments:
  output_dir         - Directory where files will be created
  readme_template    - Path to README.md template file
  json_template      - Path to JSON template file
  template_data_json - JSON string or file containing template variables

Example:
  $0 docs/schema/user \\
     templates/schema-readme.md.template \\
     templates/schema.json.template \\
     '{"title": "User Schema", "version": "1.0.0"}'

EOF
        return 1
    fi

    generate_dual_format "$@"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
