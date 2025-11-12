#!/usr/bin/env bash
#
# Custom Schema Documentation Validator
#
# This is an example custom validation script for project-specific schema documentation standards.
# It extends the baseline fractary-docs validation with project-specific rules.
#
# Usage: ./validate-schema-docs.sh <schema-doc-file.md>
#
# Exit codes:
#   0 - Validation passed
#   1 - Validation failed
#
# Returns JSON with validation results
#

set -euo pipefail

# Input validation
if [[ $# -lt 1 ]]; then
  echo '{"success": false, "error": "Missing required argument: file path"}' >&2
  exit 1
fi

FILE_PATH="$1"

if [[ ! -f "$FILE_PATH" ]]; then
  echo "{\"success\": false, \"error\": \"File not found: $FILE_PATH\"}" >&2
  exit 1
fi

# Initialize results
ERRORS=0
WARNINGS=0
INFO=0
ISSUES=()

# Helper function to add issue
add_issue() {
  local severity="$1"
  local check="$2"
  local message="$3"

  case "$severity" in
    error) ((ERRORS++)) ;;
    warning) ((WARNINGS++)) ;;
    info) ((INFO++)) ;;
  esac

  ISSUES+=("{\"severity\": \"$severity\", \"check\": \"$check\", \"message\": \"$message\"}")
}

# Extract front matter fields
extract_frontmatter() {
  local field="$1"
  awk -v field="$field" '
    /^---$/ { in_fm = !in_fm; next }
    in_fm && $0 ~ "^" field ":" {
      sub("^" field ": *", "")
      gsub(/^["'\'']|["'\'']$/, "")
      print
      exit
    }
  ' "$FILE_PATH"
}

# Check if section exists
has_section() {
  local section="$1"
  grep -q "^## $section" "$FILE_PATH"
}

# Count occurrences
count_pattern() {
  local pattern="$1"
  grep -c "$pattern" "$FILE_PATH" || true
}

# ============================================================================
# 1. Check Document Type
# ============================================================================

DOC_TYPE=$(extract_frontmatter "type")

if [[ "$DOC_TYPE" != "schema" ]]; then
  add_issue "info" "doc_type" "This validator is for schema documents (found type: $DOC_TYPE)"
fi

# ============================================================================
# 2. Naming Convention Checks
# ============================================================================

# Check entity names are PascalCase (only if Entities section exists)
if has_section "Entities"; then
  # Extract entity names from ### Entity headings
  ENTITY_NAMES=$(grep "^### " "$FILE_PATH" | grep -A1 "^## Entities" | tail -n +2 | sed 's/^### //' | cut -d' ' -f1 || true)

  while IFS= read -r entity; do
    if [[ -n "$entity" ]] && ! [[ "$entity" =~ ^[A-Z][a-zA-Z0-9]*$ ]]; then
      add_issue "error" "naming_convention" "Entity name '$entity' should be PascalCase"
    fi
  done <<< "$ENTITY_NAMES"
fi

# ============================================================================
# 3. Field Documentation Completeness
# ============================================================================

# Check Fields section exists
if ! has_section "Fields"; then
  add_issue "error" "required_section" "Missing required section: Fields"
else
  # Count field definitions (### Entity.field pattern)
  FIELD_COUNT=$(grep -c "^### .*\\..*" "$FILE_PATH" || true)

  if [[ $FIELD_COUNT -eq 0 ]]; then
    add_issue "warning" "field_documentation" "No fields documented (expected ### Entity.field headings)"
  else
    # For each field, check if it has required documentation
    # This is a simplified check - in production, parse more thoroughly
    FIELDS_WITH_EXAMPLES=$(grep -c "Examples.*:" "$FILE_PATH" || true)

    if [[ $FIELDS_WITH_EXAMPLES -lt $FIELD_COUNT ]]; then
      add_issue "warning" "field_documentation" "Some fields may be missing examples (found $FIELDS_WITH_EXAMPLES examples for $FIELD_COUNT fields)"
    fi
  fi
fi

# ============================================================================
# 4. Versioning Requirements
# ============================================================================

VERSION=$(extract_frontmatter "version")

if [[ -z "$VERSION" ]]; then
  add_issue "error" "versioning" "Missing required front matter field: version"
else
  # Check semantic versioning format (MAJOR.MINOR.PATCH)
  if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    add_issue "error" "versioning" "Version must follow semantic versioning (MAJOR.MINOR.PATCH): $VERSION"
  fi
fi

# Check Versioning section exists
if ! has_section "Versioning"; then
  add_issue "error" "versioning" "Missing required section: Versioning"
fi

# ============================================================================
# 5. Code Generation Section
# ============================================================================

if ! has_section "Code Generation"; then
  add_issue "warning" "code_generation" "Missing recommended section: Code Generation"
fi

# ============================================================================
# 6. Examples Count
# ============================================================================

EXAMPLE_SECTIONS=$(count_pattern "^### .*[Ee]xample")

if [[ $EXAMPLE_SECTIONS -lt 3 ]]; then
  add_issue "warning" "examples" "Schema should have at least 3 examples (minimal, complete, invalid). Found: $EXAMPLE_SECTIONS"
fi

# ============================================================================
# 7. Security Annotations (PII Detection)
# ============================================================================

# Check for common PII field names without security annotations
PII_PATTERNS=("email" "phone" "ssn" "social_security" "credit_card" "password" "address")
SECURITY_SECTION_EXISTS=$(has_section "Security" && echo "yes" || echo "no")

for pattern in "${PII_PATTERNS[@]}"; do
  if grep -qi "$pattern" "$FILE_PATH"; then
    if [[ "$SECURITY_SECTION_EXISTS" == "no" ]] && ! grep -qi "pii\|sensitive\|encrypted" "$FILE_PATH"; then
      add_issue "warning" "security" "Potential PII field detected ('$pattern') but no security annotations found"
      break
    fi
  fi
done

# ============================================================================
# 8. Schema Format Validation
# ============================================================================

SCHEMA_FORMAT=$(extract_frontmatter "schema_format")

if [[ -z "$SCHEMA_FORMAT" ]]; then
  add_issue "error" "schema_format" "Missing required front matter field: schema_format"
else
  VALID_FORMATS=("json-schema" "openapi" "graphql" "avro" "protobuf" "database" "event" "custom")
  VALID=0

  for fmt in "${VALID_FORMATS[@]}"; do
    if [[ "$SCHEMA_FORMAT" == "$fmt" ]]; then
      VALID=1
      break
    fi
  done

  if [[ $VALID -eq 0 ]]; then
    add_issue "warning" "schema_format" "Unknown schema_format: $SCHEMA_FORMAT (expected one of: ${VALID_FORMATS[*]})"
  fi
fi

# Check Schema Format section exists
if ! has_section "Schema Format"; then
  add_issue "error" "required_section" "Missing required section: Schema Format"
fi

# ============================================================================
# 9. Validation Rules Section
# ============================================================================

if ! has_section "Validation Rules"; then
  add_issue "error" "required_section" "Missing required section: Validation Rules"
else
  # Check that validation rules include error messages
  if ! grep -qi "error.*message\|message.*error" "$FILE_PATH"; then
    add_issue "info" "validation_rules" "Validation rules should document error messages"
  fi
fi

# ============================================================================
# 10. Performance Considerations
# ============================================================================

if ! has_section "Indexes" && ! grep -qi "performance\|index\|optimization" "$FILE_PATH"; then
  add_issue "info" "performance" "Consider documenting performance considerations (indexes, query patterns, size limits)"
fi

# ============================================================================
# Output Results
# ============================================================================

TOTAL_ISSUES=$((ERRORS + WARNINGS + INFO))

# Build JSON output
if [[ ${#ISSUES[@]} -gt 0 ]]; then
  ISSUES_JSON=$(printf '%s,' "${ISSUES[@]}" | sed 's/,$//')
else
  ISSUES_JSON=""
fi

cat <<EOF
{
  "success": true,
  "file": "$FILE_PATH",
  "validator": "project-schema-standards",
  "total_issues": $TOTAL_ISSUES,
  "errors": $ERRORS,
  "warnings": $WARNINGS,
  "info": $INFO,
  "issues": [
    $ISSUES_JSON
  ]
}
EOF

# Exit with error if there are errors
if [[ $ERRORS -gt 0 ]]; then
  exit 1
fi

exit 0
