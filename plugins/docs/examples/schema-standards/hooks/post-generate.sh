#!/usr/bin/env bash
#
# Post-Generate Hook - Example
#
# This hook runs AFTER fractary-docs generates a document.
# Use it for automation like code generation, index updates, etc.
#
# Environment variables available:
#   FILE_PATH     - Path to the generated document
#   DOC_TYPE      - Document type (from front matter)
#   PLUGIN_DIR    - Path to plugin directory
#   OPERATION     - Operation performed (generate, update, etc.)
#
# Exit codes:
#   0 - Success
#   Non-zero - Failure (will be reported to user)
#

set -euo pipefail

# Only run for schema documents
if [[ "$DOC_TYPE" != "schema" ]]; then
  echo "Skipping post-generation hooks for non-schema document"
  exit 0
fi

echo "Running post-generation hooks for schema document..."

# ============================================================================
# 1. Auto-Generate Code from Schema
# ============================================================================

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

SCHEMA_FORMAT=$(extract_frontmatter "schema_format")

echo "Schema format: $SCHEMA_FORMAT"

case "$SCHEMA_FORMAT" in
  json-schema)
    echo "Generating TypeScript types from JSON Schema..."
    # Example: npx quicktype "$FILE_PATH" -o "src/types/$(basename "$FILE_PATH" .md).ts"
    # Uncomment and customize for your project
    ;;

  openapi)
    echo "Generating OpenAPI client code..."
    # Example: openapi-generator generate -i "$FILE_PATH" -g typescript-axios -o ./generated/api
    # Uncomment and customize for your project
    ;;

  graphql)
    echo "Generating GraphQL types..."
    # Example: graphql-codegen --config codegen.yml
    # Uncomment and customize for your project
    ;;

  database)
    echo "Generating database migration..."
    # Example: Generate SQL migration from schema changes
    # Uncomment and customize for your project
    ;;

  *)
    echo "No code generation configured for format: $SCHEMA_FORMAT"
    ;;
esac

# ============================================================================
# 2. Update Schema Registry/Index
# ============================================================================

SCHEMA_INDEX="docs/api/schemas/README.md"

if [[ -f "$SCHEMA_INDEX" ]]; then
  echo "Updating schema index..."

  TITLE=$(extract_frontmatter "title")
  VERSION=$(extract_frontmatter "version")
  RELATIVE_PATH="${FILE_PATH#docs/}"

  # Check if already in index
  if grep -q "$RELATIVE_PATH" "$SCHEMA_INDEX"; then
    echo "Schema already in index, updating version..."
    # Update version in existing entry
    # This is a simplified example - customize for your index format
  else
    echo "Adding schema to index..."
    # Add new entry to index
    # This is a simplified example - customize for your index format
    echo "- [$TITLE v$VERSION]($RELATIVE_PATH)" >> "$SCHEMA_INDEX"
  fi
else
  echo "Schema index not found, skipping index update"
fi

# ============================================================================
# 3. Validate Generated Examples
# ============================================================================

echo "Validating schema examples..."

# Extract and validate examples from the generated document
# This is a placeholder - implement based on your schema format

case "$SCHEMA_FORMAT" in
  json-schema)
    # Extract JSON examples and validate against schema
    # Example using ajv: ajv validate -s schema.json -d example.json
    ;;

  openapi)
    # Validate OpenAPI spec
    # Example: openapi-spec-validator "$FILE_PATH"
    ;;

  *)
    echo "No example validation configured for format: $SCHEMA_FORMAT"
    ;;
esac

# ============================================================================
# 4. Generate Documentation Website
# ============================================================================

if command -v redoc-cli &> /dev/null && [[ "$SCHEMA_FORMAT" == "openapi" ]]; then
  echo "Generating API documentation website..."
  # Example: redoc-cli bundle "$FILE_PATH" -o docs/api/index.html
  # Uncomment and customize for your project
fi

# ============================================================================
# 5. Notify Team
# ============================================================================

if [[ "${NOTIFY_ON_SCHEMA_CHANGE:-false}" == "true" ]]; then
  echo "Notifying team of schema changes..."
  # Example: Post to Slack, send email, create GitHub issue, etc.
  # Uncomment and customize for your project
fi

echo "✅ Post-generation hooks completed successfully"
exit 0
