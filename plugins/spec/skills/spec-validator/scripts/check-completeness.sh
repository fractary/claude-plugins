#!/usr/bin/env bash
#
# check-completeness.sh - Check implementation completeness
#
# Usage: check-completeness.sh <spec_path>
#
# Outputs JSON with completeness check results

set -euo pipefail

SPEC_PATH="${1:?Spec path required}"

# Validate spec exists
if [[ ! -f "$SPEC_PATH" ]]; then
    echo '{"error": "Spec file not found"}' >&2
    exit 1
fi

# Extract acceptance criteria
TOTAL_CRITERIA=$(grep -c "^- \[.\]" "$SPEC_PATH" 2>/dev/null || echo "0")
MET_CRITERIA=$(grep -c "^- \[x\]\|^- \[X\]" "$SPEC_PATH" 2>/dev/null || echo "0")
UNMET_CRITERIA=$((TOTAL_CRITERIA - MET_CRITERIA))

# Extract expected files
EXPECTED_FILES=$(grep -E "^\s*-\s*\`[^`]+\`:" "$SPEC_PATH" 2>/dev/null |
    sed -E "s/.*\`([^`]+)\`.*/\1/" || echo "")

# Count expected files
FILE_COUNT=$(echo "$EXPECTED_FILES" | grep -c . || echo "0")

# Check which files were recently modified
MODIFIED_COUNT=0
if [[ -n "$EXPECTED_FILES" ]]; then
    while IFS= read -r file; do
        if [[ -f "$file" ]] && git log --since="30 days ago" --name-only --format="" | grep -q "^$file$"; then
            ((MODIFIED_COUNT++)) || true
        fi
    done <<< "$EXPECTED_FILES"
fi

# Check for test files modified recently
TEST_FILES=$(git log --since="30 days ago" --name-only --format="" |
    grep -E "\.(test|spec)\.(ts|js|tsx|jsx)$" |
    sort -u || echo "")
TEST_FILE_COUNT=$(echo "$TEST_FILES" | grep -c . || echo "0")

# Check for doc files modified recently (excluding specs)
DOC_FILES=$(git log --since="30 days ago" --name-only --format="" |
    grep "\.md$" |
    grep -v "^specs/" |
    grep -v "^spec-" |
    sort -u || echo "")
DOC_FILE_COUNT=$(echo "$DOC_FILES" | grep -c . || echo "0")

# Output JSON
cat <<EOF
{
  "acceptance_criteria": {
    "total": $TOTAL_CRITERIA,
    "met": $MET_CRITERIA,
    "unmet": $UNMET_CRITERIA,
    "percentage": $(awk "BEGIN {printf \"%.0f\", ($TOTAL_CRITERIA > 0 ? $MET_CRITERIA * 100 / $TOTAL_CRITERIA : 0)}")
  },
  "files": {
    "expected": $FILE_COUNT,
    "modified": $MODIFIED_COUNT,
    "percentage": $(awk "BEGIN {printf \"%.0f\", ($FILE_COUNT > 0 ? $MODIFIED_COUNT * 100 / $FILE_COUNT : 0)}")
  },
  "tests": {
    "files_modified": $TEST_FILE_COUNT,
    "status": "$([ $TEST_FILE_COUNT -gt 0 ] && echo "pass" || echo "warn")"
  },
  "docs": {
    "files_modified": $DOC_FILE_COUNT,
    "status": "$([ $DOC_FILE_COUNT -gt 0 ] && echo "pass" || echo "warn")"
  }
}
EOF
