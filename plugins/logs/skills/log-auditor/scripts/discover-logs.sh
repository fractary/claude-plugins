#!/usr/bin/env bash
# discover-logs.sh - Find all log files and log-like files in project
#
# Usage: discover-logs.sh <project_root> <output_json>
#
# Discovers:
# - Log files (*.log, *.txt in certain directories)
# - Build outputs (npm-debug.log, yarn-error.log, etc.)
# - Test outputs (junit.xml, coverage reports)
# - Deployment logs (terraform.log, kubectl logs)
# - Session logs (existing fractary-logs sessions)
# - Debug logs (debug.log, trace.log)
#
# Categorizes each log by type and managed status
# Outputs JSON inventory

set -euo pipefail

PROJECT_ROOT="${1:-.}"
OUTPUT_JSON="${2:-discovery-logs.json}"

# Patterns for log file detection
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
  "session-*.md"
  "trace.log"
  "debug.txt"
)

# Directories that commonly contain logs
LOG_DIRS=(
  "logs"
  "log"
  ".logs"
  "tmp"
  ".tmp"
  "build/logs"
  "dist/logs"
  "coverage"
  ".coverage"
  "test-results"
  ".terraform"
  ".next"
  ".nuxt"
)

# Managed log locations (fractary-logs)
MANAGED_LOCATIONS=(
  "/logs/sessions"
  "/logs/builds"
  "/logs/deployments"
  "/logs/debug"
)

cd "$PROJECT_ROOT" || exit 1

echo "🔍 Discovering log files in $PROJECT_ROOT..." >&2

# Initialize JSON output
cat > "$OUTPUT_JSON" <<'EOF'
{
  "discovery_date": "",
  "project_root": "",
  "total_logs": 0,
  "total_size_bytes": 0,
  "by_type": {},
  "by_status": {
    "managed": 0,
    "unmanaged": 0
  },
  "logs": []
}
EOF

# Arrays to collect log entries
declare -a log_entries=()
total_logs=0
total_size=0
managed_count=0
unmanaged_count=0

# Find log files
echo "  Searching for log patterns..." >&2
for pattern in "${LOG_PATTERNS[@]}"; do
  while IFS= read -r -d '' file; do
    # Skip if in node_modules, .git, or other excluded directories
    if [[ "$file" =~ node_modules|\.git|vendor|\.venv|venv ]]; then
      continue
    fi

    # Get file info
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    modified=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo 0)

    # Determine type based on filename and path
    type="other"
    if [[ "$file" =~ session-.*\.md ]]; then
      type="session"
    elif [[ "$file" =~ build|npm-debug|yarn-error ]]; then
      type="build"
    elif [[ "$file" =~ deploy|terraform ]]; then
      type="deployment"
    elif [[ "$file" =~ debug|trace ]]; then
      type="debug"
    elif [[ "$file" =~ test|junit|coverage ]]; then
      type="test"
    fi

    # Determine if managed
    managed="false"
    for managed_loc in "${MANAGED_LOCATIONS[@]}"; do
      if [[ "$file" =~ $managed_loc ]]; then
        managed="true"
        managed_count=$((managed_count + 1))
        break
      fi
    done

    if [[ "$managed" == "false" ]]; then
      unmanaged_count=$((unmanaged_count + 1))
    fi

    # Add to entries
    log_entries+=("{\"path\":\"$file\",\"size\":$size,\"modified\":$modified,\"type\":\"$type\",\"managed\":$managed}")
    total_logs=$((total_logs + 1))
    total_size=$((total_size + size))

  done < <(find . -name "$pattern" -type f -print0 2>/dev/null)
done

# Search specific log directories
echo "  Searching common log directories..." >&2
for dir in "${LOG_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    while IFS= read -r -d '' file; do
      # Skip if already processed or in excluded directories
      if [[ "$file" =~ node_modules|\.git|vendor|\.venv|venv ]]; then
        continue
      fi

      # Check if already in entries
      already_found=false
      for entry in "${log_entries[@]}"; do
        if [[ "$entry" =~ \"$file\" ]]; then
          already_found=true
          break
        fi
      done

      if [[ "$already_found" == "true" ]]; then
        continue
      fi

      # Get file info
      size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
      modified=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo 0)

      # Determine type from directory
      type="other"
      if [[ "$dir" =~ session ]]; then
        type="session"
      elif [[ "$dir" =~ build ]]; then
        type="build"
      elif [[ "$dir" =~ deploy ]]; then
        type="deployment"
      elif [[ "$dir" =~ debug ]]; then
        type="debug"
      elif [[ "$dir" =~ test|coverage ]]; then
        type="test"
      fi

      # Determine if managed
      managed="false"
      for managed_loc in "${MANAGED_LOCATIONS[@]}"; do
        if [[ "$file" =~ $managed_loc ]]; then
          managed="true"
          managed_count=$((managed_count + 1))
          break
        fi
      done

      if [[ "$managed" == "false" ]]; then
        unmanaged_count=$((unmanaged_count + 1))
      fi

      log_entries+=("{\"path\":\"$file\",\"size\":$size,\"modified\":$modified,\"type\":\"$type\",\"managed\":$managed}")
      total_logs=$((total_logs + 1))
      total_size=$((total_size + size))

    done < <(find "$dir" -type f -print0 2>/dev/null)
  fi
done

# Count by type
declare -A type_counts
for entry in "${log_entries[@]}"; do
  type=$(echo "$entry" | grep -o '"type":"[^"]*"' | cut -d':' -f2 | tr -d '"')
  type_counts[$type]=$((${type_counts[$type]:-0} + 1))
done

# Build by_type JSON
by_type_json="{"
first=true
for type in "${!type_counts[@]}"; do
  if [[ "$first" == "false" ]]; then
    by_type_json+=","
  fi
  by_type_json+="\"$type\":${type_counts[$type]}"
  first=false
done
by_type_json+="}"

# Build logs array JSON
logs_json="["
first=true
for entry in "${log_entries[@]}"; do
  if [[ "$first" == "false" ]]; then
    logs_json+=","
  fi
  logs_json+="$entry"
  first=false
done
logs_json+="]"

# Write final JSON
cat > "$OUTPUT_JSON" <<EOF
{
  "discovery_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project_root": "$PROJECT_ROOT",
  "total_logs": $total_logs,
  "total_size_bytes": $total_size,
  "by_type": $by_type_json,
  "by_status": {
    "managed": $managed_count,
    "unmanaged": $unmanaged_count
  },
  "logs": $logs_json
}
EOF

echo "✅ Discovered $total_logs log files ($(numfmt --to=iec $total_size 2>/dev/null || echo "$total_size bytes"))" >&2
echo "  Output: $OUTPUT_JSON" >&2
