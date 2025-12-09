---
spec_id: WORK-00332-faber-workflow-command-migration
work_id: 332
issue_url: https://github.com/fractary/claude-plugins/issues/332
title: "FABER: Migrate core and default workflows to command-based step format"
type: refactoring
status: draft
created: 2025-12-09
updated: 2025-12-09
author: claude
validated: false
severity: medium
source: issue+context
parent_issue: 328
---

# Refactoring Specification: FABER Workflow Command Migration

**Issue**: [#332](https://github.com/fractary/claude-plugins/issues/332)
**Parent Issue**: [#328](https://github.com/fractary/claude-plugins/issues/328)
**Type**: Refactoring
**Severity**: Medium
**Status**: Draft
**Created**: 2025-12-09

## Summary

Migrate FABER core and default workflow configurations from skill-based to command-based step format. This implements Phase 4 (Migration) of Issue #328's deterministic step execution architecture.

## Background

Issue #328 introduced deterministic step execution via the Task tool. Workflow steps should now specify a `command` field (public API) instead of a `skill` field (implementation detail). This provides deterministic execution via the Task tool and aligns with the "commands are public API, skills are implementation details" principle.

**Current format (skill-based)**:
```json
{
  "id": "generate-spec",
  "name": "Generate Specification",
  "skill": "fractary-spec:spec-generator",
  "config": { ... }
}
```

**New format (command-based)**:
```json
{
  "id": "generate-spec",
  "name": "Generate Specification",
  "description": "Create technical specification from issue context",
  "command": "/fractary-spec:create",
  "arguments": {
    "work_id": "{work_id}"
  }
}
```

## Scope of Changes

### New Files to Create

| File | Purpose |
|------|---------|
| `plugins/faber/commands/build.md` | Router command for build skill |
| `plugins/faber/commands/review.md` | Router command for issue-reviewer skill |

### Files to Modify

| File | Changes |
|------|---------|
| `plugins/faber/config/workflows/core.json` | Convert 8 steps to command-based format |
| `plugins/faber/config/workflows/default.json` | Convert 3 steps to command-based format |

## Detailed Requirements

### Requirement 1: Create build.md Command

**File**: `plugins/faber/commands/build.md`

**Purpose**: Router command that invokes the faber-manager agent to execute the build skill.

**Pattern**: Follow existing faber command patterns (audit.md, execute.md, plan.md).

**Frontmatter**:
```yaml
---
name: fractary-faber:build
description: Execute the build phase implementation based on specification
argument-hint: '[--work-id <id>] [--use-spec] [--post-comments]'
tools: Skill
model: claude-haiku-4-5
---
```

**Responsibilities**:
1. Parse optional arguments (work_id, use_spec flag, post_comments flag)
2. Pass context to the build skill
3. Return skill output

### Requirement 2: Create review.md Command

**File**: `plugins/faber/commands/review.md`

**Purpose**: Router command that invokes the faber-manager agent to execute the issue-reviewer skill.

**Pattern**: Follow existing faber command patterns.

**Frontmatter**:
```yaml
---
name: fractary-faber:review
description: Review implementation against issue requirements
argument-hint: '<work-id>'
tools: Skill
model: claude-haiku-4-5
---
```

**Responsibilities**:
1. Parse work_id argument (required)
2. Invoke issue-reviewer skill
3. Return review results

### Requirement 3: Update core.json Workflow

**File**: `plugins/faber/config/workflows/core.json`

Convert the following 8 steps from current format to command-based:

| Phase | Step ID | Current | New Command |
|-------|---------|---------|-------------|
| frame/pre_steps | core-fetch-or-create-issue | prompt | `/fractary-work:issue-fetch` |
| frame/pre_steps | core-switch-or-create-branch | prompt | `/fractary-repo:branch-create` |
| build/post_steps | core-commit-and-push-build | skill: fractary-repo:commit-creator | `/fractary-repo:commit-and-push` |
| evaluate/pre_steps | core-issue-review | skill: fractary-faber:issue-reviewer | `/fractary-faber:review` |
| evaluate/post_steps | core-commit-and-push-evaluate | skill: fractary-repo:commit-creator | `/fractary-repo:commit-and-push` |
| evaluate/post_steps | core-create-pr | skill: fractary-repo:pr-manager | `/fractary-repo:pr-create` |
| evaluate/post_steps | core-review-pr-checks | skill: fractary-repo:pr-manager | `/fractary-repo:pr-review` |
| release/post_steps | core-merge-pr | skill: fractary-repo:pr-manager | `/fractary-repo:pr-merge` |

**New Step Schema** (for each step):
```json
{
  "id": "step-id",
  "name": "Human Readable Name",
  "description": "What this step does",
  "command": "/plugin-name:command-name",
  "arguments": {
    "arg1": "{placeholder}",
    "arg2": "value"
  }
}
```

**Notes**:
- Remove `prompt` field (replaced by command)
- Remove `skill` field (replaced by command)
- Remove `config` field (configuration now lives in command arguments)
- Keep `id`, `name`, `description` fields

### Requirement 4: Update default.json Workflow

**File**: `plugins/faber/config/workflows/default.json`

Convert the following 3 steps from skill-based to command-based:

| Phase | Step ID | Current | New Command |
|-------|---------|---------|-------------|
| architect/steps | generate-spec | skill: fractary-spec:spec-generator | `/fractary-spec:create` |
| architect/steps | refine-spec | skill: fractary-spec:spec-refiner | `/fractary-spec:refine` |
| build/steps | implement | skill: fractary-faber:build | `/fractary-faber:build` |

## Step Conversion Examples

### Example 1: prompt-based to command-based

**Before** (core.json - frame phase):
```json
{
  "id": "core-fetch-or-create-issue",
  "name": "Fetch or Create Issue",
  "description": "Fetch existing issue or create new one. Reads referenced docs and existing commits for context.",
  "prompt": "If work_id provided: fetch issue with fractary-work:issue-fetcher, read all referenced documents and existing commits for context. If no work_id: create issue with fractary-work:issue-creator using the target description."
}
```

**After**:
```json
{
  "id": "core-fetch-or-create-issue",
  "name": "Fetch or Create Issue",
  "description": "Fetch existing issue or create new one. Reads referenced docs and existing commits for context.",
  "command": "/fractary-work:issue-fetch",
  "arguments": {
    "work_id": "{work_id}",
    "read_referenced_docs": true,
    "read_existing_commits": true
  }
}
```

### Example 2: skill-based to command-based

**Before** (default.json - architect phase):
```json
{
  "id": "generate-spec",
  "name": "Generate Specification",
  "description": "Create technical specification from issue context",
  "skill": "fractary-spec:spec-generator",
  "config": {
    "use_issue_context": true,
    "auto_detect_template": true
  }
}
```

**After**:
```json
{
  "id": "generate-spec",
  "name": "Generate Specification",
  "description": "Create technical specification from issue context",
  "command": "/fractary-spec:create",
  "arguments": {
    "work_id": "{work_id}",
    "use_issue_context": true,
    "auto_detect_template": true
  }
}
```

### Example 3: skill with action to specific command

**Before** (core.json - evaluate phase):
```json
{
  "id": "core-create-pr",
  "name": "Create Pull Request",
  "description": "Create PR for the implementation (skips if PR already exists). Links to issue for auto-close on merge.",
  "skill": "fractary-repo:pr-manager",
  "config": {
    "action": "create",
    "auto_link_issue": true,
    "skip_if_exists": true
  },
  "arguments": {
    "work_id": "{work_id}",
    "issue_data": "{issue_data}"
  }
}
```

**After**:
```json
{
  "id": "core-create-pr",
  "name": "Create Pull Request",
  "description": "Create PR for the implementation (skips if PR already exists). Links to issue for auto-close on merge.",
  "command": "/fractary-repo:pr-create",
  "arguments": {
    "work_id": "{work_id}",
    "issue_data": "{issue_data}",
    "auto_link_issue": true,
    "skip_if_exists": true
  }
}
```

## Command Reference

The following commands are referenced in this migration. Verify each exists:

### Existing Commands (verified)

| Command | Location | Status |
|---------|----------|--------|
| `/fractary-work:issue-fetch` | plugins/work/commands/issue-fetch.md | Verify exists |
| `/fractary-repo:branch-create` | plugins/repo/commands/branch-create.md | Verify exists |
| `/fractary-repo:commit-and-push` | plugins/repo/commands/commit-and-push.md | Verify exists |
| `/fractary-repo:pr-create` | plugins/repo/commands/pr-create.md | Verify exists |
| `/fractary-repo:pr-review` | plugins/repo/commands/pr-review.md | Verify exists |
| `/fractary-repo:pr-merge` | plugins/repo/commands/pr-merge.md | Verify exists |
| `/fractary-spec:create` | plugins/spec/commands/create.md | Verify exists |
| `/fractary-spec:refine` | plugins/spec/commands/refine.md | Verify exists |

### Commands to Create

| Command | Location | Creates |
|---------|----------|---------|
| `/fractary-faber:build` | plugins/faber/commands/build.md | This task |
| `/fractary-faber:review` | plugins/faber/commands/review.md | This task |

## Validation Checklist

Before implementation, verify:

- [ ] All referenced commands exist (see Command Reference above)
- [ ] Existing commands accept the arguments specified
- [ ] Command argument names match what commands expect

After implementation:

- [ ] JSON syntax is valid in both workflow files
- [ ] All step `id` fields are unique within their phase
- [ ] All `command` values start with `/`
- [ ] All placeholder references use `{placeholder}` format
- [ ] New commands follow established patterns

## Testing Strategy

### JSON Validation

```bash
# Validate JSON syntax
jq . plugins/faber/config/workflows/core.json
jq . plugins/faber/config/workflows/default.json
```

### Command Existence Check

```bash
# Verify all referenced commands exist
for cmd in issue-fetch branch-create commit-and-push pr-create pr-review pr-merge; do
  ls plugins/repo/commands/$cmd.md 2>/dev/null || echo "Missing: $cmd"
done

for cmd in create refine; do
  ls plugins/spec/commands/$cmd.md 2>/dev/null || echo "Missing: $cmd"
done

for cmd in build review; do
  ls plugins/faber/commands/$cmd.md 2>/dev/null || echo "Missing: $cmd"
done
```

### Integration Test

Execute a simple FABER workflow to verify command-based execution works:

```bash
/fractary-faber:run 332 --autonomy dry-run
```

## Acceptance Criteria

- [ ] **AC1**: New `/fractary-faber:build` command created at `plugins/faber/commands/build.md`
- [ ] **AC2**: New `/fractary-faber:review` command created at `plugins/faber/commands/review.md`
- [ ] **AC3**: `plugins/faber/config/workflows/core.json` updated with command-based steps (8 steps)
- [ ] **AC4**: `plugins/faber/config/workflows/default.json` updated with command-based steps (3 steps)
- [ ] **AC5**: JSON syntax valid for all modified files
- [ ] **AC6**: All referenced commands exist and are accessible

## Dependencies

- Issue #328 architectural changes merged (Task-based execution support in faber-manager)
- All referenced commands must exist before workflow files reference them

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Missing referenced command | Workflow fails at step | Verify command existence before modifying workflows |
| Command argument mismatch | Step fails with bad args | Review command documentation for expected args |
| JSON syntax error | Workflow won't load | Validate with jq before committing |

## Implementation Order

1. **First**: Verify all referenced commands exist
2. **Second**: Create `/fractary-faber:build` command
3. **Third**: Create `/fractary-faber:review` command
4. **Fourth**: Update `default.json` (smaller, lower risk)
5. **Fifth**: Update `core.json` (larger, depends on step 2-3)
6. **Sixth**: Validate JSON and test

## Related Specifications

- `WORK-00328-deterministic-step-execution.md` - Parent architecture specification

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-12-09 | 1.0 | Claude | Initial specification |
