# Workflow: Invoke Fractary CLI

This workflow describes how to invoke fractary CLI codex commands from within the plugin architecture.

## Purpose

The cli-helper skill is a **shared utility** that other codex skills delegate to when they need to execute CLI commands. This provides:
- Clean separation of concerns
- Centralized CLI invocation logic
- Consistent error handling
- Support for both global and npx installations

## Prerequisites

- `@fractary/cli` installed globally OR
- `npx` available (npm 5.2+) as fallback

## Input Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `command` | Yes | CLI command name (e.g., "fetch", "cache", "health") |
| `args` | No | Additional arguments to pass to the command |

## Steps

### Step 1: Validate CLI Installation

Before invoking the CLI, validate that it's available:

```bash
./scripts/validate-cli.sh
```

**Output**: JSON with installation status
```json
{
  "status": "success",
  "cli_available": true,
  "cli_source": "global",
  "cli_version": "0.3.2"
}
```

If validation fails, return error to calling skill with installation instructions.

### Step 2: Invoke CLI Command

Execute the CLI command with JSON output:

```bash
./scripts/invoke-cli.sh <command> [args...] --json
```

**Examples**:
```bash
# Fetch document
./scripts/invoke-cli.sh fetch "codex://fractary/project/file.md"

# List cache
./scripts/invoke-cli.sh cache list

# Health check
./scripts/invoke-cli.sh health
```

### Step 3: Parse JSON Output

The CLI returns JSON that can be parsed:

```bash
output=$(./scripts/invoke-cli.sh fetch "codex://org/proj/file.md")
status=$(echo "$output" | ./scripts/parse-output.sh status)
content=$(echo "$output" | ./scripts/parse-output.sh content)
```

### Step 4: Return Results

Return the parsed results to the calling skill in the expected format.

## Error Handling

### CLI Not Available

If CLI is not installed:
```json
{
  "status": "failure",
  "message": "@fractary/cli not installed and npx not available",
  "suggested_fixes": [
    "Install globally: npm install -g @fractary/cli",
    "Or ensure npx is available"
  ]
}
```

### Command Execution Failure

If CLI command fails:
- Preserve the CLI's exit code
- Return the CLI's error message
- Include suggested fixes if available

### JSON Parsing Failure

If output parsing fails:
```json
{
  "status": "failure",
  "message": "Failed to parse CLI output",
  "raw_output": "<cli output>"
}
```

## Delegation Pattern

Other skills should delegate to cli-helper like this:

```
┌──────────────────────────┐
│ document-fetcher skill   │
│                          │
│ "Fetch codex://..."      │
└────────────┬─────────────┘
             │
             │ delegates to
             ▼
┌──────────────────────────┐
│ cli-helper skill         │
│                          │
│ invokes: fractary codex  │
│          fetch <uri>     │
└────────────┬─────────────┘
             │
             │ executes
             ▼
┌──────────────────────────┐
│ @fractary/cli            │
│ (TypeScript SDK)         │
└──────────────────────────┘
```

## Performance Considerations

- **Global install**: < 100ms startup overhead
- **npx fallback**: ~500-1000ms first run (download), < 200ms subsequent (cached)
- Recommend global install for production use

## Notes

- All CLI commands support `--json` flag for programmatic parsing
- The invoke-cli.sh script automatically adds `--json` if not present
- Exit codes from CLI are preserved for error handling
- npx fallback is automatic but logs info message about global install recommendation
