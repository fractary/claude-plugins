---
org: omnidas
system: codex.omnidas.ai
title: Codex Sync Agent Guide
description: Operational reference for the codex-sync-manager agent - documentation sync workflows, commands, and procedures
codex_sync_include: [*]
codex_sync_exclude: []
tags: [guide, codex, sync, workflows, agent-reference]
created: 2025-09-30
updated: 2025-09-30
visibility: internal
audience: [agents]
---

# Codex Sync Agent Guide

This document provides operational reference information for the codex-sync-manager agent. For setup and administration, see [Codex Core Setup Guide](./codex-core-setup-guide.md). For distribution publishing, see [Codex Distro Agent Guide](./codex-distro-agent-guide.md). For architectural details, see [Codex Core Architecture](/docs/architecture/codex-core-architecture.md).

## File Structure

```
codex.omnidas.ai/
├── .github/                                    # GitHub Actions Infrastructure
│   └── workflows/
│       ├── omnidas-codex-sync-pull-docs.yml        # Pull docs from projects
│       ├── omnidas-codex-sync-push-docs.yml    # Push docs to projects
│       └── omnidas-codex-sync-push-claude.yml  # Push Claude tools
│
├── .claude/                                    # Claude AI Tools
│   ├── agents/omnidas/codex/
│   │   └── codex-sync-manager.md                      # Sync manager agent
│   ├── commands/omnidas/codex/
│   │   └── codex-sync-project.md                      # Sync command
│   └── scripts/omnidas/codex/
│       └── codex-core-repo-discover.sh                     # Repository discovery
│
├── .omnidas/                                   # Shared Resources
│   └── [Content distributed to projects]
│
└── docs/                                       # Codex Documentation
    ├── guides/                                        # Operational guides
    └── architecture/                                  # Architecture docs
```

## Sync Workflows

### 1. Sync Pull Docs
**File**: `.github/workflows/omnidas-codex-sync-pull-docs.yml`
**Purpose**: Pulls documentation from all projects into the Codex
**Workflow Name**: `OmniDAS Codex - Sync Pull Docs`

### 2. Sync Push Docs
**File**: `.github/workflows/omnidas-codex-sync-push-docs.yml`
**Purpose**: Pushes documentation from Codex to all projects
**Workflow Name**: `OmniDAS Codex - Sync Push Docs`

### 3. Sync Push Claude
**File**: `.github/workflows/omnidas-codex-sync-push-claude.yml`
**Purpose**: Pushes Claude tools (agents, commands, hooks) to all projects
**Workflow Name**: `OmniDAS Codex - Sync Push Claude`

## Repository Discovery

Before triggering workflows, discover the Codex repository dynamically:

```bash
# Discover the Codex repository
CODEX_REPO=$(./.claude/scripts/omnidas/codex/codex-core-repo-discover.sh)
if [ $? -ne 0 ]; then
  echo "❌ Failed to discover Codex repository"
  exit 1
fi

echo "✓ Using Codex repository: $CODEX_REPO"
```

**How it works:**
1. Checks for `.env` file with `CODEX_GITHUB_ORG` and `CODEX_GITHUB_REPO`
2. Auto-discovers repos matching `codex.*` pattern in current org
3. Exits with error if neither method succeeds

**Script location:** `.claude/scripts/omnidas/codex/codex-core-repo-discover.sh`

## Workflow Execution Commands

### Documentation Sync Operations

```bash
# Pull from all projects
gh workflow run "OmniDAS Codex - Sync Pull Docs" --repo $CODEX_REPO

# Pull from specific project
gh workflow run "OmniDAS Codex - Sync Pull Docs" --repo $CODEX_REPO -f target_repository=<repo-name>

# Push docs to all projects
gh workflow run "OmniDAS Codex - Sync Push Docs" --repo $CODEX_REPO

# Push docs to specific project
gh workflow run "OmniDAS Codex - Sync Push Docs" --repo $CODEX_REPO -f target_repository=<repo-name>

# Push Claude tools to all projects
gh workflow run "OmniDAS Codex - Sync Push Claude" --repo $CODEX_REPO

# Push Claude tools to specific project
gh workflow run "OmniDAS Codex - Sync Push Claude" --repo $CODEX_REPO -f target_repository=<repo-name>
```

## Workflow Execution Order

**Documentation sync workflows (must run sequentially):**

1. `OmniDAS Codex - Sync Pull Docs` - Pull latest from projects
2. `OmniDAS Codex - Sync Push Docs` - Push docs to projects
3. `OmniDAS Codex - Sync Push Claude` - Push Claude tools to projects

**Important**: These three workflows must complete in order to maintain data consistency. Never run them in parallel.

## Monitoring Workflows

```bash
# List recent workflow runs
gh run list --repo $CODEX_REPO --limit 5

# Watch a specific workflow run
gh run watch [run-id] --repo $CODEX_REPO

# View workflow run details
gh run view [run-id] --repo $CODEX_REPO --log
```

## Claude Tools

### Codex Sync Manager Agent
**Location**: `.claude/agents/omnidas/codex/codex-sync-manager.md`
**Purpose**: Manages documentation sync operations
**Usage**: Activated via `@codex-sync-manager` mention in Claude Code

### Codex Sync Command
**Command**: `/omnidas:codex:codex-sync-project`
**Purpose**: Triggers pull and push workflows for current or specified project

### Repository Discovery Script
**Location**: `.claude/scripts/omnidas/codex/codex-core-repo-discover.sh`
**Purpose**: Dynamically discovers Codex repository location
**Usage**: Called by codex-sync-manager agent and commands

## Key Principles

1. **Sequential Execution**: Sync workflows must run in order (pull → push docs → push claude)
2. **Background Operation**: Run operations in background with monitoring
3. **Repository Discovery**: Always use discovery script, never hardcode paths
4. **Data Consistency**: Wait for each workflow to complete before starting the next

## Sync Scope Options

- **All Projects**: Sync with all repositories in the organization
- **Specific Project**: Sync with a single named repository
- **Current Project**: Default scope when no project specified

## Workflow Monitoring Implementation

### Wait for Workflow Completion

```bash
wait_for_workflow_completion() {
    local workflow_name="$1"
    local check_interval=30

    while true; do
        local status_info=$(gh run list \
            --workflow "$workflow_name" \
            --repo $CODEX_REPO \
            --limit 1 \
            --json status,conclusion \
            --jq '.[0] | {status, conclusion}')

        local status=$(echo "$status_info" | jq -r '.status')
        local conclusion=$(echo "$status_info" | jq -r '.conclusion')

        if [[ "$status" == "completed" ]]; then
            if [[ "$conclusion" == "success" ]]; then
                echo "✅ '$workflow_name' completed successfully"
                return 0
            else
                echo "❌ '$workflow_name' failed: $conclusion"
                return 1
            fi
        fi

        sleep $check_interval
    done
}
```

## Status Communication Templates

### Initial Response
```
✅ Sync workflows triggered in background. You can continue working.
```

### Progress Updates
```
📊 Step 1/3 completed: Documentation pulled from projects
📊 Step 2/3 completed: Documentation pushed to projects
📊 Step 3/3 in progress: Pushing Claude tools to projects
```

### Completion
```
✅ All sync workflows completed successfully
```

### Failure
```
❌ Sync workflow failed: [specific error]
View details: https://github.com/$CODEX_REPO/actions
```

## Error Handling

### Authentication Failures
```bash
if ! gh auth status &>/dev/null; then
    echo "❌ Not authenticated. Run: gh auth login"
    exit 1
fi
```

### Workflow Trigger Failures
```bash
if ! gh workflow run ... 2>&1; then
    echo "❌ Failed to trigger workflow. Check permissions."
    exit 1
fi
```

### Network Issues with Retry
```bash
retry_count=0
max_retries=3
while [ $retry_count -lt $max_retries ]; do
    if gh workflow run ...; then
        break
    fi
    retry_count=$((retry_count + 1))
    sleep $((2 ** retry_count))
done
```

## Background Execution

Always use `run_in_background: true` for all operations to allow the user to continue working.

## Validation Checklist

### Before Triggering Sync
- [ ] GitHub CLI authenticated: `gh auth status`
- [ ] Repository accessible: `gh repo view $CODEX_REPO`
- [ ] Workflows listable: `gh workflow list --repo $CODEX_REPO`

### During Execution
- [ ] Workflows triggered successfully
- [ ] Each workflow completes before starting next
- [ ] Status updates provided periodically
- [ ] User can continue working (non-blocking)

### After Completion
- [ ] Final status reported
- [ ] Any errors include actionable information
- [ ] Workflow links provided for failures

## Related Documentation

- [Codex Core Setup Guide](./codex-core-setup-guide.md) - Administrator setup and configuration
- [Codex Distro Agent Guide](./codex-distro-agent-guide.md) - Distribution publishing reference
- [Codex Core Architecture](/docs/architecture/codex-core-architecture.md) - Architectural overview and patterns