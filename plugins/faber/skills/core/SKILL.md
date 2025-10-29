---
name: core
description: Core utilities for FABER workflow management - config loading, session management, status cards
---

# FABER Core Skill

Provides core utilities for FABER workflows including configuration management, session tracking, and status card generation.

## Purpose

This skill contains the fundamental operations needed by all FABER workflows:
- Load and parse configuration
- Create and manage workflow sessions
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

### Create Session

Creates a new FABER workflow session.

```bash
./scripts/session-create.sh <work_id> <issue_id> <domain>
```

**Parameters:**
- `work_id`: Unique FABER work identifier (8-char hex)
- `issue_id`: External issue ID (e.g., GitHub issue number)
- `domain`: Work domain (engineering, design, writing, data)

**Returns:** Session JSON with metadata

**Example:**
```bash
session_json=$(./scripts/session-create.sh abc12345 123 engineering)
```

### Update Session

Updates an existing workflow session with phase progress.

```bash
./scripts/session-update.sh <session_id> <stage> <status> [data_json]
```

**Parameters:**
- `session_id`: Session identifier (same as work_id)
- `stage`: FABER stage (frame, architect, build, evaluate, release)
- `status`: Stage status (started, in_progress, completed, failed)
- `data_json` (optional): Additional stage-specific data as JSON

**Returns:** Updated session JSON

**Example:**
```bash
./scripts/session-update.sh abc12345 frame completed '{"work_type": "/feature"}'
```

### Get Session Status

Retrieves current session status.

```bash
./scripts/session-status.sh <session_id>
```

**Parameters:**
- `session_id`: Session identifier

**Returns:** Session status JSON

### Post Status Card

Posts a formatted status card to the work tracking system.

```bash
./scripts/status-card-post.sh <session_id> <issue_id> <stage> <message> <options_json>
```

**Parameters:**
- `session_id`: Session identifier
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
- `{session_id}`: Session identifier
- `{message}`: Status message
- `{options}`: Available options
- `{context_refs}`: Context references (PRs, CI builds, etc.)
- `{timestamp}`: Current timestamp

## Documentation

### Status Cards

See: `docs/status-cards.md`

Complete specification for status card format, metadata, and usage.

### Session Management

See: `docs/session-management.md`

Details on session lifecycle, state transitions, and recovery.

### Configuration

See: `docs/configuration.md`

Complete reference for all FABER configuration options.

## Usage in Agents

Agents should invoke this skill for core utilities:

```bash
# Load configuration
config_json=$(claude -s core "load config")

# Create session
session_json=$(claude -s core "create session abc12345 123 engineering")

# Update session
claude -s core "update session abc12345 frame completed"

# Post status card
claude -s core "post status card abc12345 123 frame 'Frame complete' '[\"proceed\"]'"
```

## Error Handling

All scripts follow these conventions:
- Exit code 0: Success
- Exit code 1: General error
- Exit code 2: Invalid arguments
- Exit code 3: Configuration error
- Exit code 4: Session error

Error messages are written to stderr, results to stdout.

## Dependencies

- `bash` (4.0+)
- `jq` (for JSON parsing)
- `toml` (for TOML parsing) - uses Python's `toml` library
- Git (for some operations)

## File Locations

- **Config file**: `.faber.config.toml` (project root)
- **Session storage**: `.faber/sessions/` (configurable)
- **Logs**: `.faber/logs/` (configurable)
- **Templates**: `skills/core/templates/`

## Notes

- This skill is stateless - all state is stored in session files
- Scripts are idempotent where possible
- All JSON output is minified (single line) for easy parsing
- Session files use JSON format for universal compatibility
