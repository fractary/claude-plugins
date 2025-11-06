# Version Control Guide for Fractary Plugins

## TL;DR

**✅ DO commit `.fractary/` to version control**
**❌ DO NOT add `.fractary/` to `.gitignore`**

Project-specific plugin configurations should be shared with your team via version control.

---

## Why Commit Plugin Configurations?

Plugin configurations in `.fractary/plugins/*/config.json` are **project-specific settings** that define how your team works with:

- Work tracking systems (GitHub Issues, Jira, Linear)
- Source control platforms (GitHub, GitLab, Bitbucket)
- File storage (R2, S3, GCS)
- Workflow automation (FABER)
- Documentation standards
- Memory management (Codex)

**These configs should be the same for everyone on the team.** If you gitignore `.fractary/`, each developer would have to run `/plugin:init` commands manually, leading to:

- ❌ Configuration drift between team members
- ❌ Inconsistent workflows
- ❌ Onboarding friction (new devs can't just clone and go)
- ❌ Lost configuration when switching machines
- ❌ No audit trail of configuration changes

## What Goes in `.fractary/`?

### ✅ Safe to Commit

All plugin configuration files are designed to reference environment variables for secrets:

```json
{
  "handlers": {
    "source_control": {
      "github": {
        "token": "$GITHUB_TOKEN",    // ✅ Environment variable reference
        "api_url": "https://api.github.com"
      }
    }
  }
}
```

**What to commit:**
- `.fractary/plugins/*/config.json` - Plugin configurations
- `.fractary/plugins/*/config/*.json` - Additional config files
- `.fractary/workflows/` - Custom workflow definitions
- `.fractary/templates/` - Project-specific templates
- `.fractary/.gitignore` - Selective ignores (see below)

### ❌ DO NOT Commit (Add to `.fractary/.gitignore`)

Some plugins may create temporary or cache files:

```gitignore
# .fractary/.gitignore

# Temporary files
**/temp/
**/tmp/
**/.cache/
**/*.log

# OAuth tokens (if any plugin stores them locally - they shouldn't!)
**/tokens/
**/*token*.json

# Build artifacts or generated files
**/dist/
**/build/
```

## How Secrets Are Handled

### Environment Variables Pattern

All Fractary plugins follow this pattern for secrets:

**In config file (committed):**
```json
{
  "github": {
    "token": "$GITHUB_TOKEN"
  },
  "r2": {
    "access_key_id": "${R2_ACCESS_KEY_ID}",
    "secret_access_key": "${R2_SECRET_ACCESS_KEY}"
  }
}
```

**In your shell profile (NOT committed):**
```bash
# ~/.bashrc or ~/.zshrc
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxx"
export R2_ACCESS_KEY_ID="xxxxxxxxxxxxxxxxxxxxx"
export R2_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxxx"
```

**In CI/CD (NOT committed):**
- GitHub Actions: Repository Secrets
- GitLab CI: CI/CD Variables
- Other CI: Environment variables/secrets management

### Per-Developer Setup

Each developer needs to:

1. **Clone the repository** (gets all `.fractary/` configs)
2. **Set environment variables** (one-time setup per machine)
3. **Start working** (no need to run init commands)

```bash
# Clone repo (gets all configs)
git clone git@github.com:myorg/myproject.git
cd myproject

# Set environment variables (add to ~/.bashrc or ~/.zshrc)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxx"
export JIRA_TOKEN="your_jira_api_token"
export JIRA_EMAIL="developer@company.com"

# Ready to use plugins immediately!
/work:issue fetch 123
/repo:branch create 123 "new feature"
```

## Configuration Scope

### Project-Specific (Always Commit)

```
.fractary/plugins/
├── repo/
│   └── config.json          ✅ Commit (refs $GITHUB_TOKEN)
├── work/
│   └── config.json          ✅ Commit (refs $GITHUB_TOKEN or $JIRA_TOKEN)
├── file/
│   └── config.json          ✅ Commit (refs ${R2_ACCESS_KEY_ID})
└── codex/
    └── config/
        └── codex.json       ✅ Commit (sync patterns, project settings)
```

### User-Global (Never Commit)

Some plugins support optional global configs for personal preferences:

```
~/.config/fractary/           ❌ Never in project repo
└── codex/
    └── config.json           Personal defaults, org settings
```

**Note:** Most plugins should NOT use global configs since settings are project-specific.

## Migration: If You Already Gitignored `.fractary/`

If you previously added `.fractary/` to `.gitignore`, here's how to fix it:

```bash
# 1. Remove .fractary/ from .gitignore
sed -i '/^\.fractary/d' .gitignore

# 2. Review what's in .fractary/
ls -la .fractary/plugins/*/

# 3. Verify configs only reference env vars (no hardcoded secrets)
grep -r "token" .fractary/plugins/*/config.json
# Should see: "$GITHUB_TOKEN" or "${VAR_NAME}", NOT actual tokens

# 4. Create .fractary/.gitignore for temp files only
cat > .fractary/.gitignore <<'EOF'
# Temporary and cache files only
**/temp/
**/tmp/
**/.cache/
**/*.log
**/tokens/
EOF

# 5. Stage and commit
git add .fractary/
git commit -m "fix: Add plugin configs to version control

Plugin configurations use environment variables for secrets
and should be shared across the team via version control."

# 6. Push to remote
git push
```

## Best Practices

### ✅ DO

1. **Commit all `.fractary/plugins/*/config.json` files**
2. **Use environment variables for all secrets**
3. **Document required env vars in README**
4. **Add `.fractary/.gitignore` for temp files only**
5. **Review configs before committing** (ensure no hardcoded secrets)
6. **Use `.env.example` to document required vars**
7. **Update configs in PRs** (configuration is code)

### ❌ DO NOT

1. **Gitignore the entire `.fractary/` directory**
2. **Hardcode secrets in config files**
3. **Commit actual tokens/keys**
4. **Use different configs per developer** (defeats the purpose)
5. **Store OAuth refresh tokens in configs** (should be in secure storage)

## Example: .env.example

Document required environment variables for your project:

```bash
# .env.example (commit this file)

# GitHub (required for repo and work plugins)
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxx

# Jira (if using Jira for work tracking)
JIRA_TOKEN=your_jira_api_token
JIRA_EMAIL=developer@company.com

# Cloudflare R2 (if using R2 for file storage)
R2_ACCOUNT_ID=xxxxxxxxxxxxxxxxxxxxx
R2_ACCESS_KEY_ID=xxxxxxxxxxxxxxxxxxxxx
R2_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxx

# AWS (if using AWS for infrastructure)
AWS_ACCESS_KEY_ID=AKIAxxxxxxxxxxxxx
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxx
AWS_DEFAULT_REGION=us-east-1
```

Each developer copies this to `.env` (which IS gitignored) and fills in their actual values.

## Security Checklist

Before committing `.fractary/` configs:

- [ ] All tokens/secrets reference environment variables (`$VAR` or `${VAR}`)
- [ ] No hardcoded API keys, passwords, or tokens
- [ ] No OAuth refresh tokens stored in files
- [ ] Sensitive file paths use env vars if needed
- [ ] Config files are world-readable safe (no secrets inline)
- [ ] `.fractary/.gitignore` exists for temp/cache files
- [ ] `.env.example` documents all required env vars
- [ ] README explains how to set up environment variables

## Plugin-Specific Notes

### Repo Plugin
- ✅ Commit: `.fractary/plugins/repo/config.json`
- 🔐 Env var: `$GITHUB_TOKEN`, `$GITLAB_TOKEN`, `$BITBUCKET_TOKEN`

### Work Plugin
- ✅ Commit: `.fractary/plugins/work/config.json`
- 🔐 Env var: `$GITHUB_TOKEN`, `$JIRA_TOKEN`, `$LINEAR_API_KEY`

### File Plugin
- ✅ Commit: `.fractary/plugins/file/config.json`
- 🔐 Env vars: `${R2_ACCESS_KEY_ID}`, `${AWS_ACCESS_KEY_ID}`, etc.
- ⚠️ Google Drive: Never commit OAuth tokens (plugin should handle via OAuth flow)

### Codex Plugin
- ✅ Commit: `.fractary/plugins/codex/config/codex.json`
- 🔐 Env var: `$GITHUB_TOKEN` (for syncing to codex repo)

### FABER Plugin
- ✅ Commit: `.faber.config.toml`
- 🔐 No secrets (references other plugin configs)

### FABER Cloud Plugin
- ⚠️ Special case: Contains AWS profiles and sensitive infrastructure config
- See: `plugins/faber-cloud/docs/configuration-guide.md`

## Questions?

**Q: What if I need different config per environment (dev/staging/prod)?**
A: Use multiple config files and environment variables to select:
```json
{
  "environment": "${DEPLOYMENT_ENV:-dev}",
  "github": {
    "api_url": "${GITHUB_API_URL:-https://api.github.com}"
  }
}
```

**Q: What if a team member needs different settings?**
A: They shouldn't! The point of shared config is consistency. If there's a valid reason for per-developer variance, use environment variables to override specific values.

**Q: Can I override project config locally without committing?**
A: Yes, plugins check for configs in this order:
1. `.fractary/plugins/{plugin}/config.local.json` (gitignored, local overrides)
2. `.fractary/plugins/{plugin}/config.json` (committed, team settings)
3. Plugin defaults

Add to `.fractary/.gitignore`:
```
**/config.local.json
```

**Q: How do I share configs across multiple projects?**
A: Use the Codex plugin to sync common configuration patterns, or create a shared config template repository.

## See Also

- [Plugin Standards](standards/FRACTARY-PLUGIN-STANDARDS.md)
- [Security Best Practices](security/SECRET-MANAGEMENT.md) *(planned)*
- [FABER Configuration Guide](../plugins/faber/docs/configuration-guide.md) *(planned)*
- [Environment Setup Guide](setup/ENVIRONMENT-SETUP.md) *(planned)*
