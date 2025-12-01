#!/bin/bash
# Sync documentation files between repositories based on glob patterns
#
# Usage:
#   ./sync-docs.sh --source <dir> --target <dir> [options]
#
# Options:
#   --source <path>                  Source directory (required)
#   --target <path>                  Target directory (required)
#   --include <patterns>             Comma-separated include patterns (required)
#   --exclude <patterns>             Comma-separated exclude patterns
#   --dry-run <true|false>           Dry-run mode (default: false)
#   --deletion-threshold <number>    Max files to delete (default: 50)
#   --deletion-threshold-percent <n> Max deletion percentage (default: 20)
#   --json                           Output JSON only (no progress messages)
#
# Output: JSON object with sync results

set -euo pipefail

# Default values
SOURCE_DIR=""
TARGET_DIR=""
INCLUDE_PATTERNS=""
EXCLUDE_PATTERNS=""
DRY_RUN=false
DELETION_THRESHOLD=50
DELETION_THRESHOLD_PERCENT=20
JSON_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --source)
      SOURCE_DIR="$2"
      shift 2
      ;;
    --target)
      TARGET_DIR="$2"
      shift 2
      ;;
    --include)
      INCLUDE_PATTERNS="$2"
      shift 2
      ;;
    --exclude)
      EXCLUDE_PATTERNS="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="$2"
      shift 2
      ;;
    --deletion-threshold)
      DELETION_THRESHOLD="$2"
      shift 2
      ;;
    --deletion-threshold-percent)
      DELETION_THRESHOLD_PERCENT="$2"
      shift 2
      ;;
    --json)
      JSON_ONLY=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validation
if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ]; then
  echo '{"success": false, "error": "Source directory is required and must exist"}' | jq .
  exit 1
fi

if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
  echo '{"success": false, "error": "Target directory is required and must exist"}' | jq .
  exit 1
fi

if [ -z "$INCLUDE_PATTERNS" ]; then
  echo '{"success": false, "error": "Include patterns are required"}' | jq .
  exit 1
fi

# Progress message (unless JSON-only mode)
log() {
  if [ "$JSON_ONLY" = false ]; then
    echo "$@" >&2
  fi
}

log "=== Codex Sync Docs Script ==="
log "Source: $SOURCE_DIR"
log "Target: $TARGET_DIR"
log "Include patterns: $INCLUDE_PATTERNS"
log "Exclude patterns: ${EXCLUDE_PATTERNS:-none}"
log "Dry run: $DRY_RUN"

# Convert comma-separated patterns to arrays
IFS=',' read -ra INCLUDE_ARRAY <<< "$INCLUDE_PATTERNS"
IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_PATTERNS"

# Trim whitespace from patterns
for i in "${!INCLUDE_ARRAY[@]}"; do
  INCLUDE_ARRAY[$i]=$(echo "${INCLUDE_ARRAY[$i]}" | xargs)
done
for i in "${!EXCLUDE_ARRAY[@]}"; do
  EXCLUDE_ARRAY[$i]=$(echo "${EXCLUDE_ARRAY[$i]}" | xargs)
done

# Create temporary manifest files
SOURCE_MANIFEST=$(mktemp)
TARGET_MANIFEST=$(mktemp)
SYNC_MANIFEST=$(mktemp)

# Cleanup on exit
cleanup() {
  rm -f "$SOURCE_MANIFEST" "$TARGET_MANIFEST" "$SYNC_MANIFEST"
}
trap cleanup EXIT

# Function to check if file matches exclude patterns
matches_exclude() {
  local file="$1"
  for pattern in "${EXCLUDE_ARRAY[@]}"; do
    # Convert glob to regex-like matching
    if [[ "$file" == $pattern ]]; then
      return 0  # Matches exclude
    fi
  done
  return 1  # Doesn't match exclude
}

# Function to check if file matches any include pattern
matches_include() {
  local file="$1"
  for pattern in "${INCLUDE_ARRAY[@]}"; do
    # Convert glob to regex-like matching
    # **/* matches everything
    if [[ "$pattern" == "**/*" ]] || [[ "$file" == $pattern ]]; then
      return 0  # Matches include
    fi
    # Handle docs/** pattern
    if [[ "$pattern" == *"/**" ]]; then
      local prefix="${pattern%/**}"
      if [[ "$file" == "$prefix/"* ]]; then
        return 0
      fi
    fi
    # Handle specific file patterns
    if [[ "$pattern" == *"*"* ]]; then
      # Use bash glob matching
      if [[ "$file" == $pattern ]]; then
        return 0
      fi
    else
      # Exact match
      if [[ "$file" == "$pattern" ]]; then
        return 0
      fi
    fi
  done
  return 1  # Doesn't match any include
}

log "Scanning source directory..."

# Build source manifest (files matching include patterns, not matching exclude)
cd "$SOURCE_DIR"
> "$SOURCE_MANIFEST"

# Find all files in source
while IFS= read -r -d '' file; do
  # Make path relative
  rel_path="${file#./}"

  # Check if matches include patterns
  if matches_include "$rel_path"; then
    # Check if doesn't match exclude patterns
    if ! matches_exclude "$rel_path"; then
      echo "$rel_path" >> "$SOURCE_MANIFEST"
    fi
  fi
done < <(find . -type f -print0)

SOURCE_FILE_COUNT=$(wc -l < "$SOURCE_MANIFEST")
log "Found $SOURCE_FILE_COUNT files in source matching patterns"

log "Scanning target directory..."

# Build target manifest (files that currently exist in target matching our patterns)
cd "$TARGET_DIR"
> "$TARGET_MANIFEST"

# Find all files in target that match our include patterns
while IFS= read -r -d '' file; do
  rel_path="${file#./}"

  # Check if matches include patterns (files we care about syncing)
  if matches_include "$rel_path"; then
    echo "$rel_path" >> "$TARGET_MANIFEST"
  fi
done < <(find . -type f -print0 2>/dev/null || true)

TARGET_FILE_COUNT=$(wc -l < "$TARGET_MANIFEST")
log "Found $TARGET_FILE_COUNT files in target matching patterns"

# Determine files to add/modify (in source but not in target, or different)
log "Determining changes..."

ADDED_FILES=()
MODIFIED_FILES=()
DELETED_FILES=()

# Check each source file
while IFS= read -r file; do
  if [ -z "$file" ]; then
    continue
  fi

  source_file="$SOURCE_DIR/$file"
  target_file="$TARGET_DIR/$file"

  if [ ! -f "$target_file" ]; then
    # File doesn't exist in target - will be added
    ADDED_FILES+=("$file")
  elif ! cmp -s "$source_file" "$target_file"; then
    # File exists but is different - will be modified
    MODIFIED_FILES+=("$file")
  fi
done < "$SOURCE_MANIFEST"

# Check for deletions (files in target matching patterns but not in source)
while IFS= read -r file; do
  if [ -z "$file" ]; then
    continue
  fi

  if ! grep -Fxq "$file" "$SOURCE_MANIFEST"; then
    # File in target but not in source - will be deleted
    DELETED_FILES+=("$file")
  fi
done < "$TARGET_MANIFEST"

# Calculate counts
ADDED_COUNT=${#ADDED_FILES[@]}
MODIFIED_COUNT=${#MODIFIED_FILES[@]}
DELETED_COUNT=${#DELETED_FILES[@]}
SYNCED_COUNT=$((ADDED_COUNT + MODIFIED_COUNT))

log "Changes detected:"
log "  - Files to add: $ADDED_COUNT"
log "  - Files to modify: $MODIFIED_COUNT"
log "  - Files to delete: $DELETED_COUNT"

# Check deletion thresholds
DELETION_THRESHOLD_EXCEEDED=false
TOTAL_FILES=$((SYNCED_COUNT + DELETED_COUNT))

if [ "$TOTAL_FILES" -gt 0 ]; then
  DELETION_PERCENT=$((DELETED_COUNT * 100 / TOTAL_FILES))
else
  DELETION_PERCENT=0
fi

log "Deletion threshold check:"
log "  - Absolute: $DELETED_COUNT / $DELETION_THRESHOLD"
log "  - Percent: $DELETION_PERCENT% / $DELETION_THRESHOLD_PERCENT%"

if [ "$DELETED_COUNT" -gt "$DELETION_THRESHOLD" ] || [ "$DELETION_PERCENT" -gt "$DELETION_THRESHOLD_PERCENT" ]; then
  DELETION_THRESHOLD_EXCEEDED=true
  log "⚠️  Deletion threshold exceeded!"
  log "This sync would delete $DELETED_COUNT files ($DELETION_PERCENT%)"
  log "Review the deletion list carefully before proceeding."
fi

# Apply changes (unless dry-run or threshold exceeded)
if [ "$DRY_RUN" = "true" ]; then
  log "Dry-run mode: No changes will be applied"
elif [ "$DELETION_THRESHOLD_EXCEEDED" = "true" ]; then
  log "Deletion threshold exceeded: No changes will be applied"
  log "To proceed anyway, increase deletion thresholds in configuration"
else
  log "Applying changes..."

  # Copy added/modified files
  for file in "${ADDED_FILES[@]}" "${MODIFIED_FILES[@]}"; do
    if [ -z "$file" ]; then
      continue
    fi

    source_file="$SOURCE_DIR/$file"
    target_file="$TARGET_DIR/$file"

    # Create parent directory if needed
    mkdir -p "$(dirname "$target_file")"

    # Copy file
    cp "$source_file" "$target_file"
    log "  ✓ Synced: $file"
  done

  # Delete files that no longer exist in source
  for file in "${DELETED_FILES[@]}"; do
    if [ -z "$file" ]; then
      continue
    fi

    target_file="$TARGET_DIR/$file"

    # Remove file
    rm -f "$target_file"
    log "  ✗ Deleted: $file"

    # Clean up empty directories
    dir=$(dirname "$target_file")
    while [ "$dir" != "." ] && [ "$dir" != "$TARGET_DIR" ]; do
      if [ -d "$dir" ] && [ -z "$(ls -A "$dir")" ]; then
        rmdir "$dir" 2>/dev/null || true
        log "  ✗ Removed empty dir: ${dir#$TARGET_DIR/}"
      fi
      dir=$(dirname "$dir")
    done
  done

  log "✅ Sync completed successfully"
fi

# Output JSON results
jq -n \
  --argjson success true \
  --argjson files_synced "$SYNCED_COUNT" \
  --argjson files_added "$ADDED_COUNT" \
  --argjson files_modified "$MODIFIED_COUNT" \
  --argjson files_deleted "$DELETED_COUNT" \
  --argjson deletion_threshold_exceeded "$([ "$DELETION_THRESHOLD_EXCEEDED" = "true" ] && echo true || echo false)" \
  --argjson deletion_count "$DELETED_COUNT" \
  --argjson deletion_threshold "$DELETION_THRESHOLD" \
  --argjson deletion_percent "$DELETION_PERCENT" \
  --argjson deletion_threshold_percent "$DELETION_THRESHOLD_PERCENT" \
  --argjson dry_run "$([ "$DRY_RUN" = "true" ] && echo true || echo false)" \
  --argjson added "$(printf '%s\n' "${ADDED_FILES[@]}" | jq -R . | jq -s .)" \
  --argjson modified "$(printf '%s\n' "${MODIFIED_FILES[@]}" | jq -R . | jq -s .)" \
  --argjson deleted "$(printf '%s\n' "${DELETED_FILES[@]}" | jq -R . | jq -s .)" \
  '{
    success: $success,
    files_synced: $files_synced,
    files_added: $files_added,
    files_modified: $files_modified,
    files_deleted: $files_deleted,
    deletion_threshold_exceeded: $deletion_threshold_exceeded,
    deletion_count: $deletion_count,
    deletion_threshold: $deletion_threshold,
    deletion_percent: $deletion_percent,
    deletion_threshold_percent: $deletion_threshold_percent,
    files: {
      added: $added,
      modified: $modified,
      deleted: $deleted
    },
    dry_run: $dry_run,
    error: null
  }'

exit 0
