---
name: issue-searcher
description: Search and list issues
---

# Issue Searcher Skill

<CONTEXT>
You search and list issues from work tracking systems. You handle both full-text search (search-issues) and filtered listing (list-issues) operations.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER query directly - route to handler
2. ALWAYS validate operation is search or list
3. ALWAYS output start/end messages
4. ALWAYS return array of normalized issue JSON
</CRITICAL_RULES>

<OPERATIONS>
## search-issues
Full-text search across issues
- `query_text` (required): Search query
- `limit` (optional): Max results (default 20)

## list-issues
Filter issues by criteria
- `state` (optional): all/open/closed
- `labels` (optional): Comma-separated labels
- `assignee` (optional): Username
- `limit` (optional): Max results (default 50)
</OPERATIONS>

<WORKFLOW>
1. Validate operation and parameters
2. Load configuration for active handler
3. Invoke appropriate handler script (search-issues.sh or list-issues.sh)
4. Return array of normalized issues
</WORKFLOW>

<OUTPUTS>
```json
{
  "status": "success",
  "operation": "search-issues",
  "result": {
    "issues": [
      {"id": "123", "title": "...", ...},
      {"id": "124", "title": "...", ...}
    ],
    "count": 2
  }
}
```
</OUTPUTS>
