#!/usr/bin/env bash
# generate-suggestions.sh - Generate update suggestions for stale documentation
#
# Usage:
#   ./generate-suggestions.sh --target <file> --changes <json> [--output-format json|diff]
#
# Inputs:
#   --target        Target document path
#   --changes       JSON with change details from check-consistency.sh
#   --output-format Output format: json or diff (default: json)
#
# Outputs:
#   JSON with suggested updates or diff format

set -euo pipefail

# Defaults
TARGET=""
CHANGES=""
OUTPUT_FORMAT="json"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --changes)
      CHANGES="$2"
      shift 2
      ;;
    --output-format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate inputs
if [[ -z "$TARGET" ]]; then
  echo '{"success": false, "error": "Target document required", "error_code": "MISSING_TARGET"}'
  exit 1
fi

if [[ ! -f "$TARGET" ]]; then
  echo '{"success": false, "error": "Target document not found: '"$TARGET"'", "error_code": "FILE_NOT_FOUND"}'
  exit 1
fi

# Read current document content
CONTENT=$(cat "$TARGET")

# Parse changes JSON
if [[ -n "$CHANGES" ]]; then
  FEATURE_CHANGES=$(echo "$CHANGES" | jq -r '.changes.features // []')
  ARCH_CHANGES=$(echo "$CHANGES" | jq -r '.changes.architecture // []')
  CONFIG_CHANGES=$(echo "$CHANGES" | jq -r '.changes.configuration // []')
  API_CHANGES=$(echo "$CHANGES" | jq -r '.changes.api // []')
else
  FEATURE_CHANGES="[]"
  ARCH_CHANGES="[]"
  CONFIG_CHANGES="[]"
  API_CHANGES="[]"
fi

# Initialize suggestions array
SUGGESTIONS="[]"

# Generate suggestions based on document type and changes
case "$TARGET" in
  *CLAUDE.md*)
    # Check for new skills
    NEW_SKILLS=$(echo "$FEATURE_CHANGES" | jq -r '.[] | select(.file | contains("/skills/")) | select(.status == "A") | .file')

    for skill_path in $NEW_SKILLS; do
      skill_name=$(basename "$(dirname "$skill_path")")
      parent_dir=$(dirname "$(dirname "$skill_path")")

      SUGGESTIONS=$(echo "$SUGGESTIONS" | jq --arg section "Directory Structure" \
        --arg action "add" \
        --arg content "│   └── $skill_name/  # New skill" \
        --arg context "$parent_dir" \
        --arg priority "high" \
        '. + [{"section": $section, "action": $action, "content": $content, "context": $context, "priority": $priority}]')
    done

    # Check for new commands
    NEW_COMMANDS=$(echo "$FEATURE_CHANGES" | jq -r '.[] | select(.file | contains("/commands/")) | select(.status == "A") | .file')

    for cmd_path in $NEW_COMMANDS; do
      cmd_name=$(basename "$cmd_path" .md)

      SUGGESTIONS=$(echo "$SUGGESTIONS" | jq --arg section "Available Commands" \
        --arg action "add" \
        --arg content "- /$cmd_name: New command" \
        --arg context "commands" \
        --arg priority "medium" \
        '. + [{"section": $section, "action": $action, "content": $content, "context": $context, "priority": $priority}]')
    done

    # Check for config changes
    CONFIG_FILES=$(echo "$CONFIG_CHANGES" | jq -r '.[] | .file')

    if [[ -n "$CONFIG_FILES" ]]; then
      SUGGESTIONS=$(echo "$SUGGESTIONS" | jq --arg section "Configuration Files" \
        --arg action "review" \
        --arg content "Configuration files have been modified - review for accuracy" \
        --arg context "config" \
        --arg priority "medium" \
        '. + [{"section": $section, "action": $action, "content": $content, "context": $context, "priority": $priority}]')
    fi
    ;;

  *README.md)
    # Check for new features
    NEW_FEATURES=$(echo "$FEATURE_CHANGES" | jq -r '.[] | select(.status == "A") | .file')

    if [[ -n "$NEW_FEATURES" ]]; then
      SUGGESTIONS=$(echo "$SUGGESTIONS" | jq --arg section "Features" \
        --arg action "add" \
        --arg content "New features have been added - update Features section" \
        --arg context "features" \
        --arg priority "high" \
        '. + [{"section": $section, "action": $action, "content": $content, "context": $context, "priority": $priority}]')
    fi

    # Check for API changes
    API_FILES=$(echo "$API_CHANGES" | jq -r '.[] | .file')

    if [[ -n "$API_FILES" ]]; then
      SUGGESTIONS=$(echo "$SUGGESTIONS" | jq --arg section "API" \
        --arg action "review" \
        --arg content "API changes detected - update API documentation" \
        --arg context "api" \
        --arg priority "high" \
        '. + [{"section": $section, "action": $action, "content": $content, "context": $context, "priority": $priority}]')
    fi
    ;;

  *CONTRIBUTING.md)
    # Check for significant architecture changes
    ARCH_COUNT=$(echo "$ARCH_CHANGES" | jq 'length')

    if [[ "$ARCH_COUNT" -gt 3 ]]; then
      SUGGESTIONS=$(echo "$SUGGESTIONS" | jq --arg section "Project Structure" \
        --arg action "review" \
        --arg content "Significant architecture changes - review Project Structure section" \
        --arg context "architecture" \
        --arg priority "medium" \
        '. + [{"section": $section, "action": $action, "content": $content, "context": $context, "priority": $priority}]')
    fi
    ;;
esac

# Output results
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  cat <<EOF
{
  "success": true,
  "operation": "suggest",
  "target": "$TARGET",
  "suggestions": $SUGGESTIONS,
  "total_suggestions": $(echo "$SUGGESTIONS" | jq 'length')
}
EOF
else
  # Diff format output
  echo "--- $TARGET"
  echo "+++ $TARGET (suggested)"
  echo ""
  echo "$SUGGESTIONS" | jq -r '.[] | "Section: \(.section)\nAction: \(.action)\nContent: \(.content)\nPriority: \(.priority)\n---"'
fi
