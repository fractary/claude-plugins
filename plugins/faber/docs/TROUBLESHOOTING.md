# FABER Troubleshooting Guide

This guide helps you diagnose and resolve common FABER workflow issues.

## Quick Diagnostics

Start with the diagnostic script to check system health:

```bash
plugins/faber/skills/core/scripts/diagnostics.sh
```

For detailed output:

```bash
plugins/faber/skills/core/scripts/diagnostics.sh --verbose
```

## Common Problems

### Installation & Setup

#### Problem: "Configuration file not found"

**Symptoms:**
- Error message: `FABER-001: Configuration file not found`
- Cannot run `/fractary-faber:run`
- First time using FABER in project

**Solution:**
```bash
/fractary-faber:init
```

This creates `.fractary/plugins/faber/config.json` with default settings.

**Related Error Codes:** FABER-001

---

#### Problem: Work or Repo plugin not configured

**Symptoms:**
- Error message: `FABER-400: Work plugin not configured` or `FABER-401: Repo plugin not configured`
- FABER cannot fetch issues or create branches
- Integration operations fail

**Solution:**
```bash
# Initialize work tracking plugin
/fractary-work:init

# Initialize repository plugin
/fractary-repo:init

# Update FABER configuration
# Edit .fractary/plugins/faber/config.json:
{
  "integrations": {
    "work_plugin": "fractary-work",
    "repo_plugin": "fractary-repo"
  }
}
```

**Related Error Codes:** FABER-400, FABER-401

---

### Configuration Issues

#### Problem: Invalid configuration after manual editing

**Symptoms:**
- Error message: `FABER-002: Invalid JSON` or `FABER-003: Schema validation failed`
- FABER refuses to start
- Syntax errors in configuration

**Diagnosis:**
```bash
# Validate configuration
plugins/faber/skills/core/scripts/config-validate.sh .fractary/plugins/faber/config.json
```

**Solutions:**

**Option 1:** Fix syntax errors
```bash
# Use a JSON validator to identify errors
# Fix missing commas, brackets, quotes
# Re-run validation
```

**Option 2:** Restore from template
```bash
# Backup current config
cp .fractary/plugins/faber/config.json .fractary/plugins/faber/config.json.backup

# Restore from template
cp plugins/faber/config/templates/standard.json .fractary/plugins/faber/config.json

# Re-apply your customizations
```

**Related Error Codes:** FABER-002, FABER-003, FABER-004

---

#### Problem: "Invalid autonomy level specified"

**Symptoms:**
- Error message: `FABER-005: Invalid autonomy level specified`
- Typo in autonomy level setting

**Solution:**
Edit `.fractary/plugins/faber/config.json` and use one of these values:
- `dry-run` - Preview only, no changes
- `assist` - Execute through Build, pause before Release
- `guarded` - Execute all phases, require approval for Release (recommended)
- `autonomous` - Full automation, no approvals

Example:
```json
{
  "workflows": [{
    "autonomy": {
      "level": "guarded"
    }
  }]
}
```

**Related Error Codes:** FABER-005

---

### Workflow Execution

#### Problem: Workflow won't start - "Failed to acquire lock"

**Symptoms:**
- Error message: `FABER-500: Failed to acquire workflow lock` or `FABER-501: Concurrent workflow detected`
- Another workflow is running
- Previous workflow didn't complete properly

**Diagnosis:**
```bash
plugins/faber/skills/core/scripts/lock-check.sh
```

**Solutions:**

**If another workflow is running:**
```bash
# Wait for it to complete, or
# Cancel the other workflow if needed
```

**If lock is stale (process no longer exists):**
```bash
# Check lock status
plugins/faber/skills/core/scripts/lock-check.sh

# If PID is dead, remove lock
plugins/faber/skills/core/scripts/lock-release.sh

# Retry workflow
/fractary-faber:run <work-id>
```

**Prevention:**
Stale locks (>5 minutes old) are automatically cleaned on next run.

**Related Error Codes:** FABER-500, FABER-501, FABER-502

---

#### Problem: Phase execution fails

**Symptoms:**
- Error message: `FABER-200: Phase execution failed`
- Workflow stops mid-execution
- Phase returns error status

**Diagnosis:**
1. Review phase output for specific errors
2. Check state file for details:
   ```bash
   plugins/faber/skills/core/scripts/state-read.sh .current_phase
   plugins/faber/skills/core/scripts/state-read.sh .phase_results
   ```

**Solutions:**

**For Frame phase failures:**
- Verify work item exists: `gh issue view <id>`
- Check work plugin configuration
- Ensure network connectivity

**For Architect phase failures:**
- Verify spec plugin is configured
- Check disk space: `df -h`
- Review work item has sufficient detail

**For Build phase failures:**
- Review build errors in output
- Check dependencies are installed
- Verify code compiles/runs

**For Evaluate phase failures:**
- Check test failures
- Review validation criteria
- Fix failing tests before retrying

**For Release phase failures:**
- Ensure commits exist on branch
- Check branch is pushed to remote
- Verify PR requirements met
- Check repository permissions

**Resume after fixing:**
```bash
/fractary-faber:run <work-id> --resume
```

**Related Error Codes:** FABER-200, FABER-201, FABER-202, FABER-203

---

#### Problem: Work item not found

**Symptoms:**
- Error message: `FABER-402: Work item not found`
- Cannot fetch issue details
- Frame phase fails immediately

**Solutions:**
```bash
# Verify work item exists
gh issue view <id>

# Check you're in the right repository
git remote -v

# Verify work plugin authentication
/fractary-work:init
```

**Related Error Codes:** FABER-402

---

### State Management

#### Problem: Corrupted state file

**Symptoms:**
- Error message: `FABER-101: Invalid JSON` or `FABER-102: Schema validation failed`
- Cannot resume workflow
- State file appears corrupted

**Solutions:**

**Option 1:** Restore from backup
```bash
# List available backups
ls -lt .fractary/plugins/faber/backups/

# Restore most recent backup
cp .fractary/plugins/faber/backups/state-YYYYMMDD_HHMMSS.json .fractary/plugins/faber/state.json

# Resume workflow
/fractary-faber:run <work-id> --resume
```

**Option 2:** Start fresh
```bash
# Backup corrupted state for analysis
mv .fractary/plugins/faber/state.json .fractary/plugins/faber/state.json.corrupted

# Initialize new state
plugins/faber/skills/core/scripts/state-init.sh <work-id>

# Restart workflow (cannot resume)
/fractary-faber:run <work-id>
```

**Related Error Codes:** FABER-100, FABER-101, FABER-102

---

#### Problem: State version mismatch

**Symptoms:**
- Warning message: `FABER-103: State version mismatch`
- Recently upgraded FABER version
- State file from older version

**Solution:**
```bash
# Migrate state to current version
plugins/faber/skills/core/scripts/state-migrate.sh

# Verify migration
plugins/faber/skills/core/scripts/state-validate.sh .fractary/plugins/faber/state.json
```

**Related Error Codes:** FABER-103

---

#### Problem: Cannot write state file

**Symptoms:**
- Error message: `FABER-104: Failed to write state file`
- Workflow crashes during state updates
- Permission denied errors

**Diagnosis:**
```bash
# Check disk space
df -h

# Check permissions
ls -la .fractary/plugins/faber/

# Check directory exists
ls -d .fractary/plugins/faber/
```

**Solutions:**

**If disk is full:**
```bash
# Free up disk space
# Clean old backups
find .fractary/plugins/faber/backups/ -type f -mtime +30 -delete
```

**If permission issues:**
```bash
# Fix directory permissions
chmod -R u+w .fractary/plugins/faber/

# Verify ownership
ls -la .fractary/plugins/faber/
```

**If directory missing:**
```bash
# Create directory structure
mkdir -p .fractary/plugins/faber/{backups,logs}
```

**Related Error Codes:** FABER-104

---

### Integration Issues

#### Problem: Cannot create branch

**Symptoms:**
- Error message: `FABER-403: Failed to create branch`
- Frame phase fails during branch creation
- "Branch already exists" error

**Solutions:**

**If branch exists:**
```bash
# List branches
git branch -a | grep <work-id>

# Delete existing branch if needed
git branch -D feat/<work-id>-description
git push origin --delete feat/<work-id>-description
```

**If permission issues:**
```bash
# Check repository permissions
git remote -v
gh auth status

# Re-authenticate if needed
gh auth login
```

**If branch name is invalid:**
```bash
# Verify branch naming conventions
# Valid: feat/123-add-feature
# Invalid: feat/123 add feature (spaces not allowed)
```

**Related Error Codes:** FABER-403

---

#### Problem: Cannot create pull request

**Symptoms:**
- Error message: `FABER-405: Failed to create pull request`
- Release phase fails
- "No commits" or "PR already exists" errors

**Diagnosis:**
```bash
# Check commits on branch
git log origin/main..HEAD

# Check if branch is pushed
git status

# List existing PRs
gh pr list
```

**Solutions:**

**If no commits:**
```bash
# Verify changes were committed
git status
git log

# If changes not committed, commit them
/fractary-repo:commit "Your message" --work-id <id>
```

**If branch not pushed:**
```bash
# Push branch to remote
/fractary-repo:push
```

**If PR already exists:**
```bash
# View existing PR
gh pr view

# Close old PR if needed
gh pr close <number>

# Or update existing PR instead of creating new one
```

**Related Error Codes:** FABER-405

---

### Hook Issues

#### Problem: Hook execution fails

**Symptoms:**
- Warning message: `FABER-300: Hook execution failed`
- Hook script returns non-zero exit code
- Missing hook dependencies

**Diagnosis:**
```bash
# Test hook manually
plugins/path/to/hook-script.sh

# Check hook has execute permissions
ls -la plugins/path/to/hook-script.sh

# Review hook configuration
jq '.workflows[0].hooks' .fractary/plugins/faber/config.json
```

**Solutions:**

**Make hook executable:**
```bash
chmod +x plugins/path/to/hook-script.sh
```

**Fix hook script errors:**
```bash
# Test hook with bash -x for debugging
bash -x plugins/path/to/hook-script.sh

# Review error output
# Fix script errors
```

**Check hook dependencies:**
```bash
# Ensure required tools are installed
# Review script requirements
# Install missing dependencies
```

**Related Error Codes:** FABER-300, FABER-301, FABER-302, FABER-303

---

## Performance Issues

### Problem: Workflow runs slowly

**Possible Causes:**
- Large repository
- Slow network connection
- Expensive hooks
- Many validation steps

**Solutions:**

**Optimize hooks:**
```bash
# Review hook execution times
# Remove unnecessary operations
# Make hooks asynchronous if possible
# Increase timeout if needed
```

**Reduce validation:**
```bash
# Disable non-essential validation steps in configuration
# Run expensive validations only in CI/CD
```

**Use local operations:**
```bash
# Cache work item data
# Minimize API calls
# Use git worktrees for parallel work
```

---

### Problem: Disk space issues

**Symptoms:**
- Error message: `FABER-104: Failed to write state file`
- Workflow crashes unexpectedly
- Cannot create backups

**Solutions:**

**Clean old backups:**
```bash
# Remove backups older than 30 days
find .fractary/plugins/faber/backups/ -type f -mtime +30 -delete

# Keep only last 10 backups
ls -t .fractary/plugins/faber/backups/ | tail -n +11 | xargs -I {} rm .fractary/plugins/faber/backups/{}
```

**Clean logs:**
```bash
# Review and remove old logs
ls -la .fractary/plugins/faber/logs/
rm .fractary/plugins/faber/logs/old-log-file.txt
```

**Check disk usage:**
```bash
df -h
du -sh .fractary/
```

---

## Debugging Tips

### Enable verbose logging

```bash
# Run with verbose output
/fractary-faber:run <work-id> --verbose

# Check diagnostics
plugins/faber/skills/core/scripts/diagnostics.sh --verbose
```

### Inspect state

```bash
# View entire state
cat .fractary/plugins/faber/state.json | jq

# Query specific fields
plugins/faber/skills/core/scripts/state-read.sh .work_id
plugins/faber/skills/core/scripts/state-read.sh .current_phase
plugins/faber/skills/core/scripts/state-read.sh .phase_results
```

### Check configuration

```bash
# Validate configuration
plugins/faber/skills/core/scripts/config-validate.sh .fractary/plugins/faber/config.json

# View configuration
cat .fractary/plugins/faber/config.json | jq
```

### Review logs

```bash
# List recent logs
ls -lt .fractary/plugins/faber/logs/

# View specific log
cat .fractary/plugins/faber/logs/workflow-YYYYMMDD-HHMMSS.log
```

### Test in dry-run mode

```bash
# See what will happen without making changes
/fractary-faber:run <work-id> --autonomy dry-run
```

---

## Getting Help

### Run diagnostics

```bash
plugins/faber/skills/core/scripts/diagnostics.sh --verbose
```

### Check system status

```bash
# Configuration status
plugins/faber/skills/core/scripts/config-validate.sh .fractary/plugins/faber/config.json

# State status
plugins/faber/skills/core/scripts/state-validate.sh .fractary/plugins/faber/state.json

# Lock status
plugins/faber/skills/core/scripts/lock-check.sh

# Dependencies
command -v jq
command -v flock
command -v gh
```

### Report issues

When reporting issues, include:

1. **Error code and message:**
   ```bash
   FABER-XXX: Error message
   ```

2. **Diagnostic output:**
   ```bash
   plugins/faber/skills/core/scripts/diagnostics.sh --verbose > diagnostics.txt
   ```

3. **Configuration (sanitized):**
   ```bash
   cat .fractary/plugins/faber/config.json | jq 'del(.integrations.tokens)' > config-sanitized.json
   ```

4. **State (if relevant):**
   ```bash
   cat .fractary/plugins/faber/state.json > state.json
   ```

5. **Steps to reproduce**

6. **Expected vs actual behavior**

---

## Preventive Maintenance

### Regular tasks

**Daily:**
- Review workflow execution logs
- Check for failed workflows

**Weekly:**
- Clean old backups (>30 days)
- Review and optimize hooks
- Validate configuration

**Monthly:**
- Update FABER to latest version
- Review and update configuration
- Clean stale worktrees: `/fractary-repo:worktree-cleanup --stale`

### Best practices

1. **Use version control for configuration:**
   ```bash
   git add .fractary/plugins/faber/config.json
   git commit -m "docs: update FABER configuration"
   ```

2. **Test changes in dry-run mode first:**
   ```bash
   /fractary-faber:run <work-id> --autonomy dry-run
   ```

3. **Keep backups:**
   ```bash
   # Automatic backups are created, verify they exist
   ls -la .fractary/plugins/faber/backups/
   ```

4. **Monitor disk space:**
   ```bash
   df -h
   ```

5. **Validate after configuration changes:**
   ```bash
   plugins/faber/skills/core/scripts/config-validate.sh .fractary/plugins/faber/config.json
   ```

---

## See Also

- [ERROR-CODES.md](./ERROR-CODES.md) - Complete error code reference
- [CONFIGURATION.md](./CONFIGURATION.md) - Configuration guide
- [STATE-TRACKING.md](./STATE-TRACKING.md) - State management details
- [HOOKS.md](./HOOKS.md) - Phase hooks guide
