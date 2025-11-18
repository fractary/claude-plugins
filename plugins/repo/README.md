# Fractary Repo Plugin

**Version**: 2.2.0
**Universal source control operations across GitHub, GitLab, and Bitbucket**

## Overview

The `fractary-repo` plugin provides a unified, platform-agnostic interface for source control operations. It features a modular 3-layer architecture that separates user commands, decision logic, and platform-specific implementations for maximum flexibility and context efficiency.

### Key Features

- 🌍 **Multi-Platform Support**: GitHub (complete), GitLab (stub), Bitbucket (stub)
- 🎯 **Context Efficient**: 55-60% reduction in context usage through modular design
- 🔒 **Safety First**: Protected branch checks, force-with-lease, confirmation prompts
- ⚡ **Branch-Aware Permissions**: Fast workflow on feature branches, protection for production
- 📝 **Semantic Commits**: Conventional Commits + FABER metadata
- 🎨 **User-Friendly**: 7 slash commands for direct interaction
- 🔌 **FABER Integration**: Full workflow integration with traceability

## Architecture

The plugin uses a **3-layer architecture** with handler pattern:

```
┌─────────────────────────────────────────┐
│  Layer 1: Commands (User Interface)    │
│  /repo:branch, /repo:commit, etc.      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Layer 2: Agent (Routing)              │
│  repo-manager: validates & routes      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Layer 3: Skills (Workflows)           │
│  7 specialized skills + 3 handlers     │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Scripts (Deterministic Operations)    │
│  Platform-specific shell scripts       │
└─────────────────────────────────────────┘
```

## Installation

```bash
# Install plugin
claude plugin install fractary/repo
```

## Quick Start

### Option 1: Setup Wizard (Recommended) ⚡

The fastest way to get started:

```bash
/repo:init
```

The interactive wizard will:
- ✅ Auto-detect your platform (GitHub/GitLab/Bitbucket)
- ✅ Guide you through authentication setup (SSH or HTTPS+token)
- ✅ Validate your credentials
- ✅ Create the configuration file
- ✅ Test connectivity

**Time to setup**: ~2 minutes

See [`/repo:init` documentation](commands/init.md) for all options.

### Option 2: Manual Configuration

If you prefer manual setup:

1. **Set GitHub token** (required for API operations):

```bash
export GITHUB_TOKEN="your_github_token_here"
```

2. **Create configuration file**:

```bash
mkdir -p ~/.fractary/repo
cat > ~/.fractary/repo/config.json <<EOF
{
  "handlers": {
    "source_control": {
      "active": "github",
      "github": {
        "token": "$GITHUB_TOKEN"
      }
    }
  }
}
EOF
```

3. **Choose authentication method**:
   - **SSH** (recommended): Use SSH keys for git operations + token for API operations
   - **HTTPS + Token**: Use token for both git and API operations

   See [GitHub Setup Guide](docs/setup/github-setup.md) for detailed instructions.

### Configure Permissions (Highly Recommended) ⚡

**Run this immediately for the best experience**:

```bash
# Setup permissions once per project
/repo:init-permissions
```

This configures `.claude/settings.json` with a **branch-aware permission system**:

**Feature Branches (Fast Workflow)**:
```bash
# All execute immediately, no prompts!
git commit -m "Add feature"
git push origin feat/123
gh pr create
```

**Protected Branches (Requires Approval)**:
```bash
# Only these require approval
git push origin main
git push origin master
git push origin production
```

**Always Denied (Safety Net)**:
```bash
# Always blocked
git push --force origin main
rm -rf /
gh repo delete
```

**Benefits**:
- ⚡ **Fast workflow** - No prompts on feature branches
- 🛡️ **Protection** - Approval required for production branches only
- 🚫 **Safety** - Catastrophic operations always blocked
- 📋 **Customizable** - Add your own protected branches

See [Branch-Aware Permissions Guide](docs/branch-aware-permissions.md) for full details.

### Start Using Commands

```bash
# Create a feature branch
/repo:branch create 123 "add user export feature"

# Make commits
/repo:commit "Add CSV export functionality" --type feat --work-id 123

# Push changes
/repo:push --set-upstream

# Create pull request
/repo:pr create "feat: Add user export feature" --work-id 123
```

## User Commands

### /repo:init-permissions - Permission Management ⚡

Configure Claude Code permissions with **branch-aware intelligence**.

```bash
# Setup permissions (first time or update)
/repo:init-permissions

# Validate current permissions
/repo:init-permissions --mode validate

# Reset to defaults
/repo:init-permissions --mode reset
```

**What It Does:**

Creates a 3-tier permission system in `.claude/settings.json`:

1. **Auto-Allow** (55 commands): Fast workflow on feature branches
   - All git operations: `commit`, `push`, `merge`, `rebase`, `reset`
   - All GitHub CLI: `gh pr create`, `gh issue create`, etc.
   - Result: **Zero prompts** for normal development

2. **Require Approval** (9 commands - Protected branches only): Production safety
   - `git push origin main/master/production`
   - Result: **Approval required** only when it matters

3. **Always Deny** (39 commands): Catastrophic operations blocked
   - Force push to protected branches
   - System destruction: `rm -rf /`, `sudo`, `shutdown`
   - Result: **Always blocked**, no exceptions

**Workflow Comparison:**

Before:
```bash
git commit → prompt ⏱️
git push → prompt ⏱️
gh pr create → prompt ⏱️
= 3 prompts per workflow 🐢
```

After:
```bash
git commit → ✅ Done
git push origin feat/123 → ✅ Done
gh pr create → ✅ Done
git push origin main → ⚠️ Approve? (only this one)
= 0 prompts on features, 1 on production ⚡
```

**Documentation:**
- [Command Reference](commands/init-permissions.md)
- [Branch-Aware Guide](docs/branch-aware-permissions.md) - Comprehensive
- [Permission Behavior](docs/permissions-behavior.md) - Technical details
- [Original Guide](docs/permissions-guide.md) - Historical reference

### /repo:branch - Branch Management

Create, delete, and manage Git branches.

```bash
# Create feature branch
/repo:branch create 123 "add export feature"

# Delete old branch
/repo:branch delete feat/old-feature

# List stale branches
/repo:branch list --stale --merged
```

[Full documentation](commands/branch.md)

### /repo:commit - Semantic Commits

Create commits with conventional format and FABER metadata.

```bash
# Feature commit
/repo:commit "Add CSV export" --type feat --work-id 123

# Bug fix
/repo:commit "Fix auth timeout" --type fix --scope auth --work-id 456

# Breaking change
/repo:commit "Change API signature" --type feat --breaking --work-id 789
```

[Full documentation](commands/commit.md)

### /repo:push - Push Branches

Push branches to remote with safety checks.

```bash
# Push current branch
/repo:push

# Push with upstream tracking
/repo:push feat/123-export --set-upstream

# Safe force push
/repo:push feat/456-refactor --force
```

[Full documentation](commands/push.md)

### /repo:pr - Pull Request Management

Create, comment, review, and merge pull requests.

```bash
# Create PR
/repo:pr create "feat: Add user export" --work-id 123

# Add comment
/repo:pr comment 456 "LGTM! Tests passing."

# Approve PR
/repo:pr review 456 approve

# Merge PR
/repo:pr merge 456 --strategy no-ff --delete-branch
```

[Full documentation](commands/pr.md)

### /repo:tag - Version Tags

Create and push semantic version tags.

```bash
# Create release tag
/repo:tag create v1.2.3 --message "Release version 1.2.3"

# Create signed tag
/repo:tag create v2.0.0 --message "Major release" --sign

# Push tag
/repo:tag push v1.2.3
```

[Full documentation](commands/tag.md)

### /repo:cleanup - Branch Cleanup

Clean up stale and merged branches.

```bash
# Preview stale branches
/repo:cleanup --merged

# Delete merged branches
/repo:cleanup --delete --merged

# Delete old inactive branches
/repo:cleanup --delete --inactive --days 60
```

[Full documentation](commands/cleanup.md)

## Programmatic Usage

The plugin can be invoked programmatically by other plugins or FABER workflows:

```json
{
  "operation": "create-branch",
  "parameters": {
    "branch_name": "feat/123-add-export",
    "base_branch": "main"
  }
}
```

**Supported Operations** (14 total):
- `generate-branch-name` - Generate semantic branch name
- `create-branch` - Create new branch
- `delete-branch` - Delete branch locally/remotely
- `create-commit` - Create semantic commit
- `push-branch` - Push to remote
- `create-pr` - Create pull request
- `comment-pr` - Add PR comment
- `review-pr` - Submit PR review
- `merge-pr` - Merge pull request
- `create-tag` - Create version tag
- `push-tag` - Push tag to remote
- `list-stale-branches` - Find stale branches
- `configure-permissions` - Manage Claude Code permissions

## Components

### Agent

**repo-manager** - Universal routing agent
- Validates operation requests
- Routes to appropriate skills
- Returns structured responses
- Platform-agnostic (no platform-specific logic)

[Agent documentation](agents/repo-manager.md)

### Skills (8 Specialized)

1. **branch-namer** - Generate semantic branch names
2. **branch-manager** - Create and manage branches
3. **commit-creator** - Create semantic commits
4. **branch-pusher** - Push branches safely
5. **pr-manager** - Complete PR lifecycle
6. **tag-manager** - Version tag management
7. **cleanup-manager** - Branch cleanup operations
8. **permission-manager** - Claude Code permission configuration

[Skills documentation](skills/)

### Handlers (3 Platforms)

1. **handler-source-control-github** - GitHub operations (complete)
2. **handler-source-control-gitlab** - GitLab operations (stub)
3. **handler-source-control-bitbucket** - Bitbucket operations (stub)

[Handler documentation](skills/handler-source-control-github/SKILL.md)

#### Handler Invocation Pattern

**CRITICAL**: When skills invoke handlers, they must use **explicit, fully-qualified skill names** with the correct namespace prefix to prevent cross-plugin confusion.

**Correct Pattern**:
```
fractary-repo:handler-source-control-<platform>
```

**Example**:
```
Use the Skill tool with:
- command: `fractary-repo:handler-source-control-github`
- parameters: {operation-specific params}
```

**Why this matters**:
- Prevents namespace collisions with other plugins (e.g., `fractary-codex:handler-sync-github`)
- Makes the skill invocation unambiguous for Claude
- Ensures correct handler is selected even with multiple plugins loaded
- Avoids fallback to direct bash command execution

**Implementation**:
All repo skills (branch-pusher, commit-creator, pr-manager, etc.) use this pattern. Each skill:
1. Reads `config.handlers.source_control.active` to get platform (e.g., "github")
2. Constructs full skill name: `fractary-repo:handler-source-control-<platform>`
3. Invokes via Skill tool with constructed name

See individual skill documentation for specific handler invocation examples.

### Utilities

**repo-common** - Shared utilities for all skills
- Configuration loading
- Branch validation
- Commit formatting
- Metadata extraction

[Common utilities documentation](skills/repo-common/SKILL.md)

## Platform Support

| Platform | Status | Operations | CLI Tool | Authentication |
|----------|--------|------------|----------|----------------|
| GitHub | ✅ Complete | 13/13 | `gh`, `git` | `GITHUB_TOKEN` |
| GitLab | 🚧 Stub | 0/13 | `glab`, `git` | `GITLAB_TOKEN` |
| Bitbucket | 🚧 Stub | 0/13 | `curl`, `git` | `BITBUCKET_TOKEN` |

### GitHub Setup

See [GitHub Setup Guide](docs/setup/github-setup.md) (coming soon)

### GitLab Setup

See [GitLab Setup Guide](docs/setup/gitlab-setup.md) (coming soon)

### Bitbucket Setup

See [Bitbucket Setup Guide](docs/setup/bitbucket-setup.md) (coming soon)

## Configuration

Configuration is loaded from:
1. `.fractary/plugins/repo/config.json` (project-specific)
2. `~/.fractary/repo/config.json` (user-global)
3. Built-in defaults

### Example Configuration

```json
{
  "handlers": {
    "source_control": {
      "active": "github",
      "github": {
        "token": "$GITHUB_TOKEN",
        "api_url": "https://api.github.com"
      }
    }
  },
  "defaults": {
    "default_branch": "main",
    "protected_branches": ["main", "master", "production"],
    "branch_naming": {
      "pattern": "{prefix}/{issue_id}-{slug}",
      "allowed_prefixes": ["feat", "fix", "chore", "docs", "test", "refactor"]
    },
    "commit_format": "faber",
    "merge_strategy": "no-ff"
  }
}
```

[Full configuration schema](config/repo.example.json)

## Permission Management

The repo plugin includes a sophisticated **branch-aware permission management system** that optimizes for developer velocity while maintaining security.

### Overview

Traditional permission systems require approval for every operation, creating friction and slowing down development. The repo plugin's branch-aware system recognizes that:
- Most work happens on feature branches (should be fast)
- Production branches need protection (should require approval)
- Catastrophic operations should never execute (should be denied)

### Three-Tier System

#### 1. Auto-Allow (55 commands)

Commands execute **immediately without prompts** on feature branches:

**Git Operations:**
- Read: `status`, `log`, `diff`, `show`, `branch`
- Write: `commit`, `push`, `merge`, `rebase`, `reset`, `add`, `tag`
- Navigation: `checkout`, `switch`, `fetch`, `pull`, `stash`

**GitHub CLI:**
- PR: `gh pr create`, `gh pr comment`, `gh pr review`, `gh pr close`
- Issues: `gh issue create`, `gh issue comment`, `gh issue close`
- Repository: `gh repo view`, `gh repo clone`, `gh auth status`

**Safe Utilities:**
- `cat`, `head`, `tail`, `grep`, `find`, `ls`, `pwd`, `jq`, `sed`, `awk`

#### 2. Require Approval (9 commands - Protected Branches Only)

Commands prompt for approval **ONLY when targeting protected branches**:

**Protected Branch Patterns:**
- `git push origin main`
- `git push origin master`
- `git push origin production`
- `git push -u origin main/master/production`
- `gh pr merge` (when targeting protected branch)

**Feature Branch Behavior:**
```bash
git push origin feat/123     # ✅ Auto-allowed
git push origin main         # ⚠️ Requires approval
```

#### 3. Always Deny (39 commands)

Commands are **always blocked**, regardless of branch:

**Destructive File Operations:**
- `rm -rf /`, `rm -rf *`, `rm -rf .`, `rm -rf ~`
- `dd if=`, `mkfs`, `format`, `> /dev/sd`

**Dangerous Git Operations:**
- `git push --force origin main/master/production`
- `git reset --hard origin/main/master/production`
- `git clean -fdx`, `git filter-branch`

**Dangerous GitHub Operations:**
- `gh repo delete`, `gh repo archive`, `gh secret delete`

**System Operations:**
- `sudo`, `su`, `chmod 777`, `shutdown`, `reboot`, `systemctl`

**Remote Code Execution:**
- `curl | sh`, `wget | bash`

### Customization

Add your own protected branches by editing `.claude/settings.json`:

```json
{
  "permissions": {
    "bash": {
      "requireApproval": [
        "git push origin staging",
        "git push origin release",
        "git push -u origin staging",
        "git push -u origin release"
      ]
    }
  }
}
```

### Skip Mode Warning

**⚠️ CRITICAL: `--dangerously-skip-permissions` Bypasses Everything**

When running Claude Code with the `--dangerously-skip-permissions` flag:

- ❌ **Allow list** - Not checked
- ❌ **RequireApproval list** - NOT PROMPTED (executes immediately)
- ❌ **Deny list** - NOT ENFORCED (executes anyway)

This means even `rm -rf /` will execute without protection.

**Only use skip mode**:
- ✅ In isolated Docker containers
- ✅ In sandboxed VMs
- ✅ In CI/CD with full code review
- ✅ When you trust 100% of the code

**Never use skip mode**:
- ❌ On production systems
- ❌ On your development machine
- ❌ When running untrusted code
- ❌ If unsure what commands will execute

### Setup

```bash
# Run once per project
cd your-project
/repo:init-permissions

# Output shows:
# - ~50 auto-allowed commands
# - Protected branch patterns
# - ~25 denied commands
```

### Documentation

- **[Branch-Aware Permissions Guide](docs/branch-aware-permissions.md)** - Comprehensive guide with examples
- **[Permission Behavior](docs/permissions-behavior.md)** - Technical details and edge cases
- **[Permission Guide](docs/permissions-guide.md)** - Original permission system documentation
- **[Command Reference](commands/init-permissions.md)** - `/repo:init-permissions` command details

### Benefits

| Metric | Before Permissions | After Permissions |
|--------|-------------------|-------------------|
| **Feature branch workflow** | 3 prompts per cycle | 0 prompts |
| **Production push** | Inconsistent | Always prompted |
| **Catastrophic commands** | Sometimes prompted | Always blocked |
| **Developer velocity** | Slow 🐢 | Fast ⚡ |

## FABER Integration

The plugin is fully integrated with FABER workflows:

- **Frame Phase**: Automatic branch creation
- **Architect/Build Phases**: Semantic commits with author context (no prompts!)
- **Evaluate Phase**: Test commits and fixes (no prompts!)
- **Release Phase**: PR creation and merging (prompted only for protected branches)

All operations include FABER metadata for full traceability.

**With Permissions Configured**: FABER workflows run dramatically faster with zero unnecessary interruptions.

## Git Status Cache

The plugin maintains a unified git status cache to eliminate hook conflicts and improve performance.

### Overview

The status cache provides:
- **Single source of truth** - No concurrent git operations
- **Fast reads** - Cache queries are instant (~5ms vs 50-200ms for git commands)
- **Auto-refresh** - Updates on command submission and session end
- **Rich data** - 10 fields: branch, uncommitted changes, ahead/behind, stash, conflicts, etc.

### Cache Location

`~/.fractary/repo/status.cache` (JSON format)

### Automatic Updates

The cache is updated automatically via hooks:
- **UserPromptSubmit** - Updates cache when you submit commands (keeps it fresh)
- **Stop** - Updates cache when auto-commit runs (after commits)

### Status Line Integration

Use the cache in your Claude Code status line (`.claude/statusline.json`):

```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh uncommitted ahead",
      "format": "Git: %s↑%s",
      "color": "yellow"
    }
  ]
}
```

**Output**: `Git: 3↑5` (3 uncommitted changes, 5 commits ahead)

### Available Fields

- `branch` - Current branch name
- `uncommitted_changes` (alias: `uncommitted`, `changes`) - Count of staged + unstaged changes
- `untracked_files` (alias: `untracked`) - Count of untracked files
- `commits_ahead` (alias: `ahead`) - Commits ahead of remote
- `commits_behind` (alias: `behind`) - Commits behind remote
- `has_conflicts` (alias: `conflicts`) - Merge conflicts present (true/false)
- `stash_count` (alias: `stash`) - Number of stashes
- `clean` - Working tree is clean (true/false)
- `timestamp` - Last cache update (ISO 8601)
- `repo_path` - Repository root path

### Manual Operations

```bash
# Update cache manually
~/.fractary/repo/scripts/update-status-cache.sh

# Read specific fields
~/.fractary/repo/scripts/read-status-cache.sh uncommitted ahead behind

# Read entire cache
~/.fractary/repo/scripts/read-status-cache.sh
```

### Documentation

- [Status Line Examples](docs/status-cache-statusline-examples.md) - Comprehensive status line configurations
- [Migration Guide](docs/status-cache-migration-guide.md) - Migrate from custom status hooks

### Benefits

✅ **Eliminates hook conflicts** - No more concurrent git operations fighting for lock
✅ **Faster status display** - Instant cache reads vs slow git queries
✅ **Consistent data** - All consumers see same snapshot
✅ **Auto-maintained** - Updates handled by plugin hooks
✅ **Rich information** - 10 fields available for display

## Directory Structure

```
repo/
├── .claude-plugin/
│   └── plugin.json                 # Plugin manifest
├── README.md                        # This file
├── config/
│   └── repo.example.json            # Configuration template
├── docs/
│   ├── spec/
│   │   └── repo-plugin-refactoring-spec.md
│   ├── setup/                       # Setup guides
│   │   ├── github-setup.md
│   │   ├── gitlab-setup.md
│   │   └── bitbucket-setup.md
│   ├── branch-aware-permissions.md  # Branch-aware permission system (comprehensive)
│   ├── permissions-behavior.md      # Permission behavior and technical details
│   ├── permissions-guide.md         # Original permission guide
│   ├── status-cache-statusline-examples.md  # Status line integration
│   └── status-cache-migration-guide.md      # Migration from custom hooks
├── commands/                        # User commands (Layer 1)
│   ├── init-permissions.md          # Permission management command
│   ├── branch.md
│   ├── commit.md
│   ├── push.md
│   ├── pr.md
│   ├── tag.md
│   └── cleanup.md
├── agents/                          # Routing agent (Layer 2)
│   └── repo-manager.md
├── scripts/                         # Utility scripts
│   ├── auto-commit-on-stop.sh       # Auto-commit hook
│   ├── update-status-cache.sh       # Update git status cache
│   └── read-status-cache.sh         # Read git status cache
├── hooks/
│   └── hooks.json                   # Plugin hook configuration
└── skills/                          # Workflows & handlers (Layer 3)
    ├── permission-manager/          # Permission configuration
    ├── branch-namer/
    ├── branch-manager/
    ├── commit-creator/
    ├── branch-pusher/
    ├── pr-manager/
    ├── tag-manager/
    ├── cleanup-manager/
    ├── repo-common/
    ├── handler-source-control-github/
    ├── handler-source-control-gitlab/
    └── handler-source-control-bitbucket/
```

## Safety Features

- **Protected Branches**: Automatic blocking of dangerous operations on main/master/production
- **Force Push Safety**: Uses `--force-with-lease` instead of bare `--force`
- **Confirmation Prompts**: For destructive operations (configurable)
- **Merge Conflict Detection**: Prevents merging with conflicts
- **CI Status Check**: Ensures tests pass before merge
- **Review Requirements**: Enforces approval requirements

## Best Practices

### Branch Naming

Use semantic prefixes:
- `feat/` - New features
- `fix/` - Bug fixes
- `chore/` - Maintenance tasks
- `docs/` - Documentation
- `test/` - Test additions
- `refactor/` - Code refactoring
- `style/` - Style changes
- `perf/` - Performance improvements

### Commit Messages

Follow Conventional Commits:
```
<type>[optional scope]: <description>

[optional body]

Work-Item: #<id>
```

### Merge Strategies

- **no-ff**: Feature branches (preserves history)
- **squash**: Bug fixes (clean history)
- **ff-only**: Simple updates (linear history)

## Contributing

### Adding a New Platform

To add support for a new platform (e.g., GitLab):

1. **Implement handler skill** (`skills/handler-source-control-gitlab/SKILL.md`)
2. **Create platform scripts** in handler's `scripts/` directory
3. **Follow operation interface** (13 standard operations)
4. **Add setup documentation** (`docs/setup/gitlab-setup.md`)
5. **Update configuration** to include platform settings

See [Contributing Guide](../../CONTRIBUTING.md) (if exists)

## Troubleshooting

### Authentication Errors

```bash
# Check token is set
echo $GITHUB_TOKEN

# Test authentication
gh auth status

# Regenerate token at:
# https://github.com/settings/tokens
```

### Protected Branch Errors

```bash
# Check protected branches in config
cat ~/.fractary/repo/config.json

# Protected branches cannot be:
# - Force pushed
# - Deleted
# - Directly committed to
```

### Network Errors

```bash
# Check remote connectivity
git remote -v
git fetch --dry-run

# Check firewall/proxy settings
```

## Migration from v1.x

If you're upgrading from the monolithic v1.x architecture:

1. **No breaking changes** - The agent interface remains compatible
2. **Configuration update** - Copy new config format from `config/repo.example.json`
3. **Commands available** - New slash commands are additions, not replacements
4. **Handler selection** - Explicitly set active platform in config

[Migration guide](docs/migration.md) (coming soon)

## Version History

- **v2.2.0** (Current) - Branch-aware permission system
  - Branch-aware permissions (fast on features, protected on production)
  - Auto-allow ~50 commands for feature branches
  - Require approval only for protected branch operations
  - Always deny ~25 catastrophic operations
  - Comprehensive permission documentation
  - Dramatic workflow velocity improvement

- **v2.1.0** - Permission management
  - Initial 3-tier permission system (allow/requireApproval/deny)
  - Permission configuration command
  - Smart conflict resolution
  - Custom permission preservation

- **v2.0.0** (2025-10-29) - Modular architecture refactoring
  - 8 specialized skills (added permission-manager)
  - 7 user commands (added init-permissions)
  - Handler pattern implementation
  - 55-60% context reduction

- **v1.0.0** - Initial monolithic implementation
  - Single agent + single skill
  - GitHub support only
  - FABER integration

## Context Efficiency

**v1.x (Monolithic)**:
- Agent: 370 lines
- Skill: 320 lines
- Total per invocation: ~690 lines

**v2.0 (Modular)**:
- Agent: 200 lines (routing only)
- 1 Skill: 200-400 lines
- 1 Handler: 150 lines
- Total per invocation: ~350-750 lines

**Savings: 40-50% average reduction** 🎯

## License

Part of the Fractary plugin ecosystem.

## Support

- **Issues**: [GitHub Issues](https://github.com/fractary/claude-plugins/issues)
- **Documentation**: [docs/](docs/)
- **Specification**: [docs/spec/repo-plugin-refactoring-spec.md](docs/spec/repo-plugin-refactoring-spec.md)
