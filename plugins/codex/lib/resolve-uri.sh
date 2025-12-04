#!/usr/bin/env bash
# Resolve codex:// URIs to filesystem paths and source information
#
# Usage: ./resolve-uri.sh "codex://org/project/path/to/file.md" [--cache-path <path>] [--config-path <path>]
# Output: JSON with resolved path, source type, and metadata
#
# URI Formats:
#   codex://org/project/path       - GitHub org/project format
#   codex://identifier/path        - External source identifier
#
# Environment Variables:
#   CODEX_CACHE_PATH   - Path to cache directory (default: .fractary/plugins/codex/cache)
#   CODEX_CONFIG_PATH  - Path to config file (default: .fractary/plugins/codex/config.json)
#   CODEX_CURRENT_ORG  - Override current organization
#   CODEX_CURRENT_PROJECT - Override current project

set -euo pipefail

uri="${1:-}"
cache_path="${CODEX_CACHE_PATH:-.fractary/plugins/codex/cache}"
config_path="${CODEX_CONFIG_PATH:-.fractary/plugins/codex/config.json}"

# Parse additional arguments
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cache-path)
      cache_path="$2"
      shift 2
      ;;
    --config-path)
      config_path="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate URI format
if [[ -z "$uri" ]]; then
  echo '{"error": "URI is required", "usage": "resolve-uri.sh codex://org/project/path"}' | jq .
  exit 1
fi

if [[ ! "$uri" =~ ^codex:// ]]; then
  echo '{"error": "Invalid URI format. Must start with codex://", "uri": "'"$uri"'"}' | jq .
  exit 1
fi

# Strip codex:// prefix
path_part="${uri#codex://}"

# Parse URI components (org/project/path)
IFS='/' read -ra parts <<< "$path_part"

if [[ ${#parts[@]} -lt 2 ]]; then
  echo '{"error": "URI must have at least org/project", "uri": "'"$uri"'"}' | jq .
  exit 1
fi

org="${parts[0]}"
project="${parts[1]}"
file_path=""

# Join remaining parts as file path
if [[ ${#parts[@]} -gt 2 ]]; then
  file_path=$(IFS='/'; echo "${parts[*]:2}")
fi

# Detect current project
detect_current_project() {
  local current_org=""
  local current_project=""

  # Priority 1: Environment variables
  if [[ -n "${CODEX_CURRENT_ORG:-}" ]] && [[ -n "${CODEX_CURRENT_PROJECT:-}" ]]; then
    current_org="$CODEX_CURRENT_ORG"
    current_project="$CODEX_CURRENT_PROJECT"
  # Priority 2: Config file
  elif [[ -f "$config_path" ]]; then
    current_org=$(jq -r '.organization // empty' "$config_path" 2>/dev/null || true)
    current_project=$(jq -r '.project_name // empty' "$config_path" 2>/dev/null || true)

    # If project_name not in config, try to detect from git
    if [[ -z "$current_project" ]]; then
      current_project=$(detect_from_git "project")
    fi
    if [[ -z "$current_org" ]]; then
      current_org=$(detect_from_git "org")
    fi
  # Priority 3: Git remote
  else
    current_org=$(detect_from_git "org")
    current_project=$(detect_from_git "project")
  fi

  echo "$current_org|$current_project"
}

# Detect org/project from git remote
detect_from_git() {
  local what="$1"
  local remote_url=""

  remote_url=$(git remote get-url origin 2>/dev/null || true)

  if [[ -z "$remote_url" ]]; then
    return
  fi

  # Parse different remote URL formats
  # https://github.com/org/repo.git
  # git@github.com:org/repo.git
  local parsed=""

  if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
    if [[ "$what" == "org" ]]; then
      parsed="${BASH_REMATCH[1]}"
    else
      parsed="${BASH_REMATCH[2]}"
      parsed="${parsed%.git}"
    fi
  fi

  echo "$parsed"
}

# Get source configuration for org/project
get_source_config() {
  local source_org="$1"

  if [[ ! -f "$config_path" ]]; then
    # Default to github-org type
    echo '{"type": "github-org", "ttl": 604800}'
    return
  fi

  # Check if org has specific source config
  local source_config
  source_config=$(jq -r ".sources[\"$source_org\"] // empty" "$config_path" 2>/dev/null || true)

  if [[ -n "$source_config" ]]; then
    echo "$source_config"
  else
    # Return defaults
    local default_ttl
    default_ttl=$(jq -r '.cache.default_ttl // 604800' "$config_path" 2>/dev/null || echo "604800")
    echo "{\"type\": \"github-org\", \"ttl\": $default_ttl}"
  fi
}

# Resolve the URI
current_info=$(detect_current_project)
current_org="${current_info%%|*}"
current_project="${current_info##*|}"

is_current_project=false
if [[ "$org" == "$current_org" ]] && [[ "$project" == "$current_project" ]]; then
  is_current_project=true
fi

# Determine resolution type and path
source_config=$(get_source_config "$org")
source_type=$(echo "$source_config" | jq -r '.type // "github-org"')
ttl=$(echo "$source_config" | jq -r '.ttl // 604800')

# Build cache path
cache_file_path="$cache_path/$org/$project"
if [[ -n "$file_path" ]]; then
  cache_file_path="$cache_file_path/$file_path"
fi

# Build local path (for current project)
local_file_path=""
if [[ "$is_current_project" == "true" ]] && [[ -n "$file_path" ]]; then
  local_file_path="$file_path"
fi

# Determine resolution strategy
resolution_type="cache"  # Default: resolve from cache
if [[ "$is_current_project" == "true" ]] && [[ -n "$file_path" ]] && [[ -f "$file_path" ]]; then
  resolution_type="local"  # File exists in current project
fi

# Output JSON result
jq -n \
  --arg uri "$uri" \
  --arg org "$org" \
  --arg project "$project" \
  --arg file_path "$file_path" \
  --arg source_type "$source_type" \
  --argjson ttl "$ttl" \
  --arg cache_path "$cache_file_path" \
  --arg local_path "$local_file_path" \
  --arg resolution_type "$resolution_type" \
  --argjson is_current_project "$is_current_project" \
  --arg current_org "$current_org" \
  --arg current_project "$current_project" \
  '{
    uri: $uri,
    parsed: {
      org: $org,
      project: $project,
      path: $file_path
    },
    source: {
      type: $source_type,
      ttl: $ttl
    },
    resolution: {
      type: $resolution_type,
      cache_path: $cache_path,
      local_path: (if $local_path == "" then null else $local_path end)
    },
    context: {
      is_current_project: $is_current_project,
      current_org: (if $current_org == "" then null else $current_org end),
      current_project: (if $current_project == "" then null else $current_project end)
    }
  }'
