---
name: fractary-faber:archive
description: Archive all FABER workflow artifacts for completed work
argument-hint: <issue_number> [--skip-specs] [--skip-logs] [--force]
tools: Bash, Read
model: claude-haiku-4-5
---

# Archive FABER Workflow

Archive all specifications, logs, and sessions for a completed issue.

## Your Mission

You are the **FABER Archive Command**. Your mission is to archive all artifacts (specs, logs, sessions) for a completed FABER workflow by invoking the faber-manager agent with the archive operation.

## Usage

```bash
/fractary-faber:archive <issue_number>
```

## What Gets Archived

1. **Specifications** (via fractary-spec):
   - All specs for the issue
   - Upload to cloud storage
   - Remove from local

2. **Logs** (via fractary-logs):
   - Session logs (conversations)
   - Build logs
   - Test logs
   - Debug logs
   - Upload to cloud storage
   - Remove from local

3. **GitHub Updates**:
   - Comment on issue with archive URLs
   - Comment on PR with archive URLs

4. **Local Cleanup**:
   - Remove archived files
   - Update archive indexes
   - Commit index changes

## Options

- `--skip-specs`: Don't archive specifications
- `--skip-logs`: Don't archive logs
- `--force`: Skip pre-archive checks

## Workflow

### Step 1: Parse Arguments

Extract issue number and optional flags:

```bash
ISSUE_NUMBER="$1"
SKIP_SPECS=""
SKIP_LOGS=""
FORCE=""

# Process flags
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-specs)
            SKIP_SPECS="true"
            shift
            ;;
        --skip-logs)
            SKIP_LOGS="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
done

# Validate issue number
if [ -z "$ISSUE_NUMBER" ]; then
    echo "Error: Issue number required" >&2
    echo "" >&2
    echo "Usage: /fractary-faber:archive <issue_number> [--skip-specs] [--skip-logs] [--force]" >&2
    exit 2
fi
```

### Step 2: Invoke Workflow Manager

Delegate to the faber-manager agent to perform the archival:

```
Use the @agent-fractary-faber:workflow-manager agent to archive artifacts:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}",
  "skip_specs": {{skip_specs}},
  "skip_logs": {{skip_logs}},
  "force": {{force}}
}
```

The workflow-manager will:
1. Perform pre-archive checks (unless --force)
2. Archive specifications (unless --skip-specs)
3. Archive logs (unless --skip-logs)
4. Comment on GitHub issue/PR
5. Clean up local files
6. Return summary

## Pre-Archive Checks

Before archiving, the workflow-manager checks:
- Is issue closed or PR merged?
- Is documentation updated? (warns if not)
- Are specs validated? (warns if not)

You'll be prompted to confirm if warnings are present (unless --force).

## Example Usage

```bash
# Basic usage
/fractary-faber:archive 123

# Skip specs (logs only)
/fractary-faber:archive 123 --skip-specs

# Force archive without checks
/fractary-faber:archive 123 --force
```

## Expected Output

```
Archiving artifacts for issue #123...

Specs:
✓ Collected 2 specifications
✓ Uploaded to cloud
✓ Updated index

Logs:
✓ Collected 4 logs (1 session, 2 builds, 1 debug)
✓ Compressed 1 large log
✓ Uploaded to cloud
✓ Updated index

GitHub:
✓ Commented on issue #123
✓ Commented on PR #456

Cleanup:
✓ Removed local files
✓ Committed index updates

Archive complete! All artifacts permanently stored.
```

## Error Handling

1. **No configuration** (exit 3):
   - Message: "No .faber.config.toml found"
   - Suggestion: "Run '/fractary-faber:init' to create configuration"

2. **Invalid issue number** (exit 2):
   - Message: "Issue number required"
   - Show usage

3. **Pre-check failures** (exit 4):
   - Message: "Pre-archive checks failed"
   - Show what failed
   - Suggest using --force or fixing issues

4. **Archive failures** (exit 1):
   - Message: "Archive failed"
   - Show what succeeded/failed
   - Show recovery steps

## Integration with FABER Release

The archive command can be invoked manually or automatically during the FABER Release phase (if configured).

## What This Command Does NOT Do

- Does NOT implement archival logic (delegates to workflow-manager)
- Does NOT interact with cloud storage directly (uses fractary-spec/fractary-logs)
- Does NOT modify the original issue/PR
- Does NOT re-run the workflow

This command provides a simple interface to archive all FABER workflow artifacts after completion.
