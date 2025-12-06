# FABER Workflow Guide

Complete guide to understanding and using FABER workflows.

## Table of Contents

- [Overview](#overview)
- [Workflow Phases](#workflow-phases)
- [Phase Details](#phase-details)
- [Retry Mechanism](#retry-mechanism)
- [Session Management](#session-management)
- [Status Cards](#status-cards)
- [Error Handling](#error-handling)
- [Examples](#examples)

## Overview

FABER (Frame → Architect → Build → Evaluate → Release) automates the complete software development lifecycle from work item to production.

### Workflow Inheritance (v2.2+)

FABER v2.2 introduces **workflow inheritance**, allowing you to extend existing workflows:

```
                 fractary-faber:default
                         |
                    (extends)
                         |
                   my-project
                         |
                    (extends)
                         |
                   my-hotfix
```

**Key concepts**:
- **Default workflow**: `fractary-faber:default` contains all standard FABER steps
- **Extends**: Your workflow can extend any other workflow
- **Pre/post steps**: Add steps before or after inherited steps
- **Skip steps**: Exclude specific inherited steps

**Example extending default**:
```json
{
  "extends": "fractary-faber:default",
  "skip_steps": ["merge-pr"],
  "phases": {
    "build": {
      "pre_steps": [
        { "id": "lint", "prompt": "Run npm run lint" }
      ]
    }
  }
}
```

See [MIGRATION-v2.2.md](./MIGRATION-v2.2.md) for complete inheritance documentation.

### The 5 Phases

```
Issue/Ticket
    ↓
📋 Frame ────────→ Classify and prepare
    ↓
📐 Architect ────→ Design solution
    ↓
🔨 Build ────────→ Implement solution
    ↓
🧪 Evaluate ─────→ Test and review
    ↓ (retry loop if needed)
🚀 Release ──────→ Deploy/publish
    ↓
Pull Request / Production
```

### Workflow Execution

```bash
# Start workflow for an issue
/fractary-faber:run --work-id 123

# Or with explicit target
/fractary-faber:run customer-analytics --work-id 123

# FABER executes:
1. Frame phase      (1-2 minutes)
2. Architect phase  (2-5 minutes)
3. Build phase      (5-15 minutes)
4. Evaluate phase   (2-5 minutes, with potential retries)
5. Release phase    (1-2 minutes, may pause for approval)

# Total time: ~10-30 minutes (varies by complexity)
```

## Workflow Phases

### Phase 1: Frame

**Purpose**: Fetch and classify the work item, set up environment

**Input**: Work item ID (GitHub issue, Jira ticket, etc.)

**Outputs**:
- Work item details (title, description, labels)
- Work type classification (/bug, /feature, /chore, /patch)
- Git branch created
- State initialized

**Operations**:
1. Fetch work item from tracking system
2. Parse and analyze work item content
3. Classify work type based on labels/content
4. Generate branch name (e.g., `feat/123-add-authentication`)
5. Create git branch from default branch
6. Create state file (`.fractary/plugins/faber/state.json`)
7. Post Frame start status card
8. Update state with Frame complete

**Time**: ~1-2 minutes

**Failure Modes**:
- Work item not found → workflow fails
- Authentication failed → workflow fails
- Git branch already exists → may reuse or fail

### Phase 2: Architect

**Purpose**: Design solution and create detailed specification

**Input**: Work item details, work type

**Outputs**:
- Implementation specification file
- Specification committed to git
- Specification URL (if file storage configured)

**Operations**:
1. Analyze work item requirements
2. Review relevant codebase context
3. Generate detailed implementation specification
4. Create spec file (`.faber/specs/<work_id>-<type>.md`)
5. Commit specification to branch
6. Upload specification to storage (if configured)
7. Post Architect status with spec URL
8. Update state with Architect complete

**Specification Contents**:
- Work item summary
- Technical approach
- Implementation steps
- Test plan
- Acceptance criteria
- Edge cases and considerations

**Time**: ~2-5 minutes

**Failure Modes**:
- Cannot parse work item → workflow fails
- File write error → workflow fails
- Git commit error → workflow fails

### Phase 3: Build

**Purpose**: Implement solution from specification

**Input**: Implementation specification

**Outputs**:
- Code changes
- Tests (if applicable)
- Documentation updates
- Changes committed to git

**Operations**:
1. Read implementation specification
2. Implement solution following spec
3. Create/update tests as needed
4. Update documentation
5. Lint and format code
6. Commit changes with semantic message
7. Push branch to remote
8. Post Build status
9. Update state with Build complete

**Commit Message Format**:
```
<type>: <description>

Refs: #<issue-id>
Work-ID: <work_id>

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Time**: ~5-15 minutes (varies by complexity)

**Failure Modes**:
- Syntax errors → workflow fails
- Git push error → workflow fails
- Merge conflicts → workflow fails

### Phase 4: Evaluate

**Purpose**: Test and review implementation with retry loop

**Input**: Implemented code

**Outputs**:
- GO/NO-GO decision
- Test results
- Review findings
- Retry count (if retries occurred)

**Operations**:
1. Run domain-specific tests (unit, integration, e2e)
2. Execute code review checks (linting, formatting, complexity)
3. Validate against specification
4. Make GO/NO-GO decision
5. If NO-GO and retries remain:
   - Update state with NO-GO
   - Return to Build phase
6. If NO-GO and no retries remain:
   - Fail workflow
7. If GO:
   - Post Evaluate success
   - Update state with GO decision
   - Proceed to Release

**Decision Criteria**:
- All tests pass → GO
- Code quality acceptable → GO
- Specification requirements met → GO
- Any test failures → NO-GO
- Code quality issues → NO-GO (configurable)
- Missing requirements → NO-GO

**Time**: ~2-5 minutes per attempt

**Failure Modes**:
- Test failures after max retries → workflow fails
- Test execution error → workflow fails

### Phase 5: Release

**Purpose**: Deploy/publish and create pull request

**Input**: Tested implementation

**Outputs**:
- Pull request created
- PR URL
- Optionally: PR merged (if auto_merge enabled)
- Optionally: Work item closed

**Operations**:
1. Create pull request
2. Post PR URL to work item
3. Upload artifacts to storage (if configured)
4. If autonomy = "guarded":
   - Post approval request status card
   - Pause workflow
   - Wait for manual approval
5. If autonomy = "autonomous" and auto_merge = true:
   - Merge pull request
   - Delete branch (optional)
6. Post Release complete status
7. Update state with Release complete

**Pull Request Format**:
```markdown
## Summary
<Implementation summary>

## Changes
<List of changes>

## Test Plan
<Testing performed>

## Related Issues
Closes #<issue-id>

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
Work-ID: <work_id>
```

**Time**: ~1-2 minutes

**Failure Modes**:
- PR creation failed → workflow fails
- Merge conflicts → workflow fails
- Auto-merge failed → workflow fails (if enabled)

## Phase Details

### Work Type Classification

FABER classifies work into 4 types:

#### /bug - Bug Fix

**Indicators**:
- Labels: "bug", "fix", "defect"
- Keywords: "error", "broken", "doesn't work", "crash"

**Branch**: `fix/<issue-id>-<description>`

**Example**: `fix/123-login-error`

#### /feature - New Feature

**Indicators**:
- Labels: "feature", "enhancement"
- Keywords: "add", "create", "new", "implement"

**Branch**: `feat/<issue-id>-<description>`

**Example**: `feat/456-user-dashboard`

#### /chore - Maintenance

**Indicators**:
- Labels: "chore", "maintenance", "refactor"
- Keywords: "refactor", "update", "cleanup", "dependencies"

**Branch**: `chore/<issue-id>-<description>`

**Example**: `chore/789-update-deps`

#### /patch - Hotfix

**Indicators**:
- Labels: "hotfix", "urgent", "critical"
- Keywords: "urgent", "hotfix", "critical"

**Branch**: `hotfix/<issue-id>-<description>`

**Example**: `hotfix/101-security-patch`

### Branch Naming Convention

Format: `<type>/<issue-id>-<slug>`

**Components**:
- `<type>`: fix, feat, chore, hotfix
- `<issue-id>`: Issue/ticket number
- `<slug>`: Slugified title (lowercase, hyphens)

**Examples**:
```
feat/123-add-user-authentication
fix/456-login-validation-error
chore/789-update-typescript-version
hotfix/101-xss-vulnerability-fix
```

### Commit Message Convention

FABER uses Conventional Commits format:

```
<type>: <description>

[optional body]

Refs: #<issue-id>
Work-ID: <work_id>
[optional metadata]

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `chore`: Maintenance
- `docs`: Documentation
- `test`: Tests
- `refactor`: Code refactoring

## Retry Mechanism

### Evaluate → Build Loop

FABER includes an intelligent retry mechanism:

```
Build ──→ Evaluate ──→ GO ──→ Release
            ↓ NO-GO
            ↓ (retry < max)
         Build ──→ Evaluate
            ↓ NO-GO
            ↓ (retry < max)
         Build ──→ Evaluate
            ↓ NO-GO
            ↓ (retry >= max)
          FAIL
```

### Retry Configuration

```json
{
  "workflows": [{
    "phases": {
      "evaluate": {
        "enabled": true,
        "max_retries": 3,
        "retry_on_failure": true
      }
    }
  }]
}
```

**Values**:
- `0`: No retries - fail immediately
- `1-5`: Recommended range
- `3`: Default (good balance)
- `>5`: Not recommended (too slow)

### Retry Behavior

**On NO-GO Decision**:
1. Increment retry counter
2. Check if retry_count < max_retries
3. If yes:
   - Update state with retry_count
   - Return to Build phase
   - Re-implement with evaluation feedback
   - Run Evaluate again
4. If no:
   - Fail workflow
   - Post error status card
   - Preserve state for debugging

**What Changes on Retry**:
- Build phase re-executes with evaluation feedback
- Implementation may be adjusted
- Tests run again
- Retry count increments

**What Doesn't Change**:
- Frame data (work item, branch)
- Architect data (specification)
- Workflow metadata

### Retry Tracking

State file tracks retries:

```json
{
  "phases": {
    "build": {
      "status": "completed",
      "data": {
        "retry_count": 2
      }
    },
    "evaluate": {
      "status": "completed",
      "data": {
        "decision": "go",
        "retry_count": 2
      }
    }
  }
}
```

## State Management

### Dual-State Tracking (v2.0)

FABER v2.0 uses a dual-state tracking approach for optimal workflow management:

#### Current State

**Location**: `.fractary/plugins/faber/state.json`

**Purpose**:
- Track current workflow state
- Enable workflow resumption
- Single active workflow tracking
- Lightweight and always current

**Format**:
```json
{
  "work_id": "abc12345",
  "metadata": {
    "source_type": "github",
    "source_id": "123",
    "work_domain": "engineering",
    "created_at": "2025-10-22T10:30:00Z",
    "updated_at": "2025-10-22T10:45:00Z"
  },
  "current_phase": "build",
  "phases": {
    "frame": {
      "status": "completed",
      "data": {
        "work_type": "feature",
        "branch_name": "feat/123-add-auth"
      }
    },
    "architect": {
      "status": "completed",
      "data": {
        "spec_file": ".faber/specs/abc12345-feature.md",
        "spec_url": "https://..."
      }
    },
    "build": {
      "status": "in_progress",
      "data": {
        "retry_count": 0
      }
    },
    "evaluate": {
      "status": "pending"
    },
    "release": {
      "status": "pending"
    }
  },
  "history": []
}
```

#### Historical Logs

**Location**: Managed by `fractary-logs` plugin

**Purpose**:
- Complete audit trail across all workflows
- Searchable historical data
- Compliance and debugging
- Parallel workflow tracking

**Benefits of Dual Approach**:
- **Current State**: Always reflects single active workflow, enables resume
- **Historical Logs**: Complete audit trail, no accumulation in state file
- **Separation of Concerns**: Current vs. historical tracking
- **Scalability**: Single state file + centralized log management

See [STATE-TRACKING.md](STATE-TRACKING.md) for detailed implementation.

### State Lifecycle

1. **Create**: State created at workflow start (Frame phase)
2. **Update**: Updated after each phase completes
3. **Query**: Can be queried via `/fractary-faber:status`
4. **Complete**: State preserved, workflow logged to fractary-logs
5. **New Workflow**: State overwritten for next workflow

### State Operations

**Create State**:
```bash
# Automatically created by workflow-manager
# Via: skills/core scripts
```

**Update State**:
```bash
# Automatically updated after each phase
# Via: skills/core scripts
```

**Query State**:
```bash
# View status
/fractary-faber:status

# Raw state file
cat .fractary/plugins/faber/state.json

# View historical logs
# (via fractary-logs plugin commands)
```

## Status Cards

### Purpose

Status cards are formatted updates posted to work tracking systems (GitHub issues, Jira tickets, etc.) to keep stakeholders informed.

### Format

```markdown
🎬 **FABER Workflow Status**

**Phase**: Frame
**Status**: Started
**Work ID**: `abc12345`

Fetching work item and preparing environment...

---
🤖 Powered by FABER
```

### When Posted

- **Workflow Start**: Initial status card
- **Phase Start**: Each phase begins
- **Phase Complete**: Each phase finishes
- **Evaluate Results**: GO/NO-GO decision
- **Release Approval**: Approval request (guarded mode)
- **Workflow Complete**: Final success message
- **Errors**: Any phase failures

### Example Status Card Progression

**1. Workflow Start**:
```markdown
🚀 **FABER Workflow Started**

**Work ID**: `abc12345`
**Domain**: engineering
**Autonomy**: guarded

Executing phases:
1. ⏳ Frame - Fetch and classify work item
2. ⏸️ Architect - Generate specification
3. ⏸️ Build - Implement solution
4. ⏸️ Evaluate - Test and review
5. ⏸️ Release - Deploy/publish
```

**2. Phase Updates**:
```markdown
✅ **Frame Complete**

Branch created: `feat/123-add-authentication`
Work type: /feature

Next: Architect phase
```

**3. Approval Request** (guarded mode):
```markdown
⏸️ **Release Approval Required**

**Work ID**: `abc12345`
**PR**: https://github.com/org/repo/pull/45

Implementation complete and tested. Ready to create pull request.

To approve:
```bash
/fractary-faber:approve abc12345
```
```

**4. Workflow Complete**:
```markdown
🎉 **FABER Workflow Complete**

**Work ID**: `abc12345`

## Summary
1. ✅ Frame - Work classified
2. ✅ Architect - Specification generated
3. ✅ Build - Solution implemented
4. ✅ Evaluate - Tests passed
5. ✅ Release - PR created

**Pull Request**: https://github.com/org/repo/pull/45

---
🤖 Powered by FABER
```

## Error Handling

### Error Types

**Configuration Errors** (exit code 3):
- Missing configuration file
- Invalid configuration
- Missing credentials

**Work Item Errors** (exit codes 10-13):
- Work item not found (10)
- Authentication failed (11)
- Network error (12)
- Permission denied (13)

**Workflow Errors** (exit code 1):
- Phase execution failed
- Max retries exceeded
- Git operation failed
- Test failures

### Error Recovery

**Automatic Recovery**:
- Evaluate → Build retry loop (up to max_evaluate_retries)

**Manual Recovery**:
```bash
# Check what failed
/fractary-faber:status abc12345

# View state details
cat .fractary/plugins/faber/state.json | jq .

# Fix issues manually

# Retry workflow (future)
/fractary-faber:retry abc12345
```

### Error Messages

FABER provides detailed error messages:

```
❌ FABER Workflow Failed

Work ID: abc12345
Phase: Evaluate
Error: Test failures after 3 retry attempts

Failed Tests:
  - test/auth.test.ts: User login validation
  - test/api.test.ts: API endpoint authentication

To investigate:
  /fractary-faber:status abc12345

To retry manually:
  1. Fix failing tests
  2. Run: /fractary-faber:retry abc12345
```

## Examples

### Example 1: Simple Feature Workflow

```bash
# Start workflow for issue #123
/fractary-faber:run --work-id 123

# Output:
🚀 Starting FABER workflow...

Work Item: github/123
Title: Add user authentication
Work ID: abc12345
Domain: engineering
Autonomy: guarded

======================================
📋 Phase 1: Frame
======================================
Fetching issue from GitHub...
✅ Issue found: Add user authentication
Classifying work type...
✅ Work type: /feature
Creating branch: feat/123-add-user-authentication
✅ Branch created
✅ Frame phase complete

======================================
📐 Phase 2: Architect
======================================
Analyzing requirements...
Generating specification...
✅ Specification: .faber/specs/abc12345-feature.md
Committing specification...
✅ Specification committed
✅ Architect phase complete

======================================
🔨 Phase 3: Build
======================================
Implementing from specification...
Creating tests...
✅ Implementation complete
Committing changes...
✅ Changes committed and pushed
✅ Build phase complete

======================================
🧪 Phase 4: Evaluate
======================================
Running tests...
✅ All tests passed (15/15)
Running code review...
✅ Code quality acceptable
Decision: GO
✅ Evaluate phase complete - GO decision

======================================
🚀 Phase 5: Release
======================================
Creating pull request...
✅ PR created: https://github.com/acme/app/pull/45
⏸️ Waiting for release approval (guarded mode)

Post '/fractary-faber:approve abc12345' to proceed

# Later, after review:
/fractary-faber:approve abc12345  # (future command)
# Or manually merge PR via GitHub UI
```

### Example 2: Workflow with Retries

```bash
/fractary-faber:run --work-id 456

# ... Frame, Architect, Build complete ...

======================================
🧪 Phase 4: Evaluate (with retry loop)
======================================
Running tests...
❌ Tests failed (2/10 failing)
Decision: NO-GO
Retry 1 of 3...

Re-running Build phase...
✅ Build retry complete

Running tests...
❌ Tests failed (1/10 failing)
Decision: NO-GO
Retry 2 of 3...

Re-running Build phase...
✅ Build retry complete

Running tests...
✅ All tests passed (10/10)
Decision: GO
✅ Evaluate phase complete - GO decision (after 2 retries)

# Continues to Release...
```

### Example 3: Autonomous Workflow

```bash
/fractary-faber:run --work-id 789 --autonomy autonomous --auto-merge

# Executes all phases without pausing
# Automatically merges PR at the end

✅ All 5 phases completed successfully!
Pull Request: https://github.com/acme/app/pull/46 (merged)
```

## Workflow Customization

### Using Prompts to Customize Behavior

FABER v2.0 supports powerful customization via the `prompt` field in step configuration:

#### Direct Claude Execution

Steps without skills execute directly using the `prompt` field:

```json
{
  "name": "implement",
  "description": "Implement solution from specification",
  "prompt": "Implement based on specification, following TDD approach with comprehensive test coverage"
}
```

**Benefits**:
- Full control over execution behavior
- Project-specific workflows without creating custom skills
- Easy to adjust without code changes

#### Customizing Plugin Skills

Steps with skills can use prompts to customize behavior:

```json
{
  "name": "create-pr",
  "description": "Create pull request for review",
  "skill": "fractary-repo:pr-manager",
  "prompt": "Create PR with: summary of changes, testing checklist, screenshots if UI changed, FABER attribution"
}
```

**Benefits**:
- Customize plugin behavior without forking
- Add project-specific requirements
- Maintain reusable plugin skills

### Customization Examples

**Example 1: Testing Requirements**
```json
{
  "name": "test",
  "description": "Run automated test suite",
  "prompt": "Run tests with coverage. Require: all tests pass, coverage >= 80% for new code, no HIGH severity linting issues"
}
```

**Example 2: Code Review Standards**
```json
{
  "name": "review",
  "description": "Code quality review",
  "prompt": "Review focusing on: correctness, security (OWASP Top 10), maintainability. Skip: style nitpicks if linter passes"
}
```

**Example 3: Implementation Style**
```json
{
  "name": "implement",
  "description": "Implement with team conventions",
  "prompt": "Implement following: 1) TypeScript strict mode, 2) Functional style with React hooks, 3) Error boundaries for UI components, 4) Inline comments for complex logic"
}
```

### When to Customize

| Situation | Solution |
|-----------|----------|
| Standard workflow sufficient | Use plugin skills without prompts |
| Need slight behavior change | Add prompt to customize skill |
| Project-specific requirements | Use prompt for direct execution |
| Team coding standards | Add prompts with style guidelines |
| Compliance requirements | Add prompts with audit trail needs |

**See [PROMPT-CUSTOMIZATION.md](./PROMPT-CUSTOMIZATION.md) for comprehensive customization guide.**

---

## Best Practices

1. **Use guarded mode** for production workflows
2. **Review specifications** before Build phase (when possible)
3. **Monitor status cards** in your issue tracker
4. **Check status frequently** during execution
5. **Keep max_evaluate_retries reasonable** (2-4)
6. **Test with dry-run first** when trying new configurations
7. **Preserve workflow logs** for audit trail (via fractary-logs plugin)
8. **Use descriptive issue titles** for better branch names
9. **Add prompts for clarity** when steps don't use skills
10. **Customize with prompts** before forking plugins

## See Also

- [Configuration Guide](configuration.md) - Configure FABER
- [Prompt Customization](PROMPT-CUSTOMIZATION.md) - Comprehensive customization guide
- [Architecture](architecture.md) - System design
- [README](../README.md) - Quick start
