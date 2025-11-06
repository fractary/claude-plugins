#!/usr/bin/env bash
#
# generate-from-template.sh - Main script to generate documentation from template
#
# Usage: generate-from-template.sh --template <path> --data <json> --frontmatter <json> --output <path> [--validate]
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
TEMPLATE_PATH=""
DATA_JSON=""
FRONTMATTER_JSON=""
OUTPUT_PATH=""
VALIDATE=false
OVERWRITE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --template)
      TEMPLATE_PATH="$2"
      shift 2
      ;;
    --data)
      DATA_JSON="$2"
      shift 2
      ;;
    --frontmatter)
      FRONTMATTER_JSON="$2"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --validate)
      VALIDATE=true
      shift
      ;;
    --overwrite)
      OVERWRITE=true
      shift
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$TEMPLATE_PATH" ]] || [[ -z "$DATA_JSON" ]] || [[ -z "$FRONTMATTER_JSON" ]] || [[ -z "$OUTPUT_PATH" ]]; then
  echo "Error: Missing required arguments" >&2
  echo "Usage: generate-from-template.sh --template <path> --data <json> --frontmatter <json> --output <path> [--validate] [--overwrite]" >&2
  exit 1
fi

# Check if output file already exists
if [[ -f "$OUTPUT_PATH" ]] && [[ "$OVERWRITE" != "true" ]]; then
  cat <<EOF
{
  "success": false,
  "error": "File already exists: $OUTPUT_PATH",
  "error_code": "FILE_EXISTS",
  "suggested_action": "Use --overwrite flag to replace existing file"
}
EOF
  exit 1
fi

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
if [[ ! -d "$OUTPUT_DIR" ]]; then
  mkdir -p "$OUTPUT_DIR"
fi

# Create temporary file for rendering
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Step 1: Render template
echo "Rendering template..." >&2
RENDER_RESULT=$("$SCRIPT_DIR/render-template.sh" \
  --template "$TEMPLATE_PATH" \
  --data "$DATA_JSON" \
  --output "$TEMP_FILE")

if ! echo "$RENDER_RESULT" | jq -e '.success' &>/dev/null; then
  echo "Error: Template rendering failed" >&2
  echo "$RENDER_RESULT" >&2
  exit 1
fi

# Step 2: Add front matter
echo "Adding front matter..." >&2
FM_RESULT=$("$SCRIPT_DIR/add-frontmatter.sh" \
  --file "$TEMP_FILE" \
  --frontmatter "$FRONTMATTER_JSON")

if ! echo "$FM_RESULT" | jq -e '.success' &>/dev/null; then
  echo "Error: Front matter addition failed" >&2
  echo "$FM_RESULT" >&2
  exit 1
fi

# Step 3: Move to final location
mv "$TEMP_FILE" "$OUTPUT_PATH"

# Get file info
FILE_SIZE=$(stat -c%s "$OUTPUT_PATH" 2>/dev/null || stat -f%z "$OUTPUT_PATH" 2>/dev/null)

# Step 4: Validate if requested
VALIDATION_RESULT='{"validation": "skipped"}'
if [[ "$VALIDATE" == "true" ]]; then
  echo "Validating output..." >&2
  if [[ -f "$SCRIPT_DIR/validate-output.sh" ]]; then
    # Extract doc type from front matter
    DOC_TYPE=$(echo "$FRONTMATTER_JSON" | jq -r '.type // "unknown"')

    VALIDATION_RESULT=$("$SCRIPT_DIR/validate-output.sh" \
      --file "$OUTPUT_PATH" \
      --doc-type "$DOC_TYPE" 2>&1 || echo '{"success": false, "validation": "failed"}')
  else
    echo "Warning: validate-output.sh not found, skipping validation" >&2
  fi
fi

# Extract sections from generated document (markdown headings)
SECTIONS=$(grep -E '^#{1,3} ' "$OUTPUT_PATH" | sed 's/^#* //' | jq -R . | jq -s '.')

# Build result JSON
cat <<EOF
{
  "success": true,
  "operation": "generate-from-template",
  "template": "$TEMPLATE_PATH",
  "output": "$OUTPUT_PATH",
  "size_bytes": $FILE_SIZE,
  "sections": $SECTIONS,
  "validation": $(echo "$VALIDATION_RESULT" | jq -r '.validation // "skipped"'),
  "validation_issues": $(echo "$VALIDATION_RESULT" | jq '.issues // []')
}
EOF
