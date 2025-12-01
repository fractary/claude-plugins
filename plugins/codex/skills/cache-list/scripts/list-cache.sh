#!/usr/bin/env bash
# List cache entries with filtering and sorting
#
# Usage: ./list-cache.sh [--expired] [--fresh] [--project <name>] [--sort <field>]
# Output: JSON array of cache entries

set -euo pipefail

index_file="codex/.cache-index.json"

# Parse arguments
show_expired=false
show_fresh=false
project_filter=""
sort_field="cached_at"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expired)
      show_expired=true
      shift
      ;;
    --fresh)
      show_fresh=true
      shift
      ;;
    --project)
      project_filter="$2"
      shift 2
      ;;
    --sort)
      sort_field="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Check if index exists
if [[ ! -f "$index_file" ]]; then
  cat <<'EOF'
{
  "stats": {
    "total_entries": 0,
    "total_size_bytes": 0,
    "fresh_count": 0,
    "expired_count": 0
  },
  "entries": []
}
EOF
  exit 0
fi

# Get current timestamp
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build jq filter based on arguments
jq_filter='.entries'

# Filter by project if specified
if [[ -n "$project_filter" ]]; then
  jq_filter="$jq_filter | map(select(.reference | startswith(\"@codex/$project_filter/\")))"
fi

# Filter by freshness
if [[ "$show_expired" == true && "$show_fresh" == false ]]; then
  jq_filter="$jq_filter | map(select(.expires_at < \"$now\"))"
elif [[ "$show_fresh" == true && "$show_expired" == false ]]; then
  jq_filter="$jq_filter | map(select(.expires_at >= \"$now\"))"
fi

# Add freshness status to each entry
jq_filter="$jq_filter | map(. + {fresh: (.expires_at >= \"$now\")})"

# Sort by field
case "$sort_field" in
  size|size_bytes)
    jq_filter="$jq_filter | sort_by(.size_bytes) | reverse"
    ;;
  cached_at)
    jq_filter="$jq_filter | sort_by(.cached_at) | reverse"
    ;;
  expires_at)
    jq_filter="$jq_filter | sort_by(.expires_at)"
    ;;
  last_accessed)
    jq_filter="$jq_filter | sort_by(.last_accessed) | reverse"
    ;;
esac

# Execute filter and build output
filtered_entries=$(jq "$jq_filter" "$index_file")

# Calculate stats
fresh_count=$(echo "$filtered_entries" | jq '[.[] | select(.fresh == true)] | length')
expired_count=$(echo "$filtered_entries" | jq '[.[] | select(.fresh == false)] | length')
total_size=$(echo "$filtered_entries" | jq '[.[].size_bytes] | add // 0')
total_entries=$(echo "$filtered_entries" | jq 'length')

# Get last cleanup time from index (preserve JSON format with quotes)
last_cleanup=$(jq '.stats.last_cleanup // null' "$index_file")

# Output structured JSON
cat <<EOF
{
  "stats": {
    "total_entries": $total_entries,
    "total_size_bytes": $total_size,
    "fresh_count": $fresh_count,
    "expired_count": $expired_count,
    "last_cleanup": $last_cleanup
  },
  "entries": $filtered_entries
}
EOF
