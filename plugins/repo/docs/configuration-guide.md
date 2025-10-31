# Configuration Guide

Complete reference for configuring the Fractary Repo Plugin.

## Table of Contents

- [Configuration File Locations](#configuration-file-locations)
- [Configuration Structure](#configuration-structure)
- [Handler Configuration](#handler-configuration)
- [Defaults Configuration](#defaults-configuration)
- [FABER Integration](#faber-integration)
- [Platform-Specific Options](#platform-specific-options)
- [Configuration Precedence](#configuration-precedence)
- [Common Scenarios](#common-scenarios)
- [Environment Variables](#environment-variables)
- [Troubleshooting](#troubleshooting)

## Configuration File Locations

The plugin loads configuration from multiple locations in order of precedence:

### 1. Project-Specific Configuration (Highest Priority)
```
.fractary/plugins/repo/config.json
```

**Use when**:
- Settings are specific to this project
- Different repos need different configurations
- Want to commit config to version control (optional)

**Example**:
```bash
# Create project config
mkdir -p .fractary/plugins/repo
cp plugins/repo/config/repo.example.json .fractary/plugins/repo/config.json
```

### 2. User-Global Configuration (Fallback)
```
~/.fractary/repo/config.json
```

**Use when**:
- Settings apply to all your repositories
- Personal development preferences
- Don't want config in version control

**Example**:
```bash
# Create global config
mkdir -p ~/.fractary/repo
cp plugins/repo/config/repo.example.json ~/.fractary/repo/config.json
```

### 3. Built-in Defaults (Lowest Priority)
Hard-coded defaults used if no configuration file exists.

**Quick Setup**: Use `/repo:init` to create configuration interactively.

## Configuration Structure

The configuration file uses JSON format:

```json
{
  "handlers": { ... },
  "defaults": { ... },
  "faber_integration": { ... },
  "platform_specific": { ... }
}
```

## Handler Configuration

Handlers determine which source control platform to use.

### Structure

```json
{
  "handlers": {
    "source_control": {
      "active": "github",    // Which platform: github|gitlab|bitbucket
      "github": { ... },      // GitHub-specific settings
      "gitlab": { ... },      // GitLab-specific settings
      "bitbucket": { ... }    // Bitbucket-specific settings
    }
  }
}
```

### GitHub Handler

```json
{
  "github": {
    "token": "$GITHUB_TOKEN",                  // Personal Access Token (PAT)
    "api_url": "https://api.github.com"        // Override for GitHub Enterprise
  }
}
```

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `token` | string | Yes* | GitHub Personal Access Token. Use `$VAR_NAME` for env vars. |
| `api_url` | string | No | API endpoint. Default: `https://api.github.com`. Override for GitHub Enterprise. |

\* Not required if using SSH for all git operations and not using API features

**GitHub Enterprise Example**:
```json
{
  "github": {
    "token": "$GITHUB_TOKEN",
    "api_url": "https://github.company.com/api/v3"
  }
}
```

**Authentication Methods**:

**Option A: SSH + Token (Recommended)**
- Git operations (push, pull, clone): Use SSH keys from `~/.ssh/`
- API operations (PRs, issues): Use token
- Configure: `git remote set-url origin git@github.com:owner/repo.git`

**Option B: HTTPS + Token**
- Both git and API operations use token
- Configure: `git remote set-url origin https://github.com/owner/repo.git`

### GitLab Handler

```json
{
  "gitlab": {
    "token": "$GITLAB_TOKEN",                  // Personal Access Token
    "api_url": "https://gitlab.com/api/v4"     // Override for self-hosted
  }
}
```

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `token` | string | Yes | GitLab Personal Access Token |
| `api_url` | string | No | API endpoint. Default: `https://gitlab.com/api/v4` |

**Self-Hosted GitLab Example**:
```json
{
  "gitlab": {
    "token": "$GITLAB_TOKEN",
    "api_url": "https://gitlab.company.com/api/v4"
  }
}
```

### Bitbucket Handler

```json
{
  "bitbucket": {
    "username": "$BITBUCKET_USERNAME",         // Bitbucket username
    "token": "$BITBUCKET_TOKEN",               // App password
    "workspace": "your-workspace-slug",        // Workspace identifier
    "api_url": "https://api.bitbucket.org/2.0" // Override for Server
  }
}
```

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `username` | string | Yes | Bitbucket account username |
| `token` | string | Yes | Bitbucket app password |
| `workspace` | string | Yes | Workspace slug (find in workspace settings) |
| `api_url` | string | No | API endpoint. Default: `https://api.bitbucket.org/2.0` |

**Bitbucket Server Example**:
```json
{
  "bitbucket": {
    "username": "$BITBUCKET_USERNAME",
    "token": "$BITBUCKET_TOKEN",
    "api_url": "https://bitbucket.company.com/rest/api/1.0"
  }
}
```

## Defaults Configuration

General settings that apply to all platforms.

### Complete Reference

```json
{
  "defaults": {
    "default_branch": "main",
    "protected_branches": ["main", "master", "production"],
    "branch_naming": {
      "pattern": "{prefix}/{issue_id}-{slug}",
      "allowed_prefixes": ["feat", "fix", "chore"]
    },
    "commit_format": "faber",
    "require_signed_commits": false,
    "merge_strategy": "no-ff",
    "auto_delete_merged_branches": false,
    "remote": {
      "name": "origin",
      "auto_set_upstream": true
    },
    "pr": {
      "template": "standard",
      "require_work_id": true,
      "auto_link_issues": true
    },
    "cleanup": {
      "inactive_threshold_days": 30,
      "auto_cleanup_merged": false,
      "exclude_patterns": ["release/*", "hotfix/*"]
    },
    "tags": {
      "require_signed_tags": false,
      "auto_push_tags": false
    }
  }
}
```

### Field Descriptions

#### `default_branch`
- **Type**: string
- **Default**: `"main"`
- **Description**: Default base branch for new feature branches

**Example**:
```json
"default_branch": "develop"  // Use develop as base
```

#### `protected_branches`
- **Type**: array of strings
- **Default**: `["main", "master", "production"]`
- **Description**: Branches with extra protection (no force push, merge warnings)

**Example**:
```json
"protected_branches": ["main", "master", "production", "staging", "qa"]
```

#### `branch_naming`

Controls how branch names are generated.

```json
{
  "pattern": "{prefix}/{issue_id}-{slug}",
  "allowed_prefixes": ["feat", "fix", "chore", "docs", "test", "refactor"]
}
```

**Fields**:
- `pattern`: Template for branch names. Variables: `{prefix}`, `{issue_id}`, `{slug}`
- `allowed_prefixes`: Valid semantic prefixes

**Common Patterns**:
```json
// Conventional: feat/123-description
"pattern": "{prefix}/{issue_id}-{slug}"

// Simple: feat-description
"pattern": "{prefix}-{slug}"

// Ticket first: 123-feat-description
"pattern": "{issue_id}-{prefix}-{slug}"

// User prefix: username/feat/123-description
"pattern": "{username}/{prefix}/{issue_id}-{slug}"
```

**Allowed Prefixes**:
- `feat`: New features
- `fix`: Bug fixes
- `chore`: Maintenance tasks
- `hotfix`: Urgent fixes
- `docs`: Documentation
- `test`: Test additions
- `refactor`: Code refactoring
- `style`: Code style changes
- `perf`: Performance improvements

#### `commit_format`
- **Type**: string (`"conventional"` | `"faber"`)
- **Default**: `"faber"`
- **Description**: Commit message format

**Conventional Commits**:
```
feat(scope): Add new feature

Body text

Closes #123
```

**FABER Format** (includes additional metadata):
```
feat(scope): Add new feature

Body text

Work-Item: #123
Author-Context: architect
Phase: Build
```

#### `require_signed_commits`
- **Type**: boolean
- **Default**: `false`
- **Description**: Require GPG-signed commits for compliance

**Requires**:
```bash
# Generate GPG key
gpg --gen-key

# Configure git
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true
```

#### `merge_strategy`
- **Type**: string (`"no-ff"` | `"squash"` | `"ff-only"`)
- **Default**: `"no-ff"`
- **Description**: Default merge strategy for branches

**Strategies**:
- `no-ff`: Create merge commit (preserves history)
- `squash`: Squash all commits into one (clean history)
- `ff-only`: Fast-forward only (linear history)

**When to use**:
- `no-ff`: Feature branches (want to see feature development)
- `squash`: Bug fixes (want single commit in main)
- `ff-only`: Simple changes (want linear history)

#### `auto_delete_merged_branches`
- **Type**: boolean
- **Default**: `false`
- **Description**: Automatically delete branches after successful merge

**Warning**: Set to `true` for automatic cleanup, but be careful in shared repositories.

#### `remote`

Remote repository settings.

```json
{
  "name": "origin",
  "auto_set_upstream": true
}
```

**Fields**:
- `name`: Remote name (usually `"origin"`)
- `auto_set_upstream`: Automatically set upstream when pushing new branches

#### `pr`

Pull request settings.

```json
{
  "template": "standard",
  "require_work_id": true,
  "auto_link_issues": true
}
```

**Fields**:
- `template`: PR body template (`"standard"` | `"minimal"` | `"detailed"`)
- `require_work_id`: Require work item reference in PRs
- `auto_link_issues`: Automatically add "closes #issue" references

**Templates**:

**Standard**:
```markdown
## Summary
Changes for issue #123

## Related
- Closes #123
- Work ID: `123`
```

**Minimal**:
```markdown
Closes #123
```

**Detailed**:
```markdown
## Summary
[Description]

## Changes
- [Change 1]
- [Change 2]

## Testing
- [Test 1]
- [Test 2]

## Related
- Closes #123
```

#### `cleanup`

Branch cleanup settings.

```json
{
  "inactive_threshold_days": 30,
  "auto_cleanup_merged": false,
  "exclude_patterns": ["release/*", "hotfix/*"]
}
```

**Fields**:
- `inactive_threshold_days`: Days before branch is considered stale
- `auto_cleanup_merged`: Automatically delete merged branches
- `exclude_patterns`: Branch patterns to exclude from cleanup

#### `tags`

Tag management settings.

```json
{
  "require_signed_tags": false,
  "auto_push_tags": false
}
```

**Fields**:
- `require_signed_tags`: Require GPG-signed tags for releases
- `auto_push_tags`: Automatically push tags after creation

## FABER Integration

Settings for FABER workflow integration.

```json
{
  "faber_integration": {
    "enabled": true,
    "branch_creation": {
      "auto_create": true,
      "use_work_id": true
    },
    "commit_metadata": {
      "include_author_context": true,
      "include_phase": true,
      "include_work_id": true
    },
    "pr_creation": {
      "auto_create": true,
      "include_metadata": true,
      "draft_until_approved": false
    }
  }
}
```

### Fields

#### `enabled`
- **Type**: boolean
- **Default**: `true`
- **Description**: Enable FABER workflow integration

#### `branch_creation`
- `auto_create`: Automatically create branches during Frame phase
- `use_work_id`: Include work item ID in branch name

#### `commit_metadata`
- `include_author_context`: Include author role (architect|implementor|tester|reviewer)
- `include_phase`: Include FABER phase (Frame|Architect|Build|Evaluate|Release)
- `include_work_id`: Include work item ID in commit metadata

#### `pr_creation`
- `auto_create`: Automatically create PR during Release phase
- `include_metadata`: Include FABER metadata in PR body
- `draft_until_approved`: Create PRs as drafts until workflow approval

## Platform-Specific Options

Platform-specific overrides and settings.

```json
{
  "platform_specific": {
    "github": {
      "use_gh_cli": true,
      "pr_checks": {
        "require_ci_pass": true,
        "require_reviews": 1
      }
    },
    "gitlab": {
      "use_glab_cli": true,
      "mr_checks": {
        "require_ci_pass": true,
        "require_approvals": 1
      }
    },
    "bitbucket": {
      "use_bb_cli": false,
      "pr_checks": {
        "require_builds_pass": true,
        "require_approvals": 1
      }
    }
  }
}
```

### GitHub Options

- `use_gh_cli`: Use GitHub CLI for operations (recommended)
- `pr_checks.require_ci_pass`: Require CI checks before merge
- `pr_checks.require_reviews`: Minimum approving reviews (0 to disable)

### GitLab Options

- `use_glab_cli`: Use GitLab CLI for operations (recommended)
- `mr_checks.require_ci_pass`: Require CI pipelines before merge
- `mr_checks.require_approvals`: Minimum approvals required

### Bitbucket Options

- `use_bb_cli`: Use Bitbucket CLI if available
- `pr_checks.require_builds_pass`: Require builds to pass
- `pr_checks.require_approvals`: Minimum approvals required

## Configuration Precedence

When multiple config files exist, they're loaded in this order:

1. **Project-specific** (`.fractary/plugins/repo/config.json`)
2. **User-global** (`~/.fractary/repo/config.json`)
3. **Built-in defaults**

Later sources override earlier ones for matching fields.

**Example**:

Global config:
```json
{
  "defaults": {
    "default_branch": "main",
    "merge_strategy": "no-ff"
  }
}
```

Project config:
```json
{
  "defaults": {
    "default_branch": "develop"
  }
}
```

**Result**:
```json
{
  "defaults": {
    "default_branch": "develop",    // From project
    "merge_strategy": "no-ff"       // From global
  }
}
```

## Common Scenarios

### Scenario 1: Simple Personal Projects

```json
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
```

Use SSH for git operations, token only for API.

### Scenario 2: Team Project with Standards

```json
{
  "handlers": {
    "source_control": {
      "active": "github",
      "github": {
        "token": "$GITHUB_TOKEN"
      }
    }
  },
  "defaults": {
    "default_branch": "develop",
    "protected_branches": ["main", "develop", "production"],
    "require_signed_commits": true,
    "merge_strategy": "squash",
    "branch_naming": {
      "pattern": "{prefix}/{issue_id}-{slug}",
      "allowed_prefixes": ["feat", "fix", "chore", "hotfix"]
    }
  },
  "platform_specific": {
    "github": {
      "pr_checks": {
        "require_ci_pass": true,
        "require_reviews": 2
      }
    }
  }
}
```

### Scenario 3: Multiple Projects with Different Platforms

**Global config** (`~/.fractary/repo/config.json`):
```json
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
```

**Project A** (`.fractary/plugins/repo/config.json`):
```json
{
  "handlers": {
    "source_control": {
      "active": "gitlab",
      "gitlab": {
        "token": "$GITLAB_TOKEN"
      }
    }
  }
}
```

Project A uses GitLab, all others use GitHub.

### Scenario 4: CI/CD Environment

```json
{
  "handlers": {
    "source_control": {
      "active": "github",
      "github": {
        "token": "$CI_GITHUB_TOKEN"
      }
    }
  },
  "defaults": {
    "auto_delete_merged_branches": true,
    "merge_strategy": "squash"
  }
}
```

Use CI-specific token, auto-cleanup branches.

## Environment Variables

The plugin supports environment variable references in configuration:

```json
{
  "github": {
    "token": "$GITHUB_TOKEN"    // Replaced with env var value
  }
}
```

**Format**: `$VARIABLE_NAME` (no braces)

**Common Variables**:
- `$GITHUB_TOKEN` - GitHub Personal Access Token
- `$GITLAB_TOKEN` - GitLab Personal Access Token
- `$BITBUCKET_USERNAME` - Bitbucket username
- `$BITBUCKET_TOKEN` - Bitbucket app password

**Setting Variables**:
```bash
# In shell profile (~/.bashrc, ~/.zshrc)
export GITHUB_TOKEN="ghp_..."
export GITLAB_TOKEN="glpat_..."
```

## Troubleshooting

### Configuration Not Loading

**Check**:
```bash
# Verify file exists
ls -la ~/.fractary/repo/config.json
ls -la .fractary/plugins/repo/config.json

# Verify JSON syntax
cat config.json | jq .
```

### Token Not Working

**Check**:
```bash
# Verify token is set
echo $GITHUB_TOKEN

# Test token
gh auth status
gh api user
```

### Wrong Platform Being Used

**Check**:
```bash
# Verify active handler
cat config.json | jq '.handlers.source_control.active'

# Should match your platform
```

### SSH vs HTTPS Issues

**Check git remote**:
```bash
# Show current remote
git remote -v

# SSH format: git@github.com:owner/repo.git
# HTTPS format: https://github.com/owner/repo.git

# Switch to SSH
git remote set-url origin git@github.com:owner/repo.git

# Switch to HTTPS
git remote set-url origin https://github.com/owner/repo.git
```

## See Also

- [GitHub Setup Guide](setup/github-setup.md)
- [GitLab Setup Guide](setup/gitlab-setup.md)
- [Bitbucket Setup Guide](setup/bitbucket-setup.md)
- [Setup Wizard](/repo:init)
- [Example Configuration](../config/repo.example.json)
