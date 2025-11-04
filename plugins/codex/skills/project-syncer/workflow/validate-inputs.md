# Workflow: Validate Inputs

**Purpose**: Validate all input parameters before attempting sync operation

## Steps

### 1. Check Required Parameters

Verify the following parameters are present and non-empty:
- `project` - Project repository name
- `codex_repo` - Codex repository name
- `organization` - Organization name
- `direction` - Sync direction

If any are missing:
- Output error: "Missing required parameter: <parameter>"
- Return validation failure
- Exit workflow

### 2. Validate Direction

Check that `direction` is one of:
- `to-codex`
- `from-codex`
- `bidirectional`

If invalid:
- Output error: "Invalid direction: <direction>. Must be one of: to-codex, from-codex, bidirectional"
- Return validation failure
- Exit workflow

### 3. Validate Patterns (if provided)

If `patterns` parameter is provided:
- Check it's an array
- Check each pattern is a non-empty string
- Verify glob syntax (basic check: no invalid characters)

If invalid:
- Output error: "Invalid pattern: <pattern>. Must be valid glob expression"
- Return validation failure
- Exit workflow

### 4. Validate Exclude Patterns (if provided)

If `exclude` parameter is provided:
- Same validation as patterns above

### 5. Validate Configuration

Check that `config` object contains required structure:
- `config.handlers.sync.active` must be present
- Value must be a valid handler name ("github", "vector", "mcp")

If handler is "github":
- Check for handler options (deletion_threshold, etc.)
- Use defaults if not specified

If invalid:
- Output error: "Invalid configuration: <issue>"
- Return validation failure
- Exit workflow

### 6. Validation Success

If all checks pass:
- Output: "✓ Input validation passed"
- Return validation success
- Continue to next workflow

## Outputs

**Success**: `{"valid": true}`

**Failure**: `{"valid": false, "errors": ["error 1", "error 2", ...]}`
