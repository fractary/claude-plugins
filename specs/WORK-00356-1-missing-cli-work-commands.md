---
spec_id: WORK-00356-1-missing-cli-work-commands
issue_number: 356
issue_url: https://github.com/fractary/claude-plugins/issues/356
title: Missing CLI Work Commands
type: feature
status: draft
created: 2025-12-12
author: Claude (with human direction)
validated: false
parent_spec: WORK-00356-implement-faber-cli-work-commands
---

# Missing CLI Work Commands

**Issue**: [#356](https://github.com/fractary/claude-plugins/issues/356)
**Parent Spec**: WORK-00356-implement-faber-cli-work-commands
**Type**: Feature (CLI Enhancement)
**Status**: Draft
**Created**: 2025-12-12

## Summary

This spec documents 4 CLI commands that are missing from the Fractary CLI work module (v0.3.1) and are needed to complete the plugin-to-CLI migration. These commands should be implemented in the `fractary/cli` repository.

## Current CLI Status

**CLI Version**: 0.3.1
**Module**: `fractary work` (alias for `fractary faber work`)

### Available Commands (10/14)

| Command | Description |
|---------|-------------|
| `fractary work issue create` | Create a new work item |
| `fractary work issue fetch <number>` | Fetch work item details |
| `fractary work issue update <number>` | Update a work item |
| `fractary work issue close <number>` | Close a work item |
| `fractary work issue search` | Search/list work items |
| `fractary work comment create <number>` | Add comment to issue |
| `fractary work comment list <number>` | List comments on issue |
| `fractary work label add <number>` | Add labels to issue |
| `fractary work label remove <number>` | Remove labels from issue |
| `fractary work milestone list` | List milestones |

### Missing Commands (4)

1. `fractary work issue assign` - Assign issue to user
2. `fractary work issue reopen` - Reopen a closed issue
3. `fractary work init` - Initialize work tracking configuration
4. `fractary work issue classify` - Classify work type from issue

---

## Missing Command #1: `issue assign`

### Purpose

Assign or unassign a work item to a user. Essential for workflow tracking and team coordination.

### Usage

```bash
fractary work issue assign <number> [options]

Arguments:
  number              Issue number to assign

Options:
  --user <username>   User to assign (use @me for self, omit to unassign)
  --json              Output as JSON
  -h, --help          Display help
```

### Examples

```bash
# Assign issue #123 to user "jmcwilliam"
fractary work issue assign 123 --user jmcwilliam

# Assign to self
fractary work issue assign 123 --user @me

# Unassign (remove all assignees)
fractary work issue assign 123
```

### JSON Output

**Success:**
```json
{
  "success": true,
  "data": {
    "number": 123,
    "assignees": ["jmcwilliam"],
    "url": "https://github.com/org/repo/issues/123"
  }
}
```

**Unassign Success:**
```json
{
  "success": true,
  "data": {
    "number": 123,
    "assignees": [],
    "url": "https://github.com/org/repo/issues/123"
  }
}
```

### SDK Implementation

```typescript
// In @fractary/faber WorkManager
async assignIssue(number: number, user?: string): Promise<IssueResult> {
  const provider = await this.getProvider();
  return provider.assignIssue(number, user);
}
```

### Platform Mapping

| Platform | API Call |
|----------|----------|
| GitHub | `PATCH /repos/{owner}/{repo}/issues/{number}` with `assignees` |
| Jira | `PUT /rest/api/3/issue/{issueIdOrKey}/assignee` |
| Linear | `issueUpdate` mutation with `assigneeId` |

---

## Missing Command #2: `issue reopen`

### Purpose

Reopen a previously closed work item. Complements the existing `issue close` command to provide full state management.

### Usage

```bash
fractary work issue reopen <number> [options]

Arguments:
  number              Issue number to reopen

Options:
  --comment <text>    Add comment when reopening
  --json              Output as JSON
  -h, --help          Display help
```

### Examples

```bash
# Reopen issue #123
fractary work issue reopen 123

# Reopen with comment
fractary work issue reopen 123 --comment "Reopening: found additional edge cases"
```

### JSON Output

**Success:**
```json
{
  "success": true,
  "data": {
    "number": 123,
    "state": "open",
    "url": "https://github.com/org/repo/issues/123"
  }
}
```

### SDK Implementation

```typescript
// In @fractary/faber WorkManager
async reopenIssue(number: number, comment?: string): Promise<IssueResult> {
  const provider = await this.getProvider();
  return provider.updateIssueState(number, 'open', comment);
}
```

### Platform Mapping

| Platform | API Call |
|----------|----------|
| GitHub | `PATCH /repos/{owner}/{repo}/issues/{number}` with `state: "open"` |
| Jira | `POST /rest/api/3/issue/{issueIdOrKey}/transitions` |
| Linear | `issueUpdate` mutation with `stateId` |

### Alternative Design Option

Instead of a separate `reopen` command, could extend `issue close` to be `issue state`:

```bash
fractary work issue state <number> <state>

# Examples:
fractary work issue state 123 open    # Reopen
fractary work issue state 123 closed  # Close
```

**Recommendation**: Implement `issue reopen` for symmetry with `issue close`, matching user expectations.

---

## Missing Command #3: `init`

### Purpose

Initialize work tracking configuration for a project. Creates the configuration file needed for CLI and plugin to know which platform and repository to use.

### Usage

```bash
fractary work init [options]

Options:
  --platform <name>   Platform: github, jira, linear (auto-detect if not specified)
  --token <value>     API token (or use env var)
  --project <key>     Project key for Jira/Linear
  --yes               Accept defaults without prompting
  --json              Output as JSON
  -h, --help          Display help
```

### Examples

```bash
# Interactive initialization
fractary work init

# Non-interactive with platform specified
fractary work init --platform github --yes

# Initialize for Jira
fractary work init --platform jira --project PROJ --token $JIRA_TOKEN
```

### Configuration Output

Creates `.fractary/faber/config.json` with work section:

```json
{
  "work": {
    "platform": "github",
    "repository": {
      "owner": "fractary",
      "name": "claude-plugins"
    }
  }
}
```

For Jira:
```json
{
  "work": {
    "platform": "jira",
    "instance": "https://company.atlassian.net",
    "project": "PROJ"
  }
}
```

### JSON Output

**Success:**
```json
{
  "success": true,
  "data": {
    "platform": "github",
    "config_path": ".fractary/faber/config.json",
    "repository": "fractary/claude-plugins"
  }
}
```

### SDK Implementation

```typescript
// In @fractary/faber WorkManager
async init(options: InitOptions): Promise<InitResult> {
  const platform = options.platform || await this.detectPlatform();
  const config = await this.buildConfig(platform, options);
  await this.writeConfig(config);
  return { platform, config_path: this.configPath };
}

private async detectPlatform(): Promise<string> {
  // Check for .git/config remote URL
  // GitHub: github.com
  // GitLab: gitlab.com
  // Bitbucket: bitbucket.org
  // Fall back to prompt
}
```

### Behavior

1. **Auto-detection**: If `--platform` not specified, detect from git remote
2. **Prompting**: In interactive mode, prompt for missing required values
3. **Env vars**: Token can come from `GITHUB_TOKEN`, `JIRA_API_TOKEN`, `LINEAR_API_KEY`
4. **Idempotent**: Running again updates config, doesn't error

---

## Missing Command #4: `issue classify`

### Purpose

Classify a work item's type (feature, bug, chore, patch) based on its title, description, and labels. Used in FABER workflows to determine branch naming and workflow steps.

### Usage

```bash
fractary work issue classify <number> [options]

Arguments:
  number              Issue number to classify

Options:
  --json              Output as JSON
  -h, --help          Display help
```

### Examples

```bash
# Classify issue #123
fractary work issue classify 123

# Output: feature
```

### JSON Output

**Success:**
```json
{
  "success": true,
  "data": {
    "number": 123,
    "work_type": "feature",
    "confidence": 0.95,
    "signals": {
      "labels": ["enhancement"],
      "title_keywords": ["add", "implement"],
      "has_bug_markers": false
    }
  }
}
```

### Classification Logic

The classifier uses multiple signals:

1. **Labels** (highest priority):
   - `bug`, `defect`, `regression` → `bug`
   - `enhancement`, `feature`, `new feature` → `feature`
   - `chore`, `maintenance`, `dependencies` → `chore`
   - `hotfix`, `urgent`, `security` → `patch`

2. **Title keywords**:
   - `fix`, `bug`, `error`, `crash` → `bug`
   - `add`, `implement`, `new`, `create` → `feature`
   - `update`, `upgrade`, `refactor`, `clean` → `chore`

3. **Issue type** (for Jira/Linear):
   - Story → `feature`
   - Bug → `bug`
   - Task → `chore`

### SDK Implementation

```typescript
// In @fractary/faber WorkManager
async classifyIssue(number: number): Promise<ClassifyResult> {
  const issue = await this.fetchIssue(number);
  return this.classifier.classify(issue);
}

// Classifier implementation
class WorkTypeClassifier {
  classify(issue: Issue): ClassifyResult {
    const signals = this.extractSignals(issue);
    const workType = this.determineType(signals);
    const confidence = this.calculateConfidence(signals);
    return { work_type: workType, confidence, signals };
  }
}
```

### Platform Mapping

This command is platform-agnostic - it fetches the issue data and applies classification logic. The underlying `fetchIssue` call uses platform-specific APIs.

---

## Implementation Priority

| Command | Priority | Rationale |
|---------|----------|-----------|
| `issue assign` | High | Core workflow operation |
| `issue reopen` | High | Symmetry with `close`, state management |
| `init` | Medium | Needed for clean onboarding |
| `issue classify` | Medium | Used in FABER automation |

## Dependencies

All commands depend on:
- `@fractary/faber` SDK with WorkManager
- `@fractary/core` SDK with WorkProvider adapters
- Platform-specific API clients (already implemented for existing commands)

## Testing Requirements

Each command needs:
1. Unit tests for argument parsing
2. Integration tests with mock API responses
3. E2E tests against real platforms (GitHub at minimum)

## Related

- Parent spec: WORK-00356-implement-faber-cli-work-commands
- CLI repository: `fractary/cli`
- SDK specifications: SPEC-00024-fractary-faber-sdk
