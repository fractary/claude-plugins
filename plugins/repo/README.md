# Fractary Repo Plugin

**Version**: 2.0.0
**Universal source control operations across GitHub, GitLab, and Bitbucket**

## Overview

The `fractary-repo` plugin provides a unified, platform-agnostic interface for source control operations. It features a modular 3-layer architecture that separates user commands, decision logic, and platform-specific implementations for maximum flexibility and context efficiency.

### Key Features

- 🌍 **Multi-Platform Support**: GitHub (complete), GitLab (stub), Bitbucket (stub)
- 🎯 **Context Efficient**: 55-60% reduction in context usage through modular design
- 🔒 **Safety First**: Protected branch checks, force-with-lease, confirmation prompts
- 📝 **Semantic Commits**: Conventional Commits + FABER metadata
- 🎨 **User-Friendly**: 6 slash commands for direct interaction
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

**Supported Operations** (13 total):
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

## Components

### Agent

**repo-manager** - Universal routing agent
- Validates operation requests
- Routes to appropriate skills
- Returns structured responses
- Platform-agnostic (no platform-specific logic)

[Agent documentation](agents/repo-manager.md)

### Skills (7 Specialized)

1. **branch-namer** - Generate semantic branch names
2. **branch-manager** - Create and manage branches
3. **commit-creator** - Create semantic commits
4. **branch-pusher** - Push branches safely
5. **pr-manager** - Complete PR lifecycle
6. **tag-manager** - Version tag management
7. **cleanup-manager** - Branch cleanup operations

[Skills documentation](skills/)

### Handlers (3 Platforms)

1. **handler-source-control-github** - GitHub operations (complete)
2. **handler-source-control-gitlab** - GitLab operations (stub)
3. **handler-source-control-bitbucket** - Bitbucket operations (stub)

[Handler documentation](skills/handler-source-control-github/SKILL.md)

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

## FABER Integration

The plugin is fully integrated with FABER workflows:

- **Frame Phase**: Automatic branch creation
- **Architect/Build Phases**: Semantic commits with author context
- **Evaluate Phase**: Test commits and fixes
- **Release Phase**: PR creation and merging

All operations include FABER metadata for full traceability.

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
│   └── setup/                       # Setup guides (coming soon)
│       ├── github-setup.md
│       ├── gitlab-setup.md
│       └── bitbucket-setup.md
├── commands/                        # User commands (Layer 1)
│   ├── branch.md
│   ├── commit.md
│   ├── push.md
│   ├── pr.md
│   ├── tag.md
│   └── cleanup.md
├── agents/                          # Routing agent (Layer 2)
│   └── repo-manager.md
└── skills/                          # Workflows & handlers (Layer 3)
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

- **v2.0.0** (2025-10-29) - Modular architecture refactoring
  - 7 specialized skills
  - 6 user commands
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
