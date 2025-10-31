# GitLab + Git Reference for Repo Manager (Future Implementation)

This document outlines the planned GitLab integration for the repo-manager skill.

## Status

**Not yet implemented.** This is a placeholder for future development.

## Planned Authentication

GitLab adapter will use Git CLI and GitLab CLI (`glab`).

### Planned Setup

```bash
# Install glab
brew install glab  # macOS
# or download from https://gitlab.com/gitlab-org/cli

# Authenticate
glab auth login

# Or set token
export GITLAB_TOKEN="glpat-..."
```

## Planned Configuration

```toml
[project]
source_control = "gitlab"

[systems.repo_config]
default_branch = "main"
gitlab_url = "https://gitlab.com"  # or self-hosted URL
```

## Planned Operations

Similar to GitHub adapter but using `glab` CLI:

### generate-branch-name.sh
Same logic as GitHub adapter.

### create-branch.sh
```bash
git branch <branch_name> <base_branch>
```

### create-commit.sh
Same format as GitHub adapter.

### push-branch.sh
```bash
git push origin <branch_name>
```

### create-pr.sh (Merge Request in GitLab)
```bash
glab mr create --source-branch <branch> --target-branch <base> --title "<title>" --description "<body>"
```

### merge-pr.sh
```bash
glab mr merge <number> --method <strategy>
```

**Merge Strategies in GitLab:**
- `merge`: Creates merge commit (like no-ff)
- `squash`: Squashes commits
- `rebase`: Rebases and fast-forwards

## References

- [GitLab CLI](https://gitlab.com/gitlab-org/cli)
- [GitLab API](https://docs.gitlab.com/ee/api/)

## Implementation Checklist

- [ ] Create scripts/gitlab/ directory
- [ ] Implement all 6 scripts matching GitHub adapter
- [ ] Add glab CLI integration
- [ ] Test with GitLab.com
- [ ] Test with self-hosted GitLab
- [ ] Document GitLab-specific features (e.g., merge request templates)
