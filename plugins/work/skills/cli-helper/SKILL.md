---
name: cli-helper
description: Shared utilities for invoking Fractary CLI from work plugin skills
model: haiku
---

# CLI Helper Skill

<CONTEXT>
You are the cli-helper skill providing shared utilities for invoking the Fractary CLI from work plugin skills. This skill is a library, not directly invoked by agents.

The Fractary CLI (`@fractary/cli`) provides unified work tracking operations across platforms (GitHub, Jira, Linear). Skills use this helper to invoke CLI commands and parse JSON responses.
</CONTEXT>

<CRITICAL_RULES>
1. This skill is a LIBRARY - not directly invoked by agents
2. Other skills import/use the invoke-cli.sh script
3. All CLI commands MUST use --json flag for programmatic output
4. ALWAYS check CLI availability before invocation
5. ALWAYS handle CLI errors and map to plugin error format
</CRITICAL_RULES>

## CLI Invocation Pattern

Skills should invoke the CLI using this pattern:

```bash
# Direct CLI invocation (recommended)
result=$(fractary work <subcommand> [options] --json 2>&1)
exit_code=$?

# Or using the helper script
HELPER_SCRIPT="plugins/work/skills/cli-helper/scripts/invoke-cli.sh"
result=$(bash "$HELPER_SCRIPT" <subcommand> [options] --json 2>&1)
exit_code=$?
```

## Available CLI Commands

### Issue Operations
```bash
fractary work issue create --title "Title" --body "Body" --labels "a,b" --json
fractary work issue fetch <number> --json
fractary work issue update <number> --title "New title" --json
fractary work issue close <number> --json
fractary work issue search --state open --limit 10 --json
```

### Comment Operations
```bash
fractary work comment create <issue_number> --body "Comment text" --json
fractary work comment list <issue_number> --json
```

### Label Operations
```bash
fractary work label add <issue_number> --labels "label1,label2" --json
fractary work label remove <issue_number> --labels "label1" --json
fractary work label list --json
```

### Milestone Operations
```bash
fractary work milestone list --json
fractary work milestone set <issue_number> --milestone "v1.0" --json
```

## Response Format

CLI returns JSON with consistent structure:

### Success Response
```json
{
  "status": "success",
  "data": {
    // Operation-specific data
  }
}
```

### Error Response
```json
{
  "status": "error",
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message",
    "details": {}
  }
}
```

## Mapping CLI Response to Plugin Response

Skills should map CLI responses to the standard plugin response format:

```bash
# Parse CLI JSON response
cli_response=$(fractary work issue create --title "$TITLE" --json 2>&1)
cli_status=$(echo "$cli_response" | jq -r '.status')

if [ "$cli_status" = "success" ]; then
    # Extract data and build plugin response
    issue_id=$(echo "$cli_response" | jq -r '.data.number')
    issue_url=$(echo "$cli_response" | jq -r '.data.url')

    # Return plugin format
    cat <<EOF
{
  "status": "success",
  "operation": "create-issue",
  "result": {
    "id": "$issue_id",
    "identifier": "#$issue_id",
    "url": "$issue_url",
    "platform": "github"
  }
}
EOF
else
    # Extract error and return plugin error format
    error_code=$(echo "$cli_response" | jq -r '.error.code // "UNKNOWN_ERROR"')
    error_msg=$(echo "$cli_response" | jq -r '.error.message // "Unknown error"')

    cat <<EOF
{
  "status": "error",
  "operation": "create-issue",
  "code": "$error_code",
  "message": "$error_msg"
}
EOF
fi
```

## Error Handling

Map CLI errors to plugin error codes:

| CLI Exit Code | CLI Error Code | Plugin Error Code | Description |
|---------------|----------------|-------------------|-------------|
| 0 | - | - | Success |
| 1 | CLI_NOT_FOUND | 1 | CLI not installed |
| 1 | AUTH_FAILED | 11 | Authentication failed |
| 1 | NOT_FOUND | 3 | Resource not found |
| 1 | NETWORK_ERROR | 12 | Network connectivity issue |
| 1 | VALIDATION_ERROR | 2 | Invalid parameters |
| 1 | API_ERROR | 10 | Platform API error |

## Dependencies

- `@fractary/cli >= 0.3.0` - Fractary CLI with work module
- `jq` - JSON parsing
- `bash` - Shell execution

## Usage by Other Skills

Skills reference this helper by:

1. **Direct CLI invocation** (recommended):
   ```bash
   fractary work issue create --title "Title" --json
   ```

2. **Using helper script** (for version checking):
   ```bash
   bash plugins/work/skills/cli-helper/scripts/invoke-cli.sh issue create --title "Title" --json
   ```

The helper script adds:
- CLI availability check
- Version requirement validation
- Consistent error messages

## Testing

```bash
# Test CLI availability
fractary --version

# Test work module
fractary work --help

# Test JSON output
fractary work issue fetch 1 --json
```
