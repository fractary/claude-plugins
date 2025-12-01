#!/usr/bin/env bash
# Route reference to appropriate source and handler
#
# Usage: ./route-source.sh "<reference>" "<config_file>"
# Output: JSON with source configuration and handler to use

set -euo pipefail

reference="${1:-}"
config_file="${2:-.fractary/plugins/codex/config.json}"

# Validate inputs
if [[ -z "$reference" ]]; then
  cat >&2 <<'EOF'
{
  "error": "Reference required",
  "usage": "./route-source.sh <reference> [config_file]"
}
EOF
  exit 1
fi

# Check if config file exists
if [[ ! -f "$config_file" ]]; then
  cat >&2 <<EOF
{
  "error": "Configuration file not found",
  "path": "$config_file",
  "suggestion": "Run /fractary-codex:init to create configuration"
}
EOF
  exit 1
fi

# Determine reference type
if [[ "$reference" =~ ^@codex/ ]]; then
  ref_type="codex"
  # Extract project from reference
  project=$(echo "$reference" | sed 's|^@codex/||' | cut -d'/' -f1)
elif [[ "$reference" =~ ^https?:// ]]; then
  ref_type="url"
else
  cat >&2 <<EOF
{
  "error": "Invalid reference format",
  "reference": "$reference",
  "expected": "@codex/{project}/{path} or https://..."
}
EOF
  exit 1
fi

# Load sources from configuration
sources=$(jq -r '.sources // []' "$config_file")

# Check if sources exist
source_count=$(echo "$sources" | jq 'length')
if [[ "$source_count" -eq 0 ]]; then
  # Fallback to legacy configuration (codex_repo + organization)
  org=$(jq -r '.organization // ""' "$config_file")
  codex_repo=$(jq -r '.codex_repo // ""' "$config_file")

  if [[ -n "$org" ]] && [[ -n "$codex_repo" ]]; then
    # Create default source from legacy config
    cat <<EOF
{
  "source": {
    "name": "fractary-codex",
    "type": "codex",
    "handler": "github",
    "handler_config": {
      "org": "$org",
      "repo": "$codex_repo",
      "branch": "main",
      "base_path": "projects"
    },
    "cache": {
      "ttl_days": 7
    },
    "permissions": {
      "enabled": false,
      "default": "allow"
    }
  },
  "handler": "github",
  "reference_type": "$ref_type"
}
EOF
    exit 0
  fi

  cat >&2 <<EOF
{
  "error": "No sources configured",
  "config_file": "$config_file",
  "suggestion": "Add sources array to configuration"
}
EOF
  exit 1
fi

# Route based on reference type
if [[ "$ref_type" == "codex" ]]; then
  # Find source with type="codex"
  source=$(echo "$sources" | jq '.[0] | select(.type == "codex")')

  if [[ -z "$source" ]] || [[ "$source" == "null" ]]; then
    cat >&2 <<'EOF'
{
  "error": "No codex source configured",
  "suggestion": "Add a source with type='codex' to configuration"
}
EOF
    exit 1
  fi

  handler=$(echo "$source" | jq -r '.handler')

  cat <<EOF
{
  "source": $source,
  "handler": "$handler",
  "reference_type": "codex",
  "project": "$project"
}
EOF

elif [[ "$ref_type" == "url" ]]; then
  # Find source matching URL pattern
  matching_source=$(echo "$sources" | jq --arg url "$reference" '
    .[] | select(.type == "external-url" and .url_pattern != null) |
    select($url | test(.url_pattern))
  ' | head -1)

  if [[ -n "$matching_source" ]] && [[ "$matching_source" != "null" ]]; then
    handler=$(echo "$matching_source" | jq -r '.handler')

    cat <<EOF
{
  "source": $matching_source,
  "handler": "$handler",
  "reference_type": "url",
  "matched_pattern": true
}
EOF
  else
    # No matching pattern - use default HTTP handler
    cat <<EOF
{
  "source": {
    "name": "external-url",
    "type": "external-url",
    "handler": "http",
    "cache": {
      "ttl_days": 7
    },
    "permissions": {
      "enabled": false
    }
  },
  "handler": "http",
  "reference_type": "url",
  "matched_pattern": false
}
EOF
  fi
fi
