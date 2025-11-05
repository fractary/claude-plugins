#!/usr/bin/env bash
#
# generate-spec.sh - Generate specification from issue data
#
# Usage: generate-spec.sh <issue_json> <template_path> <output_path>
#
# Creates spec file from template and issue data

set -euo pipefail

ISSUE_JSON="${1:?Issue JSON required}"
TEMPLATE_PATH="${2:?Template path required}"
OUTPUT_PATH="${3:?Output path required}"

# Validate template exists
if [[ ! -f "$TEMPLATE_PATH" ]]; then
    echo "Error: Template not found: $TEMPLATE_PATH" >&2
    exit 1
fi

# Parse issue data
ISSUE_NUMBER=$(echo "$ISSUE_JSON" | jq -r '.number')
ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
ISSUE_URL=$(echo "$ISSUE_JSON" | jq -r '.url')
ISSUE_BODY=$(echo "$ISSUE_JSON" | jq -r '.body // ""')
ISSUE_LABELS=$(echo "$ISSUE_JSON" | jq -r '.labels[]?.name // empty' | paste -sd ',' -)
ISSUE_ASSIGNEES=$(echo "$ISSUE_JSON" | jq -r '.assignees[]?.login // empty' | head -1)
CREATED_AT=$(echo "$ISSUE_JSON" | jq -r '.createdAt')

# Generate slug from title
SLUG=$(echo "$ISSUE_TITLE" |
    tr '[:upper:]' '[:lower:]' |
    sed 's/[^a-z0-9 ]//g' |
    tr -s ' ' |
    tr ' ' '-' |
    cut -d'-' -f1-5)

# Extract summary (first paragraph)
SUMMARY=$(echo "$ISSUE_BODY" | awk 'BEGIN{RS=""; FS="\n"} NR==1{print; exit}' | tr '\n' ' ')

# Extract acceptance criteria
ACCEPTANCE_CRITERIA=$(echo "$ISSUE_BODY" |
    awk '/^## Acceptance Criteria/,/^##/ {if (!/^##/) print}' |
    grep -E '^\s*[-*]\s*\[.\]' || echo "")

# Extract requirements
REQUIREMENTS=$(echo "$ISSUE_BODY" |
    awk '/^## Requirements/,/^##/ {if (!/^##/) print}' |
    grep -E '^\s*[-*]' || echo "")

# Get current date
CURRENT_DATE=$(date -u +%Y-%m-%d)

# Author (from assignees or default)
AUTHOR="${ISSUE_ASSIGNEES:-Claude Code}"

# Create output directory if needed
mkdir -p "$(dirname "$OUTPUT_PATH")"

# Read template
TEMPLATE_CONTENT=$(cat "$TEMPLATE_PATH")

# Simple variable replacement (Mustache-style)
SPEC_CONTENT="$TEMPLATE_CONTENT"
SPEC_CONTENT="${SPEC_CONTENT//\{\{issue_number\}\}/$ISSUE_NUMBER}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{title\}\}/$ISSUE_TITLE}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{issue_url\}\}/$ISSUE_URL}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{slug\}\}/$SLUG}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{date\}\}/$CURRENT_DATE}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{author\}\}/$AUTHOR}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{summary\}\}/${SUMMARY:-TBD}}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{work_type\}\}/feature}"  # Will be set by caller

# Handle acceptance criteria list
if [[ -n "$ACCEPTANCE_CRITERIA" ]]; then
    CRITERIA_SECTION="$ACCEPTANCE_CRITERIA"
else
    CRITERIA_SECTION="- [ ] TBD"
fi
# Replace the mustache loop with actual content
SPEC_CONTENT=$(echo "$SPEC_CONTENT" | awk -v criteria="$CRITERIA_SECTION" '
    BEGIN { in_block=0 }
    /\{\{#acceptance_criteria\}\}/ { in_block=1; next }
    /\{\{\/acceptance_criteria\}\}/ {
        if (in_block) {
            print criteria
            in_block=0
        }
        next
    }
    { if (!in_block) print }
')

# Replace other common placeholders with TBD
SPEC_CONTENT="${SPEC_CONTENT//\{\{#functional_requirements\}\}/}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{\/functional_requirements\}\}/}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{#non_functional_requirements\}\}/}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{\/non_functional_requirements\}\}/}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{#files\}\}/}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{\/files\}\}/}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{#dependencies\}\}/}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{\/dependencies\}\}/}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{#risks\}\}/}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{\/risks\}\}/}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{technical_approach\}\}/TBD}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{testing_strategy\}\}/TBD}"
SPEC_CONTENT="${SPEC_CONTENT//\{\{notes\}\}/}"

# Write spec file
echo "$SPEC_CONTENT" > "$OUTPUT_PATH"

echo "Spec generated: $OUTPUT_PATH"
