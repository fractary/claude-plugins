#!/bin/bash
# coordinate-validate.sh - Validate document against type-specific rules
# Usage: coordinate-validate.sh <file_path> [doc_type]

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"

# Shared scripts
CLASSIFIER="$PLUGIN_ROOT/skills/doc-classifier/scripts/classify-by-path.sh"

# Parse arguments
FILE_PATH="$1"
DOC_TYPE="${2:-}"

echo "🎯 Coordinating validation..."
echo "   File: $FILE_PATH"

# Step 1: Determine doc_type if not provided
if [[ -z "$DOC_TYPE" ]]; then
    echo ""
    echo "Step 1/3: Detecting document type..."

    if [[ -f "$CLASSIFIER" ]]; then
        CLASSIFY_RESULT=$(bash "$CLASSIFIER" "$FILE_PATH" || echo '{"doc_type":"_untyped","confidence":0}')
        DOC_TYPE=$(echo "$CLASSIFY_RESULT" | jq -r '.doc_type')
        CONFIDENCE=$(echo "$CLASSIFY_RESULT" | jq -r '.confidence')

        if [[ "$DOC_TYPE" == "_untyped" || $CONFIDENCE -lt 50 ]]; then
            echo "   ⚠️  Could not auto-detect doc_type (confidence: $CONFIDENCE)" >&2
            echo "   Please specify doc_type explicitly" >&2
            exit 1
        fi

        echo "   ✅ Detected: $DOC_TYPE (confidence: $CONFIDENCE)"
    else
        echo "   ❌ Classifier not found: $CLASSIFIER" >&2
        exit 1
    fi
else
    echo "   Doc Type: $DOC_TYPE (provided)"
fi

# Step 2: Load validation rules
echo ""
echo "Step 2/3: Loading validation rules..."

TYPE_DIR="$PLUGIN_ROOT/types/$DOC_TYPE"
VALIDATION_RULES="$TYPE_DIR/validation-rules.md"
SCHEMA="$TYPE_DIR/schema.json"

if [[ ! -f "$VALIDATION_RULES" ]]; then
    echo "   ⚠️  Validation rules not found: $VALIDATION_RULES" >&2
    echo "   Performing basic validation only" >&2
fi

if [[ -f "$SCHEMA" ]]; then
    echo "   ✅ Loaded schema: $SCHEMA"
fi

if [[ -f "$VALIDATION_RULES" ]]; then
    echo "   ✅ Loaded validation rules: $VALIDATION_RULES"
fi

# Step 3: Perform validation
echo ""
echo "Step 3/3: Validating document structure..."

VALIDATION_ERRORS=()
VALIDATION_WARNINGS=()

# Extract frontmatter
FRONTMATTER=$(awk '/^---$/,/^---$/{print}' "$FILE_PATH" | grep -v '^---$' || true)

# Check 1: Frontmatter exists
if [[ -z "$FRONTMATTER" ]]; then
    VALIDATION_ERRORS+=("Missing frontmatter")
fi

# Check 2: fractary_doc_type field
DOC_TYPE_IN_FILE=$(echo "$FRONTMATTER" | grep '^fractary_doc_type:' | sed 's/fractary_doc_type: *//' | tr -d '"' || echo "")

if [[ -z "$DOC_TYPE_IN_FILE" ]]; then
    VALIDATION_ERRORS+=("Missing required field: fractary_doc_type")
elif [[ "$DOC_TYPE_IN_FILE" != "$DOC_TYPE" ]]; then
    VALIDATION_ERRORS+=("Doc type mismatch: expected '$DOC_TYPE', found '$DOC_TYPE_IN_FILE'")
fi

# Check 3: Required fields from schema
if [[ -f "$SCHEMA" ]]; then
    # Extract required fields from schema
    REQUIRED_FIELDS=$(jq -r '.required[]? // empty' "$SCHEMA" 2>/dev/null || true)

    if [[ -n "$REQUIRED_FIELDS" ]]; then
        while IFS= read -r field; do
            if ! echo "$FRONTMATTER" | grep -q "^${field}:"; then
                VALIDATION_ERRORS+=("Missing required field: $field")
            fi
        done <<< "$REQUIRED_FIELDS"
    fi
fi

# Check 4: Markdown structure
# Check for at least one heading
if ! grep -q "^#" "$FILE_PATH"; then
    VALIDATION_WARNINGS+=("No markdown headings found")
fi

# Check 5: Type-specific validation (if rules exist)
if [[ -f "$VALIDATION_RULES" ]]; then
    # Parse validation rules for required sections
    REQUIRED_SECTIONS=$(grep -E "^##.*Required" "$VALIDATION_RULES" | sed 's/##\s*//' | sed 's/\s*Required.*//' || true)

    if [[ -n "$REQUIRED_SECTIONS" ]]; then
        while IFS= read -r section; do
            [[ -z "$section" ]] && continue
            # Check if section exists in document
            if ! grep -q "^##.*$section" "$FILE_PATH"; then
                VALIDATION_WARNINGS+=("Missing recommended section: $section")
            fi
        done <<< "$REQUIRED_SECTIONS"
    fi
fi

# Report results
echo ""

if [[ ${#VALIDATION_ERRORS[@]} -eq 0 ]]; then
    echo "✅ Validation passed"

    if [[ ${#VALIDATION_WARNINGS[@]} -gt 0 ]]; then
        echo ""
        echo "Warnings (${#VALIDATION_WARNINGS[@]}):"
        for warning in "${VALIDATION_WARNINGS[@]}"; do
            echo "   ⚠️  $warning"
        done
    fi

    # Return success JSON
    cat <<EOF
{
  "status": "success",
  "operation": "validate",
  "file_path": "$FILE_PATH",
  "doc_type": "$DOC_TYPE",
  "errors": [],
  "warnings": $(jq -n -c --argjson w "$(printf '%s\n' "${VALIDATION_WARNINGS[@]}" | jq -R . | jq -s .)" '$w')
}
EOF
    exit 0
else
    echo "❌ Validation failed (${#VALIDATION_ERRORS[@]} errors)"
    echo ""
    echo "Errors:"
    for error in "${VALIDATION_ERRORS[@]}"; do
        echo "   ❌ $error"
    done

    if [[ ${#VALIDATION_WARNINGS[@]} -gt 0 ]]; then
        echo ""
        echo "Warnings:"
        for warning in "${VALIDATION_WARNINGS[@]}"; do
            echo "   ⚠️  $warning"
        done
    fi

    # Return error JSON
    cat <<EOF
{
  "status": "error",
  "operation": "validate",
  "file_path": "$FILE_PATH",
  "doc_type": "$DOC_TYPE",
  "errors": $(jq -n -c --argjson e "$(printf '%s\n' "${VALIDATION_ERRORS[@]}" | jq -R . | jq -s .)" '$e'),
  "warnings": $(jq -n -c --argjson w "$(printf '%s\n' "${VALIDATION_WARNINGS[@]}" | jq -R . | jq -s .)" '$w')
}
EOF
    exit 1
fi
