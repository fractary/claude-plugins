# GitHub API Reference for Work Manager

This document describes the GitHub integration for the work-manager skill.

## Authentication

The GitHub adapter uses the GitHub CLI (`gh`) which handles authentication.

### Setup

1. Install GitHub CLI:
   ```bash
   # macOS
   brew install gh

   # Linux
   curl -sS https://webi.sh/gh | sh

   # Windows
   winget install GitHub.cli
   ```

2. Authenticate:
   ```bash
   gh auth login
   ```

3. Or set token environment variable:
   ```bash
   export GITHUB_TOKEN="ghp_..."
   ```

## Configuration

In `.faber.config.toml`:

```toml
[project]
issue_system = "github"

[systems.work_config]
repo = "owner/repo"
api_url = "https://api.github.com"

# Classification label mappings
labels_feature = ["feature", "enhancement"]
labels_bug = ["bug", "fix"]
labels_chore = ["chore", "maintenance"]
labels_patch = ["patch", "hotfix"]
```

## Operations

### fetch-issue.sh

Fetches issue details using `gh issue view`.

**GitHub CLI Command:**
```bash
gh issue view <number> --json number,title,body,state,labels,author,createdAt,updatedAt,url
```

**Output Format:**
```json
{
  "number": 123,
  "title": "Add export feature",
  "body": "Description of the feature...",
  "state": "OPEN",
  "labels": "feature,priority-high",
  "author": {
    "login": "username"
  },
  "createdAt": "2025-01-22T10:00:00Z",
  "updatedAt": "2025-01-22T10:00:00Z",
  "url": "https://github.com/owner/repo/issues/123"
}
```

### create-comment.sh

Posts a comment to an issue using `gh issue comment`.

**GitHub CLI Command:**
```bash
gh issue comment <number> --body "<message>"
```

**Comment Format:**
The script automatically appends FABER metadata:

```markdown
<user message>

---
_FABER Work ID: `abc12345` | Author: frame_
```

### set-label.sh

Adds or removes labels using `gh issue edit`.

**GitHub CLI Commands:**
```bash
# Add label
gh issue edit <number> --add-label "<label>"

# Remove label
gh issue edit <number> --remove-label "<label>"
```

### classify-issue.sh

Classifies issues based on labels and content.

**Classification Rules:**

1. **Bug** (`/bug`):
   - Labels: bug, fix, error, crash, issue
   - Title/Body: [bug], bug:, fix:

2. **Patch** (`/patch`):
   - Labels: hotfix, patch, critical, urgent
   - Title/Body: [hotfix], hotfix:, patch:

3. **Chore** (`/chore`):
   - Labels: chore, maintenance, refactor, cleanup, debt
   - Title/Body: [chore], chore:, refactor:

4. **Feature** (`/feature`):
   - Labels: feature, enhancement, improvement
   - Title/Body: [feature], feat:, feature:
   - **Default** if no match found

## Error Codes

- `0`: Success
- `1`: General error
- `2`: Invalid arguments
- `3`: Configuration error (gh CLI not found)
- `10`: Issue not found
- `11`: Authentication error
- `12`: Network error

## GitHub CLI Reference

- **View issue**: `gh issue view <number> --json <fields>`
- **Comment**: `gh issue comment <number> --body "<text>"`
- **Edit**: `gh issue edit <number> [flags]`
- **List issues**: `gh issue list`
- **Close issue**: `gh issue close <number>`

Full documentation: https://cli.github.com/manual/gh_issue

## Permissions Required

The GitHub token needs these permissions:
- `repo` (for private repositories)
- `public_repo` (for public repositories)

## Rate Limits

GitHub API rate limits:
- **Authenticated**: 5,000 requests per hour
- **Unauthenticated**: 60 requests per hour

The `gh` CLI handles rate limiting automatically.

## Best Practices

1. **Always authenticate** with a token for higher rate limits
2. **Use issue numbers** not URLs for better compatibility
3. **Format comments with markdown** for better readability
4. **Add labels consistently** to improve classification
5. **Check return codes** to handle errors gracefully

## Troubleshooting

### Issue: "gh: command not found"
**Solution**: Install GitHub CLI

### Issue: "authentication failed"
**Solution**: Run `gh auth login` or set `GITHUB_TOKEN`

### Issue: "Could not resolve to an Issue"
**Solution**: Verify issue number and repository

### Issue: Rate limit exceeded
**Solution**: Wait for rate limit reset or use authenticated requests

## Examples

```bash
# Fetch issue
./scripts/github/fetch-issue.sh 123

# Post comment
./scripts/github/create-comment.sh 123 abc12345 frame "Starting Frame phase"

# Add label
./scripts/github/set-label.sh 123 "faber-in-progress" add

# Classify issue
issue_json=$(./scripts/github/fetch-issue.sh 123)
work_type=$(./scripts/github/classify-issue.sh "$issue_json")
echo "Work type: $work_type"
```
