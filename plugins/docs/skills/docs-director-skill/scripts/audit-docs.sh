#!/bin/bash
# audit-docs.sh - Audit documentation across project
# Usage: audit-docs.sh <base_directory> [doc_types_filter]

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"

# Parse arguments
BASE_DIR="${1:-docs}"
DOC_TYPES_FILTER="${2:-}"

echo "🎯 Starting documentation audit..."
echo "   Base directory: $BASE_DIR"
echo "   Filter: ${DOC_TYPES_FILTER:-all types}"
echo ""

# Check if base directory exists
if [[ ! -d "$BASE_DIR" ]]; then
    echo "ERROR: Directory not found: $BASE_DIR" >&2
    exit 1
fi

# Find all markdown files
echo "Scanning for documents..."

ALL_DOCS=()
DOC_TYPES=()
declare -A TYPE_COUNTS
declare -A STATUS_COUNTS
MISSING_INDICES=()
VALIDATION_ISSUES=()

# Scan for README.md files
while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # Skip index files themselves
    BASENAME=$(basename "$file")
    if [[ "$BASENAME" == "README.md" ]]; then
        # Check if this is an index file (has "automatically generated" marker)
        if grep -q "automatically generated" "$file" 2>/dev/null; then
            continue
        fi
    fi

    ALL_DOCS+=("$file")

    # Extract fractary_doc_type
    DOC_TYPE=$(grep "^fractary_doc_type:" "$file" 2>/dev/null | sed 's/fractary_doc_type: *//' | tr -d '"' || echo "_untyped")

    # Apply filter if specified
    if [[ -n "$DOC_TYPES_FILTER" && "$DOC_TYPE" != "$DOC_TYPES_FILTER" ]]; then
        continue
    fi

    # Track doc types
    if [[ ! " ${DOC_TYPES[*]} " =~ " ${DOC_TYPE} " ]]; then
        DOC_TYPES+=("$DOC_TYPE")
    fi

    # Count by type
    TYPE_COUNTS[$DOC_TYPE]=$((${TYPE_COUNTS[$DOC_TYPE]:-0} + 1))

    # Extract status
    STATUS=$(grep "^status:" "$file" 2>/dev/null | sed 's/status: *//' | tr -d '"' || echo "unknown")
    STATUS_COUNTS[$STATUS]=$((${STATUS_COUNTS[$STATUS]:-0} + 1))

    # Check for validation issues
    if [[ "$DOC_TYPE" == "_untyped" ]]; then
        VALIDATION_ISSUES+=("$file: Missing fractary_doc_type field")
    fi

    # Check for required frontmatter
    if ! head -n 1 "$file" | grep -q "^---$"; then
        VALIDATION_ISSUES+=("$file: Missing frontmatter")
    fi

done < <(find "$BASE_DIR" -name "*.md" -type f 2>/dev/null | sort)

TOTAL_DOCS=${#ALL_DOCS[@]}

echo "   Found $TOTAL_DOCS documents"
echo ""

# Check for missing indices
echo "Checking for missing indices..."

CHECKED_DIRS=()
while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue

    # Skip if already checked
    [[ " ${CHECKED_DIRS[*]} " =~ " ${dir} " ]] && continue
    CHECKED_DIRS+=("$dir")

    # Check if directory has documents but no index
    DOC_COUNT=$(find "$dir" -maxdepth 1 -name "*.md" ! -name "README.md" -type f 2>/dev/null | wc -l)

    if [[ $DOC_COUNT -gt 0 ]]; then
        if [[ ! -f "$dir/README.md" ]]; then
            MISSING_INDICES+=("$dir")
        elif ! grep -q "automatically generated" "$dir/README.md" 2>/dev/null; then
            # Index exists but not auto-generated
            MISSING_INDICES+=("$dir (manual index)")
        fi
    fi

done < <(find "$BASE_DIR" -type d 2>/dev/null | sort)

echo "   Checked ${#CHECKED_DIRS[@]} directories"
echo ""

# Generate report
echo "═══════════════════════════════════════"
echo "DOCUMENTATION AUDIT REPORT"
echo "═══════════════════════════════════════"
echo ""

echo "Summary:"
echo "  Total Documents: $TOTAL_DOCS"
echo "  Document Types: ${#DOC_TYPES[@]}"
echo "  Missing Indices: ${#MISSING_INDICES[@]}"
echo "  Validation Issues: ${#VALIDATION_ISSUES[@]}"
echo ""

echo "By Type:"
for doc_type in "${DOC_TYPES[@]}"; do
    COUNT=${TYPE_COUNTS[$doc_type]:-0}
    printf "  %-15s %3d documents\n" "$doc_type:" "$COUNT"
done
echo ""

echo "By Status:"
for status in "${!STATUS_COUNTS[@]}"; do
    COUNT=${STATUS_COUNTS[$status]}
    printf "  %-15s %3d documents\n" "$status:" "$COUNT"
done
echo ""

if [[ ${#MISSING_INDICES[@]} -gt 0 ]]; then
    echo "Missing Indices:"
    for dir in "${MISSING_INDICES[@]}"; do
        echo "  ⚠️  $dir"
    done
    echo ""
fi

if [[ ${#VALIDATION_ISSUES[@]} -gt 0 ]]; then
    echo "Validation Issues:"
    for issue in "${VALIDATION_ISSUES[@]:0:10}"; do
        echo "  ❌ $issue"
    done
    if [[ ${#VALIDATION_ISSUES[@]} -gt 10 ]]; then
        echo "  ... and $((${#VALIDATION_ISSUES[@]} - 10)) more"
    fi
    echo ""
fi

echo "═══════════════════════════════════════"

# Generate JSON report
BY_TYPE_JSON="{"
FIRST=true
for doc_type in "${DOC_TYPES[@]}"; do
    COUNT=${TYPE_COUNTS[$doc_type]:-0}
    [[ "$FIRST" == "false" ]] && BY_TYPE_JSON+=","
    BY_TYPE_JSON+="\"$doc_type\":$COUNT"
    FIRST=false
done
BY_TYPE_JSON+="}"

BY_STATUS_JSON="{"
FIRST=true
for status in "${!STATUS_COUNTS[@]}"; do
    COUNT=${STATUS_COUNTS[$status]}
    [[ "$FIRST" == "false" ]] && BY_STATUS_JSON+=","
    BY_STATUS_JSON+="\"$status\":$COUNT"
    FIRST=false
done
BY_STATUS_JSON+="}"

cat <<EOF
{
  "status": "success",
  "operation": "audit",
  "summary": {
    "total_documents": $TOTAL_DOCS,
    "doc_types": ${#DOC_TYPES[@]},
    "missing_indices": ${#MISSING_INDICES[@]},
    "validation_issues": ${#VALIDATION_ISSUES[@]}
  },
  "by_type": $BY_TYPE_JSON,
  "by_status": $BY_STATUS_JSON,
  "missing_indices": $(printf '%s\n' "${MISSING_INDICES[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]'),
  "validation_issues": $(printf '%s\n' "${VALIDATION_ISSUES[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')
}
EOF

exit 0
