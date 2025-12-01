#!/usr/bin/env bash
# Index Updater - Automatically update README.md index files with type-specific configuration
# Usage: index-updater.sh <doc_directory> <doc_type>
# Example: index-updater.sh docs/api api
#
# Reads index-config.json from plugins/docs/types/{doc_type}/ to determine:
# - Organization mode (hierarchical vs flat)
# - Grouping fields (group_by array)
# - Entry/section templates (entry_template, section_template)
# - Sorting (sort_by, sort_order)

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(cd "$SHARED_DIR/../.." && pwd)"

# Load index configuration from types/{doc_type}/index-config.json
load_index_config() {
    local doc_type="$1"
    local config_file="$PLUGIN_ROOT/types/$doc_type/index-config.json"

    if [[ ! -f "$config_file" ]]; then
        # Return default flat configuration
        echo '{"organization":"flat","group_by":[],"sort_by":"title","sort_order":"asc","entry_template":"- [**{{title}}**]({{relative_path}})","section_template":"## {{group_name}}"}'
        return 0
    fi

    cat "$config_file"
}

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

# Scan directory and collect document metadata (enhanced to extract all frontmatter fields)
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

        # Extract comprehensive metadata from frontmatter
        local title=$(extract_frontmatter_field "$file" "title")
        local status=$(extract_frontmatter_field "$file" "status")
        local date=$(extract_frontmatter_field "$file" "date")
        local description=$(extract_frontmatter_field "$file" "description")
        local version=$(extract_frontmatter_field "$file" "version")
        local doc_type=$(extract_frontmatter_field "$file" "fractary_doc_type")

        # Type-specific fields for grouping (API example)
        local endpoint=$(extract_frontmatter_field "$file" "endpoint")
        local method=$(extract_frontmatter_field "$file" "method")
        local service=$(extract_frontmatter_field "$file" "service")

        # Type-specific fields (ADR example)
        local adr_status=$(extract_frontmatter_field "$file" "adr_status")

        # Type-specific fields (Dataset example)
        local source=$(extract_frontmatter_field "$file" "source")
        local format=$(extract_frontmatter_field "$file" "format")

        # Fallback to first heading if no title in frontmatter
        if [[ -z "$title" ]]; then
            title=$(extract_first_heading "$file")
        fi

        # Default values
        [[ -z "$title" ]] && title="$filename"
        [[ -z "$status" ]] && status="unknown"
        [[ -z "$version" ]] && version="1.0.0"

        # Calculate relative path from directory
        local relative_path="./$filename"

        # Build JSON entry with all fields (for template rendering)
        if ! $first; then
            documents_json+=","
        fi
        first=false

        # Build comprehensive JSON object
        documents_json+=$(jq -n \
            --arg filename "$filename" \
            --arg path "$relative_path" \
            --arg relative_path "$relative_path" \
            --arg title "$title" \
            --arg status "$status" \
            --arg date "$date" \
            --arg description "$description" \
            --arg version "$version" \
            --arg doc_type "$doc_type" \
            --arg endpoint "$endpoint" \
            --arg method "$method" \
            --arg service "$service" \
            --arg adr_status "$adr_status" \
            --arg source "$source" \
            --arg format "$format" \
            '{
                filename: $filename,
                path: $path,
                relative_path: $relative_path,
                title: $title,
                status: $status,
                date: $date,
                description: $description,
                description_short: ($description | if length > 100 then .[0:100] + "..." else . end),
                version: $version,
                fractary_doc_type: $doc_type,
                endpoint: $endpoint,
                method: $method,
                service: $service,
                adr_status: $adr_status,
                source: $source,
                format: $format
            }')

    done < <(find "$directory" -maxdepth 1 -type f -name "*.md" | sort)

    documents_json+="]"

    echo "$documents_json"
}

# Render template with variable substitution (simple Mustache-like)
render_template() {
    local template="$1"
    local variables_json="$2"

    local rendered="$template"

    # Extract all {{variables}} from template
    local vars=$(echo "$template" | grep -oP '\{\{[^}]+\}\}' | sort -u || true)

    # Replace each variable
    for var_with_braces in $vars; do
        local var=$(echo "$var_with_braces" | sed 's/{{//; s/}}//')

        # Get value from JSON (handle null gracefully)
        local value=$(echo "$variables_json" | jq -r --arg var "$var" '.[$var] // ""')

        # Replace in template (escape special chars for sed)
        local escaped_value=$(echo "$value" | sed 's/[\/&]/\\&/g')
        rendered=$(echo "$rendered" | sed "s|{{$var}}|$escaped_value|g")
    done

    echo "$rendered"
}

# Sort documents array by field and order
sort_documents() {
    local documents_json="$1"
    local sort_by="${2:-title}"
    local sort_order="${3:-asc}"

    if [[ "$sort_order" == "desc" ]]; then
        echo "$documents_json" | jq --arg field "$sort_by" 'sort_by(.[$field]) | reverse'
    else
        echo "$documents_json" | jq --arg field "$sort_by" 'sort_by(.[$field])'
    fi
}

# Generate flat index (simple list)
generate_flat_index() {
    local documents_json="$1"
    local entry_template="$2"
    local count="$3"

    if [[ $count -eq 0 ]]; then
        echo "*No documents yet.*"
        return 0
    fi

    local output=""
    local i=0
    while [[ $i -lt $count ]]; do
        local doc=$(echo "$documents_json" | jq -c ".[$i]")
        local entry=$(render_template "$entry_template" "$doc")
        output+="$entry"$'\n'
        ((i++))
    done

    echo "$output"
}

# Generate hierarchical index (grouped by fields)
generate_hierarchical_index() {
    local documents_json="$1"
    local group_by_json="$2"
    local entry_template="$3"
    local section_template="$4"

    local output=""

    # Get group_by fields as array
    local group_count=$(echo "$group_by_json" | jq 'length')

    if [[ $group_count -eq 0 ]]; then
        # No grouping - fall back to flat
        local count=$(echo "$documents_json" | jq 'length')
        generate_flat_index "$documents_json" "$entry_template" "$count"
        return 0
    fi

    # Group by first field
    local first_group_field=$(echo "$group_by_json" | jq -r '.[0]')

    # Get unique values for first grouping field
    local unique_values=$(echo "$documents_json" | jq -r ".[] | .${first_group_field}" | sort -u)

    while IFS= read -r group_value; do
        [[ -z "$group_value" || "$group_value" == "null" ]] && continue

        # Filter documents for this group
        local group_docs=$(echo "$documents_json" | jq --arg field "$first_group_field" --arg val "$group_value" \
            '[.[] | select(.[$field] == $val)]')

        local group_count=$(echo "$group_docs" | jq 'length')
        [[ $group_count -eq 0 ]] && continue

        # Render section header
        local section_vars=$(jq -n --arg group_name "$group_value" '{"group_name": $group_name}')
        local section_header=$(render_template "$section_template" "$section_vars")
        output+="$section_header"$'\n'$'\n'

        # If multi-level grouping, recurse with remaining fields
        if [[ $group_count -gt 1 ]]; then
            local remaining_groups=$(echo "$group_by_json" | jq '.[1:]')
            local remaining_count=$(echo "$remaining_groups" | jq 'length')

            if [[ $remaining_count -gt 0 ]]; then
                # Recursive grouping
                local nested=$(generate_hierarchical_index "$group_docs" "$remaining_groups" "$entry_template" "$section_template")
                output+="$nested"$'\n'
            else
                # Leaf level - render entries
                local i=0
                while [[ $i -lt $group_count ]]; do
                    local doc=$(echo "$group_docs" | jq -c ".[$i]")
                    local entry=$(render_template "$entry_template" "$doc")
                    output+="$entry"$'\n'
                    ((i++))
                done
            fi
        else
            # Single document in group
            local doc=$(echo "$group_docs" | jq -c '.[0]')
            local entry=$(render_template "$entry_template" "$doc")
            output+="$entry"$'\n'
        fi

        output+=$'\n'

    done <<< "$unique_values"

    echo "$output"
}

# Generate index content using index-config.json
generate_index_content() {
    local doc_type="$1"
    local title="$2"
    local documents_json="$3"
    local config_json="$4"

    local count=$(echo "$documents_json" | jq 'length')

    # Extract configuration
    local organization=$(echo "$config_json" | jq -r '.organization // "flat"')
    local group_by=$(echo "$config_json" | jq -c '.group_by // []')
    local sort_by=$(echo "$config_json" | jq -r '.sort_by // "title"')
    local sort_order=$(echo "$config_json" | jq -r '.sort_order // "asc"')
    local entry_template=$(echo "$config_json" | jq -r '.entry_template // "- [**{{title}}**]({{relative_path}})"')
    local section_template=$(echo "$config_json" | jq -r '.section_template // "## {{group_name}}"')

    # Sort documents
    local sorted_docs=$(sort_documents "$documents_json" "$sort_by" "$sort_order")

    # Generate document list based on organization mode
    local doc_list=""
    if [[ "$organization" == "hierarchical" ]]; then
        doc_list=$(generate_hierarchical_index "$sorted_docs" "$group_by" "$entry_template" "$section_template")
    else
        doc_list=$(generate_flat_index "$sorted_docs" "$entry_template" "$count")
    fi

    # Generate complete index
    cat <<EOF
# $title

## Overview

This directory contains $count $doc_type document(s).

## Documents

$doc_list

## Contributing

To add a new $doc_type document:
1. Use the appropriate command: \`/docs:write $doc_type\`
2. Follow the standard template and include all required sections
3. Ensure frontmatter is complete with all required fields
4. The index will automatically update after document creation

---

*This index is automatically generated. Do not edit manually.*
*Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# Update index file with atomic write (enhanced with index-config.json support)
update_index() {
    local doc_directory="$1"
    local doc_type="$2"
    local title="${3:-${doc_type^} Documentation}"

    echo "📚 Updating index for: $doc_directory"

    # Load index configuration
    local config_json
    config_json=$(load_index_config "$doc_type")

    local organization=$(echo "$config_json" | jq -r '.organization // "flat"')
    echo "   Organization mode: $organization"

    # Collect all documents in directory
    local documents_json
    documents_json=$(collect_documents "$doc_directory")

    local count
    count=$(echo "$documents_json" | jq 'length')
    echo "   Found $count document(s)"

    # Generate index content with configuration
    local index_content
    index_content=$(generate_index_content "$doc_type" "$title" "$documents_json" "$config_json")

    # Always use doc_directory/README.md (ignore index_file from config)
    # The index_file in config is for documentation purposes only
    local index_file="$doc_directory/README.md"

    # Atomic write to README.md
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
Usage: $0 <doc_directory> <doc_type> [title]

Description:
  Automatically generate or update README.md index for a documentation directory.
  Uses index-config.json from plugins/docs/types/{doc_type}/ for configuration.

Arguments:
  doc_directory  - Directory containing documentation files
  doc_type       - Type of documents (api, adr, guide, dataset, etc.)
  title          - Optional: Title for the index (default: "{Type} Documentation")

Example:
  $0 docs/api api "API Documentation"
  $0 docs/architecture/ADR adr "Architecture Decision Records"

Features:
  - Loads type-specific configuration from index-config.json
  - Supports flat and hierarchical organization modes
  - Multi-level grouping (e.g., by service → version)
  - Configurable entry and section templates
  - Configurable sorting (field and order)
  - Scans directory for all .md files except README.md
  - Extracts comprehensive metadata from frontmatter
  - Updates README.md atomically (safe for concurrent access)

Configuration (index-config.json):
  - organization: "flat" | "hierarchical"
  - group_by: Array of fields for hierarchical grouping
  - sort_by: Field name to sort documents by
  - sort_order: "asc" | "desc"
  - entry_template: Mustache template for document entries
  - section_template: Mustache template for section headers
  - index_file: Target file path (default: {doc_directory}/README.md)

EOF
        return 1
    fi

    update_index "$@"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
