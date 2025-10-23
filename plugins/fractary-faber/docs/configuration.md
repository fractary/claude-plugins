# FABER Configuration Guide

This guide covers all aspects of configuring FABER for your projects.

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration File Structure](#configuration-file-structure)
- [Configuration Sections](#configuration-sections)
- [Platform-Specific Configuration](#platform-specific-configuration)
- [Advanced Configuration](#advanced-configuration)
- [Environment Variables](#environment-variables)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Option 1: Auto-Detection (Recommended)

```bash
cd your-project
/faber init
```

This auto-detects your project settings and creates `.faber.config.toml`.

### Option 2: Use a Preset

```bash
# Copy a preset
cp plugins/fractary-faber/presets/software-guarded.toml .faber.config.toml

# Edit placeholders
vim .faber.config.toml

# Replace <...> values with your actual settings
```

### Option 3: Manual Configuration

```bash
# Copy example
cp plugins/fractary-faber/config/faber.example.toml .faber.config.toml

# Edit completely
vim .faber.config.toml
```

## Configuration File Structure

FABER uses TOML format for configuration:

```toml
[project]
# Project metadata

[defaults]
# Default workflow settings

[workflow]
# Workflow behavior

[safety]
# Safety rules

[systems.work_config]
# Work tracking system config

[systems.repo_config]
# Source control config

[systems.file_config]
# File storage config
```

## Configuration Sections

### [project]

Project metadata and system selection.

```toml
[project]
name = "my-app"              # Project name
org = "acme"                 # Organization/owner
repo = "my-app"              # Repository name
issue_system = "github"      # Work tracking: github, jira, linear
repo_system = "github"       # Source control: github, gitlab, bitbucket
file_system = "r2"           # File storage: r2, s3, local
```

**Fields**:

- **name** (required): Project name
  - Used in branch names and commits
  - Should match your actual project name
  - Example: `"my-app"`, `"backend-api"`

- **org** (required): Organization or username
  - GitHub organization or username
  - Used for repository URLs
  - Example: `"acme"`, `"john-doe"`

- **repo** (required): Repository name
  - Git repository name
  - Used for cloning and PR URLs
  - Example: `"my-app"`, `"backend-api"`

- **issue_system** (required): Work tracking system
  - Supported: `"github"`, `"jira"` (future), `"linear"` (future)
  - Determines which work-manager adapter to use
  - Default: `"github"`

- **repo_system** (required): Source control system
  - Supported: `"github"`, `"gitlab"` (future), `"bitbucket"` (future)
  - Determines which repo-manager adapter to use
  - Default: `"github"`

- **file_system** (required): File storage system
  - Supported: `"r2"`, `"s3"` (future), `"local"`
  - Determines which file-manager adapter to use
  - Default: `"local"`

### [defaults]

Default workflow settings.

```toml
[defaults]
work_domain = "engineering"  # Domain: engineering, design, writing, data
autonomy = "guarded"         # Autonomy: dry-run, assist, guarded, autonomous
```

**Fields**:

- **work_domain** (optional): Default domain for workflows
  - Supported: `"engineering"`, `"design"` (future), `"writing"` (future), `"data"` (future)
  - Can be overridden per workflow with `--domain` flag
  - Default: `"engineering"`

- **autonomy** (optional): Default autonomy level
  - Supported: `"dry-run"`, `"assist"`, `"guarded"`, `"autonomous"`
  - Can be overridden per workflow with `--autonomy` flag
  - Default: `"guarded"`
  - See [Autonomy Levels](#autonomy-levels) for details

### [workflow]

Workflow behavior configuration.

```toml
[workflow]
max_evaluate_retries = 3     # Max retries for Evaluate phase
auto_merge = false           # Auto-merge PRs after creation
```

**Fields**:

- **max_evaluate_retries** (optional): Maximum Evaluate → Build retries
  - Integer: 0-10
  - 0 = fail immediately on evaluation failure
  - 3 = retry up to 3 times (recommended)
  - Higher values = more resilient but slower
  - Default: `3`

- **auto_merge** (optional): Automatically merge PRs
  - Boolean: `true` or `false`
  - `true` = merge PR immediately after creation (⚠️ dangerous!)
  - `false` = create PR but require manual merge (recommended)
  - Can be overridden per workflow with `--auto-merge` flag
  - Default: `false`

### [safety]

Safety rules and protections.

```toml
[safety]
protected_paths = [
    ".git/",
    "node_modules/",
    ".env",
    "*.key",
    "*.pem"
]
require_confirmation = [
    "release"
]
```

**Fields**:

- **protected_paths** (optional): Paths that FABER cannot modify
  - Array of strings (glob patterns supported)
  - Prevents accidental modification of critical files
  - Recommended: `.git/`, `node_modules/`, secrets, credentials
  - Default: `[".git/", "node_modules/", ".env"]`

- **require_confirmation** (optional): Operations requiring confirmation
  - Array of strings: phase names or operation types
  - Supported: `"release"`, `"merge"`, `"deploy"`
  - Forces manual confirmation before operation
  - Default: `["release"]` for guarded mode

### [systems.work_config]

Work tracking system configuration.

#### GitHub

```toml
[systems.work_config]
# No configuration needed - uses gh CLI
```

GitHub work tracking uses the `gh` CLI, which handles authentication automatically.

**Setup**:
```bash
gh auth login
```

#### Jira (Future)

```toml
[systems.work_config]
jira_url = "https://company.atlassian.net"
jira_email = "user@company.com"
jira_api_token = "${JIRA_API_TOKEN}"  # Use environment variable
```

#### Linear (Future)

```toml
[systems.work_config]
linear_api_key = "${LINEAR_API_KEY}"  # Use environment variable
```

### [systems.repo_config]

Source control system configuration.

#### GitHub

```toml
[systems.repo_config]
default_branch = "main"      # Default branch name
```

**Fields**:

- **default_branch** (optional): Default branch name
  - String: branch name
  - Used as base for feature branches
  - Common: `"main"`, `"master"`, `"develop"`
  - Default: `"main"`

**Setup**:
```bash
# Git authentication via SSH or HTTPS
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# GitHub CLI for PRs
gh auth login
```

#### GitLab (Future)

```toml
[systems.repo_config]
gitlab_url = "https://gitlab.com"
gitlab_token = "${GITLAB_TOKEN}"
default_branch = "main"
```

### [systems.file_config]

File storage system configuration.

#### Local Filesystem

```toml
[systems.file_config]
storage_path = ".faber/storage"
```

**Fields**:

- **storage_path** (optional): Local storage directory
  - String: relative or absolute path
  - Directory for storing artifacts locally
  - Default: `".faber/storage"`

**Setup**: No setup required.

#### Cloudflare R2

```toml
[systems.file_config]
account_id = "your-account-id"
bucket_name = "faber-artifacts"
public_url = "https://faber-artifacts.your-account.r2.dev"
```

**Fields**:

- **account_id** (required): Cloudflare account ID
  - String: 32-character hex ID
  - Find in Cloudflare dashboard → R2 → Settings
  - Example: `"a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"`

- **bucket_name** (required): R2 bucket name
  - String: bucket name (must exist)
  - Create via Cloudflare dashboard or wrangler
  - Example: `"faber-artifacts"`

- **public_url** (optional): Public URL for bucket
  - String: full URL
  - Enable public access in R2 settings first
  - Format: `https://<bucket>.<account>.r2.dev`
  - If omitted, presigned URLs will be used

**Setup**:

1. Create R2 bucket:
   ```bash
   wrangler r2 bucket create faber-artifacts
   ```

2. Configure AWS CLI for R2:
   ```bash
   aws configure
   # Access Key ID: <R2_ACCESS_KEY_ID>
   # Secret Access Key: <R2_SECRET_ACCESS_KEY>
   # Region: auto
   ```

3. (Optional) Enable public access in R2 settings

#### AWS S3 (Future)

```toml
[systems.file_config]
s3_bucket = "faber-artifacts"
s3_region = "us-east-1"
s3_endpoint = ""  # Optional for S3-compatible services
```

## Autonomy Levels

FABER supports 4 autonomy levels:

### dry-run

**Behavior**: Simulates workflow without making changes

**When to use**:
- Testing FABER setup
- Understanding workflow behavior
- Debugging issues
- Validating configuration

**Configuration**:
```toml
[defaults]
autonomy = "dry-run"
```

**Override**:
```bash
/faber run 123 --autonomy dry-run
```

### assist

**Behavior**: Executes Frame → Architect → Build → Evaluate, stops before Release

**When to use**:
- Learning FABER workflows
- Cautious automation
- Want to review before creating PR

**Configuration**:
```toml
[defaults]
autonomy = "assist"
```

**Override**:
```bash
/faber run 123 --autonomy assist
```

### guarded (RECOMMENDED)

**Behavior**: Executes all 5 phases, pauses at Release for approval

**When to use**:
- Production workflows
- Standard development process
- Balance of automation and control
- Most common use case

**Configuration**:
```toml
[defaults]
autonomy = "guarded"
```

**Override**:
```bash
/faber run 123 --autonomy guarded
```

### autonomous

**Behavior**: Executes all phases without pausing, optionally auto-merges

**When to use**:
- Non-critical changes (docs, tests)
- Internal tools
- High confidence in setup
- Maximum automation

**Configuration**:
```toml
[defaults]
autonomy = "autonomous"

[workflow]
auto_merge = true  # Optional
```

**Override**:
```bash
/faber run 123 --autonomy autonomous --auto-merge
```

⚠️ **WARNING**: Use autonomous mode with caution in production!

## Platform-Specific Configuration

### GitHub + R2 (Recommended)

```toml
[project]
name = "my-app"
org = "acme"
repo = "my-app"
issue_system = "github"
repo_system = "github"
file_system = "r2"

[systems.file_config]
account_id = "your-account-id"
bucket_name = "faber-artifacts"
public_url = "https://faber-artifacts.your-account.r2.dev"
```

**Setup**:
```bash
gh auth login
aws configure  # For R2
```

### GitHub + Local Storage

```toml
[project]
name = "my-app"
org = "acme"
repo = "my-app"
issue_system = "github"
repo_system = "github"
file_system = "local"

[systems.file_config]
storage_path = ".faber/storage"
```

**Setup**:
```bash
gh auth login
```

### Jira + GitHub + S3 (Future)

```toml
[project]
name = "my-app"
org = "acme"
repo = "my-app"
issue_system = "jira"
repo_system = "github"
file_system = "s3"

[systems.work_config]
jira_url = "https://company.atlassian.net"
jira_email = "user@company.com"
jira_api_token = "${JIRA_API_TOKEN}"

[systems.file_config]
s3_bucket = "faber-artifacts"
s3_region = "us-east-1"
```

## Advanced Configuration

### Custom Branch Naming

Edit repo-manager skill scripts to customize branch naming:

```bash
# Edit: skills/repo-manager/scripts/github/generate-branch-name.sh
# Customize format:
BRANCH_NAME="feat/${ISSUE_ID}-${SLUG}"  # Default
BRANCH_NAME="feature/${WORK_TYPE}/${ISSUE_ID}"  # Custom
```

### Custom Status Cards

Edit faber-core status card template:

```bash
# Edit: skills/faber-core/scripts/status-card-post.sh
# Customize card format
```

### Multiple Environments

Maintain separate configs for different environments:

```bash
.faber.config.toml              # Active (development)
.faber.config.production.toml   # Production settings
.faber.config.staging.toml      # Staging settings
```

Switch environments:
```bash
cp .faber.config.production.toml .faber.config.toml
```

### Per-Domain Configuration

Different domains can have different settings:

```toml
[defaults]
work_domain = "engineering"

# Override for design workflows
[domains.design]
autonomy = "assist"
max_evaluate_retries = 1

# Override for data workflows
[domains.data]
autonomy = "autonomous"
auto_merge = false
```

Then:
```bash
/faber run 123 --domain design  # Uses design settings
```

## Environment Variables

FABER supports environment variables for sensitive data:

### In Configuration File

```toml
[systems.work_config]
jira_api_token = "${JIRA_API_TOKEN}"

[systems.file_config]
account_id = "${R2_ACCOUNT_ID}"
```

### Set Environment Variables

```bash
# In ~/.bashrc or ~/.zshrc
export JIRA_API_TOKEN="your-token"
export R2_ACCOUNT_ID="your-account-id"
export R2_ACCESS_KEY_ID="your-key"
export R2_SECRET_ACCESS_KEY="your-secret"
```

### Secure Storage

Use a secrets manager:

```bash
# Using 1Password CLI
export JIRA_API_TOKEN=$(op read "op://vault/jira/token")

# Using AWS Secrets Manager
export R2_ACCESS_KEY_ID=$(aws secretsmanager get-secret-value --secret-id r2-access-key --query SecretString --output text)
```

## Troubleshooting

### Configuration Not Found

**Error**: `Configuration file not found`

**Solution**:
```bash
/faber init  # Auto-detect
# OR
cp plugins/fractary-faber/presets/software-guarded.toml .faber.config.toml
```

### Invalid Configuration

**Error**: `Failed to load configuration`

**Solution**:
1. Check TOML syntax: https://toml.io/
2. Validate required fields
3. Check for typos in field names

```bash
# Test configuration
/faber status
```

### Authentication Failed

**Error**: `Authentication failed`

**GitHub Solution**:
```bash
gh auth login
gh auth status  # Verify
```

**R2 Solution**:
```bash
aws configure
aws s3 ls --endpoint-url https://<account-id>.r2.cloudflarestorage.com  # Test
```

### Platform Not Supported

**Error**: `Unsupported work tracking system: xyz`

**Solution**: Check supported platforms:
- Work tracking: `github` (jira, linear coming soon)
- Source control: `github` (gitlab, bitbucket coming soon)
- File storage: `r2`, `local` (s3 coming soon)

### Protected Path Modified

**Error**: `Cannot modify protected path`

**Solution**: Review `safety.protected_paths` in config:
```toml
[safety]
protected_paths = [
    ".git/",
    "node_modules/",
    # Remove or add as needed
]
```

## Validation

### Check Configuration

```bash
# Test loading configuration
/faber status

# Dry-run to validate
/faber run 123 --autonomy dry-run
```

### Validate Platforms

```bash
# Test GitHub
gh auth status
gh issue view 123

# Test R2
aws s3 ls --endpoint-url https://<account-id>.r2.cloudflarestorage.com

# Test Git
git status
git remote -v
```

## Best Practices

1. **Start with a preset** - Don't configure from scratch
2. **Use environment variables** for secrets - Never commit credentials
3. **Version control your config** - Commit `.faber.config.toml` (without secrets)
4. **Test with dry-run first** - Validate configuration safely
5. **Use guarded mode** for production - Balance automation and control
6. **Keep protected_paths comprehensive** - Prevent accidental modifications
7. **Document custom settings** - Add comments to your config
8. **Review regularly** - Update as project evolves

## See Also

- [Workflow Guide](workflow-guide.md) - How workflows execute
- [Architecture](architecture.md) - System design
- [Presets](../presets/README.md) - Pre-configured templates
- [Example Config](../config/faber.example.toml) - Complete reference
