---
name: issue-creator
description: Create new issues in work tracking systems
---

# Issue Creator Skill

<CONTEXT>
You are the issue-creator skill responsible for creating new issues in work tracking systems. You are invoked by the work-manager agent and delegate to the active handler for platform-specific execution.

This skill supports creating issues with titles, descriptions, labels, and assignees across GitHub Issues, Jira, and Linear.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER create issues directly - ALWAYS route to handler
2. ALWAYS validate title parameter is present and non-empty
3. ALWAYS output start/end messages for visibility
4. ALWAYS return normalized JSON matching universal data model
5. NEVER expose platform-specific implementation details
</CRITICAL_RULES>

<INPUTS>
You receive requests from work-manager agent with:
- **operation**: `create-issue`
- **parameters**:
  - `title` (required): Issue title
  - `description` (optional): Issue body/description
  - `labels` (optional): Comma-separated label names
  - `assignees` (optional): Comma-separated usernames

### Example Request
```json
{
  "operation": "create-issue",
  "parameters": {
    "title": "Add dark mode support",
    "description": "Implement dark mode theme with user toggle in settings",
    "labels": "feature,ui",
    "assignees": "johndoe"
  }
}
```
</INPUTS>

<WORKFLOW>
1. Output start message with title and parameters
2. Validate title parameter is present and non-empty
3. Load configuration to determine active handler
4. Determine handler based on config: `.handlers["work-tracker"].active`
5. Invoke handler-work-tracker-{platform} skill with create-issue operation
6. Receive normalized issue JSON from handler (id, identifier, title, url, platform)
7. Validate response has required fields (id, url)
8. Output end message with created issue details
9. Return response to work-manager agent
</WORKFLOW>

<HANDLERS>
The active handler is determined from configuration:
- **GitHub**: `handler-work-tracker-github`
- **Jira**: `handler-work-tracker-jira` (future)
- **Linear**: `handler-work-tracker-linear` (future)

Configuration path: `.fractary/plugins/work/config.json`
Field: `.handlers["work-tracker"].active`

### How to Invoke Handler

Read the configuration file to determine the active handler:

```bash
# Load configuration
CONFIG_FILE=".fractary/plugins/work/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration not found at $CONFIG_FILE"
    exit 1
fi

# Extract active handler
ACTIVE_HANDLER=$(jq -r '.handlers["work-tracker"].active' "$CONFIG_FILE")
```

Then use the Bash tool to invoke the handler script:

```bash
# Invoke handler script
SCRIPT_PATH="plugins/work/skills/handler-work-tracker-${ACTIVE_HANDLER}/scripts/create-issue.sh"
bash "$SCRIPT_PATH" "$TITLE" "$DESCRIPTION" "$LABELS" "$ASSIGNEES"
```

The handler script returns JSON to stdout on success.
</HANDLERS>

<NORMALIZED_RESPONSE>
Handler returns normalized issue JSON:

```json
{
  "id": "124",
  "identifier": "#124",
  "title": "Add dark mode support",
  "url": "https://github.com/owner/repo/issues/124",
  "platform": "github"
}
```

### Required Fields
- `id`: Platform-specific issue identifier (string)
- `identifier`: Human-readable identifier (e.g., "#124", "PROJ-124")
- `title`: Issue title (echoed from input)
- `url`: Web URL to view the created issue
- `platform`: Platform name (github, jira, linear)

### Script Exit Codes
- `0`: Success - issue created
- `2`: Invalid parameters (missing title, empty title)
- `10`: Issue creation failed (API error)
- `11`: Authentication failed
- `12`: Network error
</NORMALIZED_RESPONSE>

<COMPLETION_CRITERIA>
Operation is complete when:
1. Handler script executed successfully (exit code 0)
2. Normalized issue JSON received from handler
3. Response contains all required fields (id, identifier, title, url, platform)
4. End message outputted with issue details
5. Response returned to caller
</COMPLETION_CRITERIA>

<OUTPUTS>
You return to work-manager agent:
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

On error:
```json
{
  "status": "error",
  "operation": "create-issue",
  "code": 2,
  "message": "Title is required",
  "details": "Provide a non-empty title for the issue"
}
```
</OUTPUTS>

<DOCUMENTATION>
After creating issue:
1. Output completion message with:
   - Issue identifier (e.g., #124)
   - Issue title
   - Issue URL
   - Platform
2. No explicit documentation files needed (handled by workflow)
</DOCUMENTATION>

<ERROR_HANDLING>
## Error Scenarios

### Missing Title (code 2)
- Title parameter missing or empty string
- Return error JSON with message "Title is required"
- Suggest providing a non-empty title

### Invalid Parameters (code 2)
- Labels format invalid
- Assignees format invalid
- Return error JSON with parameter validation message
- Show expected format

### Authentication Failed (code 11)
- Handler returns exit code 11
- Return error JSON with auth failure message
- Suggest checking token or running `gh auth login` (GitHub)

### Network Error (code 12)
- Handler returns exit code 12
- Return error JSON with network failure message
- Suggest checking internet connection and retrying

### Issue Creation Failed (code 10)
- Handler returns exit code 10
- API rejected the request (permissions, validation, etc.)
- Return error JSON with creation failure message
- Include handler error output if available

### Handler Not Found (code 3)
- Configuration specifies invalid handler
- Handler script doesn't exist
- Return error JSON with handler not found message
- Suggest running `/work:init` to configure plugin

## Error Response Format
```json
{
  "status": "error",
  "operation": "create-issue",
  "code": 2,
  "message": "Title is required",
  "details": "Provide a non-empty title for the issue"
}
```
</ERROR_HANDLING>

## Start/End Message Format

### Start Message
```
🎯 STARTING: Issue Creator
Title: "Add dark mode support"
Labels: feature, ui
Assignees: johndoe
Platform: github
───────────────────────────────────────
```

### End Message (Success)
```
✅ COMPLETED: Issue Creator
Issue created: #124 - "Add dark mode support"
URL: https://github.com/owner/repo/issues/124
Platform: github
───────────────────────────────────────
Next: Use /work:issue fetch 124 to view details
```

### End Message (Error)
```
❌ FAILED: Issue Creator
Error: Title is required
Provide a non-empty title for the issue
───────────────────────────────────────
```

## Usage Examples

### From work-manager agent
```json
{
  "skill": "issue-creator",
  "operation": "create-issue",
  "parameters": {
    "title": "Add dark mode support",
    "description": "Implement dark mode theme with user toggle",
    "labels": "feature,ui",
    "assignees": "johndoe"
  }
}
```

### From command line (testing)
```bash
# Create issue with all parameters
claude --skill issue-creator '{
  "operation": "create-issue",
  "parameters": {
    "title": "Fix login bug",
    "description": "Login fails on Safari",
    "labels": "bug,urgent",
    "assignees": "@me"
  }
}'

# Create issue with title only
claude --skill issue-creator '{
  "operation": "create-issue",
  "parameters": {
    "title": "Update documentation"
  }
}'
```

### Direct handler invocation (for testing)
```bash
# This is what the skill does internally
cd plugins/work/skills/handler-work-tracker-github
./scripts/create-issue.sh "Add dark mode" "Implement theme toggle" "feature,ui" "johndoe"
```

## Implementation Notes

- This skill is a thin wrapper around handler create-issue operation
- Primary responsibility is validation and normalization
- Handler performs actual API/CLI operations
- Response format is consistent across all platforms
- Title is the only required parameter
- Labels and assignees are comma-separated strings
- Platform-specific formatting is handled by handlers

## Dependencies

- Active handler (handler-work-tracker-github, handler-work-tracker-jira, or handler-work-tracker-linear)
- Configuration file at `.fractary/plugins/work/config.json`
- work-manager agent for routing
- jq command for JSON parsing

## Platform-Specific Notes

### GitHub
- Issue ID is numeric (e.g., 124)
- Uses `gh issue create` command
- Labels are simple strings
- Assignees use @username format
- Returns GitHub issue URL

### Jira (future)
- Issue key is alphanumeric (e.g., "PROJ-124")
- Uses Jira REST API
- Issue type determined from config mapping
- Custom fields may be supported
- Returns Jira issue URL

### Linear (future)
- Issue ID is UUID internally, team-prefixed externally (e.g., "TEAM-124")
- Uses GraphQL API
- Labels use UUIDs (looked up by name)
- Priority can be specified
- Returns Linear issue URL

## Testing

Test issue creation:

```bash
# Test with valid parameters
claude --skill issue-creator '{
  "operation": "create-issue",
  "parameters": {
    "title": "Test issue",
    "description": "Testing issue creation",
    "labels": "test"
  }
}'

# Test with missing title (should return error code 2)
claude --skill issue-creator '{
  "operation": "create-issue",
  "parameters": {
    "description": "Missing title"
  }
}'

# Test with empty title (should return error code 2)
claude --skill issue-creator '{
  "operation": "create-issue",
  "parameters": {
    "title": ""
  }
}'

# Test with invalid labels format (should handle gracefully)
claude --skill issue-creator '{
  "operation": "create-issue",
  "parameters": {
    "title": "Test",
    "labels": "invalid label with spaces"
  }
}'
```

## Configuration Example

Ensure configuration exists at `.fractary/plugins/work/config.json`:

```json
{
  "handlers": {
    "work-tracker": {
      "active": "github",
      "github": {
        "owner": "myorg",
        "repo": "myrepo"
      }
    }
  }
}
```

Run `/work:init` to create configuration if it doesn't exist.
