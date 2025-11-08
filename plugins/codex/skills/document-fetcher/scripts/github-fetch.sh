#!/usr/bin/env bash
# Fetch document from GitHub codex repository using sparse checkout
#
# Usage: ./github-fetch.sh "project-name" "path/to/file.md" "codex.fractary.com"
# Output: File content to stdout

set -euo pipefail

project="${1:-}"
path="${2:-}"
codex_repo="${3:-}"

# Validate inputs
if [[ -z "$project" ]] || [[ -z "$path" ]] || [[ -z "$codex_repo" ]]; then
  echo "ERROR: Usage: $0 <project> <path> <codex_repo>" >&2
  exit 1
fi

# Load configuration to get organization
config_file=".fractary/plugins/codex/config.json"
if [[ ! -f "$config_file" ]]; then
  echo "ERROR: Codex configuration not found at $config_file" >&2
  echo "Run /codex:init to create configuration" >&2
  exit 1
fi

org=$(jq -r '.organization // empty' "$config_file")
if [[ -z "$org" ]]; then
  echo "ERROR: organization not found in config" >&2
  exit 1
fi

# Construct full path in codex repo
full_path="projects/$project/$path"

# Create temporary directory for sparse checkout
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

# Clone with sparse checkout
cd "$temp_dir"

# Initialize git repo with sparse checkout enabled
git clone --filter=blob:none --no-checkout --depth=1 \
  "https://github.com/$org/$codex_repo.git" repo 2>&1 | \
  grep -v "warning: You appear to have cloned an empty repository" || true

cd repo

# Enable sparse checkout
git sparse-checkout init --cone

# Set sparse checkout pattern
git sparse-checkout set "projects/$project"

# Checkout the files
if ! git checkout 2>&1 | grep -v "warning: You appear to have cloned an empty repository"; then
  echo "ERROR: Failed to checkout from $org/$codex_repo" >&2
  exit 1
fi

# Check if file exists and output content
if [[ -f "$full_path" ]]; then
  cat "$full_path"
else
  echo "ERROR: Document not found in codex: $full_path" >&2
  echo "Repository: $org/$codex_repo" >&2
  exit 1
fi
