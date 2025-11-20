# FABER Error Codes

This document catalogs all FABER error codes with their meanings, severities, and recovery actions.

## Quick Reference

| Code | Category | Severity | Message |
|------|----------|----------|---------|
| FABER-001 | Configuration | Error | Configuration file not found |
| FABER-002 | Configuration | Error | Invalid JSON in configuration file |
| FABER-003 | Configuration | Error | Configuration schema validation failed |
| FABER-004 | Configuration | Error | Missing required configuration field |
| FABER-005 | Configuration | Error | Invalid autonomy level specified |
| FABER-100 | State | Error | State file not found |
| FABER-101 | State | Error | Invalid JSON in state file |
| FABER-102 | State | Error | State schema validation failed |
| FABER-103 | State | Warning | State version mismatch |
| FABER-104 | State | Error | Failed to write state file |
| FABER-200 | Execution | Error | Phase execution failed |
| FABER-201 | Execution | Error | Phase validation failed |
| FABER-202 | Execution | Error | Step execution failed |
| FABER-203 | Execution | Error | Max retries exceeded |
| FABER-300 | Hooks | Warning | Hook execution failed |
| FABER-301 | Hooks | Warning | Hook timeout exceeded |
| FABER-302 | Hooks | Error | Hook validation failed |
| FABER-303 | Hooks | Error | Hook path not found |
| FABER-400 | Integration | Error | Work plugin not configured |
| FABER-401 | Integration | Error | Repo plugin not configured |
| FABER-402 | Integration | Error | Work item not found |
| FABER-403 | Integration | Error | Failed to create branch |
| FABER-404 | Integration | Error | Failed to create specification |
| FABER-405 | Integration | Error | Failed to create pull request |
| FABER-500 | Concurrency | Error | Failed to acquire workflow lock |
| FABER-501 | Concurrency | Error | Concurrent workflow execution detected |
| FABER-502 | Concurrency | Warning | Stale lock detected |

## Error Categories

### Configuration Errors (001-099)

Errors related to FABER configuration files and settings.

#### FABER-001: Configuration file not found

**Severity:** Error
**Category:** Configuration

**Description:**
The FABER configuration file `.fractary/plugins/faber/config.json` does not exist.

**Common Causes:**
- First time using FABER in this project
- Configuration file was accidentally deleted
- Working in wrong directory

**Recovery:**
```bash
/fractary-faber:init
```

This will create a default configuration from the standard template.

---

#### FABER-002: Invalid JSON in configuration file

**Severity:** Error
**Category:** Configuration

**Description:**
The configuration file exists but contains invalid JSON syntax.

**Common Causes:**
- Manual editing introduced syntax errors
- Corrupted file due to incomplete write
- Missing commas, brackets, or quotes

**Recovery:**
1. Validate JSON syntax using a JSON validator
2. Restore from template if errors are extensive
3. Check `.fractary/plugins/faber/backups/` for recent backups

```bash
# Validate configuration
plugins/faber/skills/core/scripts/config-validate.sh .fractary/plugins/faber/config.json

# Restore from template
cp plugins/faber/config/templates/standard.json .fractary/plugins/faber/config.json
```

---

#### FABER-003: Configuration schema validation failed

**Severity:** Error
**Category:** Configuration

**Description:**
The configuration file is valid JSON but does not conform to the FABER configuration schema.

**Common Causes:**
- Missing required fields (schema_version, workflows, integrations)
- Invalid field values (wrong type, out of range)
- Incorrect workflow or phase structure
- Invalid autonomy level

**Recovery:**
```bash
# Get detailed validation errors
plugins/faber/skills/core/scripts/config-validate.sh .fractary/plugins/faber/config.json

# Review error output and fix issues
# Reference: plugins/faber/config/config.schema.json
```

---

#### FABER-004: Missing required configuration field

**Severity:** Error
**Category:** Configuration

**Description:**
A required field is missing from the configuration.

**Required Fields:**
- `schema_version` (string)
- `workflows` (array)
- `workflows[].id` (string)
- `workflows[].phases` (object)
- `integrations` (object)

**Recovery:**
Add the missing field or use a complete template:

```bash
cp plugins/faber/config/templates/standard.json .fractary/plugins/faber/config.json
```

---

#### FABER-005: Invalid autonomy level specified

**Severity:** Error
**Category:** Configuration

**Description:**
The autonomy level in configuration is not one of the valid values.

**Valid Autonomy Levels:**
- `dry-run` - Show what would happen, make no changes
- `assist` - Execute through Build, pause before Release
- `guarded` - Execute all phases, require approval for Release
- `autonomous` - Execute all phases without human approval

**Recovery:**
Edit `.fractary/plugins/faber/config.json` and set `workflows[].autonomy.level` to one of the valid values above.

---

### State Errors (100-199)

Errors related to workflow state management.

#### FABER-100: State file not found

**Severity:** Error
**Category:** State

**Description:**
The workflow state file `.fractary/plugins/faber/state.json` does not exist when attempting to read or update state.

**Common Causes:**
- No workflow has been started yet
- State file was deleted
- Attempting to resume non-existent workflow

**Recovery:**
```bash
# Initialize state for new workflow
plugins/faber/skills/core/scripts/state-init.sh <work-id>

# Or start a new workflow
/fractary-faber:run <work-id>
```

---

#### FABER-101: Invalid JSON in state file

**Severity:** Error
**Category:** State

**Description:**
The state file exists but contains invalid JSON syntax.

**Common Causes:**
- File corruption due to interrupted write
- Manual editing introduced syntax errors
- Disk full during write operation

**Recovery:**
```bash
# Restore from most recent backup
ls -lt .fractary/plugins/faber/backups/
cp .fractary/plugins/faber/backups/state-YYYYMMDD_HHMMSS.json .fractary/plugins/faber/state.json

# If no backups available, start new workflow
plugins/faber/skills/core/scripts/state-init.sh <work-id>
```

---

#### FABER-102: State schema validation failed

**Severity:** Error
**Category:** State

**Description:**
The state file is valid JSON but does not conform to the expected state schema.

**Common Causes:**
- State file was corrupted
- Manual editing introduced invalid values
- Schema version mismatch

**Recovery:**
State file is corrupted. Restore from backup or start new workflow:

```bash
# Check available backups
ls -lt .fractary/plugins/faber/backups/

# Restore from backup
cp .fractary/plugins/faber/backups/state-YYYYMMDD_HHMMSS.json .fractary/plugins/faber/state.json

# Or reinitialize
plugins/faber/skills/core/scripts/state-init.sh <work-id>
```

---

#### FABER-103: State version mismatch

**Severity:** Warning
**Category:** State

**Description:**
The state file version does not match the current FABER version.

**Common Causes:**
- Upgraded FABER to newer version
- Downgraded FABER to older version
- State file from different FABER version

**Recovery:**
```bash
# Run migration script to upgrade state
plugins/faber/skills/core/scripts/state-migrate.sh
```

---

#### FABER-104: Failed to write state file

**Severity:** Error
**Category:** State

**Description:**
Unable to write to the state file.

**Common Causes:**
- Disk full
- No write permissions on `.fractary/plugins/faber/`
- File system error
- Directory does not exist

**Recovery:**
1. Check disk space: `df -h`
2. Check permissions: `ls -la .fractary/plugins/faber/`
3. Ensure directory exists: `mkdir -p .fractary/plugins/faber/`

---

### Execution Errors (200-299)

Errors related to workflow and phase execution.

#### FABER-200: Phase execution failed

**Severity:** Error
**Category:** Execution

**Description:**
A FABER phase (Frame, Architect, Build, Evaluate, Release) failed to execute successfully.

**Common Causes:**
- Script execution error
- Skill invocation failure
- Integration failure (work plugin, repo plugin)
- Validation criteria not met

**Recovery:**
1. Review error details from phase output
2. Fix underlying issues
3. Retry the phase:
   ```bash
   /fractary-faber:run <work-id> --resume
   ```

---

#### FABER-201: Phase validation failed

**Severity:** Error
**Category:** Execution

**Description:**
A phase completed but did not meet its validation criteria.

**Common Causes:**
- Required artifacts not created
- Validation checks failed
- Missing required fields in artifacts
- Integration verification failed

**Recovery:**
Complete missing validation criteria before proceeding:
1. Review validation requirements in configuration
2. Create missing artifacts
3. Fix validation failures
4. Retry phase

---

#### FABER-202: Step execution failed

**Severity:** Error
**Category:** Execution

**Description:**
A specific step within a phase failed to execute.

**Common Causes:**
- Script error
- Missing dependencies
- Integration failure
- Invalid parameters

**Recovery:**
1. Review step error details
2. Fix underlying issues
3. Retry step (if optional, skip with `--skip-step`)
4. Or retry entire phase

---

#### FABER-203: Max retries exceeded

**Severity:** Error
**Category:** Execution

**Description:**
A phase or step was retried the maximum number of times and still failed.

**Common Causes:**
- Persistent integration failures
- Configuration issues
- External service unavailable
- Fundamental implementation problems

**Recovery:**
Evaluate phase failed after max retries. Review and fix issues manually:
1. Examine all error logs
2. Identify root cause
3. Fix issues outside FABER if needed
4. Reset retry count and retry

---

### Hook Errors (300-399)

Errors related to phase hook execution.

#### FABER-300: Hook execution failed

**Severity:** Warning
**Category:** Hooks

**Description:**
A configured hook script or document failed to execute successfully.

**Common Causes:**
- Hook script has errors
- Hook script not executable
- Hook dependencies missing
- Hook path incorrect

**Recovery:**
1. Check hook configuration in `.fractary/plugins/faber/config.json`
2. Verify hook script has execute permissions:
   ```bash
   chmod +x path/to/hook-script.sh
   ```
3. Test hook manually
4. Review hook output for errors

---

#### FABER-301: Hook timeout exceeded

**Severity:** Warning
**Category:** Hooks

**Description:**
A hook took longer than the configured timeout to execute.

**Common Causes:**
- Hook performing expensive operations
- Hook waiting on external services
- Infinite loop in hook logic
- Network delays

**Recovery:**
1. Increase hook timeout in configuration
2. Optimize hook execution time
3. Remove blocking operations from hook
4. Consider making hook asynchronous

---

#### FABER-302: Hook validation failed

**Severity:** Error
**Category:** Hooks

**Description:**
The hook configuration is invalid or hook type is incorrect.

**Common Causes:**
- Invalid hook type (not document/script/skill)
- Missing required hook fields
- Hook path format incorrect

**Recovery:**
Check hook type matches configuration:
- `document` - Path to markdown file with instructions
- `script` - Path to executable shell script
- `skill` - Skill identifier (e.g., "fractary-work:comment-create")

---

#### FABER-303: Hook path not found

**Severity:** Error
**Category:** Hooks

**Description:**
The specified document or script path for a hook does not exist.

**Common Causes:**
- Typo in path
- File was deleted or moved
- Incorrect relative path
- File not committed to repository

**Recovery:**
Verify document or script path exists:
```bash
ls -la path/to/hook-file
```

Update configuration with correct path.

---

### Integration Errors (400-499)

Errors related to plugin integrations (work, repo, spec).

#### FABER-400: Work plugin not configured

**Severity:** Error
**Category:** Integration

**Description:**
The work tracking plugin is not configured but is required for this operation.

**Common Causes:**
- First time using FABER with work tracking
- Integration removed from configuration
- Work plugin not installed

**Recovery:**
```bash
/fractary-work:init
```

Then update FABER configuration to specify work plugin:
```json
{
  "integrations": {
    "work_plugin": "fractary-work"
  }
}
```

---

#### FABER-401: Repo plugin not configured

**Severity:** Error
**Category:** Integration

**Description:**
The repository plugin is not configured but is required for this operation.

**Common Causes:**
- First time using FABER with repository operations
- Integration removed from configuration
- Repo plugin not installed

**Recovery:**
```bash
/fractary-repo:init
```

Then update FABER configuration to specify repo plugin:
```json
{
  "integrations": {
    "repo_plugin": "fractary-repo"
  }
}
```

---

#### FABER-402: Work item not found

**Severity:** Error
**Category:** Integration

**Description:**
The specified work item (issue, ticket) does not exist in the work tracking system.

**Common Causes:**
- Incorrect work item ID
- Work item was deleted
- Work item in different repository/project
- Authentication issue with work tracker

**Recovery:**
Verify work item ID exists in your work tracking system:
- GitHub: `gh issue view <id>`
- Jira: Check Jira web interface
- Linear: Check Linear web interface

---

#### FABER-403: Failed to create branch

**Severity:** Error
**Category:** Integration

**Description:**
Unable to create a Git branch through the repo plugin.

**Common Causes:**
- Branch already exists
- No write permissions on repository
- Invalid branch name
- Git not configured
- Remote repository unavailable

**Recovery:**
Check repository permissions and branch naming:
```bash
git branch -a  # List existing branches
git remote -v  # Verify remote configuration
```

Ensure branch name follows conventions (no spaces, special characters).

---

#### FABER-404: Failed to create specification

**Severity:** Error
**Category:** Integration

**Description:**
Unable to create implementation specification through spec plugin.

**Common Causes:**
- Spec plugin not configured
- No write permissions
- Invalid work item data
- Template not found

**Recovery:**
Check spec plugin configuration and disk space:
```bash
df -h  # Check disk space
ls -la .fractary/plugins/spec/  # Check permissions
```

---

#### FABER-405: Failed to create pull request

**Severity:** Error
**Category:** Integration

**Description:**
Unable to create pull request through repo plugin.

**Common Causes:**
- No commits on branch
- Branch not pushed to remote
- PR already exists
- No repository permissions
- PR title/body validation failed

**Recovery:**
Check repo permissions, branch status, and PR requirements:
```bash
git status  # Check branch status
git log origin/main..HEAD  # Check commits
gh pr list  # List existing PRs
```

Ensure:
- Branch has commits
- Branch is pushed to remote
- No existing PR for this branch
- PR title and body are valid

---

### Concurrency Errors (500-599)

Errors related to concurrent workflow execution and locking.

#### FABER-500: Failed to acquire workflow lock

**Severity:** Error
**Category:** Concurrency

**Description:**
Unable to acquire the workflow lock file to prevent concurrent execution.

**Common Causes:**
- Another FABER workflow is currently running
- Previous workflow did not release lock
- Lock file permissions issue
- flock not available

**Recovery:**
Another workflow is running. Wait or check lock status:
```bash
plugins/faber/skills/core/scripts/lock-check.sh
```

If lock is stale (no active process), it will be auto-cleaned on next run.

---

#### FABER-501: Concurrent workflow execution detected

**Severity:** Error
**Category:** Concurrency

**Description:**
Attempted to start a workflow while another workflow is already running.

**Common Causes:**
- Multiple FABER commands run simultaneously
- Previous workflow still executing
- Lock not released from previous run

**Recovery:**
Wait for other workflow to complete or manually release lock:
```bash
# Check lock status
plugins/faber/skills/core/scripts/lock-check.sh

# If process is no longer running, remove stale lock
plugins/faber/skills/core/scripts/lock-release.sh
```

---

#### FABER-502: Stale lock detected

**Severity:** Warning
**Category:** Concurrency

**Description:**
A lock file exists but the process that created it is no longer running.

**Common Causes:**
- Process killed or crashed
- System reboot
- Process terminated without cleanup

**Recovery:**
Stale lock will be auto-cleaned. Retry workflow execution:
```bash
/fractary-faber:run <work-id>
```

The lock will be automatically removed if it's older than 5 minutes and the PID is not active.

---

## Using Error Codes

### Reporting Errors

Use the error reporting script to display formatted error messages:

```bash
plugins/faber/skills/core/scripts/error-report.sh FABER-001
plugins/faber/skills/core/scripts/error-report.sh FABER-501 "Work item #123"
```

### Getting Recovery Suggestions

Extract recovery suggestions programmatically:

```bash
RECOVERY=$(plugins/faber/skills/core/scripts/error-recovery.sh FABER-403)
echo "$RECOVERY"
```

### In Scripts

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for configuration
if [ ! -f ".fractary/plugins/faber/config.json" ]; then
    "$SCRIPT_DIR/error-report.sh" FABER-001
    exit 1
fi

# Acquire lock
if ! "$SCRIPT_DIR/lock-acquire.sh"; then
    "$SCRIPT_DIR/error-report.sh" FABER-500
    exit 1
fi
```

## See Also

- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Problem-to-solution mapping
- [CONFIGURATION.md](./CONFIGURATION.md) - Configuration guide
- [STATE-TRACKING.md](./STATE-TRACKING.md) - State management guide
