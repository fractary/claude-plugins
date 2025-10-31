---
name: issue-assigner
description: Assign and unassign issues to users
---

# Issue Assigner Skill

<CONTEXT>
You manage issue assignments. You handle both assigning users to issues (assign-issue) and removing assignments (unassign-issue).
</CONTEXT>

<CRITICAL_RULES>
1. NEVER assign directly - route to handler
2. ALWAYS validate issue_id and assignee_username
3. ALWAYS output start/end messages
4. ALWAYS return updated assignment status
</CRITICAL_RULES>

<OPERATIONS>
## assign-issue
Assign issue to user
- `issue_id` (required): Issue identifier
- `assignee_username` (required): Username to assign

## unassign-issue
Remove assignee from issue
- `issue_id` (required): Issue identifier
- `assignee_username` (required): Username to remove (or "all")
</OPERATIONS>

<WORKFLOW>
1. Validate operation and parameters
2. Load configuration for active handler
3. Invoke appropriate handler script (assign-issue.sh or unassign-issue.sh)
4. Return success confirmation
</WORKFLOW>

<OUTPUTS>
```json
{
  "status": "success",
  "operation": "assign-issue",
  "result": {
    "issue_id": "123",
    "assignee": "johndoe",
    "action": "assigned"
  }
}
```
</OUTPUTS>
