# FABER GitHub Integration

Trigger FABER workflows from GitHub using GitHub Actions and issue labels.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Configuration](#configuration)
4. [Triggering Workflows](#triggering-workflows)
5. [Label-Based Configuration](#label-based-configuration)
6. [Examples](#examples)
7. [Security & Safety](#security--safety)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The FABER GitHub integration enables automated development workflows triggered by:
- **Issue labels** - Add `faber:run` label to trigger workflow
- **Issue comments** - Use slash commands in comments
- **Manual dispatch** - Trigger via GitHub Actions UI

FABER will:
1. **Parse issue context** - Extract requirements from issue title/body
2. **Execute the workflow** - Frame, Architect, Build, Evaluate, Release
3. **Post status updates** - Progress comments on the issue
4. **Create pull requests** - Link PR back to the issue

### Architecture

```
Issue labeled 'faber:run'
        ↓
GitHub Actions workflow triggers
        ↓
/fractary-faber:run --work-id {issue_number}
        ↓
FABER executes workflow phases
        ↓
Status updates posted to issue
        ↓
Pull request created and linked
```

---

## Quick Start

### 1. Set Up GitHub Actions

Create `.github/workflows/faber.yml` in your repository:

```yaml
name: FABER Workflow

on:
  issues:
    types: [labeled]
  workflow_dispatch:
    inputs:
      issue_number:
        description: 'Issue number to process'
        required: true
        type: string
      target:
        description: 'Target name (optional, inferred from issue if empty)'
        required: false
        type: string
      phases:
        description: 'Phases to run (comma-separated, e.g., frame,architect)'
        required: false
        type: string

jobs:
  faber:
    # Only run if 'faber:run' label was added
    if: github.event.label.name == 'faber:run' || github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get issue number
        id: issue
        run: |
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            echo "number=${{ github.event.inputs.issue_number }}" >> $GITHUB_OUTPUT
          else
            echo "number=${{ github.event.issue.number }}" >> $GITHUB_OUTPUT
          fi

      - name: Post starting comment
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: ${{ steps.issue.outputs.number }},
              body: '🎯 **FABER Workflow Starting**\n\nProcessing issue #${{ steps.issue.outputs.number }}...'
            })

      - name: Run FABER
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: |
            /fractary-faber:run --work-id ${{ steps.issue.outputs.number }} ${{ github.event.inputs.target && format('"{0}"', github.event.inputs.target) || '' }} ${{ github.event.inputs.phases && format('--phase {0}', github.event.inputs.phases) || '' }}

      - name: Remove trigger label
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            try {
              await github.rest.issues.removeLabel({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: ${{ steps.issue.outputs.number }},
                name: 'faber:run'
              });
            } catch (e) {
              // Label may already be removed
            }
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
      "file": "./workflows/default.json",
      "description": "Standard FABER workflow"
    }
  ],
  "integrations": {
    "work_plugin": "fractary-work",
    "repo_plugin": "fractary-repo"
  }
}
```

**Quick setup:**
```bash
# Initialize FABER configuration
/fractary-faber:init

# Commit configuration
git add .fractary/plugins/faber/
git commit -m "Add FABER configuration"
git push
```

### 4. Try It Out

1. Create a GitHub issue with clear requirements
2. Add the `faber:run` label to the issue
3. Watch FABER execute the workflow in the Actions tab
4. Status updates appear as issue comments
5. Review the created pull request

---

## Configuration

### Autonomy Levels

Control automation level in your workflow configuration:

| Level | Description | Behavior |
|-------|-------------|----------|
| `dry-run` | Simulation | No changes, shows what would happen |
| `assist` | Semi-automated | Stops before Release phase |
| `guarded` | Approval gates | Pauses at Release for approval |
| `autonomous` | Fully automated | Creates PR without pausing |

Configure in `.fractary/plugins/faber/workflows/default.json`:

```json
{
  "autonomy": {
    "level": "guarded",
    "require_approval_for": ["release"]
  }
}
```

### Safety Configuration

Protect critical files:

```json
{
  "safety": {
    "protected_paths": [
      ".github/**",
      "*.env",
      "secrets/**"
    ]
  }
}
```

---

## Triggering Workflows

### Method 1: Label Trigger (Recommended)

Add the `faber:run` label to any issue to trigger the workflow.

**Benefits:**
- Simple and visual
- Easy to track which issues are being processed
- Label automatically removed after workflow completes

### Method 2: Manual Dispatch

Trigger from the GitHub Actions UI:

1. Go to **Actions** → **FABER Workflow**
2. Click **Run workflow**
3. Enter the issue number
4. Optionally specify target and phases
5. Click **Run workflow**

**Benefits:**
- Fine-grained control over execution
- Can specify phases to run
- Useful for retries or partial execution

### Method 3: Issue Comment (Future)

Use slash commands in issue comments:

```
/faber run
/faber run --phase frame,architect
/faber status
```

*Note: Comment-based triggering requires additional GitHub Actions configuration.*

---

## Label-Based Configuration

Configure workflow behavior using issue labels with the `faber:` prefix:

| Label | Effect |
|-------|--------|
| `faber:run` | Triggers the workflow |
| `faber:workflow=hotfix` | Uses hotfix workflow |
| `faber:autonomy=autonomous` | Overrides autonomy level |
| `faber:phase=frame,architect` | Runs only specified phases |
| `faber:step=build:implement` | Runs only specified step |

### Priority Order

1. **GitHub Actions inputs** (highest)
2. **Issue labels** (`faber:*`)
3. **Config file defaults**
4. **Hardcoded fallbacks** (lowest)

### Examples

**Run with hotfix workflow:**
Add labels: `faber:run`, `faber:workflow=hotfix`

**Design only (no implementation):**
Add labels: `faber:run`, `faber:phase=frame,architect`

**Full autonomous run:**
Add labels: `faber:run`, `faber:autonomy=autonomous`

---

## Examples

### Example 1: Standard Workflow

**Issue #123: "Add CSV export feature"**

1. Add `faber:run` label
2. FABER posts starting comment
3. Executes all 5 phases
4. Posts progress updates
5. Creates PR #124 linked to issue
6. Removes `faber:run` label

**Result:**
```markdown
✅ FABER Workflow Complete

Work ID: abc12345
Duration: 8m 32s

Phases:
✓ Frame - Classified as feature
✓ Architect - Spec created
✓ Build - Implementation complete
✓ Evaluate - All tests passed
✓ Release - PR #124 created

Pull Request: https://github.com/owner/repo/pull/124
```

### Example 2: Design Only

**Issue #150: "Refactor authentication system"**

Labels: `faber:run`, `faber:phase=frame,architect`

**Result:**
- Creates design specification
- Stops before implementation
- Spec available at `.faber/specs/150.md`

### Example 3: Hotfix Workflow

**Issue #200: "Critical security patch"**

Labels: `faber:run`, `faber:workflow=hotfix`, `faber:autonomy=autonomous`

**Result:**
- Uses hotfix workflow (streamlined)
- Runs fully automated
- PR created immediately

---

## Security & Safety

### Permission Requirements

The GitHub Actions workflow requires:

```yaml
permissions:
  contents: write        # Commit changes, create branches
  issues: write          # Post comments, update labels
  pull-requests: write   # Create PRs
```

### Safety Mechanisms

1. **Protected paths** - Files that won't be modified
2. **Autonomy levels** - Control automation degree
3. **Label removal** - Prevents duplicate runs
4. **Audit trail** - All changes in issue comments

### Best Practices

1. Use `guarded` autonomy for production repos
2. Configure protected paths for sensitive files
3. Enable branch protection on main
4. Review all FABER-created PRs
5. Monitor workflow runs in Actions tab

---

## Troubleshooting

### Workflow Not Triggering

**Problem:** Adding label doesn't start workflow

**Solutions:**
1. Verify `.github/workflows/faber.yml` exists
2. Check workflow is enabled in Actions settings
3. Ensure label name is exactly `faber:run`
4. Check Actions logs for errors

### Configuration Not Found

**Error:** `Configuration not found`

**Solution:**
```bash
/fractary-faber:init
git add .fractary/plugins/faber/
git commit -m "Add FABER configuration"
git push
```

### Permission Errors

**Error:** `Failed to create branch` or `Failed to push`

**Solutions:**
1. Check `CLAUDE_CODE_OAUTH_TOKEN` secret is set
2. Verify workflow permissions in YAML
3. Check branch protection rules

### Phase Failures

**Error:** Phase failed with error

**Solutions:**
1. Check Actions logs for details
2. Review error in issue comments
3. Fix the issue
4. Add `faber:run` label again to retry

---

## Advanced Usage

### Custom Workflows

Create additional workflows for different scenarios:

```json
{
  "workflows": [
    {
      "id": "default",
      "file": "./workflows/default.json"
    },
    {
      "id": "hotfix",
      "file": "./workflows/hotfix.json"
    },
    {
      "id": "docs-only",
      "file": "./workflows/docs-only.json"
    }
  ]
}
```

Trigger with label: `faber:workflow=hotfix`

### Phase Selection

Run specific phases:

```bash
# Via manual dispatch
/fractary-faber:run --work-id 123 --phase frame,architect

# Via label
faber:phase=build,evaluate
```

### Step Selection

Run a single step:

```bash
# Via command
/fractary-faber:run --work-id 123 --step build:implement

# Via label
faber:step=evaluate:test
```

### Custom Instructions

Add instructions via `--prompt`:

```bash
/fractary-faber:run --work-id 123 --prompt "Focus on performance. Use caching."
```

---

## Migration from v1.x

If upgrading from v1.x with `@faber` mention support:

1. **Remove** `.github/workflows/faber.yml` that uses `/fractary-faber:mention`
2. **Create** new workflow using `/fractary-faber:run` (see Quick Start)
3. **Update** config from TOML to JSON (see MIGRATION-v2.md)
4. **Use labels** instead of mentions to trigger workflows

See [MIGRATION-v2.md](MIGRATION-v2.md) for detailed migration guide.

---

## Additional Resources

- [Configuration Guide](configuration.md)
- [Workflow Guide](workflow-guide.md)
- [Hooks Documentation](HOOKS.md)
- [Migration Guide](MIGRATION-v2.md)
- [FABER Architecture](architecture.md)

---

**Questions or feedback?** Open an issue: https://github.com/fractary/claude-plugins/issues
