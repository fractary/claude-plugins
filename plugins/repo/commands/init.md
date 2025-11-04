---
name: fractary-repo:init
description: Repository Plugin Setup Wizard
argument-hint: [--platform <name>] [--global|--project] [--token <value>] [--yes] [--force]
---

# /repo:init - Repository Plugin Setup Wizard

**Interactive setup wizard for the Fractary Repo Plugin**

## Description

The `/repo:init` command provides an interactive setup wizard that guides you through configuring the Fractary Repo Plugin for your project. It detects your environment, validates credentials, and creates the appropriate configuration file.

## Usage

```bash
# Run setup wizard (interactive)
/repo:init

# Setup with specific platform
/repo:init --platform github

# Setup with global scope (user-wide config)
/repo:init --global

# Setup with project scope (current project only)
/repo:init --project

# Non-interactive mode with defaults
/repo:init --platform github --token $GITHUB_TOKEN --yes
```

## Options

- `--platform <name>` - Specify platform: `github`, `gitlab`, or `bitbucket`
- `--global` - Create user-global config at `~/.fractary/repo/config.json`
- `--project` - Create project-specific config at `.fractary/plugins/repo/config.json`
- `--token <value>` - Provide GitHub/GitLab/Bitbucket token directly
- `--yes` or `-y` - Skip confirmations (use detected/provided values)
- `--force` - Overwrite existing configuration
- `--help` - Show this help message

## What the Wizard Does

### 1. **Environment Detection**
- Checks if you're in a git repository
- Detects remote URL (SSH vs HTTPS)
- Identifies platform (GitHub, GitLab, Bitbucket) from remote
- Checks for existing plugin configuration

### 2. **Authentication Setup**
- Detects authentication method (SSH vs HTTPS)
- Prompts for Personal Access Token if needed
- Validates token with platform API
- Tests git connectivity

### 3. **Configuration Creation**
- Prompts for config scope (project vs global)
- Creates config directory structure
- Writes configuration file
- Sets appropriate permissions

### 4. **Validation**
- Tests API authentication
- Verifies git remote access
- Confirms gh/glab CLI availability
- Provides setup summary

## Interactive Flow

### Step 1: Welcome & Detection

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Fractary Repo Plugin Setup Wizard
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Detecting environment...
✓ Git repository detected
✓ Remote: git@github.com:owner/repo.git
✓ Platform: GitHub
✓ Auth method: SSH
```

### Step 2: Platform Selection

If platform can't be detected:
```
Select source control platform:
  1. GitHub (github.com or Enterprise)
  2. GitLab (gitlab.com or self-hosted)
  3. Bitbucket (bitbucket.org or Server)

Choice [1-3]:
```

### Step 3: Authentication Method

```
Current setup:
  Remote URL: git@github.com:owner/repo.git
  Method: SSH (git push/pull use SSH keys)

You still need a Personal Access Token for API operations:
  • Creating pull requests
  • Managing issues
  • Commenting on PRs
  • Review operations

Do you have a GITHUB_TOKEN environment variable set? (y/n):
```

### Step 4: Token Validation

```
Enter GitHub Personal Access Token (or press Enter to use $GITHUB_TOKEN):
[hidden input]

Validating token...
✓ Token is valid
✓ Scopes: repo, workflow, read:org
✓ User: username
```

### Step 5: Configuration Scope

```
Where should the configuration be stored?

  1. Project-specific (.fractary/plugins/repo/config.json)
     - Only for this repository
     - Committed to version control (if desired)
     - Overrides user-global config

  2. User-global (~/.fractary/repo/config.json)
     - Used for all repositories
     - Not committed to version control
     - Convenient for personal projects

Choice [1-2]:
```

### Step 6: Configuration Options

```
Additional configuration:

  Default branch [main]:
  Protected branches [main,master,production]:
  Merge strategy (no-ff/squash/ff-only) [no-ff]:
  Push sync strategy (auto-merge/pull-rebase/pull-merge/manual/fail) [auto-merge]:

Use defaults? (y/n):
```

**Push Sync Strategy Options:**
- `auto-merge`: Automatically pull and merge when branch is out of sync (recommended for solo developers)
- `pull-rebase`: Automatically pull and rebase local commits
- `pull-merge`: Pull with explicit merge commit
- `manual`: Prompt for action when out of sync
- `fail`: Abort push if out of sync

### Step 7: Summary & Completion

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Configuration Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Platform: GitHub
Auth: SSH + Token
Config: ~/.fractary/repo/config.json

✓ Configuration file created
✓ GitHub token validated
✓ SSH connection verified
✓ gh CLI available

Setup complete! Try these commands:

  /repo:branch create 123 "new feature"
  /repo:commit "Add feature" --type feat
  /repo:push --set-upstream
  /repo:pr create "feat: New feature"

Documentation: plugins/repo/docs/setup/github-setup.md
```

## Examples

### Example 1: Basic Interactive Setup

```bash
$ /repo:init

# Wizard guides through all steps interactively
# Detects GitHub from remote URL
# Prompts for token
# Creates config at chosen location
```

### Example 2: GitHub with Existing Token

```bash
$ export GITHUB_TOKEN="ghp_..."
$ /repo:init --platform github --yes

# Uses existing token from environment
# Skips prompts, uses detected values
# Creates config automatically
```

### Example 3: Project-Specific Configuration

```bash
$ /repo:init --project

# Creates config in .fractary/plugins/repo/config.json
# Specific to current project
# Can be committed to repo
```

### Example 4: Global Configuration

```bash
$ /repo:init --global --platform github

# Creates config in ~/.fractary/repo/config.json
# Used for all projects
# Not in version control
```

### Example 5: Force Reconfigure

```bash
$ /repo:init --force

# Overwrites existing configuration
# Useful for fixing broken config
# Runs full wizard again
```

## Environment Detection Logic

### Platform Detection

```javascript
// Pseudo-code for detection logic
remote_url = git remote get-url origin

if (remote_url.includes("github.com") || remote_url.includes("github")) {
  platform = "github"
} else if (remote_url.includes("gitlab.com") || remote_url.includes("gitlab")) {
  platform = "gitlab"
} else if (remote_url.includes("bitbucket.org") || remote_url.includes("bitbucket")) {
  platform = "bitbucket"
} else {
  // Prompt user
}
```

### Auth Method Detection

```javascript
// Pseudo-code for auth detection
remote_url = git remote get-url origin

if (remote_url.startsWith("git@") || remote_url.startsWith("ssh://")) {
  auth_method = "SSH"
  git_auth = "SSH keys (~/.ssh/)"
  api_auth = "Token required"
} else if (remote_url.startsWith("https://")) {
  auth_method = "HTTPS"
  git_auth = "Token"
  api_auth = "Token"
}
```

## Configuration File Structure

The wizard creates a configuration file with this structure:

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
    "default_branch": "main",
    "protected_branches": ["main", "master", "production"],
    "merge_strategy": "no-ff",
    "push_sync_strategy": "auto-merge"
  }
}
```

## Validation Steps

The wizard performs these validations:

### 1. Git Repository Check
```bash
git rev-parse --git-dir
# Exit if not in git repository
```

### 2. Remote Check
```bash
git remote get-url origin
# Warn if no remote configured
```

### 3. Token Validation (GitHub)
```bash
gh auth status
# Or direct API call:
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

### 4. SSH Connection Test (if SSH detected)
```bash
ssh -T git@github.com
# Should return: "successfully authenticated"
```

### 5. CLI Availability
```bash
which gh    # GitHub CLI
which glab  # GitLab CLI
which git   # Git itself
```

## Error Handling

### Not in Git Repository

```
✗ Error: Not in a git repository

Initialize a git repository first:
  git init
  git remote add origin <url>

Or navigate to an existing repository.
```

### Token Validation Failed

```
✗ Error: GitHub token validation failed

Possible issues:
  1. Token is invalid or expired
  2. Token doesn't have required scopes (repo, workflow)
  3. Network connectivity issues

Generate a new token:
  https://github.com/settings/tokens

Required scopes: repo, workflow, read:org
```

### SSH Not Configured

```
⚠ Warning: SSH authentication not configured

Git operations may fail. Setup SSH:
  1. Generate key: ssh-keygen -t ed25519
  2. Add to GitHub: https://github.com/settings/keys
  3. Test: ssh -T git@github.com

Or switch to HTTPS:
  git remote set-url origin https://github.com/owner/repo.git
```

### Existing Configuration

```
⚠ Configuration already exists at:
  ~/.fractary/repo/config.json

Options:
  1. Update existing config (merge changes)
  2. Overwrite with new config
  3. Cancel and keep existing

Choice [1-3]:
```

## Implementation Notes

<CONTEXT>
You are the /repo:init command for the Fractary repo plugin.
You provide an interactive setup wizard that configures the plugin for the user's environment.
You detect platform, authentication, and create appropriate configuration files.
</CONTEXT>

<CRITICAL_RULES>
1. **NEVER overwrite config without confirmation** unless `--force` flag is used
2. **ALWAYS validate tokens** before saving them to config
3. **NEVER log or display tokens** in plain text (mask with ***)
4. **ALWAYS test connectivity** before confirming success
5. **NEVER assume platform** if detection is ambiguous - always prompt
</CRITICAL_RULES>

<INPUTS>
**Arguments**:
- `--platform <name>` - Platform override
- `--global` - Create global config
- `--project` - Create project config
- `--token <value>` - Token value
- `--yes` - Auto-confirm
- `--force` - Overwrite existing

**Environment Variables**:
- `$GITHUB_TOKEN` - GitHub token
- `$GITLAB_TOKEN` - GitLab token
- `$BITBUCKET_TOKEN` - Bitbucket token
- `$BITBUCKET_USERNAME` - Bitbucket username
</INPUTS>

<WORKFLOW>
1. **Parse command arguments**
   - Extract flags and options
   - Determine interactive vs non-interactive mode

2. **Detect environment**
   - Check if in git repository
   - Get remote URL
   - Detect platform from remote
   - Detect auth method (SSH vs HTTPS)

3. **Check existing configuration**
   - Look for project-specific config
   - Look for global config
   - If exists, prompt for action (unless --force)

4. **Platform selection** (if not detected/specified)
   - Prompt user for platform
   - Validate selection

5. **Authentication setup**
   - Check for token in environment
   - Prompt for token if not found
   - Validate token with platform API
   - Test SSH if SSH method detected

6. **Configuration scope**
   - Prompt for project vs global (if not specified)
   - Validate chosen directory

7. **Additional options** (interactive mode)
   - Default branch
   - Protected branches
   - Merge strategy (for PR merging)
   - Push sync strategy (for handling out-of-sync branches)
   - Or accept defaults

8. **Create configuration**
   - Create directory if needed
   - Write config file
   - Set appropriate permissions

9. **Validate setup**
   - Test API authentication
   - Test git remote access
   - Check CLI availability

10. **Display summary**
    - Show configuration location
    - Show detected settings
    - Provide next steps
</WORKFLOW>

<OUTPUTS>
**Success**:
- Configuration file created at specified location
- Summary of configuration
- Next steps to try

**Failure**:
- Clear error message
- Troubleshooting guidance
- Exit code > 0

**Exit Codes**:
- 0: Success
- 1: General error
- 2: Invalid arguments
- 3: Not in git repository
- 10: Configuration already exists (without --force)
- 11: Token validation failed
- 12: Network/connectivity error
</OUTPUTS>

<AGENT_INVOCATION>
Invoke the `repo-manager` agent with operation `initialize-configuration`:

```json
{
  "operation": "initialize-configuration",
  "parameters": {
    "platform": "github|gitlab|bitbucket",
    "scope": "project|global",
    "token": "masked-token-value",
    "interactive": true|false,
    "force": true|false,
    "options": {
      "default_branch": "main",
      "protected_branches": ["main", "master"],
      "merge_strategy": "no-ff",
      "push_sync_strategy": "auto-merge"
    }
  }
}
```
</AGENT_INVOCATION>

<ERROR_HANDLING>
- **Not in git repo**: Exit with clear error and instructions
- **No remote**: Warn but continue (local-only setup)
- **Token invalid**: Prompt to re-enter or exit
- **SSH not configured**: Warn but continue (token can work)
- **Existing config**: Prompt for action (update/overwrite/cancel)
- **Network error**: Retry once, then fail with troubleshooting
- **Missing CLI tools**: Warn but continue (core git operations still work)
</ERROR_HANDLING>

## Platform-Specific Notes

### GitHub
- Requires `gh` CLI for full functionality
- Token scopes: `repo`, `workflow`, `read:org`
- SSH test: `ssh -T git@github.com`
- API test: `gh auth status` or `curl https://api.github.com/user`

### GitLab
- Requires `glab` CLI for full functionality
- Token scopes: `api`, `write_repository`, `read_repository`
- SSH test: `ssh -T git@gitlab.com`
- API test: `glab auth status`

### Bitbucket
- No official CLI (uses curl for API)
- Requires username + app password
- Requires workspace slug
- SSH test: `ssh -T git@bitbucket.org`

## See Also

- [GitHub Setup Guide](../docs/setup/github-setup.md)
- [GitLab Setup Guide](../docs/setup/gitlab-setup.md)
- [Bitbucket Setup Guide](../docs/setup/bitbucket-setup.md)
- [Configuration Reference](../docs/configuration-guide.md)

## Troubleshooting

If the wizard fails, try manual configuration:

```bash
# Create config directory
mkdir -p ~/.fractary/repo

# Copy example config
cp plugins/repo/config/repo.example.json ~/.fractary/repo/config.json

# Edit manually
nano ~/.fractary/repo/config.json
```

Then set your token:
```bash
export GITHUB_TOKEN="your_token_here"
```

And test:
```bash
/repo:branch list --help
```
