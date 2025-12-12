# SPEC-00017: Work Tracking SDK

| Field | Value |
|-------|-------|
| **Status** | Draft |
| **Created** | 2025-12-11 |
| **Author** | Claude (with human direction) |
| **Related** | SPEC-00016-sdk-architecture, plugins/work/ |

## 1. Executive Summary

This specification details the **Work Tracking SDK** implementation within `@fractary/core`. It maps all 12 skills and 27 commands from the current `fractary-work` plugin to SDK methods and CLI commands.

### 1.1 Scope

- Implementation of `WorkProvider` interface (defined in SPEC-00016)
- Platform handlers: GitHub Issues, Jira Cloud, Linear
- All operations: issues, comments, labels, milestones, state management
- CLI command mappings
- Plugin migration path

### 1.2 Current Plugin Summary

| Metric | Value |
|--------|-------|
| Skills | 12 |
| Commands | 27 |
| Handlers | 3 (GitHub, Jira, Linear) |
| Operations | 15+ |

## 2. SDK Implementation

### 2.1 Module Structure

```
@fractary/core/
└── work/
    ├── types.ts              # WorkProvider interface, data types
    ├── index.ts              # Public exports
    ├── registry.ts           # Provider registry
    ├── classifier.ts         # Work type classification
    ├── github.ts             # GitHub Issues implementation
    ├── jira.ts               # Jira Cloud implementation
    └── linear.ts             # Linear implementation
```

### 2.2 Provider Registry

```typescript
// work/registry.ts

import { WorkProvider } from './types';
import { GitHubWorkProvider } from './github';
import { JiraWorkProvider } from './jira';
import { LinearWorkProvider } from './linear';

export type WorkProviderType = 'github' | 'jira' | 'linear';

export interface WorkProviderConfig {
  provider: WorkProviderType;
  // Provider-specific config
  github?: {
    token: string;
    owner: string;
    repo: string;
  };
  jira?: {
    baseUrl: string;
    email: string;
    apiToken: string;
    projectKey: string;
  };
  linear?: {
    apiKey: string;
    teamId: string;
  };
}

export function createWorkProvider(config: WorkProviderConfig): WorkProvider {
  switch (config.provider) {
    case 'github':
      if (!config.github) throw new ConfigurationError('GitHub config required');
      return new GitHubWorkProvider(config.github);
    case 'jira':
      if (!config.jira) throw new ConfigurationError('Jira config required');
      return new JiraWorkProvider(config.jira);
    case 'linear':
      if (!config.linear) throw new ConfigurationError('Linear config required');
      return new LinearWorkProvider(config.linear);
    default:
      throw new ConfigurationError(`Unknown provider: ${config.provider}`);
  }
}
```

## 3. Operation Mappings

### 3.1 Issue Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `issue-fetcher` | `getWorkItem(id)` | `fractary work issue fetch <id>` |
| `issue-creator` | `createWorkItem(input)` | `fractary work issue create` |
| `issue-updater` | `updateWorkItem(id, updates)` | `fractary work issue update <id>` |
| `issue-searcher` (search) | `searchWorkItems(query)` | `fractary work issue search "<query>"` |
| `issue-searcher` (list) | `listWorkItems(filters)` | `fractary work issue list` |

#### 3.1.1 getWorkItem

**Current Plugin**: `issue-fetcher` skill

**SDK Method**:
```typescript
async getWorkItem(id: string): Promise<WorkItem>
```

**CLI**:
```bash
fractary work issue fetch <id> [options]

Options:
  --format <format>    Output format: json, table, markdown (default: table)
  --include-comments   Include comments in output
  --json               Shorthand for --format json
```

**Implementation Notes**:
- Normalizes response to universal `WorkItem` schema
- Fetches issue description + all comments
- Extracts labels, assignees, milestone
- Maps platform-specific states to universal states

**Platform Mapping (GitHub)**:
```typescript
// github.ts
async getWorkItem(id: string): Promise<WorkItem> {
  const issue = await this.octokit.issues.get({
    owner: this.owner,
    repo: this.repo,
    issue_number: parseInt(id),
  });

  return {
    id: issue.data.number.toString(),
    key: `#${issue.data.number}`,
    title: issue.data.title,
    description: issue.data.body || '',
    status: issue.data.state,
    state: this.mapState(issue.data.state, issue.data.state_reason),
    type: this.classifyType(issue.data),
    labels: issue.data.labels.map(l => typeof l === 'string' ? l : l.name),
    assignee: issue.data.assignee?.login,
    assignees: issue.data.assignees?.map(a => a.login),
    reporter: issue.data.user?.login,
    milestone: issue.data.milestone?.title,
    createdAt: new Date(issue.data.created_at),
    updatedAt: new Date(issue.data.updated_at),
    closedAt: issue.data.closed_at ? new Date(issue.data.closed_at) : undefined,
    url: issue.data.html_url,
  };
}
```

#### 3.1.2 createWorkItem

**Current Plugin**: `issue-creator` skill

**SDK Method**:
```typescript
async createWorkItem(input: CreateWorkItemInput): Promise<WorkItem>
```

**CLI**:
```bash
fractary work issue create [options]

Options:
  --title <title>        Issue title (required)
  --body <body>          Issue description
  --type <type>          Work type: feature, bug, chore, patch
  --labels <labels>      Comma-separated labels
  --assignees <users>    Comma-separated assignees
  --milestone <name>     Milestone name or ID
  --json                 Output as JSON
```

**Implementation Notes**:
- Maps `type` to platform-specific labels (bug → "bug" label)
- Supports comma-separated labels and assignees
- Returns full WorkItem with generated ID and URL

#### 3.1.3 updateWorkItem

**Current Plugin**: `issue-updater` skill

**SDK Method**:
```typescript
async updateWorkItem(id: string, updates: UpdateWorkItemInput): Promise<WorkItem>
```

**CLI**:
```bash
fractary work issue update <id> [options]

Options:
  --title <title>        New title
  --body <body>          New description
  --labels <labels>      Replace labels (comma-separated)
  --assignees <users>    Replace assignees (comma-separated)
  --milestone <name>     Set milestone (or "none" to remove)
  --json                 Output as JSON
```

**Implementation Notes**:
- At least one update field required
- Partial updates (only specified fields change)
- Returns updated WorkItem

#### 3.1.4 searchWorkItems

**Current Plugin**: `issue-searcher` skill (search operation)

**SDK Method**:
```typescript
async searchWorkItems(query: WorkItemQuery): Promise<PaginatedResult<WorkItem>>
```

**CLI**:
```bash
fractary work issue search "<query>" [options]

Options:
  --limit <n>            Max results (default: 20)
  --json                 Output as JSON
```

**Implementation Notes**:
- Full-text search across title and description
- Platform-specific query syntax supported
- Returns paginated results

#### 3.1.5 listWorkItems

**Current Plugin**: `issue-searcher` skill (list operation)

**SDK Method**:
```typescript
async listWorkItems(filters: WorkItemFilters): Promise<PaginatedResult<WorkItem>>
```

**CLI**:
```bash
fractary work issue list [options]

Options:
  --state <state>        Filter: open, closed, all (default: open)
  --labels <labels>      Filter by labels (comma-separated)
  --assignee <user>      Filter by assignee
  --milestone <name>     Filter by milestone
  --limit <n>            Max results (default: 20)
  --since <date>         Created after date (ISO format)
  --json                 Output as JSON
```

### 3.2 State Management Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `state-manager` (close) | `closeWorkItem(id, comment?)` | `fractary work state close <id>` |
| `state-manager` (reopen) | `reopenWorkItem(id, comment?)` | `fractary work state reopen <id>` |
| `state-manager` (transition) | `transitionWorkItem(id, state)` | `fractary work state transition <id> <state>` |

#### 3.2.1 closeWorkItem

**Current Plugin**: `state-manager` skill (close operation)

**SDK Method**:
```typescript
async closeWorkItem(id: string, comment?: string): Promise<WorkItem>
```

**CLI**:
```bash
fractary work state close <id> [options]

Options:
  --comment <text>       Closing comment
  --work-id <id>         Work ID for FABER metadata
  --json                 Output as JSON
```

**Implementation Notes**:
- Optionally adds closing comment
- Critical for FABER Release phase
- Returns updated WorkItem with closedAt timestamp

#### 3.2.2 reopenWorkItem

**Current Plugin**: `state-manager` skill (reopen operation)

**SDK Method**:
```typescript
async reopenWorkItem(id: string, comment?: string): Promise<WorkItem>
```

**CLI**:
```bash
fractary work state reopen <id> [options]

Options:
  --comment <text>       Reopen comment
  --json                 Output as JSON
```

#### 3.2.3 transitionWorkItem

**Current Plugin**: `state-manager` skill (update-state operation)

**SDK Method**:
```typescript
async transitionWorkItem(id: string, state: string): Promise<WorkItem>
```

**CLI**:
```bash
fractary work state transition <id> <state> [options]

Arguments:
  <state>                Target state: open, in_progress, in_review, done, closed

Options:
  --json                 Output as JSON
```

**Implementation Notes**:
- Maps universal states to platform-specific states
- GitHub: open/closed only (state_reason for nuance)
- Jira: Full workflow transitions
- Linear: Status ID mapping

### 3.3 Assignment Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `issue-assigner` (assign) | `assignWorkItem(id, assignee)` | `fractary work issue assign <id> <user>` |
| `issue-assigner` (unassign) | `unassignWorkItem(id, assignee?)` | `fractary work issue unassign <id> [user]` |

#### 3.3.1 assignWorkItem

**Current Plugin**: `issue-assigner` skill (assign operation)

**SDK Method**:
```typescript
async assignWorkItem(id: string, assignee: string): Promise<WorkItem>
```

**CLI**:
```bash
fractary work issue assign <id> <user> [options]

Options:
  --json                 Output as JSON
```

#### 3.3.2 unassignWorkItem

**Current Plugin**: `issue-assigner` skill (unassign operation)

**SDK Method**:
```typescript
async unassignWorkItem(id: string, assignee?: string): Promise<WorkItem>
```

**CLI**:
```bash
fractary work issue unassign <id> [user] [options]

Arguments:
  [user]                 Specific user to unassign, or "all" for all assignees

Options:
  --json                 Output as JSON
```

### 3.4 Comment Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `comment-creator` | `addComment(workItemId, comment, metadata?)` | `fractary work comment create <id> "<text>"` |
| `comment-lister` | `listComments(workItemId, options?)` | `fractary work comment list <id>` |

#### 3.4.1 addComment

**Current Plugin**: `comment-creator` skill

**SDK Method**:
```typescript
async addComment(
  workItemId: string,
  comment: string,
  metadata?: CommentMetadata
): Promise<Comment>
```

**CLI**:
```bash
fractary work comment create <id> "<text>" [options]

Options:
  --work-id <id>         Work ID for FABER metadata
  --author-context <ctx> FABER context: frame, architect, build, evaluate, release
  --json                 Output as JSON
```

**Implementation Notes**:
- Supports markdown formatting
- FABER metadata footer when work_id + author_context provided
- Standalone comments without metadata also supported

**FABER Comment Format**:
```markdown
<user comment>

---
*FABER Context: Build phase for #123*
```

#### 3.4.2 listComments

**Current Plugin**: `comment-lister` skill

**SDK Method**:
```typescript
async listComments(
  workItemId: string,
  options?: ListCommentsOptions
): Promise<PaginatedResult<Comment>>
```

**CLI**:
```bash
fractary work comment list <id> [options]

Options:
  --limit <n>            Max comments (default: 20)
  --since <date>         Comments after date (ISO format)
  --json                 Output as JSON
```

### 3.5 Label Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `label-manager` (add) | `addLabel(workItemId, label)` | `fractary work label add <id> <label>` |
| `label-manager` (remove) | `removeLabel(workItemId, label)` | `fractary work label remove <id> <label>` |
| `label-manager` (set) | `setLabels(workItemId, labels)` | `fractary work label set <id> <labels>` |
| `label-manager` (list) | `listLabels()` | `fractary work label list` |

#### 3.5.1 addLabel

**SDK Method**:
```typescript
async addLabel(workItemId: string, label: string): Promise<void>
```

**CLI**:
```bash
fractary work label add <id> <label>
```

#### 3.5.2 removeLabel

**SDK Method**:
```typescript
async removeLabel(workItemId: string, label: string): Promise<void>
```

**CLI**:
```bash
fractary work label remove <id> <label>
```

#### 3.5.3 setLabels

**SDK Method**:
```typescript
async setLabels(workItemId: string, labels: string[]): Promise<void>
```

**CLI**:
```bash
fractary work label set <id> <labels>

Arguments:
  <labels>               Comma-separated labels (replaces all existing)
```

#### 3.5.4 listLabels

**SDK Method**:
```typescript
async listLabels(): Promise<Label[]>
```

**CLI**:
```bash
fractary work label list [options]

Options:
  --json                 Output as JSON
```

**Common FABER Labels**:
- `faber-in-progress` - FABER workflow active
- `faber-completed` - FABER workflow completed

### 3.6 Milestone Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `milestone-manager` (create) | `createMilestone(input)` | `fractary work milestone create` |
| `milestone-manager` (update) | `updateMilestone(id, updates)` | `fractary work milestone update <id>` |
| `milestone-manager` (assign) | `assignMilestone(workItemId, milestoneId)` | `fractary work milestone set <id> <milestone>` |
| `milestone-manager` (remove) | `removeMilestone(workItemId)` | `fractary work milestone remove <id>` |
| `milestone-manager` (list) | `listMilestones(filters?)` | `fractary work milestone list` |

#### 3.6.1 createMilestone

**SDK Method**:
```typescript
async createMilestone(input: CreateMilestoneInput): Promise<Milestone>
```

**CLI**:
```bash
fractary work milestone create [options]

Options:
  --title <title>        Milestone title (required)
  --description <text>   Description
  --due-date <date>      Due date (YYYY-MM-DD format)
  --json                 Output as JSON
```

#### 3.6.2 updateMilestone

**SDK Method**:
```typescript
async updateMilestone(id: string, updates: UpdateMilestoneInput): Promise<Milestone>
```

**CLI**:
```bash
fractary work milestone update <id> [options]

Options:
  --title <title>        New title
  --description <text>   New description
  --due-date <date>      New due date
  --state <state>        State: open, closed
  --json                 Output as JSON
```

#### 3.6.3 assignMilestone

**SDK Method**:
```typescript
async assignMilestone(workItemId: string, milestoneId: string): Promise<WorkItem>
```

**CLI**:
```bash
fractary work milestone set <issue-id> <milestone>

Arguments:
  <milestone>            Milestone name or ID
```

#### 3.6.4 removeMilestone

**SDK Method**:
```typescript
async removeMilestone(workItemId: string): Promise<WorkItem>
```

**CLI**:
```bash
fractary work milestone remove <issue-id>
```

#### 3.6.5 listMilestones

**SDK Method**:
```typescript
async listMilestones(filters?: MilestoneFilters): Promise<PaginatedResult<Milestone>>
```

**CLI**:
```bash
fractary work milestone list [options]

Options:
  --state <state>        Filter: open, closed, all (default: open)
  --json                 Output as JSON
```

### 3.7 Classification

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `issue-classifier` | `classifyWorkItem(workItem)` | (internal, used by other operations) |

#### 3.7.1 classifyWorkItem

**Current Plugin**: `issue-classifier` skill

**SDK Method**:
```typescript
classifyWorkItem(workItem: WorkItem): WorkType
```

**Implementation**:
```typescript
// classifier.ts

export function classifyWorkItem(workItem: WorkItem): WorkType {
  const labels = workItem.labels.map(l => l.toLowerCase());
  const title = workItem.title.toLowerCase();
  const description = (workItem.description || '').toLowerCase();

  // Label-based classification (highest priority)
  if (labels.some(l => ['bug', 'defect', 'hotfix'].includes(l))) {
    return 'bug';
  }
  if (labels.some(l => ['feature', 'enhancement'].includes(l))) {
    return 'feature';
  }
  if (labels.some(l => ['chore', 'maintenance', 'refactor'].includes(l))) {
    return 'chore';
  }
  if (labels.some(l => ['patch', 'quick-fix'].includes(l))) {
    return 'patch';
  }

  // Title-based classification
  if (/^(fix|bug|hotfix|patch)[\s:\-]/i.test(title)) {
    return 'bug';
  }
  if (/^(feat|feature|add|implement)[\s:\-]/i.test(title)) {
    return 'feature';
  }
  if (/^(chore|refactor|cleanup|maintain)[\s:\-]/i.test(title)) {
    return 'chore';
  }

  // Default
  return 'feature';
}
```

**Work Types**:
- `feature` - New functionality
- `bug` - Defect fix
- `chore` - Maintenance, refactoring
- `patch` - Quick fix, minor update

## 4. Platform Implementations

### 4.1 GitHub Issues

**File**: `@fractary/core/work/github.ts`

**Dependencies**:
- `@octokit/rest` - GitHub API client

**Configuration**:
```typescript
interface GitHubWorkConfig {
  token: string;           // GITHUB_TOKEN
  owner: string;           // Repository owner
  repo: string;            // Repository name
}
```

**State Mapping**:
```typescript
// GitHub states: open, closed
// Universal states: open, in_progress, in_review, done, closed

function mapToUniversalState(state: string, stateReason?: string): WorkItemState {
  if (state === 'open') return 'open';
  if (state === 'closed') {
    if (stateReason === 'completed') return 'done';
    if (stateReason === 'not_planned') return 'closed';
    return 'closed';
  }
  return 'open';
}

function mapToPlatformState(state: WorkItemState): { state: 'open' | 'closed', stateReason?: string } {
  switch (state) {
    case 'open':
    case 'in_progress':
    case 'in_review':
      return { state: 'open' };
    case 'done':
      return { state: 'closed', stateReason: 'completed' };
    case 'closed':
      return { state: 'closed', stateReason: 'not_planned' };
  }
}
```

### 4.2 Jira Cloud

**File**: `@fractary/core/work/jira.ts`

**Dependencies**:
- `jira.js` - Jira API client

**Configuration**:
```typescript
interface JiraWorkConfig {
  baseUrl: string;         // https://company.atlassian.net
  email: string;           // User email
  apiToken: string;        // API token
  projectKey: string;      // PROJ
}
```

**State Mapping**:
```typescript
// Jira has configurable workflows
// Map common status categories to universal states

function mapJiraStatus(status: JiraStatus): WorkItemState {
  const category = status.statusCategory.key;
  switch (category) {
    case 'new': return 'open';
    case 'indeterminate': return 'in_progress';
    case 'done': return 'done';
    default: return 'open';
  }
}
```

**Type Mapping**:
```typescript
function mapJiraType(issueType: string): WorkType {
  const type = issueType.toLowerCase();
  if (['bug', 'defect'].includes(type)) return 'bug';
  if (['story', 'feature', 'improvement'].includes(type)) return 'feature';
  if (['task', 'sub-task'].includes(type)) return 'chore';
  return 'feature';
}
```

### 4.3 Linear

**File**: `@fractary/core/work/linear.ts`

**Dependencies**:
- `@linear/sdk` - Linear API client

**Configuration**:
```typescript
interface LinearWorkConfig {
  apiKey: string;          // LINEAR_API_KEY
  teamId: string;          // Team identifier
}
```

**State Mapping**:
```typescript
// Linear has team-configurable states
// Map by state type

function mapLinearState(state: LinearState): WorkItemState {
  switch (state.type) {
    case 'backlog': return 'open';
    case 'unstarted': return 'open';
    case 'started': return 'in_progress';
    case 'completed': return 'done';
    case 'canceled': return 'closed';
    default: return 'open';
  }
}
```

## 5. CLI Implementation

### 5.1 Command Structure

```
@fractary/cli/
└── src/tools/work/
    ├── index.ts              # Work command group
    └── commands/
        ├── issue/
        │   ├── fetch.ts
        │   ├── create.ts
        │   ├── update.ts
        │   ├── search.ts
        │   ├── list.ts
        │   ├── assign.ts
        │   └── unassign.ts
        ├── comment/
        │   ├── create.ts
        │   └── list.ts
        ├── label/
        │   ├── add.ts
        │   ├── remove.ts
        │   ├── set.ts
        │   └── list.ts
        ├── milestone/
        │   ├── create.ts
        │   ├── update.ts
        │   ├── set.ts
        │   ├── remove.ts
        │   ├── list.ts
        │   └── close.ts
        ├── state/
        │   ├── close.ts
        │   ├── reopen.ts
        │   └── transition.ts
        └── init.ts
```

### 5.2 Example Command Implementation

```typescript
// src/tools/work/commands/issue/fetch.ts

import { Command } from 'commander';
import chalk from 'chalk';
import { createWorkProvider, loadWorkConfig } from '@fractary/core/work';
import { formatTable, formatJson } from '../../utils/output';

export function fetchCommand(): Command {
  return new Command('fetch')
    .description('Fetch work item details')
    .argument('<id>', 'Work item ID')
    .option('--format <format>', 'Output format: json, table, markdown', 'table')
    .option('--include-comments', 'Include comments in output')
    .option('--json', 'Shorthand for --format json')
    .action(async (id, options) => {
      try {
        const config = await loadWorkConfig();
        const provider = createWorkProvider(config);

        const workItem = await provider.getWorkItem(id);

        const format = options.json ? 'json' : options.format;

        if (format === 'json') {
          console.log(formatJson(workItem));
        } else if (format === 'table') {
          console.log(chalk.bold(`${workItem.key}: ${workItem.title}`));
          console.log(chalk.gray('─'.repeat(60)));
          console.log(`Status: ${formatState(workItem.state)}`);
          console.log(`Type: ${workItem.type}`);
          console.log(`Labels: ${workItem.labels.join(', ') || 'none'}`);
          console.log(`Assignee: ${workItem.assignee || 'unassigned'}`);
          console.log(`URL: ${workItem.url}`);
          if (workItem.description) {
            console.log(chalk.gray('─'.repeat(60)));
            console.log(workItem.description);
          }
        }

        if (options.includeComments) {
          const comments = await provider.listComments(id);
          console.log(chalk.gray('─'.repeat(60)));
          console.log(chalk.bold(`Comments (${comments.total}):`));
          for (const comment of comments.items) {
            console.log(`\n${chalk.cyan(comment.author)} (${comment.createdAt.toISOString()}):`);
            console.log(comment.body);
          }
        }

      } catch (error: any) {
        console.error(chalk.red('Error:'), error.message);
        process.exit(1);
      }
    });
}
```

## 6. Plugin Migration

### 6.1 Current Plugin Structure

```
plugins/work/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── work-manager.md
├── commands/
│   ├── issue-fetch.md
│   ├── issue-create.md
│   └── ... (27 commands)
├── skills/
│   ├── issue-fetcher/
│   │   ├── SKILL.md
│   │   └── scripts/
│   ├── handler-work-tracker-github/
│   │   └── scripts/
│   └── ... (12 skills)
└── config/
    └── config.example.json
```

### 6.2 Post-Migration Structure

```
plugins/work/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── work-manager.md           # Thin router to CLI
├── commands/
│   ├── issue-fetch.md            # Invokes CLI
│   ├── issue-create.md
│   └── ...
└── config/
    └── config.example.json
```

### 6.3 Agent Migration

**Before (current)**:
```markdown
# work-manager.md

<WORKFLOW>
1. Parse user request
2. Route to appropriate skill
3. Skill executes scripts
4. Return result
</WORKFLOW>
```

**After (post-migration)**:
```markdown
# work-manager.md

<WORKFLOW>
1. Parse user request
2. Map to CLI command
3. Execute: fractary work <resource> <action> [args]
4. Format response for Claude
</WORKFLOW>

<COMMAND_MAPPING>
| Operation | CLI Command |
|-----------|-------------|
| fetch issue | `fractary work issue fetch {id}` |
| create issue | `fractary work issue create --title "{title}"` |
| close issue | `fractary work state close {id}` |
</COMMAND_MAPPING>
```

### 6.4 What Gets Removed

- `skills/issue-fetcher/` - Logic moves to `@fractary/core/work/`
- `skills/issue-creator/` - Logic moves to SDK
- `skills/handler-work-tracker-github/` - Logic moves to SDK
- All shell scripts - Replaced by TypeScript/Python

### 6.5 What Stays

- `commands/*.md` - Claude UX layer
- `agents/work-manager.md` - Claude routing
- `config/` - Configuration templates

## 7. Configuration

### 7.1 Configuration Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "schema_version": {
      "type": "string",
      "const": "1.0"
    },
    "provider": {
      "type": "string",
      "enum": ["github", "jira", "linear"]
    },
    "github": {
      "type": "object",
      "properties": {
        "token_env": { "type": "string", "default": "GITHUB_TOKEN" },
        "owner": { "type": "string" },
        "repo": { "type": "string" }
      }
    },
    "jira": {
      "type": "object",
      "properties": {
        "base_url": { "type": "string" },
        "email_env": { "type": "string", "default": "JIRA_EMAIL" },
        "api_token_env": { "type": "string", "default": "JIRA_API_TOKEN" },
        "project_key": { "type": "string" }
      }
    },
    "linear": {
      "type": "object",
      "properties": {
        "api_key_env": { "type": "string", "default": "LINEAR_API_KEY" },
        "team_id": { "type": "string" }
      }
    }
  },
  "required": ["schema_version", "provider"]
}
```

### 7.2 Example Configuration

```json
{
  "schema_version": "1.0",
  "provider": "github",
  "github": {
    "token_env": "GITHUB_TOKEN",
    "owner": "fractary",
    "repo": "claude-plugins"
  }
}
```

## 8. Error Handling

### 8.1 Error Types

| Error | When | SDK Exception |
|-------|------|---------------|
| Issue not found | ID doesn't exist | `NotFoundError` |
| Authentication failed | Invalid token | `AuthenticationError` |
| Rate limit | Too many requests | `RateLimitError` |
| Invalid input | Missing required field | `ValidationError` |
| Provider error | API error | `ProviderError` |

### 8.2 CLI Error Output

```bash
$ fractary work issue fetch 99999
Error: Issue not found: 99999
  Provider: github
  Resource: issue
  ID: 99999

$ fractary work issue create
Error: Validation failed
  Missing required option: --title

Usage: fractary work issue create --title <title> [options]
```

## 9. Testing

### 9.1 Unit Tests

```typescript
// work/github.test.ts

describe('GitHubWorkProvider', () => {
  describe('getWorkItem', () => {
    it('fetches issue and normalizes to WorkItem', async () => {
      const provider = new GitHubWorkProvider(mockConfig);
      mockOctokit.issues.get.mockResolvedValue({ data: mockGitHubIssue });

      const result = await provider.getWorkItem('123');

      expect(result.id).toBe('123');
      expect(result.key).toBe('#123');
      expect(result.state).toBe('open');
    });

    it('throws NotFoundError for missing issue', async () => {
      const provider = new GitHubWorkProvider(mockConfig);
      mockOctokit.issues.get.mockRejectedValue({ status: 404 });

      await expect(provider.getWorkItem('999')).rejects.toThrow(NotFoundError);
    });
  });
});
```

### 9.2 Integration Tests

```typescript
// tests/integration/work-github.test.ts

describe('GitHub Work Provider Integration', () => {
  // Requires GITHUB_TOKEN and test repository

  it('creates and closes issue', async () => {
    const provider = createWorkProvider(testConfig);

    const created = await provider.createWorkItem({
      title: 'Test Issue',
      description: 'Integration test',
    });

    expect(created.id).toBeDefined();
    expect(created.state).toBe('open');

    const closed = await provider.closeWorkItem(created.id, 'Test complete');
    expect(closed.state).toBe('closed');
  });
});
```

## 10. References

- [SPEC-00016: SDK Architecture](./SPEC-00016-sdk-architecture.md) - Core interfaces
- [GitHub Issues API](https://docs.github.com/en/rest/issues)
- [Jira Cloud REST API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)
- [Linear GraphQL API](https://developers.linear.app/docs/graphql/working-with-the-graphql-api)
