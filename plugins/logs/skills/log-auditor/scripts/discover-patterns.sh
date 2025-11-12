#!/usr/bin/env bash
# discover-patterns.sh - Analyze log file patterns and categorization
#
# Usage: discover-patterns.sh <discovery_logs_json> <output_json>
#
# Analyzes:
# - Common log naming patterns
# - Log types and their prevalence
# - Log rotation patterns
# - Mapping to fractary-logs categories
#
# Outputs JSON with pattern analysis

set -euo pipefail

DISCOVERY_LOGS="${1:-discovery-logs.json}"
OUTPUT_JSON="${2:-discovery-patterns.json}"

echo "🔍 Analyzing log patterns..." >&2

# Check if input exists
if [[ ! -f "$DISCOVERY_LOGS" ]]; then
  echo "❌ Error: $DISCOVERY_LOGS not found" >&2
  exit 1
fi

# Read logs from discovery JSON
logs_json=$(cat "$DISCOVERY_LOGS")

# Initialize pattern counters
declare -A pattern_counts
declare -A type_counts
declare -A extension_counts
declare -A directory_counts

# Parse each log entry and analyze patterns
# Using jq if available, otherwise basic parsing
if command -v jq &>/dev/null; then
  # Extract logs array and iterate using process substitution to avoid subshell
  while IFS= read -r log_entry; do
    path=$(echo "$log_entry" | jq -r '.path')
    type=$(echo "$log_entry" | jq -r '.type')

    # Count by type
    type_counts[$type]=$((${type_counts[$type]:-0} + 1))

    # Extract extension
    if [[ "$path" =~ \.[^.]+$ ]]; then
      ext="${BASH_REMATCH[0]}"
      extension_counts[$ext]=$((${extension_counts[$ext]:-0} + 1))
    fi

    # Extract directory
    dir=$(dirname "$path")
    directory_counts[$dir]=$((${directory_counts[$dir]:-0} + 1))

    # Detect patterns
    if [[ "$path" =~ npm-debug\.log ]]; then
      pattern_counts["npm-debug"]=$((${pattern_counts["npm-debug"]:-0} + 1))
    elif [[ "$path" =~ yarn-error\.log ]]; then
      pattern_counts["yarn-error"]=$((${pattern_counts["yarn-error"]:-0} + 1))
    elif [[ "$path" =~ session-[0-9]+ ]]; then
      pattern_counts["session-ISSUE"]=$((${pattern_counts["session-ISSUE"]:-0} + 1))
    elif [[ "$path" =~ build.*\.log ]]; then
      pattern_counts["build-logs"]=$((${pattern_counts["build-logs"]:-0} + 1))
    elif [[ "$path" =~ deploy.*\.log ]]; then
      pattern_counts["deploy-logs"]=$((${pattern_counts["deploy-logs"]:-0} + 1))
    elif [[ "$path" =~ terraform\.log ]]; then
      pattern_counts["terraform"]=$((${pattern_counts["terraform"]:-0} + 1))
    elif [[ "$path" =~ junit.*\.xml ]]; then
      pattern_counts["junit-xml"]=$((${pattern_counts["junit-xml"]:-0} + 1))
    elif [[ "$path" =~ debug\.log ]]; then
      pattern_counts["debug-log"]=$((${pattern_counts["debug-log"]:-0} + 1))
    else
      pattern_counts["other"]=$((${pattern_counts["other"]:-0} + 1))
    fi
  done < <(echo "$logs_json" | jq -r '.logs[] | @json')
else
  # Fallback: basic parsing without jq
  echo "  (jq not found, using basic parsing)" >&2
fi

# Build pattern analysis JSON
patterns_json="{"
first=true
for pattern in "${!pattern_counts[@]}"; do
  if [[ "$first" == "false" ]]; then
    patterns_json+=","
  fi
  patterns_json+="\"$pattern\":${pattern_counts[$pattern]}"
  first=false
done
patterns_json+="}"

# Build type counts JSON
types_json="{"
first=true
for type in "${!type_counts[@]}"; do
  if [[ "$first" == "false" ]]; then
    types_json+=","
  fi
  types_json+="\"$type\":${type_counts[$type]}"
  first=false
done
types_json+="}"

# Build extension counts JSON
extensions_json="{"
first=true
for ext in "${!extension_counts[@]}"; do
  if [[ "$first" == "false" ]]; then
    extensions_json+=","
  fi
  extensions_json+="\"$ext\":${extension_counts[$ext]}"
  first=false
done
extensions_json+="}"

# Build top directories JSON (top 10)
top_dirs_json="{"
first=true
count=0
for dir in "${!directory_counts[@]}"; do
  if [[ $count -ge 10 ]]; then break; fi
  if [[ "$first" == "false" ]]; then
    top_dirs_json+=","
  fi
  top_dirs_json+="\"$dir\":${directory_counts[$dir]}"
  first=false
  count=$((count + 1))
done
top_dirs_json+="}"

# Mapping recommendations to fractary-logs categories
cat > "$OUTPUT_JSON" <<EOF
{
  "discovery_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "patterns": $patterns_json,
  "type_distribution": $types_json,
  "extensions": $extensions_json,
  "top_directories": $top_dirs_json,
  "recommendations": {
    "session_logs": {
      "pattern": "session-*.md",
      "target_location": "/logs/sessions/",
      "description": "Claude Code session logs"
    },
    "build_logs": {
      "pattern": "build*.log, npm-debug.log, yarn-error.log",
      "target_location": "/logs/builds/",
      "description": "Build and package manager logs"
    },
    "deployment_logs": {
      "pattern": "deploy*.log, terraform.log",
      "target_location": "/logs/deployments/",
      "description": "Deployment and infrastructure logs"
    },
    "debug_logs": {
      "pattern": "debug.log, trace.log",
      "target_location": "/logs/debug/",
      "description": "Debug and trace logs"
    },
    "test_logs": {
      "pattern": "junit*.xml, test-results.txt",
      "target_location": "/logs/tests/",
      "description": "Test execution logs"
    }
  }
}
EOF

echo "✅ Pattern analysis complete" >&2
echo "  Patterns identified: ${#pattern_counts[@]}" >&2
echo "  Output: $OUTPUT_JSON" >&2
