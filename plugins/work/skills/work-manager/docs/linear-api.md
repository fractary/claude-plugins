# Linear API Reference for Work Manager (Future Implementation)

This document outlines the planned Linear integration for the work-manager skill.

## Status

**Not yet implemented.** This is a placeholder for future development.

## Planned Authentication

Linear adapter will use GraphQL API with API key authentication.

### Planned Setup

```bash
export LINEAR_API_KEY="lin_api_..."
```

## Planned Configuration

```toml
[project]
issue_system = "linear"

[systems.work_config]
linear_team = "your-team"
linear_workspace = "your-workspace"
```

## Planned Operations

### fetch-issue.sh

Will fetch issue details using Linear GraphQL API:
```graphql
query GetIssue($id: String!) {
  issue(id: $id) {
    id
    title
    description
    state {
      name
    }
    labels {
      nodes {
        name
      }
    }
    createdAt
    updatedAt
    url
  }
}
```

### create-comment.sh

Will create comments using:
```graphql
mutation CreateComment($issueId: String!, $body: String!) {
  commentCreate(input: {
    issueId: $issueId
    body: $body
  }) {
    comment {
      id
    }
  }
}
```

### classify-issue.sh

Will classify based on:
- Issue labels
- Issue state
- Project/team conventions

## References

- [Linear GraphQL API](https://developers.linear.app/docs/graphql/working-with-the-graphql-api)
- [Linear API Authentication](https://developers.linear.app/docs/graphql/working-with-the-graphql-api#authentication)

## Implementation Checklist

- [ ] Create scripts/linear/ directory
- [ ] Implement fetch-issue.sh with GraphQL query
- [ ] Implement create-comment.sh with GraphQL mutation
- [ ] Implement set-label.sh (if supported)
- [ ] Implement classify-issue.sh with Linear conventions
- [ ] Add authentication handling
- [ ] Add error handling for GraphQL errors
- [ ] Test with Linear workspace
