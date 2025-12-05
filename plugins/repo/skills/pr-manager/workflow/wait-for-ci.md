# Workflow: Wait for CI Completion

This document describes the CI polling workflow used when `wait_for_ci` is enabled for PR analysis.

## Overview

When a user runs `pr-review --wait-for-ci`, the system polls GitHub's API for CI check status before proceeding with PR analysis. This enables automated workflows that chain `pr-create` → `pr-review` without manual timing.

## When to Use

- **After PR creation**: CI checks often take time to complete after a PR is created
- **FABER workflows**: Automated pipelines that need to wait for CI before analysis
- **Long-running CI**: Projects with extended build/test pipelines

## Workflow Steps

### Step 1: Validate Polling Parameters

Extract polling configuration from parameters:
- `interval`: Seconds between polls (default: 60)
- `timeout`: Maximum wait time (default: 900 = 15 minutes)
- `initial_delay`: Wait before first check (default: 10 seconds)

### Step 2: Execute Polling Script

Invoke the polling script:

```bash
./plugins/repo/skills/handler-source-control-github/scripts/poll-ci-workflows.sh \
  "$PR_NUMBER" \
  --interval "$INTERVAL" \
  --timeout "$TIMEOUT" \
  --initial-delay "$INITIAL_DELAY" \
  --json
```

### Step 3: Handle Polling Results

Process the script's exit code and output:

| Exit Code | Status | Action |
|-----------|--------|--------|
| 0 | Success | All CI checks passed. Proceed to analysis. |
| 4 | Failed | CI checks failed. Proceed to analysis (user sees failure in report). |
| 5 | Timeout | CI still pending after timeout. Proceed to analysis with warning. |
| 6 | No CI | No CI checks configured. Proceed to analysis immediately. |
| 11 | Auth Error | GitHub authentication failed. Report error. |

### Step 4: Report Polling Status

Display polling results to user:

```
⏳ CI POLLING STATUS:
Status: {success|failed|timeout|no_ci}
Elapsed: {elapsed_seconds}s
Checks: {passed}/{total} passed
{If failed: List failed check names}
───────────────────────────────────────
```

### Step 5: Proceed to Analysis

After polling completes (or exits), continue with the standard PR analysis workflow.

## Script Details

### Script Location
`plugins/repo/skills/handler-source-control-github/scripts/poll-ci-workflows.sh`

### Script Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `pr_number` | Yes | - | PR number to check |
| `--interval` | No | 60 | Seconds between polls |
| `--timeout` | No | 900 | Maximum wait time in seconds |
| `--initial-delay` | No | 10 | Initial delay before first check |
| `--quiet` | No | false | Suppress progress output |
| `--json` | No | false | Output results as JSON |

### JSON Output Format

```json
{
  "status": "success|failed|timeout|no_ci|error",
  "message": "Human-readable message",
  "pr_number": 456,
  "ci_summary": {
    "total_checks": 5,
    "passed": 5,
    "failed": 0,
    "pending": 0
  },
  "elapsed_seconds": 180,
  "check_details": [
    {
      "name": "build",
      "status": "completed",
      "conclusion": "success",
      "is_complete": true,
      "is_success": true,
      "is_failure": false
    }
  ]
}
```

## Configuration

CI polling settings can be configured in `.fractary/plugins/repo/config.json`:

```json
{
  "defaults": {
    "pr": {
      "ci_polling": {
        "enabled": true,
        "interval_seconds": 60,
        "timeout_seconds": 900,
        "initial_delay_seconds": 10
      }
    }
  }
}
```

## Error Handling

### Timeout Reached
If CI checks are still pending after the timeout:
1. Log warning about timeout
2. Proceed to analysis
3. Analysis will show pending CI status

### CI Failures Detected
If CI checks fail:
1. Report which checks failed
2. Proceed to analysis
3. Analysis will show failure status and recommend fixing CI first

### No CI Configured
If PR has no CI checks:
1. Skip polling entirely
2. Proceed directly to analysis
3. Analysis will note no CI is configured

### Network/API Errors
If GitHub API fails:
1. Retry up to 3 times (built into gh CLI)
2. If persistent, report error
3. User can retry manually

## Integration with FABER

In FABER workflows, the Release phase can be configured to wait for CI:

```toml
[workflow.release]
pr_review = true
wait_for_ci = true
ci_timeout = 900
```

This ensures the PR review step waits for CI before analyzing, enabling fully automated Release phases.

## Best Practices

1. **Use appropriate timeouts**: Set timeout based on your CI pipeline's typical duration
2. **Initial delay**: The default 10-second delay allows CI to initialize on GitHub
3. **Interval tuning**: Shorter intervals (30s) for fast CI, longer (120s) for slow CI
4. **Monitor rate limits**: Frequent polling may hit GitHub API rate limits
