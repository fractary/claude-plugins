#!/usr/bin/env bash
# discover-vcs-logs.sh - Find log files tracked in version control
#
# Usage: discover-vcs-logs.sh <project_root> <output_json>
#
# Discovers:
# - Log files tracked by Git
# - Logs that should be in .gitignore but aren't
# - Repository size impact
# - Files that need to be removed
#
# Outputs JSON with VCS log analysis

set -euo pipefail

PROJECT_ROOT="${1:-.}"
OUTPUT_JSON="${2:-discovery-vcs-logs.json}"

cd "$PROJECT_ROOT" || exit 1

echo "🔍 Checking for logs in version control..." >&2

# Check if this is a Git repository
if [[ ! -d ".git" ]]; then
  echo "⚠️  Not a Git repository, skipping VCS analysis" >&2
  cat > "$OUTPUT_JSON" <<EOF
{
  "discovery_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "is_git_repo": false,
  "vcs_logs": [],
  "total_vcs_logs": 0,
  "total_size_bytes": 0,
  "should_be_ignored": [],
  "repository_impact_bytes": 0
}
EOF
  exit 0
fi

# Patterns for log files (similar to discover-logs.sh)
LOG_PATTERNS=(
  "*.log"
  "*.log.*"
  "*-debug.log"
  "*-error.log"
  "npm-debug.log"
  "yarn-error.log"
  "pnpm-debug.log"
  "test-results.txt"
  "junit*.xml"
  "terraform.log"
  "deploy*.log"
  "build*.log"
)

# Precompute regex patterns (optimize by converting once outside the loop)
declare -a LOG_REGEXES=()
for pattern in "${LOG_PATTERNS[@]}"; do
  # Convert glob pattern to regex
  pattern_regex=$(echo "$pattern" | sed 's/\./\\./g' | sed 's/\*/.*/g')
  LOG_REGEXES+=("$pattern_regex")
done

declare -a vcs_logs=()
declare -a should_ignore=()
total_vcs_logs=0
total_size=0
repo_impact=0

# Find all tracked files
echo "  Scanning tracked files..." >&2
while IFS= read -r file; do
  # Check if file matches log patterns (using precomputed regexes)
  is_log=false
  for pattern_regex in "${LOG_REGEXES[@]}"; do
    if [[ "$file" =~ $pattern_regex ]]; then
      is_log=true
      break
    fi
  done

  # Also check if file is in a log directory
  if [[ "$file" =~ /logs?/|/tmp/|/build/logs|/dist/logs|/coverage/|/test-results/ ]]; then
    is_log=true
  fi

  if [[ "$is_log" == "true" ]]; then
    # File is a log and is tracked in Git
    if [[ -f "$file" ]]; then
      size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    else
      size=0
    fi

    # Check if it's in .gitignore (but still tracked - was added before .gitignore)
    in_gitignore=false
    if git check-ignore -q "$file" 2>/dev/null; then
      in_gitignore=true
    fi

    vcs_logs+=("{\"path\":\"$file\",\"size\":$size,\"in_gitignore\":$in_gitignore}")
    total_vcs_logs=$((total_vcs_logs + 1))
    total_size=$((total_size + size))

    # If not in .gitignore, it should be
    if [[ "$in_gitignore" == "false" ]]; then
      should_ignore+=("\"$file\"")
      repo_impact=$((repo_impact + size))
    fi
  fi
done < <(git ls-files)

# Build vcs_logs array JSON
vcs_logs_json="["
first=true
for entry in "${vcs_logs[@]}"; do
  if [[ "$first" == "false" ]]; then
    vcs_logs_json+=","
  fi
  vcs_logs_json+="$entry"
  first=false
done
vcs_logs_json+="]"

# Build should_be_ignored array JSON
should_ignore_json="["
first=true
for path in "${should_ignore[@]}"; do
  if [[ "$first" == "false" ]]; then
    should_ignore_json+=","
  fi
  should_ignore_json+="$path"
  first=false
done
should_ignore_json+="]"

# Write final JSON
cat > "$OUTPUT_JSON" <<EOF
{
  "discovery_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "is_git_repo": true,
  "vcs_logs": $vcs_logs_json,
  "total_vcs_logs": $total_vcs_logs,
  "total_size_bytes": $total_size,
  "should_be_ignored": $should_ignore_json,
  "repository_impact_bytes": $repo_impact
}
EOF

if [[ $total_vcs_logs -gt 0 ]]; then
  echo "⚠️  Found $total_vcs_logs log files in version control ($(numfmt --to=iec $total_size 2>/dev/null || echo "$total_size bytes"))" >&2
  echo "  ${#should_ignore[@]} files should be in .gitignore" >&2
else
  echo "✅ No log files in version control" >&2
fi
echo "  Output: $OUTPUT_JSON" >&2
