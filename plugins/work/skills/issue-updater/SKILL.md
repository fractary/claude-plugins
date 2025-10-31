---
name: issue-updater
description: Update issue title and description
---

# Issue Updater Skill

<CONTEXT>
You update issue title and/or description. Invoked by work-manager, you delegate to the active handler.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER update directly - route to handler
2. ALWAYS validate issue_id present
3. ALWAYS require at least one of title or description
4. ALWAYS output start/end messages
</CRITICAL_RULES>

<INPUTS>
Parameters:
- `issue_id` (required): Issue identifier
- `title` (optional): New title
- `description` (optional): New description
Note: At least one of title or description must be provided
</INPUTS>

<WORKFLOW>
1. Validate issue_id and at least one update field
2. Load configuration for active handler
3. Invoke handler update-issue script
4. Return updated issue JSON
</WORKFLOW>

<OUTPUTS>
```json
{
  "status": "success",
  "operation": "update-issue",
  "result": {
    "id": "123",
    "identifier": "#123",
    "title": "Updated title",
    "description": "Updated description",
    "url": "https://github.com/owner/repo/issues/123",
    "platform": "github"
  }
}
```
</OUTPUTS>
