#!/usr/bin/env bash
# Check cache for document and verify TTL
#
# Usage: ./cache-lookup.sh "codex/project-name/path/to/file.md"
# Output: JSON with cache status

set -euo pipefail

cache_path="${1:-}"
index_file="codex/.cache-index.json"

# Validate input
if [[ -z "$cache_path" ]]; then
  echo '{"error": "Cache path argument required"}' >&2
  exit 1
fi

# Check if cache file exists
if [[ ! -f "$cache_path" ]]; then
  echo '{"cached": false, "fresh": false, "reason": "not_in_cache"}'
  exit 0
fi

# Check if index exists
if [[ ! -f "$index_file" ]]; then
  echo '{"cached": false, "fresh": false, "reason": "index_missing"}'
  exit 0
fi

# Look up entry in index (normalize path to remove leading codex/)
normalized_path="${cache_path#codex/}"

entry=$(jq --arg path "$normalized_path" \
  '.entries[] | select(.path == $path)' \
  "$index_file" 2>/dev/null || echo "")

if [[ -z "$entry" ]]; then
  echo '{"cached": true, "fresh": false, "reason": "not_in_index"}'
  exit 0
fi

# Check TTL
expires_at=$(echo "$entry" | jq -r '.expires_at')
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ "$expires_at" < "$now" ]]; then
  cached_at=$(echo "$entry" | jq -r '.cached_at')
  cat <<EOF
{
  "cached": true,
  "fresh": false,
  "reason": "expired",
  "cached_at": "$cached_at",
  "expires_at": "$expires_at"
}
EOF
  exit 0
fi

# Cache hit - fresh
cached_at=$(echo "$entry" | jq -r '.cached_at')
source=$(echo "$entry" | jq -r '.source')
size_bytes=$(echo "$entry" | jq -r '.size_bytes')

cat <<EOF
{
  "cached": true,
  "fresh": true,
  "reason": "valid",
  "cached_at": "$cached_at",
  "expires_at": "$expires_at",
  "source": "$source",
  "size_bytes": $size_bytes
}
EOF
