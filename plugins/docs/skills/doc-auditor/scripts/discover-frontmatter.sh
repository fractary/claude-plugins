#!/usr/bin/env bash
#
# discover-frontmatter.sh - Analyze front matter patterns in documentation
#
# Usage: discover-frontmatter.sh <discovery_docs_json> <output_json>
#
# Analyzes:
# - Which files have front matter
# - Front matter formats (YAML, TOML, JSON)
# - Common fields used
# - Front matter consistency
# - Codex integration readiness
#
# Output: JSON file with front matter analysis

set -euo pipefail

DISCOVERY_DOCS="${1:-discovery-docs.json}"
OUTPUT_JSON="${2:-discovery-frontmatter.json}"

# Ensure input exists
if [ ! -f "$DISCOVERY_DOCS" ]; then
    echo "Error: Discovery docs file not found: $DISCOVERY_DOCS" >&2
    exit 1
fi

# Extract project root from discovery file
PROJECT_ROOT=$(jq -r '.project_root' "$DISCOVERY_DOCS")
TOTAL_FILES=$(jq -r '.total_files' "$DISCOVERY_DOCS")

# Analyze front matter in a file
analyze_frontmatter() {
    local filepath="$1"
    local format="none"
    local fields=""

    # Check if file starts with front matter delimiter
    local first_line=$(head -n 1 "$filepath" 2>/dev/null || echo "")

    if [ "$first_line" = "---" ]; then
        format="yaml"
        # Extract front matter fields (lines between first and second ---)
        fields=$(awk '/^---$/{if(++n==2) exit; next} n==1' "$filepath" 2>/dev/null | grep -E '^[a-zA-Z_-]+:' | sed 's/:.*//' | tr '\n' ',' | sed 's/,$//')
    elif [ "$first_line" = "+++" ]; then
        format="toml"
        fields=$(awk '/^\+\+\+$/{if(++n==2) exit; next} n==1' "$filepath" 2>/dev/null | grep -E '^[a-zA-Z_-]+\s*=' | sed 's/=.*//' | sed 's/^[[:space:]]*//' | tr '\n' ',' | sed 's/,$//')
    fi

    echo "$format|$fields"
}

# Process all files from discovery
with_frontmatter=0
without_frontmatter=0
format_yaml=0
format_toml=0
format_none=0

declare -A field_counts

files_json="["
first=true

# Read files from discovery JSON
while IFS= read -r file_path; do
    [ -z "$file_path" ] && continue

    full_path="$PROJECT_ROOT/$file_path"

    if [ ! -f "$full_path" ]; then
        continue
    fi

    # Analyze front matter
    analysis=$(analyze_frontmatter "$full_path")
    format=$(echo "$analysis" | cut -d'|' -f1)
    fields=$(echo "$analysis" | cut -d'|' -f2)

    # Update counts
    if [ "$format" != "none" ]; then
        ((with_frontmatter++)) || true

        case "$format" in
            yaml) ((format_yaml++)) || true ;;
            toml) ((format_toml++)) || true ;;
        esac

        # Count field occurrences
        if [ -n "$fields" ]; then
            IFS=',' read -ra field_array <<< "$fields"
            for field in "${field_array[@]}"; do
                field_counts[$field]=$((${field_counts[$field]:-0} + 1))
            done
        fi
    else
        ((without_frontmatter++)) || true
        ((format_none++)) || true
    fi

    # Add to JSON
    if [ "$first" = true ]; then
        first=false
    else
        files_json+=","
    fi

    # Escape fields for JSON
    fields_json=$(echo "$fields" | sed 's/"/\\"/g')
    fields_json="[$(echo "$fields_json" | sed 's/,/","/g' | sed 's/^/"/;s/$/"/')]"

    files_json+="
    {
      \"path\": \"$file_path\",
      \"has_frontmatter\": $([ "$format" != "none" ] && echo "true" || echo "false"),
      \"format\": \"$format\",
      \"fields\": $fields_json
    }"

done < <(jq -r '.files[].path' "$DISCOVERY_DOCS")

files_json+="
  ]"

# Build common fields JSON
common_fields_json="["
first=true
for field in "${!field_counts[@]}"; do
    count=${field_counts[$field]}
    percentage=$((count * 100 / (with_frontmatter > 0 ? with_frontmatter : 1)))

    if [ "$first" = true ]; then
        first=false
    else
        common_fields_json+=","
    fi

    common_fields_json+="
    {
      \"field\": \"$field\",
      \"count\": $count,
      \"percentage\": $percentage
    }"
done
common_fields_json+="
  ]"

# Calculate percentages
if [ $TOTAL_FILES -gt 0 ]; then
    coverage_pct=$((with_frontmatter * 100 / TOTAL_FILES))
else
    coverage_pct=0
fi

# Determine format consistency
format_primary="none"
format_consistency="none"

if [ $format_yaml -gt 0 ] && [ $format_toml -eq 0 ]; then
    format_primary="yaml"
    format_consistency="consistent"
elif [ $format_toml -gt 0 ] && [ $format_yaml -eq 0 ]; then
    format_primary="toml"
    format_consistency="consistent"
elif [ $format_yaml -gt 0 ] && [ $format_toml -gt 0 ]; then
    if [ $format_yaml -gt $format_toml ]; then
        format_primary="yaml"
    else
        format_primary="toml"
    fi
    format_consistency="mixed"
fi

# Check codex readiness (need title, type, tags fields at minimum)
codex_ready=false
has_title=$((${field_counts[title]:-0}))
has_type=$((${field_counts[type]:-0}))
has_tags=$((${field_counts[tags]:-0}))
has_codex_sync=$((${field_counts[codex_sync]:-0}))

if [ $has_title -gt 0 ] && [ $has_type -gt 0 ]; then
    codex_ready=true
fi

# Build output JSON using jq for safe construction
discovery_date=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

# Generate recommendations
action_rec=$([ $without_frontmatter -gt 0 ] && echo "Add front matter to $without_frontmatter files" || echo "Front matter coverage is complete")
format_rec=$([ "$format_consistency" = "mixed" ] && echo "Standardize on $format_primary format" || echo "Format is consistent")
codex_rec=$([ "$codex_ready" = "false" ] && echo "Add title and type fields for codex integration" || echo "Ready for codex integration")

# Use jq to construct base JSON safely
jq -n \
  --arg schema_version "1.0" \
  --arg discovery_date "$discovery_date" \
  --argjson total_files "$TOTAL_FILES" \
  --argjson with_frontmatter "$with_frontmatter" \
  --argjson without_frontmatter "$without_frontmatter" \
  --argjson coverage_pct "$coverage_pct" \
  --arg format_primary "$format_primary" \
  --arg format_consistency "$format_consistency" \
  --argjson format_yaml "$format_yaml" \
  --argjson format_toml "$format_toml" \
  --argjson format_none "$format_none" \
  --argjson codex_ready "$codex_ready" \
  --argjson has_title "$((has_title > 0))" \
  --argjson has_type "$((has_type > 0))" \
  --argjson has_tags "$((has_tags > 0))" \
  --argjson has_codex_sync "$((has_codex_sync > 0))" \
  --arg action_rec "$action_rec" \
  --arg format_rec "$format_rec" \
  --arg codex_rec "$codex_rec" \
  '{
    schema_version: $schema_version,
    discovery_date: $discovery_date,
    total_files: $total_files,
    with_frontmatter: $with_frontmatter,
    without_frontmatter: $without_frontmatter,
    coverage_percentage: $coverage_pct,
    format: {
      primary: $format_primary,
      consistency: $format_consistency,
      yaml_count: $format_yaml,
      toml_count: $format_toml,
      none_count: $format_none
    },
    common_fields: [],
    codex_integration: {
      ready: $codex_ready,
      has_title_field: $has_title,
      has_type_field: $has_type,
      has_tags_field: $has_tags,
      has_codex_sync_field: $has_codex_sync
    },
    files: [],
    recommendations: {
      action: $action_rec,
      format: $format_rec,
      codex: $codex_rec
    }
  }' > "$OUTPUT_JSON"

# Merge in common_fields array (already valid JSON)
if [ -n "$common_fields_json" ] && [ "$common_fields_json" != "[
  ]" ]; then
  jq --argjson fields "$common_fields_json" '.common_fields = $fields' "$OUTPUT_JSON" > "${OUTPUT_JSON}.tmp" && mv "${OUTPUT_JSON}.tmp" "$OUTPUT_JSON"
fi

# Merge in files array (already valid JSON)
if [ -n "$files_json" ] && [ "$files_json" != "[
  ]" ]; then
  jq --argjson files "$files_json" '.files = $files' "$OUTPUT_JSON" > "${OUTPUT_JSON}.tmp" && mv "${OUTPUT_JSON}.tmp" "$OUTPUT_JSON"
fi

# Validate JSON is well-formed
if ! jq empty "$OUTPUT_JSON" 2>/dev/null; then
    echo "Error: Generated invalid JSON" >&2
    exit 1
fi

echo "Front matter analysis complete"
echo "Coverage: $with_frontmatter/$TOTAL_FILES ($coverage_pct%)"
echo "Primary format: $format_primary"
echo "Codex ready: $codex_ready"
echo "Output: $OUTPUT_JSON"
