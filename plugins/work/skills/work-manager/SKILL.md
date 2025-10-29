---
name: work-manager
description: Issue tracking operations across GitHub, Jira, Linear, etc.
---

# Work Manager Skill

Provides issue tracking operations for FABER workflows. This skill is platform-agnostic and supports multiple issue trackers through adapters.

## Purpose

Handle all interactions with work tracking systems:
- Fetch work item details (issues, tickets, tasks)
- Post comments and status updates
- Classify work items by type
- Update work item status
- Set labels and metadata

## Configuration

Reads `project.issue_system` from configuration to determine which adapter to use:

```toml
[project]
issue_system = "github"  # github | jira | linear | manual
```

## Operations

### Fetch Issue

Retrieve complete issue details from tracking system.

```bash
./scripts/<adapter>/fetch-issue.sh <issue_id>
```

**Parameters:**
- `issue_id`: External issue identifier (e.g., GitHub issue number, Jira ticket ID)

**Returns:** JSON with issue details

**Example:**
```bash
issue_json=$(./scripts/github/fetch-issue.sh 123)
title=$(echo "$issue_json" | jq -r '.title')
```

### Create Comment

Post a comment to an issue.

```bash
./scripts/<adapter>/create-comment.sh <issue_id> <work_id> <author> <message>
```

**Parameters:**
- `issue_id`: External issue identifier
- `work_id`: FABER work identifier
- `author`: Comment context (frame, architect, build, evaluate, release)
- `message`: Comment content (markdown supported)

**Returns:** Success/failure indicator

**Example:**
```bash
./scripts/github/create-comment.sh 123 abc12345 frame "Frame phase started"
```

### Set Label

Add or update labels on an issue.

```bash
./scripts/<adapter>/set-label.sh <issue_id> <label> [action]
```

**Parameters:**
- `issue_id`: External issue identifier
- `label`: Label to set
- `action` (optional): `add` (default) or `remove`

**Returns:** Success/failure indicator

**Example:**
```bash
./scripts/github/set-label.sh 123 "faber-in-progress" add
```

### Classify Issue

Determine work type from issue content and labels.

```bash
./scripts/<adapter>/classify-issue.sh <issue_json>
```

**Parameters:**
- `issue_json`: Issue JSON from fetch operation

**Returns:** Work type classification (/bug, /feature, /chore, /patch)

**Example:**
```bash
issue_json=$(./scripts/github/fetch-issue.sh 123)
work_type=$(./scripts/github/classify-issue.sh "$issue_json")
```

## Adapters

### GitHub Adapter

Located in: `scripts/github/`

Uses GitHub CLI (`gh`) for API operations.

**Requirements:**
- `gh` CLI installed
- `GITHUB_TOKEN` environment variable set
- Configured repository in `.faber.config.toml`

**See:** `docs/github-api.md` for details

### Jira Adapter (Future)

Located in: `scripts/jira/`

Will use Jira REST API for operations.

**See:** `docs/jira-api.md` for future implementation

### Linear Adapter (Future)

Located in: `scripts/linear/`

Will use Linear GraphQL API for operations.

**See:** `docs/linear-api.md` for future implementation

## Error Handling

All scripts follow these conventions:
- Exit code 0: Success
- Exit code 1: General error
- Exit code 2: Invalid arguments
- Exit code 3: Configuration error
- Exit code 10: Issue not found
- Exit code 11: Authentication error
- Exit code 12: Network error

Error messages are written to stderr, results to stdout.

## Usage in Agents

Agents should invoke this skill for work tracking operations:

```bash
# From work-manager agent
SCRIPT_DIR="$(dirname "$0")/../skills/work-manager/scripts"

# Determine adapter from config
ADAPTER=$(get_work_system_from_config)  # Returns: github, jira, linear

# Fetch issue
issue_json=$("$SCRIPT_DIR/$ADAPTER/fetch-issue.sh" "$issue_id")

# Post comment
"$SCRIPT_DIR/$ADAPTER/create-comment.sh" "$issue_id" "$work_id" "frame" "Starting work"

# Classify
work_type=$("$SCRIPT_DIR/$ADAPTER/classify-issue.sh" "$issue_json")
```

## Dependencies

### All Adapters
- `bash` (4.0+)
- `jq` (for JSON parsing)

### GitHub Adapter
- `gh` CLI
- `GITHUB_TOKEN` environment variable

### Jira Adapter (Future)
- `curl`
- `JIRA_TOKEN` and `JIRA_EMAIL` environment variables

### Linear Adapter (Future)
- `curl`
- `LINEAR_API_KEY` environment variable

## Script Locations

```
skills/work-manager/
├── SKILL.md (this file)
├── scripts/
│   ├── github/
│   │   ├── fetch-issue.sh
│   │   ├── create-comment.sh
│   │   ├── set-label.sh
│   │   └── classify-issue.sh
│   ├── jira/
│   │   └── (future)
│   └── linear/
│       └── (future)
└── docs/
    ├── github-api.md
    ├── jira-api.md
    └── linear-api.md
```

## Testing

Test scripts independently:

```bash
# Test GitHub adapter
export GITHUB_TOKEN="ghp_..."
./scripts/github/fetch-issue.sh 123
./scripts/github/create-comment.sh 123 test123 test "Test comment"
```

## Notes

- Scripts are stateless and idempotent where possible
- All JSON output is minified (single line) for easy parsing
- Comments support GitHub-flavored markdown
- Classification logic can be customized via configuration labels
