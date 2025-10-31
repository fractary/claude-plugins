# GitHub Setup Guide

Complete setup guide for using the Fractary Repo Plugin with GitHub.

## Prerequisites

- Git installed and configured
- GitHub account
- Access to repositories you want to manage

## Installation

### 1. Install GitHub CLI

The plugin uses the GitHub CLI (`gh`) for GitHub API operations.

**macOS**:
```bash
brew install gh
```

**Linux (Debian/Ubuntu)**:
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

**Windows**:
```bash
winget install --id GitHub.cli
```

### 2. Authenticate with GitHub

```bash
gh auth login
```

Follow the prompts:
1. Select GitHub.com
2. Choose HTTPS or SSH
3. Authenticate via browser or token
4. Choose your preferred protocol

### 3. Verify Installation

```bash
# Check gh CLI
gh --version

# Check authentication
gh auth status

# Test API access
gh repo view
```

## Configuration

### Authentication Methods Overview

The Fractary Repo Plugin supports two authentication methods for GitHub:

| Method | Use Case | Git Operations | API Operations (gh CLI) | Security |
|--------|----------|----------------|-------------------------|----------|
| **SSH Keys** | Recommended for daily development | ✅ Yes | ❌ No (requires token) | 🔒 Most secure (key-based) |
| **HTTPS + Token** | Simplest setup, CI/CD | ✅ Yes | ✅ Yes | 🔐 Secure (token-based) |

**Recommendation**: Use **SSH for git operations** (clone, push, pull) and **token for API operations** (creating PRs, managing issues). This provides the best security and user experience.

### Option A: SSH Authentication (Recommended)

SSH keys provide secure, password-less authentication for git operations.

#### 1. Generate SSH Key (if you don't have one)

```bash
# Generate new SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# When prompted for file location, press Enter to accept default
# Set a secure passphrase when prompted (or press Enter for no passphrase)
```

For older systems that don't support Ed25519:
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

#### 2. Add SSH Key to SSH Agent

```bash
# Start ssh-agent
eval "$(ssh-agent -s)"

# Add your SSH private key
ssh-add ~/.ssh/id_ed25519  # or ~/.ssh/id_rsa if you used RSA
```

**macOS users**: Add to `~/.ssh/config` for automatic key loading:
```
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
```

#### 3. Add SSH Public Key to GitHub

```bash
# Copy your public key to clipboard
# macOS:
pbcopy < ~/.ssh/id_ed25519.pub

# Linux:
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard

# Windows (Git Bash):
cat ~/.ssh/id_ed25519.pub | clip
```

Then:
1. Go to GitHub Settings → SSH and GPG keys: https://github.com/settings/keys
2. Click "New SSH key"
3. Title: "My Development Machine" (or descriptive name)
4. Paste your public key
5. Click "Add SSH key"

#### 4. Test SSH Connection

```bash
ssh -T git@github.com
```

You should see:
```
Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

#### 5. Configure Git to Use SSH

For new repositories:
```bash
# Clone with SSH
git clone git@github.com:owner/repo.git
```

For existing repositories using HTTPS:
```bash
# Switch remote to SSH
git remote set-url origin git@github.com:owner/repo.git

# Verify
git remote -v
```

#### 6. GitHub Token for API Operations

Even with SSH, you still need a Personal Access Token for API operations (creating PRs, issues, etc.):

```bash
# Create token (see Option B below for detailed steps)
export GITHUB_TOKEN="ghp_your_token_here"
```

Add to your shell profile (`~/.bashrc` or `~/.zshrc`):
```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

#### 7. Configure Plugin for SSH

When using SSH, your plugin configuration is minimal:

```json
{
  "handlers": {
    "source_control": {
      "active": "github",
      "github": {
        "token": "$GITHUB_TOKEN"  // Only for API operations
      }
    }
  }
}
```

**Note**: Git operations (push, pull, clone) will use SSH keys automatically. The token is only needed for `gh` CLI API operations (creating PRs, managing issues).

### Option B: HTTPS with Personal Access Token

HTTPS authentication uses a Personal Access Token for both git and API operations.

#### 1. Create GitHub Personal Access Token

1. Go to GitHub Settings: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Give it a descriptive name: "Fractary Repo Plugin"
4. Select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Action workflows)
   - ✅ `read:org` (Read org and team membership)
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again)

### 2. Set Environment Variable

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

Reload your shell:
```bash
source ~/.bashrc  # or ~/.zshrc
```

Verify:
```bash
echo $GITHUB_TOKEN
```

### 3. Configure Repo Plugin

Create configuration file:

```bash
# Create directory
mkdir -p ~/.fractary/repo

# Copy example configuration
cp plugins/repo/config/repo.example.json ~/.fractary/repo/config.json
```

Edit `~/.fractary/repo/config.json`:

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
    "protected_branches": ["main", "master", "production", "staging"],
    "branch_naming": {
      "pattern": "{prefix}/{issue_id}-{slug}",
      "allowed_prefixes": ["feat", "fix", "chore", "hotfix", "docs", "test", "refactor", "style", "perf"]
    },
    "commit_format": "faber",
    "require_signed_commits": false,
    "merge_strategy": "no-ff",
    "auto_delete_merged_branches": false
  }
}
```

## Testing

### Test Basic Operations

```bash
# 1. Navigate to a Git repository
cd /path/to/your/repo

# 2. Test branch creation
/repo:branch create 1 "test setup"

# 3. Make a change
echo "test" > test.txt
git add test.txt

# 4. Test commit
/repo:commit "Test commit" --type test --work-id 1

# 5. Test push
/repo:push --set-upstream

# 6. Clean up test branch
git checkout main
/repo:branch delete test/1-test-setup
```

## GitHub Enterprise Setup

If using GitHub Enterprise, update the API URL:

```json
{
  "handlers": {
    "source_control": {
      "active": "github",
      "github": {
        "token": "$GITHUB_TOKEN",
        "api_url": "https://github.your-company.com/api/v3"
      }
    }
  }
}
```

## Advanced Configuration

### GPG Signing

To enable commit signing:

1. **Generate GPG key**:
```bash
gpg --gen-key
```

2. **Configure Git**:
```bash
# List keys
gpg --list-secret-keys --keyid-format LONG

# Set signing key
git config --global user.signingkey YOUR_KEY_ID

# Enable signing
git config --global commit.gpgsign true
```

3. **Add to GitHub**:
```bash
# Export public key
gpg --armor --export YOUR_KEY_ID

# Add to GitHub: Settings → SSH and GPG keys → New GPG key
```

4. **Update plugin config**:
```json
{
  "defaults": {
    "require_signed_commits": true
  }
}
```

### Protected Branches

Configure branch protection in GitHub:

1. Go to repository Settings → Branches
2. Add branch protection rule for `main`:
   - Require pull request reviews before merging
   - Require status checks to pass
   - Require branches to be up to date
   - Include administrators (optional)

Update plugin config to match:
```json
{
  "defaults": {
    "protected_branches": ["main", "master", "production", "staging"],
    "platform_specific": {
      "github": {
        "pr_checks": {
          "require_ci_pass": true,
          "require_reviews": 1
        }
      }
    }
  }
}
```

### Multiple Organizations

If working with multiple GitHub organizations:

```bash
# Switch between organizations
gh auth switch

# Or use multiple tokens
export GITHUB_TOKEN_ORG1="token1"
export GITHUB_TOKEN_ORG2="token2"
```

## Troubleshooting

### Authentication Issues

**Problem**: "Authentication failed"

**Solutions**:
```bash
# 1. Check token is set
echo $GITHUB_TOKEN

# 2. Re-authenticate gh CLI
gh auth login

# 3. Verify token has correct scopes
# Go to https://github.com/settings/tokens and check permissions

# 4. Test API access
gh api user
```

### Rate Limiting

**Problem**: "API rate limit exceeded"

**Solutions**:
- Use authenticated requests (ensure GITHUB_TOKEN is set)
- Wait for rate limit reset (check with `gh api rate_limit`)
- Consider GitHub Enterprise for higher limits

### Permission Errors

**Problem**: "Permission denied"

**Solutions**:
```bash
# 1. Check repository access
gh repo view owner/repo

# 2. Verify token scopes include 'repo'
# Regenerate token with correct scopes if needed

# 3. Check organization permissions
# May need admin approval for certain operations
```

### Branch Protection Errors

**Problem**: "Cannot push to protected branch"

**Solutions**:
- Create PR instead of direct push
- Use `/repo:pr create` command
- Check if you have admin override permissions

### Network Issues

**Problem**: "Failed to connect to GitHub"

**Solutions**:
```bash
# 1. Check internet connectivity
ping github.com

# 2. Check firewall/proxy settings
git config --global http.proxy http://proxy:port

# 3. Test GitHub API
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

### SSH Authentication Issues

**Problem**: "Permission denied (publickey)"

**Solutions**:
```bash
# 1. Test SSH connection
ssh -T git@github.com

# 2. Check if ssh-agent is running and has your key
ssh-add -l

# 3. Add your SSH key to agent
ssh-add ~/.ssh/id_ed25519  # or ~/.ssh/id_rsa

# 4. Verify key is added to GitHub
# Go to https://github.com/settings/keys

# 5. Check SSH config
cat ~/.ssh/config

# 6. Use verbose mode to debug
ssh -vT git@github.com
```

**Problem**: "Could not open a connection to your authentication agent"

**Solutions**:
```bash
# Start ssh-agent
eval "$(ssh-agent -s)"

# Then add your key
ssh-add ~/.ssh/id_ed25519
```

**Problem**: "Host key verification failed"

**Solutions**:
```bash
# Accept GitHub's host key
ssh-keyscan github.com >> ~/.ssh/known_hosts

# Or remove old host key and reconnect
ssh-keygen -R github.com
ssh -T git@github.com  # Accept new key when prompted
```

**Problem**: "Git operations work but API operations fail"

**Solution**:
This is expected when using SSH for git operations. API operations require a Personal Access Token:
```bash
# Set GitHub token for API operations
export GITHUB_TOKEN="ghp_your_token_here"

# Test API access
gh auth status
gh api user
```

## Best Practices

### Token Management

1. **Never commit tokens to repositories**
2. **Use environment variables** for token storage
3. **Rotate tokens regularly** (every 90 days recommended)
4. **Use minimal scopes** required for operations
5. **Revoke unused tokens** immediately

### Repository Workflow

1. **Always work on feature branches**, never directly on main
2. **Use semantic branch names**: `feat/123-description`
3. **Write clear commit messages** following Conventional Commits
4. **Create PRs for all changes** to protected branches
5. **Request reviews** before merging
6. **Delete merged branches** to keep repository clean

### Security

1. **Enable branch protection** on main/production branches
2. **Require reviews** for all PRs
3. **Enable CI checks** and require them to pass
4. **Use signed commits** for production code
5. **Audit access regularly** (check collaborators and permissions)

## Integration with FABER

When using with FABER workflows:

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

## Resources

- **GitHub CLI Documentation**: https://cli.github.com/manual/
- **GitHub API Documentation**: https://docs.github.com/en/rest
- **Personal Access Tokens**: https://github.com/settings/tokens
- **Branch Protection Rules**: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches
- **Conventional Commits**: https://www.conventionalcommits.org/

## Support

If you encounter issues:

1. Check this guide's troubleshooting section
2. Verify GitHub service status: https://www.githubstatus.com/
3. Review GitHub CLI issues: https://github.com/cli/cli/issues
4. File plugin issue: https://github.com/fractary/claude-plugins/issues
