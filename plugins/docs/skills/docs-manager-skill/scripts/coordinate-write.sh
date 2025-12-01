#!/bin/bash
# coordinate-write.sh - Orchestrate write → validate → index pipeline
# Usage: coordinate-write.sh <file_path> <doc_type> <context_json> [--skip-validation] [--skip-index]

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"

# Shared scripts
DOC_WRITER="$PLUGIN_ROOT/skills/doc-writer/scripts/write-doc.sh"
DOC_VALIDATOR="$PLUGIN_ROOT/skills/doc-validator/scripts/validate-structure.sh"
INDEX_UPDATER="$PLUGIN_ROOT/skills/_shared/lib/index-updater.sh"

# Parse arguments
FILE_PATH="$1"
DOC_TYPE="$2"
CONTEXT_JSON="${3:-{}}"
SKIP_VALIDATION="${4:-false}"
SKIP_INDEX="${5:-false}"

# Extract directory from file path
DIR=$(dirname "$FILE_PATH")
FILENAME=$(basename "$FILE_PATH")

echo "🎯 Coordinating write pipeline..."
echo "   File: $FILE_PATH"
echo "   Doc Type: $DOC_TYPE"
echo "   Skip Validation: $SKIP_VALIDATION"
echo "   Skip Index: $SKIP_INDEX"
echo ""

# Step 1: Load type context
echo "Step 1/5: Loading type context..."
TYPE_DIR="$PLUGIN_ROOT/types/$DOC_TYPE"

if [[ ! -d "$TYPE_DIR" ]]; then
    echo "ERROR: Type context not found for: $DOC_TYPE" >&2
    exit 1
fi

SCHEMA="$TYPE_DIR/schema.json"
TEMPLATE="$TYPE_DIR/template.md"
STANDARDS="$TYPE_DIR/standards.md"

if [[ ! -f "$TEMPLATE" ]]; then
    echo "ERROR: Template not found: $TEMPLATE" >&2
    exit 1
fi

echo "   ✅ Loaded type context from: $TYPE_DIR"
echo ""

# Step 2: Write document
echo "Step 2/5: Writing document..."

# Create directory if needed
mkdir -p "$DIR"

# Extract frontmatter from context
FRONTMATTER=$(echo "$CONTEXT_JSON" | jq -c '{
    title: .title,
    fractary_doc_type: "'$DOC_TYPE'",
    status: (.status // "draft"),
    version: (.version // "1.0.0")
} + .')

# Extract content from context (or use template default)
CONTENT=$(echo "$CONTEXT_JSON" | jq -r '.content // ""')

# If no content, use template
if [[ -z "$CONTENT" || "$CONTENT" == "null" ]]; then
    # Simple template rendering - replace {{variables}}
    CONTENT=$(<"$TEMPLATE")

    # Replace variables from context
    while IFS= read -r key; do
        VALUE=$(echo "$CONTEXT_JSON" | jq -r --arg k "$key" '.[$k] // ""')
        CONTENT=$(echo "$CONTENT" | sed "s|{{$key}}|$VALUE|g")
    done < <(echo "$CONTEXT_JSON" | jq -r 'keys[]')
fi

# Write file
echo "---" > "$FILE_PATH"
echo "$FRONTMATTER" | jq -r 'to_entries | map("\(.key): \"\(.value)\"") | .[]' >> "$FILE_PATH"
echo "---" >> "$FILE_PATH"
echo "" >> "$FILE_PATH"
echo "$CONTENT" >> "$FILE_PATH"

echo "   ✅ Document written: $FILE_PATH"
echo ""

# Step 3: Validate document (unless skipped)
VALIDATION_STATUS="skipped"

if [[ "$SKIP_VALIDATION" != "true" ]]; then
    echo "Step 3/5: Validating document..."

    # Basic validation checks
    VALIDATION_ERRORS=()

    # Check frontmatter exists
    if ! head -n 1 "$FILE_PATH" | grep -q "^---$"; then
        VALIDATION_ERRORS+=("Missing frontmatter delimiter")
    fi

    # Check fractary_doc_type matches
    DOC_TYPE_IN_FILE=$(grep "^fractary_doc_type:" "$FILE_PATH" | sed 's/fractary_doc_type: *//' | tr -d '"' || echo "")
    if [[ "$DOC_TYPE_IN_FILE" != "$DOC_TYPE" ]]; then
        VALIDATION_ERRORS+=("Doc type mismatch: expected $DOC_TYPE, found $DOC_TYPE_IN_FILE")
    fi

    # Load validation rules
    VALIDATION_RULES="$TYPE_DIR/validation-rules.md"

    if [[ -f "$VALIDATION_RULES" ]]; then
        # Extract required fields from validation rules
        # This is a simplified check - full validation would use doc-validator skill

        if grep -q "title.*Required" "$VALIDATION_RULES"; then
            if ! grep -q "^title:" "$FILE_PATH"; then
                VALIDATION_ERRORS+=("Missing required field: title")
            fi
        fi
    fi

    if [[ ${#VALIDATION_ERRORS[@]} -eq 0 ]]; then
        echo "   ✅ Validation passed (0 errors)"
        VALIDATION_STATUS="passed"
    else
        echo "   ❌ Validation failed (${#VALIDATION_ERRORS[@]} errors):"
        for error in "${VALIDATION_ERRORS[@]}"; do
            echo "      - $error"
        done
        VALIDATION_STATUS="failed"
        exit 1
    fi
    echo ""
fi

# Step 4: Update index (unless skipped)
INDEX_UPDATED=false

if [[ "$SKIP_INDEX" != "true" ]]; then
    echo "Step 4/5: Updating index..."

    if [[ -f "$INDEX_UPDATER" ]]; then
        if bash "$INDEX_UPDATER" "$DIR" "$DOC_TYPE"; then
            echo "   ✅ Index updated"
            INDEX_UPDATED=true
        else
            echo "   ⚠️  Index update failed (non-fatal)"
        fi
    else
        echo "   ⚠️  Index updater not found: $INDEX_UPDATER"
    fi
    echo ""
fi

# Step 5: Report success
echo "✅ Write pipeline completed successfully"
echo ""
echo "Results:"
echo "  File: $FILE_PATH"
echo "  Doc Type: $DOC_TYPE"
echo "  Validation: $VALIDATION_STATUS"
echo "  Index Updated: $INDEX_UPDATED"

# Return JSON result
cat <<EOF
{
  "status": "success",
  "operation": "write",
  "file_path": "$FILE_PATH",
  "doc_type": "$DOC_TYPE",
  "validation": "$VALIDATION_STATUS",
  "index_updated": $INDEX_UPDATED
}
EOF

exit 0
