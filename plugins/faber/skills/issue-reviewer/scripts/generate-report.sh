#!/bin/bash
#
# generate-report.sh
# Generates a markdown report from issue review analysis
#
# Usage: generate-report.sh --work-id <id> --status <status> --spec-compliance <json> --code-quality <json>
#
# Output: Path to generated report file
#

set -euo pipefail

# Parse arguments
WORK_ID=""
STATUS=""
SPEC_COMPLIANCE=""
CODE_QUALITY=""
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --work-id)
      WORK_ID="$2"
      shift 2
      ;;
    --status)
      STATUS="$2"
      shift 2
      ;;
    --spec-compliance)
      SPEC_COMPLIANCE="$2"
      shift 2
      ;;
    --code-quality)
      CODE_QUALITY="$2"
      shift 2
      ;;
    --message)
      MESSAGE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$WORK_ID" ]] || [[ -z "$STATUS" ]]; then
  echo "Usage: generate-report.sh --work-id <id> --status <status> [--spec-compliance <json>] [--code-quality <json>]" >&2
  exit 1
fi

# Setup output directory with error handling
REVIEWS_DIR=".fractary/plugins/faber/reviews"
if ! mkdir -p "$REVIEWS_DIR" 2>/dev/null; then
  echo "Error: Failed to create reviews directory: $REVIEWS_DIR" >&2
  exit 1
fi

# Generate timestamp
TIMESTAMP=$(date -u +"%Y%m%d%H%M%S")
HUMAN_TIME=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Generate report filename
REPORT_FILE="${REVIEWS_DIR}/${WORK_ID}-${TIMESTAMP}.md"

# Status emoji
case "$STATUS" in
  success) STATUS_EMOJI="✅" ;;
  warning) STATUS_EMOJI="⚠️" ;;
  failure) STATUS_EMOJI="❌" ;;
  *) STATUS_EMOJI="❓" ;;
esac

# Extract spec compliance data
if [[ -n "$SPEC_COMPLIANCE" ]] && [[ "$SPEC_COMPLIANCE" != "null" ]]; then
  COVERAGE=$(echo "$SPEC_COMPLIANCE" | jq -r '.coverage_percentage // "N/A"')
  REQ_MET=$(echo "$SPEC_COMPLIANCE" | jq -r '.requirements_met // 0')
  REQ_TOTAL=$(echo "$SPEC_COMPLIANCE" | jq -r '.requirements_total // 0')
  CRITICAL_GAPS=$(echo "$SPEC_COMPLIANCE" | jq -r '.critical_gaps // []')
  MAJOR_GAPS=$(echo "$SPEC_COMPLIANCE" | jq -r '.major_gaps // []')
else
  COVERAGE="N/A"
  REQ_MET="0"
  REQ_TOTAL="0"
  CRITICAL_GAPS="[]"
  MAJOR_GAPS="[]"
fi

# Extract code quality data
if [[ -n "$CODE_QUALITY" ]] && [[ "$CODE_QUALITY" != "null" ]]; then
  CRITICAL_ISSUES=$(echo "$CODE_QUALITY" | jq -r '.critical_issues // 0')
  MAJOR_ISSUES=$(echo "$CODE_QUALITY" | jq -r '.major_issues // 0')
  MINOR_ISSUES=$(echo "$CODE_QUALITY" | jq -r '.minor_issues // 0')
  TEST_ADEQUATE=$(echo "$CODE_QUALITY" | jq -r '.test_coverage_adequate // false')
  DOCS_ADEQUATE=$(echo "$CODE_QUALITY" | jq -r '.documentation_adequate // false')
  ISSUES_LIST=$(echo "$CODE_QUALITY" | jq -r '.issues // []')
else
  CRITICAL_ISSUES="0"
  MAJOR_ISSUES="0"
  MINOR_ISSUES="0"
  TEST_ADEQUATE="false"
  DOCS_ADEQUATE="false"
  ISSUES_LIST="[]"
fi

# Generate report content
cat > "$REPORT_FILE" << EOF
# Issue Review Report

**Work ID**: #${WORK_ID}
**Date**: ${HUMAN_TIME}
**Status**: ${STATUS_EMOJI} ${STATUS}

---

## Summary

${MESSAGE:-"Automated review of implementation against specification and issue requirements."}

---

## Specification Compliance

| Metric | Value |
|--------|-------|
| Coverage | ${COVERAGE}% |
| Requirements Met | ${REQ_MET}/${REQ_TOTAL} |

EOF

# Add gaps if any
if [[ $(echo "$CRITICAL_GAPS" | jq 'length') -gt 0 ]]; then
  echo "### Critical Gaps" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  echo "$CRITICAL_GAPS" | jq -r '.[] | "- ❌ " + .' >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
fi

if [[ $(echo "$MAJOR_GAPS" | jq 'length') -gt 0 ]]; then
  echo "### Major Gaps" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  echo "$MAJOR_GAPS" | jq -r '.[] | "- ⚠️ " + .' >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" << EOF

---

## Code Quality

| Severity | Count |
|----------|-------|
| Critical | ${CRITICAL_ISSUES} |
| Major | ${MAJOR_ISSUES} |
| Minor | ${MINOR_ISSUES} |

| Check | Status |
|-------|--------|
| Test Coverage | $([ "$TEST_ADEQUATE" == "true" ] && echo "✅ Adequate" || echo "⚠️ Needs improvement") |
| Documentation | $([ "$DOCS_ADEQUATE" == "true" ] && echo "✅ Adequate" || echo "⚠️ Needs improvement") |

EOF

# Add issues list if any
TOTAL_ISSUES=$((CRITICAL_ISSUES + MAJOR_ISSUES + MINOR_ISSUES))
if [[ $TOTAL_ISSUES -gt 0 ]]; then
  echo "### Issues Found" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"

  if [[ $(echo "$ISSUES_LIST" | jq 'length') -gt 0 ]]; then
    echo "$ISSUES_LIST" | jq -r '.[] | "1. **[" + .severity + "]** " + .description + " (`" + (.file // "N/A") + ":" + (.line | tostring // "N/A") + "`)"' >> "$REPORT_FILE"
  else
    echo "Issues details not available in structured format." >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
fi

# Add recommendations based on status
cat >> "$REPORT_FILE" << EOF

---

## Recommendations

EOF

case "$STATUS" in
  success)
    echo "1. ✅ Implementation is complete and ready for release" >> "$REPORT_FILE"
    echo "2. Consider a final manual review before merging" >> "$REPORT_FILE"
    ;;
  warning)
    echo "1. ⚠️ Address minor issues before release if time permits" >> "$REPORT_FILE"
    echo "2. Consider creating follow-up issues for improvements" >> "$REPORT_FILE"
    echo "3. Proceed with caution - implementation is functional" >> "$REPORT_FILE"
    ;;
  failure)
    echo "1. ❌ Return to Build phase to address critical gaps" >> "$REPORT_FILE"
    echo "2. Focus on implementing missing requirements" >> "$REPORT_FILE"
    echo "3. Add tests for new functionality" >> "$REPORT_FILE"
    echo "4. Do not proceed to release until issues are resolved" >> "$REPORT_FILE"
    ;;
esac

# Footer
cat >> "$REPORT_FILE" << EOF

---

*Generated by issue-reviewer skill*
*Model: claude-opus-4-5*
*Timestamp: ${TIMESTAMP}*
EOF

# Verify report was written successfully
if [[ ! -f "$REPORT_FILE" ]]; then
  echo "Error: Failed to create report file: $REPORT_FILE" >&2
  exit 1
fi

# Output the report path
echo "$REPORT_FILE"
