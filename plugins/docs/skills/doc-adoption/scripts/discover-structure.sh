#!/usr/bin/env bash
#
# discover-structure.sh - Analyze documentation directory structure
#
# Usage: discover-structure.sh <project_root> <output_json>
#
# Discovers:
# - Directory organization
# - Documentation hierarchy
# - Naming conventions
# - Common paths for doc types
# - Structure complexity
#
# Output: JSON file with structure analysis

set -euo pipefail

PROJECT_ROOT="${1:-.}"
OUTPUT_JSON="${2:-discovery-structure.json}"

# Ensure project root exists
if [ ! -d "$PROJECT_ROOT" ]; then
    echo "Error: Project root not found: $PROJECT_ROOT" >&2
    exit 1
fi

# Find documentation directories
find_doc_dirs() {
    find "$PROJECT_ROOT" -type d \
        \( -name "docs" -o -name "doc" -o -name "documentation" -o -name "Documents" \) \
        ! -path "*/node_modules/*" \
        ! -path "*/.git/*" \
        ! -path "*/vendor/*" \
        ! -path "*/build/*" \
        ! -path "*/dist/*" \
        2>/dev/null || true
}

# Analyze directory depth and organization
analyze_structure() {
    local doc_dirs=("$@")

    if [ ${#doc_dirs[@]} -eq 0 ]; then
        echo "flat"
        return
    fi

    # Check for subdirectory organization
    local has_subdirs=false
    local max_depth=0

    for dir in "${doc_dirs[@]}"; do
        [ -z "$dir" ] && continue
        local depth=$(find "$dir" -type d 2>/dev/null | wc -l)
        if [ "$depth" -gt 1 ]; then
            has_subdirs=true
        fi
        if [ "$depth" -gt "$max_depth" ]; then
            max_depth=$depth
        fi
    done

    if [ "$max_depth" -gt 5 ]; then
        echo "hierarchical"
    elif $has_subdirs; then
        echo "organized"
    else
        echo "flat"
    fi
}

# Detect naming conventions
detect_naming_convention() {
    local files=("$@")

    local kebab_count=0
    local snake_count=0
    local camel_count=0
    local mixed_count=0

    for file in "${files[@]}"; do
        [ -z "$file" ] && continue
        local basename=$(basename "$file" .md)

        if [[ "$basename" =~ ^[a-z0-9]+(-[a-z0-9]+)+$ ]]; then
            ((kebab_count++)) || true
        elif [[ "$basename" =~ ^[a-z0-9]+(_[a-z0-9]+)+$ ]]; then
            ((snake_count++)) || true
        elif [[ "$basename" =~ ^[a-z][a-zA-Z0-9]+$ ]]; then
            ((camel_count++)) || true
        else
            ((mixed_count++)) || true
        fi
    done

    local total=$((kebab_count + snake_count + camel_count + mixed_count))
    if [ $total -eq 0 ]; then
        echo "none"
        return
    fi

    # Return dominant convention
    if [ $kebab_count -gt $((total / 2)) ]; then
        echo "kebab-case"
    elif [ $snake_count -gt $((total / 2)) ]; then
        echo "snake_case"
    elif [ $camel_count -gt $((total / 2)) ]; then
        echo "camelCase"
    else
        echo "mixed"
    fi
}

# Find common paths for each doc type
find_common_paths() {
    local type="$1"
    local pattern="$2"

    find "$PROJECT_ROOT" -type f -name "$pattern" \
        ! -path "*/node_modules/*" \
        ! -path "*/.git/*" \
        ! -path "*/vendor/*" \
        ! -path "*/.fractary/*" \
        2>/dev/null | head -n 5 | while read -r file; do
            dirname "${file#$PROJECT_ROOT/}"
        done | sort | uniq -c | sort -rn | head -n 1 | awk '{print $2}'
}

# Get directory tree (limited depth)
get_directory_tree() {
    local doc_dirs=("$@")
    local tree_json="["
    local first=true

    for dir in "${doc_dirs[@]}"; do
        [ -z "$dir" ] && continue

        local rel_dir="${dir#$PROJECT_ROOT/}"
        local file_count=$(find "$dir" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l)
        local subdir_count=$(find "$dir" -maxdepth 1 -type d ! -path "$dir" 2>/dev/null | wc -l)

        if [ "$first" = true ]; then
            first=false
        else
            tree_json+=","
        fi

        # Get subdirectories
        subdirs_json="["
        local first_sub=true
        while IFS= read -r subdir; do
            [ -z "$subdir" ] && continue
            local sub_name=$(basename "$subdir")
            local sub_count=$(find "$subdir" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l)

            if [ "$first_sub" = true ]; then
                first_sub=false
            else
                subdirs_json+=","
            fi

            subdirs_json+="
      {\"name\": \"$sub_name\", \"file_count\": $sub_count}"
        done < <(find "$dir" -maxdepth 1 -type d ! -path "$dir" 2>/dev/null)
        subdirs_json+="
    ]"

        tree_json+="
    {
      \"path\": \"$rel_dir\",
      \"file_count\": $file_count,
      \"subdir_count\": $subdir_count,
      \"subdirs\": $subdirs_json
    }"
    done

    tree_json+="
  ]"
    echo "$tree_json"
}

# Main discovery
mapfile -t doc_dirs < <(find_doc_dirs)
mapfile -t all_md_files < <(find "$PROJECT_ROOT" -type f -name "*.md" \
    ! -path "*/node_modules/*" \
    ! -path "*/.git/*" \
    ! -path "*/vendor/*" \
    ! -path "*/.fractary/*" \
    2>/dev/null || true)

# Analyze structure
structure_type=$(analyze_structure "${doc_dirs[@]}")
naming_convention=$(detect_naming_convention "${all_md_files[@]}")

# Find primary documentation directory
primary_docs_dir=""
if [ ${#doc_dirs[@]} -gt 0 ]; then
    # Find the one with most files
    max_files=0
    for dir in "${doc_dirs[@]}"; do
        [ -z "$dir" ] && continue
        file_count=$(find "$dir" -type f -name "*.md" 2>/dev/null | wc -l)
        if [ "$file_count" -gt "$max_files" ]; then
            max_files=$file_count
            primary_docs_dir="${dir#$PROJECT_ROOT/}"
        fi
    done
else
    primary_docs_dir="."
fi

# Find common paths for doc types
adr_path=$(find_common_paths "adr" "*ADR*.md" || echo "")
design_path=$(find_common_paths "design" "*design*.md" || echo "")
runbook_path=$(find_common_paths "runbook" "*runbook*.md" || echo "")
api_path=$(find_common_paths "api" "*api*.md" || echo "")

# Get directory tree
directory_tree=$(get_directory_tree "${doc_dirs[@]}")

# Build output JSON using jq for safe construction
discovery_date=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

# Generate recommendations
structure_rec=$([ "$structure_type" = "flat" ] && echo "Consider organizing docs into type-based directories" || echo "Current structure is well-organized")
naming_rec=$([ "$naming_convention" = "mixed" ] && echo "Standardize on kebab-case for consistency" || echo "Naming convention is consistent")

# Use jq to construct JSON safely, then merge in the directory tree
jq -n \
  --arg schema_version "1.0" \
  --arg discovery_date "$discovery_date" \
  --arg project_root "$PROJECT_ROOT" \
  --arg structure_type "$structure_type" \
  --arg naming_convention "$naming_convention" \
  --arg primary_docs_dir "$primary_docs_dir" \
  --argjson doc_dirs_count "${#doc_dirs[@]}" \
  --arg adr_path "${adr_path:-not found}" \
  --arg design_path "${design_path:-not found}" \
  --arg runbook_path "${runbook_path:-not found}" \
  --arg api_path "${api_path:-not found}" \
  --arg structure_rec "$structure_rec" \
  --arg naming_rec "$naming_rec" \
  '{
    schema_version: $schema_version,
    discovery_date: $discovery_date,
    project_root: $project_root,
    structure_type: $structure_type,
    naming_convention: $naming_convention,
    primary_docs_dir: $primary_docs_dir,
    documentation_directories: $doc_dirs_count,
    common_paths: {
      adrs: $adr_path,
      designs: $design_path,
      runbooks: $runbook_path,
      api_docs: $api_path
    },
    directory_tree: [],
    recommendations: {
      structure: $structure_rec,
      naming: $naming_rec
    }
  }' > "$OUTPUT_JSON"

# Merge in directory tree (already valid JSON)
if [ -n "$directory_tree" ]; then
  jq --argjson tree "$directory_tree" '.directory_tree = $tree' "$OUTPUT_JSON" > "${OUTPUT_JSON}.tmp" && mv "${OUTPUT_JSON}.tmp" "$OUTPUT_JSON"
fi

# Validate JSON is well-formed
if ! jq empty "$OUTPUT_JSON" 2>/dev/null; then
    echo "Error: Generated invalid JSON" >&2
    exit 1
fi

echo "Structure analysis complete"
echo "Structure type: $structure_type"
echo "Primary docs directory: $primary_docs_dir"
echo "Output: $OUTPUT_JSON"
