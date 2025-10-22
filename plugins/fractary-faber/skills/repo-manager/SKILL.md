---
name: repo-manager
description: Source control operations across GitHub, GitLab, Bitbucket, etc.
---

# Repo Manager Skill

Provides source control operations for FABER workflows. This skill is platform-agnostic and supports multiple version control systems through adapters.

## Purpose

Handle all interactions with source control systems:
- Generate semantic branch names
- Create and switch branches
- Create commits with metadata
- Push changes to remote
- Create pull requests
- Merge branches safely

## Configuration

Reads `project.source_control` from configuration to determine which adapter to use:

```toml
[project]
source_control = "github"  # github | gitlab | bitbucket
```

## Operations

### Generate Branch Name

Create a semantic branch name from work metadata.

```bash
./scripts/<adapter>/generate-branch-name.sh <work_id> <issue_id> <work_type> <title>
```

**Parameters:**
- `work_id`: FABER work identifier
- `issue_id`: External issue ID
- `work_type`: Work classification (/bug, /feature, /chore, /patch)
- `title`: Work title (will be slugified)

**Returns:** Branch name string

**Example:**
```bash
branch_name=$(./scripts/github/generate-branch-name.sh abc12345 123 /feature "Add export feature")
# Returns: feat/123-add-export-feature
```

### Create Branch

Create a new git branch.

```bash
./scripts/<adapter>/create-branch.sh <branch_name> [base_branch]
```

**Parameters:**
- `branch_name`: Name of branch to create
- `base_branch` (optional): Base branch (defaults to main)

**Returns:** Success/failure indicator

**Example:**
```bash
./scripts/github/create-branch.sh feat/123-add-export main
```

### Create Commit

Create a semantic commit with FABER metadata.

```bash
./scripts/<adapter>/create-commit.sh <work_id> <author> <issue_id> <work_type> [message]
```

**Parameters:**
- `work_id`: FABER work identifier
- `author`: Commit author context (architect, implementor, tester, reviewer)
- `issue_id`: External issue ID
- `work_type`: Work classification
- `message` (optional): Custom commit message

**Returns:** Commit SHA

**Example:**
```bash
commit_sha=$(./scripts/github/create-commit.sh abc12345 implementor 123 /feature "Implement export feature")
```

### Push Branch

Push branch to remote repository.

```bash
./scripts/<adapter>/push-branch.sh <branch_name> [force] [set_upstream]
```

**Parameters:**
- `branch_name`: Branch to push
- `force` (optional): Use --force-with-lease (true/false, default: false)
- `set_upstream` (optional): Set upstream tracking (true/false, default: false)

**Returns:** Success/failure indicator

**Example:**
```bash
./scripts/github/push-branch.sh feat/123-add-export false true
```

### Create Pull Request

Create a pull request.

```bash
./scripts/<adapter>/create-pr.sh <work_id> <branch_name> <issue_id> <title> [body]
```

**Parameters:**
- `work_id`: FABER work identifier
- `branch_name`: Source branch
- `issue_id`: External issue ID
- `title`: PR title
- `body` (optional): PR description

**Returns:** PR URL

**Example:**
```bash
pr_url=$(./scripts/github/create-pr.sh abc12345 feat/123-add-export 123 "Add export feature" "Implements export functionality...")
```

### Merge Pull Request

Merge a pull request (or branch directly).

```bash
./scripts/<adapter>/merge-pr.sh <source_branch> <target_branch> <strategy> <work_id> <issue_id>
```

**Parameters:**
- `source_branch`: Branch to merge from
- `target_branch`: Branch to merge into
- `strategy`: Merge strategy (no-ff, squash, ff-only)
- `work_id`: FABER work identifier
- `issue_id`: External issue ID

**Returns:** Success/failure indicator

**Example:**
```bash
./scripts/github/merge-pr.sh feat/123-add-export main no-ff abc12345 123
```

## Adapters

### GitHub Adapter

Located in: `scripts/github/`

Uses Git CLI and GitHub CLI (`gh`) for operations.

**Requirements:**
- `git` CLI installed
- `gh` CLI installed
- `GITHUB_TOKEN` environment variable set
- Configured repository in `.faber.config.toml`

**See:** `docs/github-git.md` for details

### GitLab Adapter (Future)

Located in: `scripts/gitlab/`

Will use Git CLI and GitLab CLI (`glab`) for operations.

**See:** `docs/gitlab-git.md` for future implementation

### Bitbucket Adapter (Future)

Located in: `scripts/bitbucket/`

Will use Git CLI and Bitbucket API for operations.

## Error Handling

All scripts follow these conventions:
- Exit code 0: Success
- Exit code 1: General error
- Exit code 2: Invalid arguments
- Exit code 3: Configuration error
- Exit code 10: Branch already exists
- Exit code 11: Authentication error
- Exit code 12: Network error
- Exit code 13: Merge conflict

Error messages are written to stderr, results to stdout.

## Usage in Agents

Agents should invoke this skill for repository operations:

```bash
# From repo-manager agent
SCRIPT_DIR="$(dirname "$0")/../skills/repo-manager/scripts"

# Determine adapter from config
ADAPTER=$(get_repo_system_from_config)  # Returns: github, gitlab, bitbucket

# Generate branch name
branch_name=$("$SCRIPT_DIR/$ADAPTER/generate-branch-name.sh" "$work_id" "$issue_id" "$work_type" "$title")

# Create branch
"$SCRIPT_DIR/$ADAPTER/create-branch.sh" "$branch_name" "main"

# Create commit
commit_sha=$("$SCRIPT_DIR/$ADAPTER/create-commit.sh" "$work_id" "implementor" "$issue_id" "$work_type")

# Push branch
"$SCRIPT_DIR/$ADAPTER/push-branch.sh" "$branch_name" false true

# Create PR
pr_url=$("$SCRIPT_DIR/$ADAPTER/create-pr.sh" "$work_id" "$branch_name" "$issue_id" "$title" "$body")
```

## Dependencies

### All Adapters
- `bash` (4.0+)
- `git` CLI
- `jq` (for JSON parsing)

### GitHub Adapter
- `gh` CLI
- `GITHUB_TOKEN` environment variable

### GitLab Adapter (Future)
- `glab` CLI
- `GITLAB_TOKEN` environment variable

### Bitbucket Adapter (Future)
- `curl`
- `BITBUCKET_TOKEN` environment variable

## Script Locations

```
skills/repo-manager/
├── SKILL.md (this file)
├── scripts/
│   ├── github/
│   │   ├── generate-branch-name.sh
│   │   ├── create-branch.sh
│   │   ├── create-commit.sh
│   │   ├── push-branch.sh
│   │   ├── create-pr.sh
│   │   └── merge-pr.sh
│   ├── gitlab/
│   │   └── (future)
│   └── bitbucket/
│       └── (future)
└── docs/
    ├── github-git.md
    └── gitlab-git.md
```

## Branch Naming Convention

Branches follow semantic naming:

- **Feature**: `feat/123-description` or `feature/123-description`
- **Bug**: `bug/123-description` or `fix/123-description`
- **Chore**: `chore/123-description`
- **Patch**: `patch/123-description` or `hotfix/123-description`

Configurable via:
```toml
[defaults]
branch_naming = "feat/{issue_id}-{slug}"
```

Variables: `{work_id}`, `{issue_id}`, `{slug}`, `{work_type}`

## Commit Message Format

Commits follow semantic format with FABER metadata:

```
<type>: <description>

<optional body>

Refs: #<issue_id>
Work-ID: <work_id>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Testing

Test scripts independently:

```bash
# Test GitHub adapter
export GITHUB_TOKEN="ghp_..."
cd /path/to/repo
./scripts/github/generate-branch-name.sh abc12345 123 /feature "Test feature"
./scripts/github/create-branch.sh feat/123-test-feature main
./scripts/github/create-commit.sh abc12345 implementor 123 /feature "Test commit"
```

## Notes

- Scripts are stateless where possible
- All JSON output is minified (single line) for easy parsing
- Branch creation doesn't automatically switch to the branch
- Merge operations include safety checks for protected branches
- PR creation supports GitHub-flavored markdown in body
