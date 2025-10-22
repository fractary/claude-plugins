# Codex Sync Manager Agent

## Overview

The Codex Sync Manager is a specialized Claude Code agent that handles documentation synchronization between individual projects and the central Codex repository. It orchestrates bidirectional syncing operations, running workflows in the background while you continue working.

## What It Does

The Codex Sync Manager agent:

- **Triggers sync workflows** in the correct sequence (pull → push docs → push Claude)
- **Runs operations in the background** allowing you to continue working
- **Monitors workflow progress** and provides status updates
- **Handles multiple sync scopes**: current project, specific project, or all projects
- **Recognizes natural language commands** including common misspellings

## Available Commands

### `/codex-sync-project`

Synchronizes projects with the Codex repository bidirectionally.

**What happens:**
1. **Pull Phase**: Pulls documentation from project(s) into Codex
2. **Push Docs Phase**: Pushes shared documentation from Codex back to project(s)
3. **Push Claude Phase**: Updates Claude tools (agents, commands, hooks) in project(s)

**Usage:**
```bash
# Sync current project (when in a project directory)
/codex-sync-project

# Sync specific project by name
/codex-sync-project my-project-name

# Sync ALL projects in the organization
/codex-sync-project *
```

⚠️ **Warning:** Using `*` affects all repositories in your organization. Use with appropriate caution.

## Natural Language Support

The agent automatically activates for various natural language requests:

- "sync codex" or "codex sync"
- "sync all documents" or "sync all docs"
- "synchronize documentation"
- "sync all codex documents"
- "codex sync project"

It even handles common misspellings:
- "codec sync" (codec instead of codex)
- "sink codex" (sink instead of sync)
- "codex synch" (synch instead of sync)

## How It Works

1. **Detection**: Agent recognizes sync commands or natural language requests
2. **Scope Determination**: Identifies whether to sync current project, specific project, or all projects
3. **Repository Discovery**: Uses `codex-core-repo-discover.sh` to find the Codex repository
4. **Workflow Triggering**: Executes three GitHub workflows **sequentially**
5. **Background Execution**: Runs non-blocking, allowing continued work
6. **Progress Monitoring**: Provides periodic status updates
7. **Completion Reporting**: Notifies when sync is complete or if errors occur

### Workflow Sequence

The agent triggers three workflows **sequentially** (never in parallel):

1. **Sync Pull Docs**: `omnidas-codex-sync-pull-docs.yml`
   - Pulls documentation from project(s) into Codex

2. **Sync Push Docs**: `omnidas-codex-sync-push-docs.yml`
   - Pushes shared documentation from Codex to project(s)

3. **Sync Push Claude**: `omnidas-codex-sync-push-claude.yml`
   - Pushes Claude agents, commands, and hooks to project(s)

**Why sequential?** These workflows must run in order to maintain data consistency and avoid conflicts.

## Setup Instructions

### Prerequisites

1. **GitHub CLI installed**: Download from [cli.github.com](https://cli.github.com)
2. **Access to organization's Codex repository**
3. **Authentication configured** (see below)

### Repository Configuration

The agent automatically discovers your Codex repository using `codex-core-repo-discover.sh`:

**Auto-discovery** (default):
- Finds repositories matching `codex.*` pattern in your organization
- No configuration needed

**Manual configuration** (optional):
Create a `.env` file in your project root:
```bash
CODEX_GITHUB_ORG=myorg
CODEX_GITHUB_REPO=codex.myorg.com
```

This is useful for:
- Non-standard repository naming
- Testing with specific Codex instances
- Explicitly controlling which Codex repo to use

### Authentication Setup

#### Recommended: Personal Access Token (PAT)

The PAT method is preferred because it aligns with the core bundle requirements and provides consistent access.

**If you've already set up the core bundle:**

Use the same `CODEX_SYNC_PAT`:
```bash
# Use your existing CODEX_SYNC_PAT
echo "ghp_xxxxxxxxxxxxxxxxxxxx" > token.txt
gh auth login --with-token < token.txt
rm token.txt
```

**Creating a new PAT:**

1. Go to GitHub → Settings → Developer settings → [Personal access tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Name it "Codex Sync PAT"
4. Select scopes:
   - `repo` (Full control of private repositories)
   - `workflow` (Update GitHub Action workflows)
5. Set expiration (90 days recommended)
6. Generate and copy the token immediately

```bash
# Configure GitHub CLI with your PAT
echo "ghp_xxxxxxxxxxxxxxxxxxxx" > token.txt
gh auth login --with-token < token.txt
rm token.txt
```

**Note:** This same PAT will be used as `CODEX_SYNC_PAT` in the core bundle setup.

#### Alternative: Browser Authentication

For organization members who prefer browser-based login:

```bash
gh auth login
# Select: GitHub.com → HTTPS → Login with a web browser
```

### Verify Setup

Test your access:
```bash
# Check authentication
gh auth status

# Verify Codex repository discovery
./.claude/scripts/omnidas/codex/codex-core-repo-discover.sh

# List workflows in discovered repo
CODEX_REPO=$(./.claude/scripts/omnidas/codex/codex-core-repo-discover.sh)
gh workflow list --repo $CODEX_REPO
```

### First Use

1. Navigate to your project:
   ```bash
   cd /path/to/your/project
   ```

2. Run a sync:
   ```
   /codex-sync-project
   ```

3. Monitor the output and verify new files:
   ```bash
   ls -la .omnidas/
   ls -la .claude/
   ```

## Status Messages

The agent provides concise status updates:

- **Initial**: "🔄 Sync workflows triggered in background. You can continue working."
- **Progress**: "✓ Step 1/3 completed: Documentation pulled from projects"
- **Success**: "✅ All sync workflows completed successfully"
- **Failure**: "❌ Sync workflow failed: [error]. View details: [link]"

## Troubleshooting

### Common Issues

**"Resource not accessible by integration"**
- Ensure PAT has `repo` and `workflow` scopes
- Run `gh auth status` to verify authentication

**"Must have admin rights"**
- Contact organization admin to adjust workflow permissions
- Check repository Settings → Actions → General

**"Repository not found"** or **"Could not determine Codex repository"**
- Ensure your Codex repository follows the `codex.*` naming pattern
- Or create a `.env` file with explicit CODEX_GITHUB_ORG and CODEX_GITHUB_REPO values
- Check for pending invitations to the Codex repository
- Confirm access with an admin

**Workflow failures**
- Check GitHub Actions tab in Codex repository
- Review workflow logs for specific errors
- Verify PAT hasn't expired

### Manual Workflow Checks

```bash
# Discover your Codex repo
CODEX_REPO=$(./.claude/scripts/omnidas/codex/codex-core-repo-discover.sh)

# List recent runs
gh run list --repo $CODEX_REPO --limit 5

# View specific run
gh run view [run-id] --repo $CODEX_REPO
```

## Performance

- **Single project sync**: 2-5 minutes typical
- **All projects sync**: 10-20 minutes depending on organization size
- **Background execution**: No blocking of your work
- **Sequential workflows**: Ensures data consistency

## Related Documentation

### Agent Documentation
- [Codex Distro Manager Agent](/docs/agents/codex/codex-distro-manager.md) - Distribution publishing agent

### Guides
- [Codex Sync Agent Guide](/docs/guides/codex-sync-agent-guide.md) - Complete operational reference for sync operations
- [Codex Distro Agent Guide](/docs/guides/codex-distro-agent-guide.md) - Distribution publishing operational reference
- [Codex Core Setup Guide](/docs/guides/codex-core-setup-guide.md) - Initial setup and configuration

### Architecture & Specs
- [Codex Core Architecture](/docs/architecture/codex-core-architecture.md) - System architecture overview
- [Codex Distribution System Spec](/docs/specs/codex-distribution-system.md) - Distribution system technical specification
- [Documentation Standards](/docs/standards/documentation-standards.md) - Codex documentation guidelines

### External Resources
- [GitHub CLI Documentation](https://cli.github.com/manual/) - GitHub CLI reference

## Support

For issues or questions:
1. Check your organization's documentation
2. Review the [Codex Sync Agent Guide](/docs/guides/codex-sync-agent-guide.md)
3. Contact GitHub organization administrators
4. Open an issue in the Codex repository