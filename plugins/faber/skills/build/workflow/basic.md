# Build Phase: Basic Workflow

This workflow implements the basic Build phase - implementing solutions from specifications.

## Steps

### 1. Post Build Start Notification
```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "build" "🔨 **Build Phase Started**

**Work ID**: \`${WORK_ID}\`
**Type**: ${WORK_TYPE}
$([ "$RETRY_COUNT" -gt 0 ] && echo "**Retry**: Attempt $((RETRY_COUNT + 1))")

Implementing solution from specification..." '[]'
```

### 2. Load and Analyze Specification
```bash
# Read spec file
SPEC_FILE=$(echo "$ARCHITECT_CONTEXT" | jq -r '.spec_file')
SPEC_CONTENT=$(cat "$SPEC_FILE")

# If retry, consider previous failures
if [ "$RETRY_COUNT" -gt 0 ]; then
    echo "🔄 Retry Context: $RETRY_CONTEXT"
    echo "Previous attempt failed - addressing issues..."
fi
```

### 3. Implement Solution

Using Claude's capabilities, implement the solution according to the specification:

- Read "Files to Modify" section from spec
- Read "Implementation Strategy" from spec
- Make necessary code changes
- Follow technical approach defined in spec
- Address retry context if this is a retry

**Implementation Guidance**:
- Create/modify files as specified
- Follow coding standards and best practices
- Add appropriate error handling
- Include inline documentation
- Ensure code is testable

### 4. Commit Changes

Use repo-manager to commit implementation:

```markdown
Use the @agent-fractary-repo:repo-manager agent with the following request:
{
  "operation": "create-commit",
  "parameters": {
    "message": "{work_type}: {work_item_title}",
    "type": "{work_type_prefix}",
    "work_id": "{work_id}",
    "files": ["{changed_files}"]
  }
}
```

Store commit information for session update.

### 5. Update Session
```bash
BUILD_DATA=$(cat <<EOF
{
  "commits": ["$COMMIT_SHA"],
  "files_changed": $(echo "$CHANGED_FILES" | jq -R . | jq -s .),
  "retry_count": $RETRY_COUNT
}
EOF
)

"$CORE_SKILL/session-update.sh" "$WORK_ID" "build" "completed" "$BUILD_DATA"
```

### 6. Post Build Complete
```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "build" "✅ **Build Phase Complete**

**Commits**: ${#COMMITS[@]}
**Files Changed**: ${#CHANGED_FILES[@]}

Implementation complete. Ready for evaluation..." '[]'
```

### 7. Return Results
```bash
cat <<EOF
{
  "status": "success",
  "phase": "build",
  "commits": $(echo "$COMMITS" | jq -s .),
  "files_changed": $(echo "$CHANGED_FILES" | jq -R . | jq -s .),
  "retry_count": $RETRY_COUNT
}
EOF
```

## Success Criteria
- ✅ Specification loaded and analyzed
- ✅ Solution implemented according to spec
- ✅ Changes committed to version control
- ✅ Session updated with build results
- ✅ Build complete notification posted

## Retry Handling

When invoked as a retry (retry_count > 0):
1. Review retry_context for failure reasons
2. Address specific issues mentioned
3. Re-implement or fix problematic areas
4. Ensure tests will pass this time

This basic Build workflow implements solutions from specifications while supporting the Build-Evaluate retry loop.
