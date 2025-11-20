# FABER GitHub Integration

Trigger FABER workflows directly from GitHub issues using `@faber` mentions.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Configuration](#configuration)
4. [Usage](#usage)
5. [Intent Types](#intent-types)
6. [Examples](#examples)
7. [Security & Safety](#security--safety)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The FABER GitHub integration enables you to trigger automated development workflows by mentioning `@faber` in GitHub issues and pull requests. FABER will:

1. **Parse your intent** from the mention text
2. **Execute the appropriate workflow** (full workflow, single phase, status check, or control command)
3. **Post status updates** back to the GitHub issue
4. **Create pull requests** when work is complete
5. **Respect your safety gates** and autonomy settings

### How It Works

```
User mentions @faber in issue
         ↓
GitHub Actions workflow triggers
         ↓
FABER parses intent and loads config
         ↓
Director orchestrates workflow phases
         ↓
Status updates post to issue
         ↓
Pull request created (if applicable)
```

---

## Quick Start

### 1. Set Up GitHub Actions

Create `.github/workflows/faber.yml` in your repository:

```yaml
name: FABER Workflow

on:
  issue_comment:
    types: [created]
  issues:
    types: [opened, assigned]

jobs:
  faber:
    if: contains(github.event.comment.body, '@faber') || contains(github.event.issue.body, '@faber')
    runs-on: ubuntu-latest
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: '/faber:mention'
        env:
          GITHUB_CONTEXT: ${{ toJson(github) }}
```

### 2. Add GitHub Secret

Add your Claude Code OAuth token to repository secrets:

1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `CLAUDE_CODE_OAUTH_TOKEN`
4. Value: Your Claude Code OAuth token
5. Click **Add secret**

### 3. Create FABER Configuration

Create `.fractary/plugins/faber/config.json` in your repository:

```json
{
  "schema_version": "2.0",
  "workflows": [
    {
      "id": "default",
      "description": "Standard FABER workflow",
      "phases": {
        "frame": { "enabled": true },
        "architect": { "enabled": true },
        "build": { "enabled": true },
        "evaluate": { "enabled": true },
        "release": { "enabled": true }
      },
      "autonomy": {
        "level": "guarded",
        "pause_before_release": true,
        "require_approval_for": ["release"]
      }
    }
  ],
  "integrations": {
    "work_plugin": "fractary-work",
    "repo_plugin": "fractary-repo",
    "spec_plugin": "fractary-spec",
    "logs_plugin": "fractary-logs"
  },
  "logging": {
    "use_logs_plugin": true,
    "log_type": "workflow"
  },
  "safety": {
    "protected_paths": [".github/**", "*.env", "secrets/**"],
    "require_confirm_for": ["release", "merge_to_main"]
  }
}
```

**Quick setup:**
```bash
# Initialize FABER configuration
/fractary-faber:init

# Or copy from example template
cp plugins/faber/config/faber.example.json .fractary/plugins/faber/config.json

# Commit configuration
git add .fractary/plugins/faber/config.json
git commit -m "Add FABER configuration"
git push
```

**Note**: v2.0 uses JSON configuration (`.fractary/plugins/faber/config.json`). If you have a v1.x TOML config (`.faber.config.toml`), see [MIGRATION-v2.md](MIGRATION-v2.md) for upgrade instructions.

### 4. Try It Out

1. Create or open a GitHub issue
2. Comment: `@faber run this issue`
3. Watch FABER execute the workflow
4. Status updates appear as issue comments
5. Approve release when ready: `@faber approve`

---

## Configuration

### Autonomy Levels

Control how much automation FABER applies:

#### `dry-run` - Simulation Only
```json
{
  "workflows": [{
    "autonomy": {
      "level": "dry-run"
    }
  }]
}
```
- Simulates all phases
- **No actual changes made**
- Shows what would happen
- Ideal for testing

#### `assist` - Stops Before Release
```json
{
  "workflows": [{
    "autonomy": {
      "level": "assist",
      "stop_before": "release"
    }
  }]
}
```
- Executes Frame → Architect → Build → Evaluate
- **Stops before Release**
- Manual approval required to proceed
- Good for learning FABER

#### `guarded` - Pauses at Release (Recommended)
```json
{
  "workflows": [{
    "autonomy": {
      "level": "guarded",
      "pause_before_release": true,
      "require_approval_for": ["release"]
    }
  }]
}
```
- Executes all phases
- **Pauses at Release for approval**
- Posts status asking for confirmation
- Reply with `@faber approve` to proceed
- **Recommended for production use**

#### `autonomous` - Fully Automated
```json
{
  "workflows": [{
    "autonomy": {
      "level": "autonomous"
    }
  }]
}
```
- Executes all phases without pausing
- Creates PR and optionally merges
- **No human intervention required**
- Use with caution!

### Safety Configuration

Protect critical files and operations:

```json
{
  "safety": {
    "require_confirm_for": [
      "release",
      "merge_to_main",
      "deploy_production"
    ],
    "protected_paths": [
      ".github/**",
      "*.env",
      "**/.env*",
      "secrets/**",
      "**/credentials*",
      "infra/prod/**",
      "terraform.tfstate"
    ]
  }
}
```

### Workflow Settings

Control retry behavior in phase configuration:

```json
{
  "workflows": [{
    "phases": {
      "evaluate": {
        "enabled": true,
        "max_retries": 3,
        "retry_on_failure": true
      },
      "release": {
        "enabled": true,
        "auto_merge": false,
        "auto_close_work_item": true
      }
    }
  }]
}
```

---

## Usage

### Triggering Workflows

Mention `@faber` in:
- **Issue comments**
- **Issue descriptions** (when creating issues)
- **Pull request review comments**
- **Pull request reviews**

### Basic Syntax

```
@faber <intent>
```

Where `<intent>` is what you want FABER to do (see [Intent Types](#intent-types) below).

---

## Intent Types

FABER supports four types of intents:

### 1. Full Workflow

Execute complete Frame → Architect → Build → Evaluate → Release workflow.

**Patterns:**
- `@faber run this issue`
- `@faber work on this`
- `@faber handle this`
- `@faber do this`
- `@faber` (empty mention defaults to full workflow)

**What happens:**
1. Frame: Fetch issue, classify, setup branch
2. Architect: Design solution, create spec
3. Build: Implement from spec
4. Evaluate: Run tests (with retries)
5. Release: Create PR, optionally merge

### 2. Single Phase Execution

Execute only specific phases of the workflow.

#### Frame Only
```
@faber just frame this
@faber setup this issue
```
- Fetches issue and classifies work type
- Stops after framing

#### Architect Only (Design)
```
@faber just design this
@faber create a spec for this
@faber just architect, don't implement
```
- Executes Frame → Architect
- Creates design spec at `.faber/specs/{issue_id}.md`
- Stops before implementation

#### Build (Implementation)
```
@faber just implement this
@faber only build this
```
- Executes Frame → Architect → Build
- Implements the solution
- Stops before testing

#### Evaluate (Testing)
```
@faber test this
@faber just run tests
@faber evaluate this work
```
- Runs tests on current state
- Requires existing implementation
- Stops after evaluation

#### Release Only
```
@faber release this
@faber create pr for this
@faber deploy this
```
- Creates pull request
- Requires completed work
- Safety: requires approval in guarded mode

### 3. Status Queries

Check the current status of a workflow.

**Patterns:**
```
@faber status
@faber what's the progress?
@faber where are we?
@faber show me progress
```

**Response:**
```markdown
📊 FABER Workflow Status

Work ID: abc12345
Current Phase: Build

Progress:
- Frame: completed
- Architect: completed
- Build: in_progress
- Evaluate: pending
- Release: pending

State File: .fractary/plugins/faber/state.json
```

### 4. Control Commands

Control active workflows.

#### Approve Release
```
@faber approve
@faber approve release
@faber looks good
@faber LGTM
@faber proceed
```
- Proceeds with release phase
- Only works when paused at release gate (guarded mode)

#### Retry Failed Phase
```
@faber retry
@faber try again
@faber retry evaluation
```
- Retries the last failed phase
- Useful after fixing issues

#### Cancel Workflow
```
@faber cancel
@faber stop
@faber abort
```
- Cancels the active workflow
- Marks session as cancelled

---

## Examples

### Example 1: Full Workflow

**Issue #123: "Add CSV export feature"**

```
User: @faber run this issue
```

**FABER Response:**
```markdown
🎯 FABER Workflow Starting

Intent: run this issue
Work ID: abc12345
Autonomy: guarded
Triggered by: @username

Processing your request...
```

**Phase Updates:**
```markdown
✅ Frame Complete
- Fetched issue details
- Classified as: feature
- Created branch: faber/123-add-csv-export
- Setup environment
Next: Architect phase
───────────────────────────────

✅ Architect Complete
- Designed solution architecture
- Created specification: .faber/specs/123.md
- Identified components: CSV serializer, download endpoint
Next: Build phase
───────────────────────────────

✅ Build Complete
- Implemented CSV serializer (src/lib/csv.ts)
- Created download endpoint (src/routes/api/export.ts)
- Added tests (src/lib/csv.test.ts)
- Created commit: feat: Add CSV export feature (#123)
Next: Evaluate phase
───────────────────────────────

✅ Evaluate Complete
- All tests passed ✓
- Linting passed ✓
- Type checking passed ✓
- Build successful ✓
Next: Release phase (awaiting approval)

⚠️ APPROVAL REQUIRED
Reply with: @faber approve release
───────────────────────────────
```

```
User: @faber approve release
```

```markdown
✅ Release Complete
- Created PR: #124
- PR link: https://github.com/owner/repo/pull/124
- All checks passed
- Ready for review

🎉 WORKFLOW COMPLETE
Branch: faber/123-add-csv-export
PR: #124
Duration: 3m 42s
```

### Example 2: Design Only

**Issue #150: "Refactor authentication system"**

```
User: @faber just design this, I'll implement myself
```

```markdown
🎯 FABER: phase_architect

Interpretation: Executing up to architect phase only
───────────────────────────────

✅ Frame Complete
- Fetched issue details
- Classified as: refactoring
- Analyzed current auth system
───────────────────────────────

✅ Architect Complete
- Created design specification: .faber/specs/150.md
- Outlined migration strategy
- Identified breaking changes
- Estimated effort: 2-3 days

📄 Specification created. Review at: .faber/specs/150.md

Stopping as requested. When ready to implement:
- @faber build (to implement the design)
- @faber run (to complete full workflow)
```

### Example 3: Status Check

**Issue #155: "Optimize database queries"**

Context: Workflow started earlier, now running.

```
User: @faber status
```

```markdown
📊 FABER Workflow Status
Issue: #155
Branch: faber/155-optimize-database-queries
───────────────────────────────

Current Phase: Evaluate
Progress: ████████░░ 80%

Completed:
✓ Frame (2m ago)
✓ Architect (5m ago)
✓ Build (8m ago)

In Progress:
⏳ Evaluate
  - Tests: Running...
  - Lint: Passed ✓
  - Type check: Passed ✓

Pending:
○ Release

Last Update: 30 seconds ago
State: .fractary/plugins/faber/state.json
```

### Example 4: Test and Retry

**Issue #160: "Fix login validation bug"**

```
User: @faber just test this
```

```markdown
🧪 FABER Evaluate Phase
Intent: Test only
───────────────────────────────

⏳ Running Evaluation...
- Installing dependencies...
- Running test suite...
───────────────────────────────

❌ Evaluation Failed
- Tests: 2 failed, 45 passed
- Lint: Passed ✓
- Type check: Passed ✓

Failed Tests:
  ✗ src/auth/login.test.ts
    - "should validate email format"
    - "should reject invalid passwords"

Review the failures and fix the code.
Then retry with: @faber retry evaluate
```

User fixes code, then:

```
User: @faber retry evaluate
```

```markdown
✅ Evaluate Complete
- Tests: All passed ✓
- Lint: Passed ✓
- Type check: Passed ✓

Tests are passing. Use @faber release to create PR.
```

### Example 5: Configuration Missing

**Issue #165: "Add dark mode"**

```
User: @faber run this
```

```markdown
❌ FABER Configuration Not Found

FABER requires a configuration file to run.

Setup Instructions:

1. Initialize configuration:
   /fractary-faber:init

2. Or copy example template:
   cp plugins/faber/config/faber.example.json .fractary/plugins/faber/config.json

3. Customize settings (optional):
   vim .fractary/plugins/faber/config.json

4. Commit the configuration:
   git add .fractary/plugins/faber/config.json
   git commit -m "Add FABER configuration"
   git push

5. Mention @faber again to start workflow

Documentation:
- [FABER Setup Guide](https://docs.fractary.com/faber/setup)
- [Configuration Reference](https://docs.fractary.com/faber/config)

Triggered by: @username
```

---

## Security & Safety

### Permission Requirements

The GitHub Actions workflow requires these permissions:

```yaml
permissions:
  contents: write        # Read repo, commit changes, create branches
  issues: write          # Post comments, update labels
  pull-requests: write   # Create PRs, post comments
```

These are **repository-level permissions**. The workflow can only modify the repository it's running in.

### Safety Mechanisms

#### 1. Configuration-Based Safety

All safety rules are defined in `.fractary/plugins/faber/config.json`:
- Protected paths prevent modification
- Confirmation gates require approval
- Autonomy levels control automation degree

#### 2. Protected Paths

Default protected paths (never auto-modified):

```json
{
  "safety": {
    "protected_paths": [
      ".github/**",
      "*.env",
      "**/.env*",
      "secrets/**",
      "**/credentials*",
      "infra/prod/**",
      "terraform.tfstate",
      "*.pem",
      "*.key"
    ]
  }
}
```

Add project-specific paths as needed.

#### 3. Autonomy Levels

- **dry-run**: No actual changes (simulation only)
- **assist**: Stops before release
- **guarded**: Pauses at release for approval ✅ **Recommended**
- **autonomous**: Full automation (use carefully)

#### 4. Confirmation Gates

Operations requiring explicit approval (in guarded mode):
- Release phase
- Merge to main/master branch
- Production deployments
- Destructive operations

#### 5. Audit Trail

All workflow activity is logged:
- Issue comments show every phase completion
- Current state in `.fractary/plugins/faber/state.json`
- Historical logs via fractary-logs plugin
- All commits reference issue ID
- PRs link back to original issue

### Security Best Practices

1. **Use guarded mode** for production repositories
2. **Review protected paths** and add project-specific ones
3. **Store secrets properly** (GitHub Secrets, not in repo)
4. **Enable branch protection** on main/master
5. **Require PR reviews** before merging
6. **Limit who can approve** FABER releases
7. **Monitor workflow runs** in GitHub Actions
8. **Review FABER commits** before merging PRs

---

## Troubleshooting

### Configuration Not Found

**Error:**
```
❌ Configuration not found
```

**Solution:**
1. Initialize FABER configuration: `/fractary-faber:init`
2. Or copy template: `cp plugins/faber/config/faber.example.json .fractary/plugins/faber/config.json`
3. Commit and push
4. Try mentioning `@faber` again

### Configuration Invalid

**Error:**
```
❌ Configuration validation failed
```

**Solution:**
1. Check JSON syntax: https://jsonlint.com/
2. Review error message for specific issues
3. Compare with example: `plugins/faber/config/faber.example.json`
4. Validate schema version is "2.0"
5. Check required fields: `workflows`, `integrations`

### Permission Errors

**Error:**
```
Failed to fetch issue #123
```

**Solution:**
1. Verify `CLAUDE_CODE_OAUTH_TOKEN` secret is set
2. Check workflow permissions in `.github/workflows/faber.yml`
3. Ensure permissions include: `contents: write`, `issues: write`, `pull-requests: write`
4. Verify token hasn't expired

### Workflow Not Triggering

**Problem:** Mentioning `@faber` doesn't start workflow

**Solution:**
1. Check `.github/workflows/faber.yml` exists
2. Verify workflow is enabled (Actions tab → FABER Workflow)
3. Check workflow syntax (Actions tab shows errors)
4. Ensure `@faber` is in comment body (not just title)
5. Check event triggers match your use case

### Phase Failures

**Error:**
```
❌ [Phase] phase failed
```

**Solution:**
1. Check GitHub Actions logs for details
2. Review state file: `.fractary/plugins/faber/state.json`
3. Check error message in issue comments
4. Fix the underlying issue
5. Retry: `@faber retry`

### Cannot Find Session

**Error:**
```
No active workflow session found
```

**Solution:**
1. Start a workflow first: `@faber run this issue`
2. Check if state file exists: `.fractary/plugins/faber/state.json`
3. State file tracks single active workflow
4. Check workflow logs via fractary-logs plugin for historical data

### Approval Not Working

**Error:**
```
⚠️ No workflow awaiting approval
```

**Solution:**
1. Check workflow is actually paused: `@faber status`
2. Verify autonomy level is "guarded" in config
3. Ensure workflow reached release phase
4. Check state in `.fractary/plugins/faber/state.json`

### Getting Help

If you encounter issues not covered here:

1. **Check logs**: GitHub Actions → FABER Workflow → View run details
2. **Review state**: `.fractary/plugins/faber/state.json`
3. **Check documentation**: `plugins/faber/docs/`
4. **Create issue**: https://github.com/fractary/claude-plugins/issues
5. **Community**: [Discord](https://discord.gg/fractary)

---

## Advanced Usage

### Multiple Workflows

Run multiple workflows on the same issue:

```
@faber just design this     # Creates design spec
# Review the spec in .faber/specs/123.md
@faber just build this      # Implements the design
# Review the implementation
@faber test this            # Run tests
@faber release              # Create PR
```

Each command creates a new work_id and session.

### Custom Workflows

Override configuration per-issue by editing `.fractary/plugins/faber/config.json` in a branch:

1. Create branch: `config-changes`
2. Edit `.fractary/plugins/faber/config.json`
3. Push branch
4. Create issue referencing the branch
5. `@faber run this issue` will use branch config

### Integration with Other Tools

FABER works alongside:
- **CI/CD**: PR checks run independently
- **Code review**: PRs follow normal review process
- **Monitoring**: Workflow runs visible in Actions
- **Issue tracking**: Status updates in issue comments

---

## FAQ

### Does FABER replace code review?

**No.** FABER creates pull requests that go through your normal review process. It's a development assistant, not a replacement for human oversight.

### Can I use FABER on private repositories?

**Yes.** FABER works with both public and private repositories. Ensure your `CLAUDE_CODE_OAUTH_TOKEN` has access.

### What happens if FABER makes a mistake?

All changes go through PRs. You can:
1. Review the PR and request changes
2. Close the PR and provide feedback
3. Edit the PR directly
4. Ask FABER to retry with specific instructions

### How much does it cost?

FABER uses Claude Code, which has usage-based pricing. Cost depends on:
- Complexity of issues
- Number of retries
- Codebase size
- Frequency of use

See [Claude Code Pricing](https://claude.com/pricing).

### Can FABER work with monorepos?

**Yes.** Configure paths and modules in `.fractary/plugins/faber/config.json`. FABER respects your project structure.

### Does FABER support multiple languages?

**Yes.** FABER is language-agnostic. It adapts to your project's languages and frameworks.

---

## Version History

- **v2.0.0** (2025-11-20): FABER v2.0 Architecture
  - Universal workflow-manager (60% context reduction)
  - JSON configuration (`.fractary/plugins/faber/config.json`)
  - Dual-state tracking (state + logs)
  - Prompt customization support
  - Phase-level hooks

- **v1.1.0** (2025-10-31): GitHub integration added
  - `@faber` mention support
  - Intent parsing (full workflow, single phase, status, control)
  - Status card posting to issues
  - Approval workflow for guarded mode

---

## Additional Resources

- **FABER Architecture**: `specs/SPEC-00002-faber-architecture.md`
- **Configuration Reference**: `plugins/faber/config/faber.example.json`
- **Configuration Guide**: `plugins/faber/docs/configuration.md`
- **Migration Guide**: `plugins/faber/docs/MIGRATION-v2.md`
- **Command Reference**: `plugins/faber/commands/`
- **Agent Documentation**: `plugins/faber/agents/`
- **Plugin Standards**: `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`

---

**Questions or feedback?** Open an issue: https://github.com/fractary/claude-plugins/issues
