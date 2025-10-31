# Fractary Work Plugin - Universal Issue Management Specification

**Version:** 2.0.0
**Status:** Proposed
**Last Updated:** 2025-01-29
**Authors:** Fractary Team

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Universal Data Model](#3-universal-data-model)
4. [Operations Specification](#4-operations-specification)
5. [Skill Definitions](#5-skill-definitions)
6. [Handler Implementation](#6-handler-implementation)
7. [Configuration](#7-configuration)
8. [Platform Support](#8-platform-support)
9. [Integration with FABER](#9-integration-with-faber)
10. [Implementation Phases](#10-implementation-phases)
11. [Testing Strategy](#11-testing-strategy)
12. [Examples](#12-examples)
13. [Migration Guide](#13-migration-guide)
14. [Future Enhancements](#14-future-enhancements)

---

## 1. Overview

### 1.1 Purpose

The **Fractary Work Plugin** provides universal issue management capabilities across multiple work tracking platforms (GitHub Issues, Jira, Linear). It enables:

- **Platform-agnostic operations**: Same interface works with any supported platform
- **FABER workflow integration**: Seamless work item management in automated workflows
- **Standalone usage**: Can be used independently of FABER
- **Extensibility**: Easy to add new platforms or operations

### 1.2 Goals

1. **Universal Interface**: Abstract platform differences behind common operations
2. **Consistency**: Follow the same architectural patterns as the repo plugin
3. **Maintainability**: Clear separation of concerns via 3-layer architecture
4. **Context Efficiency**: Minimize LLM context by using focused skills and external scripts
5. **Reliability**: Deterministic operations with proper error handling

### 1.3 Design Principles

- **Skills are focused**: Each skill performs one type of operation
- **Handlers abstract platforms**: Platform-specific logic centralized in handlers
- **Scripts are deterministic**: All operations execute outside LLM context
- **Configuration drives behavior**: No code changes to switch platforms
- **Normalize everything**: Common data model across all platforms

---

## 2. Architecture

### 2.1 Three-Layer Architecture

```
Layer 1: Commands & Director
   ↓
Layer 2: work-manager Agent (Decision Logic & Routing)
   ↓
Layer 3: Focused Skills (Workflow Orchestration)
   ↓
Layer 4: Handlers (Platform Abstraction)
   ↓
Layer 5: Scripts (Deterministic Operations)
```

**Context Efficiency:**
- Layers 1-3: In LLM context (~300 lines)
- Layers 4-5: Outside LLM context (executed via Bash)
- **Result:** ~55-60% context reduction vs monolithic approach

### 2.2 Directory Structure

```
plugins/work/
├── agents/
│   └── work-manager.md                    # Pure routing agent
├── skills/
│   ├── issue-fetcher/                     # Fetch issue details
│   ├── issue-classifier/                  # Classify work type
│   ├── issue-creator/                     # Create new issues
│   ├── issue-updater/                     # Update title/description
│   ├── state-manager/                     # Lifecycle state changes
│   ├── comment-creator/                   # Post comments
│   ├── label-manager/                     # Manage labels
│   ├── issue-assigner/                    # Assign to users
│   ├── issue-linker/                      # Link related issues
│   ├── milestone-manager/                 # Milestone operations
│   ├── issue-searcher/                    # Query/list issues
│   ├── handler-work-tracker-github/       # GitHub adapter
│   ├── handler-work-tracker-jira/         # Jira adapter
│   ├── handler-work-tracker-linear/       # Linear adapter
│   └── work-common/                       # Shared utilities
├── config/
│   └── config.example.json                # Configuration template
└── docs/
    └── README.md                          # User documentation
```

**Total:** 11 focused skills + 3 handlers + 1 common = 15 skill directories

### 2.3 Component Responsibilities

#### work-manager Agent (Layer 2)
- Parse operation requests
- Validate operation and parameters
- Route to appropriate skill
- Return structured responses
- **Never executes operations directly**

#### Focused Skills (Layer 3)
- Receive requests from agent
- Determine which handler to invoke
- Coordinate handler calls
- Normalize responses
- Document work (if applicable)
- **Never contain platform-specific logic**

#### Handler Skills (Layer 4)
- Platform-specific operation implementation
- Execute scripts with proper parameters
- Handle platform quirks and differences
- Return normalized responses
- **Only handlers know about platforms**

#### Scripts (Layer 5)
- Deterministic shell scripts
- Called by handlers via Bash tool
- Exit codes for error handling
- JSON output for structured data
- **Outside LLM context for efficiency**

---

## 3. Universal Data Model

### 3.1 Normalized Issue Structure

All handlers must transform platform-specific responses to this common format:

```json
{
  "id": "string",              // Platform-specific ID (123, "PROJ-456", "uuid")
  "identifier": "string",      // Human-readable ID ("#123", "PROJ-456", "TEAM-123")
  "title": "string",           // Issue title
  "description": "string",     // Issue body/description (markdown where possible)
  "state": "string",           // Normalized state (see 3.2)
  "labels": ["string"],        // Array of label names
  "assignees": [               // Array of assigned users
    {
      "id": "string",
      "username": "string",
      "email": "string"        // Optional
    }
  ],
  "author": {                  // Issue creator
    "id": "string",
    "username": "string"
  },
  "createdAt": "ISO8601",      // Creation timestamp
  "updatedAt": "ISO8601",      // Last update timestamp
  "closedAt": "ISO8601",       // Close timestamp (if closed)
  "url": "string",             // Web URL to issue
  "platform": "string",        // "github", "jira", or "linear"
  "metadata": {                // Platform-specific extra fields
    "priority": "string",      // Optional
    "estimate": "number",      // Optional
    "sprint": "string",        // Optional
    "custom": {}               // Platform-specific custom fields
  }
}
```

### 3.2 State Terminology Mapping

| Universal State | GitHub | Jira | Linear |
|-----------------|--------|------|--------|
| `open` | OPEN | Open / To Do | Backlog / Todo |
| `in_progress` | OPEN + label | In Progress | In Progress |
| `in_review` | OPEN + label | In Review / Code Review | In Review |
| `done` | CLOSED | Done / Resolved | Done / Completed |
| `closed` | CLOSED | Closed | Canceled / Archived |

**Implementation Notes:**
- Each handler has state mapping configuration
- `update-state.sh` translates universal → platform states
- GitHub uses labels for intermediate states (in_progress, in_review)
- Jira uses workflow transitions
- Linear uses team-specific state definitions

### 3.3 Work Type Classification

| Universal Type | GitHub Labels | Jira Issue Types | Linear Labels |
|----------------|---------------|------------------|---------------|
| `/bug` | bug, fix | Bug | bug |
| `/feature` | feature, enhancement | Story, Feature, Epic | feature |
| `/chore` | chore, maintenance, docs | Task, Chore | improvement, maintenance |
| `/patch` | hotfix, patch, urgent | Bug (with hotfix label) | urgent, hotfix |

**Classification Logic:**
- Each handler implements `classify-issue.sh`
- Examines labels, issue type, title, description
- Returns normalized `/type` format
- Configuration allows custom label mappings

### 3.4 Priority Mapping

| Universal Priority | GitHub | Jira | Linear |
|--------------------|--------|------|--------|
| `urgent` | Label: priority-urgent | Priority: Highest | priority: 1 |
| `high` | Label: priority-high | Priority: High | priority: 2 |
| `normal` | Label: priority-normal | Priority: Medium | priority: 3 |
| `low` | Label: priority-low | Priority: Low | priority: 4 |
| `none` | No label | Priority: (none) | priority: 0 |

---

## 4. Operations Specification

### 4.1 Universal Operations

These 18 operations MUST be supported by every platform handler:

#### READ Operations

##### 4.1.1 fetch-issue
**Purpose:** Retrieve complete issue details
**Input:** `issue_id` (platform-specific format)
**Output:** Normalized issue JSON (see 3.1)
**Exit Codes:** 0=success, 10=not found, 11=auth error, 12=network error
**Usage:** Frame phase (FABER), query operations

##### 4.1.2 classify-issue
**Purpose:** Determine work type from issue metadata
**Input:** issue JSON (from fetch-issue)
**Output:** `/bug`, `/feature`, `/chore`, or `/patch`
**Exit Codes:** 0=success, 1=cannot classify
**Usage:** Frame phase (FABER)

#### CREATE Operations

##### 4.1.3 create-issue
**Purpose:** Create new issue in tracking system
**Input:** `title`, `description`, `labels[]`, `assignees[]`
**Output:** Created issue JSON with `id` and `url`
**Exit Codes:** 0=success, 2=invalid input, 11=auth error
**Usage:** Follow-up tasks, batch operations

#### UPDATE Operations

##### 4.1.4 update-issue
**Purpose:** Modify issue title and/or description
**Input:** `issue_id`, `title` (optional), `description` (optional)
**Output:** Updated issue JSON
**Exit Codes:** 0=success, 10=not found, 2=no changes provided
**Usage:** Clarifying requirements, adding context

##### 4.1.5 update-state
**Purpose:** Change issue lifecycle state
**Input:** `issue_id`, `target_state` (universal state name)
**Output:** New state confirmation
**Exit Codes:** 0=success, 10=not found, 3=invalid transition
**Usage:** Workflow state management

#### STATE Operations

##### 4.1.6 close-issue
**Purpose:** Close/resolve an issue
**Input:** `issue_id`, `close_comment` (optional)
**Output:** Closed issue JSON
**Exit Codes:** 0=success, 10=not found, 3=already closed
**Usage:** Release phase (FABER) - **CRITICAL**

##### 4.1.7 reopen-issue
**Purpose:** Reopen a closed issue
**Input:** `issue_id`, `reopen_comment` (optional)
**Output:** Reopened issue JSON
**Exit Codes:** 0=success, 10=not found, 3=not closed
**Usage:** Issue needs more work

#### COMMUNICATION Operations

##### 4.1.8 create-comment
**Purpose:** Post a comment to an issue
**Input:** `issue_id`, `work_id`, `author_context`, `message` (markdown)
**Output:** Comment ID/URL
**Exit Codes:** 0=success, 10=not found
**Usage:** All FABER phases (status updates)

**Note on Markdown:**
- GitHub/Linear: Use markdown as-is
- Jira: Convert markdown → ADF via `work-common/markdown-to-adf.sh`

#### METADATA Operations

##### 4.1.9 add-label
**Purpose:** Add label to issue
**Input:** `issue_id`, `label_name`
**Output:** Success confirmation
**Exit Codes:** 0=success, 10=not found, 3=label doesn't exist
**Usage:** Frame, Evaluate, Release phases

**Platform Notes:**
- GitHub: Direct label name
- Jira: Label string in labels array
- Linear: Must lookup label UUID first

##### 4.1.10 remove-label
**Purpose:** Remove label from issue
**Input:** `issue_id`, `label_name`
**Output:** Success confirmation
**Exit Codes:** 0=success, 10=not found, 3=label not on issue
**Usage:** State transitions, cleanup

##### 4.1.11 assign-issue
**Purpose:** Assign issue to user(s)
**Input:** `issue_id`, `assignee_username[]`
**Output:** Updated assignee list
**Exit Codes:** 0=success, 10=not found, 3=user doesn't exist
**Usage:** Team workflows, bot ownership

##### 4.1.12 unassign-issue
**Purpose:** Remove assignee(s) from issue
**Input:** `issue_id`, `assignee_username[]` (or "all")
**Output:** Updated assignee list
**Exit Codes:** 0=success, 10=not found
**Usage:** Reassignment, cleanup

##### 4.1.13 link-issues
**Purpose:** Create relationship between issues
**Input:** `issue_id`, `related_issue_id`, `relationship_type`
**Output:** Link confirmation
**Exit Codes:** 0=success, 10=not found
**Usage:** Dependency tracking, related work

**Relationship Types (platform-dependent):**
- `blocks` / `blocked_by`
- `relates_to`
- `duplicates` / `duplicated_by`
- `depends_on` / `depended_on_by`

**Platform Notes:**
- GitHub: Via PR references or comment mentions
- Jira: Native issue links API
- Linear: Relations API

##### 4.1.14 assign-milestone
**Purpose:** Associate issue with milestone/sprint
**Input:** `issue_id`, `milestone_id`
**Output:** Updated issue with milestone
**Exit Codes:** 0=success, 10=not found, 3=milestone doesn't exist
**Usage:** Release planning, sprint management

#### QUERY Operations

##### 4.1.15 search-issues
**Purpose:** Full-text search across issues
**Input:** `query_text`, `limit` (optional)
**Output:** Array of normalized issue JSON
**Exit Codes:** 0=success
**Usage:** Finding related issues, duplicate detection

**Platform Notes:**
- GitHub: `gh issue list --search "query"`
- Jira: JQL text search `text ~ "query"`
- Linear: GraphQL `searchableContent` filter

##### 4.1.16 list-issues
**Purpose:** List/filter issues by criteria
**Input:** `state` (optional), `labels[]` (optional), `assignee` (optional), `limit` (optional)
**Output:** Array of normalized issue JSON
**Exit Codes:** 0=success
**Usage:** Batch operations, entity discovery

#### MILESTONE Operations

##### 4.1.17 create-milestone
**Purpose:** Create new milestone/sprint
**Input:** `title`, `description` (optional), `due_date` (optional)
**Output:** Created milestone JSON with `id`
**Exit Codes:** 0=success, 2=invalid input
**Usage:** Release planning

**Platform Mapping:**
- GitHub: Milestones
- Jira: Versions or Sprints
- Linear: Cycles

##### 4.1.18 update-milestone
**Purpose:** Update milestone details
**Input:** `milestone_id`, `title` (optional), `description` (optional), `due_date` (optional), `state` (optional)
**Output:** Updated milestone JSON
**Exit Codes:** 0=success, 10=not found
**Usage:** Adjusting release dates, sprint changes

### 4.2 Operation Summary Matrix

| Operation | GitHub | Jira | Linear | Priority |
|-----------|--------|------|--------|----------|
| fetch-issue | ✅ gh CLI | ✅ REST API | ✅ GraphQL | P0 (CRITICAL) |
| classify-issue | ✅ Labels | ✅ Issue Type | ✅ Labels | P0 (CRITICAL) |
| create-issue | ✅ gh issue create | ✅ POST /issue | ✅ issueCreate | P1 (HIGH) |
| update-issue | ✅ gh issue edit | ✅ PUT /issue | ✅ issueUpdate | P1 (HIGH) |
| update-state | ✅ close + labels | ✅ Transitions | ✅ State update | P0 (CRITICAL) |
| close-issue | ✅ gh issue close | ✅ Transition | ✅ State: done | P0 (CRITICAL) |
| reopen-issue | ✅ gh issue reopen | ✅ Transition | ✅ State: open | P1 (HIGH) |
| create-comment | ✅ gh issue comment | ✅ POST /comment (ADF) | ✅ commentCreate | P0 (CRITICAL) |
| add-label | ✅ --add-label | ✅ labels array | ✅ issueAddLabel | P0 (CRITICAL) |
| remove-label | ✅ --remove-label | ✅ labels array | ✅ issueRemoveLabel | P1 (HIGH) |
| assign-issue | ✅ --add-assignee | ✅ assignee field | ✅ assignee update | P2 (MEDIUM) |
| unassign-issue | ✅ --remove-assignee | ✅ assignee null | ✅ assignee null | P2 (MEDIUM) |
| link-issues | ⚠️ Via comments | ✅ Issue links | ✅ Relations | P2 (MEDIUM) |
| assign-milestone | ✅ --milestone | ✅ fixVersions | ✅ cycle | P2 (MEDIUM) |
| search-issues | ✅ --search | ✅ JQL text search | ✅ searchableContent | P2 (MEDIUM) |
| list-issues | ✅ gh issue list | ✅ JQL queries | ✅ issues query | P1 (HIGH) |
| create-milestone | ✅ gh api | ✅ versions API | ✅ cycle create | P3 (LOW) |
| update-milestone | ✅ gh api | ✅ versions API | ✅ cycle update | P3 (LOW) |

**Priority Levels:**
- **P0 (CRITICAL):** Required for FABER workflows to function
- **P1 (HIGH):** Important for common operations
- **P2 (MEDIUM):** Useful for advanced workflows
- **P3 (LOW):** Nice-to-have, future enhancement

---

## 5. Skill Definitions

### 5.1 Focused Skills Overview

Each skill performs ONE type of operation and delegates to the appropriate handler.

#### 5.1.1 issue-fetcher

**Purpose:** Retrieve issue details from tracking system
**Operations:** fetch-issue
**Invokes:** `handler-work-tracker-{platform}`
**Used By:** Frame phase, all query operations
**Returns:** Normalized issue JSON

**SKILL.md Structure:**
```markdown
<CONTEXT>
Fetch issue details from work tracking system.
</CONTEXT>

<WORKFLOW>
1. Load configuration to determine active handler
2. Invoke handler-work-tracker-{platform} with fetch-issue operation
3. Receive normalized issue JSON
4. Return to caller
</WORKFLOW>

<OUTPUTS>
Normalized issue JSON (see Universal Data Model)
</OUTPUTS>
```

#### 5.1.2 issue-classifier

**Purpose:** Determine work type from issue metadata
**Operations:** classify-issue
**Invokes:** `handler-work-tracker-{platform}`
**Used By:** Frame phase
**Returns:** `/bug`, `/feature`, `/chore`, `/patch`

**Classification Rules (configurable):**
- Examines labels, issue type field, title keywords
- Configurable label mappings per platform
- Returns normalized work type for FABER

#### 5.1.3 issue-creator

**Purpose:** Create new issues in tracking system
**Operations:** create-issue
**Invokes:** `handler-work-tracker-{platform}`
**Used By:** Follow-up task creation, batch operations
**Returns:** Created issue ID and URL

**Use Cases:**
- Create sub-tasks from main issue
- Create follow-up issues for tech debt
- Batch issue creation from templates

#### 5.1.4 issue-updater

**Purpose:** Update issue title and/or description
**Operations:** update-issue
**Invokes:** `handler-work-tracker-{platform}`
**Used By:** Clarifying requirements, adding context
**Returns:** Updated issue JSON

#### 5.1.5 state-manager

**Purpose:** Manage issue lifecycle states
**Operations:** close-issue, reopen-issue, update-state
**Invokes:** `handler-work-tracker-{platform}`
**Used By:** Release phase (close-issue), workflow management
**Returns:** Updated state confirmation

**CRITICAL:** This skill fixes the current bug where Release phase cannot actually close issues.

**State Transitions:**
```
open → in_progress → in_review → done
  ↑                                 ↓
  └─────────── closed ──────────────┘
```

#### 5.1.6 comment-creator

**Purpose:** Post comments to issues
**Operations:** create-comment
**Invokes:** `handler-work-tracker-{platform}`
**Used By:** ALL FABER phases (status updates)
**Returns:** Comment ID/URL

**Comment Format:**
```markdown
🎯 **Phase**: [Frame|Architect|Build|Evaluate|Release]

[Status message]

Work ID: `{work_id}`
Author: {author_context}
```

#### 5.1.7 label-manager

**Purpose:** Manage issue labels
**Operations:** add-label, remove-label
**Invokes:** `handler-work-tracker-{platform}`
**Used By:** Frame (add in-progress), Release (remove in-progress, add completed)
**Returns:** Success confirmation

**Common Labels:**
- `faber-in-progress` - Active work
- `faber-completed` - Done
- `faber-error` - Failed workflow

#### 5.1.8 issue-assigner

**Purpose:** Assign issues to users
**Operations:** assign-issue, unassign-issue
**Invokes:** `handler-work-tracker-{platform}`
**Used By:** Team workflows, bot ownership
**Returns:** Updated assignee list

#### 5.1.9 issue-linker

**Purpose:** Create relationships between issues
**Operations:** link-issues
**Invokes:** `handler-work-tracker-{platform}`
**Used By:** Dependency tracking, related work discovery
**Returns:** Link confirmation

#### 5.1.10 milestone-manager

**Purpose:** Manage milestones/sprints
**Operations:** create-milestone, update-milestone, assign-to-milestone
**Invokes:** `handler-work-tracker-{platform}`
**Used By:** Release planning, sprint management
**Returns:** Milestone info

#### 5.1.11 issue-searcher

**Purpose:** Query and list issues
**Operations:** search-issues, list-issues
**Invokes:** `handler-work-tracker-{platform}`
**Used By:** Batch operations, discovery, duplicate detection
**Returns:** Array of normalized issues

**Query Capabilities:**
- Full-text search
- Filter by state, labels, assignee
- Limit results
- Sort by created/updated date

---

## 6. Handler Implementation

### 6.1 Handler Pattern

Handlers centralize ALL platform-specific logic:
- API/CLI invocation
- Response parsing and normalization
- Error handling and retries
- Platform quirks and workarounds

**Handler Structure:**
```
handler-work-tracker-{platform}/
├── SKILL.md                      # Handler documentation
├── scripts/
│   ├── fetch-issue.sh            # One script per operation
│   ├── classify-issue.sh
│   ├── create-issue.sh
│   └── ... (18 total)
└── docs/
    ├── {platform}-api.md         # API reference
    └── operations.md             # Operation details
```

### 6.2 handler-work-tracker-github

**Status:** Complete implementation (Phase 1)

**Access Method:** GitHub CLI (`gh`)
**Authentication:** `GITHUB_TOKEN` environment variable
**Rate Limits:** 5,000 requests/hour (authenticated)

#### Scripts to Implement (18 total)

##### Existing (Move from work-manager)
1. ✅ `fetch-issue.sh` - gh issue view --json
2. ✅ `classify-issue.sh` - Label-based classification
3. ✅ `create-comment.sh` - gh issue comment
4. ✅ `set-label.sh` - gh issue edit --add-label (rename to add-label.sh)

##### New (Priority 0 - CRITICAL)
5. ⚠️ `close-issue.sh` - gh issue close --comment
6. ⚠️ `update-state.sh` - Maps to close/reopen + labels
7. ⚠️ `list-issues.sh` - gh issue list with filters

##### New (Priority 1 - HIGH)
8. 🔲 `create-issue.sh` - gh issue create --title --body --label
9. 🔲 `update-issue.sh` - gh issue edit --title --body
10. 🔲 `reopen-issue.sh` - gh issue reopen --comment
11. 🔲 `remove-label.sh` - gh issue edit --remove-label

##### New (Priority 2 - MEDIUM)
12. 🔲 `assign-issue.sh` - gh issue edit --add-assignee
13. 🔲 `unassign-issue.sh` - gh issue edit --remove-assignee
14. 🔲 `link-issues.sh` - Add reference comment
15. 🔲 `assign-milestone.sh` - gh issue edit --milestone
16. 🔲 `search-issues.sh` - gh issue list --search

##### New (Priority 3 - LOW)
17. 🔲 `create-milestone.sh` - gh api repos/{owner}/{repo}/milestones -X POST
18. 🔲 `update-milestone.sh` - gh api repos/{owner}/{repo}/milestones/{id} -X PATCH

#### Example Script: close-issue.sh

```bash
#!/bin/bash
# Close a GitHub issue

set -euo pipefail

ISSUE_ID="$1"
CLOSE_COMMENT="${2:-Closed by FABER workflow}"
WORK_ID="${3:-}"

# Validate inputs
if [ -z "$ISSUE_ID" ]; then
    echo "Error: ISSUE_ID required" >&2
    exit 2
fi

# Check authentication
if ! gh auth status >/dev/null 2>&1; then
    echo "Error: GitHub authentication failed" >&2
    exit 11
fi

# Close the issue
if ! gh issue close "$ISSUE_ID" --comment "$CLOSE_COMMENT" 2>/dev/null; then
    echo "Error: Failed to close issue #$ISSUE_ID" >&2
    exit 1
fi

# Fetch updated issue to confirm
issue_json=$(gh issue view "$ISSUE_ID" --json number,state,closedAt,url)

# Output normalized JSON
echo "$issue_json" | jq -c '{
  id: .number | tostring,
  identifier: ("#" + (.number | tostring)),
  state: (.state | ascii_downcase),
  closedAt: .closedAt,
  url: .url,
  platform: "github"
}'

exit 0
```

**Exit Codes:**
- 0: Success
- 1: General error (issue close failed)
- 2: Invalid arguments
- 10: Issue not found
- 11: Authentication error

### 6.3 handler-work-tracker-jira

**Status:** Future implementation (Phase 5)

**Access Method:** Jira REST API v3
**Authentication:** Email + API token (Basic Auth)
**Rate Limits:** ~10 requests/second (varies by plan)

#### Key Differences from GitHub

1. **Issue IDs:** Keys not numbers (e.g., "PROJ-123")
2. **State Management:** Workflow transitions, not direct state changes
3. **Comment Format:** Atlassian Document Format (ADF), not markdown
4. **Classifications:** Native issue types (Bug, Story, Task, Epic)

#### Special Requirements

**Markdown → ADF Conversion:**
```bash
# work-common/markdown-to-adf.sh
# Converts markdown to Atlassian Document Format
# Required for create-comment operation

markdown_text="$1"

# Simple conversion (expand as needed)
cat <<EOF
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [
        {
          "type": "text",
          "text": "$markdown_text"
        }
      ]
    }
  ]
}
EOF
```

**State Transitions:**
```bash
# update-state.sh must find valid transition
# Cannot directly set state, must transition through workflow

# 1. GET /issue/{key}/transitions to list available
# 2. Find transition ID for desired state
# 3. POST /issue/{key}/transitions with transition ID
```

#### Example Script Signatures

```bash
# Jira uses keys instead of numeric IDs
./scripts/fetch-issue.sh "PROJ-123"

# Comments require ADF format
./scripts/create-comment.sh "PROJ-123" "work-id" "author" "Message text"
# → Internally converts markdown to ADF

# State changes are transitions
./scripts/update-state.sh "PROJ-123" "in_progress"
# → Finds "Start Progress" transition and executes
```

### 6.4 handler-work-tracker-linear

**Status:** Future implementation (Phase 6)

**Access Method:** GraphQL API
**Authentication:** API key
**Rate Limits:** ~1,500 requests/hour (soft limit)

#### Key Differences from GitHub

1. **IDs:** UUIDs internally, human-readable identifiers externally (TEAM-123)
2. **Labels:** Use UUIDs not names (must lookup first)
3. **States:** Team-specific workflows
4. **Priority:** Numeric 0-4 (0=none, 1=urgent, 4=low)

#### Special Requirements

**Label UUID Lookup:**
```bash
# add-label.sh must first find label UUID
label_name="bug"

# Query team's labels
label_uuid=$(curl -X POST "https://api.linear.app/graphql" \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -d '{
    "query": "query { team(id: \"...\") { labels { nodes { id name } } } }"
  }' | jq -r ".data.team.labels.nodes[] | select(.name == \"$label_name\") | .id")

# Then use UUID in issueAddLabel mutation
```

**State Lookup:**
```bash
# update-state.sh must find state UUID for team
target_state="In Progress"

# Query team's workflow states
state_uuid=$(curl -X POST "https://api.linear.app/graphql" \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -d '{
    "query": "query { team(id: \"...\") { states { nodes { id name } } } }"
  }' | jq -r ".data.team.states.nodes[] | select(.name == \"$target_state\") | .id")
```

#### GraphQL Mutations

```graphql
# Create issue
mutation CreateIssue($teamId: String!, $title: String!, $description: String) {
  issueCreate(input: {
    teamId: $teamId,
    title: $title,
    description: $description
  }) {
    issue {
      id
      identifier
      url
    }
  }
}

# Close issue
mutation CloseIssue($id: String!, $stateId: String!) {
  issueUpdate(id: $id, input: {stateId: $stateId}) {
    issue {
      id
      state {
        name
      }
    }
  }
}
```

---

## 7. Configuration

### 7.1 Configuration Location

**Path:** `.faber/plugins/work/config.json`

**Not committed to git** (contains platform-specific settings, possibly sensitive)

**Template:** `plugins/work/config/config.example.json` (committed)

### 7.2 Configuration Schema

```json
{
  "version": "1.0",

  "project": {
    "issue_system": "github",        // "github" | "jira" | "linear"
    "repository": "owner/repo"       // GitHub repo, Jira project, Linear team
  },

  "handlers": {
    "work-tracker": {
      "active": "github",            // Which handler to use

      "github": {
        "owner": "myorg",
        "repo": "my-project",
        "api_url": "https://api.github.com",  // For GitHub Enterprise

        "classification": {
          "feature": ["feature", "enhancement", "story"],
          "bug": ["bug", "fix", "defect"],
          "chore": ["chore", "maintenance", "docs", "test"],
          "patch": ["hotfix", "patch", "urgent", "critical"]
        },

        "states": {
          "open": "OPEN",
          "in_progress": "OPEN",       // Uses label: in-progress
          "in_review": "OPEN",         // Uses label: in-review
          "done": "CLOSED",
          "closed": "CLOSED"
        },

        "labels": {
          "prefix": "faber-",          // Prefix for FABER-managed labels
          "in_progress": "in-progress",
          "completed": "completed",
          "error": "faber-error"
        }
      },

      "jira": {
        "url": "https://mycompany.atlassian.net",
        "project_key": "PROJ",
        "email": "user@example.com",   // For authentication

        "issue_types": {
          "feature": "Story",
          "bug": "Bug",
          "chore": "Task",
          "patch": "Bug"               // With hotfix label
        },

        "states": {
          "open": "To Do",
          "in_progress": "In Progress",
          "in_review": "In Review",
          "done": "Done",
          "closed": "Closed"
        },

        "transitions": {
          "to_progress": "Start Progress",
          "to_review": "Submit for Review",
          "to_done": "Done",
          "to_closed": "Close Issue"
        }
      },

      "linear": {
        "workspace_id": "workspace-uuid",
        "team_id": "team-uuid",
        "team_key": "TEAM",            // Human-readable prefix

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
        },

        "priority_mapping": {
          "urgent": 1,
          "high": 2,
          "normal": 3,
          "low": 4,
          "none": 0
        }
      }
    }
  },

  "defaults": {
    "auto_assign": false,            // Auto-assign issues to bot
    "auto_label": true,              // Auto-add FABER labels
    "close_on_merge": true,          // Close issue when PR merges
    "comment_on_state_change": true  // Post comment when state changes
  }
}
```

### 7.3 Environment Variables

```bash
# GitHub
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# Jira
export JIRA_TOKEN="jira_api_token_here"
export JIRA_EMAIL="user@example.com"

# Linear
export LINEAR_API_KEY="lin_api_xxxxxxxxxxxxxxxxxxxx"
```

### 7.4 Configuration Loading

**Script:** `work-common/scripts/config-loader.sh`

```bash
#!/bin/bash
# Load work plugin configuration

CONFIG_FILE=".faber/plugins/work/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE" >&2
    exit 3
fi

# Validate JSON
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "Error: Invalid JSON in config file" >&2
    exit 3
fi

# Output full config
cat "$CONFIG_FILE"
exit 0
```

**Usage in handlers:**
```bash
# Load config
CONFIG_JSON=$(./work-common/scripts/config-loader.sh) || exit $?

# Extract platform
PLATFORM=$(echo "$CONFIG_JSON" | jq -r '.handlers["work-tracker"].active')

# Extract platform-specific settings
GITHUB_OWNER=$(echo "$CONFIG_JSON" | jq -r '.handlers["work-tracker"].github.owner')
```

---

## 8. Platform Support

### 8.1 GitHub Issues

#### Strengths
- ✅ Excellent CLI tooling (`gh`)
- ✅ Simple, flat data model
- ✅ Fast and responsive
- ✅ Native markdown support
- ✅ Great for open source workflows
- ✅ Free for public repositories

#### Limitations
- ❌ Limited metadata (no custom fields)
- ❌ No native priority/severity
- ❌ Only two states (open/closed)
- ❌ No native time tracking
- ❌ Limited workflow customization

#### Best For
- Open source projects
- Simple issue tracking
- GitHub-native workflows
- Fast iteration

#### Implementation Status
- **Phase 1:** ✅ Basic operations (fetch, comment, label, classify)
- **Phase 2:** ⚠️ State management (close, reopen, list) - IN PROGRESS
- **Phase 3:** 🔲 Advanced (create, update, assign, search)

### 8.2 Jira

#### Strengths
- ✅ Rich metadata and custom fields
- ✅ Powerful workflow engine
- ✅ Enterprise features (sprints, epics, versions)
- ✅ Advanced JQL query language
- ✅ Time tracking and story points
- ✅ Extensive integrations

#### Limitations
- ❌ Complex data model
- ❌ Verbose API responses
- ❌ Slower than GitHub/Linear
- ❌ ADF format for comments (not markdown)
- ❌ Different between Cloud/Server/Data Center
- ❌ Higher cost for teams

#### Best For
- Enterprise organizations
- Complex workflows
- Agile project management
- Detailed reporting needs

#### Implementation Status
- **Phase 5:** 🔲 All operations - FUTURE
- **Requirements:** ADF conversion, workflow transitions, JQL support

### 8.3 Linear

#### Strengths
- ✅ Modern GraphQL API
- ✅ Fast and efficient
- ✅ Native markdown support
- ✅ Great keyboard-driven UI
- ✅ Cycles (sprints) built-in
- ✅ Relations (issue dependencies)
- ✅ Clean, simple interface

#### Limitations
- ❌ GraphQL only (no REST fallback)
- ❌ Limited custom fields vs Jira
- ❌ Newer platform (fewer integrations)
- ❌ UUID-based (requires lookups)
- ❌ Team-specific workflows (more complex)

#### Best For
- Modern development teams
- Fast-paced startups
- Teams that value UX
- GraphQL-familiar developers

#### Implementation Status
- **Phase 6:** 🔲 All operations - FUTURE
- **Requirements:** GraphQL queries, UUID lookups, team state management

### 8.4 Platform Comparison

| Feature | GitHub | Jira | Linear |
|---------|--------|------|--------|
| **API Type** | REST + CLI | REST | GraphQL |
| **Authentication** | Token | Email + Token | API Key |
| **Rate Limits** | 5000/hr | 10/sec | 1500/hr |
| **ID Format** | Number | Key (PROJ-123) | UUID + Identifier |
| **States** | 2 (open/closed) | Custom workflow | Team-specific |
| **Custom Fields** | None | Extensive | Limited |
| **Comments** | Markdown | ADF | Markdown |
| **Cost** | Free (public) | $$$ | $$ |
| **Complexity** | Low | High | Medium |
| **Best For** | OSS, Simple | Enterprise | Modern Teams |

---

## 9. Integration with FABER

### 9.1 FABER Workflow Overview

The work plugin integrates with all FABER workflow phases:

```
Frame → Architect → Build → Evaluate → Release
  ↓         ↓         ↓         ↓          ↓
 WORK     WORK      WORK      WORK       WORK
```

### 9.2 Frame Phase Integration

**Operations Used:**
1. `fetch-issue` - Get work item details
2. `classify-issue` - Determine work type (/bug, /feature, /chore, /patch)
3. `add-label` - Add "faber-in-progress" label
4. `create-comment` - Post "Frame phase started" comment

**Flow:**
```
Frame Manager → work-manager agent
  → issue-fetcher skill → handler-work-tracker-{platform}
  → Returns normalized issue JSON

Frame Manager → work-manager agent
  → issue-classifier skill → handler-work-tracker-{platform}
  → Returns /feature (example)

Frame Manager → work-manager agent
  → label-manager skill → handler-work-tracker-{platform}
  → Adds "faber-in-progress" label

Frame Manager → work-manager agent
  → comment-creator skill → handler-work-tracker-{platform}
  → Posts "🎯 Frame phase started" comment
```

### 9.3 Architect, Build, Evaluate Phases

**Operations Used:**
- `create-comment` - Post phase status updates

**Example Comments:**
```markdown
🏗️ **Phase**: Architect
Status: Complete

Architecture document created at: `.faber/sessions/{work_id}/architect/architecture.md`

Work ID: `{work_id}`
```

### 9.4 Release Phase Integration

**Operations Used:**
1. `remove-label` - Remove "faber-in-progress"
2. `add-label` - Add "faber-completed"
3. `create-comment` - Post "Release phase complete" with PR link
4. `close-issue` - **CRITICAL** - Actually close the issue

**Current Bug:**
- Release manager calls `work-manager "update ${source_id} closed ${work_id}"`
- But `update` operation only posts a comment
- Issue remains OPEN after workflow completes

**Fix:**
- Release manager calls `work-manager "close ${source_id} 'Closed by FABER' ${work_id}"`
- `close` operation routes to state-manager skill
- state-manager invokes handler close-issue.sh
- Issue actually closes

**Fixed Flow:**
```
Release Manager → work-manager agent
  → state-manager skill (operation: close-issue)
  → handler-work-tracker-{platform}
  → close-issue.sh executes (gh issue close)
  → Issue state changes to CLOSED
  → Returns success confirmation
```

### 9.5 Configuration in FABER

**In `.faber.config.toml`:**
```toml
[project]
issue_system = "github"  # Tells FABER which system to use

[workflow]
auto_close_issue = true  # Close issue on successful release
```

**FABER reads work plugin config:**
```bash
# frame-manager.md
CONFIG_JSON=$("$SCRIPT_DIR/../skills/work-common/scripts/config-loader.sh")
ISSUE_SYSTEM=$(echo "$CONFIG_JSON" | jq -r '.project.issue_system')
```

---

## 10. Implementation Phases

### Phase 1: Critical Operations (FABER Required)

**Goal:** Fix critical Release phase bug, enable basic FABER workflows

**Tasks:**
1. ✅ Remove obsolete `plugins/repo/skills/repo-manager/`
2. ⚠️ Refactor `work-manager` agent to pure router (like repo-manager)
3. ⚠️ Create `state-manager` skill
4. ⚠️ Implement `handler-work-tracker-github/scripts/close-issue.sh`
5. ⚠️ Implement `handler-work-tracker-github/scripts/update-state.sh`
6. ⚠️ Test Release phase can actually close issues

**Success Criteria:**
- Release phase successfully closes GitHub issues
- FABER workflows complete end-to-end
- No breaking changes to existing functionality

**Estimated Effort:** 2-3 hours

### Phase 2: Core Skills (Existing Operations)

**Goal:** Refactor existing operations into focused skills

**Tasks:**
1. Create `issue-fetcher` skill (uses existing fetch-issue.sh)
2. Create `issue-classifier` skill (uses existing classify-issue.sh)
3. Create `comment-creator` skill (uses existing create-comment.sh)
4. Create `label-manager` skill (uses existing set-label.sh, add remove-label.sh)
5. Create `handler-work-tracker-github/SKILL.md`
6. Move existing scripts to handler
7. Move existing docs to handler

**Success Criteria:**
- All existing FABER operations still work
- Skills follow plugin standards
- Handler documentation complete

**Estimated Effort:** 3-4 hours

### Phase 3: New Operations (Enhancement)

**Goal:** Add create, update, assign, search capabilities

**Tasks:**
1. Create `issue-creator` skill + create-issue.sh
2. Create `issue-updater` skill + update-issue.sh
3. Implement list-issues.sh for GitHub
4. Create `issue-searcher` skill + search-issues.sh
5. Create `issue-assigner` skill + assign-issue.sh + unassign-issue.sh

**Success Criteria:**
- Can create new issues via work plugin
- Can search and list issues
- Can assign issues to users

**Estimated Effort:** 4-5 hours

### Phase 4: Advanced Features

**Goal:** Add linking, milestones, common utilities

**Tasks:**
1. Create `issue-linker` skill + link-issues.sh
2. Create `milestone-manager` skill + milestone scripts
3. Create `work-common` skill with utilities:
   - config-loader.sh
   - normalize-issue.sh
   - validate-issue-id.sh
   - error-codes.sh
4. Create example config: `config/config.example.json`

**Success Criteria:**
- Can link related issues
- Can manage milestones
- Shared utilities available

**Estimated Effort:** 3-4 hours

### Phase 5: Jira Support

**Goal:** Full Jira integration with all 18 operations

**Tasks:**
1. Create `handler-work-tracker-jira/SKILL.md` (stub → complete)
2. Implement all 18 scripts for Jira REST API
3. Create `work-common/scripts/markdown-to-adf.sh` converter
4. Handle workflow transitions (state management)
5. Handle JQL queries (search/list)
6. Test all operations with Jira Cloud
7. Document Jira-specific configuration

**Success Criteria:**
- All 18 operations work with Jira
- ADF conversion works correctly
- Workflow transitions handled properly

**Estimated Effort:** 10-12 hours

### Phase 6: Linear Support

**Goal:** Full Linear integration with all 18 operations

**Tasks:**
1. Create `handler-work-tracker-linear/SKILL.md` (stub → complete)
2. Implement all 18 scripts using GraphQL
3. Handle label UUID lookups
4. Handle team-specific state management
5. Implement GraphQL queries for search/list
6. Test all operations with Linear
7. Document Linear-specific configuration

**Success Criteria:**
- All 18 operations work with Linear
- GraphQL queries optimized
- UUID lookups work correctly

**Estimated Effort:** 10-12 hours

### Phase 7: Cleanup and Documentation

**Goal:** Remove old structure, complete documentation

**Tasks:**
1. Delete `plugins/work/skills/work-manager/scripts/` directories
2. Delete `plugins/work/skills/work-manager/docs/` directories
3. Update `plugins/work/README.md` with new structure
4. Create migration guide for users
5. Update FABER specs to reference new operations
6. Integration testing across all platforms
7. Performance testing and optimization

**Success Criteria:**
- Old structure removed
- Documentation complete and accurate
- All tests passing

**Estimated Effort:** 4-5 hours

### Total Estimated Effort

- **Phase 1:** 2-3 hours (CRITICAL)
- **Phase 2:** 3-4 hours
- **Phase 3:** 4-5 hours
- **Phase 4:** 3-4 hours
- **Phase 5:** 10-12 hours (Jira)
- **Phase 6:** 10-12 hours (Linear)
- **Phase 7:** 4-5 hours

**Total:** 36-45 hours for complete implementation

**MVP (Phases 1-3):** 9-12 hours

---

## 11. Testing Strategy

### 11.1 Unit Tests (Per Script)

Each handler script must be independently testable:

```bash
# Test GitHub handler scripts
export GITHUB_TOKEN="ghp_..."

# Test fetch-issue
./handler-work-tracker-github/scripts/fetch-issue.sh 123
# Verify: Returns valid JSON with required fields

# Test close-issue
./handler-work-tracker-github/scripts/close-issue.sh 123 "Test close"
# Verify: Issue state changes to CLOSED

# Test create-comment
./handler-work-tracker-github/scripts/create-comment.sh 123 test-id test "Test comment"
# Verify: Comment appears on issue

# Test classify-issue
issue_json=$(./handler-work-tracker-github/scripts/fetch-issue.sh 123)
./handler-work-tracker-github/scripts/classify-issue.sh "$issue_json"
# Verify: Returns /bug, /feature, /chore, or /patch
```

### 11.2 Integration Tests (Skill → Handler)

Test that skills correctly invoke handlers:

```bash
# Test issue-fetcher skill
result=$(claude --agent work-manager '{"operation":"fetch","issue_id":"123"}')
echo "$result" | jq -e '.status == "success"' || exit 1
echo "$result" | jq -e '.result.id' || exit 1

# Test state-manager skill
result=$(claude --agent work-manager '{"operation":"close","issue_id":"123","comment":"Test"}')
echo "$result" | jq -e '.status == "success"' || exit 1
echo "$result" | jq -e '.result.state == "closed"' || exit 1
```

### 11.3 Cross-Platform Tests

Verify normalized output is consistent:

```bash
# Fetch same logical issue from different platforms
github_issue=$(./handler-work-tracker-github/scripts/fetch-issue.sh 123)
jira_issue=$(./handler-work-tracker-jira/scripts/fetch-issue.sh "PROJ-123")
linear_issue=$(./handler-work-tracker-linear/scripts/fetch-issue.sh "TEAM-123")

# All should have required fields
for issue in "$github_issue" "$jira_issue" "$linear_issue"; do
  echo "$issue" | jq -e '.id' || exit 1
  echo "$issue" | jq -e '.title' || exit 1
  echo "$issue" | jq -e '.state' || exit 1
  echo "$issue" | jq -e '.platform' || exit 1
done
```

### 11.4 FABER Workflow Tests

End-to-end testing with FABER:

```bash
# Test complete FABER workflow
/faber run 123 --autonomy guarded

# Verify operations happened:
# 1. Issue was fetched in Frame phase
# 2. Label "faber-in-progress" was added
# 3. Comments were posted in each phase
# 4. Issue was closed in Release phase

# Check issue state
issue=$(gh issue view 123 --json state,labels,comments)
echo "$issue" | jq -e '.state == "CLOSED"' || exit 1
echo "$issue" | jq -e '.labels[] | select(.name == "faber-completed")' || exit 1
```

### 11.5 Mock Adapter (Development)

Create mock handler for testing without real APIs:

```
handler-work-tracker-mock/
├── SKILL.md
└── scripts/
    ├── fetch-issue.sh        # Returns synthetic JSON
    ├── close-issue.sh        # Logs action, returns success
    └── ... (all 18 operations)
```

**Mock fetch-issue.sh:**
```bash
#!/bin/bash
# Mock issue fetcher for testing

ISSUE_ID="$1"

# Return synthetic issue
cat <<EOF
{
  "id": "$ISSUE_ID",
  "identifier": "#$ISSUE_ID",
  "title": "Mock Issue $ISSUE_ID",
  "description": "This is a mock issue for testing",
  "state": "open",
  "labels": ["mock", "test"],
  "assignees": [],
  "author": {"id": "1", "username": "mock-user"},
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "url": "https://example.com/issues/$ISSUE_ID",
  "platform": "mock"
}
EOF

exit 0
```

### 11.6 Error Handling Tests

Verify proper error codes and messages:

```bash
# Test not found
./handler-work-tracker-github/scripts/fetch-issue.sh 999999999
# Expected: Exit code 10, error message to stderr

# Test invalid auth
unset GITHUB_TOKEN
./handler-work-tracker-github/scripts/fetch-issue.sh 123
# Expected: Exit code 11, auth error message

# Test invalid transition
./handler-work-tracker-jira/scripts/update-state.sh "PROJ-123" "invalid_state"
# Expected: Exit code 3, invalid transition error
```

### 11.7 Performance Tests

Benchmark operation speed:

```bash
# Measure fetch-issue latency
time ./handler-work-tracker-github/scripts/fetch-issue.sh 123
# Target: <500ms

# Measure list-issues with 100 results
time ./handler-work-tracker-github/scripts/list-issues.sh --limit 100
# Target: <2s

# Test rate limit handling
for i in {1..100}; do
  ./handler-work-tracker-github/scripts/fetch-issue.sh $i &
done
wait
# Verify: No rate limit errors, proper backoff
```

---

## 12. Examples

### 12.1 Example 1: Fetch and Classify Issue (Frame Phase)

**Scenario:** FABER Frame phase needs to fetch issue details and determine work type

```bash
# Step 1: Fetch issue
issue_json=$(claude --agent work-manager '{
  "operation": "fetch",
  "parameters": {"issue_id": "123"}
}')

# Response:
{
  "status": "success",
  "operation": "fetch",
  "result": {
    "id": "123",
    "identifier": "#123",
    "title": "Fix login page crash on mobile",
    "description": "Users report app crashes when...",
    "state": "open",
    "labels": ["bug", "mobile", "priority-high"],
    "assignees": [],
    "author": {"username": "user123"},
    "createdAt": "2025-01-29T10:00:00Z",
    "updatedAt": "2025-01-29T10:00:00Z",
    "url": "https://github.com/owner/repo/issues/123",
    "platform": "github"
  }
}

# Step 2: Classify issue
work_type=$(claude --agent work-manager '{
  "operation": "classify",
  "parameters": {"issue_json": "..."}
}')

# Response:
{
  "status": "success",
  "operation": "classify",
  "result": {
    "work_type": "/bug",
    "confidence": "high",
    "reason": "Issue has 'bug' label and title contains 'crash'"
  }
}
```

### 12.2 Example 2: Post Status Comment (Any Phase)

**Scenario:** Build phase wants to post a status update

```bash
claude --agent work-manager '{
  "operation": "comment",
  "parameters": {
    "issue_id": "123",
    "work_id": "abc12345",
    "author_context": "build",
    "message": "🏗️ **Phase**: Build\n\nImplementation complete. Running tests...\n\nWork ID: `abc12345`"
  }
}'

# Response:
{
  "status": "success",
  "operation": "comment",
  "result": {
    "comment_id": "987654",
    "comment_url": "https://github.com/owner/repo/issues/123#issuecomment-987654"
  }
}
```

### 12.3 Example 3: Close Issue (Release Phase)

**Scenario:** Release phase completes successfully, close the issue

```bash
claude --agent work-manager '{
  "operation": "close",
  "parameters": {
    "issue_id": "123",
    "close_comment": "✅ **Release Complete**\n\nPR merged: #456\nDeployed to: production\n\nWork ID: `abc12345`",
    "work_id": "abc12345"
  }
}'

# Response:
{
  "status": "success",
  "operation": "close",
  "result": {
    "id": "123",
    "identifier": "#123",
    "state": "closed",
    "closedAt": "2025-01-29T15:30:00Z",
    "url": "https://github.com/owner/repo/issues/123"
  }
}
```

### 12.4 Example 4: Create Follow-up Issue

**Scenario:** During build, identify tech debt that needs separate issue

```bash
claude --agent work-manager '{
  "operation": "create",
  "parameters": {
    "title": "Refactor authentication module",
    "description": "During implementation of #123, discovered auth code needs refactoring:\n\n- Extract validation logic\n- Add unit tests\n- Update documentation\n\nRelated to: #123",
    "labels": ["chore", "tech-debt", "faber-generated"],
    "assignees": []
  }
}'

# Response:
{
  "status": "success",
  "operation": "create",
  "result": {
    "id": "124",
    "identifier": "#124",
    "title": "Refactor authentication module",
    "url": "https://github.com/owner/repo/issues/124"
  }
}
```

### 12.5 Example 5: Batch Query Issues

**Scenario:** Find all open bugs with high priority

```bash
claude --agent work-manager '{
  "operation": "list",
  "parameters": {
    "state": "open",
    "labels": ["bug", "priority-high"],
    "limit": 50
  }
}'

# Response:
{
  "status": "success",
  "operation": "list",
  "result": {
    "issues": [
      {
        "id": "123",
        "identifier": "#123",
        "title": "Fix login page crash on mobile",
        "state": "open",
        "labels": ["bug", "priority-high"],
        ...
      },
      {
        "id": "125",
        "identifier": "#125",
        "title": "Database connection timeout",
        "state": "open",
        "labels": ["bug", "priority-high"],
        ...
      }
    ],
    "count": 2,
    "total": 2
  }
}
```

### 12.6 Example 6: Link Related Issues

**Scenario:** Link a bug to its root cause issue

```bash
claude --agent work-manager '{
  "operation": "link",
  "parameters": {
    "issue_id": "123",
    "related_issue_id": "120",
    "relationship_type": "blocked_by"
  }
}'

# Response:
{
  "status": "success",
  "operation": "link",
  "result": {
    "issue_id": "123",
    "related_issue_id": "120",
    "relationship": "blocked_by",
    "message": "Issue #123 is blocked by #120"
  }
}
```

---

## 13. Migration Guide

### 13.1 For Users: Migrating to v2.0

**Breaking Changes:**
- Configuration moved from `.faber.config.toml` work section to `.faber/plugins/work/config.json`
- Agent operation format changed from string to JSON

**Migration Steps:**

1. **Create new config file:**
```bash
# Create directory
mkdir -p .faber/plugins/work

# Copy template
cp plugins/work/config/config.example.json .faber/plugins/work/config.json

# Edit with your settings
vim .faber/plugins/work/config.json
```

2. **Update `.faber.config.toml`:**
```toml
# OLD (remove):
[work]
system = "github"
owner = "myorg"
repo = "myrepo"

# NEW (keep minimal reference):
[project]
issue_system = "github"  # Work plugin reads .faber/plugins/work/config.json
```

3. **Test operations:**
```bash
# Verify fetch works
claude --agent work-manager '{"operation":"fetch","parameters":{"issue_id":"123"}}'

# Run FABER workflow
/faber run 123 --autonomy dry-run
```

4. **Update any custom scripts:**
```bash
# OLD agent invocation:
claude --agent work-manager "fetch 123"

# NEW agent invocation:
claude --agent work-manager '{"operation":"fetch","parameters":{"issue_id":"123"}}'
```

### 13.2 For Developers: Migrating Custom Integrations

**If you built custom skills using work-manager:**

1. **Update skill invocations:**
```bash
# OLD (bash string):
./agents/work-manager.md "fetch 123"

# NEW (JSON):
./agents/work-manager.md '{"operation":"fetch","parameters":{"issue_id":"123"}}'
```

2. **Use new focused skills:**
```markdown
# OLD:
USE SKILL work-manager
Operation: fetch 123

# NEW:
USE SKILL issue-fetcher
Parameters: {"issue_id": "123"}
```

3. **Handle normalized responses:**
```javascript
// Response format is now standardized
{
  "status": "success|failure",
  "operation": "operation_name",
  "result": { /* operation-specific data */ },
  "error": "error message if failure"
}
```

### 13.3 Backward Compatibility

**Temporary Compatibility Layer:**

For Phase 1-2 implementation, maintain backward compatibility:

```bash
# work-manager agent detects old format and converts
if [[ "$1" =~ ^(fetch|comment|classify|label)\ .+ ]]; then
  # OLD FORMAT: "fetch 123"
  operation=$(echo "$1" | cut -d' ' -f1)
  params=$(echo "$1" | cut -d' ' -f2-)

  # Convert to new format
  new_format=$(convert_to_json "$operation" "$params")

  # Process new format
  process_operation "$new_format"
fi
```

**Deprecation Timeline:**
- **v2.0.0:** New format introduced, old format deprecated
- **v2.1.0:** Warning logged for old format usage
- **v2.2.0:** Old format removed

---

## 14. Future Enhancements

### 14.1 Additional Platforms

**Azure DevOps:**
- REST API similar to Jira
- Work items instead of issues
- Different terminology (Boards, Sprints, Backlogs)
- **Effort:** 10-12 hours

**GitLab Issues:**
- Similar to GitHub but with different API
- More features than GitHub (weights, time tracking)
- **Effort:** 8-10 hours

**Asana:**
- Task management, not issue tracking
- Different data model (projects, sections, tasks)
- **Effort:** 12-15 hours

### 14.2 Advanced Features

**Custom Fields Support:**
- Allow platform-specific custom fields in normalized model
- Configuration for field mappings
- Validation for required fields

**Attachments:**
- Upload files to issues
- Download attachments from issues
- Platform-specific: GitHub Assets, Jira Attachments, Linear File URLs

**Batch Operations:**
- Bulk create issues from template
- Bulk update labels across multiple issues
- Parallel processing for performance

**Webhooks:**
- Listen for issue updates
- Trigger FABER workflows automatically
- React to external changes

**Advanced Search:**
- Complex query builder
- Saved search templates
- Cross-platform search aggregation

### 14.3 Performance Optimizations

**Caching Layer:**
```bash
# Cache issue metadata locally
CACHE_DIR=".faber/plugins/work/cache"

# fetch-issue checks cache first
if [ -f "$CACHE_DIR/$ISSUE_ID.json" ]; then
  # Check if cache is fresh (< 5 minutes)
  if [ $(($(date +%s) - $(stat -f %m "$CACHE_DIR/$ISSUE_ID.json"))) -lt 300 ]; then
    cat "$CACHE_DIR/$ISSUE_ID.json"
    exit 0
  fi
fi

# Otherwise fetch from API and cache
```

**Request Batching:**
- Batch multiple operations into single API calls
- Reduce API requests for list operations
- GraphQL batch queries for Linear

**Rate Limit Management:**
- Automatic retry with exponential backoff
- Rate limit tracking and warnings
- Queue operations when approaching limits

### 14.4 Developer Experience

**CLI Tool:**
```bash
# Standalone CLI for work plugin
work-cli fetch 123
work-cli close 123 "Done"
work-cli list --state open --label bug

# Config management
work-cli config init
work-cli config validate
work-cli config test-auth
```

**Interactive Mode:**
```bash
# Interactive issue selection
work-cli interactive

# UI:
# [1] #123 - Fix login crash (bug, priority-high)
# [2] #124 - Add export feature (feature)
# [3] #125 - Update docs (chore)
# Select issue: 1

# [F]etch [C]lose [U]pdate [L]ist [Q]uit
# Action: F
# Fetching issue #123...
```

**VS Code Extension:**
- Issue viewer in sidebar
- Quick actions (close, comment, label)
- FABER workflow status
- Configuration editor

### 14.5 Monitoring & Observability

**Operation Metrics:**
- Track operation counts
- Measure latencies
- Identify failures

**Dashboard:**
```json
{
  "work_plugin_metrics": {
    "operations_today": 1247,
    "operations_by_type": {
      "fetch": 450,
      "comment": 380,
      "close": 120,
      "create": 95
    },
    "average_latency_ms": {
      "github": 245,
      "jira": 890,
      "linear": 320
    },
    "errors_24h": 12,
    "rate_limit_warnings": 3
  }
}
```

**Logging:**
- Structured logs for all operations
- Correlation IDs for FABER workflows
- Platform-specific metrics

---

## Appendix A: Decision Log

### A.1 Why Focused Skills vs Monolithic?

**Decision:** Break into 11 focused skills instead of one monolithic work-manager skill

**Reasoning:**
1. Follows repo plugin pattern (proven successful)
2. Reduces context usage (load only needed skills)
3. Easier to test and maintain
4. Clearer separation of concerns
5. Follows FRACTARY-PLUGIN-STANDARDS.md

**Trade-offs:**
- More directories (15 vs 1)
- More SKILL.md files to maintain
- Slightly more complex routing

**Result:** Better maintainability and consistency outweigh structural complexity

### A.2 Why Handler Pattern?

**Decision:** Centralize platform-specific logic in handler skills

**Reasoning:**
1. Skills remain platform-agnostic
2. Easy to add new platforms (just add handler)
3. Platform quirks isolated to handlers
4. Same pattern as repo plugin
5. Testable independently

**Alternative Considered:** Platform detection in each skill
**Rejected Because:** Would duplicate platform logic across 11 skills

### A.3 Why External Scripts?

**Decision:** Execute operations in shell scripts via Bash tool

**Reasoning:**
1. Keeps deterministic operations out of LLM context
2. 55-60% context reduction
3. Scripts testable independently
4. Easier to debug and iterate
5. Standard practice in all Fractary plugins

**Alternative Considered:** Inline operations in SKILL.md
**Rejected Because:** Massive context usage, harder to test

### A.4 Why JSON Request/Response?

**Decision:** Use structured JSON for agent requests/responses

**Reasoning:**
1. Type-safe parameters
2. Easy to validate
3. Future-proof (easy to add fields)
4. Consistent with repo plugin
5. Better error messages

**Alternative Considered:** Positional string arguments ("fetch 123")
**Rejected Because:** Ambiguous, hard to extend, no validation

---

## Appendix B: Glossary

- **Handler:** Platform-specific skill that executes operations via scripts
- **Universal Operation:** Operation supported across all platforms
- **Normalized JSON:** Common data format across platforms
- **Work Type:** Classification of issue (/bug, /feature, /chore, /patch)
- **State Mapping:** Translation between universal states and platform states
- **ADF:** Atlassian Document Format (Jira's comment format)
- **JQL:** Jira Query Language
- **UUID:** Universally Unique Identifier (used by Linear)
- **GraphQL:** Query language used by Linear API
- **gh CLI:** GitHub's official command-line interface

---

## Appendix C: References

- **FRACTARY-PLUGIN-STANDARDS.md:** Plugin architecture patterns
- **plugins/repo/:** Reference implementation for focused skills + handlers
- **GitHub Issues API:** https://docs.github.com/en/rest/issues
- **Jira REST API:** https://developer.atlassian.com/cloud/jira/platform/rest/v3/
- **Linear GraphQL API:** https://developers.linear.app/docs/graphql/working-with-the-graphql-api

---

**Document Status:** ✅ COMPLETE
**Next Steps:** Begin Phase 1 implementation
**Owner:** Fractary Team
**Last Review:** 2025-01-29
