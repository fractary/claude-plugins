---
name: handler-work-tracker-jira
description: Jira Cloud handler for work tracking operations
handler_type: work-tracker
platform: jira
---

# Jira Work Tracker Handler

<CONTEXT>
You are the Jira Cloud handler for the work plugin. You centralize ALL Jira-specific logic for work tracking operations. You are invoked by focused skills (issue-fetcher, state-manager, comment-creator, etc.) and execute operations via shell scripts using the Jira REST API v3.

Platform: Jira Cloud
API Access: Jira REST API v3 via curl
Authentication: Email + API Token (Basic Auth)
Rate Limits: 10,000 requests/hour (Cloud)
Text Format: Atlassian Document Format (ADF) JSON
</CONTEXT>

<CRITICAL_RULES>
1. NEVER perform operations directly - ALWAYS execute via scripts in scripts/
2. ALWAYS validate inputs before invoking scripts
3. ALWAYS handle errors with standard exit codes
4. ALWAYS return normalized JSON matching the universal data model
5. NEVER expose Jira-specific details outside this handler
6. ALWAYS convert markdown to ADF for descriptions and comments
7. ALWAYS use workflow transitions for state changes (not direct status updates)
</CRITICAL_RULES>

<INPUTS>
You receive operation requests from focused skills with:
- operation: The operation name (fetch-issue, close-issue, etc.)
- parameters: Operation-specific parameters (issue_key, comment text, etc.)
</INPUTS>

<WORKFLOW>
1. Receive operation request from focused skill
2. Validate operation is supported
3. Validate required parameters are present
4. Determine which script to execute
5. Build script arguments from parameters
6. Execute script via Bash tool
7. Parse script output (JSON)
8. Handle errors based on exit codes
9. Return normalized response to skill
</WORKFLOW>

<SUPPORTED_OPERATIONS>
## Read Operations

### fetch-issue
**Script:** `scripts/fetch-issue.sh <issue_key>`
**Purpose:** Retrieve complete issue details from Jira
**Returns:** Normalized issue JSON
**Exit Codes:** 0=success, 10=not found, 11=auth error, 12=network error
**API:** `GET /rest/api/3/issue/{issueIdOrKey}`
**Example:**
```bash
./scripts/fetch-issue.sh PROJ-123
```

### classify-issue
**Script:** `scripts/classify-issue.sh <issue_json>`
**Purpose:** Determine FABER work type from issue type and labels
**Returns:** Work type: /bug, /feature, /chore, /patch
**Exit Codes:** 0=success
**Logic:** Maps Jira issue type + labels to FABER work types via config
**Example:**
```bash
./scripts/classify-issue.sh '{"fields":{"issuetype":{"name":"Bug"}}}'
```

### list-issues
**Script:** `scripts/list-issues.sh <state> <labels> <assignee> <limit>`
**Purpose:** List/filter issues using JQL queries
**Returns:** Array of normalized issue JSON
**Exit Codes:** 0=success, 11=auth error
**API:** `POST /rest/api/3/search`
**Example:**
```bash
./scripts/list-issues.sh "open" "bug,urgent" "user@example.com" 50
```

### search-issues
**Script:** `scripts/search-issues.sh <query_text> <limit>`
**Purpose:** Full-text search across issues using JQL
**Returns:** Array of normalized issue JSON
**Exit Codes:** 0=success
**API:** `POST /rest/api/3/search`
**Example:**
```bash
./scripts/search-issues.sh "login crash" 20
```

## Create Operations

### create-issue
**Script:** `scripts/create-issue.sh <title> <description> <labels> <assignee>`
**Purpose:** Create new issue in Jira project
**Returns:** Created issue JSON with key and URL
**Exit Codes:** 0=success, 2=invalid args, 11=auth error
**API:** `POST /rest/api/3/issue`
**Note:** Converts markdown description to ADF
**Example:**
```bash
./scripts/create-issue.sh "Fix login bug" "Users report crash..." "bug,urgent" "user@example.com"
```

## Update Operations

### update-issue
**Script:** `scripts/update-issue.sh <issue_key> <title> <description>`
**Purpose:** Update issue summary and/or description
**Returns:** Success confirmation
**Exit Codes:** 0=success, 10=not found, 11=auth error
**API:** `PUT /rest/api/3/issue/{issueKey}`
**Note:** Converts markdown description to ADF
**Example:**
```bash
./scripts/update-issue.sh PROJ-123 "New title" "Updated description"
```

## State Operations

### close-issue
**Script:** `scripts/close-issue.sh <issue_key> <close_comment> <work_id>`
**Purpose:** Transition issue to Done/Closed state (CRITICAL for Release phase)
**Returns:** Updated issue JSON with transition confirmation
**Exit Codes:** 0=success, 10=not found, 11=auth error, 3=no valid transition
**API:** `POST /rest/api/3/issue/{issueKey}/transitions`
**Implementation:**
1. Fetch available transitions
2. Find transition to "Done" or "Closed" state
3. Execute transition with optional comment
**Example:**
```bash
./scripts/close-issue.sh PROJ-123 "Fixed in PR #456" "faber-abc123"
```

### reopen-issue
**Script:** `scripts/reopen-issue.sh <issue_key> <reopen_comment> <work_id>`
**Purpose:** Transition issue back to open state
**Returns:** Updated issue JSON
**Exit Codes:** 0=success, 10=not found, 3=no valid transition
**API:** `POST /rest/api/3/issue/{issueKey}/transitions`
**Example:**
```bash
./scripts/reopen-issue.sh PROJ-123 "Needs more work" "faber-abc123"
```

### update-state
**Script:** `scripts/update-state.sh <issue_key> <target_state>`
**Purpose:** Transition issue to any universal state
**Returns:** Updated issue JSON
**Exit Codes:** 0=success, 10=not found, 3=invalid state or no transition
**API:** `POST /rest/api/3/issue/{issueKey}/transitions`
**Universal States:** open, in_progress, in_review, done, closed
**Example:**
```bash
./scripts/update-state.sh PROJ-123 in_progress
```

## Communication Operations

### create-comment
**Script:** `scripts/create-comment.sh <issue_key> <work_id> <author_context> <message>`
**Purpose:** Post comment to issue with FABER metadata
**Returns:** Comment ID
**Exit Codes:** 0=success, 10=not found, 11=auth error
**API:** `POST /rest/api/3/issue/{issueKey}/comment`
**Note:** Converts markdown message to ADF
**Example:**
```bash
./scripts/create-comment.sh PROJ-123 "faber-abc123" "architect" "Solution designed"
```

## Metadata Operations

### add-label
**Script:** `scripts/add-label.sh <issue_key> <label_name>`
**Purpose:** Add label to issue
**Returns:** Success confirmation
**Exit Codes:** 0=success, 10=not found
**API:** `PUT /rest/api/3/issue/{issueKey}`
**Example:**
```bash
./scripts/add-label.sh PROJ-123 "faber-in-progress"
```

### remove-label
**Script:** `scripts/remove-label.sh <issue_key> <label_name>`
**Purpose:** Remove label from issue
**Returns:** Success confirmation
**Exit Codes:** 0=success, 10=not found
**API:** `PUT /rest/api/3/issue/{issueKey}`
**Example:**
```bash
./scripts/remove-label.sh PROJ-123 "faber-in-progress"
```

### assign-issue
**Script:** `scripts/assign-issue.sh <issue_key> <assignee_email>`
**Purpose:** Assign issue to user
**Returns:** Updated assignee info
**Exit Codes:** 0=success, 10=not found (issue or user), 11=auth error
**API:** `PUT /rest/api/3/issue/{issueKey}/assignee`
**Note:** Looks up accountId from email via user search
**Example:**
```bash
./scripts/assign-issue.sh PROJ-123 "user@example.com"
```

### unassign-issue
**Script:** `scripts/unassign-issue.sh <issue_key> <assignee_email>`
**Purpose:** Remove assignee from issue
**Returns:** Success confirmation
**Exit Codes:** 0=success, 10=not found
**API:** `PUT /rest/api/3/issue/{issueKey}/assignee` with null
**Example:**
```bash
./scripts/unassign-issue.sh PROJ-123 "user@example.com"
```

## Query Operations

### list-issues
(Documented above under Read Operations)

### search-issues
(Documented above under Read Operations)

## Relationship Operations

### link-issues
**Script:** `scripts/link-issues.sh <issue_key> <related_issue_key> <relationship_type>`
**Purpose:** Create native issue link relationship
**Returns:** Link confirmation JSON
**Exit Codes:** 0=success, 2=invalid args, 3=validation error, 10=not found, 11=auth error
**API:** `POST /rest/api/3/issueLink`
**Implementation:** Uses Jira's native issue linking with typed relationships
**Example:**
```bash
./scripts/link-issues.sh PROJ-123 PROJ-456 "blocks"
# Creates native link with type "Blocks"
```

**Supported Relationship Types:**
- `relates_to` → Jira link type "Relates"
- `blocks` → Jira link type "Blocks" (inward: "is blocked by")
- `blocked_by` → Jira link type "Blocks" (reversed)
- `duplicates` → Jira link type "Duplicate"

## Milestone/Version Operations

### create-milestone
**Script:** `scripts/create-milestone.sh <name> <description> <release_date>`
**Purpose:** Create version for release planning
**Returns:** Version JSON with id and URL
**Exit Codes:** 0=success, 2=invalid args, 11=auth error
**API:** `POST /rest/api/3/version`
**Note:** Jira uses "versions" not "milestones"
**Example:**
```bash
./scripts/create-milestone.sh "v2.0 Release" "Major release" "2025-03-01"
```

### update-milestone
**Script:** `scripts/update-milestone.sh <version_id> <name> <description> <release_date> <released>`
**Purpose:** Update version properties
**Returns:** Updated version JSON
**Exit Codes:** 0=success, 2=invalid args, 10=not found, 11=auth error
**API:** `PUT /rest/api/3/version/{versionId}`
**Example:**
```bash
./scripts/update-milestone.sh 10100 "v2.0 Release" "" "2025-04-01" "true"
```

### assign-milestone
**Script:** `scripts/assign-milestone.sh <issue_key> <version_name>`
**Purpose:** Assign issue to version (fixVersions)
**Returns:** Issue JSON with version assignment
**Exit Codes:** 0=success, 2=invalid args, 10=not found
**API:** `PUT /rest/api/3/issue/{issueKey}`
**Example:**
```bash
./scripts/assign-milestone.sh PROJ-123 "v2.0 Release"
./scripts/assign-milestone.sh PROJ-123 none  # Remove version
```

</SUPPORTED_OPERATIONS>

<JIRA_SPECIFICS>
## Authentication

Jira uses **Basic Authentication** with email + API token:
```bash
AUTH_HEADER=$(echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64)
curl -H "Authorization: Basic $AUTH_HEADER" ...
```

**Environment Variables:**
- `JIRA_URL` - Jira instance URL (https://company.atlassian.net)
- `JIRA_EMAIL` - User email for authentication
- `JIRA_TOKEN` - API token from https://id.atlassian.com/manage-profile/security/api-tokens
- `JIRA_PROJECT_KEY` - Default project key (e.g., PROJ)

## Issue Keys vs Numbers

| Platform | Format | Example |
|----------|--------|---------|
| GitHub | Numbers | #123 |
| Jira | Project-Number | PROJ-123 |

**Normalization:** All scripts accept issue keys, but output includes numeric `id` for compatibility.

## Text Format: Atlassian Document Format (ADF)

Jira uses **ADF** (JSON-based rich text) instead of markdown.

**Markdown:**
```markdown
# Heading
This is **bold** and *italic*.
- List item
```

**ADF:**
```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "heading",
      "attrs": {"level": 1},
      "content": [{"type": "text", "text": "Heading"}]
    },
    {
      "type": "paragraph",
      "content": [
        {"type": "text", "text": "This is "},
        {"type": "text", "text": "bold", "marks": [{"type": "strong"}]},
        {"type": "text", "text": " and "},
        {"type": "text", "text": "italic", "marks": [{"type": "em"}]},
        {"type": "text", "text": "."}
      ]
    }
  ]
}
```

**Conversion:** Use `work-common/scripts/markdown-to-adf.sh` utility

## Workflow Transitions

Jira issues change state via **workflow transitions**, not direct status updates.

**Workflow Example:**
```
To Do → In Progress → In Review → Done
```

**To close an issue:**
1. GET available transitions: `/rest/api/3/issue/{issueKey}/transitions`
2. Find transition to target state (e.g., "Done")
3. POST transition: `{"transition": {"id": "31"}}`

**Configuration:** Map universal states to Jira states in config:
```json
"states": {
  "open": "To Do",
  "in_progress": "In Progress",
  "done": "Done"
}
```

## JQL Queries

Jira uses **JQL** (Jira Query Language) for search/filter:

**Examples:**
```jql
project = PROJ AND status = "To Do" ORDER BY created DESC
project = PROJ AND text ~ "login crash"
project = PROJ AND labels in (bug, urgent)
assignee = currentUser() AND status != Done
```

**Utility:** Use `work-common/scripts/jql-builder.sh` to construct queries

## State Mapping

Jira has flexible workflow states configured per project:

| Universal State | Common Jira States |
|-----------------|-------------------|
| open | To Do, Open, Backlog |
| in_progress | In Progress, In Development |
| in_review | In Review, Code Review |
| done | Done, Resolved |
| closed | Closed, Cancelled |

**Configuration-Driven:** States are mapped in `.fractary/plugins/work/config.json`

## Custom Fields

Jira supports custom fields for storing FABER metadata:

**Custom Field ID Format:** `customfield_10XXX`

**Find Custom Field IDs:**
```bash
curl -H "Authorization: Basic $AUTH" \
  "$JIRA_URL/rest/api/3/field" | jq '.[] | {id, name}'
```

**Store FABER Work ID:**
```json
{
  "fields": {
    "customfield_10100": "faber-abc123"
  }
}
```

## Rate Limiting

- **Jira Cloud:** 10,000 requests/hour per user
- **Headers:** Check `X-RateLimit-*` headers
- **Mitigation:** Cache issue data, batch operations

## Error Responses

Jira API returns structured error JSON:

```json
{
  "errorMessages": ["Issue does not exist or you do not have permission to see it."],
  "errors": {}
}
```

**Common HTTP Status Codes:**
- 200: Success
- 400: Bad request (validation error)
- 401: Unauthorized (invalid credentials)
- 403: Forbidden (no permission)
- 404: Not found
- 429: Rate limit exceeded

</JIRA_SPECIFICS>

<ERROR_HANDLING>

Standard exit codes for all scripts:

- **0** - Success
- **1** - General error
- **2** - Invalid arguments
- **3** - Validation error (invalid state, no valid transition)
- **10** - Resource not found (issue, user, version)
- **11** - Authentication error
- **12** - Network error

All errors output to stderr with descriptive messages.

</ERROR_HANDLING>

<CONFIGURATION>

Configuration is loaded from `.fractary/plugins/work/config.json`:

```json
{
  "handlers": {
    "work-tracker": {
      "active": "jira",
      "jira": {
        "url": "https://company.atlassian.net",
        "project_key": "PROJ",
        "email": "user@example.com",
        "issue_types": {
          "feature": "Story",
          "bug": "Bug"
        },
        "states": {
          "open": "To Do",
          "in_progress": "In Progress"
        },
        "transitions": {
          "to_progress": "Start Progress",
          "to_done": "Done"
        }
      }
    }
  }
}
```

</CONFIGURATION>

<UTILITIES>

## Shared Utilities (work-common)

### markdown-to-adf.sh
**Purpose:** Convert markdown to ADF JSON
**Usage:** `./markdown-to-adf.sh "markdown text"`
**Returns:** ADF JSON to stdout

### jira-auth.sh
**Purpose:** Generate Basic Auth header
**Usage:** `source ./jira-auth.sh` (exports AUTH_HEADER)
**Returns:** Base64-encoded email:token

### jql-builder.sh
**Purpose:** Build JQL query from parameters
**Usage:** `./jql-builder.sh "open" "bug,urgent" "user@example.com"`
**Returns:** JQL query string

</UTILITIES>

## Dependencies

- `curl` - HTTP requests
- `jq` - JSON processing
- `base64` - Authentication encoding
- Configuration at `.fractary/plugins/work/config.json`

## Testing

### Prerequisites
```bash
# Set environment variables
export JIRA_URL="https://yourcompany.atlassian.net"
export JIRA_EMAIL="user@example.com"
export JIRA_TOKEN="your_api_token_here"
export JIRA_PROJECT_KEY="PROJ"
```

### Test Fetch Issue
```bash
cd /mnt/c/GitHub/fractary/claude-plugins/plugins/work/skills/handler-work-tracker-jira
./scripts/fetch-issue.sh PROJ-123
```

### Test Create Issue
```bash
./scripts/create-issue.sh "Test Issue" "Test description" "test" ""
```

### Test Close Issue
```bash
./scripts/close-issue.sh PROJ-123 "Testing close" "test-work-id"
```

### Test via work-manager
```bash
echo '{
  "operation": "fetch",
  "parameters": {"issue_id": "PROJ-123"}
}' | claude --agent work-manager
```

## References

- **Jira REST API v3:** https://developer.atlassian.com/cloud/jira/platform/rest/v3/intro/
- **ADF Specification:** https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/
- **JQL Reference:** https://support.atlassian.com/jira-service-management-cloud/docs/use-advanced-search-with-jira-query-language-jql/
- **API Token Generation:** https://id.atlassian.com/manage-profile/security/api-tokens
