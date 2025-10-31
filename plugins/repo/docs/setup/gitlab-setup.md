# GitLab Setup Guide

Setup guide for using the Fractary Repo Plugin with GitLab.

## ⚠️ Current Status

**GitLab support is currently in STUB phase**. The handler structure exists, but platform-specific scripts are not yet implemented.

**What exists**:
- ✅ Handler skill structure (`skills/handler-source-control-gitlab/SKILL.md`)
- ✅ Configuration schema
- ✅ Operation interface defined

**What's needed**:
- ❌ GitLab-specific scripts (13 operations)
- ❌ `glab` CLI integration
- ❌ GitLab API implementation
- ❌ Testing and validation

## Contributing

We welcome contributions to implement GitLab support! This guide provides the foundation for implementation.

## Prerequisites (Future)

Once implemented, GitLab support will require:

- Git installed and configured
- GitLab account (gitlab.com or self-hosted)
- Access to repositories you want to manage
- GitLab CLI (`glab`) installed

## Installation (Future)

### 1. Install GitLab CLI

**macOS**:
```bash
brew install glab
```

**Linux**:
```bash
# Binary installation
curl -s https://raw.githubusercontent.com/profclems/glab/trunk/scripts/install.sh | sh

# Or via package manager (Debian/Ubuntu)
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E0B4FD07F0F9B6B9
sudo apt-add-repository 'deb https://cli.github.com/packages stable main'
sudo apt update
sudo apt install glab
```

**Windows**:
```bash
scoop install glab
```

### 2. Authenticate with GitLab

```bash
glab auth login
```

### 3. Create GitLab Personal Access Token

1. Go to GitLab Settings: https://gitlab.com/-/profile/personal_access_tokens
2. Click "Add new token"
3. Give it a name: "Fractary Repo Plugin"
4. Select scopes:
   - ✅ `api` (Full API access)
   - ✅ `write_repository` (Write repository data)
   - ✅ `read_repository` (Read repository data)
5. Click "Create personal access token"
6. **Copy the token immediately**

### 4. Set Environment Variable

```bash
export GITLAB_TOKEN="your_token_here"
```

## Configuration (Future)

Once implemented, configure like this:

### GitLab.com

```json
{
  "handlers": {
    "source_control": {
      "active": "gitlab",
      "gitlab": {
        "token": "$GITLAB_TOKEN",
        "api_url": "https://gitlab.com/api/v4"
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
    "merge_strategy": "no-ff"
  }
}
```

### Self-Hosted GitLab

```json
{
  "handlers": {
    "source_control": {
      "active": "gitlab",
      "gitlab": {
        "token": "$GITLAB_TOKEN",
        "api_url": "https://gitlab.your-company.com/api/v4"
      }
    }
  }
}
```

## Operations to Implement

The GitLab handler needs these 13 operations:

### Branch Operations
1. **generate-branch-name.sh** - Create semantic branch names
2. **create-branch.sh** - Create new Git branches
3. **delete-branch.sh** - Delete branches locally/remotely

### Commit Operations
4. **create-commit.sh** - Create semantic commits

### Push Operations
5. **push-branch.sh** - Push branches to remote

### Merge Request Operations
6. **create-pr.sh** - Create merge requests (GitLab's version of PRs)
7. **comment-pr.sh** - Add comments to merge requests
8. **review-pr.sh** - Submit merge request reviews
9. **merge-pr.sh** - Merge merge requests

### Tag Operations
10. **create-tag.sh** - Create version tags
11. **push-tag.sh** - Push tags to remote

### Cleanup Operations
12. **list-stale-branches.sh** - Find stale branches

## Implementation Guide

### Script Template

Each script should follow this pattern:

```bash
#!/bin/bash
# GitLab operation script
# Operation: operation-name

set -e

# Input validation
if [ $# -lt 1 ]; then
    echo "Usage: $0 <param1> [param2] ..." >&2
    exit 2
fi

# Load configuration
CONFIG_TOKEN="${GITLAB_TOKEN}"
API_URL="${GITLAB_API_URL:-https://gitlab.com/api/v4}"

# Authentication check
if [ -z "$CONFIG_TOKEN" ]; then
    echo "Error: GITLAB_TOKEN not set" >&2
    exit 11
fi

# Main operation using glab CLI or API
# ...

# Return structured JSON
echo '{"status": "success", "result": {...}}'
exit 0
```

### GitLab API Examples

**List branches**:
```bash
curl --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://gitlab.com/api/v4/projects/:id/repository/branches"
```

**Create merge request**:
```bash
curl --request POST --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://gitlab.com/api/v4/projects/:id/merge_requests" \
  --data "source_branch=feat/123-test&target_branch=main&title=Test MR"
```

**Create branch**:
```bash
curl --request POST --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://gitlab.com/api/v4/projects/:id/repository/branches" \
  --data "branch=feat/123-test&ref=main"
```

### Using glab CLI

The `glab` CLI provides easier GitLab operations:

```bash
# Create merge request
glab mr create --source-branch feat/123 --target-branch main \
  --title "feat: Add feature" --description "..."

# List merge requests
glab mr list

# Merge merge request
glab mr merge 123

# Create branch
git checkout -b feat/123-test
git push -u origin feat/123-test
```

## Key Differences from GitHub

### Merge Requests vs Pull Requests

GitLab uses "Merge Requests" (MRs) instead of "Pull Requests" (PRs), but the concept is the same.

**Terminology mapping**:
- GitHub PR = GitLab MR
- create-pr.sh → creates merge request
- merge-pr.sh → merges merge request

### GitLab-Specific Features

- **Approvals**: More granular approval rules
- **Squash commits**: Option during merge
- **Remove source branch**: Auto-delete after merge
- **Pipelines**: GitLab CI/CD integration
- **Protected branches**: Branch protection rules

## Testing (Once Implemented)

```bash
# 1. Navigate to GitLab repository
cd /path/to/your/repo

# 2. Test branch creation
/repo:branch create 1 "test setup"

# 3. Make changes and commit
echo "test" > test.txt
git add test.txt
/repo:commit "Test commit" --type test --work-id 1

# 4. Push
/repo:push --set-upstream

# 5. Create MR
/repo:pr create "feat: Test MR" --work-id 1

# 6. Clean up
git checkout main
/repo:branch delete test/1-test-setup
```

## How to Contribute

### Prerequisites
- Fork the repository
- Understand GitLab API: https://docs.gitlab.com/ee/api/
- Install `glab`: https://gitlab.com/gitlab-org/cli
- Access to GitLab instance for testing

### Implementation Steps

1. **Clone and setup**:
```bash
git clone https://github.com/fractary/claude-plugins.git
cd claude-plugins/plugins/repo
```

2. **Create scripts directory**:
```bash
mkdir -p skills/handler-source-control-gitlab/scripts
```

3. **Implement scripts** (start with these):
   - `generate-branch-name.sh`
   - `create-branch.sh`
   - `create-commit.sh`
   - `push-branch.sh`
   - `create-pr.sh` (for merge requests)
   - `merge-pr.sh`

4. **Follow existing patterns**:
   - Study GitHub implementation in `skills/handler-source-control-github/scripts/`
   - Use same parameter format
   - Return same JSON structure
   - Follow same error codes

5. **Test thoroughly**:
   - Test on GitLab.com
   - Test on self-hosted GitLab (if available)
   - Test all 13 operations
   - Verify error handling

6. **Submit PR**:
   - Create PR with implemented scripts
   - Include test results
   - Document any GitLab-specific considerations

### Script Checklist

For each script, ensure:
- [ ] Input validation
- [ ] Authentication check
- [ ] Error handling with proper exit codes
- [ ] JSON output format
- [ ] Protected branch safety (where applicable)
- [ ] Comments and documentation
- [ ] Tested with real GitLab instance

## GitLab-Specific Considerations

### Nested Groups

GitLab supports nested groups (subgroups):
```
group/subgroup/project
```

Ensure scripts handle project paths correctly.

### Project IDs

GitLab uses numeric project IDs for API calls. Scripts should:
1. Get project ID from current repository
2. Or accept project path and resolve to ID

### CI/CD Integration

GitLab has built-in CI/CD. Consider:
- Pipeline status checks before merge
- Required pipeline success
- Manual approval gates

### Permissions

GitLab permission model:
- Guest, Reporter, Developer, Maintainer, Owner
- Scripts should handle permission errors gracefully

## Resources

- **GitLab CLI**: https://gitlab.com/gitlab-org/cli
- **GitLab API**: https://docs.gitlab.com/ee/api/
- **Personal Access Tokens**: https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html
- **Merge Requests**: https://docs.gitlab.com/ee/user/project/merge_requests/
- **Protected Branches**: https://docs.gitlab.com/ee/user/project/protected_branches.html

## Status Updates

Track implementation progress:

| Operation | Status | Contributor | PR |
|-----------|--------|-------------|-----|
| generate-branch-name | 🚧 | - | - |
| create-branch | 🚧 | - | - |
| delete-branch | 🚧 | - | - |
| create-commit | 🚧 | - | - |
| push-branch | 🚧 | - | - |
| create-pr | 🚧 | - | - |
| comment-pr | 🚧 | - | - |
| review-pr | 🚧 | - | - |
| merge-pr | 🚧 | - | - |
| create-tag | 🚧 | - | - |
| push-tag | 🚧 | - | - |
| list-stale-branches | 🚧 | - | - |

**Want to contribute?** Pick an operation and open a PR!

## Contact

- **Issues**: https://github.com/fractary/claude-plugins/issues
- **Discussions**: https://github.com/fractary/claude-plugins/discussions
- **Email**: support@fractary.io (if exists)
