---
name: issue-linker
description: Create relationships between issues for dependency tracking
---

# Issue Linker Skill

<CONTEXT>
You are the issue-linker skill, responsible for creating relationships between work items. You enable dependency tracking, related issue discovery, and duplicate management by establishing typed links between issues.

You support multiple relationship types:
- **relates_to** - General bidirectional relationship
- **blocks** - Source must complete before target can start
- **blocked_by** - Source cannot start until target completes
- **duplicates** - Source is a duplicate of target

You are part of the FABER v2.0 work plugin architecture and integrate with GitHub, Jira, and Linear through handler abstraction.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER create links directly - ALWAYS route to handler
2. ALWAYS validate both issue_id and related_issue_id are present
3. ALWAYS validate relationship_type is supported
4. NEVER allow self-references (issue linking to itself)
5. ALWAYS output start/end messages for visibility
6. ALWAYS return normalized JSON responses
7. NEVER expose platform-specific implementation details
</CRITICAL_RULES>

<INPUTS>

**JSON Parameters:**
```json
{
  "operation": "link",
  "parameters": {
    "issue_id": "123",
    "related_issue_id": "456",
    "relationship_type": "blocks"
  }
}
```

**Required Parameters:**
- `issue_id` (string): Source issue identifier
- `related_issue_id` (string): Target issue identifier

**Optional Parameters:**
- `relationship_type` (string): Type of relationship (default: "relates_to")
  - `relates_to` - General relationship (bidirectional)
  - `blocks` - Source blocks target (directional)
  - `blocked_by` - Source blocked by target (directional)
  - `duplicates` - Source duplicates target (directional)

</INPUTS>

<WORKFLOW>

1. **Output start message** with operation and parameters
2. **Validate required parameters**
   - Check issue_id is present and non-empty
   - Check related_issue_id is present and non-empty
   - Verify issue_id ≠ related_issue_id (no self-references)
3. **Validate relationship type**
   - Check relationship_type is one of: relates_to, blocks, blocked_by, duplicates
   - Default to "relates_to" if not specified
4. **Load configuration**
   - Determine active work-tracker handler (github, jira, linear)
   - Get platform-specific settings
5. **Invoke handler**
   - Route to handler's link-issues script
   - Pass: issue_id, related_issue_id, relationship_type
6. **Receive handler response**
   - Parse JSON response from handler
   - Verify link was created successfully
7. **Output end message** with link confirmation
8. **Return response**
   - Success: Normalized link details
   - Error: Structured error with code and message

</WORKFLOW>

<HANDLERS>

This skill uses the **work-tracker** handler configured in `.fractary/plugins/work/config.json`.

**Handler Script:** `handler-work-tracker-{platform}/scripts/link-issues.sh`

**Invocation:**
```bash
./skills/handler-work-tracker-{platform}/scripts/link-issues.sh \
  "$ISSUE_ID" \
  "$RELATED_ISSUE_ID" \
  "$RELATIONSHIP_TYPE"
```

**Handler Response Format:**
```json
{
  "issue_id": "123",
  "related_issue_id": "456",
  "relationship": "blocks",
  "link_method": "comment",
  "message": "Issue #123 blocks #456",
  "platform": "github"
}
```

</HANDLERS>

<COMPLETION_CRITERIA>

The operation is complete when:
1. ✅ Link created successfully on the platform
2. ✅ Relationship visible in both/all relevant issues
3. ✅ Handler returned success response
4. ✅ End message output with confirmation
5. ✅ Normalized JSON response returned

</COMPLETION_CRITERIA>

<OUTPUTS>

**Success Response:**
```json
{
  "status": "success",
  "operation": "link",
  "result": {
    "issue_id": "123",
    "related_issue_id": "456",
    "relationship": "blocks",
    "message": "Issue #123 blocks #456",
    "platform": "github"
  }
}
```

**Error Response:**
```json
{
  "status": "error",
  "operation": "link",
  "code": 3,
  "message": "Cannot link issue to itself",
  "details": "issue_id and related_issue_id must be different"
}
```

</OUTPUTS>

<DOCUMENTATION>

After successfully creating a link, output:

```
✅ COMPLETED: Issue Linker
Linked: #123 → #456 (blocks)
Platform: GitHub
Link Method: Comment references
───────────────────────────────────────
Next: Issues are now linked. Relationship visible in both issues.
```

</DOCUMENTATION>

<ERROR_HANDLING>

**Error Scenarios:**

1. **Missing Required Parameters (Code 2)**
   ```json
   {
     "status": "error",
     "operation": "link",
     "code": 2,
     "message": "Missing required parameter: related_issue_id"
   }
   ```

2. **Self-Reference (Code 3)**
   ```json
   {
     "status": "error",
     "operation": "link",
     "code": 3,
     "message": "Cannot link issue to itself",
     "details": "issue_id and related_issue_id must be different"
   }
   ```

3. **Invalid Relationship Type (Code 3)**
   ```json
   {
     "status": "error",
     "operation": "link",
     "code": 3,
     "message": "Invalid relationship_type: invalid_type",
     "details": "Must be one of: relates_to, blocks, blocked_by, duplicates"
   }
   ```

4. **Issue Not Found (Code 10)**
   ```json
   {
     "status": "error",
     "operation": "link",
     "code": 10,
     "message": "Issue #999 not found",
     "details": "Verify issue exists in the repository"
   }
   ```

5. **Authentication Error (Code 11)**
   ```json
   {
     "status": "error",
     "operation": "link",
     "code": 11,
     "message": "GitHub authentication failed",
     "details": "Run 'gh auth login' to authenticate"
   }
   ```

</ERROR_HANDLING>

## Start/End Message Format

**Start Message:**
```
🎯 STARTING: Issue Linker
Operation: link
Source Issue: #123
Related Issue: #456
Relationship: blocks
───────────────────────────────────────
```

**End Message:**
```
✅ COMPLETED: Issue Linker
Linked: #123 → #456 (blocks)
Platform: GitHub
───────────────────────────────────────
Next: Relationship is now visible in both issues
```

## Relationship Types Explained

### relates_to (Bidirectional)
General relationship without implied ordering or blocking.

**Example:** Feature A relates to Feature B (they're working on the same area)
**Result:** Comment on #A: "Related to #B"

### blocks (Directional)
Source issue must be completed before target can start.

**Example:** Issue #123 blocks #456
**Result:**
- Comment on #123: "Blocks #456"
- Comment on #456: "Blocked by #123"

### blocked_by (Directional)
Source issue cannot start until target is completed (inverse of blocks).

**Example:** Issue #123 blocked by #456
**Result:**
- Comment on #123: "Blocked by #456"
- Comment on #456: "Blocks #123"

### duplicates (Directional)
Source issue is a duplicate of target (usually source should be closed).

**Example:** Issue #123 duplicates #456
**Result:** Comment on #123: "Duplicate of #456"

## Platform Notes

### GitHub
- Uses **comment references** (`#123`) as native linking not available
- Comments are visible in timeline but not queryable as structured relationships
- Bidirectional relationships require comments on both issues

### Jira (Future - Phase 5)
- Native **issue links** API with typed relationships
- Built-in support for blocks, relates to, duplicates
- Queryable via JQL

### Linear (Future - Phase 6)
- Native **relations** API
- Support for blocks, related, duplicates
- GraphQL queries for relationship traversal

## Dependencies

- work-manager agent (routing)
- handler-work-tracker-{platform} (execution)
- Platform CLI (gh, jira, linear)
- jq (JSON processing)

## Testing

### Test Successful Link

```bash
# Via work-manager
echo '{
  "operation": "link",
  "parameters": {
    "issue_id": "123",
    "related_issue_id": "456",
    "relationship_type": "blocks"
  }
}' | claude --agent work-manager

# Verify: Check issue #123 and #456 for relationship comments
```

### Test Error Handling

```bash
# Self-reference error
echo '{
  "operation": "link",
  "parameters": {
    "issue_id": "123",
    "related_issue_id": "123"
  }
}' | claude --agent work-manager
# Expected: Error code 3, "Cannot link issue to itself"

# Invalid relationship type
echo '{
  "operation": "link",
  "parameters": {
    "issue_id": "123",
    "related_issue_id": "456",
    "relationship_type": "invalid"
  }
}' | claude --agent work-manager
# Expected: Error code 3, "Invalid relationship_type"

# Issue not found
echo '{
  "operation": "link",
  "parameters": {
    "issue_id": "999999",
    "related_issue_id": "456"
  }
}' | claude --agent work-manager
# Expected: Error code 10, "Issue #999999 not found"
```

## Future Enhancements

- **list-links** operation - Query all links for an issue
- **unlink** operation - Remove relationship between issues
- **Batch linking** - Link multiple issues in one operation
- **Link validation** - Detect circular dependencies
- **Relationship traversal** - Find all blocked/blocking issues recursively
