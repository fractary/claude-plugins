# Automatic FABER Primitives

This document defines the automatic primitives that execute at phase boundaries in the FABER workflow. These primitives are **built into the faber-manager skill** and do not require explicit step definitions in workflow configs.

## Overview

| Primitive | Phase | Trigger Point | Condition |
|-----------|-------|---------------|-----------|
| Issue Fetch | Pre-workflow | faber-director Step 0.5 | work_id provided |
| Work Type Classification | Architect Entry | Before Architect steps | Always |
| Branch Creation | Build Entry | Before Build steps | work_type != "analysis" AND branch not exists |
| PR Creation | Release Exit | After Release steps | commits exist AND PR not exists |

## Issue Fetch (faber-director)

**Location**: `faber-director/SKILL.md` Step 0.5

**Status**: Already implemented. No changes needed.

**Behavior**:
- When `work_id` is provided to faber-director, issue is fetched automatically
- Issue data (title, description, labels, comments) stored in workflow context
- Passed to faber-manager for all subsequent phases
- When `work_id` NOT provided, issue fetch is skipped (local workflow mode)

## Work Type Classification

**Location**: Architect phase entry (before pre-hooks)

**Purpose**: Classify the work to determine:
1. Whether to generate a spec
2. Which spec template to use
3. Whether commits are expected (affects branch/PR decisions)

### Classification Logic

```
INPUT: Issue context (title, description, labels)

CLASSIFICATION RULES (in priority order):

1. CHECK LABELS FIRST (most explicit signal):
   - Labels contain "analysis" or "research" → ANALYSIS
   - Labels contain "chore" or "dependencies" or "maintenance" → SIMPLE
   - Labels contain "bug" or "defect" or "hotfix" → MODERATE
   - Labels contain "feature" or "enhancement" or "breaking" → COMPLEX

2. CHECK TITLE KEYWORDS (if no label match):
   - Title contains "typo", "spelling", "grammar" → SIMPLE
   - Title contains "bump", "upgrade", "update" + "version"/"dependency" → SIMPLE
   - Title contains "config", "configuration" + "change"/"update" → SIMPLE
   - Title contains "analyze", "audit", "investigate", "research" → ANALYSIS
   - Title contains "fix", "bug", "patch", "repair" → MODERATE
   - Title contains "add", "implement", "create", "feature" → COMPLEX
   - Title contains "refactor", "redesign", "rewrite", "overhaul" → COMPLEX

3. DEFAULT: COMPLEX (err on side of creating artifacts)
```

### Work Type Outcomes

| Work Type | Spec Generation | Spec Template | Expects Commits | Branch Created | PR Created |
|-----------|-----------------|---------------|-----------------|----------------|------------|
| ANALYSIS | Skip | N/A | No | No | No |
| SIMPLE | Skip | N/A | Yes | Yes | Yes |
| MODERATE | Generate | basic | Yes | Yes | Yes |
| COMPLEX | Generate | feature | Yes | Yes | Yes |

### State Updates

After classification, update workflow state:

```json
{
  "work_type": "complex",
  "work_type_classification": {
    "type": "complex",
    "reason": "Label 'feature' detected",
    "expects_commits": true,
    "spec_required": true,
    "spec_template": "feature",
    "classified_at": "2025-12-01T15:00:00Z"
  }
}
```

### Logging

Log classification decision for debugging:

```json
{
  "event_type": "automatic_primitive",
  "primitive": "work_type_classification",
  "phase": "architect",
  "trigger": "phase_entry",
  "result": {
    "work_type": "complex",
    "reason": "Label 'feature' detected",
    "expects_commits": true,
    "spec_required": true
  }
}
```

## Branch Creation

**Location**: Build phase entry (after pre-hooks, before steps)

**Purpose**: Create semantic branch with worktree for isolated development.

### Trigger Conditions

Branch creation is triggered when ALL of these are true:
1. Entering Build phase
2. `work_type != "analysis"` (analysis workflows don't produce commits)
3. Branch does not already exist in state (not a resume scenario)
4. `worktree` parameter is true (always true from faber-director)

### Skip Conditions

Skip branch creation (log and continue) when ANY of these are true:
1. `state.branch.name` exists → Resume scenario, reuse existing branch
2. `state.work_type_classification.expects_commits == false` → Analysis workflow
3. Already on a feature branch matching work_id pattern → Manual branch creation

### Branch Creation Logic

```
IF state.branch.name exists THEN
  LOG "Reusing existing branch: {state.branch.name}"
  VERIFY branch is checked out
  CONTINUE to phase steps

ELSE IF NOT state.work_type_classification.expects_commits THEN
  LOG "Analysis workflow - skipping branch creation"
  CONTINUE to phase steps (on current branch)

ELSE
  # Determine branch prefix from work type
  prefix = CASE state.work_type:
    "feature", "complex" → "feat"
    "bug", "moderate" → "fix"
    "chore", "simple" → "chore"
    "docs" → "docs"
    DEFAULT → "feat"

  # Generate branch description from issue title
  description = slugify(state.issue.title)  # max 50 chars

  # Create branch with worktree
  INVOKE /repo:branch-create "{description}" --work-id {work_id} --prefix {prefix} --worktree

  # Capture results
  branch_name = "{prefix}/{work_id}-{description}"
  worktree_path = result.worktree_path

  # Update state
  state.branch = {
    "name": branch_name,
    "prefix": prefix,
    "worktree_path": worktree_path,
    "base_branch": "main",
    "created_at": NOW(),
    "created_by": "automatic_primitive"
  }

  LOG "Created branch {branch_name} with worktree at {worktree_path}"
END
```

### State Updates

After branch creation:

```json
{
  "branch": {
    "name": "feat/189-automatic-workflow-primitives",
    "prefix": "feat",
    "worktree_path": "/path/to/repo-wt-feat-189-automatic-workflow-primitives",
    "base_branch": "main",
    "created_at": "2025-12-01T15:10:00Z",
    "created_by": "automatic_primitive"
  }
}
```

### Logging

```json
{
  "event_type": "automatic_primitive",
  "primitive": "branch_creation",
  "phase": "build",
  "trigger": "phase_entry",
  "result": {
    "action": "created",
    "branch_name": "feat/189-automatic-workflow-primitives",
    "worktree_path": "/path/to/worktree",
    "reason": "work_type=complex expects commits"
  }
}
```

### Error Handling

| Error | Action |
|-------|--------|
| Branch already exists (git error) | Check if it's our branch, if yes reuse, if no fail with clear message |
| Worktree creation fails | Log error, continue without worktree (degraded mode) |
| No work_id available | Skip branch creation, log warning |

## PR Creation

**Location**: Release phase exit (after steps, before post-hooks)

**Purpose**: Automatically create pull request when work is ready for review.

### Trigger Conditions

PR creation is triggered when ALL of these are true:
1. Completing Release phase (after all steps)
2. Commits exist on branch (diff from base branch)
3. PR does not already exist in state (not a resume scenario)
4. Autonomy level allows (or user approves)

### Skip Conditions

Skip PR creation (log and continue) when ANY of these are true:
1. `state.pr.number` exists → PR already created
2. No commits on branch → Nothing to review
3. `work_type == "analysis"` → No code changes expected
4. Autonomy denied and user rejected → User chose not to create PR

### PR Creation Logic

```
IF state.pr.number exists THEN
  LOG "PR already exists: #{state.pr.number}"
  CONTINUE to post-phase hooks

ELSE
  # Check for commits
  commits = git log {base_branch}..HEAD --oneline

  IF commits.length == 0 THEN
    LOG "No commits on branch - skipping PR creation"
    CONTINUE to post-phase hooks
  END

  # Check autonomy
  IF autonomy.level == "guarded" AND "release" in autonomy.require_approval_for THEN
    # Pause for approval
    PROMPT USER: "Ready to create PR for issue #{work_id}. Proceed?"
    IF user.response == "no" THEN
      LOG "PR creation declined by user"
      CONTINUE to post-phase hooks
    END
  END

  # Generate PR title
  IF state.spec.path exists THEN
    title = extract_title_from_spec(state.spec.path)
  ELSE
    title = state.issue.title
  END

  # Generate PR body
  body = generate_pr_body({
    summary: state.spec.summary OR state.issue.description,
    issue_link: "Closes #{work_id}",
    spec_link: state.spec.path,
    testing_notes: state.phases.evaluate.results,
    commits: commits
  })

  # Create PR
  INVOKE /repo:pr-create "{title}" --body "{body}" --work-id {work_id}

  # Capture results
  pr_number = result.number
  pr_url = result.url

  # Update state
  state.pr = {
    "number": pr_number,
    "url": pr_url,
    "title": title,
    "created_at": NOW(),
    "created_by": "automatic_primitive"
  }

  LOG "Created PR #{pr_number}: {pr_url}"
END
```

### PR Body Template

```markdown
## Summary

{summary_from_spec_or_issue}

## Changes

{commit_list}

## Related

- Closes #{work_id}
- Spec: {spec_path}

## Testing

{testing_notes_from_evaluate_phase}

---
Generated by FABER workflow
```

### State Updates

After PR creation:

```json
{
  "pr": {
    "number": 190,
    "url": "https://github.com/org/repo/pull/190",
    "title": "feat: Automatic FABER workflow primitives",
    "created_at": "2025-12-01T16:00:00Z",
    "created_by": "automatic_primitive"
  }
}
```

### Logging

```json
{
  "event_type": "automatic_primitive",
  "primitive": "pr_creation",
  "phase": "release",
  "trigger": "phase_exit",
  "result": {
    "action": "created",
    "pr_number": 190,
    "pr_url": "https://github.com/org/repo/pull/190",
    "commits_count": 5,
    "reason": "commits exist, autonomy approved"
  }
}
```

### Autonomy Behavior

| Autonomy Level | PR Creation Behavior |
|----------------|---------------------|
| `autonomous` | Create PR automatically, no prompt |
| `guarded` | Pause and prompt user before creating |
| `assist` | Create as draft PR |
| `dry-run` | Log what would happen, don't create |

### Error Handling

| Error | Action |
|-------|--------|
| PR creation fails (API error) | Log error, mark workflow as needing manual PR |
| No commits but user expects PR | Warn user, suggest checking branch |
| Duplicate PR detection | Check for existing PR, link if found |

## Backward Compatibility

If workflow configs still contain explicit primitive steps (e.g., `fetch-work`, `create-branch`, `create-pr`), the automatic primitives check state first:

1. **Explicit step runs first**: State updated, automatic primitive becomes no-op
2. **Automatic primitive runs first**: State updated, explicit step should check and skip

This allows gradual migration from explicit to automatic primitives.

## Integration with Existing Skills

| Automatic Primitive | Invokes |
|--------------------|---------|
| Issue Fetch | `/work:issue-fetch` (via faber-director) |
| Work Type Classification | Inline logic (no external skill) |
| Branch Creation | `/repo:branch-create` with `--worktree` |
| PR Creation | `/repo:pr-create` |

## Debugging

All automatic primitive decisions are logged with:
- `event_type: "automatic_primitive"`
- `primitive`: Name of primitive
- `phase`: Which phase triggered it
- `trigger`: "phase_entry" or "phase_exit"
- `result`: What action was taken and why

Query logs with:
```bash
# Find all automatic primitive events for a workflow
jq 'select(.event_type == "automatic_primitive")' workflow-log.json
```
