# Linear GraphQL API Reference

## Overview

Linear uses a GraphQL API for all operations. This handler implementation uses the Linear GraphQL API v1.

- **API Endpoint**: `https://api.linear.app/graphql`
- **Authentication**: Bearer token via `LINEAR_API_KEY` environment variable
- **Protocol**: GraphQL (queries and mutations)
- **Rate Limits**: ~1,500 requests/hour (soft limit)

## Authentication

### Setting Up API Key

1. Log into Linear: https://linear.app
2. Go to Settings → API → Personal API Keys
3. Generate a new API key
4. Set environment variable:

```bash
export LINEAR_API_KEY="lin_api_xxxxxxxxxxxxxxxxxxxxxxxx"
```

### Authentication in Requests

All requests require the Authorization header:

```bash
curl -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query": "..."}'
```

## Core Concepts

### IDs and Identifiers

Linear uses UUIDs internally but provides human-readable identifiers:

- **UUID**: `"a1b2c3d4-e5f6-7890-abcd-ef1234567890"` (internal ID)
- **Identifier**: `"TEAM-123"` (human-readable, displayed in UI)

Most API operations accept either format.

### Teams

Linear organizes work by teams. Each issue belongs to a team:

- Team ID (UUID): Required for creating issues and cycles
- Team Key (string): Human-readable prefix (e.g., "ENG", "PROD")

### Workflow States

States are team-specific and have types:

- **backlog**: Issue is in backlog
- **unstarted**: Issue not yet started (Todo)
- **started**: Issue is in progress
- **completed**: Issue is done
- **canceled**: Issue was canceled

### Labels

Labels use UUIDs internally. Must lookup label by name to get UUID before operations:

```graphql
query {
  team(id: "team-uuid") {
    labels {
      nodes {
        id
        name
      }
    }
  }
}
```

### Cycles

Cycles are Linear's equivalent of sprints/milestones:

- Have start and end dates
- Belong to a team
- Issues can be assigned to cycles

## Common Operations

### Query Issue

```graphql
query GetIssue($issueId: String!) {
  issue(id: $issueId) {
    id
    identifier
    title
    description
    createdAt
    updatedAt
    completedAt
    url
    state {
      id
      name
      type
    }
    labels {
      nodes {
        id
        name
      }
    }
    assignee {
      id
      name
      email
    }
    creator {
      id
      name
      email
    }
    priority
    estimate
    cycle {
      id
      name
    }
  }
}
```

Variables:
```json
{
  "issueId": "TEAM-123"
}
```

### Create Issue

```graphql
mutation CreateIssue($teamId: String!, $title: String!, $description: String, $labelIds: [String!], $assigneeId: String) {
  issueCreate(input: {
    teamId: $teamId,
    title: $title,
    description: $description,
    labelIds: $labelIds,
    assigneeId: $assigneeId
  }) {
    success
    issue {
      id
      identifier
      title
      url
    }
  }
}
```

Variables:
```json
{
  "teamId": "team-uuid",
  "title": "Fix login bug",
  "description": "Users cannot login on mobile",
  "labelIds": ["label-uuid-1", "label-uuid-2"],
  "assigneeId": "user-uuid"
}
```

### Update Issue State

```graphql
mutation UpdateIssueState($issueId: String!, $stateId: String!) {
  issueUpdate(id: $issueId, input: {stateId: $stateId}) {
    success
    issue {
      id
      identifier
      state {
        name
        type
      }
    }
  }
}
```

### Create Comment

```graphql
mutation CreateComment($issueId: String!, $body: String!) {
  commentCreate(input: {issueId: $issueId, body: $body}) {
    success
    comment {
      id
      url
      createdAt
    }
  }
}
```

Note: Linear supports markdown in comment body.

### Add Label to Issue

```graphql
mutation AddLabel($issueId: String!, $labelId: String!) {
  issueAddLabel(id: $issueId, labelId: $labelId) {
    success
    issue {
      id
      labels {
        nodes {
          name
        }
      }
    }
  }
}
```

### Remove Label from Issue

```graphql
mutation RemoveLabel($issueId: String!, $labelId: String!) {
  issueRemoveLabel(id: $issueId, labelId: $labelId) {
    success
  }
}
```

### Assign Issue

```graphql
mutation AssignIssue($issueId: String!, $assigneeId: String!) {
  issueUpdate(id: $issueId, input: {assigneeId: $assigneeId}) {
    success
    issue {
      assignee {
        id
        name
        email
      }
    }
  }
}
```

### Search Issues

```graphql
query SearchIssues($query: String!, $limit: Int) {
  issues(
    first: $limit,
    filter: {searchableContent: {containsIgnoreCase: $query}}
  ) {
    nodes {
      id
      identifier
      title
      state {
        name
      }
      url
    }
  }
}
```

### List Issues with Filters

```graphql
query ListIssues($filter: IssueFilter!, $limit: Int) {
  issues(first: $limit, filter: $filter) {
    nodes {
      id
      identifier
      title
      state {
        name
        type
      }
      labels {
        nodes {
          name
        }
      }
      url
    }
  }
}
```

Example filter:
```json
{
  "filter": {
    "team": {"id": {"eq": "team-uuid"}},
    "state": {"type": {"eq": "started"}},
    "labels": {"some": {"name": {"in": ["bug", "urgent"]}}}
  },
  "limit": 50
}
```

### Create Issue Relation

```graphql
mutation CreateIssueRelation($issueId: String!, $relatedIssueId: String!, $type: IssueRelationType!) {
  issueRelationCreate(input: {
    issueId: $issueId,
    relatedIssueId: $relatedIssueId,
    type: $type
  }) {
    success
    issueRelation {
      id
      type
    }
  }
}
```

Relation types:
- `blocks`: This issue blocks another
- `related`: This issue is related to another
- `duplicate`: This issue duplicates another

### Create Cycle

```graphql
mutation CreateCycle($teamId: String!, $name: String!, $startsAt: TimelessDate, $endsAt: TimelessDate) {
  cycleCreate(input: {
    teamId: $teamId,
    name: $name,
    startsAt: $startsAt,
    endsAt: $endsAt
  }) {
    success
    cycle {
      id
      name
      startsAt
      endsAt
      url
    }
  }
}
```

Date format: `"2025-01-29"` (YYYY-MM-DD)

### Assign Issue to Cycle

```graphql
mutation AssignIssueToCycle($issueId: String!, $cycleId: String!) {
  issueUpdate(id: $issueId, input: {cycleId: $cycleId}) {
    success
    issue {
      cycle {
        name
      }
    }
  }
}
```

## Lookup Operations

### Get Team States

Required for state transitions:

```graphql
query GetTeamStates($teamId: String!) {
  team(id: $teamId) {
    states {
      nodes {
        id
        name
        type
      }
    }
  }
}
```

### Get Team Labels

Required for label operations:

```graphql
query GetTeamLabels($teamId: String!) {
  team(id: $teamId) {
    labels {
      nodes {
        id
        name
        color
      }
    }
  }
}
```

### Get Users

Required for assignment operations:

```graphql
query GetUsers {
  users {
    nodes {
      id
      name
      email
    }
  }
}
```

## Error Handling

### Error Response Format

```json
{
  "errors": [
    {
      "message": "Error message here",
      "locations": [{"line": 1, "column": 1}],
      "path": ["issueUpdate"]
    }
  ]
}
```

### Common Error Messages

- `"Issue not found"`: Issue ID/identifier invalid
- `"Unauthorized"`: API key invalid or missing
- `"Invalid input"`: Mutation input validation failed
- `"Rate limit exceeded"`: Too many requests

### Handler Exit Codes

- **0**: Success
- **1**: General error
- **2**: Invalid arguments
- **3**: Invalid state/transition or entity not found (labels, states)
- **10**: Issue not found
- **11**: Authentication error
- **12**: Network error
- **13**: Rate limit exceeded

## Rate Limits

Linear has soft rate limits (~1,500 requests/hour):

- No explicit rate limit headers
- Throttling is gradual (slower responses)
- Best practice: batch operations, cache lookups

### Optimization Strategies

1. **Cache UUID lookups**: Labels and states don't change often
2. **Batch queries**: Fetch multiple issues in one query
3. **Use fragments**: Reuse common field selections
4. **Minimize fields**: Only request needed fields

## Best Practices

### 1. Always Lookup UUIDs

Labels and states require UUIDs. Never hardcode:

```bash
# Bad
LABEL_ID="hardcoded-uuid"

# Good
LABEL_ID=$(query_label_by_name "$LABEL_NAME")
```

### 2. Handle Team-Specific States

State names vary by team. Use configuration:

```json
{
  "states": {
    "open": "Todo",
    "in_progress": "In Progress",
    "done": "Done"
  }
}
```

### 3. Support Both ID Formats

Accept both UUID and identifier (TEAM-123):

```bash
if [[ "$ISSUE_ID" =~ ^[A-Z]+-[0-9]+$ ]]; then
  # Identifier format (TEAM-123)
else
  # UUID format
fi
```

### 4. Markdown Support

Linear natively supports markdown in descriptions and comments. No conversion needed!

```graphql
{
  body: "# Title\n\n**Bold** and *italic* text\n\n- List item"
}
```

### 5. Error Recovery

Check for errors in every response:

```bash
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    # Handle error
fi
```

## References

- **Official API Docs**: https://developers.linear.app/docs/graphql/working-with-the-graphql-api
- **GraphQL Schema**: https://studio.apollographql.com/public/Linear-API/explorer
- **Playground**: https://linear.app/fractary/settings/api (requires account)
- **SDK**: https://github.com/linear/linear (TypeScript SDK)

## Configuration Example

```json
{
  "handlers": {
    "work-tracker": {
      "active": "linear",
      "linear": {
        "workspace_id": "workspace-uuid",
        "team_id": "team-uuid",
        "team_key": "TEAM",
        "classification": {
          "feature": ["feature", "enhancement"],
          "bug": ["bug"],
          "chore": ["improvement", "maintenance"],
          "patch": ["urgent", "hotfix"]
        },
        "states": {
          "open": "Todo",
          "in_progress": "In Progress",
          "in_review": "In Review",
          "done": "Done",
          "closed": "Canceled"
        }
      }
    }
  }
}
```

## Troubleshooting

### "Issue not found"
- Verify issue identifier format (TEAM-123)
- Check issue belongs to the configured team
- Try using UUID instead of identifier

### "Unauthorized"
- Verify LINEAR_API_KEY is set and valid
- Check API key hasn't expired
- Regenerate key in Linear settings if needed

### "Label not found"
- Label names are case-sensitive
- Verify label exists in the team
- Create label in Linear UI first

### Slow Responses
- Check rate limit status
- Reduce query complexity (fewer fields)
- Add delays between requests
- Cache frequently accessed data

## Changelog

- **2025-10-29**: Initial Linear handler implementation (18 operations)
- All operations match GitHub and Jira handlers for 100% feature parity
