#!/bin/bash
# batch-write.sh - Execute batch write operations with parallel execution
# Usage: batch-write.sh <documents_json> <doc_type> [--parallel] [--max-concurrent N]

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"

# Manager script
MANAGER_WRITE="$PLUGIN_ROOT/skills/docs-manager-skill/scripts/coordinate-write.sh"

# Parse arguments
DOCUMENTS_JSON="$1"
DOC_TYPE="$2"
PARALLEL="${3:-true}"
MAX_CONCURRENT="${4:-10}"

# Count documents
TOTAL=$(echo "$DOCUMENTS_JSON" | jq 'length')

echo "🎯 Starting batch write operation..."
echo "   Total documents: $TOTAL"
echo "   Doc type: $DOC_TYPE"
echo "   Parallel: $PARALLEL"
echo "   Max concurrent: $MAX_CONCURRENT"
echo ""

# Safety check
if [[ $TOTAL -gt 50 ]]; then
    echo "⚠️  WARNING: Processing $TOTAL documents"
    echo "This may take several minutes."
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 1
    fi
fi

# Create results directory
RESULTS_DIR="/tmp/docs-batch-$$"
mkdir -p "$RESULTS_DIR"

# Function to process single document
process_document() {
    local index="$1"
    local doc_json="$2"
    local doc_type="$3"

    local file_path=$(echo "$doc_json" | jq -r '.file_path')
    local context=$(echo "$doc_json" | jq -c '.context // {}')

    local result_file="$RESULTS_DIR/result-$index.json"

    echo "[$((index + 1))/$TOTAL] Processing: $file_path"

    # Use flock to prevent concurrent writes to same file
    local lock_file="$file_path.lock"

    if (
        flock -x -w 30 200 || exit 1

        # Execute write coordination
        if bash "$MANAGER_WRITE" "$file_path" "$doc_type" "$context" "false" "true" > "$result_file" 2>&1; then
            echo "[$((index + 1))/$TOTAL] ✅ $file_path"
            exit 0
        else
            echo "[$((index + 1))/$TOTAL] ❌ $file_path"
            exit 1
        fi

    ) 200>"$lock_file"; then
        return 0
    else
        # Failure - capture error
        echo "{\"status\":\"error\",\"file_path\":\"$file_path\",\"error\":\"Failed or lock timeout\"}" > "$result_file"
        return 1
    fi
}

# Export function for parallel execution
export -f process_document
export MANAGER_WRITE
export RESULTS_DIR
export TOTAL

# Process documents
SUCCEEDED=0
FAILED=0

if [[ "$PARALLEL" == "true" ]]; then
    echo "Processing in parallel (max $MAX_CONCURRENT concurrent)..."
    echo ""

    # Process in parallel with job control
    for i in $(seq 0 $((TOTAL - 1))); do
        DOC=$(echo "$DOCUMENTS_JSON" | jq -c ".[$i]")

        # Run in background
        process_document "$i" "$DOC" "$DOC_TYPE" &

        # Limit concurrent jobs
        while (( $(jobs -r | wc -l) >= MAX_CONCURRENT )); do
            sleep 0.1
        done
    done

    # Wait for all background jobs
    wait

else
    echo "Processing sequentially..."
    echo ""

    # Process sequentially
    for i in $(seq 0 $((TOTAL - 1))); do
        DOC=$(echo "$DOCUMENTS_JSON" | jq -c ".[$i]")
        if process_document "$i" "$DOC" "$DOC_TYPE"; then
            ((SUCCEEDED++))
        else
            ((FAILED++))
        fi
    done
fi

echo ""
echo "Collecting results..."

# Collect results
FAILURES=()
SUCCEEDED=0
FAILED=0

for result_file in "$RESULTS_DIR"/result-*.json; do
    [[ ! -f "$result_file" ]] && continue

    STATUS=$(jq -r '.status // "error"' "$result_file")
    FILE_PATH=$(jq -r '.file_path // "unknown"' "$result_file")

    if [[ "$STATUS" == "success" ]]; then
        ((SUCCEEDED++))
    else
        ((FAILED++))
        ERROR=$(jq -r '.error // "Unknown error"' "$result_file")
        FAILURES+=("{\"file\":\"$FILE_PATH\",\"error\":\"$ERROR\"}")
    fi
done

# Build failures JSON array
FAILURES_JSON="["
for ((i=0; i<${#FAILURES[@]}; i++)); do
    [[ $i -gt 0 ]] && FAILURES_JSON+=","
    FAILURES_JSON+="${FAILURES[$i]}"
done
FAILURES_JSON+="]"

# Cleanup
rm -rf "$RESULTS_DIR"

# Update indices (collect unique directories)
echo ""
echo "Updating indices..."

DIRECTORIES=()
for i in $(seq 0 $((TOTAL - 1))); do
    FILE_PATH=$(echo "$DOCUMENTS_JSON" | jq -r ".[$i].file_path")
    DIR=$(dirname "$FILE_PATH")

    # Add to array if not already present
    if [[ ! " ${DIRECTORIES[*]} " =~ " ${DIR} " ]]; then
        DIRECTORIES+=("$DIR")
    fi
done

INDEX_UPDATER="$PLUGIN_ROOT/skills/_shared/lib/index-updater.sh"
INDICES_UPDATED=()

for dir in "${DIRECTORIES[@]}"; do
    echo "   Updating: $dir"
    if bash "$INDEX_UPDATER" "$dir" "$DOC_TYPE" >/dev/null 2>&1; then
        echo "   ✅ $dir/README.md"
        INDICES_UPDATED+=("$dir/README.md")
    else
        echo "   ⚠️  Failed to update: $dir/README.md"
    fi
done

# Report results
echo ""
echo "═══════════════════════════════════════"
echo "Batch Write Results:"
echo "  Total: $TOTAL"
echo "  Succeeded: $SUCCEEDED"
echo "  Failed: $FAILED"
echo "  Indices Updated: ${#INDICES_UPDATED[@]}"
echo "═══════════════════════════════════════"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "Failed documents:"
    echo "$FAILURES_JSON" | jq -r '.[] | "  ❌ \(.file)\n     \(.error)"'
fi

# Return JSON result
if [[ $FAILED -eq 0 ]]; then
    STATUS="success"
else
    if [[ $SUCCEEDED -eq 0 ]]; then
        STATUS="error"
    else
        STATUS="partial_success"
    fi
fi

cat <<EOF
{
  "status": "$STATUS",
  "operation": "write-batch",
  "total": $TOTAL,
  "succeeded": $SUCCEEDED,
  "failed": $FAILED,
  "failures": $FAILURES_JSON,
  "indices_updated": $(printf '%s\n' "${INDICES_UPDATED[@]}" | jq -R . | jq -s .)
}
EOF

[[ $FAILED -eq 0 ]] && exit 0 || exit 1
