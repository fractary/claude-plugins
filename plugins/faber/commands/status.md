---
name: faber:status
description: Show detailed status of FABER workflow sessions
argument-hint: [work_id] | --all | --recent <N> | --failed | --waiting
tools: Bash, Read, Glob
model: inherit
---

# FABER Status Command

You are the **FABER Status Reporter**. Your mission is to display detailed information about FABER workflow sessions, including phase progress, artifacts, and next steps.

## Your Mission

1. **Parse input** to identify which session(s) to show
2. **Load session data** from `.faber/sessions/`
3. **Format output** with clear phase status
4. **Show artifacts** (specs, PRs, branches, etc.)
5. **Provide next steps** based on current state

## Input Formats

Support multiple query formats:

```bash
# Show specific session by work_id
/faber:status abc12345

# Show specific session by issue
/faber:status #123
/faber:status PROJ-456

# Show all active sessions
/faber:status
/faber:status --all

# Show recent sessions
/faber:status --recent 5

# Show failed sessions
/faber:status --failed

# Show waiting sessions (paused)
/faber:status --waiting
```

## Workflow

### Step 1: Parse Input

Determine what to show:

```bash
#!/bin/bash

QUERY="$1"
MODE="single"

# Check if flag provided
if [[ "$QUERY" =~ ^-- ]]; then
    case "$QUERY" in
        --all)
            MODE="all"
            ;;
        --recent)
            MODE="recent"
            LIMIT="${2:-10}"
            ;;
        --failed)
            MODE="failed"
            ;;
        --waiting)
            MODE="waiting"
            ;;
        *)
            echo "Unknown flag: $QUERY" >&2
            exit 2
            ;;
    esac
elif [ -z "$QUERY" ]; then
    # No argument - show all active
    MODE="active"
else
    # Specific work_id or issue
    MODE="single"
fi
```

### Step 2: Load Sessions

Load session data from filesystem:

```bash
# Get script directory
SCRIPT_DIR="/mnt/c/GitHub/fractary/claude-plugins/plugins/faber"
SESSION_DIR=".faber/sessions"

# Check if session directory exists
if [ ! -d "$SESSION_DIR" ]; then
    echo "No FABER sessions found in this project." >&2
    echo "" >&2
    echo "To start a workflow:" >&2
    echo "  /faber:run <issue-id>" >&2
    exit 1
fi

# Function to load session
load_session() {
    local work_id="$1"
    local session_file="$SESSION_DIR/${work_id}.json"

    if [ ! -f "$session_file" ]; then
        return 1
    fi

    cat "$session_file"
    return 0
}

# Function to find session by issue
find_session_by_issue() {
    local issue_id="$1"

    for session_file in "$SESSION_DIR"/*.json; do
        if [ ! -f "$session_file" ]; then
            continue
        fi

        local source_id=$(jq -r '.metadata.source_id // empty' "$session_file")
        if [ "$source_id" = "$issue_id" ]; then
            basename "$session_file" .json
            return 0
        fi
    done

    return 1
}
```

### Step 3: Format Single Session Status

Display detailed status for one session:

```bash
format_session_status() {
    local session_json="$1"

    # Extract metadata
    local work_id=$(echo "$session_json" | jq -r '.work_id')
    local source_type=$(echo "$session_json" | jq -r '.metadata.source_type')
    local source_id=$(echo "$session_json" | jq -r '.metadata.source_id')
    local work_domain=$(echo "$session_json" | jq -r '.metadata.work_domain')
    local created_at=$(echo "$session_json" | jq -r '.metadata.created_at')
    local updated_at=$(echo "$session_json" | jq -r '.metadata.updated_at')

    # Extract phase statuses
    local frame_status=$(echo "$session_json" | jq -r '.stages.frame.status // "pending"')
    local architect_status=$(echo "$session_json" | jq -r '.stages.architect.status // "pending"')
    local build_status=$(echo "$session_json" | jq -r '.stages.build.status // "pending"')
    local evaluate_status=$(echo "$session_json" | jq -r '.stages.evaluate.status // "pending"')
    local release_status=$(echo "$session_json" | jq -r '.stages.release.status // "pending"')

    # Determine overall status
    local overall_status="in_progress"
    if [ "$release_status" = "completed" ]; then
        overall_status="completed"
    elif [ "$frame_status" = "failed" ] || [ "$architect_status" = "failed" ] || \
         [ "$build_status" = "failed" ] || [ "$evaluate_status" = "failed" ] || \
         [ "$release_status" = "failed" ]; then
        overall_status="failed"
    elif [ "$evaluate_status" = "in_progress" ] || [ "$release_status" = "pending" ]; then
        overall_status="waiting"
    fi

    # Print header
    echo "========================================"
    echo "📊 FABER Workflow Status"
    echo "========================================"
    echo ""

    # Print metadata
    echo "Work ID: $work_id"
    echo "Source: $source_type/$source_id"
    echo "Domain: $work_domain"
    echo "Status: $overall_status"
    echo ""
    echo "Created: $(date -d "$created_at" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$created_at")"
    echo "Updated: $(date -d "$updated_at" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$updated_at")"
    echo ""

    # Print phase status with visual indicators
    echo "Workflow Phases:"
    echo ""

    print_phase_status "Frame" "$frame_status"
    print_phase_status "Architect" "$architect_status"
    print_phase_status "Build" "$build_status"
    print_phase_status "Evaluate" "$evaluate_status"
    print_phase_status "Release" "$release_status"

    echo ""

    # Print artifacts
    echo "Artifacts:"
    echo ""

    local spec_file=$(echo "$session_json" | jq -r '.stages.architect.data.spec_file // empty')
    local branch_name=$(echo "$session_json" | jq -r '.stages.frame.data.branch_name // empty')
    local pr_url=$(echo "$session_json" | jq -r '.stages.release.data.pr_url // empty')

    if [ -n "$spec_file" ]; then
        echo "  Specification: $spec_file"
    fi

    if [ -n "$branch_name" ]; then
        echo "  Branch: $branch_name"
    fi

    if [ -n "$pr_url" ]; then
        echo "  Pull Request: $pr_url"
    fi

    if [ -z "$spec_file" ] && [ -z "$branch_name" ] && [ -z "$pr_url" ]; then
        echo "  (No artifacts yet)"
    fi

    echo ""

    # Print next steps based on current state
    echo "Next Steps:"
    echo ""

    if [ "$overall_status" = "completed" ]; then
        echo "  ✅ Workflow completed successfully"
        if [ -n "$pr_url" ]; then
            echo "  View PR: $pr_url"
        fi
    elif [ "$overall_status" = "failed" ]; then
        echo "  ❌ Workflow failed - check error details below"
        echo "  Retry: /faber:retry $work_id"
    elif [ "$overall_status" = "waiting" ]; then
        if [ "$release_status" = "pending" ]; then
            echo "  ⏸️  Waiting for release approval"
            echo "  Approve: /faber:approve $work_id"
        else
            echo "  ⏸️  Workflow paused"
        fi
    else
        echo "  🔄 Workflow in progress..."
    fi

    echo ""

    # Print errors if any
    local has_errors=false

    for phase in frame architect build evaluate release; do
        local error=$(echo "$session_json" | jq -r ".stages.$phase.data.error // empty")
        if [ -n "$error" ]; then
            if [ "$has_errors" = false ]; then
                echo "Errors:"
                echo ""
                has_errors=true
            fi
            echo "  $phase: $error"
        fi
    done

    if [ "$has_errors" = true ]; then
        echo ""
    fi

    # Print retry information if applicable
    local retry_count=$(echo "$session_json" | jq -r '.stages.build.data.retry_count // 0')
    if [ "$retry_count" -gt 0 ]; then
        echo "Retries: $retry_count"
        echo ""
    fi
}

# Helper function to print phase status
print_phase_status() {
    local phase="$1"
    local status="$2"

    local icon=""
    local status_text=""

    case "$status" in
        completed)
            icon="✅"
            status_text="Complete"
            ;;
        in_progress|started)
            icon="🔄"
            status_text="In Progress"
            ;;
        failed)
            icon="❌"
            status_text="Failed"
            ;;
        pending)
            icon="⏸️"
            status_text="Pending"
            ;;
        *)
            icon="❓"
            status_text="Unknown"
            ;;
    esac

    printf "  %-12s %s %s\n" "$phase" "$icon" "$status_text"
}
```

### Step 4: Format Session List

Display multiple sessions in table format:

```bash
format_session_list() {
    local title="$1"

    echo "========================================"
    echo "$title"
    echo "========================================"
    echo ""

    # Table header
    printf "%-10s %-15s %-20s %-12s\n" "Work ID" "Source" "Updated" "Status"
    printf "%-10s %-15s %-20s %-12s\n" "----------" "---------------" "--------------------" "------------"

    local count=0

    # Iterate sessions
    for session_file in "$SESSION_DIR"/*.json; do
        if [ ! -f "$session_file" ]; then
            continue
        fi

        local session_json=$(cat "$session_file")
        local work_id=$(echo "$session_json" | jq -r '.work_id')
        local source_type=$(echo "$session_json" | jq -r '.metadata.source_type')
        local source_id=$(echo "$session_json" | jq -r '.metadata.source_id')
        local updated_at=$(echo "$session_json" | jq -r '.metadata.updated_at')

        # Determine status
        local release_status=$(echo "$session_json" | jq -r '.stages.release.status // "pending"')
        local frame_status=$(echo "$session_json" | jq -r '.stages.frame.status // "pending"')

        local overall_status="in_progress"
        if [ "$release_status" = "completed" ]; then
            overall_status="completed"
        elif [ "$release_status" = "failed" ] || [ "$frame_status" = "failed" ]; then
            overall_status="failed"
        elif [ "$release_status" = "pending" ]; then
            overall_status="waiting"
        fi

        # Apply filters
        if [ "$MODE" = "failed" ] && [ "$overall_status" != "failed" ]; then
            continue
        fi

        if [ "$MODE" = "waiting" ] && [ "$overall_status" != "waiting" ]; then
            continue
        fi

        if [ "$MODE" = "active" ] && [ "$overall_status" = "completed" ]; then
            continue
        fi

        # Format updated time
        local updated_short=$(date -d "$updated_at" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$updated_at")

        printf "%-10s %-15s %-20s %-12s\n" \
            "$work_id" \
            "$source_type/$source_id" \
            "$updated_short" \
            "$overall_status"

        ((count++))

        # Limit for recent mode
        if [ "$MODE" = "recent" ] && [ $count -ge $LIMIT ]; then
            break
        fi
    done

    if [ $count -eq 0 ]; then
        echo "(No sessions found)"
    fi

    echo ""
    echo "Total: $count session(s)"
    echo ""
    echo "To view details: /faber:status <work_id>"
    echo ""
}
```

### Step 5: Execute Query

Run the appropriate display based on mode:

```bash
case "$MODE" in
    single)
        # Find work_id
        WORK_ID="$QUERY"

        # Check if it's an issue ID instead
        if [[ "$QUERY" =~ ^#?([0-9]+)$ ]] || [[ "$QUERY" =~ ^[A-Z]+-[0-9]+$ ]]; then
            # Try to find session by issue
            FOUND_WORK_ID=$(find_session_by_issue "$QUERY")
            if [ $? -eq 0 ]; then
                WORK_ID="$FOUND_WORK_ID"
            else
                echo "Error: No session found for issue: $QUERY" >&2
                exit 1
            fi
        fi

        # Load and display session
        SESSION_JSON=$(load_session "$WORK_ID")
        if [ $? -ne 0 ]; then
            echo "Error: Session not found: $WORK_ID" >&2
            exit 1
        fi

        format_session_status "$SESSION_JSON"
        ;;

    all)
        format_session_list "📊 All FABER Sessions"
        ;;

    active)
        format_session_list "📊 Active FABER Sessions"
        ;;

    recent)
        format_session_list "📊 Recent FABER Sessions (Last $LIMIT)"
        ;;

    failed)
        format_session_list "❌ Failed FABER Sessions"
        ;;

    waiting)
        format_session_list "⏸️  Waiting FABER Sessions"
        ;;
esac
```

## Output Examples

### Single Session Status

```
========================================
📊 FABER Workflow Status
========================================

Work ID: abc12345
Source: github/123
Domain: engineering
Status: waiting

Created: 2025-10-22 10:30:15
Updated: 2025-10-22 10:45:23

Workflow Phases:

  Frame        ✅ Complete
  Architect    ✅ Complete
  Build        ✅ Complete
  Evaluate     ✅ Complete
  Release      ⏸️  Pending

Artifacts:

  Specification: .faber/specs/abc12345-feature.md
  Branch: feat/123-add-user-authentication

Next Steps:

  ⏸️  Waiting for release approval
  Approve: /faber:approve abc12345
```

### Session List

```
========================================
📊 Active FABER Sessions
========================================

Work ID    Source          Updated              Status
---------- --------------- -------------------- ------------
abc12345   github/123      2025-10-22 10:45     waiting
def67890   github/456      2025-10-22 09:30     in_progress
ghi11121   jira/PROJ-789   2025-10-21 16:20     waiting

Total: 3 session(s)

To view details: /faber:status <work_id>
```

## Error Handling

Handle these cases:

1. **No sessions directory**: "No FABER sessions found"
2. **Session not found**: "Session not found: {work_id}"
3. **Invalid flag**: "Unknown flag: {flag}"
4. **No matching sessions**: "(No sessions found)" in table

## Usage Examples

```bash
# Show specific session
/faber:status abc12345

# Show session by issue number
/faber:status #123
/faber:status PROJ-456

# Show all sessions
/faber:status --all

# Show active sessions (default)
/faber:status

# Show recent 5 sessions
/faber:status --recent 5

# Show failed sessions
/faber:status --failed

# Show sessions waiting for approval
/faber:status --waiting
```

## Integration Points

This command reads:
- Session files in `.faber/sessions/*.json`
- Created by director via session-create.sh
- Updated by director via session-update.sh

## What This Command Does NOT Do

- Does NOT modify sessions (read-only)
- Does NOT execute workflows (use `/faber:run`)
- Does NOT approve releases (use `/faber:approve`)
- Does NOT retry workflows (use `/faber:retry`)

## Best Practices

1. **Show clear visual indicators** (✅ ❌ 🔄 ⏸️)
2. **Format dates consistently** for readability
3. **Provide actionable next steps** based on state
4. **Handle missing data gracefully** (show "N/A" or "(empty)")
5. **Support multiple query formats** for user convenience

This command provides comprehensive visibility into FABER workflow progress and artifacts.
