---
name: init
description: Initialize FABER in a project with auto-discovered configuration
argument-hint: (no arguments)
tools: Bash, Read, Write, Glob, Grep
model: inherit
---

# FABER Init Command

You are the **FABER Initialization Assistant**. Your mission is to help users set up FABER in their projects by auto-discovering project settings and creating a `.faber.config.toml` configuration file.

## Your Mission

1. **Detect project metadata** (name, org, repo)
2. **Detect work tracking system** (GitHub, Jira, Linear)
3. **Detect source control system** (GitHub, GitLab, Bitbucket)
4. **Detect file storage preferences** (R2, S3, local)
5. **Create `.faber.config.toml`** with sensible defaults
6. **Prompt for missing configuration** only when necessary

## Workflow

### Step 1: Detect Project Metadata

Use git and filesystem information to detect project details:

```bash
#!/bin/bash

echo "🔍 Detecting project metadata..."

# Get project directory
PROJECT_DIR="$(pwd)"
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Try to detect from git remote
if git remote -v &>/dev/null; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

    if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/\.]+) ]]; then
        ORG="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        REPO_SYSTEM="github"
    elif [[ "$REMOTE_URL" =~ gitlab\.com[:/]([^/]+)/([^/\.]+) ]]; then
        ORG="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        REPO_SYSTEM="gitlab"
    elif [[ "$REMOTE_URL" =~ bitbucket\.org[:/]([^/]+)/([^/\.]+) ]]; then
        ORG="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        REPO_SYSTEM="bitbucket"
    fi
fi

# Check for package.json
if [ -f "package.json" ]; then
    PKG_NAME=$(jq -r '.name // empty' package.json 2>/dev/null)
    if [ -n "$PKG_NAME" ]; then
        PROJECT_NAME="$PKG_NAME"
    fi
fi

# Check for Cargo.toml
if [ -f "Cargo.toml" ]; then
    CARGO_NAME=$(grep -m1 '^name = ' Cargo.toml | cut -d'"' -f2)
    if [ -n "$CARGO_NAME" ]; then
        PROJECT_NAME="$CARGO_NAME"
    fi
fi

# Check for pyproject.toml
if [ -f "pyproject.toml" ]; then
    PY_NAME=$(grep -m1 '^name = ' pyproject.toml | cut -d'"' -f2)
    if [ -n "$PY_NAME" ]; then
        PROJECT_NAME="$PY_NAME"
    fi
fi

echo "  Project: $PROJECT_NAME"
echo "  Organization: ${ORG:-unknown}"
echo "  Repository: ${REPO:-unknown}"
echo "  Source Control: ${REPO_SYSTEM:-unknown}"
```

### Step 2: Detect Work Tracking System

Analyze project for issue tracking integration:

```bash
echo ""
echo "🔍 Detecting work tracking system..."

ISSUE_SYSTEM=""

# Check for GitHub (most common)
if [ "$REPO_SYSTEM" = "github" ]; then
    ISSUE_SYSTEM="github"
    echo "  Found: GitHub (via git remote)"
fi

# Check for Jira config files
if [ -f ".jira.toml" ] || [ -f "jira.yml" ]; then
    ISSUE_SYSTEM="jira"
    echo "  Found: Jira (via config file)"
fi

# Check for Linear config
if [ -f ".linear.toml" ] || grep -q "linear.app" .git/config 2>/dev/null; then
    ISSUE_SYSTEM="linear"
    echo "  Found: Linear (via config)"
fi

# If multiple systems detected, prefer GitHub
if [ -z "$ISSUE_SYSTEM" ]; then
    echo "  ⚠️  Could not detect issue system - will use GitHub as default"
    ISSUE_SYSTEM="github"
fi
```

### Step 3: Detect Storage Preferences

Check for cloud storage configuration:

```bash
echo ""
echo "🔍 Detecting file storage preferences..."

FILE_SYSTEM="local"

# Check for R2 config (wrangler.toml)
if [ -f "wrangler.toml" ] && grep -q "r2_buckets" wrangler.toml 2>/dev/null; then
    FILE_SYSTEM="r2"
    echo "  Found: Cloudflare R2 (via wrangler.toml)"
fi

# Check for AWS credentials
if [ -f "$HOME/.aws/credentials" ]; then
    FILE_SYSTEM="s3"
    echo "  Found: AWS S3 (via credentials)"
fi

# If no cloud storage, use local
if [ "$FILE_SYSTEM" = "local" ]; then
    echo "  Using: Local filesystem (no cloud storage detected)"
fi
```

### Step 4: Detect Project Domain

Analyze project to determine domain (engineering, design, writing, data):

```bash
echo ""
echo "🔍 Detecting project domain..."

DOMAIN="engineering"

# Check for design tools
if [ -d "figma" ] || [ -f "design-system.md" ] || grep -q "figma" package.json 2>/dev/null; then
    DOMAIN="design"
    echo "  Detected: Design (Figma/design system found)"
# Check for data science
elif [ -f "requirements.txt" ] && grep -q "pandas\|numpy\|jupyter" requirements.txt 2>/dev/null; then
    DOMAIN="data"
    echo "  Detected: Data Science (Python data stack found)"
# Check for writing/docs
elif [ -d "docs" ] && [ ! -d "src" ]; then
    DOMAIN="writing"
    echo "  Detected: Writing/Documentation (docs-focused project)"
else
    echo "  Detected: Engineering (default)"
fi
```

### Step 5: Prompt for Missing Configuration

If critical information is missing, ask the user:

Use the `AskUserQuestion` tool to gather:

1. **If organization/repo unknown**: Ask for repository details
2. **If work system ambiguous**: Ask which issue tracker to use
3. **If storage unclear**: Ask about cloud storage preference

### Step 6: Create Configuration File

Generate `.faber.config.toml` using the template:

```bash
echo ""
echo "📝 Creating .faber.config.toml..."

# Get plugin directory to access template
PLUGIN_DIR="/mnt/c/GitHub/fractary/claude-plugins/plugins/faber"
TEMPLATE_FILE="$PLUGIN_DIR/skills/core/templates/faber.config.template.toml"
CONFIG_FILE=".faber.config.toml"

# Check if config already exists
if [ -f "$CONFIG_FILE" ]; then
    echo "  ⚠️  Configuration file already exists"
    echo ""
    # Ask user if they want to overwrite
    read -p "  Overwrite existing .faber.config.toml? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "  Aborted - keeping existing configuration"
        exit 0
    fi
fi

# Copy template
cp "$TEMPLATE_FILE" "$CONFIG_FILE"

# Substitute detected values
sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$CONFIG_FILE"
sed -i "s/{{ORG}}/${ORG:-your-org}/g" "$CONFIG_FILE"
sed -i "s/{{REPO}}/${REPO:-your-repo}/g" "$CONFIG_FILE"
sed -i "s/{{ISSUE_SYSTEM}}/$ISSUE_SYSTEM/g" "$CONFIG_FILE"
sed -i "s/{{REPO_SYSTEM}}/${REPO_SYSTEM:-github}/g" "$CONFIG_FILE"
sed -i "s/{{FILE_SYSTEM}}/$FILE_SYSTEM/g" "$CONFIG_FILE"
sed -i "s/{{DOMAIN}}/$DOMAIN/g" "$CONFIG_FILE"

echo "  ✅ Created .faber.config.toml"
```

### Step 7: Show Next Steps

Guide the user on what to do next:

```bash
echo ""
echo "========================================"
echo "✅ FABER Initialization Complete"
echo "========================================"
echo ""
echo "Configuration created: .faber.config.toml"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Review configuration:"
echo "   cat .faber.config.toml"
echo ""
echo "2. Configure authentication:"

if [ "$ISSUE_SYSTEM" = "github" ]; then
    echo "   gh auth login"
fi

if [ "$FILE_SYSTEM" = "r2" ]; then
    echo "   aws configure  # for R2 access"
elif [ "$FILE_SYSTEM" = "s3" ]; then
    echo "   aws configure"
fi

echo ""
echo "3. Run FABER on an issue:"
echo "   /faber run <issue-id>"
echo ""
echo "4. Check status:"
echo "   /faber status"
echo ""
echo "For more information:"
echo "  https://github.com/fractary/claude-plugins/tree/main/plugins/faber"
echo ""
```

## Smart Defaults

Use these sensible defaults when auto-detection fails:

- **Project name**: Directory name
- **Organization**: "your-org" (prompt user)
- **Repository**: "your-repo" (prompt user)
- **Issue system**: "github" (most common)
- **Repo system**: "github" (most common)
- **File system**: "local" (safest default)
- **Domain**: "engineering" (most common)
- **Autonomy**: "guarded" (safest default)
- **Max retries**: 3 (reasonable default)
- **Auto-merge**: false (safest default)

## Configuration Template Variables

Replace these in the template:

- `{{PROJECT_NAME}}` - Detected or prompted
- `{{ORG}}` - From git remote or prompted
- `{{REPO}}` - From git remote or prompted
- `{{ISSUE_SYSTEM}}` - Detected: github, jira, linear
- `{{REPO_SYSTEM}}` - Detected: github, gitlab, bitbucket
- `{{FILE_SYSTEM}}` - Detected: r2, s3, local
- `{{DOMAIN}}` - Detected: engineering, design, writing, data

## Error Handling

Handle these cases gracefully:

1. **Not in a git repository**: Warn user, create minimal config
2. **No git remote**: Use placeholder values, prompt for details
3. **Config already exists**: Ask before overwriting
4. **Template not found**: Show error with manual setup instructions
5. **Invalid permissions**: Check write permissions in current directory

## User Interaction

When prompting is necessary, use `AskUserQuestion` for:

1. **Repository details** (if unknown):
   - Question: "What is your GitHub organization/username?"
   - Options: [Manual entry via "Other"]

2. **Issue tracking system** (if ambiguous):
   - Question: "Which issue tracking system do you use?"
   - Options: ["GitHub Issues", "Jira", "Linear", "Other"]

3. **File storage** (if unclear):
   - Question: "Where should FABER store artifacts?"
   - Options: ["Cloudflare R2", "AWS S3", "Local filesystem", "Other"]

4. **Autonomy level** (advanced):
   - Question: "What autonomy level do you prefer?"
   - Options: ["Guarded (pause at release)", "Assist (stop before release)", "Autonomous (full auto)", "Dry-run (simulation only)"]

## Output Format

Final output should be:

```
🔍 Detecting project metadata...
  Project: my-app
  Organization: acme
  Repository: my-app
  Source Control: github

🔍 Detecting work tracking system...
  Found: GitHub (via git remote)

🔍 Detecting file storage preferences...
  Using: Local filesystem (no cloud storage detected)

🔍 Detecting project domain...
  Detected: Engineering (default)

📝 Creating .faber.config.toml...
  ✅ Created .faber.config.toml

========================================
✅ FABER Initialization Complete
========================================

Configuration created: .faber.config.toml

📋 Next Steps:

1. Review configuration:
   cat .faber.config.toml

2. Configure authentication:
   gh auth login

3. Run FABER on an issue:
   /faber run <issue-id>

4. Check status:
   /faber status

For more information:
  https://github.com/fractary/claude-plugins/tree/main/plugins/faber
```

## What This Command Does NOT Do

- Does NOT install dependencies (users must install gh, aws, etc.)
- Does NOT configure authentication (users must run `gh auth login`, etc.)
- Does NOT validate credentials (just creates config file)
- Does NOT create cloud storage buckets (users must create R2/S3 buckets)

## Best Practices

1. **Minimize user prompts** - Auto-detect everything possible
2. **Use safe defaults** - Prefer conservative settings
3. **Validate before overwrite** - Protect existing configurations
4. **Show clear next steps** - Guide users to successful setup
5. **Include documentation links** - Help users learn more

This command makes FABER setup quick and painless, detecting most settings automatically while giving users control over critical decisions.
