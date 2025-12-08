---
name: core
description: Core utilities for FABER workflow management - config loading, state management, status cards
model: claude-opus-4-5
---

# FABER Core Skill

Provides core utilities for FABER workflows including configuration management, state tracking, and status card generation.

## Purpose

This skill contains the fundamental operations needed by all FABER workflows:
- Load and parse configuration
- Manage workflow state (read, update, write)
- Generate and post status cards to work tracking systems
- Handle template variable substitution

## Operations

### Load Configuration

Loads and parses the FABER configuration file.

```bash
./scripts/config-loader.sh [config_path]
```

**Parameters:**
- `config_path` (optional): Path to config file (defaults to `.faber.config.toml`)

**Returns:** JSON representation of configuration

**Example:**
```bash
config_json=$(./scripts/config-loader.sh)
work_system=$(echo "$config_json" | jq -r '.project.issue_system')
```

### Read State

Reads the current FABER workflow state.

```bash
./scripts/state-read.sh <state_file>
```

**Parameters:**
- `state_file`: Path to state file (`.fractary/plugins/faber/state.json`)

**Returns:** State JSON with workflow progress

**Example:**
```bash
state_json=$(./scripts/state-read.sh ".fractary/plugins/faber/state.json")
```

### Update Phase State

Updates a specific phase in the FABER workflow state.

```bash
./scripts/state-update-phase.sh <phase> <status> [data_json]
```

**Parameters:**
- `phase`: FABER phase (frame, architect, build, evaluate, release)
- `status`: Phase status (pending, in_progress, completed, failed)
- `data_json` (optional): Additional phase-specific data as JSON

**Returns:** Updated state JSON

**Example:**
```bash
./scripts/state-update-phase.sh frame completed '{"work_type": "feature"}'
```

### Write State

Writes the complete FABER workflow state.

```bash
./scripts/state-write.sh <state_file>
```

**Parameters:**
- `state_file`: Path to state file (`.fractary/plugins/faber/state.json`)
- Input: State JSON via stdin

**Returns:** Success/failure status

**Example:**
```bash
echo "$STATE_JSON" | ./scripts/state-write.sh ".fractary/plugins/faber/state.json"
```

### Post Status Card

Posts a formatted status card to the work tracking system.

```bash
./scripts/status-card-post.sh <work_id> <issue_id> <stage> <message> <options_json>
```

**Parameters:**
- `work_id`: Work identifier
- `issue_id`: External issue ID
- `stage`: Current FABER stage
- `message`: Status message
- `options_json`: Available options as JSON array (e.g., `["ship to staging", "hold", "reject"]`)

**Returns:** Success/failure indicator

**Example:**
```bash
./scripts/status-card-post.sh abc12345 123 evaluate "Build is green" '["ship", "hold", "reject"]'
```

### Pattern Substitution

Replaces template variables in strings.

```bash
./scripts/pattern-substitute.sh <template> <work_id> <issue_id> [environment]
```

**Parameters:**
- `template`: String with patterns like `{work_id}`, `{issue_id}`, `{environment}`
- `work_id`: Work identifier
- `issue_id`: Issue identifier
- `environment` (optional): Target environment

**Returns:** Substituted string

**Example:**
```bash
branch_name=$(./scripts/pattern-substitute.sh "feat/{issue_id}-{work_id}" abc12345 123)
# Returns: feat/123-abc12345
```

## Templates

### Configuration Template

Located at: `templates/faber-config.toml.template`

Base template for generating project-specific FABER configurations.

### Status Card Template

Located at: `templates/status-card.template.md`

Markdown template for status cards posted to work tracking systems.

Variables supported:
- `{stage}`: Current FABER stage
- `{work_id}`: Work identifier
- `{message}`: Status message
- `{options}`: Available options
- `{context_refs}`: Context references (PRs, CI builds, etc.)
- `{timestamp}`: Current timestamp

## Documentation

### Status Cards

See: `docs/status-cards.md`

Complete specification for status card format, metadata, and usage.

### State Management

See: `docs/state-management.md`

Details on workflow state lifecycle, state transitions, and recovery.

### Configuration

See: `docs/configuration.md`

Complete reference for all FABER configuration options.

## Usage in Agents

Agents should invoke this skill for core utilities:

```bash
# Load configuration
config_json=$(claude -s core "load config")

# Read workflow state
state_json=$(claude -s core "read state")

# Update phase state
claude -s core "update phase frame completed"

# Post status card
claude -s core "post status card abc12345 123 frame 'Frame complete' '[\"proceed\"]'"
```

## Error Handling

All scripts follow these conventions:
- Exit code 0: Success
- Exit code 1: General error
- Exit code 2: Invalid arguments
- Exit code 3: Configuration error
- Exit code 4: State error

Error messages are written to stderr, results to stdout.

## Dependencies

- `bash` (4.0+)
- `jq` (for JSON parsing)
- `toml` (for TOML parsing) - uses Python's `toml` library
- Git (for some operations)

## File Locations

- **Config file**: `.fractary/plugins/faber/config.json` (v2.0)
- **State file**: `.fractary/plugins/faber/state.json`
- **Logs**: Managed by `fractary-logs` plugin (workflow log type)
- **Templates**: `skills/core/templates/`

## Notes

- This skill is stateless - all state is stored in the state file
- Scripts are idempotent where possible
- All JSON output is minified (single line) for easy parsing
- State files use JSON format for universal compatibility
