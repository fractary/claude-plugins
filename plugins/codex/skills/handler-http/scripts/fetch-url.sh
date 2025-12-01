#!/usr/bin/env bash
# Fetch content from HTTP/HTTPS URL with safety checks
#
# Usage: ./fetch-url.sh <url> [timeout] [max_size_mb]
# Output: Content to stdout, metadata to stderr as JSON

set -euo pipefail

url="${1:-}"
timeout="${2:-30}"
max_size_mb="${3:-10}"

# Validate inputs
if [[ -z "$url" ]]; then
  cat >&2 <<'EOF'
{
  "error": "URL required",
  "usage": "./fetch-url.sh <url> [timeout] [max_size_mb]"
}
EOF
  exit 1
fi

# Validate URL protocol
if [[ ! "$url" =~ ^https?:// ]]; then
  cat >&2 <<EOF
{
  "error": "Invalid protocol",
  "message": "Only http:// and https:// protocols are allowed",
  "url": "$url"
}
EOF
  exit 1
fi

# Calculate max size in bytes
max_size_bytes=$((max_size_mb * 1024 * 1024))

# Create temp file for response
temp_file=$(mktemp)
temp_headers=$(mktemp)
trap "rm -f $temp_file $temp_headers" EXIT

# Fetch URL with curl
# -L: Follow redirects (max 5)
# -s: Silent mode
# -S: Show errors
# -m: Timeout
# --max-filesize: Size limit
# -w: Write out metadata
# -D: Dump headers

http_code=$(curl -L -s -S \
  -m "$timeout" \
  --max-filesize "$max_size_bytes" \
  -w "%{http_code}" \
  -D "$temp_headers" \
  -o "$temp_file" \
  "$url" 2>&1 | tail -1 || echo "000")

# Check HTTP status code
if [[ "$http_code" -lt 200 ]] || [[ "$http_code" -ge 300 ]]; then
  case "$http_code" in
    000)
      error_msg="Connection failed or timeout"
      ;;
    404)
      error_msg="Not found"
      ;;
    403)
      error_msg="Access denied"
      ;;
    500|502|503|504)
      error_msg="Server error"
      ;;
    *)
      error_msg="HTTP error"
      ;;
  esac

  cat >&2 <<EOF
{
  "error": "$error_msg",
  "http_code": $http_code,
  "url": "$url"
}
EOF
  exit 1
fi

# Extract metadata from headers
content_type=$(grep -i "^content-type:" "$temp_headers" | tail -1 | cut -d: -f2- | tr -d '\r' | xargs || echo "application/octet-stream")
content_length=$(grep -i "^content-length:" "$temp_headers" | tail -1 | cut -d: -f2- | tr -d '\r' | xargs || echo "0")
last_modified=$(grep -i "^last-modified:" "$temp_headers" | tail -1 | cut -d: -f2- | tr -d '\r' | xargs || echo "")
etag=$(grep -i "^etag:" "$temp_headers" | tail -1 | cut -d: -f2- | tr -d '\r' | xargs || echo "")

# Get final URL (after redirects)
final_url=$(grep -i "^location:" "$temp_headers" | tail -1 | cut -d: -f2- | tr -d '\r' | xargs || echo "$url")

# Output metadata to stderr
cat >&2 <<EOF
{
  "success": true,
  "http_code": $http_code,
  "content_type": "$content_type",
  "content_length": $content_length,
  "last_modified": "$last_modified",
  "etag": "$etag",
  "url": "$url",
  "final_url": "$final_url"
}
EOF

# Output content to stdout
cat "$temp_file"
