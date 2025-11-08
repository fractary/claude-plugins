#!/usr/bin/env bash
# Store document in cache and update index
#
# Usage: ./cache-store.sh "@codex/ref" "codex/path" "content" [ttl_days]
# Output: JSON with success status

set -euo pipefail

reference="${1:-}"
cache_path="${2:-}"
content="${3:-}"
ttl_days="${4:-7}"

index_file="codex/.cache-index.json"

# Validate inputs
if [[ -z "$reference" ]] || [[ -z "$cache_path" ]]; then
  echo '{"error": "Reference and cache_path required"}' >&2
  exit 1
fi

# Create codex directory if it doesn't exist
mkdir -p "$(dirname "$cache_path")"

# Create index file if it doesn't exist
if [[ ! -f "$index_file" ]]; then
  mkdir -p "$(dirname "$index_file")"
  cat > "$index_file" <<'EOF'
{
  "version": "1.0",
  "entries": [],
  "stats": {
    "total_entries": 0,
    "total_size_bytes": 0,
    "last_cleanup": null
  }
}
EOF
fi

# Write content to cache file
if [[ -n "$content" ]]; then
  echo "$content" > "$cache_path"
else
  # Content comes from stdin
  cat > "$cache_path"
fi

# Calculate metadata
size_bytes=$(wc -c < "$cache_path" | tr -d ' ')
hash=$(sha256sum "$cache_path" | cut -d' ' -f1)
cached_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Calculate expiration date (handle both Linux and macOS date command)
if date --version >/dev/null 2>&1; then
  # GNU date (Linux)
  expires_at=$(date -u -d "+${ttl_days} days" +"%Y-%m-%dT%H:%M:%SZ")
else
  # BSD date (macOS)
  expires_at=$(date -u -v+${ttl_days}d +"%Y-%m-%dT%H:%M:%SZ")
fi

# Normalize path (remove leading codex/)
normalized_path="${cache_path#codex/}"

# Remove existing entry and add new one
jq --arg ref "$reference" \
   --arg path "$normalized_path" \
   --arg cached "$cached_at" \
   --arg expires "$expires_at" \
   --argjson ttl "$ttl_days" \
   --argjson size "$size_bytes" \
   --arg hash "$hash" \
  '
  # Remove existing entry with same reference
  .entries |= map(select(.reference != $ref)) |
  # Add new entry
  .entries += [{
    reference: $ref,
    path: $path,
    source: "fractary-codex",
    cached_at: $cached,
    expires_at: $expires,
    ttl_days: $ttl,
    size_bytes: $size,
    hash: $hash,
    last_accessed: $cached
  }] |
  # Update stats
  .stats.total_entries = (.entries | length) |
  .stats.total_size_bytes = ([.entries[].size_bytes] | add // 0)
  ' "$index_file" > "${index_file}.tmp"

# Atomic update
mv "${index_file}.tmp" "$index_file"

# Output success
cat <<EOF
{
  "success": true,
  "reference": "$reference",
  "cache_path": "$cache_path",
  "size_bytes": $size_bytes,
  "cached_at": "$cached_at",
  "expires_at": "$expires_at",
  "ttl_days": $ttl_days
}
EOF
