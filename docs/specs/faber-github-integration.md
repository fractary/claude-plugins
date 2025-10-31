# FABER GitHub Integration Specification

**Version:** 1.0.0
**Date:** 2025-10-31
**Status:** Draft
**Author:** System Architecture Team

---

## Table of Contents

1. [Overview](#overview)
2. [Motivation](#motivation)
3. [Architecture](#architecture)
4. [Design Decisions](#design-decisions)
5. [Implementation Plan](#implementation-plan)
6. [Component Specifications](#component-specifications)
7. [Integration Flow](#integration-flow)
8. [Configuration](#configuration)
9. [Security & Safety](#security--safety)
10. [Examples](#examples)
11. [Testing Strategy](#testing-strategy)
12. [Future Extensions](#future-extensions)

---

## Overview

### Purpose

Enable users to trigger FABER workflows directly from GitHub issues using `@faber` mentions, creating a seamless integration between issue tracking and automated development workflows.

### Goals

1. **Natural Interface**: Use `@faber` mentions with natural language commands
2. **Context-Aware**: Automatically extract issue context and repository configuration
3. **Safe by Default**: Respect repository configuration and safety gates
4. **Transparent**: Post workflow status updates back to GitHub issues
5. **Flexible**: Support multiple intent types (full workflow, single phase, status, control)

### Non-Goals

1. Support for platforms other than GitHub (initial version)
2. Real-time streaming of workflow execution
3. Interactive multi-turn conversations in issue comments
4. Workflow customization via mention text (use config file instead)

---

## Motivation

### Current State

- Users can run FABER workflows via `/faber run <issue-id>` in Claude Code CLI
- Requires local environment with Claude Code installed
- No integration with GitHub Actions or CI/CD pipelines
- Existing `@claude` integration exists but doesn't route through FABER

### Desired State

- Users can trigger FABER workflows by commenting `@faber` on GitHub issues
- Workflows execute in GitHub Actions environment
- Status updates posted automatically to issues
- Configuration read from repository's `.faber.config.toml`
- Multiple intent types supported for different workflow needs

### Benefits

1. **Accessibility**: Trigger workflows without local Claude Code installation
2. **Transparency**: All workflow activity visible in GitHub issues
3. **Collaboration**: Team members can monitor and approve workflows
4. **CI/CD Integration**: Leverage GitHub Actions infrastructure
5. **Audit Trail**: Complete workflow history in issue comments

---

## Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Issue                             │
│                   @faber run this issue                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              GitHub Actions Workflow                         │
│              (.github/workflows/faber.yml)                   │
│                                                              │
│  Triggers: issue_comment, issues, PR comments               │
│  Condition: Contains '@faber'                                │
│  Action: anthropics/claude-code-action@v1                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│           Claude Code in GitHub Runner                       │
│                                                              │
│  Command: /faber:mention                                     │
│  Context: Issue ID, Comment Body, Repository                │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│         FABER Mention Command                                │
│         (plugins/faber/commands/mention.md)                  │
│                                                              │
│  1. Parse GitHub event context                              │
│  2. Extract @faber mention text                             │
│  3. Load .faber.config.toml                                 │
│  4. Invoke Enhanced Director Agent                          │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│         Enhanced FABER Director Agent                        │
│         (plugins/faber/agents/director.md)                   │
│                                                              │
│  NEW: Intent Parsing Section                                │
│  ┌────────────────────────────────────────┐                │
│  │ Parse mention text for intent:         │                │
│  │ • Full workflow                        │                │
│  │ • Single phase                         │                │
│  │ • Status query                         │                │
│  │ • Control command                      │                │
│  └────────────────────────────────────────┘                │
│                                                              │
│  EXISTING: Workflow Orchestration                           │
│  ┌────────────────────────────────────────┐                │
│  │ Frame → Architect → Build →            │                │
│  │ Evaluate → Release                     │                │
│  └────────────────────────────────────────┘                │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Phase Manager Agents                            │
│                                                              │
│  • frame-manager.md                                         │
│  • architect-manager.md                                     │
│  • build-manager.md                                         │
│  • evaluate-manager.md                                      │
│  • release-manager.md                                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Primitive Manager Agents                        │
│                                                              │
│  work-manager → GitHub Issues, Jira, Linear                 │
│  repo-manager → GitHub, GitLab, Bitbucket                   │
│  file-manager → R2, S3, Local                               │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│           Status Updates Posted to GitHub Issue             │
│                                                              │
│  • Workflow started                                         │
│  • Phase completions                                        │
│  • Evaluation results                                       │
│  • Release approval requests                                │
│  • Final status                                             │
└─────────────────────────────────────────────────────────────┘
```

### Component Relationships

```
GitHub Issue @faber Mention
        ↓
    faber.yml (GitHub Workflow)
        ↓
    mention.md (Command)
        ↓
    director.md (Enhanced Agent) ─┐
        ↓                         │
    Intent Router ────────────────┤
        ├─→ Full Workflow         │
        ├─→ Single Phase          │
        ├─→ Status Query          │
        └─→ Control Command       │
                                  │
    Existing Orchestration ←──────┘
        ↓
    Phase Managers
        ↓
    Primitive Managers
        ↓
    GitHub Status Updates
```

---

## Design Decisions

### Decision 1: Enhance Director vs. Create New Router

**Options Considered:**

**Option A: Create Separate faber-router Agent**
- Pros: Clean separation of concerns, follows devops-director pattern
- Cons: Additional agent file, potential duplication

**Option B: Enhance Existing Director Agent** ✅ **SELECTED**
- Pros: Single entry point, simpler structure, maintains existing orchestration
- Cons: Director has dual responsibility (routing + orchestration)

**Rationale:**
- Director already owns the workflow orchestration logic
- Intent parsing is a natural precursor to execution
- Adding a router section at the beginning keeps all workflow control in one place
- Follows the pattern: "parse intent → execute workflow"
- Reduces complexity by avoiding multiple agent handoffs

### Decision 2: Configuration Source

**Options Considered:**

**Option A: Default to Guarded Preset**
- Pros: Safest option, consistent behavior
- Cons: Ignores repository preferences, less flexible

**Option B: Allow Config Override in Mention**
- Pros: Maximum flexibility per-invocation
- Cons: Security risk, inconsistent configuration

**Option C: Use Repository's .faber.config.toml** ✅ **SELECTED**
- Pros: Respects project configuration, consistent with local usage, safe by design
- Cons: Requires config file in repository

**Rationale:**
- Repository configuration is the source of truth for workflow behavior
- Projects already configure autonomy levels, safety gates, and protected paths
- Consistent behavior between local and GitHub-triggered workflows
- Safety mechanisms (guarded mode, protected paths) already configured per project

### Decision 3: GitHub Workflow File

**Options Considered:**

**Option A: Integrate into claude.yml**
- Pros: Single workflow file
- Cons: Complex conditional logic, harder to customize separately

**Option B: Separate faber.yml** ✅ **SELECTED**
- Pros: Clean separation, easier to understand, independent customization
- Cons: Additional file

**Rationale:**
- @faber and @claude serve different purposes
- Separate workflows are easier to maintain and debug
- Users can enable/disable @faber independently
- Clear separation of concerns

### Decision 4: Supported Intents (MVP)

**Selected Intents:** ✅ **ALL FOUR**

1. **Run Full Workflow**: Execute complete Frame→Architect→Build→Evaluate→Release
2. **Single Phase Execution**: Run individual phases (just design, just implement, etc.)
3. **Status Queries**: Check current workflow status
4. **Approval/Control**: Approve releases, retry evaluations, etc.

**Rationale:**
- Full workflow is the primary use case (highest priority)
- Single phase execution enables incremental work
- Status queries provide visibility
- Control commands enable human-in-the-loop workflows
- All four are achievable with reasonable effort

---

## Implementation Plan

### Phase 1: Core GitHub Integration (Week 1)

**Goal:** Enable basic `@faber run this issue` functionality

**Tasks:**
1. Create `.github/workflows/faber.yml`
   - Define triggers (issue_comment, issues opened/assigned)
   - Add @faber mention detection
   - Configure claude-code-action

2. Create `plugins/faber/commands/mention.md`
   - Parse GitHub event context
   - Extract issue ID and comment body
   - Load repository configuration
   - Invoke director agent

3. Update `plugins/faber/.claude-plugin/plugin.json`
   - Register mention command
   - Increment version to 1.1.0

**Deliverables:**
- Working GitHub workflow triggered by @faber
- Mention command that invokes director
- Basic integration test

### Phase 2: Intent Parsing Enhancement (Week 2)

**Goal:** Add intent parsing to director agent

**Tasks:**
1. Enhance `plugins/faber/agents/director.md`
   - Add `<INTENT_PARSING>` section at beginning
   - Parse four intent types
   - Route to appropriate execution path
   - Preserve all existing orchestration logic

2. Define intent patterns:
   - **Full workflow**: "run", "work on", "handle", "process"
   - **Single phase**: "frame", "design", "architect", "build", "implement", "evaluate", "test", "release", "deploy"
   - **Status**: "status", "progress", "what's happening", "where are we"
   - **Control**: "approve", "retry", "cancel", "skip"

3. Add fallback logic:
   - Default to full workflow if intent unclear
   - Error handling for ambiguous requests

**Deliverables:**
- Enhanced director with intent parsing
- Documentation of supported intents
- Test cases for each intent type

### Phase 3: Status Feedback Integration (Week 3)

**Goal:** Ensure workflow status posts to GitHub issues

**Tasks:**
1. Verify existing status card mechanism works with GitHub Actions
2. Test status updates in GitHub runner environment
3. Add mention-specific status card templates if needed
4. Ensure error messages post to issues

**Deliverables:**
- Status cards posting to GitHub issues
- Error handling with user-visible messages
- Test coverage for status updates

### Phase 4: Documentation & Testing (Week 4)

**Goal:** Complete documentation and comprehensive testing

**Tasks:**
1. Create `plugins/faber/docs/github-integration.md`
   - Setup instructions
   - Usage examples
   - Troubleshooting guide

2. Update main FABER README
3. Create integration test suite
4. Test with multiple repositories
5. Document edge cases and limitations

**Deliverables:**
- Complete documentation
- Test suite
- Example configurations
- Troubleshooting guide

---

## Component Specifications

### 1. GitHub Workflow (`.github/workflows/faber.yml`)

```yaml
name: FABER Workflow

on:
  issue_comment:
    types: [created]
  issues:
    types: [opened, assigned]
  pull_request_review_comment:
    types: [created]
  pull_request_review:
    types: [submitted]

jobs:
  faber:
    # Only run if comment/body contains @faber
    if: |
      (github.event_name == 'issue_comment' && contains(github.event.comment.body, '@faber')) ||
      (github.event_name == 'pull_request_review_comment' && contains(github.event.comment.body, '@faber')) ||
      (github.event_name == 'pull_request_review' && contains(github.event.review.body, '@faber')) ||
      (github.event_name == 'issues' && (contains(github.event.issue.body, '@faber') || contains(github.event.issue.title, '@faber')))

    runs-on: ubuntu-latest

    permissions:
      contents: write
      issues: write
      pull-requests: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run FABER via Claude Code
        uses: anthropics/claude-code-action@v1
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          claude_api_key: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          command: '/faber:mention'
        env:
          GITHUB_CONTEXT: ${{ toJson(github) }}
```

**Key Features:**
- Triggers on multiple GitHub events
- Conditional execution on @faber mention
- Uses claude-code-action for execution
- Provides GitHub context as environment variable
- Requires CLAUDE_CODE_OAUTH_TOKEN secret

### 2. Mention Command (`plugins/faber/commands/mention.md`)

```markdown
# /faber:mention - GitHub Mention Entry Point

## Purpose
Entry point for @faber mentions from GitHub issues and PRs. Parses GitHub event context and invokes the FABER director agent.

## Trigger
This command is automatically invoked by the GitHub Actions workflow when @faber is mentioned.

## Behavior

### 1. Parse GitHub Event Context
Extract from $GITHUB_CONTEXT environment variable:
- Issue/PR number
- Comment body or issue body
- Repository name and owner
- Event type (comment, issue opened, etc.)
- Commenter username

### 2. Extract Mention Text
- Find @faber mention in comment/body
- Extract text after @faber (the intent)
- Clean and normalize the text
- Example: "@faber run this issue" → "run this issue"

### 3. Load Repository Configuration
- Read .faber.config.toml from repository root
- Validate configuration
- Extract:
  - Autonomy level (dry-run, assist, guarded, autonomous)
  - Workflow settings
  - Safety gates
  - Protected paths
  - Platform configurations (work, repo, file)

### 4. Prepare Director Context
Create structured context object:
```json
{
  "trigger": "github-mention",
  "issue_id": "123",
  "repository": "owner/repo",
  "mention_text": "run this issue",
  "commenter": "username",
  "event_type": "issue_comment",
  "config": { /* loaded config */ }
}
```

### 5. Invoke Director Agent
Use the enhanced FABER director agent:
```
Use the @agent-fractary-faber:director agent with the following context:
{context_object}

The user mentioned @faber with: "{mention_text}"

Execute the appropriate workflow based on the intent.
```

## Error Handling

### Configuration Not Found
If .faber.config.toml doesn't exist:
- Post comment to issue: "FABER configuration not found. Run '/faber init' to set up."
- Exit with helpful instructions

### Invalid Configuration
If config is malformed:
- Post comment with validation errors
- Suggest fixes or link to documentation

### Permission Errors
If GitHub token lacks permissions:
- Post comment explaining permission requirements
- Link to setup documentation

## Output
- All director output posts to the GitHub issue
- Status cards appear as issue comments
- Errors visible in issue comments
- Workflow summary posted on completion
```

### 3. Enhanced Director Agent (`plugins/faber/agents/director.md`)

**New Section to Add at Beginning:**

```markdown
<INTENT_PARSING>

## Purpose
When invoked from GitHub mentions, parse the user's intent and route to the appropriate workflow execution path.

## Context Detection
Check if this is a GitHub mention invocation:
- Look for `trigger: "github-mention"` in context
- If not present, skip intent parsing (direct invocation via CLI)

## Intent Types

### 1. Full Workflow Intent
**Patterns:** "run", "work on", "handle", "process", "do", "complete", "execute"

**Examples:**
- "@faber run this issue"
- "@faber work on this"
- "@faber handle issue #123"
- "@faber do this"

**Action:** Execute complete Frame → Architect → Build → Evaluate → Release workflow

**Implementation:**
- Proceed to WORKFLOW ORCHESTRATION section
- Execute all five phases in sequence
- Apply autonomy level from config

### 2. Single Phase Intent
**Patterns:** Phase names or phase-specific verbs

**Frame Phase:**
- "frame", "setup", "initialize", "fetch"
- Example: "@faber just frame this"
- Action: Execute frame-manager only, stop

**Architect Phase:**
- "design", "architect", "spec", "plan"
- Example: "@faber just design this, don't implement"
- Action: Execute frame-manager → architect-manager, stop

**Build Phase:**
- "build", "implement", "code", "develop"
- Example: "@faber only implement this"
- Action: Execute frame-manager → architect-manager → build-manager, stop
- Note: Requires existing spec or creates minimal one

**Evaluate Phase:**
- "test", "evaluate", "check", "verify", "validate"
- Example: "@faber run tests on this"
- Action: Execute evaluate-manager on current state, stop

**Release Phase:**
- "release", "deploy", "ship", "publish"
- Example: "@faber release this"
- Action: Execute release-manager only (requires completed work)
- Safety: Requires guarded or autonomous mode confirmation

**Implementation:**
- Route to specific phase manager(s)
- Respect dependencies (can't architect without frame)
- Post status card with phase-specific information

### 3. Status Query Intent
**Patterns:** "status", "progress", "where", "what's happening", "show me", "current state"

**Examples:**
- "@faber status"
- "@faber what's the progress on this?"
- "@faber where are we?"

**Action:** Invoke status command and post results

**Implementation:**
- Read session state from .faber/sessions/{issue_id}.json
- Format current status (phase, progress, blockers)
- Post status card to issue
- Do NOT execute workflow

### 4. Control Command Intent
**Patterns:** Workflow control actions

**Approve:**
- "approve", "approve release", "looks good", "LGTM", "proceed"
- Example: "@faber approve release"
- Action: If workflow is paused at release gate, proceed with release

**Retry:**
- "retry", "try again", "retry evaluate"
- Example: "@faber retry evaluation"
- Action: Re-run last failed phase (typically evaluate)

**Cancel:**
- "cancel", "stop", "abort"
- Example: "@faber cancel this workflow"
- Action: Mark session as cancelled, post status

**Skip:**
- "skip", "skip evaluation", "bypass"
- Example: "@faber skip tests" (only in dry-run or assist mode)
- Action: Skip current phase and proceed

**Implementation:**
- Read session state
- Validate control command is valid for current state
- Execute control action
- Update session state
- Post status update

## Fallback Logic

### Intent Unclear
If mention text doesn't match any pattern:
- Default to full workflow execution
- Post comment: "Interpreting this as a full workflow request. Starting Frame → Architect → Build → Evaluate → Release."

### Empty Mention
If mention is just "@faber" with no additional text:
- Check issue state:
  - If new issue: Default to full workflow
  - If existing workflow session: Default to status query

### Ambiguous Intent
If multiple intents detected:
- Prioritize in order: Control > Status > Single Phase > Full Workflow
- Post comment explaining interpretation

## Error Handling

### Invalid Phase for Current State
- "Can't architect without framing first"
- "No work to release yet"
- Post clear error message and suggest correct command

### Invalid Control Command
- "No workflow to approve"
- "Nothing to retry"
- Post status and available actions

## Output
After intent parsing:
- Post comment acknowledging intent: "Starting [intent description]..."
- Proceed to appropriate execution path
- Post status card on completion

</INTENT_PARSING>
```

**Integration with Existing Content:**
- Intent parsing section goes FIRST
- If no GitHub mention context, skip directly to existing orchestration
- All existing workflow orchestration logic remains unchanged
- Phase managers invoked exactly as before

---

## Integration Flow

### Flow 1: Full Workflow from GitHub Mention

```
1. User comments "@faber run this issue" on GitHub issue #123

2. GitHub Actions workflow triggers
   - Detects @faber mention
   - Checks out repository
   - Runs claude-code-action

3. Claude Code invokes /faber:mention command
   - Parses GITHUB_CONTEXT env variable
   - Extracts issue_id=123, mention_text="run this issue"
   - Loads .faber.config.toml

4. mention.md command invokes director agent
   - Passes structured context
   - Includes mention text and config

5. Director agent parses intent
   - "run this issue" matches "Full Workflow Intent"
   - Proceeds to orchestration section

6. Director orchestrates workflow
   - Frame: Fetch issue #123, classify, setup branch
   - Architect: Design solution, create spec
   - Build: Implement from spec, create commits
   - Evaluate: Run tests, review code
   - Release: Create PR, optionally merge

7. Status updates post to issue #123
   - "Starting Frame phase..."
   - "Frame complete. Starting Architect..."
   - "Build complete. Starting Evaluate..."
   - "Evaluation passed. Ready for release."
   - "PR created: #124"

8. Workflow completes
   - Final status card posted
   - Issue updated with PR link
   - Session saved to .faber/sessions/123.json
```

### Flow 2: Status Query from GitHub Mention

```
1. User comments "@faber status" on issue #123

2. GitHub workflow triggers → claude-code-action → /faber:mention

3. mention.md loads context and config, invokes director

4. Director parses intent
   - "status" matches "Status Query Intent"
   - Routes to status command

5. Status command executes
   - Reads .faber/sessions/123.json
   - Formats current state

6. Status card posted to issue
   - Current phase: Build
   - Progress: 75%
   - Last update: 2 minutes ago
   - Next action: Evaluate phase

7. Director exits (no workflow execution)
```

### Flow 3: Phase-Specific Execution

```
1. User comments "@faber just design this, don't implement" on issue #123

2. GitHub workflow → claude-code-action → /faber:mention

3. mention.md invokes director with context

4. Director parses intent
   - "just design this" matches "Single Phase Intent: Architect"
   - Routes to Frame + Architect only

5. Director executes Frame and Architect phases
   - Frame: Fetch issue, classify, setup
   - Architect: Design solution, create spec at .faber/specs/123.md

6. Director stops after Architect
   - Posts status: "Architecture spec created at .faber/specs/123.md"
   - Posts comment: "Design complete. Stopping as requested. Use '@faber build' to implement."

7. Session saved with state="architect_complete"
```

### Flow 4: Approval Control Command

```
1. Workflow previously paused at Release gate (guarded mode)
   - Session state: "awaiting_release_approval"
   - Issue has comment: "Evaluation passed. Approve release with '@faber approve'"

2. User comments "@faber approve release" on issue #123

3. GitHub workflow → claude-code-action → /faber:mention

4. Director parses intent
   - "approve release" matches "Control Command Intent: Approve"
   - Validates current state allows approval

5. Director reads session
   - Confirms state="awaiting_release_approval"
   - Proceeds with release phase

6. Release phase executes
   - Creates PR #124
   - Posts link to issue
   - Optionally merges (if auto_merge=true)

7. Workflow completes
   - Final status posted
   - Session marked complete
```

---

## Configuration

### Repository Configuration (.faber.config.toml)

**Minimum Required for GitHub Integration:**

```toml
[project]
name = "my-project"
issue_system = "github"
source_control = "github"

[defaults]
preset = "software-guarded"  # Recommended for GitHub
autonomy = "guarded"         # Pause before release

[workflow]
max_evaluate_retries = 3
auto_merge = false           # Require manual merge for safety
auto_close_work_item = true  # Close issue when PR merged

[safety]
require_confirm_for = ["release", "merge_to_main"]
protected_paths = [
  ".github/**",
  "*.env",
  "secrets/**"
]

[systems.work_config]
platform = "github"
# owner/repo detected from GitHub context

[systems.repo_config]
platform = "github"
default_branch = "main"
pr_template_path = ".github/pull_request_template.md"
```

**Advanced Configuration:**

```toml
[github_integration]
# GitHub-specific settings
post_status_cards = true
post_phase_updates = true
post_evaluation_results = true
post_errors = true
mention_user_on_approval = true

[director]
# Director agent settings
model = "claude-sonnet-4-5"
max_tokens = 8192

[phases.frame]
auto_create_branch = true
branch_naming = "faber/{issue_id}-{slug}"

[phases.evaluate]
required_checks = ["tests", "lint", "type-check"]
allow_retry = true

[phases.release]
require_approval = true           # Always require approval for release
approval_timeout_hours = 24       # Auto-cancel if no approval
create_pr = true
auto_merge = false
delete_branch_after_merge = true
```

### GitHub Secrets

**Required:**
- `CLAUDE_CODE_OAUTH_TOKEN` - Claude Code API token

**Optional:**
- `FABER_CONFIG_OVERRIDE` - JSON override for config (advanced)

### GitHub Permissions

**Workflow permissions required:**
```yaml
permissions:
  contents: write        # Read repo, commit changes, create branches
  issues: write          # Post comments, update labels
  pull-requests: write   # Create PRs, post comments
```

---

## Security & Safety

### Safety Mechanisms

**1. Configuration-Based Safety**
- Repository's .faber.config.toml defines safety rules
- Protected paths prevent accidental modification
- Confirmation gates for critical operations
- Autonomy levels control automation degree

**2. Autonomy Levels**
- **dry-run**: No actual changes, simulation only
- **assist**: Execute through Build, stop before Release
- **guarded**: Execute all phases, require approval for Release
- **autonomous**: Full automation (use with caution)

**Recommendation for GitHub:** Default to `guarded` mode

**3. Protected Paths**
Default protected paths (never auto-modify):
- `.github/**` - Workflow files
- `*.env`, `**/.env*` - Environment files
- `secrets/**`, `**/*secret*` - Secrets
- `**/credentials*` - Credentials
- `infra/prod/**` - Production infrastructure
- `terraform.tfstate` - Terraform state

**4. Confirmation Gates**
Operations requiring explicit approval:
- Release phase (in guarded mode)
- Merge to main/master
- Production deployments
- Destructive operations

**5. Audit Trail**
- All workflow activity logged in GitHub issue comments
- Session state saved to `.faber/sessions/{issue_id}.json`
- Commits reference issue ID
- PRs link to original issue

### Security Considerations

**1. Secrets Management**
- Never commit secrets to repository
- Use GitHub Secrets for sensitive tokens
- Protected paths prevent accidental secret exposure
- Scan for secrets before commit

**2. Access Control**
- GitHub token permissions limited to required scopes
- CLAUDE_CODE_OAUTH_TOKEN stored as encrypted secret
- Workflow runs in isolated GitHub runner
- Repository permissions control who can trigger @faber

**3. Code Review**
- All changes go through PR process
- Evaluation phase includes automated checks
- Human approval required before release (guarded mode)
- Diff review before merge

**4. Rate Limiting**
- Workflow triggered only on @faber mention
- Session state prevents duplicate executions
- Retry limits prevent infinite loops
- Timeout on approval gates

### Failure Modes

**1. Configuration Missing**
- Workflow fails gracefully
- Clear error message posted to issue
- Instructions for setup provided

**2. Invalid Mention**
- Intent parser defaults to full workflow or posts error
- User feedback guides correction
- No silent failures

**3. Phase Failure**
- Workflow stops at failing phase
- Error details posted to issue
- Session state saved for retry
- Retry command available

**4. Network/API Failures**
- GitHub Actions retry logic
- Exponential backoff for API calls
- Clear error messages
- Manual retry option

---

## Examples

### Example 1: Basic Full Workflow

**GitHub Issue #145: "Add CSV export feature"**

**User Action:**
```
User comments: @faber work on this issue
```

**Workflow Execution:**

```
Status Update (comment 1):
🎯 FABER Workflow Started
Issue: #145
Triggered by: @username
Autonomy: guarded
───────────────────────────────

Status Update (comment 2):
✅ Frame Complete
- Fetched issue details
- Classified as: feature
- Created branch: faber/145-add-csv-export
- Setup environment
Next: Architect phase
───────────────────────────────

Status Update (comment 3):
✅ Architect Complete
- Designed solution architecture
- Created specification: .faber/specs/145.md
- Identified components: CSV serializer, download endpoint
Next: Build phase
───────────────────────────────

Status Update (comment 4):
✅ Build Complete
- Implemented CSV serializer (src/lib/csv.ts)
- Created download endpoint (src/routes/api/export.ts)
- Added tests (src/lib/csv.test.ts)
- Created commit: feat: Add CSV export feature (#145)
Next: Evaluate phase
───────────────────────────────

Status Update (comment 5):
✅ Evaluate Complete
- All tests passed ✓
- Linting passed ✓
- Type checking passed ✓
- Build successful ✓
Next: Release phase (awaiting approval)

⚠️ APPROVAL REQUIRED
Reply with: @faber approve release
───────────────────────────────

User replies: @faber approve release

Status Update (comment 6):
✅ Release Complete
- Created PR: #146
- PR link: https://github.com/owner/repo/pull/146
- All checks passed
- Ready for review

🎉 WORKFLOW COMPLETE
Branch: faber/145-add-csv-export
PR: #146
Duration: 3m 42s
───────────────────────────────
```

### Example 2: Design Only

**GitHub Issue #150: "Refactor authentication system"**

**User Action:**
```
User comments: @faber just design this, I'll implement myself
```

**Workflow Execution:**

```
Status Update (comment 1):
🎯 FABER Architect Phase
Issue: #150
Intent: Design only
───────────────────────────────

Status Update (comment 2):
✅ Frame Complete
- Fetched issue details
- Classified as: refactoring
- Analyzed current auth system
───────────────────────────────

Status Update (comment 3):
✅ Architect Complete
- Created design specification: .faber/specs/150.md
- Outlined migration strategy
- Identified breaking changes
- Estimated effort: 2-3 days

📄 Specification created. Review at: .faber/specs/150.md

Stopping as requested. When ready to implement:
- @faber build (to implement the design)
- @faber run (to complete full workflow)
───────────────────────────────
```

### Example 3: Status Check

**GitHub Issue #155: "Optimize database queries"**

**Context:** Workflow started earlier, now running

**User Action:**
```
User comments: @faber status
```

**Response:**

```
📊 FABER Workflow Status
Issue: #155
Branch: faber/155-optimize-database-queries
───────────────────────────────

Current Phase: Evaluate
Progress: ████████░░ 80%

Completed:
✓ Frame (2m ago)
✓ Architect (5m ago)
✓ Build (8m ago)

In Progress:
⏳ Evaluate
  - Tests: Running...
  - Lint: Passed ✓
  - Type check: Passed ✓

Pending:
○ Release

Last Update: 30 seconds ago
Session: .faber/sessions/155.json
───────────────────────────────
```

### Example 4: Test Run

**GitHub Issue #160: "Fix login validation bug"**

**User Action:**
```
User comments: @faber just test this
```

**Workflow Execution:**

```
Status Update (comment 1):
🧪 FABER Evaluate Phase
Issue: #160
Intent: Test only
───────────────────────────────

Status Update (comment 2):
⏳ Running Evaluation...
- Installing dependencies...
- Running test suite...
───────────────────────────────

Status Update (comment 3):
❌ Evaluation Failed
- Tests: 2 failed, 45 passed
- Lint: Passed ✓
- Type check: Passed ✓

Failed Tests:
  ✗ src/auth/login.test.ts
    - "should validate email format"
    - "should reject invalid passwords"

Review the failures and fix the code.
Then retry with: @faber retry evaluate
───────────────────────────────

User fixes code and replies: @faber retry evaluate

Status Update (comment 4):
✅ Evaluate Complete
- Tests: All passed ✓
- Lint: Passed ✓
- Type check: Passed ✓

Tests are passing. Use @faber release to create PR.
───────────────────────────────
```

### Example 5: Error Handling

**GitHub Issue #165: "Add dark mode"**

**User Action:**
```
User comments: @faber run this
```

**Error Scenario: No config found**

```
❌ FABER Configuration Not Found

FABER requires a configuration file to run.

Setup Instructions:
1. Install FABER: npm install -g @fractary/faber-cli
2. Initialize: cd your-repo && faber init
3. Choose a preset (recommended: software-guarded)
4. Commit .faber.config.toml to repository

Documentation:
https://docs.fractary.com/faber/setup

Once configured, mention @faber again to start workflow.
───────────────────────────────
```

---

## Testing Strategy

### Unit Tests

**1. Mention Command Tests**
- Parse GitHub event context correctly
- Extract issue ID from various event types
- Handle malformed context gracefully
- Load configuration with validation

**2. Intent Parsing Tests**
Test director agent intent parser:
```javascript
testCases = [
  // Full workflow
  { input: "run this", expected: "full_workflow" },
  { input: "work on this issue", expected: "full_workflow" },
  { input: "handle #123", expected: "full_workflow" },

  // Single phase
  { input: "just design this", expected: "architect_only" },
  { input: "only implement", expected: "build_only" },
  { input: "run tests", expected: "evaluate_only" },
  { input: "release", expected: "release_only" },

  // Status
  { input: "status", expected: "status_query" },
  { input: "what's happening", expected: "status_query" },
  { input: "progress?", expected: "status_query" },

  // Control
  { input: "approve release", expected: "control_approve" },
  { input: "retry", expected: "control_retry" },
  { input: "cancel", expected: "control_cancel" },

  // Ambiguous (default to full workflow)
  { input: "@faber", expected: "full_workflow" },
  { input: "please help", expected: "full_workflow" }
]
```

**3. Configuration Loading Tests**
- Valid TOML parsing
- Missing config handling
- Invalid config validation
- Preset merging

### Integration Tests

**1. GitHub Workflow Tests**
- Trigger on @faber mention in comment
- Trigger on @faber in issue body
- Ignore non-@faber comments
- Correct permissions

**2. End-to-End Flow Tests**
Create test repository with:
- Sample .faber.config.toml
- Test issue templates
- Mock GitHub events

Test scenarios:
- Full workflow execution
- Single phase execution
- Status query
- Approval flow
- Error handling

**3. Status Update Tests**
- Status cards post to issues
- Updates appear in correct order
- Error messages visible
- Session state persists

### Manual Testing Checklist

**Setup:**
- [ ] Install GitHub App with correct permissions
- [ ] Add CLAUDE_CODE_OAUTH_TOKEN secret
- [ ] Create .faber.config.toml in test repository
- [ ] Create test issue

**Full Workflow:**
- [ ] Comment "@faber run this issue"
- [ ] Verify workflow starts (comment appears)
- [ ] Verify each phase posts status
- [ ] Verify approval request in guarded mode
- [ ] Approve release
- [ ] Verify PR created
- [ ] Verify issue linked to PR

**Single Phase:**
- [ ] Comment "@faber just design this"
- [ ] Verify only Frame and Architect run
- [ ] Verify spec file created
- [ ] Verify workflow stops after Architect

**Status Query:**
- [ ] Start workflow with "@faber run this"
- [ ] While running, comment "@faber status"
- [ ] Verify status card shows current phase
- [ ] Verify progress information accurate

**Control Commands:**
- [ ] Start workflow to release gate
- [ ] Comment "@faber approve"
- [ ] Verify release proceeds
- [ ] Start new workflow with evaluation failure
- [ ] Comment "@faber retry"
- [ ] Verify evaluate re-runs

**Error Handling:**
- [ ] Test with missing config
- [ ] Test with invalid config
- [ ] Test with invalid intent
- [ ] Test with permission errors
- [ ] Verify all errors post to issue

---

## Future Extensions

### Phase 2: Enhanced Intent Understanding

**Natural Language Processing:**
- Support more conversational intents
- Handle typos and variations
- Multi-turn conversations in issues
- Context-aware suggestions

**Examples:**
```
@faber can you help me with this?
@faber I need a design for the API
@faber show me what you've built so far
@faber looks good, ship it
```

### Phase 3: Multi-Platform Support

**Jira Integration:**
- Support @faber in Jira issue comments
- Jira-specific workflow adaptations
- Jira status field updates

**Linear Integration:**
- Support @faber in Linear issue comments
- Linear-specific status updates
- Linear project board integration

**GitLab Integration:**
- GitLab issue mentions
- GitLab CI/CD integration
- GitLab MR creation

### Phase 4: Advanced Workflows

**Domain-Specific Workflows:**
- Design workflow manager (for UI/UX work)
- Data workflow manager (for data pipelines)
- Infrastructure workflow manager (for cloud resources)

**Parallel Phase Execution:**
- Run multiple builds in parallel
- Concurrent evaluation strategies
- Distributed workflow execution

**Workflow Customization:**
- Define custom phases in config
- Phase dependencies and DAGs
- Conditional phase execution

### Phase 5: Enhanced Collaboration

**Team Collaboration:**
- Multiple reviewers for approval
- Role-based workflow triggers
- Collaborative design sessions
- Handoff between team members

**Integration Hooks:**
- Slack notifications
- Email updates
- Custom webhooks
- Third-party tool integrations

### Phase 6: Analytics & Insights

**Workflow Metrics:**
- Phase completion times
- Success/failure rates
- Bottleneck identification
- Team velocity tracking

**AI Insights:**
- Workflow optimization suggestions
- Pattern recognition
- Anomaly detection
- Predictive analytics

---

## Appendix

### A. File Inventory

**New Files:**
1. `.github/workflows/faber.yml` - GitHub Actions workflow
2. `plugins/faber/commands/mention.md` - Mention command
3. `plugins/faber/docs/github-integration.md` - User documentation
4. `docs/specs/faber-github-integration.md` - This specification

**Modified Files:**
1. `plugins/faber/agents/director.md` - Add intent parsing section
2. `plugins/faber/.claude-plugin/plugin.json` - Register mention command

### B. Estimated Effort

**Development:**
- GitHub workflow: 4 hours
- Mention command: 8 hours
- Director enhancement: 12 hours
- Testing: 16 hours
- Documentation: 8 hours
- **Total: ~48 hours (1 week)**

**Testing & Validation:**
- Integration testing: 16 hours
- Manual testing: 8 hours
- Bug fixes: 8 hours
- **Total: ~32 hours (4 days)**

**Documentation & Launch:**
- User guide: 8 hours
- Examples: 4 hours
- Blog post: 4 hours
- **Total: ~16 hours (2 days)**

**Grand Total: ~96 hours (~2 weeks for 1 developer)**

### C. Dependencies

**External:**
- anthropics/claude-code-action@v1
- GitHub Actions (ubuntu-latest runner)
- Claude Code CLI

**Internal:**
- fractary-work plugin (GitHub handler)
- fractary-repo plugin (GitHub handler)
- FABER core plugin

**Configuration:**
- .faber.config.toml in repository
- CLAUDE_CODE_OAUTH_TOKEN secret

### D. Risks & Mitigations

**Risk 1: GitHub API Rate Limits**
- Mitigation: Implement exponential backoff, cache responses, use conditional requests

**Risk 2: Long-Running Workflows**
- Mitigation: GitHub Actions timeout (6 hours max), checkpoint session state, resumable workflows

**Risk 3: Configuration Complexity**
- Mitigation: Provide presets, validation, clear error messages, setup wizard

**Risk 4: Security Vulnerabilities**
- Mitigation: Protected paths, confirmation gates, permission scoping, code review

**Risk 5: Cost Management**
- Mitigation: Rate limiting, workflow quotas, cost monitoring, usage alerts

### E. Success Metrics

**Adoption:**
- Number of repositories with @faber enabled
- Number of @faber mentions per week
- Number of successful workflows

**Quality:**
- Workflow success rate
- Average workflow completion time
- User-reported issues

**User Satisfaction:**
- User feedback surveys
- Feature requests
- Community engagement

**Technical:**
- System uptime
- API error rates
- Test coverage

### F. References

**Related Documents:**
- [FABER Architecture Specification](./fractary-faber-architecture.md)
- [Work Plugin Specification](./fractary-work-plugin-specification.md)
- [Fractary Plugin Standards](../standards/FRACTARY-PLUGIN-STANDARDS.md)

**External Resources:**
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Claude Code Documentation](https://docs.claude.com/claude-code)
- [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)

---

**Document Version History:**

- v1.0.0 (2025-10-31): Initial specification
  - Core architecture defined
  - Implementation plan outlined
  - Component specifications detailed
  - Testing strategy documented

**Next Review:** After Phase 1 implementation completion

**Maintainers:** Fractary FABER Team

**Status:** Ready for Implementation
