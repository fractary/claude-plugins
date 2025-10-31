# Bitbucket Setup Guide

Setup guide for using the Fractary Repo Plugin with Bitbucket.

## ⚠️ Current Status

**Bitbucket support is currently in STUB phase**. The handler structure exists, but platform-specific scripts are not yet implemented.

**What exists**:
- ✅ Handler skill structure (`skills/handler-source-control-bitbucket/SKILL.md`)
- ✅ Configuration schema
- ✅ Operation interface defined

**What's needed**:
- ❌ Bitbucket-specific scripts (13 operations)
- ❌ Bitbucket API integration
- ❌ Testing and validation

## Contributing

We welcome contributions to implement Bitbucket support! This guide provides the foundation for implementation.

## Prerequisites (Future)

Once implemented, Bitbucket support will require:

- Git installed and configured
- Bitbucket account (bitbucket.org or Bitbucket Server)
- Access to repositories you want to manage
- Bitbucket credentials (app password)

## Installation (Future)

### 1. Create Bitbucket App Password

Unlike GitHub and GitLab which have CLIs, Bitbucket operations typically use the REST API directly with app passwords.

**Create App Password**:
1. Go to Bitbucket Settings: https://bitbucket.org/account/settings/app-passwords/
2. Click "Create app password"
3. Label: "Fractary Repo Plugin"
4. Select permissions:
   - ✅ Repositories: Read, Write, Admin
   - ✅ Pull requests: Read, Write
   - ✅ Webhooks: Read and write (optional)
5. Click "Create"
6. **Copy the password immediately** (you won't see it again)

### 2. Set Environment Variables

```bash
export BITBUCKET_USERNAME="your_username"
export BITBUCKET_TOKEN="your_app_password"
```

Add to your shell profile (`~/.bashrc`, `~/.zshrc`):
```bash
export BITBUCKET_USERNAME="your_username"
export BITBUCKET_TOKEN="your_app_password"
```

## Configuration (Future)

Once implemented, configure like this:

### Bitbucket Cloud

```json
{
  "handlers": {
    "source_control": {
      "active": "bitbucket",
      "bitbucket": {
        "username": "$BITBUCKET_USERNAME",
        "token": "$BITBUCKET_TOKEN",
        "workspace": "your-workspace-slug",
        "api_url": "https://api.bitbucket.org/2.0"
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

### Bitbucket Server (Self-Hosted)

```json
{
  "handlers": {
    "source_control": {
      "active": "bitbucket",
      "bitbucket": {
        "username": "$BITBUCKET_USERNAME",
        "token": "$BITBUCKET_TOKEN",
        "api_url": "https://bitbucket.your-company.com/rest/api/1.0"
      }
    }
  }
}
```

## Operations to Implement

The Bitbucket handler needs these 13 operations:

### Branch Operations
1. **generate-branch-name.sh** - Create semantic branch names
2. **create-branch.sh** - Create new Git branches
3. **delete-branch.sh** - Delete branches locally/remotely

### Commit Operations
4. **create-commit.sh** - Create semantic commits

### Push Operations
5. **push-branch.sh** - Push branches to remote

### Pull Request Operations
6. **create-pr.sh** - Create pull requests
7. **comment-pr.sh** - Add comments to pull requests
8. **review-pr.sh** - Submit pull request reviews
9. **merge-pr.sh** - Merge pull requests

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
# Bitbucket operation script
# Operation: operation-name

set -e

# Input validation
if [ $# -lt 1 ]; then
    echo "Usage: $0 <param1> [param2] ..." >&2
    exit 2
fi

# Load configuration
USERNAME="${BITBUCKET_USERNAME}"
TOKEN="${BITBUCKET_TOKEN}"
WORKSPACE="${BITBUCKET_WORKSPACE}"
API_URL="${BITBUCKET_API_URL:-https://api.bitbucket.org/2.0}"

# Authentication check
if [ -z "$USERNAME" ] || [ -z "$TOKEN" ]; then
    echo "Error: BITBUCKET_USERNAME and BITBUCKET_TOKEN must be set" >&2
    exit 11
fi

# Main operation using Bitbucket API
# ...

# Return structured JSON
echo '{"status": "success", "result": {...}}'
exit 0
```

### Bitbucket API Examples

**Authentication**:
```bash
# Basic auth with app password
curl -u "$USERNAME:$TOKEN" \
  "https://api.bitbucket.org/2.0/user"
```

**List branches**:
```bash
curl -u "$USERNAME:$TOKEN" \
  "https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO/refs/branches"
```

**Create pull request**:
```bash
curl -u "$USERNAME:$TOKEN" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "title": "feat: Add feature",
    "source": {
      "branch": {"name": "feat/123-test"}
    },
    "destination": {
      "branch": {"name": "main"}
    }
  }' \
  "https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO/pullrequests"
```

**Create branch** (via Git):
```bash
git checkout -b feat/123-test main
git push -u origin feat/123-test
```

**Merge pull request**:
```bash
curl -u "$USERNAME:$TOKEN" \
  -X POST \
  "https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO/pullrequests/1/merge"
```

## Key Differences from GitHub/GitLab

### Workspaces

Bitbucket uses "workspaces" (formerly "teams"):
```
workspace/repository
```

### Repository Slugs

Bitbucket uses repository slugs in API paths:
```
https://api.bitbucket.org/2.0/repositories/{workspace}/{repo_slug}
```

### API Versions

- **Bitbucket Cloud**: API 2.0 (https://api.bitbucket.org/2.0)
- **Bitbucket Server**: REST API 1.0 (different endpoint structure)

### No Official CLI

Unlike GitHub (`gh`) and GitLab (`glab`), Bitbucket doesn't have an official CLI. Use `curl` for API operations.

### Pull Request States

Bitbucket pull requests have states:
- OPEN
- MERGED
- DECLINED
- SUPERSEDED

## Testing (Once Implemented)

```bash
# 1. Navigate to Bitbucket repository
cd /path/to/your/repo

# 2. Test branch creation
/repo:branch create 1 "test setup"

# 3. Make changes and commit
echo "test" > test.txt
git add test.txt
/repo:commit "Test commit" --type test --work-id 1

# 4. Push
/repo:push --set-upstream

# 5. Create PR
/repo:pr create "feat: Test PR" --work-id 1

# 6. Clean up
git checkout main
/repo:branch delete test/1-test-setup
```

## How to Contribute

### Prerequisites
- Fork the repository
- Understand Bitbucket API: https://developer.atlassian.com/cloud/bitbucket/rest/
- Access to Bitbucket workspace for testing
- `curl` and `jq` installed

### Implementation Steps

1. **Clone and setup**:
```bash
git clone https://github.com/fractary/claude-plugins.git
cd claude-plugins/plugins/repo
```

2. **Create scripts directory**:
```bash
mkdir -p skills/handler-source-control-bitbucket/scripts
```

3. **Implement scripts** (start with these):
   - `generate-branch-name.sh`
   - `create-branch.sh`
   - `create-commit.sh`
   - `push-branch.sh`
   - `create-pr.sh`
   - `merge-pr.sh`

4. **Follow existing patterns**:
   - Study GitHub implementation in `skills/handler-source-control-github/scripts/`
   - Use same parameter format
   - Return same JSON structure
   - Follow same error codes

5. **Handle both Cloud and Server**:
   - Support Bitbucket Cloud (API 2.0)
   - Consider Bitbucket Server compatibility
   - Document differences

6. **Test thoroughly**:
   - Test on Bitbucket Cloud
   - Test on Bitbucket Server (if available)
   - Test all 13 operations
   - Verify error handling

7. **Submit PR**:
   - Create PR with implemented scripts
   - Include test results
   - Document Bitbucket-specific considerations

### Script Checklist

For each script, ensure:
- [ ] Input validation
- [ ] Authentication check (username + app password)
- [ ] Error handling with proper exit codes
- [ ] JSON output format
- [ ] Protected branch safety (where applicable)
- [ ] Comments and documentation
- [ ] Tested with real Bitbucket workspace
- [ ] Handles API pagination (where needed)
- [ ] Works with both Cloud and Server APIs

## Bitbucket-Specific Considerations

### Workspaces vs Teams

Bitbucket renamed "teams" to "workspaces". Scripts should use workspace terminology.

### Repository Access Levels

Bitbucket access levels:
- Read, Write, Admin

### Pull Request Reviewers

Bitbucket allows:
- Required reviewers
- Default reviewers
- Build status checks

### Branch Permissions

Bitbucket branch permissions:
- Branch restrictions
- Merge checks
- Required approvals

### API Pagination

Bitbucket API uses pagination:
```json
{
  "values": [...],
  "next": "https://api.bitbucket.org/2.0/..."
}
```

Scripts must handle paginated responses for listing operations.

### Rate Limiting

Bitbucket Cloud rate limits:
- 1000 requests per hour per user
- 60 requests per hour for unauthenticated requests

Implement retry logic with exponential backoff.

## Resources

- **Bitbucket Cloud API**: https://developer.atlassian.com/cloud/bitbucket/rest/
- **Bitbucket Server API**: https://developer.atlassian.com/server/bitbucket/rest/
- **App Passwords**: https://support.atlassian.com/bitbucket-cloud/docs/app-passwords/
- **Pull Requests**: https://support.atlassian.com/bitbucket-cloud/docs/pull-requests/
- **Branch Permissions**: https://support.atlassian.com/bitbucket-cloud/docs/branch-permissions/

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

## API Examples Library

### Get Repository Info
```bash
curl -u "$USERNAME:$TOKEN" \
  "https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO"
```

### List Pull Requests
```bash
curl -u "$USERNAME:$TOKEN" \
  "https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO/pullrequests?state=OPEN"
```

### Add PR Comment
```bash
curl -u "$USERNAME:$TOKEN" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"content": {"raw": "Great work!"}}' \
  "https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO/pullrequests/1/comments"
```

### Get Branch Info
```bash
curl -u "$USERNAME:$TOKEN" \
  "https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO/refs/branches/main"
```

### Delete Branch
```bash
curl -u "$USERNAME:$TOKEN" \
  -X DELETE \
  "https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO/refs/branches/feat%2F123-test"
```

Note: Branch names in URLs must be URL-encoded.

## Contact

- **Issues**: https://github.com/fractary/claude-plugins/issues
- **Discussions**: https://github.com/fractary/claude-plugins/discussions
- **Bitbucket Support**: https://support.atlassian.com/bitbucket-cloud/
