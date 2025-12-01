#!/usr/bin/env bash
# Check if requesting project has permission to access document
#
# Usage: ./check-permissions.sh "<frontmatter_json>" "<requesting_project>"
# Output: JSON with allowed status and reason

set -euo pipefail

frontmatter_json="${1:-}"
requesting_project="${2:-}"

# Validate inputs
if [[ -z "$frontmatter_json" ]] || [[ -z "$requesting_project" ]]; then
  cat >&2 <<'EOF'
{
  "error": "Missing required arguments",
  "usage": "./check-permissions.sh <frontmatter_json> <requesting_project>"
}
EOF
  exit 1
fi

# Pattern matching function
match_pattern() {
  local value="$1"
  local pattern="$2"

  # Handle exact match
  if [[ "$value" == "$pattern" ]]; then
    return 0
  fi

  # Handle wildcard patterns
  # Convert glob pattern to regex
  # * matches any characters
  local regex=$(echo "$pattern" | sed 's/\*/.*/' | sed 's/\?/./')

  if [[ "$value" =~ ^${regex}$ ]]; then
    return 0  # Match
  else
    return 1  # No match
  fi
}

# Extract permission arrays from frontmatter
# Default to ["*"] (public) if codex_sync_include not specified
include_list=$(echo "$frontmatter_json" | jq -r '.codex_sync_include // ["*"]' 2>/dev/null || echo '["*"]')
exclude_list=$(echo "$frontmatter_json" | jq -r '.codex_sync_exclude // []' 2>/dev/null || echo '[]')

# Check if include list is ["*"] (public access)
if echo "$include_list" | jq -e '. == ["*"]' >/dev/null 2>&1; then
  # Check exclude list even for public access
  while IFS= read -r pattern; do
    if [[ -n "$pattern" ]] && match_pattern "$requesting_project" "$pattern"; then
      cat <<EOF
{
  "allowed": false,
  "reason": "Excluded by pattern: $pattern",
  "matched_pattern": "$pattern"
}
EOF
      exit 0
    fi
  done < <(echo "$exclude_list" | jq -r '.[]' 2>/dev/null || true)

  # Not excluded, allow access
  cat <<'EOF'
{
  "allowed": true,
  "reason": "public",
  "matched_pattern": "*"
}
EOF
  exit 0
fi

# Check exclude list first (takes precedence)
while IFS= read -r pattern; do
  if [[ -n "$pattern" ]] && match_pattern "$requesting_project" "$pattern"; then
    cat <<EOF
{
  "allowed": false,
  "reason": "Excluded by pattern: $pattern",
  "matched_pattern": "$pattern"
}
EOF
    exit 0
  fi
done < <(echo "$exclude_list" | jq -r '.[]' 2>/dev/null || true)

# Check include list
while IFS= read -r pattern; do
  if [[ -n "$pattern" ]] && match_pattern "$requesting_project" "$pattern"; then
    cat <<EOF
{
  "allowed": true,
  "reason": "Matched include pattern",
  "matched_pattern": "$pattern"
}
EOF
    exit 0
  fi
done < <(echo "$include_list" | jq -r '.[]' 2>/dev/null || true)

# Not in include list - deny access
cat <<EOF
{
  "allowed": false,
  "reason": "Project not in codex_sync_include list",
  "include_list": $include_list
}
EOF
