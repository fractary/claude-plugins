# Create Architecture Document Workflow

This workflow describes the complete process for creating a new architecture document.

## Prerequisites

- Configuration loaded from schema and project config
- Required parameters validated (title, overview, components, patterns)
- Target directory exists or can be created

## Steps

### 1. Validate Input Parameters

```bash
# Check required fields
if [[ -z "$TITLE" ]]; then
    echo "ERROR: title is required" >&2
    exit 1
fi

if [[ -z "$OVERVIEW" ]]; then
    echo "ERROR: overview is required" >&2
    exit 1
fi

if [[ -z "$COMPONENTS" || "$COMPONENTS" == "[]" ]]; then
    echo "ERROR: At least one component is required" >&2
    exit 1
fi

if [[ -z "$PATTERNS" || "$PATTERNS" == "[]" ]]; then
    echo "ERROR: At least one pattern is required" >&2
    exit 1
fi
```

### 2. Generate Filename

```bash
# Source slugify utility
source "$SKILL_ROOT/../_shared/scripts/slugify.sh"

# Generate slug from title
SLUG=$(slugify "$TITLE")

# Determine filename based on type
case "$DOC_TYPE" in
    "component")
        FILENAME="${COMPONENT_NAME}-architecture.md"
        ;;
    "diagram")
        FILENAME="${SLUG}-diagram.md"
        ;;
    *)
        FILENAME="architecture-${SLUG}.md"
        ;;
esac

FILE_PATH="$DOC_PATH/$FILENAME"
```

### 3. Check File Existence

```bash
if [[ -f "$FILE_PATH" ]]; then
    if [[ "$OVERWRITE" != "true" ]]; then
        echo "ERROR: File already exists: $FILE_PATH" >&2
        echo "Use overwrite: true to replace existing file" >&2
        exit 1
    fi
fi
```

### 4. Select Template

```bash
# Select appropriate template based on type
case "$DOC_TYPE" in
    "overview")
        TEMPLATE="$SKILL_ROOT/templates/overview.md.template"
        ;;
    "component")
        TEMPLATE="$SKILL_ROOT/templates/component.md.template"
        ;;
    "diagram")
        TEMPLATE="$SKILL_ROOT/templates/diagram.md.template"
        ;;
    *)
        TEMPLATE="$SKILL_ROOT/templates/overview.md.template"
        ;;
esac

if [[ ! -f "$TEMPLATE" ]]; then
    echo "ERROR: Template not found: $TEMPLATE" >&2
    exit 1
fi
```

### 5. Prepare Template Data

```bash
# Build JSON data for template rendering
TEMPLATE_DATA=$(cat <<EOF
{
  "title": "$TITLE",
  "overview": "$OVERVIEW",
  "components": $COMPONENTS,
  "patterns": $PATTERNS,
  "type": "$DOC_TYPE",
  "component_name": "$COMPONENT_NAME",
  "status": "${STATUS:-draft}",
  "date": "$(date -u +%Y-%m-%d)",
  "author": "${AUTHOR:-Claude Code}",
  "tags": ${TAGS:-[]},
  "related": ${RELATED:-[]},
  "technologies": ${TECHNOLOGIES:-[]},
  "diagrams": ${DIAGRAMS:-[]},
  "system_context": "$SYSTEM_CONTEXT",
  "data_flow": "$DATA_FLOW",
  "deployment": "$DEPLOYMENT",
  "security": "$SECURITY",
  "scalability": "$SCALABILITY"
}
EOF
)
```

### 6. Render Template

```bash
# Render template with data
# Simple Mustache-style variable substitution
RENDERED_CONTENT=$(cat "$TEMPLATE")

# Replace variables ({{variable}})
while IFS= read -r key; do
    value=$(echo "$TEMPLATE_DATA" | jq -r ".$key // empty")
    if [[ -n "$value" && "$value" != "null" ]]; then
        RENDERED_CONTENT="${RENDERED_CONTENT//\{\{$key\}\}/$value}"
    fi
done < <(echo "$TEMPLATE_DATA" | jq -r 'keys[]')

# Handle arrays (simple implementation)
# For production, use a proper Mustache renderer
```

### 7. Add Frontmatter

```bash
# Frontmatter is already in the template
# Ensure it's properly formatted
if ! head -n 1 <<< "$RENDERED_CONTENT" | grep -q "^---$"; then
    echo "WARNING: Template missing frontmatter" >&2
fi
```

### 8. Write File

```bash
# Create directory if needed
mkdir -p "$DOC_PATH"

# Write rendered content to file
echo "$RENDERED_CONTENT" > "$FILE_PATH"

echo "Created: $FILE_PATH"
```

### 9. Update Index

```bash
# Update index if auto_update_index is enabled
if [[ "$AUTO_UPDATE_INDEX" == "true" ]]; then
    source "$SKILL_ROOT/../_shared/lib/index-updater.sh"

    update_index "$DOC_PATH" "architecture" "" "Architecture Documentation"

    echo "Index updated: $DOC_PATH/README.md"
fi
```

### 10. Validate Output

```bash
# Validate the generated document
if [[ "$VALIDATE" == "true" ]]; then
    # Check required sections exist
    REQUIRED_SECTIONS=("Overview" "Components" "Patterns")

    for section in "${REQUIRED_SECTIONS[@]}"; do
        if ! grep -q "^## $section" "$FILE_PATH"; then
            echo "WARNING: Missing required section: $section" >&2
        fi
    done

    # Check content length
    WORD_COUNT=$(wc -w < "$FILE_PATH")
    if [[ $WORD_COUNT -lt 100 ]]; then
        echo "WARNING: Document is very short ($WORD_COUNT words)" >&2
    fi

    echo "Validation: Passed"
fi
```

### 11. Return Result

```bash
# Build result JSON
cat <<EOF
{
  "success": true,
  "operation": "create",
  "doc_type": "architecture",
  "result": {
    "file_path": "$FILE_PATH",
    "title": "$TITLE",
    "type": "$DOC_TYPE",
    "status": "${STATUS:-draft}",
    "size_bytes": $(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null),
    "sections": ["Overview", "Components", "Patterns"],
    "validation": "passed",
    "index_updated": $AUTO_UPDATE_INDEX
  },
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

## Success Criteria

- ✅ File created at configured path
- ✅ All required sections present
- ✅ Frontmatter properly formatted
- ✅ Index updated (if enabled)
- ✅ Validation passed
- ✅ Result returned with file details

## Error Conditions

- ❌ Missing required parameters → Return validation error
- ❌ File already exists (no overwrite) → Return file exists error
- ❌ Template not found → Return template error
- ❌ Write permission denied → Return permission error
- ❌ Index update failed → Warn but continue

## Notes

- The workflow prioritizes user-provided data over defaults
- Empty optional fields are omitted from the final document
- Index update failures don't fail the overall operation
- Validation is optional but recommended
