#!/usr/bin/env bash
# Fetch content from HTTP/HTTPS URLs
#
# Usage: ./fetch-http.sh <url> [options]
# Output: JSON with content and metadata
#
# Options:
#   --raw                Output raw content only (no JSON wrapper)
#   --headers <json>     Additional headers as JSON object
#   --timeout <seconds>  Request timeout (default: 30)
#   --user-agent <ua>    Custom user agent string
#
# Environment Variables:
#   CODEX_CONFIG_PATH  - Path to config file (default: .fractary/plugins/codex/config.json)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_path="${CODEX_CONFIG_PATH:-.fractary/plugins/codex/config.json}"

# Arguments
url="${1:-}"
shift || true

# Options
raw_mode="false"
headers=""
timeout=30
user_agent="Fractary-Codex/1.0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --raw)
      raw_mode="true"
      shift
      ;;
    --headers)
      headers="$2"
      shift 2
      ;;
    --timeout)
      timeout="$2"
      shift 2
      ;;
    --user-agent)
      user_agent="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Validate inputs
if [[ -z "$url" ]]; then
  jq -n '{
    success: false,
    error: "missing_url",
    message: "Usage: fetch-http.sh <url> [options]"
  }'
  exit 1
fi

# Validate URL format
if [[ ! "$url" =~ ^https?:// ]]; then
  jq -n --arg url "$url" '{
    success: false,
    error: "invalid_url",
    message: "URL must start with http:// or https://",
    url: $url
  }'
  exit 1
fi

# Build curl options
curl_opts=(-s -f -L --max-time "$timeout" -A "$user_agent")

# Add custom headers if provided
if [[ -n "$headers" ]]; then
  while IFS='=' read -r key value; do
    if [[ -n "$key" ]]; then
      curl_opts+=(-H "$key: $value")
    fi
  done < <(echo "$headers" | jq -r 'to_entries[] | "\(.key)=\(.value)"' 2>/dev/null || true)
fi

# Attempt to fetch
http_code=""
content=""
error_msg=""
content_type=""

# Fetch with headers
if response=$(curl "${curl_opts[@]}" -w "\n%{http_code}\n%{content_type}" "$url" 2>&1); then
  # Parse response parts
  content_type=$(echo "$response" | tail -1)
  http_code=$(echo "$response" | tail -2 | head -1)
  content=$(echo "$response" | head -n -2)
else
  error_msg="$response"
  http_code="0"
fi

# Handle results
if [[ -n "$content" ]] && [[ "$http_code" =~ ^2 ]]; then
  if [[ "$raw_mode" == "true" ]]; then
    echo "$content"
  else
    # Calculate size
    size=${#content}

    # Extract domain for metadata
    domain=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|')

    jq -n \
      --arg content "$content" \
      --arg url "$url" \
      --arg domain "$domain" \
      --arg content_type "$content_type" \
      --argjson size "$size" \
      --arg fetched_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        success: true,
        content: $content,
        metadata: {
          url: $url,
          domain: $domain,
          content_type: $content_type,
          size_bytes: $size,
          fetched_at: $fetched_at
        }
      }'
  fi
else
  # Determine error type
  local error_type="fetch_failed"
  local message="Failed to fetch URL"

  case "$http_code" in
    401|403)
      error_type="auth_required"
      message="Authentication required or forbidden"
      ;;
    404)
      error_type="not_found"
      message="URL not found"
      ;;
    429)
      error_type="rate_limited"
      message="Rate limited. Try again later."
      ;;
    5*)
      error_type="server_error"
      message="Server error"
      ;;
    0)
      error_type="network_error"
      message="Network error or timeout"
      ;;
  esac

  jq -n \
    --arg error "$error_type" \
    --arg message "$message" \
    --arg url "$url" \
    --arg http_code "$http_code" \
    --arg details "$error_msg" \
    '{
      success: false,
      error: $error,
      message: $message,
      details: {
        url: $url,
        http_code: $http_code,
        raw_error: (if $details == "" then null else $details end)
      }
    }'
  exit 1
fi
