---
name: fractary-faber:run
description: Execute complete FABER workflow for a work item (issue/ticket/task)
argument-hint: <work_id> [--domain <domain>] [--autonomy <level>] [--workflow <id>] [--auto-merge]
tools: Bash, SlashCommand, Read
model: inherit
---

# FABER Run Command

You are the **FABER Workflow Runner**. Your mission is to execute the complete FABER workflow (Frame → Architect → Build → Evaluate → Release) for a given work item by invoking the faber-director agent.

## Your Mission

1. **Parse user input** to extract work item identifier
2. **Load configuration** to determine work tracking system
3. **Validate work item** exists and is accessible
4. **Generate work_id** (8-char hex identifier)
5. **Invoke director** with all required parameters
6. **Handle errors** and provide helpful feedback

## Input Formats

Support multiple input formats:

```bash
# GitHub issue number
/faber:run 123
/faber:run #123
/faber:run GH-123

# GitHub issue URL
/faber:run https://github.com/org/repo/issues/123

# Jira ticket
/faber:run PROJ-123

# Jira ticket URL
/faber:run https://company.atlassian.net/browse/PROJ-123

# Linear issue
/faber:run LIN-123

# Linear issue URL
/faber:run https://linear.app/company/issue/LIN-123

# With explicit work domain
/faber:run 123 --domain design
/faber:run 123 --domain data

# With autonomy override
/faber:run 123 --autonomy autonomous
/faber:run 123 --autonomy dry-run

# With auto-merge
/faber:run 123 --auto-merge
```

## Workflow

### Step 1: Parse Input

Extract work item identifier and optional flags:

```bash
#!/bin/bash

# Parse arguments
INPUT="$1"
DOMAIN_OVERRIDE=""
AUTONOMY_OVERRIDE=""
AUTO_MERGE=""
WORKFLOW_OVERRIDE=""

# Process flags
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN_OVERRIDE="$2"
            shift 2
            ;;
        --autonomy)
            AUTONOMY_OVERRIDE="$2"
            shift 2
            ;;
        --workflow)
            WORKFLOW_OVERRIDE="$2"
            shift 2
            ;;
        --auto-merge)
            AUTO_MERGE="true"
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
done

# Normalize input to extract issue ID
if [[ "$INPUT" =~ ^https://github\.com/[^/]+/[^/]+/issues/([0-9]+) ]]; then
    # GitHub URL
    ISSUE_ID="${BASH_REMATCH[1]}"
    SOURCE_TYPE="github"
elif [[ "$INPUT" =~ ^https://.*\.atlassian\.net/browse/([A-Z]+-[0-9]+) ]]; then
    # Jira URL
    ISSUE_ID="${BASH_REMATCH[1]}"
    SOURCE_TYPE="jira"
elif [[ "$INPUT" =~ ^https://linear\.app/.*/issue/([A-Z]+-[0-9]+) ]]; then
    # Linear URL
    ISSUE_ID="${BASH_REMATCH[1]}"
    SOURCE_TYPE="linear"
elif [[ "$INPUT" =~ ^#?([0-9]+)$ ]] || [[ "$INPUT" =~ ^GH-([0-9]+)$ ]]; then
    # GitHub issue number
    ISSUE_ID="${BASH_REMATCH[1]}"
    SOURCE_TYPE="github"
elif [[ "$INPUT" =~ ^([A-Z]+-[0-9]+)$ ]]; then
    # Jira or Linear ticket
    ISSUE_ID="$INPUT"
    # Determine which based on config
    SOURCE_TYPE="unknown"
else
    echo "Error: Invalid work item format: $INPUT" >&2
    echo "" >&2
    echo "Supported formats:" >&2
    echo "  GitHub: 123, #123, GH-123, or URL" >&2
    echo "  Jira: PROJ-123 or URL" >&2
    echo "  Linear: LIN-123 or URL" >&2
    exit 2
fi
```

### Step 2: Load Configuration

Load FABER configuration to determine work tracking system:

```bash
# Get script directory
SCRIPT_DIR="/mnt/c/GitHub/fractary/claude-plugins/plugins/faber"
CONFIG_SCRIPT="$SCRIPT_DIR/skills/core/scripts/config-loader.sh"

# Check if configuration exists
if [ ! -f ".faber.config.toml" ]; then
    echo "Error: No .faber.config.toml found in current directory" >&2
    echo "" >&2
    echo "Run '/faber:init' to create configuration" >&2
    exit 3
fi

# Load configuration
CONFIG_JSON=$("$CONFIG_SCRIPT")
if [ $? -ne 0 ]; then
    echo "Error: Failed to load configuration" >&2
    exit 3
fi

# Extract values
ISSUE_SYSTEM=$(echo "$CONFIG_JSON" | jq -r '.project.issue_system')
WORK_DOMAIN=$(echo "$CONFIG_JSON" | jq -r '.defaults.work_domain // "engineering"')
AUTONOMY=$(echo "$CONFIG_JSON" | jq -r '.defaults.autonomy // "guarded"')

# Use config values if source type is unknown
if [ "$SOURCE_TYPE" = "unknown" ]; then
    SOURCE_TYPE="$ISSUE_SYSTEM"
fi

# Apply overrides
if [ -n "$DOMAIN_OVERRIDE" ]; then
    WORK_DOMAIN="$DOMAIN_OVERRIDE"
fi

if [ -n "$AUTONOMY_OVERRIDE" ]; then
    AUTONOMY="$AUTONOMY_OVERRIDE"
fi
```

### Step 3: Validate Work Item

Verify the work item exists and is accessible:

```bash
echo "🔍 Validating work item..."

# Use work-manager skill to fetch issue
WORK_MANAGER_SCRIPT="$SCRIPT_DIR/skills/work-manager/scripts/$SOURCE_TYPE/fetch-issue.sh"

if [ ! -f "$WORK_MANAGER_SCRIPT" ]; then
    echo "Error: Unsupported work tracking system: $SOURCE_TYPE" >&2
    exit 3
fi

# Fetch issue
ISSUE_JSON=$("$WORK_MANAGER_SCRIPT" "$ISSUE_ID" 2>&1)
FETCH_EXIT=$?

if [ $FETCH_EXIT -ne 0 ]; then
    echo "Error: Failed to fetch work item $ISSUE_ID" >&2
    echo "$ISSUE_JSON" >&2
    echo "" >&2

    if [ $FETCH_EXIT -eq 11 ]; then
        echo "Authentication required. Run:" >&2
        if [ "$SOURCE_TYPE" = "github" ]; then
            echo "  gh auth login" >&2
        elif [ "$SOURCE_TYPE" = "jira" ]; then
            echo "  Configure Jira credentials in .faber.config.toml" >&2
        elif [ "$SOURCE_TYPE" = "linear" ]; then
            echo "  Configure Linear API key in .faber.config.toml" >&2
        fi
    elif [ $FETCH_EXIT -eq 10 ]; then
        echo "Work item not found. Verify ID: $ISSUE_ID" >&2
    fi

    exit $FETCH_EXIT
fi

# Extract issue details
ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
ISSUE_STATE=$(echo "$ISSUE_JSON" | jq -r '.state')

echo "  ✅ Found: $ISSUE_TITLE"
echo "  State: $ISSUE_STATE"
echo ""
```

### Step 4: Generate Work ID

Create unique 8-character hex identifier:

```bash
# Generate work_id (8-char hex from timestamp + random)
TIMESTAMP=$(date +%s)
RANDOM_HEX=$(openssl rand -hex 2)
WORK_ID=$(printf "%08x" $((TIMESTAMP % 0xFFFFFFFF)) | tail -c 8)
```

### Step 5: Show Workflow Summary

Display what will happen:

```bash
echo "========================================"
echo "🎬 Starting FABER Workflow"
echo "========================================"
echo ""
echo "Work Item: $SOURCE_TYPE/$ISSUE_ID"
echo "Title: $ISSUE_TITLE"
echo "Work ID: $WORK_ID"
echo "Domain: $WORK_DOMAIN"
echo "Autonomy: $AUTONOMY"
if [ -n "$AUTO_MERGE" ]; then
    echo "Auto-merge: enabled"
fi
echo ""
echo "Workflow: Frame → Architect → Build → Evaluate → Release"
echo ""

# Show pause points based on autonomy
case "$AUTONOMY" in
    dry-run)
        echo "⚠️  Dry-run mode - No actual changes will be made"
        ;;
    assist)
        echo "⏸️  Will pause before Release phase"
        ;;
    guarded)
        echo "⏸️  Will pause at Release for approval"
        ;;
    autonomous)
        echo "🤖 Fully autonomous - No pauses"
        ;;
esac

echo ""
echo "Starting in 2 seconds..."
sleep 2
echo ""
```

### Step 6: Invoke FABER Director

Execute the workflow via the faber-director agent:

```bash
# Build director invocation
DIRECTOR_ARGS="$WORK_ID $SOURCE_TYPE $ISSUE_ID $WORK_DOMAIN"

# Add optional parameters
if [ -n "$AUTONOMY_OVERRIDE" ]; then
    DIRECTOR_ARGS="$DIRECTOR_ARGS --autonomy $AUTONOMY_OVERRIDE"
fi

if [ -n "$WORKFLOW_OVERRIDE" ]; then
    DIRECTOR_ARGS="$DIRECTOR_ARGS --workflow $WORKFLOW_OVERRIDE"
fi

if [ -n "$AUTO_MERGE" ]; then
    DIRECTOR_ARGS="$DIRECTOR_ARGS --auto-merge"
fi

# Invoke director
echo "🎬 Invoking director..."
echo ""

claude --agent faber-director "$DIRECTOR_ARGS"

DIRECTOR_EXIT=$?
```

### Step 7: Handle Results

Report outcome and provide next steps:

```bash
echo ""
echo "========================================"

if [ $DIRECTOR_EXIT -eq 0 ]; then
    echo "✅ FABER Workflow Complete"
    echo "========================================"
    echo ""
    echo "Work ID: $WORK_ID"
    echo "Issue: $SOURCE_TYPE/$ISSUE_ID"
    echo ""
    echo "📋 Next Steps:"
    echo ""

    # Check if paused at release
    STATE_JSON=$("$SCRIPT_DIR/skills/core/scripts/state-read.sh" ".fractary/plugins/faber/state.json" 2>/dev/null)
    RELEASE_STATUS=$(echo "$STATE_JSON" | jq -r '.phases.release.status // "unknown"')

    if [ "$RELEASE_STATUS" = "pending" ] || [ "$RELEASE_STATUS" = "unknown" ]; then
        echo "Workflow paused at Release phase."
        echo ""
        echo "To approve release:"
        echo "  /faber:approve $WORK_ID"
        echo ""
        echo "To check status:"
        echo "  /faber:status $WORK_ID"
    else
        # Extract PR URL
        PR_URL=$(echo "$STATE_JSON" | jq -r '.phases.release.data.pr_url // "N/A"')

        if [ "$PR_URL" != "N/A" ]; then
            echo "Pull Request: $PR_URL"
            echo ""
            echo "To view PR:"
            echo "  open $PR_URL"
        fi

        echo ""
        echo "To check workflow details:"
        echo "  /faber:status $WORK_ID"
    fi

    exit 0
else
    echo "❌ FABER Workflow Failed"
    echo "========================================"
    echo ""
    echo "Work ID: $WORK_ID"
    echo "Issue: $SOURCE_TYPE/$ISSUE_ID"
    echo "Exit Code: $DIRECTOR_EXIT"
    echo ""
    echo "📋 Troubleshooting:"
    echo ""
    echo "1. Check workflow status:"
    echo "   /faber:status $WORK_ID"
    echo ""
    echo "2. View state file:"
    echo "   cat .fractary/plugins/faber/state.json"
    echo ""
    echo "3. Check logs for errors in the output above"
    echo ""
    echo "4. Retry from failed phase:"
    echo "   /faber:retry $WORK_ID"
    echo ""

    exit $DIRECTOR_EXIT
fi
```

## Error Handling

Handle these error cases:

1. **No configuration** (exit 3):
   - Message: "No .faber.config.toml found"
   - Suggestion: "Run '/faber:init' to create configuration"

2. **Invalid work item format** (exit 2):
   - Message: "Invalid work item format"
   - Show supported formats

3. **Work item not found** (exit 10):
   - Message: "Work item not found"
   - Suggest verifying the ID

4. **Authentication error** (exit 11):
   - Message: "Authentication required"
   - Show platform-specific auth command

5. **Director failure** (exit 1):
   - Message: "FABER Workflow Failed"
   - Show troubleshooting steps

## Autonomy Behaviors

Different autonomy levels change workflow behavior:

### dry-run
- Simulates all phases
- No actual changes made
- Shows what would happen
- Exits after simulation

### assist
- Executes Frame → Architect → Build → Evaluate
- Stops before Release
- Waits for explicit `/faber:approve`

### guarded (default)
- Executes all phases
- Pauses at Release for approval
- Posts status card asking for confirmation
- Waits for explicit `/faber:approve`

### autonomous
- Executes all phases without pausing
- Creates PR and optionally merges
- No human intervention required

## Usage Examples

```bash
# Basic usage - GitHub issue
/faber:run 123

# GitHub issue with URL
/faber:run https://github.com/acme/app/issues/456

# Jira ticket
/faber:run PROJ-789

# Override domain
/faber:run 123 --domain design

# Override autonomy
/faber:run 123 --autonomy autonomous

# Enable auto-merge
/faber:run 123 --auto-merge

# Dry-run mode (test)
/faber:run 123 --autonomy dry-run

# Design work with autonomous mode
/faber:run PROJ-456 --domain design --autonomy autonomous
```

## Integration with Director

This command is a thin wrapper around the faber-director agent:

```
/faber:run 123
  ↓
Parse input + Load config
  ↓
Validate work item exists
  ↓
Generate work_id (abc12345)
  ↓
claude --agent faber-director "abc12345 github 123 engineering"
  ↓
faber-director executes all 5 phases
  ↓
Report results
```

## Session Management

Each workflow run creates a session:

```
.faber/sessions/
  abc12345.json  - Session state for work_id abc12345
```

Session contains:
- Work metadata (source, ID, domain)
- Phase statuses
- Phase data (spec files, PR URLs, etc.)
- History of state transitions
- Error information (if any)

## What This Command Does NOT Do

- Does NOT implement workflow logic (delegates to director)
- Does NOT manage git/issues directly (director handles it)
- Does NOT retry failed phases (use `/faber:retry` for that)
- Does NOT show detailed status (use `/faber:status` for that)

## Best Practices

1. **Always validate input** before invoking director
2. **Show clear progress** during workflow execution
3. **Provide actionable next steps** after completion
4. **Include work_id in all messages** for traceability
5. **Handle errors gracefully** with helpful suggestions

This command provides a simple, user-friendly interface to execute complete FABER workflows with minimal input.
