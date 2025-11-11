#!/usr/bin/env bash
#
# discover-docs.sh - Discover all documentation files in project
#
# Usage: discover-docs.sh <project_root> <output_json>
#
# Discovers:
# - All markdown files
# - Documentation types (ADR, design, runbook, API, etc.)
# - File locations and sizes
# - Modification dates
#
# Output: JSON file with documentation inventory

set -euo pipefail

PROJECT_ROOT="${1:-.}"
OUTPUT_JSON="${2:-discovery-docs.json}"

# Ensure project root exists
if [ ! -d "$PROJECT_ROOT" ]; then
    echo "Error: Project root not found: $PROJECT_ROOT" >&2
    exit 1
fi

# Document type detection patterns
classify_doc_type() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    local content=""

    # Try to read first few lines for content-based classification
    if [ -f "$filepath" ]; then
        content=$(head -n 50 "$filepath" 2>/dev/null || echo "")
    fi

    # Classify by filename patterns
    case "$filename" in
        README.md|readme.md)
            echo "readme"
            ;;
        ADR-*|adr-*|*-adr.md)
            echo "adr"
            ;;
        *design*.md|*architecture*.md)
            if [[ "$filepath" =~ runbook ]]; then
                echo "runbook"
            else
                echo "design"
            fi
            ;;
        *runbook*.md|*procedure*.md|*operations*.md)
            echo "runbook"
            ;;
        *api*.md|*endpoint*.md)
            echo "api-spec"
            ;;
        *test*report*.md|*test*result*.md)
            echo "test-report"
            ;;
        *deploy*.md)
            echo "deployment"
            ;;
        CHANGELOG.md|changelog.md|CHANGES.md)
            echo "changelog"
            ;;
        *postmortem*.md|*incident*.md)
            echo "postmortem"
            ;;
        *troubleshoot*.md|*debug*.md)
            echo "troubleshooting"
            ;;
        *)
            # Content-based classification
            if echo "$content" | grep -qi "^#.*ADR\|Architecture Decision"; then
                echo "adr"
            elif echo "$content" | grep -qi "^#.*Design\|^#.*Architecture"; then
                echo "design"
            elif echo "$content" | grep -qi "^#.*Runbook\|^#.*Procedure\|Prerequisites.*Steps"; then
                echo "runbook"
            elif echo "$content" | grep -qi "^#.*API\|Endpoints\|^#.*REST"; then
                echo "api-spec"
            else
                echo "other"
            fi
            ;;
    esac
}

# Initialize JSON structure
cat > "$OUTPUT_JSON" <<'EOF'
{
  "schema_version": "1.0",
  "discovery_date": "",
  "project_root": "",
  "total_files": 0,
  "by_type": {
    "readme": 0,
    "adr": 0,
    "design": 0,
    "runbook": 0,
    "api-spec": 0,
    "test-report": 0,
    "deployment": 0,
    "changelog": 0,
    "architecture": 0,
    "troubleshooting": 0,
    "postmortem": 0,
    "other": 0
  },
  "files": []
}
EOF

# Find all markdown files, excluding common non-doc locations
mapfile -t md_files < <(find "$PROJECT_ROOT" -type f -name "*.md" \
    ! -path "*/node_modules/*" \
    ! -path "*/.git/*" \
    ! -path "*/vendor/*" \
    ! -path "*/build/*" \
    ! -path "*/dist/*" \
    ! -path "*/.fractary/*" \
    2>/dev/null || true)

# Process each file
declare -A type_counts
type_counts=(
    [readme]=0
    [adr]=0
    [design]=0
    [runbook]=0
    [api-spec]=0
    [test-report]=0
    [deployment]=0
    [changelog]=0
    [architecture]=0
    [troubleshooting]=0
    [postmortem]=0
    [other]=0
)

files_json="["
first=true

for filepath in "${md_files[@]}"; do
    [ -z "$filepath" ] && continue

    # Get file info
    rel_path="${filepath#$PROJECT_ROOT/}"
    size=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo "0")
    modified=$(stat -f%m "$filepath" 2>/dev/null || stat -c%Y "$filepath" 2>/dev/null || echo "0")
    modified_date=$(date -r "$modified" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "@$modified" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")

    # Classify document type
    doc_type=$(classify_doc_type "$filepath")

    # Increment type counter
    ((type_counts[$doc_type]++)) || true

    # Check for front matter
    has_frontmatter=false
    if head -n 1 "$filepath" | grep -q "^---$"; then
        has_frontmatter=true
    fi

    # Add to JSON array
    if [ "$first" = true ]; then
        first=false
    else
        files_json+=","
    fi

    files_json+=$(cat <<JSON_ENTRY

  {
    "path": "$rel_path",
    "type": "$doc_type",
    "size_bytes": $size,
    "modified": "$modified_date",
    "has_frontmatter": $has_frontmatter
  }
JSON_ENTRY
)
done

files_json+="
]"

# Build final JSON
total_files=${#md_files[@]}
discovery_date=$(date "+%Y-%m-%d %H:%M:%S")

cat > "$OUTPUT_JSON" <<EOF
{
  "schema_version": "1.0",
  "discovery_date": "$discovery_date",
  "project_root": "$PROJECT_ROOT",
  "total_files": $total_files,
  "by_type": {
    "readme": ${type_counts[readme]},
    "adr": ${type_counts[adr]},
    "design": ${type_counts[design]},
    "runbook": ${type_counts[runbook]},
    "api-spec": ${type_counts[api-spec]},
    "test-report": ${type_counts[test-report]},
    "deployment": ${type_counts[deployment]},
    "changelog": ${type_counts[changelog]},
    "architecture": ${type_counts[architecture]},
    "troubleshooting": ${type_counts[troubleshooting]},
    "postmortem": ${type_counts[postmortem]},
    "other": ${type_counts[other]}
  },
  "files": $files_json
}
EOF

echo "Discovery complete: $total_files documentation files found"
echo "Output: $OUTPUT_JSON"
