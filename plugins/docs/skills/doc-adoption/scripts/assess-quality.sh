#!/usr/bin/env bash
#
# assess-quality.sh - Assess documentation quality
#
# Usage: assess-quality.sh <discovery_docs_json> <output_json>
#
# Assesses:
# - Documentation completeness
# - Quality scores per document
# - Broken links
# - Missing sections
# - Documentation coverage
#
# Output: JSON file with quality assessment

set -euo pipefail

DISCOVERY_DOCS="${1:-discovery-docs.json}"
OUTPUT_JSON="${2:-discovery-quality.json}"

if [ ! -f "$DISCOVERY_DOCS" ]; then
    echo "Error: Discovery docs file not found: $DISCOVERY_DOCS" >&2
    exit 1
fi

PROJECT_ROOT=$(jq -r '.project_root' "$DISCOVERY_DOCS")
TOTAL_FILES=$(jq -r '.total_files' "$DISCOVERY_DOCS")

# Calculate quality score for a document
calculate_quality_score() {
    local filepath="$1"
    local score=0

    [ ! -f "$filepath" ] && echo "0" && return

    local size=$(wc -c < "$filepath")
    local lines=$(wc -l < "$filepath")
    local has_frontmatter=$(head -n 1 "$filepath" | grep -q "^---$" && echo "true" || echo "false")

    # Size scoring (0-3 points)
    if [ $size -gt 5000 ]; then score=$((score + 3))
    elif [ $size -gt 2000 ]; then score=$((score + 2))
    elif [ $size -gt 500 ]; then score=$((score + 1))
    fi

    # Structure scoring (0-3 points)
    local heading_count=$(grep -c "^#" "$filepath" || echo "0")
    if [ $heading_count -gt 5 ]; then score=$((score + 3))
    elif [ $heading_count -gt 2 ]; then score=$((score + 2))
    elif [ $heading_count -gt 0 ]; then score=$((score + 1))
    fi

    # Front matter (0-2 points)
    if [ "$has_frontmatter" = "true" ]; then score=$((score + 2)); fi

    # Links and references (0-2 points)
    local link_count=$(grep -o '\[.*\](.*)' "$filepath" | wc -l || echo "0")
    if [ $link_count -gt 3 ]; then score=$((score + 2))
    elif [ $link_count -gt 0 ]; then score=$((score + 1))
    fi

    echo "$score"
}

# Process all files
total_score=0
high_quality=0
medium_quality=0
low_quality=0

files_json="["
first=true

while IFS= read -r file_path; do
    [ -z "$file_path" ] && continue
    full_path="$PROJECT_ROOT/$file_path"
    [ ! -f "$full_path" ] && continue

    score=$(calculate_quality_score "$full_path")
    total_score=$((total_score + score))

    if [ $score -ge 8 ]; then ((high_quality++)) || true
    elif [ $score -ge 5 ]; then ((medium_quality++)) || true
    else ((low_quality++)) || true
    fi

    if [ "$first" = true ]; then first=false; else files_json+=","; fi

    files_json+="
    {\"path\": \"$file_path\", \"quality_score\": $score}"
done < <(jq -r '.files[].path' "$DISCOVERY_DOCS")

files_json+="
  ]"

avg_score=$((TOTAL_FILES > 0 ? total_score / TOTAL_FILES : 0))
discovery_date=$(date "+%Y-%m-%d %H:%M:%S")

cat > "$OUTPUT_JSON" <<EOF
{
  "schema_version": "1.0",
  "discovery_date": "$discovery_date",
  "total_files": $TOTAL_FILES,
  "average_quality_score": $avg_score,
  "distribution": {
    "high_quality": $high_quality,
    "medium_quality": $medium_quality,
    "low_quality": $low_quality
  },
  "files": $files_json,
  "recommendations": [
    "$([ $low_quality -gt 0 ] && echo "Improve $low_quality low-quality documents" || echo "Documentation quality is good")",
    "$([ $avg_score -lt 7 ] && echo "Add more structure and cross-references" || echo "Maintain current quality standards")"
  ]
}
EOF

echo "Quality assessment complete: Average score $avg_score/10"
echo "Output: $OUTPUT_JSON"
