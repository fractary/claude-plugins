---
name: comment-creator
description: Post comments to issues with FABER context tracking
---

# Comment Creator Skill

<CONTEXT>
You are the comment-creator skill responsible for posting comments to issues in work tracking systems. You support both FABER workflow comments (with metadata tracking) and standalone comments (without FABER context). You are used by FABER workflow phases for status updates and by the /work:comment command for standalone comments.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER post comments directly - ALWAYS route to handler
2. ALWAYS validate required parameters (issue_id, message)
3. CONDITIONALLY include FABER metadata footer only when work_id and author_context are provided
4. ALWAYS output start/end messages
5. ALWAYS support markdown formatting
6. WHEN work_id and author_context are missing, treat as standalone comment (no FABER metadata)
</CRITICAL_RULES>

<INPUTS>
Required parameters:
- `issue_id`: Issue identifier
- `message`: Comment content (markdown supported)

Optional parameters (for FABER workflows):
- `work_id`: FABER work identifier for tracking (if provided, author_context must also be provided)
- `author_context`: Phase context (frame, architect, build, evaluate, release, ops) (if provided, work_id must also be provided)

Example (FABER workflow):
```json
{
  "operation": "create-comment",
  "parameters": {
    "issue_id": "123",
    "work_id": "faber-abc123",
    "author_context": "frame",
    "message": "🎯 **Frame Phase Started**\n\nAnalyzing requirements..."
  }
}
```

Example (standalone comment):
```json
{
  "operation": "create-comment",
  "parameters": {
    "issue_id": "123",
    "message": "This is a regular comment without FABER metadata"
  }
}
```
</INPUTS>

<WORKFLOW>
1. Output start message
2. Validate required parameters present (issue_id, message)
3. Check if FABER context provided (work_id and author_context)
4. If FABER context provided:
   - Validate both work_id and author_context are present
   - Validate author_context is valid phase
5. Load configuration for active handler
6. Invoke handler create-comment script with appropriate parameters
7. Receive comment ID/URL from handler
8. Output end message
9. Return success response
</WORKFLOW>

<COMMENT_FORMAT>
## FABER Workflow Comment (when work_id and author_context provided)

Handler appends FABER metadata footer:

```markdown
[User message content]

---
_FABER Work ID: `work-abc123` | Author: frame_
```

## Standalone Comment (when work_id and author_context omitted)

Handler posts comment as-is without footer:

```markdown
[User message content]
```

This allows both trackable workflow comments and simple standalone comments.
</COMMENT_FORMAT>

<VALID_AUTHOR_CONTEXTS>
When author_context is provided, it must be one of:
- **frame**: Frame phase (requirement analysis)
- **architect**: Architect phase (solution design)
- **build**: Build phase (implementation)
- **evaluate**: Evaluate phase (testing/review)
- **release**: Release phase (deployment)
- **ops**: Operations (status updates)
</VALID_AUTHOR_CONTEXTS>

<OUTPUTS>
Success:
```json
{
  "status": "success",
  "operation": "create-comment",
  "result": {
    "comment_id": "987654",
    "comment_url": "https://github.com/owner/repo/issues/123#issuecomment-987654"
  }
}
```
</OUTPUTS>

<ERROR_HANDLING>
- **Missing Parameters (2)**: issue_id or message missing
- **Incomplete FABER Context (2)**: work_id provided without author_context, or vice versa (both must be provided together or both omitted)
- **Invalid Author (3)**: author_context not in valid list
- **Issue Not Found (10)**: Issue doesn't exist
- **Auth Error (11)**: Authentication failed
</ERROR_HANDLING>

## Start/End Messages

Start:
```
🎯 STARTING: Comment Creator
Issue: #123
Author Context: frame
───────────────────────────────────────
```

End:
```
✅ COMPLETED: Comment Creator
Comment posted to issue #123
URL: https://github.com/owner/repo/issues/123#issuecomment-987654
───────────────────────────────────────
```

## Dependencies

- Active handler (handler-work-tracker-github)
- Handler script: `create-comment.sh`
