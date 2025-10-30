---
name: fractary-work:init
description: Work Plugin Setup Wizard
argument-hint: [--platform github|jira|linear] [--token <value>] [--yes] [--force]
---

# /work:init - Work Plugin Setup Wizard

**Interactive setup wizard for the Fractary Work Plugin**

## Description

The `/work:init` command provides an interactive setup wizard that guides you through configuring the Fractary Work Plugin for your project. It detects your environment, validates credentials, and creates the appropriate configuration file.

## Usage

```bash
# Run setup wizard (interactive)
/work:init

# Setup with specific platform
/work:init --platform github

# Non-interactive mode with defaults
/work:init --platform github --token $GITHUB_TOKEN --yes

# Force reconfigure
/work:init --force
```

## Options

- `--platform <name>` - Specify platform: `github`, `jira`, or `linear`
- `--token <value>` - Provide GitHub/Jira/Linear token directly
- `--yes` or `-y` - Skip confirmations (use detected/provided values)
- `--force` - Overwrite existing configuration
- `--help` - Show this help message

## What the Wizard Does

### 1. **Environment Detection**
- Checks if you're in a git repository
- Detects remote URL if present
- Identifies GitHub from remote (if applicable)
- Checks for existing plugin configuration

### 2. **Platform Selection**
- Auto-detects GitHub if remote URL contains github.com
- Prompts user to select: GitHub, Jira, or Linear
- Gathers platform-specific configuration

### 3. **Authentication Setup**
- Checks for token in environment variables
- Prompts for token if needed
- Validates token with platform API
- Tests basic API operations

### 4. **Configuration Creation**
- Creates `.fractary/plugins/work/` directory
- Copies and customizes config template
- Writes configuration file
- Sets appropriate permissions

### 5. **Validation**
- Tests API authentication
- Verifies repository/project access
- Confirms configuration loads correctly
- Provides setup summary

## Interactive Flow

### Step 1: Welcome & Detection

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Fractary Work Plugin Setup Wizard
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Detecting environment...
✓ Git repository detected
✓ Remote: git@github.com:owner/repo.git
✓ Detected platform: GitHub (github.com)
```

### Step 2: Platform Selection

If platform can't be detected:
```
Select work tracking platform:
  1. GitHub Issues (github.com or Enterprise)
  2. Jira Cloud (atlassian.net)
  3. Linear (linear.app)

Choice [1-3]:
```

### Step 3: Platform-Specific Configuration

#### For GitHub:
```
GitHub Configuration:

  Repository owner: [auto-detected or prompt]
  Repository name: [auto-detected or prompt]
  GitHub API URL: https://api.github.com

Do you have a GITHUB_TOKEN environment variable set? (y/n):
```

#### For Jira:
```
Jira Configuration:

  Jira URL (e.g., https://your-domain.atlassian.net):
  Project key (e.g., PROJ):
  Email address:

Do you have a JIRA_TOKEN environment variable set? (y/n):
```

#### For Linear:
```
Linear Configuration:

  Workspace ID:
  Team ID:
  Team key (e.g., ENG):

Do you have a LINEAR_API_KEY environment variable set? (y/n):
```

### Step 4: Token Validation

```
Enter token (or press Enter to use environment variable):
[hidden input]

Validating token...
✓ Token is valid
✓ Access verified for: owner/repo
```

### Step 5: Summary & Completion

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Configuration Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Platform: GitHub
Repository: owner/repo
Config: .fractary/plugins/work/config.json

✓ Configuration file created
✓ GitHub token validated
✓ Repository access verified
✓ gh CLI available

Setup complete! Try these commands:

  /work:issue create "New feature" --type feature
  /work:issue fetch 123
  /work:issue comment 123 "Working on this"
  /work:state close 123

Documentation: plugins/work/README.md
```

## Examples

### Example 1: Basic Interactive Setup

```bash
$ /work:init

# Wizard guides through all steps interactively
# Detects GitHub from remote URL if present
# Prompts for token
# Creates config at .fractary/plugins/work/config.json
```

### Example 2: GitHub with Existing Token

```bash
$ export GITHUB_TOKEN="ghp_..."
$ /work:init --platform github --yes

# Uses existing token from environment
# Auto-detects owner/repo from git remote
# Creates config automatically
```

### Example 3: Jira Configuration

```bash
$ export JIRA_TOKEN="your_token"
$ export JIRA_EMAIL="your@email.com"
$ /work:init --platform jira

# Prompts for Jira URL and project key
# Uses tokens from environment
# Creates Jira-specific config
```

### Example 4: Force Reconfigure

```bash
$ /work:init --force

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
  // Extract owner/repo from URL
} else {
  // Prompt user to select platform
}
```

### Repository Parsing (GitHub)

```javascript
// Extract owner and repo from remote URL
// SSH: git@github.com:owner/repo.git
// HTTPS: https://github.com/owner/repo.git

if (ssh_format) {
  parts = remote_url.split(":")[1].replace(".git", "").split("/")
} else {
  parts = remote_url.split("github.com/")[1].replace(".git", "").split("/")
}

owner = parts[0]
repo = parts[1]
```

## Configuration File Structure

The wizard creates a configuration file with this structure:

### GitHub Configuration

```json
{
  "version": "2.0",
  "project": {
    "issue_system": "github",
    "repository": "owner/repo"
  },
  "handlers": {
    "work-tracker": {
      "active": "github",
      "github": {
        "owner": "owner",
        "repo": "repo",
        "api_url": "https://api.github.com",
        "classification": {
          "type_labels": {
            "feature": "type: feature",
            "bug": "type: bug",
            "chore": "type: chore"
          }
        },
        "states": {
          "open": "open",
          "in_progress": "in_progress",
          "closed": "closed"
        },
        "labels": {
          "prefix": "type: "
        }
      }
    }
  },
  "defaults": {
    "auto_assign": true,
    "template_issue_type": "feature"
  }
}
```

### Jira Configuration

```json
{
  "version": "2.0",
  "handlers": {
    "work-tracker": {
      "active": "jira",
      "jira": {
        "url": "https://your-domain.atlassian.net",
        "project_key": "PROJ",
        "email": "your@email.com",
        "custom_fields": {}
      }
    }
  }
}
```

### Linear Configuration

```json
{
  "version": "2.0",
  "handlers": {
    "work-tracker": {
      "active": "linear",
      "linear": {
        "workspace_id": "workspace-id",
        "team_id": "team-id",
        "team_key": "ENG"
      }
    }
  }
}
```

## Validation Steps

The wizard performs these validations:

### 1. Git Repository Check (Optional)
```bash
git rev-parse --git-dir
# Warn if not in git repository (not required)
```

### 2. Token Validation (GitHub)
```bash
gh auth status
# Or direct API call:
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

### 3. Repository Access Test (GitHub)
```bash
gh api repos/{owner}/{repo}
# Verify read access to repository
```

### 4. Token Validation (Jira)
```bash
curl -u email:token https://your-domain.atlassian.net/rest/api/3/myself
# Verify authentication and get user info
```

### 5. Token Validation (Linear)
```bash
curl -H "Authorization: LINEAR_API_KEY" https://api.linear.app/graphql \
  -d '{"query": "{ viewer { id name } }"}'
# Verify API key and get user info
```

### 6. Configuration Loading Test
```bash
# Test that config-loader.sh can read the new config
./plugins/work/skills/work-common/scripts/config-loader.sh
```

## Error Handling

### Token Validation Failed

```
✗ Error: GitHub token validation failed

Possible issues:
  1. Token is invalid or expired
  2. Token doesn't have required scopes (repo, read:org)
  3. Network connectivity issues

Generate a new token:
  https://github.com/settings/tokens

Required scopes: repo, read:org
```

### Repository Not Accessible

```
✗ Error: Cannot access repository owner/repo

Possible issues:
  1. Repository doesn't exist
  2. Token doesn't have access to this repository
  3. Owner or repo name is incorrect

Verify repository exists:
  https://github.com/owner/repo
```

### Existing Configuration

```
⚠ Configuration already exists at:
  .fractary/plugins/work/config.json

Options:
  1. Update existing config (merge changes)
  2. Overwrite with new config
  3. Cancel and keep existing

Choice [1-3]:
```

### Not in Git Repository (GitHub)

```
⚠ Warning: Not in a git repository

Cannot auto-detect repository. You'll need to manually enter:
  - Repository owner
  - Repository name

Or navigate to your git repository first:
  cd /path/to/your/repo
```

## Implementation Notes

<CONTEXT>
You are the /work:init command for the Fractary work plugin.
You provide an interactive setup wizard that configures the plugin for the user's work tracking system.
You detect platform, gather configuration, validate credentials, and create the config file.
This is a GitHub-focused MVP - Jira and Linear support is simplified for now.
</CONTEXT>

<CRITICAL_RULES>
1. **NEVER overwrite config without confirmation** unless `--force` flag is used
2. **ALWAYS validate tokens** before saving them to config
3. **NEVER log or display tokens** in plain text (mask with ***)
4. **ALWAYS test API connectivity** before confirming success
5. **NEVER assume platform** if detection is ambiguous - always prompt
6. **CONFIGURATION SCOPE**: Only create project-local config at `.fractary/plugins/work/config.json` (no global scope)
</CRITICAL_RULES>

<INPUTS>
**Arguments**:
- `--platform <name>` - Platform override (github, jira, linear)
- `--token <value>` - Token value
- `--yes` - Auto-confirm
- `--force` - Overwrite existing

**Environment Variables**:
- `$GITHUB_TOKEN` - GitHub token
- `$JIRA_TOKEN` - Jira API token
- `$JIRA_EMAIL` - Jira email address
- `$LINEAR_API_KEY` - Linear API key
</INPUTS>

<WORKFLOW>
1. **Parse command arguments**
   - Extract flags and options
   - Determine interactive vs non-interactive mode

2. **Detect environment**
   - Check if in git repository (optional, warn if not)
   - Get remote URL if present
   - Detect platform from remote (GitHub only)
   - Extract owner/repo from GitHub remote

3. **Check existing configuration**
   - Look for project-specific config at `.fractary/plugins/work/config.json`
   - If exists, prompt for action (unless --force)

4. **Platform selection** (if not detected/specified)
   - Prompt user for platform (GitHub/Jira/Linear)
   - Validate selection

5. **Gather platform-specific configuration**
   - **GitHub**: owner, repo, api_url
   - **Jira**: url, project_key, email
   - **Linear**: workspace_id, team_id, team_key

6. **Authentication setup**
   - Check for token in environment variables
   - Prompt for token if not found
   - Validate token with platform API

7. **Create configuration**
   - Create `.fractary/plugins/work/` directory if needed
   - Copy template from `plugins/work/config/config.example.json`
   - Customize with user's values
   - Write config file
   - Set appropriate permissions

8. **Validate setup**
   - Test configuration loads with config-loader.sh
   - Test API authentication
   - Verify repository/project access

9. **Display summary**
   - Show configuration location
   - Show detected settings
   - Provide next steps
</WORKFLOW>

<OUTPUTS>
**Success**:
- Configuration file created at `.fractary/plugins/work/config.json`
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
- 10: Configuration already exists (without --force)
- 11: Token validation failed
- 12: Network/connectivity error
- 13: Invalid platform
</OUTPUTS>

<AGENT_INVOCATION>
Invoke the `work-manager` agent with operation `initialize-configuration`:

```json
{
  "operation": "initialize-configuration",
  "parameters": {
    "platform": "github|jira|linear",
    "token": "masked-token-value",
    "interactive": true|false,
    "force": true|false,
    "github_config": {
      "owner": "owner",
      "repo": "repo",
      "api_url": "https://api.github.com"
    },
    "jira_config": {
      "url": "https://domain.atlassian.net",
      "project_key": "PROJ",
      "email": "user@example.com"
    },
    "linear_config": {
      "workspace_id": "workspace-id",
      "team_id": "team-id",
      "team_key": "ENG"
    }
  }
}
```
</AGENT_INVOCATION>

<ERROR_HANDLING>
- **Not in git repo (GitHub)**: Warn but continue, prompt for owner/repo manually
- **No remote (GitHub)**: Prompt for owner/repo manually
- **Token invalid**: Prompt to re-enter or exit
- **Existing config**: Prompt for action (update/overwrite/cancel)
- **Network error**: Retry once, then fail with troubleshooting
- **Missing CLI tools**: Warn but continue (still create config)
- **Invalid platform**: Exit with error listing valid platforms
</ERROR_HANDLING>

## Platform-Specific Notes

### GitHub (MVP Focus)
- Requires `gh` CLI for full functionality
- Token scopes: `repo`, `read:org`
- API test: `gh auth status` or `curl https://api.github.com/user`
- Repository test: `gh api repos/{owner}/{repo}`
- Can auto-detect owner/repo from git remote

### Jira (Basic Support)
- Token = API token (not password)
- Requires email address + token for authentication
- API test: `curl -u email:token https://domain.atlassian.net/rest/api/3/myself`
- No auto-detection available

### Linear (Basic Support)
- Requires API key from Linear settings
- API test via GraphQL: `curl -H "Authorization: KEY" https://api.linear.app/graphql`
- No auto-detection available

## See Also

- [Work Plugin README](../README.md)
- [Configuration Reference](../config/config.example.json)
- [GitHub Issues Handler](../skills/handler-work-tracker-github/SKILL.md)
- [Jira Handler](../skills/handler-work-tracker-jira/SKILL.md)
- [Linear Handler](../skills/handler-work-tracker-linear/SKILL.md)

## Troubleshooting

If the wizard fails, try manual configuration:

```bash
# Create config directory
mkdir -p .fractary/plugins/work

# Copy example config
cp plugins/work/config/config.example.json .fractary/plugins/work/config.json

# Edit manually
nano .fractary/plugins/work/config.json
```

Then set your token:
```bash
# For GitHub
export GITHUB_TOKEN="your_token_here"

# For Jira
export JIRA_TOKEN="your_api_token"
export JIRA_EMAIL="your@email.com"

# For Linear
export LINEAR_API_KEY="your_api_key"
```

And test:
```bash
/work:issue fetch --help
```
