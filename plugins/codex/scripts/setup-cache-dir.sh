#!/usr/bin/env bash
# Setup the codex cache directory structure
#
# Usage: ./setup-cache-dir.sh [--cache-path <path>]
# Output: JSON with created paths
#
# Creates:
#   .fractary/plugins/codex/cache/           - Cache directory
#   .fractary/plugins/codex/cache/.gitignore - Ignore cache contents
#   .fractary/plugins/codex/cache/.cache-index.json - Cache index
#
# Also updates project .gitignore to exclude cache directory

set -euo pipefail

# Default paths
cache_path="${CODEX_CACHE_PATH:-.fractary/plugins/codex/cache}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cache-path)
      cache_path="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Track what was created
created_dirs=()
created_files=()
updated_files=()

# Create cache directory
if [[ ! -d "$cache_path" ]]; then
  mkdir -p "$cache_path"
  created_dirs+=("$cache_path")
fi

# Create .gitignore in cache directory
cache_gitignore="$cache_path/.gitignore"
if [[ ! -f "$cache_gitignore" ]]; then
  cat > "$cache_gitignore" << 'EOF'
# Ignore all cached content
*

# But keep these files
!.gitignore
!.cache-index.json
EOF
  created_files+=("$cache_gitignore")
fi

# Create empty cache index
cache_index="$cache_path/.cache-index.json"
if [[ ! -f "$cache_index" ]]; then
  cat > "$cache_index" << 'EOF'
{
  "version": "3.0",
  "entries": [],
  "stats": {
    "total_entries": 0,
    "total_size_bytes": 0,
    "last_cleanup": null
  }
}
EOF
  created_files+=("$cache_index")
fi

# Update project .gitignore
project_gitignore=".gitignore"
gitignore_entry=".fractary/plugins/codex/cache/"
gitignore_updated="false"

if [[ -f "$project_gitignore" ]]; then
  # Check if entry already exists
  if ! grep -qF "$gitignore_entry" "$project_gitignore" 2>/dev/null; then
    # Add entry with a newline before if file doesn't end with one
    if [[ -s "$project_gitignore" ]] && [[ "$(tail -c 1 "$project_gitignore")" != "" ]]; then
      echo "" >> "$project_gitignore"
    fi
    echo "" >> "$project_gitignore"
    echo "# Codex cache (ephemeral)" >> "$project_gitignore"
    echo "$gitignore_entry" >> "$project_gitignore"
    updated_files+=("$project_gitignore")
    gitignore_updated="true"
  fi
else
  # Create new .gitignore
  cat > "$project_gitignore" << EOF
# Codex cache (ephemeral)
$gitignore_entry
EOF
  created_files+=("$project_gitignore")
  gitignore_updated="true"
fi

# Output result
jq -n \
  --arg cache_path "$cache_path" \
  --arg cache_index "$cache_index" \
  --argjson created_dirs "$(printf '%s\n' "${created_dirs[@]:-}" | jq -R . | jq -s .)" \
  --argjson created_files "$(printf '%s\n' "${created_files[@]:-}" | jq -R . | jq -s .)" \
  --argjson updated_files "$(printf '%s\n' "${updated_files[@]:-}" | jq -R . | jq -s .)" \
  --argjson gitignore_updated "$gitignore_updated" \
  '{
    success: true,
    cache_path: $cache_path,
    cache_index: $cache_index,
    created: {
      directories: $created_dirs,
      files: $created_files
    },
    updated: $updated_files,
    gitignore_updated: $gitignore_updated
  }'
