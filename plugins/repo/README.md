# Fractary Repo Manager Plugin

Source control operations across multiple platforms.

## Overview

The `fractary-repo` plugin provides a unified interface for source control operations across different Git-based platforms. It handles branching, committing, pushing, pull requests, and merging while abstracting platform-specific differences.

## Platforms Supported

- ✅ **GitHub** (complete) - Full implementation with branch management, commits, PRs, merging
- 🚧 **GitLab** (structure ready) - Framework in place, scripts need implementation
- 🚧 **Bitbucket** (future) - Planned support

## Installation

```bash
claude plugin install fractary/repo
```

## Components

### Agent

**`repo-manager`** - Orchestrates source control operations
- Creates and manages branches
- Creates semantic commits
- Pushes to remote repositories
- Creates and merges pull/merge requests
- Generates branch names following conventions

### Skill

**`repo-manager`** - Platform adapter selection
- Reads configuration to determine active platform (GitHub/GitLab/Bitbucket)
- Invokes appropriate platform-specific scripts
- Handles platform-specific Git workflows

## Configuration

When used with `fractary-faber`, configure in `faber.yaml`:

```yaml
handlers:
  repository:
    active: "github"
    github:
      owner: "myorg"
      repo: "my-project"
      main_branch: "main"
```

## Usage

This plugin is primarily used by other Fractary plugins (especially `fractary-faber`) and typically not invoked directly by users.

**Agent invocation example:**
```bash
claude --agent fractary-repo/repo-manager "create-branch feature/new-feature"
```

## Directory Structure

```
repo/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── agents/
│   └── repo-manager.md      # Repo manager agent
├── skills/
│   └── repo-manager/
│       ├── SKILL.md         # Skill definition
│       ├── scripts/
│       │   ├── github/      # GitHub adapter
│       │   └── gitlab/      # GitLab adapter (future)
│       └── docs/
│           ├── github-git.md
│           └── gitlab-git.md
└── README.md                # This file
```

## Operations Supported

All platform adapters implement these operations:

- **generate-branch-name.sh** - Create semantic branch names
- **create-branch.sh** - Create new Git branches
- **create-commit.sh** - Create commits with semantic messages
- **push-branch.sh** - Push branches to remote
- **create-pr.sh** - Create pull/merge requests
- **merge-pr.sh** - Merge pull/merge requests

## Adding New Platforms

To add support for a new platform:

1. Create scripts directory: `skills/repo-manager/scripts/{platform}/`
2. Implement required scripts (see operations list above)
3. Add API documentation: `skills/repo-manager/docs/{platform}-git.md`
4. Update handler configuration in your project's `faber.yaml`

## License

Part of the Fractary plugin ecosystem.
