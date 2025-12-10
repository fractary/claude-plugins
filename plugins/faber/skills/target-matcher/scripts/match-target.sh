#!/usr/bin/env bash
# match-target.sh - Match a target against configured patterns
#
# This script matches a target string against the patterns defined in
# FABER's config.json targets section and returns the best matching
# target definition with its metadata.
#
# Usage:
#   match-target.sh <target> [--config <path>] [--project-root <path>]
#
# Arguments:
#   target            The target string to match (e.g., "ipeds/admissions", "src/auth/**")
#
# Options:
#   --config          Path to config.json (default: .fractary/plugins/faber/config.json)
#   --project-root    Project root directory (default: current directory)
#
# Output (JSON):
#   {
#     "status": "success" | "no_match" | "error",
#     "match": {
#       "name": "target-definition-name",
#       "pattern": "matched-pattern",
#       "type": "dataset|code|plugin|docs|config|test|infra",
#       "description": "...",
#       "metadata": {...},
#       "workflow_override": "...",
#       "score": 150,
#       "specificity": {
#         "literal_prefix_length": 5,
#         "wildcard_count": 1,
#         "definition_index": 0
#       }
#     },
#     "input": "original-target-input",
#     "all_matches": [...],  // All matching definitions with scores
#     "message": "Human-readable result message"
#   }
#
# Exit codes:
#   0 - Success (match found or no_match with require_match=false)
#   1 - Error (invalid config, require_match=true but no match)

set -euo pipefail

# Defaults
CONFIG_PATH=".fractary/plugins/faber/config.json"
PROJECT_ROOT="$(pwd)"
TARGET=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONFIG_PATH="$2"
            shift 2
            ;;
        --project-root)
            PROJECT_ROOT="$2"
            shift 2
            ;;
        -*)
            echo '{"status":"error","message":"Unknown option: '"$1"'"}' >&2
            exit 1
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

# Validate target provided
if [[ -z "$TARGET" ]]; then
    echo '{"status":"error","message":"Target argument is required"}'
    exit 1
fi

# Resolve config path relative to project root
if [[ ! "$CONFIG_PATH" = /* ]]; then
    CONFIG_PATH="$PROJECT_ROOT/$CONFIG_PATH"
fi

# Check config exists
if [[ ! -f "$CONFIG_PATH" ]]; then
    # No config - return no_match with default type
    cat <<EOF
{
  "status": "no_match",
  "input": "$TARGET",
  "match": {
    "name": null,
    "pattern": null,
    "type": "file",
    "description": "Default target type (no config found)",
    "metadata": {},
    "workflow_override": null
  },
  "all_matches": [],
  "message": "No FABER config found at $CONFIG_PATH, using default type 'file'"
}
EOF
    exit 0
fi

# Read config
CONFIG=$(cat "$CONFIG_PATH")

# Check if targets section exists
if ! echo "$CONFIG" | jq -e '.targets' > /dev/null 2>&1; then
    # No targets section - return no_match with default type
    cat <<EOF
{
  "status": "no_match",
  "input": "$TARGET",
  "match": {
    "name": null,
    "pattern": null,
    "type": "file",
    "description": "Default target type (no targets configured)",
    "metadata": {},
    "workflow_override": null
  },
  "all_matches": [],
  "message": "No targets section in config, using default type 'file'"
}
EOF
    exit 0
fi

# Extract targets configuration
DEFINITIONS=$(echo "$CONFIG" | jq -c '.targets.definitions // []')
DEFAULT_TYPE=$(echo "$CONFIG" | jq -r '.targets.default_type // "file"')
REQUIRE_MATCH=$(echo "$CONFIG" | jq -r '.targets.require_match // false')

# Function to calculate specificity score
# Formula: (literal_prefix_length * 100) - (wildcard_count * 10) - definition_index
calculate_score() {
    local pattern="$1"
    local index="$2"

    # Calculate literal prefix length (characters before first wildcard)
    local prefix="${pattern%%[\*\?\[]*}"
    local prefix_length=${#prefix}

    # Count wildcards (* and **)
    local single_stars=$(echo "$pattern" | grep -o '\*' | grep -v '\*\*' | wc -l || echo 0)
    local double_stars=$(echo "$pattern" | grep -o '\*\*' | wc -l || echo 0)
    local wildcard_count=$((single_stars + double_stars))

    # Calculate score
    local score=$((prefix_length * 100 - wildcard_count * 10 - index))

    echo "$prefix_length $wildcard_count $score"
}

# Function to check if target matches pattern using bash glob
matches_pattern() {
    local target="$1"
    local pattern="$2"

    # Convert glob pattern to extended glob for matching
    # Enable extended globbing
    shopt -s extglob nullglob 2>/dev/null || true

    # Handle ** patterns by converting to regex-like matching
    # ** matches any number of path segments
    # * matches anything except /

    # Simple approach: use case statement with pattern
    # shellcheck disable=SC2254
    case "$target" in
        $pattern)
            return 0
            ;;
        *)
            # Try with fnmatch-style matching via find (more reliable for complex patterns)
            # Use a temp approach for ** patterns
            local regex_pattern="$pattern"
            # Convert ** to regex-compatible pattern
            regex_pattern="${regex_pattern//\*\*/.*}"
            regex_pattern="${regex_pattern//\*/[^/]*}"
            regex_pattern="^${regex_pattern}$"

            if echo "$target" | grep -qE "$regex_pattern" 2>/dev/null; then
                return 0
            fi
            return 1
            ;;
    esac
}

# Find all matching definitions
MATCHES="[]"
INDEX=0

while IFS= read -r def; do
    [[ -z "$def" ]] && continue

    PATTERN=$(echo "$def" | jq -r '.pattern')
    NAME=$(echo "$def" | jq -r '.name')

    if matches_pattern "$TARGET" "$PATTERN"; then
        # Calculate specificity
        read -r prefix_len wildcard_cnt score <<< "$(calculate_score "$PATTERN" "$INDEX")"

        # Add match with score
        MATCH_ENTRY=$(echo "$def" | jq -c \
            --argjson score "$score" \
            --argjson prefix_len "$prefix_len" \
            --argjson wildcard_cnt "$wildcard_cnt" \
            --argjson index "$INDEX" \
            '. + {
                "score": $score,
                "specificity": {
                    "literal_prefix_length": $prefix_len,
                    "wildcard_count": $wildcard_cnt,
                    "definition_index": $index
                }
            }')

        MATCHES=$(echo "$MATCHES" | jq -c ". + [$MATCH_ENTRY]")
    fi

    INDEX=$((INDEX + 1))
done < <(echo "$DEFINITIONS" | jq -c '.[]')

# Sort matches by score (descending) and get best match
MATCH_COUNT=$(echo "$MATCHES" | jq 'length')

if [[ "$MATCH_COUNT" -eq 0 ]]; then
    # No matches
    if [[ "$REQUIRE_MATCH" == "true" ]]; then
        cat <<EOF
{
  "status": "error",
  "input": "$TARGET",
  "match": null,
  "all_matches": [],
  "message": "No target definition matches '$TARGET'. Configure targets in .fractary/plugins/faber/config.json"
}
EOF
        exit 1
    else
        cat <<EOF
{
  "status": "no_match",
  "input": "$TARGET",
  "match": {
    "name": null,
    "pattern": null,
    "type": "$DEFAULT_TYPE",
    "description": "Default target type (no pattern matched)",
    "metadata": {},
    "workflow_override": null
  },
  "all_matches": [],
  "message": "No pattern matched '$TARGET', using default type '$DEFAULT_TYPE'"
}
EOF
        exit 0
    fi
fi

# Sort by score descending and get best match
SORTED_MATCHES=$(echo "$MATCHES" | jq -c 'sort_by(-.score)')
BEST_MATCH=$(echo "$SORTED_MATCHES" | jq -c '.[0]')

# Check for ambiguous matches (same score)
if [[ "$MATCH_COUNT" -gt 1 ]]; then
    BEST_SCORE=$(echo "$BEST_MATCH" | jq '.score')
    SECOND_SCORE=$(echo "$SORTED_MATCHES" | jq '.[1].score')

    if [[ "$BEST_SCORE" -eq "$SECOND_SCORE" ]]; then
        AMBIGUOUS_MATCHES=$(echo "$SORTED_MATCHES" | jq -c "[.[] | select(.score == $BEST_SCORE)]")
        AMBIGUOUS_NAMES=$(echo "$AMBIGUOUS_MATCHES" | jq -r '.[].name' | tr '\n' ', ' | sed 's/,$//')

        # Use first match but warn about ambiguity
        MESSAGE="Multiple patterns match '$TARGET' with equal specificity: $AMBIGUOUS_NAMES. Using first defined: $(echo "$BEST_MATCH" | jq -r '.name')"
    else
        MESSAGE="Matched '$TARGET' to '$(echo "$BEST_MATCH" | jq -r '.name')' (pattern: $(echo "$BEST_MATCH" | jq -r '.pattern'))"
    fi
else
    MESSAGE="Matched '$TARGET' to '$(echo "$BEST_MATCH" | jq -r '.name')' (pattern: $(echo "$BEST_MATCH" | jq -r '.pattern'))"
fi

# Output result
cat <<EOF
{
  "status": "success",
  "input": "$TARGET",
  "match": $BEST_MATCH,
  "all_matches": $SORTED_MATCHES,
  "message": "$MESSAGE"
}
EOF
