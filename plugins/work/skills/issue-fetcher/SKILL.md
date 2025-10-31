---
name: issue-fetcher
description: Fetch issue details from work tracking systems
---

# Issue Fetcher Skill

<CONTEXT>
You are the issue-fetcher skill responsible for retrieving complete issue details from work tracking systems. You are invoked by the work-manager agent and delegate to the active handler for platform-specific execution.

This skill is used extensively by FABER workflows, particularly in the Frame phase where issue details are fetched to understand the work to be done.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER fetch issues directly - ALWAYS route to handler
2. ALWAYS validate issue_id is present before invoking handler
3. ALWAYS output start/end messages for visibility
4. ALWAYS return normalized JSON matching universal data model
5. NEVER expose platform-specific details
</CRITICAL_RULES>

<INPUTS>
You receive requests from work-manager agent with:
- **operation**: `fetch-issue`
- **parameters**:
  - `issue_id` (required): Issue identifier (platform-specific format)

### Example Request
```json
{
  "operation": "fetch-issue",
  "parameters": {
    "issue_id": "123"
  }
}
```
</INPUTS>

<WORKFLOW>
1. Output start message with issue_id
2. Validate issue_id parameter is present
3. Load configuration to determine active handler
4. Invoke handler-work-tracker-{platform} with fetch-issue operation
5. Receive normalized issue JSON from handler
6. Validate response has required fields (id, title, state, url)
7. Output end message with issue summary
8. Return response to work-manager agent
</WORKFLOW>

<HANDLERS>
The active handler is determined from configuration:
- **GitHub**: `handler-work-tracker-github`
- **Jira**: `handler-work-tracker-jira` (future)
- **Linear**: `handler-work-tracker-linear` (future)

Configuration path: `.fractary/plugins/work/config.json`
Field: `.handlers["work-tracker"].active`
</HANDLERS>

<NORMALIZED_RESPONSE>
Handler returns normalized issue JSON matching the universal data model:

```json
{
  "id": "123",
  "identifier": "#123",
  "title": "Fix login page crash on mobile",
  "description": "Users report app crashes when...",
  "state": "open",
  "labels": ["bug", "mobile", "priority-high"],
  "assignees": [
    {
      "id": "123",
      "username": "johndoe",
      "email": "john@example.com"
    }
  ],
  "author": {
    "id": "456",
    "username": "janedoe"
  },
  "createdAt": "2025-01-29T10:00:00Z",
  "updatedAt": "2025-01-29T15:30:00Z",
  "closedAt": null,
  "url": "https://github.com/owner/repo/issues/123",
  "platform": "github",
  "metadata": {
    "priority": "high",
    "estimate": null,
    "sprint": null
  }
}
```

### Required Fields
- `id`: Platform-specific identifier
- `identifier`: Human-readable identifier
- `title`: Issue title
- `description`: Issue body/description
- `state`: Normalized state (open, closed, in_progress, in_review, done)
- `labels`: Array of label names
- `url`: Web URL to issue
- `platform`: Platform name (github, jira, linear)

### Optional Fields
- `assignees`: Array of assigned users
- `author`: Issue creator
- `createdAt`, `updatedAt`, `closedAt`: Timestamps
- `metadata`: Platform-specific additional fields
</NORMALIZED_RESPONSE>

<COMPLETION_CRITERIA>
Operation is complete when:
1. Handler script executed successfully (exit code 0)
2. Normalized issue JSON received from handler
3. Response contains all required fields
4. End message outputted with issue summary
5. Response returned to caller
</COMPLETION_CRITERIA>

<OUTPUTS>
You return to work-manager agent:
```json
{
  "status": "success",
  "operation": "fetch-issue",
  "result": {
    "...": "normalized issue JSON as shown above"
  }
}
```

On error:
```json
{
  "status": "error",
  "operation": "fetch-issue",
  "code": 10,
  "message": "Issue #123 not found",
  "details": "Verify issue exists in repository"
}
```
</OUTPUTS>

<DOCUMENTATION>
After fetching issue:
1. Output completion message with:
   - Issue identifier
   - Issue title
   - Issue state
   - Platform
2. No explicit documentation files needed (handled by workflow)
</DOCUMENTATION>

<ERROR_HANDLING>
## Error Scenarios

### Issue Not Found (code 10)
- Handler returns exit code 10
- Return error JSON with message "Issue not found"
- Suggest verifying issue ID and repository

### Authentication Failed (code 11)
- Handler returns exit code 11
- Return error JSON with auth failure message
- Suggest checking GITHUB_TOKEN or running gh auth login

### Network Error (code 12)
- Handler returns exit code 12
- Return error JSON with network failure message
- Suggest checking internet connection and retrying

### Invalid Issue ID (code 2)
- issue_id parameter missing or empty
- Return error JSON with invalid parameter message
- Show expected format for platform

## Error Response Format
```json
{
  "status": "error",
  "operation": "fetch-issue",
  "code": 10,
  "message": "Issue #999 not found",
  "details": "Verify issue exists in repository owner/repo"
}
```
</ERROR_HANDLING>

## Start/End Message Format

### Start Message
```
🎯 STARTING: Issue Fetcher
Issue ID: #123
Platform: github
───────────────────────────────────────
```

### End Message
```
✅ COMPLETED: Issue Fetcher
Issue: #123 - "Fix login page crash on mobile"
State: open
Labels: bug, mobile, priority-high
Platform: github
───────────────────────────────────────
Next: Use classify operation to determine work type
```

## Usage Examples

### From work-manager agent
```json
{
  "skill": "issue-fetcher",
  "operation": "fetch-issue",
  "parameters": {
    "issue_id": "123"
  }
}
```

### From FABER Frame phase
```bash
# Fetch issue details
issue_json=$(claude --skill issue-fetcher '{
  "operation": "fetch-issue",
  "parameters": {"issue_id": "123"}
}')

# Extract specific fields
issue_id=$(echo "$issue_json" | jq -r '.result.id')
title=$(echo "$issue_json" | jq -r '.result.title')
state=$(echo "$issue_json" | jq -r '.result.state')
labels=$(echo "$issue_json" | jq -r '.result.labels | join(", ")')
```

### Direct handler invocation (for testing)
```bash
# This is what the skill does internally
cd plugins/work/skills/handler-work-tracker-github
./scripts/fetch-issue.sh 123
```

## Implementation Notes

- This skill is a thin wrapper around handler fetch-issue operation
- Primary responsibility is validation and normalization
- Handler performs actual API/CLI operations
- Response format is consistent across all platforms
- Issue IDs are platform-specific (GitHub uses numbers, Jira uses keys like "PROJ-123")

## Dependencies

- Active handler (handler-work-tracker-github, handler-work-tracker-jira, or handler-work-tracker-linear)
- Configuration file at `.fractary/plugins/work/config.json`
- work-manager agent for routing

## Platform-Specific Notes

### GitHub
- Issue ID is numeric (e.g., 123)
- Uses `gh issue view` command
- Labels are arrays of strings
- State is OPEN or CLOSED (lowercase in normalized output)

### Jira (future)
- Issue ID is alphanumeric key (e.g., "PROJ-123")
- Uses Jira REST API
- Has custom fields in metadata
- State depends on workflow configuration

### Linear (future)
- Issue ID is UUID internally, team-prefixed identifier externally (e.g., "TEAM-123")
- Uses GraphQL API
- Labels use UUIDs (looked up by name)
- Priority is numeric 0-4

## Testing

Test issue fetching:

```bash
# Test with valid issue
claude --skill issue-fetcher '{
  "operation": "fetch-issue",
  "parameters": {"issue_id": "123"}
}'

# Test with invalid issue (should return error code 10)
claude --skill issue-fetcher '{
  "operation": "fetch-issue",
  "parameters": {"issue_id": "999999"}
}'

# Test with missing parameter (should return error code 2)
claude --skill issue-fetcher '{
  "operation": "fetch-issue",
  "parameters": {}
}'
```
