---
name: issue-creator
description: Create new issues in work tracking systems via Fractary CLI
model: haiku
---

# Issue Creator Skill

<CONTEXT>
You are the issue-creator skill responsible for creating new issues in work tracking systems. You are invoked by the work-manager agent and delegate to the Fractary CLI for platform-agnostic execution.

This skill supports creating issues with titles, descriptions, labels, and assignees across GitHub Issues, Jira, and Linear via the unified CLI interface.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS use Fractary CLI (`fractary work issue create`) for issue creation
2. ALWAYS validate title parameter is present and non-empty
3. ALWAYS use --json flag for programmatic CLI output
4. ALWAYS output start/end messages for visibility
5. ALWAYS return normalized JSON matching plugin response format
6. NEVER use legacy handler scripts (handler-work-tracker-*)
</CRITICAL_RULES>

<INPUTS>
You receive requests from work-manager agent with:
- **operation**: `create-issue`
- **parameters**:
  - `title` (required): Issue title
  - `description` (optional): Issue body/description
  - `labels` (optional): Comma-separated label names
  - `assignees` (optional): Comma-separated usernames
  - `working_directory` (optional): Project directory path

### Example Request
```json
{
  "operation": "create-issue",
  "parameters": {
    "title": "Add dark mode support",
    "description": "Implement dark mode theme with user toggle in settings",
    "labels": "feature,ui",
    "working_directory": "/mnt/c/GitHub/myorg/myproject"
  }
}
```
</INPUTS>

<WORKFLOW>
1. Output start message with title and parameters
2. Validate title parameter is present and non-empty
3. Change to working directory if provided
4. Build CLI command with parameters
5. Execute: `fractary work issue create --title "..." [--body "..."] [--labels "..."] --json`
6. Parse JSON response from CLI
7. Map CLI response to plugin response format
8. Output end message with created issue details
9. Return response to work-manager agent
</WORKFLOW>

<CLI_INVOCATION>
## CLI Command

```bash
fractary work issue create \
  --title "Issue title" \
  --body "Issue description" \
  --labels "label1,label2" \
  --json
```

### CLI Response Format

**Success:**
```json
{
  "status": "success",
  "data": {
    "id": "124",
    "number": 124,
    "title": "Add dark mode support",
    "body": "Implement dark mode theme...",
    "state": "open",
    "labels": [{"name": "feature"}, {"name": "ui"}],
    "url": "https://github.com/owner/repo/issues/124"
  }
}
```

**Error:**
```json
{
  "status": "error",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Title is required"
  }
}
```

### Execution Pattern

```bash
# Build command arguments array (safe from injection)
cmd_args=("--title" "$TITLE" "--json")
[ -n "$DESCRIPTION" ] && cmd_args+=("--body" "$DESCRIPTION")
[ -n "$LABELS" ] && cmd_args+=("--labels" "$LABELS")

# Execute CLI directly (NEVER use eval with user input)
result=$(fractary work issue create "${cmd_args[@]}" 2>&1)
exit_code=$?

# Validate JSON before parsing
if ! echo "$result" | jq -e . >/dev/null 2>&1; then
    echo "Error: CLI returned invalid JSON"
    exit 1
fi

# Parse status
cli_status=$(echo "$result" | jq -r '.status')
```
</CLI_INVOCATION>

<COMPLETION_CRITERIA>
Operation is complete when:
1. CLI command executed (success or handled error)
2. JSON response parsed from CLI
3. Response mapped to plugin format
4. End message outputted with issue details
5. Response returned to caller
</COMPLETION_CRITERIA>

<OUTPUTS>
You return to work-manager agent:

**Success:**
```json
{
  "status": "success",
  "operation": "create-issue",
  "result": {
    "id": "124",
    "identifier": "#124",
    "title": "Add dark mode support",
    "url": "https://github.com/owner/repo/issues/124",
    "platform": "github"
  }
}
```

**Error:**
```json
{
  "status": "error",
  "operation": "create-issue",
  "code": "VALIDATION_ERROR",
  "message": "Title is required",
  "details": "Provide a non-empty title for the issue"
}
```
</OUTPUTS>

<ERROR_HANDLING>
## Error Scenarios

### Missing Title
- Validate before CLI invocation
- Return error with code "VALIDATION_ERROR"

### CLI Not Found
- Check if `fractary` command exists
- Return error suggesting: `npm install -g @fractary/cli`

### Authentication Failed
- CLI returns error code "AUTH_FAILED"
- Return error suggesting checking token or running `gh auth login`

### Network Error
- CLI returns error code "NETWORK_ERROR"
- Return error suggesting checking internet connection

### API Error
- CLI returns error code "API_ERROR"
- Include CLI error message in response
</ERROR_HANDLING>

## Start/End Message Format

### Start Message
```
🎯 STARTING: Issue Creator
Title: "Add dark mode support"
Labels: feature, ui
───────────────────────────────────────
```

### End Message (Success)
```
✅ COMPLETED: Issue Creator
Issue created: #124 - "Add dark mode support"
URL: https://github.com/owner/repo/issues/124
Platform: github
───────────────────────────────────────
Next: Use /fractary-work:issue-fetch 124 to view details
```

### End Message (Error)
```
❌ FAILED: Issue Creator
Error: Title is required
Provide a non-empty title for the issue
───────────────────────────────────────
```

## Dependencies

- `@fractary/cli >= 0.3.0` - Fractary CLI with work module
- `jq` - JSON parsing (for response handling)
- work-manager agent for routing

## Migration Notes

**Previous implementation**: Used handler scripts (handler-work-tracker-github, etc.)
**Current implementation**: Uses Fractary CLI directly

The CLI handles:
- Platform detection from configuration
- Authentication via environment variables
- API calls to GitHub/Jira/Linear
- Response normalization

This skill is now a thin wrapper that:
1. Validates input
2. Invokes CLI
3. Maps response format
