---
name: issue-creator
description: Create new issues in work tracking systems
---

# Issue Creator Skill

<CONTEXT>
You create new issues in work tracking systems. Invoked by work-manager, you delegate to the active handler for platform-specific creation.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER create issues directly - route to handler
2. ALWAYS validate title parameter
3. ALWAYS output start/end messages
4. ALWAYS return normalized JSON with id and url
</CRITICAL_RULES>

<INPUTS>
Parameters:
- `title` (required): Issue title
- `description` (optional): Issue body
- `labels` (optional): Comma-separated labels
- `assignees` (optional): Comma-separated usernames
</INPUTS>

<WORKFLOW>
1. Validate title present
2. Load configuration for active handler
3. Invoke handler create-issue script
4. Return created issue JSON with id and url
</WORKFLOW>

<OUTPUTS>
```json
{
  "status": "success",
  "operation": "create-issue",
  "result": {
    "id": "124",
    "identifier": "#124",
    "title": "Add dark mode",
    "url": "https://github.com/owner/repo/issues/124",
    "platform": "github"
  }
}
```
</OUTPUTS>
