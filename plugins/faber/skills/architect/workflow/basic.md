# Architect Phase: Basic Workflow

This workflow implements the basic Architect phase operations for FABER workflows. It generates implementation specifications from work items, providing detailed technical design documents that guide the Build phase.

## Overview

The Architect phase is responsible for:
1. Generating implementation specifications
2. Documenting technical approach
3. Defining success criteria
4. Committing specifications to version control

## Implementation Steps

### Step 1: Post Architect Start Notification

Post a status card to the work tracking system:

```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "architect" "📐 **Architect Phase Started**

**Work ID**: \`${WORK_ID}\`
**Type**: ${WORK_TYPE}

Generating implementation specification from requirements..." '[]'
```

### Step 2: Generate Specification Document

**If configured**, use fractary-spec to generate the specification:

```bash
GENERATE_SPEC=$(echo "$CONFIG_JSON" | jq -r '.workflow.architect.generate_spec // true')
SPEC_TEMPLATE=$(echo "$CONFIG_JSON" | jq -r '.workflow.architect.spec_template // "auto"')
```

#### Option A: Using fractary-spec (Recommended)

If `generate_spec` is enabled, use the spec-manager agent:

```markdown
Use the @agent-fractary-spec:spec-manager agent with the following request:
{
  "operation": "generate",
  "parameters": {
    "issue_number": "{source_id}",
    "template": "{spec_template}",
    "link_to_issue": true,
    "work_type": "{work_type}",
    "work_domain": "{work_domain}"
  }
}
```

The spec-manager will:
- Auto-detect template based on work type (if template = "auto")
- Generate comprehensive specification
- Save to configured location (e.g., `/specs/spec-{issue_number}-{slug}.md`)
- Comment on issue with spec location
- Return spec file path

**Store Spec Path**:
```bash
SPEC_FILE=$(echo "$SPEC_RESULT" | jq -r '.spec_file')
echo "✅ Specification generated: $SPEC_FILE"
```

#### Option B: Manual Specification (Fallback)

If `generate_spec` is disabled, create a manual specification.

**Specification Template**:

```markdown
# Implementation Specification: {work_item_title}

**Work ID**: {work_id}
**Type**: {work_type}
**Source**: {source_type}/{source_id}
**Created**: {current_date}

## Summary

{Brief 2-3 sentence overview of what needs to be done}

## Requirements

### Functional Requirements
{List what the solution must do from user perspective}

- Requirement 1
- Requirement 2
- ...

### Technical Requirements
{List technical constraints and requirements}

- Technology/framework to use
- Performance requirements
- Security requirements
- Compatibility requirements

## Technical Approach

### Architecture

{Describe the high-level architecture or design}

### Implementation Strategy

{Describe how the solution will be implemented}

1. Step 1: {What will be done}
2. Step 2: {What will be done}
3. ...

### Key Decisions

{List important architectural/technical decisions made}

- Decision 1: {Why this approach}
- Decision 2: {Why this approach}
- ...

## Files to Modify

{List files that will need changes}

- `path/to/file1.ext` - {What changes}
- `path/to/file2.ext` - {What changes}
- ...

## Testing Strategy

### Unit Tests
{What unit tests are needed}

### Integration Tests
{What integration tests are needed}

### End-to-End Tests
{What E2E tests are needed}

## Security Considerations

{Any security implications to consider}

- Authentication/Authorization changes
- Data validation requirements
- Secure coding practices needed

## Success Criteria

{Checklist of requirements for completion}

- [ ] Functional requirement 1 met
- [ ] Functional requirement 2 met
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Code reviewed and approved

## References

- Original Work Item: {source_url}
- Related Documentation: {links}
```

**Generate Specification Content**:

Using Claude's capabilities, generate a detailed specification based on:
- Work item title and description from Frame phase
- Work type (/bug, /feature, /chore, /patch)
- Domain context (engineering, design, etc.)
- Any additional context from the work item

**Specification File Path**:
```bash
# Create spec directory if it doesn't exist
mkdir -p .faber/specs

# Generate spec filename
SPEC_SLUG=$(echo "$WORK_ITEM_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-50)
SPEC_FILE=".faber/specs/${WORK_ID}-${SPEC_SLUG}.md"

echo "📝 Generating specification: $SPEC_FILE"
```

**Write Specification**:
```bash
# Generate and write specification content
cat > "$SPEC_FILE" <<EOF
# Implementation Specification: ${WORK_ITEM_TITLE}

... (generated content) ...
EOF

echo "✅ Specification generated: $SPEC_FILE"
```

### Step 3: Generate ADR (Optional)

**If configured and work is architectural**, generate an Architecture Decision Record:

```bash
GENERATE_ADR=$(echo "$CONFIG_JSON" | jq -r '.workflow.architect.generate_adr // false')
ADR_THRESHOLD=$(echo "$CONFIG_JSON" | jq -r '.workflow.architect.adr_threshold // "architectural"')
```

**Decision Logic**:
```
if GENERATE_ADR == true AND work_is_architectural:
    Generate ADR
```

**What qualifies as "architectural"?**
- Major technology changes (new framework, database, etc.)
- Significant architecture changes (microservices, event-driven, etc.)
- Security model changes
- Infrastructure decisions
- Integration patterns

```markdown
Use the @agent-fractary-docs:docs-manager agent with the following request:
{
  "operation": "generate-adr",
  "parameters": {
    "title": "{work_item_title}",
    "context": "{work_context}",
    "decision": "{architectural_decision}",
    "consequences": "{expected_consequences}"
  }
}
```

The docs-manager will:
- Generate ADR using template
- Save to `/docs/architecture/adrs/`
- Number ADR sequentially
- Return ADR file path

**Store ADR Path**:
```bash
if [ "$GENERATE_ADR" = "true" ]; then
    ADR_FILE=$(echo "$ADR_RESULT" | jq -r '.adr_file')
    echo "✅ ADR generated: $ADR_FILE"
fi
```

### Step 4: Commit Specification and ADR

Use repo-manager to commit the specification (and ADR if generated):

```bash
# Validate spec file was created
if [ -z "$SPEC_FILE" ] || [ ! -f "$SPEC_FILE" ]; then
    echo "❌ Error: Specification file not created"
    exit 1
fi

# Build file list
FILES_TO_COMMIT="[\"$SPEC_FILE\""
if [ -n "$ADR_FILE" ]; then
    # Validate ADR file exists if specified
    if [ ! -f "$ADR_FILE" ]; then
        echo "⚠️  Warning: ADR file specified but not found: $ADR_FILE"
    else
        FILES_TO_COMMIT="${FILES_TO_COMMIT}, \"$ADR_FILE\""
    fi
fi
FILES_TO_COMMIT="${FILES_TO_COMMIT}]"

# Sanitize work item title for commit message (prevent injection)
# Remove newlines, limit length, escape special characters
SAFE_TITLE=$(echo "$WORK_ITEM_TITLE" | tr -d '\n\r' | cut -c1-100 | sed 's/[`$"\\]/\\&/g')

# Determine commit message
if [ -n "$ADR_FILE" ] && [ -f "$ADR_FILE" ]; then
    COMMIT_MSG="docs(spec): Add specification and ADR for ${SAFE_TITLE}"
else
    COMMIT_MSG="docs(spec): Add specification for ${SAFE_TITLE}"
fi
```

**Security Note**: Always sanitize user-controlled inputs (work item titles, descriptions) before using in commit messages or shell commands to prevent injection attacks.

```markdown
Use the @agent-fractary-repo:repo-manager agent with the following request:
{
  "operation": "create-commit",
  "parameters": {
    "message": "${COMMIT_MSG}",
    "type": "docs",
    "work_id": "{work_id}",
    "scope": "spec",
    "files": ${FILES_TO_COMMIT}
  }
}
```

**Store Commit Information**:
```bash
COMMIT_SHA=$(echo "$COMMIT_RESULT" | jq -r '.commit_sha')
if [ -n "$ADR_FILE" ]; then
    echo "✅ Specification and ADR committed: $COMMIT_SHA"
else
    echo "✅ Specification committed: $COMMIT_SHA"
fi
```

### Step 5: Push Specification (Optional)

If configured, push the specification to remote:

```bash
# Check configuration for auto-push
AUTO_PUSH=$(echo "$CONFIG_JSON" | jq -r '.architect.auto_push // true')

if [ "$AUTO_PUSH" = "true" ]; then
    echo "📤 Pushing specification to remote..."

    # Use repo-manager to push
    # (repo-manager will handle branch tracking and remote push)

    echo "✅ Specification pushed to remote"
else
    echo "⏭️  Skipping push (auto_push disabled)"
fi
```

### Step 6: Extract Key Decisions

Parse the specification to extract key decisions for context:

```bash
# Extract key decisions from spec (simple grep approach)
KEY_DECISIONS=$(grep -A 5 "### Key Decisions" "$SPEC_FILE" | grep "^- " | sed 's/^- //' | jq -R . | jq -s .)

echo "Key Decisions:"
echo "$KEY_DECISIONS" | jq -r '.[]'
```

### Step 7: Update Workflow State

Update the workflow state with Architect results:

```bash
# Build Architect data JSON
ARCHITECT_DATA=$(cat <<EOF
{
  "spec_file": "$SPEC_FILE",
  "commit_sha": "$COMMIT_SHA",
  "spec_url": "${REPO_URL}/blob/${BRANCH_NAME}/${SPEC_FILE}",
  "key_decisions": $KEY_DECISIONS
}
EOF
)

# Update state
"$CORE_SKILL/state-update-phase.sh" "architect" "completed" "$ARCHITECT_DATA"
```

### Step 8: Post Architect Complete Notification

Post completion status to work tracking system:

```bash
# Build spec URL for linking
if [ -n "$REPO_URL" ] && [ -n "$BRANCH_NAME" ]; then
    SPEC_LINK="[View Specification](${REPO_URL}/blob/${BRANCH_NAME}/${SPEC_FILE})"
else
    SPEC_LINK="Specification: \`${SPEC_FILE}\`"
fi

"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "architect" "✅ **Architect Phase Complete**

**Specification**: ${SPEC_LINK}
**Commit**: \`${COMMIT_SHA}\`

Implementation specification has been generated and committed.

**Key Decisions**:
$(echo "$KEY_DECISIONS" | jq -r '.[] | "- " + .')

**Next**: Building solution from specification..." '[]'
```

### Step 8: Return Results

Return Architect results to workflow-manager:

```bash
cat <<EOF
{
  "status": "success",
  "phase": "architect",
  "spec_file": "$SPEC_FILE",
  "commit_sha": "$COMMIT_SHA",
  "spec_url": "${REPO_URL}/blob/${BRANCH_NAME}/${SPEC_FILE}",
  "key_decisions": $KEY_DECISIONS
}
EOF
```

## Success Criteria

Architect phase succeeds when:
- ✅ Specification generated with all required sections
- ✅ Specification includes clear requirements
- ✅ Technical approach documented
- ✅ Success criteria defined
- ✅ Specification file saved to repository
- ✅ Specification committed to version control
- ✅ Architect start notification posted
- ✅ Session updated with Architect data
- ✅ Architect complete notification posted with spec link

## Specification Quality Guidelines

### For /feature Work Type
- Focus on functional requirements and user value
- Include detailed technical approach
- Define comprehensive testing strategy
- List all files that need creation or modification

### For /bug Work Type
- Describe the bug and its impact
- Include root cause analysis (if known)
- Define fix approach and testing strategy
- List files to modify for the fix

### For /chore Work Type
- Describe maintenance task or refactoring
- Explain benefits and rationale
- Define scope of changes
- Include migration strategy if applicable

### For /patch Work Type
- Describe urgent issue being patched
- Include immediate fix approach
- Define rollback strategy
- Include long-term fix plan (if different)

## Error Recovery

### Specification Generation Failure
- **Action**: Log error, update session, post error notification, exit with code 1
- **Recovery**: User can review work item and retry Architect phase

### File Write Failure
- **Action**: Check permissions, log error, update session, exit with code 1
- **Recovery**: Fix file permissions, retry Architect phase

### Commit Failure
- **Action**: Check git state, log error, update session, exit with code 1
- **Recovery**: Resolve git issues (conflicts, etc.), retry Architect phase

### Push Failure (Non-Fatal)
- **Action**: Log warning, continue without pushing
- **Recovery**: Push can be done manually later

## Configuration

Architect phase respects these configuration settings:

```toml
[architect]
spec_directory = ".faber/specs"  # Where to save specifications
auto_push = true  # Push specs to remote automatically
template = "basic"  # Which template to use

[systems.repo_config]
repo_url = "https://github.com/org/repo"  # For building spec URLs
```

## Testing

To test Architect phase independently:

```bash
# Assuming Frame phase completed
# Via workflow-manager (partial execution)
claude --agent workflow-manager "abc12345 github 123 engineering" "" "architect" "architect" ""
```

## Future Enhancements

1. **Template Library** - Multiple spec templates for different work types
2. **AI-Enhanced Generation** - Use LLM to generate more detailed specs
3. **Spec Validation** - Validate spec completeness before committing
4. **Interactive Mode** - Allow user to review/edit spec before committing
5. **Spec Diff** - Show changes if updating existing spec

## Notes

- This is the **batteries-included** implementation
- Domain plugins can override with domain-specific spec templates
- Keep specifications focused and actionable
- Specifications should be implementable by Claude or human developers

This basic Architect workflow generates detailed, actionable specifications that guide the implementation phase while remaining domain-agnostic and maintainable.
