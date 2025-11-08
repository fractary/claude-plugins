#!/usr/bin/env bash
# Clear cache entries based on filters
#
# Usage: ./clear-cache.sh [--all] [--expired] [--project <name>] [--pattern <glob>] [--dry-run]
# Output: JSON with deletion results

set -euo pipefail

index_file="codex/.cache-index.json"

# Parse arguments
scope=""
project_filter=""
pattern_filter=""
dry_run=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      scope="all"
      shift
      ;;
    --expired)
      scope="expired"
      shift
      ;;
    --project)
      scope="project"
      project_filter="$2"
      shift 2
      ;;
    --pattern)
      scope="pattern"
      pattern_filter="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate scope specified
if [[ -z "$scope" ]]; then
  cat >&2 <<'EOF'
{
  "error": "Scope required",
  "usage": "Specify one of: --all, --expired, --project <name>, --pattern <glob>"
}
EOF
  exit 1
fi

# Check if index exists
if [[ ! -f "$index_file" ]]; then
  cat <<'EOF'
{
  "deleted_count": 0,
  "deleted_size_bytes": 0,
  "deleted_entries": [],
  "message": "Cache index does not exist (cache is empty)"
}
EOF
  exit 0
fi

# Get current timestamp
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build jq filter to select entries to delete
case "$scope" in
  all)
    jq_filter='.entries'
    ;;
  expired)
    jq_filter=".entries | map(select(.expires_at < \"$now\"))"
    ;;
  project)
    jq_filter=".entries | map(select(.reference | startswith(\"@codex/$project_filter/\")))"
    ;;
  pattern)
    # Convert glob pattern to regex (basic conversion)
    # This is a simple conversion - for complex patterns use a more robust solution
    regex_pattern="${pattern_filter//\*/.*}"
    jq_filter=".entries | map(select(.reference | test(\"$regex_pattern\")))"
    ;;
esac

# Get entries to delete
entries_to_delete=$(jq -c "$jq_filter" "$index_file")
delete_count=$(echo "$entries_to_delete" | jq 'length')

# If nothing to delete
if [[ "$delete_count" -eq 0 ]]; then
  cat <<EOF
{
  "deleted_count": 0,
  "deleted_size_bytes": 0,
  "deleted_entries": [],
  "message": "No entries matched the filter"
}
EOF
  exit 0
fi

# Calculate total size to delete
total_size=$(echo "$entries_to_delete" | jq '[.[].size_bytes] | add // 0')

# If dry-run, just report what would be deleted
if [[ "$dry_run" == true ]]; then
  cat <<EOF
{
  "dry_run": true,
  "would_delete_count": $delete_count,
  "would_delete_size_bytes": $total_size,
  "entries": $entries_to_delete
}
EOF
  exit 0
fi

# Actually delete files and update index
deleted_refs=()
deleted_paths=()

while IFS= read -r entry; do
  reference=$(echo "$entry" | jq -r '.reference')
  path=$(echo "$entry" | jq -r '.path')
  full_path="codex/$path"

  # Delete file if it exists
  if [[ -f "$full_path" ]]; then
    rm -f "$full_path"
    deleted_paths+=("$full_path")
  fi

  deleted_refs+=("$reference")
done < <(echo "$entries_to_delete" | jq -c '.[]')

# Update index to remove deleted entries
jq --argjson refs "$(printf '%s\n' "${deleted_refs[@]}" | jq -R . | jq -s .)" '
  .entries |= map(select(.reference as $ref | $refs | index($ref) | not)) |
  .stats.total_entries = (.entries | length) |
  .stats.total_size_bytes = ([.entries[].size_bytes] | add // 0) |
  .stats.last_cleanup = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
' "$index_file" > "${index_file}.tmp"

# Atomic update
mv "${index_file}.tmp" "$index_file"

# Output results
cat <<EOF
{
  "deleted_count": $delete_count,
  "deleted_size_bytes": $total_size,
  "deleted_entries": $entries_to_delete
}
EOF
