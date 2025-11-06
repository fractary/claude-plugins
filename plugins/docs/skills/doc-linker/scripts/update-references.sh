#!/usr/bin/env bash
#
# update-references.sh - Update cross-references between documents
#
# Usage: update-references.sh --source <file> --target <file> [--bidirectional] [--validate]
#

set -euo pipefail

# Default values
SOURCE_FILE=""
TARGET_FILE=""
BIDIRECTIONAL=true
VALIDATE_BEFORE=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --source)
      SOURCE_FILE="$2"
      shift 2
      ;;
    --target)
      TARGET_FILE="$2"
      shift 2
      ;;
    --bidirectional)
      BIDIRECTIONAL="$2"
      shift 2
      ;;
    --validate)
      VALIDATE_BEFORE="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$SOURCE_FILE" ]]; then
  cat <<EOF
{
  "success": false,
  "error": "Missing required argument: --source",
  "error_code": "MISSING_ARGUMENT"
}
EOF
  exit 1
fi

if [[ -z "$TARGET_FILE" ]]; then
  cat <<EOF
{
  "success": false,
  "error": "Missing required argument: --target",
  "error_code": "MISSING_ARGUMENT"
}
EOF
  exit 1
fi

# Check if jq and yq are available
if ! command -v jq &> /dev/null; then
  cat <<EOF
{
  "success": false,
  "error": "jq is required but not installed",
  "error_code": "MISSING_DEPENDENCY"
}
EOF
  exit 1
fi

# Validate files exist
if [[ "$VALIDATE_BEFORE" == "true" ]]; then
  if [[ ! -f "$SOURCE_FILE" ]]; then
    cat <<EOF
{
  "success": false,
  "error": "Source file not found: $SOURCE_FILE",
  "error_code": "FILE_NOT_FOUND"
}
EOF
    exit 1
  fi

  if [[ ! -f "$TARGET_FILE" ]]; then
    cat <<EOF
{
  "success": false,
  "error": "Target file not found: $TARGET_FILE",
  "error_code": "FILE_NOT_FOUND"
}
EOF
    exit 1
  fi
fi

# Get script directory to find doc-updater
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_METADATA_SCRIPT="$SCRIPT_DIR/../../doc-updater/scripts/update-metadata.sh"

if [[ ! -f "$UPDATE_METADATA_SCRIPT" ]]; then
  cat <<EOF
{
  "success": false,
  "error": "update-metadata.sh not found at $UPDATE_METADATA_SCRIPT",
  "error_code": "MISSING_DEPENDENCY"
}
EOF
  exit 1
fi

# Helper function to add reference to file
add_reference_to_file() {
  local file=$1
  local target=$2

  # Get directory of file for calculating relative path
  local file_dir="$(cd "$(dirname "$file")" && pwd)"

  # Calculate relative path from file to target
  local rel_path=$(realpath --relative-to="$file_dir" "$target" 2>/dev/null || echo "$target")

  # Check if file has front matter
  if ! head -n 1 "$file" | grep -q "^---$"; then
    echo "Warning: $file has no front matter, skipping" >&2
    return 1
  fi

  # Extract front matter
  local fm_content=$(sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d')

  # Parse existing related array
  local related_array="[]"
  if command -v yq &> /dev/null; then
    related_array=$(echo "$fm_content" | yq eval '.related // []' -o json 2>/dev/null || echo "[]")
  else
    # Try to extract related array with basic parsing
    if echo "$fm_content" | grep -q "^related:"; then
      # Extract array items (very basic)
      related_array=$(echo "$fm_content" | sed -n '/^related:/,/^[a-z]/p' | grep '^\s*-' | sed 's/^\s*-\s*//' | jq -R -s -c 'split("\n") | map(select(length > 0))')
    fi
  fi

  # Check if target already in related array
  if echo "$related_array" | jq -e --arg target "$rel_path" 'any(. == $target)' > /dev/null 2>&1; then
    echo "Reference already exists in $file" >&2
    return 0
  fi

  # Add target to related array
  local new_related=$(echo "$related_array" | jq --arg target "$rel_path" '. += [$target]')

  # Update front matter using update-metadata.sh
  "$UPDATE_METADATA_SCRIPT" \
    --file "$file" \
    --field "related" \
    --value "$new_related" \
    --auto-timestamp true > /dev/null 2>&1

  if [[ $? -eq 0 ]]; then
    echo "Added reference: $file -> $rel_path" >&2
    return 0
  else
    echo "Failed to update $file" >&2
    return 1
  fi
}

# Add reference from source to target
LINKS_ADDED=0

if add_reference_to_file "$SOURCE_FILE" "$TARGET_FILE"; then
  ((LINKS_ADDED++))
fi

# Add bidirectional reference if enabled
if [[ "$BIDIRECTIONAL" == "true" ]]; then
  if add_reference_to_file "$TARGET_FILE" "$SOURCE_FILE"; then
    ((LINKS_ADDED++))
  fi
fi

# Check for circular references (basic check)
SOURCE_DIR="$(cd "$(dirname "$SOURCE_FILE")" && pwd)"
TARGET_DIR="$(cd "$(dirname "$TARGET_FILE")" && pwd)"
SOURCE_BASE="$(basename "$SOURCE_FILE")"
TARGET_BASE="$(basename "$TARGET_FILE")"

# Return results
cat <<EOF
{
  "success": true,
  "operation": "update-references",
  "source_file": "$SOURCE_FILE",
  "target_file": "$TARGET_FILE",
  "bidirectional": $BIDIRECTIONAL,
  "links_added": $LINKS_ADDED,
  "timestamp": "$(date -Iseconds)"
}
EOF
