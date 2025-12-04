#!/usr/bin/env bash
# Cache management operations for codex plugin
#
# Usage:
#   ./cache-manager.sh get <uri> [--stale-ok]
#   ./cache-manager.sh put <uri> [--content-file <file>] [--source <source>] [--ttl <seconds>]
#   ./cache-manager.sh check <uri>
#   ./cache-manager.sh remove <uri>
#   ./cache-manager.sh list [--org <org>] [--project <project>] [--stale]
#   ./cache-manager.sh stats
#
# Output: JSON with operation result
#
# Environment Variables:
#   CODEX_CACHE_PATH   - Path to cache directory (default: .fractary/plugins/codex/cache)
#   CODEX_CONFIG_PATH  - Path to config file (default: .fractary/plugins/codex/config.json)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cache_path="${CODEX_CACHE_PATH:-.fractary/plugins/codex/cache}"
config_path="${CODEX_CONFIG_PATH:-.fractary/plugins/codex/config.json}"
index_path="$cache_path/.cache-index.json"

# Get default TTL from config or use 7 days
get_default_ttl() {
  if [[ -f "$config_path" ]]; then
    jq -r '.cache.default_ttl // 604800' "$config_path" 2>/dev/null || echo "604800"
  else
    echo "604800"
  fi
}

# Initialize cache index if it doesn't exist
init_index() {
  if [[ ! -f "$index_path" ]]; then
    mkdir -p "$cache_path"
    echo '{
      "version": "3.0",
      "entries": [],
      "stats": {
        "total_entries": 0,
        "total_size_bytes": 0,
        "last_cleanup": null
      }
    }' > "$index_path"
  fi
}

# Check if entry is fresh
is_fresh() {
  local expires_at="$1"
  local now
  now=$(date -u +%s)
  local expires
  expires=$(date -u -d "$expires_at" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null || echo "0")
  [[ "$now" -lt "$expires" ]]
}

# Calculate file hash (md5)
file_hash() {
  local file="$1"
  if command -v md5sum &>/dev/null; then
    md5sum "$file" | cut -d' ' -f1
  elif command -v md5 &>/dev/null; then
    md5 -q "$file"
  else
    echo "unknown"
  fi
}

# URI to cache file path
uri_to_path() {
  local uri="$1"
  local path_part="${uri#codex://}"
  echo "$cache_path/$path_part"
}

# Get entry from index
get_entry() {
  local uri="$1"
  jq -r --arg uri "$uri" '.entries[] | select(.uri == $uri)' "$index_path" 2>/dev/null || echo ""
}

# Check cache freshness for a URI
cmd_check() {
  local uri="$1"
  init_index

  local entry
  entry=$(get_entry "$uri")

  if [[ -z "$entry" ]]; then
    jq -n --arg uri "$uri" '{
      uri: $uri,
      exists: false,
      fresh: false,
      cached_at: null,
      expires_at: null,
      source: null
    }'
    return
  fi

  local expires_at
  expires_at=$(echo "$entry" | jq -r '.expires_at')
  local fresh=false

  if is_fresh "$expires_at"; then
    fresh=true
  fi

  echo "$entry" | jq --argjson fresh "$fresh" '. + {exists: true, fresh: $fresh}'
}

# Get content from cache
cmd_get() {
  local uri="$1"
  local stale_ok="${2:-false}"

  init_index

  local file_path
  file_path=$(uri_to_path "$uri")

  local entry
  entry=$(get_entry "$uri")

  # Check if file exists
  if [[ ! -f "$file_path" ]]; then
    jq -n --arg uri "$uri" '{
      success: false,
      error: "not_found",
      message: "Content not in cache",
      uri: $uri
    }'
    return 1
  fi

  # Check freshness
  if [[ -n "$entry" ]]; then
    local expires_at
    expires_at=$(echo "$entry" | jq -r '.expires_at')
    local fresh=false

    if is_fresh "$expires_at"; then
      fresh=true
    fi

    if [[ "$fresh" != "true" ]] && [[ "$stale_ok" != "true" ]]; then
      # Check config for fallback_to_stale
      local fallback_to_stale="true"
      if [[ -f "$config_path" ]]; then
        fallback_to_stale=$(jq -r '.cache.fallback_to_stale // true' "$config_path" 2>/dev/null || echo "true")
      fi

      if [[ "$fallback_to_stale" != "true" ]]; then
        jq -n --arg uri "$uri" '{
          success: false,
          error: "expired",
          message: "Content expired and fallback_to_stale is disabled",
          uri: $uri
        }'
        return 1
      fi
    fi

    # Update last_accessed
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local tmp_index
    tmp_index=$(mktemp)
    jq --arg uri "$uri" --arg now "$now" \
      '.entries = [.entries[] | if .uri == $uri then .last_accessed = $now else . end]' \
      "$index_path" > "$tmp_index"
    mv "$tmp_index" "$index_path"
  fi

  # Read and return content
  local content
  content=$(cat "$file_path")
  local size
  size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")

  jq -n \
    --arg uri "$uri" \
    --arg content "$content" \
    --argjson size "$size" \
    --argjson entry "$([[ -n "$entry" ]] && echo "$entry" || echo "null")" \
    '{
      success: true,
      uri: $uri,
      content: $content,
      size_bytes: $size,
      metadata: $entry
    }'
}

# Put content into cache
cmd_put() {
  local uri="$1"
  shift

  local content_file=""
  local source="sync"
  local ttl=""
  local synced_via=""

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --content-file)
        content_file="$2"
        shift 2
        ;;
      --source)
        source="$2"
        shift 2
        ;;
      --ttl)
        ttl="$2"
        shift 2
        ;;
      --synced-via)
        synced_via="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  init_index

  # Get content from file or stdin
  local content
  if [[ -n "$content_file" ]] && [[ -f "$content_file" ]]; then
    content=$(cat "$content_file")
  else
    content=$(cat)
  fi

  # Get TTL
  if [[ -z "$ttl" ]]; then
    ttl=$(get_default_ttl)
  fi

  # Calculate paths and metadata
  local file_path
  file_path=$(uri_to_path "$uri")
  local dir_path
  dir_path=$(dirname "$file_path")

  # Create directory structure
  mkdir -p "$dir_path"

  # Write content
  echo "$content" > "$file_path"

  # Calculate metadata
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local expires_at
  expires_at=$(date -u -d "@$(($(date +%s) + ttl))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
               date -u -r "$(($(date +%s) + ttl))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
               echo "$now")
  local size
  size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")
  local hash
  hash=$(file_hash "$file_path")

  # Path relative to cache
  local relative_path="${file_path#$cache_path/}"

  # Create entry
  local new_entry
  new_entry=$(jq -n \
    --arg uri "$uri" \
    --arg path "$relative_path" \
    --arg source "$source" \
    --arg cached_at "$now" \
    --arg expires_at "$expires_at" \
    --argjson ttl "$ttl" \
    --argjson size "$size" \
    --arg hash "$hash" \
    --arg last_accessed "$now" \
    --arg synced_via "$synced_via" \
    '{
      uri: $uri,
      path: $path,
      source: $source,
      cached_at: $cached_at,
      expires_at: $expires_at,
      ttl: $ttl,
      size_bytes: $size,
      hash: $hash,
      last_accessed: $last_accessed,
      synced_via: (if $synced_via == "" then null else $synced_via end)
    }')

  # Update index with file locking to prevent concurrent modification
  local tmp_index
  local lock_file="${index_path}.lock"

  # Acquire exclusive lock (wait up to 30 seconds)
  exec 9>"$lock_file"
  flock -w 30 9 || { echo "Error: Could not acquire cache index lock"; return 1; }

  trap "flock -u 9; rm -f $lock_file" RETURN

  # Update index (remove old entry if exists, add new)
  tmp_index=$(mktemp)
  jq --arg uri "$uri" --argjson entry "$new_entry" '
    .entries = ([.entries[] | select(.uri != $uri)] + [$entry]) |
    .stats.total_entries = (.entries | length) |
    .stats.total_size_bytes = ([.entries[].size_bytes] | add // 0)
  ' "$index_path" > "$tmp_index"
  mv "$tmp_index" "$index_path"

  jq -n \
    --arg uri "$uri" \
    --arg path "$file_path" \
    --argjson size "$size" \
    --arg cached_at "$now" \
    --arg expires_at "$expires_at" \
    '{
      success: true,
      uri: $uri,
      path: $path,
      size_bytes: $size,
      cached_at: $cached_at,
      expires_at: $expires_at
    }'
}

# Remove entry from cache
cmd_remove() {
  local uri="$1"
  init_index

  local file_path
  file_path=$(uri_to_path "$uri")

  # Remove file
  if [[ -f "$file_path" ]]; then
    rm -f "$file_path"
  fi

  # Update index
  local tmp_index
  tmp_index=$(mktemp)
  jq --arg uri "$uri" '
    .entries = [.entries[] | select(.uri != $uri)] |
    .stats.total_entries = (.entries | length) |
    .stats.total_size_bytes = ([.entries[].size_bytes] | add // 0)
  ' "$index_path" > "$tmp_index"
  mv "$tmp_index" "$index_path"

  jq -n --arg uri "$uri" '{success: true, uri: $uri, removed: true}'
}

# List cache entries
cmd_list() {
  local filter_org=""
  local filter_project=""
  local show_stale="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --org)
        filter_org="$2"
        shift 2
        ;;
      --project)
        filter_project="$2"
        shift 2
        ;;
      --stale)
        show_stale="true"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  init_index

  local now
  now=$(date -u +%s)

  jq --arg org "$filter_org" --arg project "$filter_project" --arg show_stale "$show_stale" --argjson now "$now" '
    .entries
    | map(
        . + {
          fresh: ((.expires_at | split("T")[0] + "T" + .expires_at | split("T")[1]) as $exp |
                 ($now < (($exp | gsub("[TZ]"; " ") | split(".")[0]) | strptime("%Y-%m-%d %H:%M:%S") | mktime)))
        }
      )
    | if $org != "" then [.[] | select(.uri | contains($org))] else . end
    | if $project != "" then [.[] | select(.uri | contains($project))] else . end
    | if $show_stale == "true" then [.[] | select(.fresh == false)] else . end
  ' "$index_path" 2>/dev/null || echo "[]"
}

# Get cache stats
cmd_stats() {
  init_index

  local now
  now=$(date -u +%s)

  jq --argjson now "$now" '
    {
      total_entries: .stats.total_entries,
      total_size_bytes: .stats.total_size_bytes,
      total_size_mb: ((.stats.total_size_bytes // 0) / 1048576 | . * 100 | floor / 100),
      fresh_entries: ([.entries[] | select(
        (.expires_at | gsub("[TZ]"; " ") | split(".")[0]) as $exp |
        ($now < (($exp) | strptime("%Y-%m-%d %H:%M:%S") | mktime))
      )] | length),
      stale_entries: ([.entries[] | select(
        (.expires_at | gsub("[TZ]"; " ") | split(".")[0]) as $exp |
        ($now >= (($exp) | strptime("%Y-%m-%d %H:%M:%S") | mktime))
      )] | length),
      last_cleanup: .stats.last_cleanup,
      sources: ([.entries[].source] | group_by(.) | map({(.[0]): length}) | add // {}),
      orgs: ([.entries[].uri | split("/")[0] | gsub("codex://"; "")] | unique)
    }
  ' "$index_path" 2>/dev/null || echo '{"error": "Failed to read cache index"}'
}

# Main dispatcher
command="${1:-help}"
shift || true

case "$command" in
  get)
    uri="${1:-}"
    stale_ok="false"
    if [[ "${2:-}" == "--stale-ok" ]]; then
      stale_ok="true"
    fi
    cmd_get "$uri" "$stale_ok"
    ;;
  put)
    cmd_put "$@"
    ;;
  check)
    cmd_check "${1:-}"
    ;;
  remove)
    cmd_remove "${1:-}"
    ;;
  list)
    cmd_list "$@"
    ;;
  stats)
    cmd_stats
    ;;
  help|--help|-h)
    echo "Usage: cache-manager.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  get <uri> [--stale-ok]        Get content from cache"
    echo "  put <uri> [options]           Store content in cache"
    echo "  check <uri>                   Check cache status for URI"
    echo "  remove <uri>                  Remove entry from cache"
    echo "  list [--org <org>] [--stale]  List cache entries"
    echo "  stats                         Show cache statistics"
    echo ""
    echo "Put options:"
    echo "  --content-file <file>   Read content from file"
    echo "  --source <source>       Source identifier (default: sync)"
    echo "  --ttl <seconds>         Time to live in seconds"
    echo "  --synced-via <method>   Sync method (e.g., sync-project)"
    ;;
  *)
    echo '{"error": "Unknown command: '"$command"'"}' >&2
    exit 1
    ;;
esac
