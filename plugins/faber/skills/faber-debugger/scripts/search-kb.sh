#!/usr/bin/env bash
#
# search-kb.sh - Search the troubleshooting knowledge base
#
# Usage:
#   search-kb.sh --keywords "keyword1,keyword2" [options]
#
# Options:
#   --keywords <list>    Comma-separated keywords to search for
#   --patterns <list>    Comma-separated error patterns (supports wildcards)
#   --category <cat>     Filter by category (workflow|build|test|deploy|general)
#   --limit <n>          Maximum results to return (default: 5)
#   --threshold <n>      Minimum similarity score 0.0-1.0 (default: 0.5)
#   --exact-match        Only return exact pattern matches
#
# Examples:
#   search-kb.sh --keywords "type error,annotation"
#   search-kb.sh --keywords "timeout" --category test --limit 3
#   search-kb.sh --patterns "Type error: Expected*" --threshold 0.7
#
# Output: JSON array of matching entries with scores

set -euo pipefail

# Path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FABER_ROOT="$(cd "$SKILL_ROOT/../.." && pwd)"

# Default knowledge base location
KB_PATH="${KB_PATH:-.fractary/plugins/faber/debugger/knowledge-base}"
INDEX_FILE="$KB_PATH/index.json"

# Defaults
KEYWORDS=""
PATTERNS=""
CATEGORY=""
LIMIT=5
THRESHOLD="0.5"
EXACT_MATCH=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keywords)
            KEYWORDS="$2"
            shift 2
            ;;
        --patterns)
            PATTERNS="$2"
            shift 2
            ;;
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --exact-match)
            EXACT_MATCH=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Check if knowledge base exists
if [ ! -f "$INDEX_FILE" ]; then
    # Return empty result (not an error - KB is optional)
    echo '{"matches": [], "total_searched": 0, "kb_available": false}'
    exit 0
fi

# Load index
INDEX_CONTENT=$(cat "$INDEX_FILE")
TOTAL_ENTRIES=$(echo "$INDEX_CONTENT" | jq '.entries | length')

# Build jq filter based on parameters
build_filter() {
    local filter="."

    # Category filter
    if [ -n "$CATEGORY" ]; then
        filter="$filter | select(.category == \"$CATEGORY\")"
    fi

    echo "$filter"
}

# Calculate keyword match score
# Returns score between 0.0 and 1.0
calculate_keyword_score() {
    local search_keywords="$1"
    local entry_keywords="$2"

    if [ -z "$search_keywords" ]; then
        echo "0"
        return
    fi

    local matched=0
    local total=0

    IFS=',' read -ra SEARCH_ARRAY <<< "$search_keywords"
    for keyword in "${SEARCH_ARRAY[@]}"; do
        keyword=$(echo "$keyword" | xargs)  # Trim whitespace
        total=$((total + 1))
        if echo "$entry_keywords" | grep -qi "$keyword"; then
            matched=$((matched + 1))
        fi
    done

    if [ $total -eq 0 ]; then
        echo "0"
    else
        # Return as decimal (bash doesn't do float math well, use awk)
        awk "BEGIN {printf \"%.2f\", $matched / $total}"
    fi
}

# Calculate pattern match score using simple fuzzy matching
# Returns score between 0.0 and 1.0
calculate_pattern_score() {
    local search_patterns="$1"
    local entry_patterns="$2"

    if [ -z "$search_patterns" ]; then
        echo "0"
        return
    fi

    local best_score=0

    IFS=',' read -ra SEARCH_ARRAY <<< "$search_patterns"
    for pattern in "${SEARCH_ARRAY[@]}"; do
        pattern=$(echo "$pattern" | xargs)  # Trim whitespace
        # Convert wildcard to regex
        local regex_pattern=$(echo "$pattern" | sed 's/\*/.*?/g')

        # Check if any entry pattern matches
        if echo "$entry_patterns" | grep -qiE "$regex_pattern"; then
            # Exact or close match
            best_score=1
            break
        elif echo "$entry_patterns" | grep -qi "${pattern%% *}"; then
            # Partial match (first word)
            if [ "$(awk "BEGIN {print ($best_score < 0.5)}")" = "1" ]; then
                best_score=0.5
            fi
        fi
    done

    echo "$best_score"
}

# Calculate recency score based on last_used date
calculate_recency_score() {
    local last_used="$1"

    if [ -z "$last_used" ] || [ "$last_used" = "null" ]; then
        echo "0.3"
        return
    fi

    local now=$(date +%s)
    local used=$(date -d "$last_used" +%s 2>/dev/null || echo "0")
    local days_ago=$(( (now - used) / 86400 ))

    if [ $days_ago -le 30 ]; then
        echo "1.0"
    elif [ $days_ago -le 90 ]; then
        echo "0.7"
    elif [ $days_ago -le 180 ]; then
        echo "0.5"
    else
        echo "0.3"
    fi
}

# Process each entry and calculate scores
process_entries() {
    local results="[]"

    # Get all entry IDs
    local entry_ids=$(echo "$INDEX_CONTENT" | jq -r '.entries | keys[]')

    for entry_id in $entry_ids; do
        local entry=$(echo "$INDEX_CONTENT" | jq -r ".entries[\"$entry_id\"]")
        local entry_category=$(echo "$entry" | jq -r '.category // "general"')
        local entry_keywords=$(echo "$entry" | jq -r '.keywords | join(",")')
        local entry_patterns=$(echo "$entry" | jq -r '.patterns | join(",")')
        local entry_last_used=$(echo "$entry" | jq -r '.last_used // ""')

        # Skip if category filter doesn't match
        if [ -n "$CATEGORY" ] && [ "$entry_category" != "$CATEGORY" ]; then
            continue
        fi

        # Calculate component scores
        local keyword_score=$(calculate_keyword_score "$KEYWORDS" "$entry_keywords")
        local pattern_score=$(calculate_pattern_score "$PATTERNS" "$entry_patterns")
        local category_score="0.5"  # Base category score if not filtered
        if [ -n "$CATEGORY" ]; then
            category_score="1.0"
        fi
        local recency_score=$(calculate_recency_score "$entry_last_used")

        # Calculate weighted final score
        # Weights: keywords 40%, patterns 40%, category 10%, recency 10%
        local final_score=$(awk "BEGIN {
            kw = $keyword_score * 0.4
            pt = $pattern_score * 0.4
            ct = $category_score * 0.1
            rc = $recency_score * 0.1
            printf \"%.2f\", kw + pt + ct + rc
        }")

        # Check threshold
        if [ "$(awk "BEGIN {print ($final_score >= $THRESHOLD)}")" = "1" ]; then
            # Get additional fields for output
            local issue_pattern=$(echo "$entry" | jq -r '.issue_pattern // ""')
            local status=$(echo "$entry" | jq -r '.status // "unverified"')
            local usage_count=$(echo "$entry" | jq -r '.usage_count // 0')
            local path=$(echo "$entry" | jq -r '.path // ""')

            # Determine relevance level
            local relevance="low"
            if [ "$(awk "BEGIN {print ($final_score >= 0.8)}")" = "1" ]; then
                relevance="high"
            elif [ "$(awk "BEGIN {print ($final_score >= 0.6)}")" = "1" ]; then
                relevance="medium"
            fi

            # Add to results
            local match_obj=$(jq -n \
                --arg kb_id "$entry_id" \
                --arg score "$final_score" \
                --arg category "$entry_category" \
                --arg issue_pattern "$issue_pattern" \
                --arg relevance "$relevance" \
                --arg status "$status" \
                --argjson usage_count "$usage_count" \
                --arg last_used "$entry_last_used" \
                --arg path "$path" \
                '{
                    kb_id: $kb_id,
                    score: ($score | tonumber),
                    category: $category,
                    issue_pattern: $issue_pattern,
                    relevance: $relevance,
                    status: $status,
                    usage_count: $usage_count,
                    last_used: $last_used,
                    path: $path
                }')

            results=$(echo "$results" | jq ". + [$match_obj]")
        fi
    done

    # Sort by score descending and limit
    echo "$results" | jq "sort_by(.score) | reverse | .[0:$LIMIT]"
}

# Main execution
matches=$(process_entries)
match_count=$(echo "$matches" | jq 'length')

# Build final output
jq -n \
    --argjson matches "$matches" \
    --argjson total_searched "$TOTAL_ENTRIES" \
    --argjson matches_found "$match_count" \
    --arg threshold "$THRESHOLD" \
    --argjson kb_available true \
    '{
        matches: $matches,
        total_searched: $total_searched,
        matches_found: $matches_found,
        threshold_used: ($threshold | tonumber),
        kb_available: $kb_available
    }'
