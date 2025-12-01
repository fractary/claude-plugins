#!/usr/bin/env bash
# Resolve @codex/ reference to component parts
#
# Usage: ./resolve-reference.sh "@codex/project-name/path/to/file.md"
# Output: JSON with parsed components

set -euo pipefail

reference="${1:-}"

# Validate input
if [[ -z "$reference" ]]; then
  echo '{"error": "Reference argument required", "usage": "@codex/project/path"}' >&2
  exit 1
fi

# Validate format
if [[ ! "$reference" =~ ^@codex/.+ ]]; then
  cat >&2 <<EOF
{"error": "Invalid reference format", "reference": "$reference", "expected": "@codex/{project}/{path}"}
EOF
  exit 1
fi

# Extract components
relative_path="${reference#@codex/}"

# Validate path doesn't contain directory traversal
if [[ "$relative_path" =~ \.\. ]]; then
  echo '{"error": "Directory traversal not allowed", "reference": "'"$reference"'"}' >&2
  exit 1
fi

# Validate reference has at least one slash (project/path structure)
if [[ ! "$relative_path" =~ / ]]; then
  echo '{"error": "Invalid reference: missing path component", "reference": "'"$reference"'", "expected": "@codex/{project}/{path}"}' >&2
  exit 1
fi

# Extract project name (first path segment)
project=$(echo "$relative_path" | cut -d'/' -f1)

# Extract path (everything after project name)
path="${relative_path#$project/}"

# Validate we have both project and path
if [[ -z "$project" ]] || [[ -z "$path" ]] || [[ "$path" == "$project" ]]; then
  echo '{"error": "Invalid reference: missing project or path", "reference": "'"$reference"'"}' >&2
  exit 1
fi

# Output JSON
cat <<EOF
{
  "reference": "$reference",
  "relative_path": "$relative_path",
  "cache_path": "codex/$relative_path",
  "project": "$project",
  "path": "$path",
  "mcp_uri": "codex://$relative_path"
}
EOF
