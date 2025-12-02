#!/usr/bin/env bash
# copy-to-docs.sh - Copy session summaries to docs/conversations/ directory
#
# Usage:
#   ./copy-to-docs.sh --summary-path <path> --docs-path <path> [--issue-number <num>] [--update-index true|false]
#
# Inputs:
#   --summary-path   Path to the session summary file
#   --docs-path      Target docs directory (e.g., docs/conversations)
#   --issue-number   Associated issue number (optional)
#   --update-index   Update README.md index (default: true)
#   --config-file    Path to logs config file (optional)
#
# Outputs:
#   JSON with copy results

set -euo pipefail

# Defaults
SUMMARY_PATH=""
DOCS_PATH="docs/conversations"
ISSUE_NUMBER=""
UPDATE_INDEX="true"
CONFIG_FILE=".fractary/plugins/logs/config.json"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --summary-path)
      SUMMARY_PATH="$2"
      shift 2
      ;;
    --docs-path)
      DOCS_PATH="$2"
      shift 2
      ;;
    --issue-number)
      ISSUE_NUMBER="$2"
      shift 2
      ;;
    --update-index)
      UPDATE_INDEX="$2"
      shift 2
      ;;
    --config-file)
      CONFIG_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate inputs
if [[ -z "$SUMMARY_PATH" ]]; then
  echo '{"success": false, "error": "Summary path required", "error_code": "MISSING_SUMMARY"}'
  exit 1
fi

if [[ ! -f "$SUMMARY_PATH" ]]; then
  echo '{"success": false, "error": "Summary file not found: '"$SUMMARY_PATH"'", "error_code": "FILE_NOT_FOUND"}'
  exit 1
fi

# Load config if available
if [[ -f "$CONFIG_FILE" ]]; then
  DOCS_INTEGRATION_ENABLED=$(jq -r '.docs_integration.enabled // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
  DOCS_PATH=$(jq -r '.docs_integration.docs_path // "docs/conversations"' "$CONFIG_FILE" 2>/dev/null || echo "$DOCS_PATH")
  INDEX_FILE=$(jq -r '.docs_integration.index_file // "docs/conversations/README.md"' "$CONFIG_FILE" 2>/dev/null || echo "$DOCS_PATH/README.md")
  FILENAME_PATTERN=$(jq -r '.docs_integration.summary_filename_pattern // "{date}-{issue_number}-{slug}.md"' "$CONFIG_FILE" 2>/dev/null || echo "{date}-{issue_number}-{slug}.md")
  MAX_INDEX_ENTRIES=$(jq -r '.docs_integration.max_index_entries // 50' "$CONFIG_FILE" 2>/dev/null || echo "50")
else
  DOCS_INTEGRATION_ENABLED="true"
  INDEX_FILE="$DOCS_PATH/README.md"
  FILENAME_PATTERN="{date}-{issue_number}-{slug}.md"
  MAX_INDEX_ENTRIES="50"
fi

# Check if docs integration is enabled
if [[ "$DOCS_INTEGRATION_ENABLED" != "true" ]]; then
  echo '{"success": true, "skipped": true, "message": "Docs integration disabled in config"}'
  exit 0
fi

# Create docs directory if it doesn't exist
mkdir -p "$DOCS_PATH"

# Extract metadata from summary file
SUMMARY_DATE=$(date +%Y-%m-%d)
if [[ -f "$SUMMARY_PATH" ]]; then
  # Try to extract date from frontmatter
  FRONTMATTER_DATE=$(grep -m1 "^date:" "$SUMMARY_PATH" 2>/dev/null | sed 's/date: *//' | tr -d '"' || echo "")
  if [[ -n "$FRONTMATTER_DATE" ]]; then
    SUMMARY_DATE=$(echo "$FRONTMATTER_DATE" | cut -d'T' -f1)
  fi

  # Try to extract title for slug
  TITLE=$(grep -m1 "^title:" "$SUMMARY_PATH" 2>/dev/null | sed 's/title: *//' | tr -d '"' || echo "session")
  SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-50)
fi

# Build filename
FILENAME="$FILENAME_PATTERN"
FILENAME="${FILENAME//\{date\}/$SUMMARY_DATE}"
FILENAME="${FILENAME//\{issue_number\}/${ISSUE_NUMBER:-unknown}}"
FILENAME="${FILENAME//\{slug\}/${SLUG:-session}}"

# Target path
TARGET_PATH="$DOCS_PATH/$FILENAME"

# Copy the summary file
cp "$SUMMARY_PATH" "$TARGET_PATH"

# Update index if requested
INDEX_UPDATED="false"
if [[ "$UPDATE_INDEX" == "true" ]]; then
  # Create index file if it doesn't exist
  if [[ ! -f "$INDEX_FILE" ]]; then
    cat > "$INDEX_FILE" << 'EOF'
# Conversation Logs

This directory contains summaries of Claude Code sessions, automatically captured by the fractary-logs plugin.

## Recent Conversations

| Date | Issue | Summary |
|------|-------|---------|
EOF
    INDEX_UPDATED="true"
  fi

  # Extract first line of summary for description
  SUMMARY_LINE=$(grep -m1 "^##\|^###\|^-" "$TARGET_PATH" 2>/dev/null | sed 's/^[#-]* *//' | cut -c1-60 || echo "Session summary")

  # Add new entry to index (after the table header)
  NEW_ENTRY="| $SUMMARY_DATE | #${ISSUE_NUMBER:-N/A} | [$SLUG](./$FILENAME) - $SUMMARY_LINE |"

  # Check if we have a table in the index
  if grep -q "^| Date" "$INDEX_FILE"; then
    # Insert after the header row (line with |---|)
    sed -i "/^|---/a $NEW_ENTRY" "$INDEX_FILE"
    INDEX_UPDATED="true"

    # Limit to max entries (count data rows, not header)
    DATA_LINES=$(grep -c "^| [0-9]" "$INDEX_FILE" 2>/dev/null || echo "0")
    if [[ "$DATA_LINES" -gt "$MAX_INDEX_ENTRIES" ]]; then
      # Remove oldest entries (last lines that match data pattern)
      LINES_TO_REMOVE=$((DATA_LINES - MAX_INDEX_ENTRIES))
      # Use tac to reverse, remove lines, then reverse back
      tac "$INDEX_FILE" | sed "0,/^| [0-9]/{ s/^| [0-9].*$//; }" | tac > "$INDEX_FILE.tmp"
      mv "$INDEX_FILE.tmp" "$INDEX_FILE"
    fi
  fi
fi

# Output results
cat <<EOF
{
  "success": true,
  "operation": "copy-to-docs",
  "summary_path": "$SUMMARY_PATH",
  "target_path": "$TARGET_PATH",
  "filename": "$FILENAME",
  "docs_path": "$DOCS_PATH",
  "index_file": "$INDEX_FILE",
  "index_updated": $INDEX_UPDATED,
  "issue_number": "${ISSUE_NUMBER:-null}"
}
EOF
