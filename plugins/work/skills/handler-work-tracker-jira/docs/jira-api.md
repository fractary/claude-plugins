# Jira API Reference for Work Manager (Future Implementation)

This document outlines the planned Jira integration for the work-manager skill.

## Status

**Not yet implemented.** This is a placeholder for future development.

## Planned Authentication

Jira adapter will use REST API with token authentication.

### Planned Setup

```bash
export JIRA_TOKEN="your-api-token"
export JIRA_EMAIL="user@example.com"
```

## Planned Configuration

```toml
[project]
issue_system = "jira"

[systems.work_config]
jira_url = "https://your-domain.atlassian.net"
jira_project = "PROJ"
```

## Planned Operations

### fetch-issue.sh

Will fetch issue details using Jira REST API:
```bash
curl -X GET "https://${JIRA_URL}/rest/api/3/issue/${ISSUE_KEY}" \
  -u "${JIRA_EMAIL}:${JIRA_TOKEN}" \
  -H "Accept: application/json"
```

### create-comment.sh

Will post comments using:
```bash
curl -X POST "https://${JIRA_URL}/rest/api/3/issue/${ISSUE_KEY}/comment" \
  -u "${JIRA_EMAIL}:${JIRA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"body": {"type": "doc", "version": 1, "content": [...]}}'
```

### classify-issue.sh

Will classify based on:
- Issue type (Bug, Story, Task, Epic)
- Labels
- Custom fields

## References

- [Jira Cloud REST API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)
- [Jira API Authentication](https://developer.atlassian.com/cloud/jira/platform/basic-auth-for-rest-apis/)

## Implementation Checklist

- [ ] Create scripts/jira/ directory
- [ ] Implement fetch-issue.sh with Jira REST API
- [ ] Implement create-comment.sh with Jira comments API
- [ ] Implement set-label.sh
- [ ] Implement classify-issue.sh with Jira issue types
- [ ] Add authentication handling
- [ ] Add error handling for Jira-specific errors
- [ ] Test with Jira Cloud
- [ ] Test with Jira Server
