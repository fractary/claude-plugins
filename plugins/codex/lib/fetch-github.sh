#!/usr/bin/env bash
# Fetch content from GitHub with authentication cascade
#
# Usage: ./fetch-github.sh <org> <project> <path> [options]
# Output: JSON with content and metadata
#
# Authentication Cascade (in order of priority):
#   1. Source-specific token from codex config (sources.<org>.token_env)
#   2. GITHUB_TOKEN environment variable
#   3. Git credential helper
#   4. Public/unauthenticated access (if fallback_to_public is enabled)
#
# Environment Variables:
#   CODEX_CONFIG_PATH  - Path to config file (default: .fractary/plugins/codex/config.json)
#   GITHUB_TOKEN       - GitHub personal access token
#
# Options:
#   --branch <branch>    Target branch (default: main)
#   --raw                Output raw content only (no JSON wrapper)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_path="${CODEX_CONFIG_PATH:-.fractary/plugins/codex/config.json}"

# Arguments
org="${1:-}"
project="${2:-}"
path="${3:-}"
shift 3 || true

# Options
branch="main"
raw_mode="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      branch="$2"
      shift 2
      ;;
    --raw)
      raw_mode="true"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Validate inputs
if [[ -z "$org" ]] || [[ -z "$project" ]] || [[ -z "$path" ]]; then
  jq -n '{
    success: false,
    error: "missing_arguments",
    message: "Usage: fetch-github.sh <org> <project> <path> [--branch <branch>]"
  }'
  exit 1
fi

# Get token from authentication cascade
get_token() {
  local token=""

  # Priority 1: Source-specific token from config
  if [[ -f "$config_path" ]]; then
    local token_env
    token_env=$(jq -r ".sources[\"$org\"].token_env // empty" "$config_path" 2>/dev/null || true)

    if [[ -n "$token_env" ]]; then
      token="${!token_env:-}"
    fi

    # Check for direct token (with env var expansion)
    if [[ -z "$token" ]]; then
      local direct_token
      direct_token=$(jq -r ".sources[\"$org\"].token // empty" "$config_path" 2>/dev/null || true)

      if [[ -n "$direct_token" ]] && [[ "$direct_token" =~ ^\$\{(.+)\}$ ]]; then
        local env_name="${BASH_REMATCH[1]}"
        token="${!env_name:-}"
      elif [[ -n "$direct_token" ]]; then
        token="$direct_token"
      fi
    fi
  fi

  # Priority 2: GITHUB_TOKEN environment variable
  if [[ -z "$token" ]]; then
    token="${GITHUB_TOKEN:-}"
  fi

  # Priority 3: Git credential helper
  if [[ -z "$token" ]]; then
    token=$(git credential fill <<EOF 2>/dev/null | grep "^password=" | cut -d= -f2 || true
protocol=https
host=github.com
EOF
    )
  fi

  echo "$token"
}

# Check if public fallback is enabled
public_fallback_enabled() {
  if [[ -f "$config_path" ]]; then
    local fallback
    fallback=$(jq -r '.auth.fallback_to_public // true' "$config_path" 2>/dev/null || echo "true")
    [[ "$fallback" == "true" ]]
  else
    true  # Default to enabled
  fi
}

# Build GitHub raw content URL
raw_url="https://raw.githubusercontent.com/$org/$project/$branch/$path"

# Get auth token
token=$(get_token)

# Prepare curl options
curl_opts=(-s -f -L --max-time 30)

if [[ -n "$token" ]]; then
  curl_opts+=(-H "Authorization: token $token")
fi

# Attempt to fetch
http_code=""
content=""
error_msg=""

# Try authenticated request first
if response=$(curl "${curl_opts[@]}" -w "\n%{http_code}" "$raw_url" 2>&1); then
  http_code="${response##*$'\n'}"
  content="${response%$'\n'*}"
else
  # If curl failed, try to extract error
  error_msg="$response"
  http_code=$(echo "$response" | grep -oE 'HTTP/[0-9.]+ [0-9]+' | tail -1 | grep -oE '[0-9]+$' || echo "0")

  # If we had auth and failed, try without auth (public fallback)
  if [[ -n "$token" ]] && public_fallback_enabled; then
    curl_opts_public=(-s -f -L --max-time 30)
    if response=$(curl "${curl_opts_public[@]}" -w "\n%{http_code}" "$raw_url" 2>&1); then
      http_code="${response##*$'\n'}"
      content="${response%$'\n'*}"
      error_msg=""
    fi
  fi
fi

# Handle results
if [[ -n "$content" ]] && [[ -z "$error_msg" ]]; then
  if [[ "$raw_mode" == "true" ]]; then
    echo "$content"
  else
    # Calculate size
    size=${#content}

    jq -n \
      --arg content "$content" \
      --arg org "$org" \
      --arg project "$project" \
      --arg path "$path" \
      --arg branch "$branch" \
      --arg url "$raw_url" \
      --argjson size "$size" \
      --arg fetched_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        success: true,
        content: $content,
        metadata: {
          org: $org,
          project: $project,
          path: $path,
          branch: $branch,
          url: $url,
          size_bytes: $size,
          fetched_at: $fetched_at
        }
      }'
  fi
else
  # Determine error type
  local error_type="fetch_failed"
  local message="Failed to fetch from GitHub"

  case "$http_code" in
    401|403)
      error_type="auth_failed"
      message="Authentication failed. Check your GitHub token."
      ;;
    404)
      error_type="not_found"
      message="File not found: $org/$project/$path (branch: $branch)"
      ;;
    0)
      error_type="network_error"
      message="Network error or timeout"
      ;;
  esac

  jq -n \
    --arg error "$error_type" \
    --arg message "$message" \
    --arg org "$org" \
    --arg project "$project" \
    --arg path "$path" \
    --arg branch "$branch" \
    --arg url "$raw_url" \
    --arg http_code "$http_code" \
    --arg details "$error_msg" \
    '{
      success: false,
      error: $error,
      message: $message,
      details: {
        org: $org,
        project: $project,
        path: $path,
        branch: $branch,
        url: $url,
        http_code: $http_code,
        raw_error: (if $details == "" then null else $details end)
      }
    }'
  exit 1
fi
