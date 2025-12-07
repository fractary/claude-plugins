#!/usr/bin/env bash
#
# format-feedback-comment.sh - Format a feedback request as a GitHub issue comment
#
# Usage:
#   format-feedback-comment.sh --run-id <id> --request-id <id> --type <type> \
#     --phase <phase> --step <step> --prompt <text> --options <json> \
#     [--context <json>] [--timestamp <ts>]
#
# Outputs markdown-formatted comment to stdout
#

set -euo pipefail

# Parse arguments
RUN_ID=""
REQUEST_ID=""
FEEDBACK_TYPE=""
PHASE=""
STEP=""
PROMPT=""
OPTIONS_JSON="[]"
CONTEXT_JSON="{}"
TIMESTAMP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --run-id)
            RUN_ID="$2"
            shift 2
            ;;
        --request-id)
            REQUEST_ID="$2"
            shift 2
            ;;
        --type)
            FEEDBACK_TYPE="$2"
            shift 2
            ;;
        --phase)
            PHASE="$2"
            shift 2
            ;;
        --step)
            STEP="$2"
            shift 2
            ;;
        --prompt)
            PROMPT="$2"
            shift 2
            ;;
        --options)
            OPTIONS_JSON="$2"
            shift 2
            ;;
        --context)
            CONTEXT_JSON="$2"
            shift 2
            ;;
        --timestamp)
            TIMESTAMP="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$RUN_ID" || -z "$REQUEST_ID" || -z "$FEEDBACK_TYPE" || -z "$PHASE" || -z "$STEP" || -z "$PROMPT" ]]; then
    echo "Missing required parameters" >&2
    exit 1
fi

# Validate run_id format - must match: org/project/uuid (prevents path traversal)
if [[ ! "$RUN_ID" =~ ^[a-z0-9][a-z0-9_-]*[a-z0-9]/[a-z0-9][a-z0-9_-]*[a-z0-9]/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]] && \
   [[ ! "$RUN_ID" =~ ^[a-z0-9]/[a-z0-9]/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
    echo "Invalid run_id format. Must be: org/project/uuid" >&2
    exit 1
fi

# Default timestamp
if [[ -z "$TIMESTAMP" ]]; then
    TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")
fi

# Extract context fields
SUMMARY=$(echo "$CONTEXT_JSON" | jq -r '.summary // empty')
ARTIFACT_PATH=$(echo "$CONTEXT_JSON" | jq -r '.artifact_path // empty')

# Get option descriptions based on type
get_option_description() {
    local option="$1"
    local type="$2"

    case "$type" in
        approval)
            case "$option" in
                approve) echo "Continue to next phase" ;;
                reject) echo "Cancel this workflow run" ;;
                *) echo "" ;;
            esac
            ;;
        review)
            case "$option" in
                approve) echo "Continue to next phase" ;;
                request_changes) echo "Provide feedback for revision" ;;
                reject) echo "Cancel this workflow run" ;;
                *) echo "" ;;
            esac
            ;;
        error_resolution)
            case "$option" in
                retry) echo "Attempt the step again" ;;
                skip) echo "Skip this step and continue" ;;
                abort) echo "Cancel this workflow run" ;;
                *) echo "" ;;
            esac
            ;;
        confirmation)
            case "$option" in
                confirm) echo "Proceed with the action" ;;
                cancel) echo "Do not proceed" ;;
                *) echo "" ;;
            esac
            ;;
        *)
            echo ""
            ;;
    esac
}

# Format phase name for display
format_phase() {
    local phase="$1"
    # Capitalize first letter
    echo "${phase^}"
}

# Build the comment
cat << EOF
## Feedback Requested

**Workflow Run**: \`${RUN_ID}\`
**Phase**: $(format_phase "$PHASE")
**Step**: ${STEP}
**Requested**: ${TIMESTAMP}

### Decision Needed

${PROMPT}

EOF

# Add summary if present
if [[ -n "$SUMMARY" ]]; then
    cat << EOF
**Summary**:
${SUMMARY}

EOF
fi

# Add artifact link if present
if [[ -n "$ARTIFACT_PATH" ]]; then
    ARTIFACT_FILENAME=$(basename "$ARTIFACT_PATH")
    cat << EOF
**Artifact**: [${ARTIFACT_FILENAME}](${ARTIFACT_PATH})

EOF
fi

# Add options
echo "### Options"
echo ""

INDEX=1
echo "$OPTIONS_JSON" | jq -r '.[]' | while read -r option; do
    DESC=$(get_option_description "$option" "$FEEDBACK_TYPE")
    if [[ -n "$DESC" ]]; then
        echo "${INDEX}. **${option}** - ${DESC}"
    else
        echo "${INDEX}. **${option}**"
    fi
    INDEX=$((INDEX + 1))
done

cat << EOF

### How to Respond

Reply to this issue with your decision. Include \`@faber resume\` in your comment to trigger workflow continuation.

**Example response:**
\`\`\`
I approve this design. The approach looks good.

@faber resume
\`\`\`

---
_This feedback request will remain open until addressed._
_Run ID: \`${RUN_ID}\` | Request ID: \`${REQUEST_ID}\`_
EOF
