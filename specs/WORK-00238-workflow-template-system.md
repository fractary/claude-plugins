# WORK-00238: Workflow Inheritance System

## Summary

This specification introduces a **workflow inheritance system** for FABER that allows workflows to extend other workflows. A workflow can define pre-steps and post-steps for each phase, with child workflows inheriting and nesting within their parent's structure. This creates a clean, composable system where common patterns are defined once and extended as needed.

## Problem Statement

### Current Issues

1. **Default Workflow Maintenance Problem**: Currently, the default workflow JSON is copied into each project's FABER config directory during init. If the default workflow is updated, existing projects don't receive the changes.

2. **Automatic Primitives Limitation**: v2.1 introduced "automatic primitives" (hardcoded steps like issue fetch, branch creation, PR creation). While this simplifies common workflows, it removes flexibility for workflows that don't want these steps.

3. **Code Duplication**: Similar workflows (e.g., multiple ETL workflows) must each define the same common steps, leading to maintenance overhead.

4. **Hook Complexity**: The current hooks system (`pre_frame`, `post_frame`, etc.) is redundant with the ability to simply add steps before/after other steps.

### Proposed Solution

Create a **workflow inheritance system** where:
- Any workflow can extend another workflow via an `extends` field
- Parent workflows define pre-steps and post-steps for each phase
- Child workflow steps are injected between parent pre/post steps
- Multiple levels of inheritance create nested execution (grandparent → parent → child → parent → grandparent)
- The default workflow remains in the FABER plugin code (not copied to projects)
- Hooks are deprecated in favor of pre/post steps

## Key Design Decision: Unified Model

**Templates and workflows are the same thing.** There is no separate "template" concept. All workflows can:
- Define steps for each phase
- Define pre_steps and post_steps for each phase
- Extend another workflow via `extends`

This unification simplifies the mental model and implementation.

## Architecture

### Workflow Inheritance

A workflow can extend another workflow. The child's steps are injected between the parent's pre_steps and post_steps:

```
Parent Workflow Phase Execution:
┌──────────────────────────────────────────────────────────────┐
│  Phase: {name}                                               │
├──────────────────────────────────────────────────────────────┤
│  1. Parent pre_steps                                         │
│     - Common setup operations                                │
│                                                              │
│  2. [CHILD WORKFLOW INJECTED HERE]                           │
│     - Child pre_steps (if any)                               │
│     - Child steps                                            │
│     - Child post_steps (if any)                              │
│                                                              │
│  3. Parent post_steps                                        │
│     - Common cleanup/validation                              │
└──────────────────────────────────────────────────────────────┘
```

### Nested Inheritance

Workflows can form inheritance chains:

```
my-workflow extends etl-common extends default
```

Execution order for each phase (using Build as example):

```
Build Phase Execution:
1. default.build.pre_steps      ← Outermost parent first
2.   etl-common.build.pre_steps   ← Middle parent
3.     my-workflow.build.steps      ← Child (innermost)
4.   etl-common.build.post_steps  ← Middle parent
5. default.build.post_steps     ← Outermost parent last
```

This nesting ensures that:
- The base workflow's setup runs first
- The base workflow's cleanup runs last
- Each inheritance level wraps the next

### File Locations and Namespacing

Workflows are namespaced by their source:

| Namespace | Location | Description |
|-----------|----------|-------------|
| `fractary-faber:` | `plugins/faber/workflows/` | Core FABER workflows |
| `fractary-faber-cloud:` | `plugins/faber-cloud/workflows/` | Cloud infrastructure workflows |
| `project:` | `.fractary/plugins/faber/workflows/` | Project-specific workflows |

**Examples:**
- `fractary-faber:default` - The core default workflow
- `fractary-faber-cloud:infrastructure` - Cloud deployment workflow
- `project:my-custom-workflow` - Project-specific workflow

**Resolution Rules:**
1. If namespace provided, look in that location
2. If no namespace, assume `project:` (project-local workflows)
3. Error if workflow not found

This means unnamespaced workflow IDs like `"my-workflow"` resolve to `project:my-workflow`. To reference a core FABER workflow, you must use the full namespace: `"fractary-faber:default"`.

### Workflow Structure

```json
{
  "$schema": "../workflow.schema.json",
  "id": "my-workflow",
  "description": "Custom workflow extending default",
  "extends": "fractary-faber:default",
  "skip_steps": ["merge-pr"],
  "phases": {
    "frame": {
      "enabled": true,
      "pre_steps": [],
      "steps": [],
      "post_steps": []
    },
    "architect": {
      "enabled": true,
      "steps": [
        {
          "id": "generate-spec",
          "skill": "fractary-spec:spec-generator"
        }
      ]
    },
    "build": {
      "enabled": true,
      "steps": [
        {
          "id": "implement",
          "prompt": "Implement based on specification"
        }
      ]
    },
    "evaluate": {
      "enabled": true,
      "max_retries": 3,
      "steps": []
    },
    "release": {
      "enabled": true,
      "require_approval": true,
      "steps": []
    }
  },
  "autonomy": {
    "level": "guarded",
    "require_approval_for": ["release"]
  }
}
```

## Schema Design

### Updated Workflow Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "FABER Workflow Schema",
  "type": "object",
  "required": ["id", "phases", "autonomy"],
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9-]*$",
      "description": "Workflow identifier (lowercase, hyphens allowed)"
    },
    "description": {
      "type": "string",
      "description": "Human-readable workflow description"
    },
    "extends": {
      "type": "string",
      "description": "Parent workflow to extend (e.g., 'fractary-faber:default')"
    },
    "skip_steps": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Step IDs from parent workflows to skip"
    },
    "phases": {
      "$ref": "#/definitions/phases"
    },
    "autonomy": {
      "$ref": "#/definitions/autonomy"
    }
  },
  "definitions": {
    "phases": {
      "type": "object",
      "properties": {
        "frame": { "$ref": "#/definitions/phase" },
        "architect": { "$ref": "#/definitions/phase" },
        "build": { "$ref": "#/definitions/phase" },
        "evaluate": { "$ref": "#/definitions/phase_with_retries" },
        "release": { "$ref": "#/definitions/phase_with_approval" }
      }
    },
    "phase": {
      "type": "object",
      "properties": {
        "enabled": {
          "type": "boolean",
          "description": "Whether this phase is enabled"
        },
        "description": {
          "type": "string",
          "description": "Phase description"
        },
        "pre_steps": {
          "type": "array",
          "items": { "$ref": "#/definitions/step" },
          "description": "Steps to execute BEFORE child workflow steps"
        },
        "steps": {
          "type": "array",
          "items": { "$ref": "#/definitions/step" },
          "description": "Main phase steps"
        },
        "post_steps": {
          "type": "array",
          "items": { "$ref": "#/definitions/step" },
          "description": "Steps to execute AFTER child workflow steps"
        },
        "validation": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Validation checks for phase completion"
        }
      }
    },
    "step": {
      "type": "object",
      "required": ["id"],
      "properties": {
        "id": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9-]*$",
          "description": "Unique step identifier (must be unique across entire merged workflow)"
        },
        "name": {
          "type": "string",
          "description": "Human-readable step name"
        },
        "description": {
          "type": "string",
          "description": "Step documentation"
        },
        "skill": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9-]*:[a-z][a-z0-9-]*$",
          "description": "Skill reference (plugin:skill-name)"
        },
        "prompt": {
          "type": "string",
          "description": "Execution instruction for Claude"
        },
        "config": {
          "type": "object",
          "description": "Step-specific configuration"
        },
        "result_handling": {
          "$ref": "#/definitions/result_handling"
        }
      }
    },
    "result_handling": {
      "type": "object",
      "properties": {
        "on_success": {
          "type": "string",
          "enum": ["continue", "prompt"],
          "default": "continue"
        },
        "on_warning": {
          "type": "string",
          "enum": ["continue", "prompt", "stop"],
          "default": "continue"
        },
        "on_failure": {
          "const": "stop",
          "default": "stop",
          "description": "IMMUTABLE: Failure always stops"
        }
      }
    }
  }
}
```

### Removed: Hooks

The `hooks` section is **removed** from the schema. Use `pre_steps` and `post_steps` instead:

**Before (hooks - deprecated):**
```json
{
  "hooks": {
    "pre_frame": [{ "type": "script", "path": "..." }],
    "post_frame": [{ "type": "script", "path": "..." }]
  }
}
```

**After (pre/post steps):**
```json
{
  "phases": {
    "frame": {
      "pre_steps": [{ "id": "my-setup", "skill": "..." }],
      "post_steps": [{ "id": "my-cleanup", "skill": "..." }]
    }
  }
}
```

## Default Workflow Design

The default workflow (`fractary-faber:default`) provides common primitives as pre/post steps:

### Frame Phase

**Pre-Steps:**
1. **fetch-or-create-issue**
   - If `work_id` provided: fetch issue, read referenced docs, read existing commits
   - If no `work_id`: create issue

2. **switch-or-create-branch**
   - If issue has branch: checkout and fetch
   - If new issue: create branch with work_id
   - Update git status cache

**Steps:** (none - let child workflows define)

**Post-Steps:** (none)

### Architect Phase

**Pre-Steps:** (none)

**Steps:**
1. **generate-spec** - Create specification from issue

**Post-Steps:** (none)

### Build Phase

**Pre-Steps:** (none)

**Steps:**
1. **implement** - Implement from specification

**Post-Steps:**
1. **commit-and-push** - Ensure all changes committed and pushed

### Evaluate Phase

**Pre-Steps:**
1. **issue-review** - Verify implementation completeness

**Steps:** (none - let child workflows define tests)

**Post-Steps:**
1. **commit-and-push** - Ensure fixes committed
2. **create-pr** - Create pull request
3. **review-pr-checks** - Wait for and review CI status

### Release Phase

**Pre-Steps:** (none)

**Steps:** (none)

**Post-Steps:**
1. **merge-pr** - Merge PR and delete branch

## Default Workflow JSON

```json
{
  "$schema": "../workflow.schema.json",
  "id": "default",
  "description": "Default FABER workflow providing common primitives for software development",
  "phases": {
    "frame": {
      "enabled": true,
      "description": "Fetch work item, classify, and setup environment",
      "pre_steps": [
        {
          "id": "fetch-or-create-issue",
          "name": "Fetch or Create Issue",
          "description": "Fetch existing issue or create new one. Reads referenced docs and existing commits.",
          "prompt": "If work_id provided: fetch issue with fractary-work:issue-fetcher, read all referenced documents and existing commits for context. If no work_id: create issue with fractary-work:issue-creator using the target description."
        },
        {
          "id": "switch-or-create-branch",
          "name": "Switch or Create Branch",
          "description": "Checkout existing branch or create new one linked to issue",
          "prompt": "If issue has associated branch: checkout and fetch it. If new issue or no branch: create branch with fractary-repo:branch-create --work-id. Update git status cache with branch and work ID."
        }
      ],
      "steps": [],
      "post_steps": []
    },
    "architect": {
      "enabled": true,
      "description": "Generate technical specification",
      "pre_steps": [],
      "steps": [
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
      ],
      "post_steps": []
    },
    "build": {
      "enabled": true,
      "description": "Implement solution and commit",
      "pre_steps": [],
      "steps": [
        {
          "id": "implement",
          "name": "Implement Solution",
          "description": "Implement based on specification following project patterns",
          "prompt": "Analyze the specification and implement the solution. Follow project code standards, patterns, and best practices. Create tests as appropriate."
        }
      ],
      "post_steps": [
        {
          "id": "commit-and-push-build",
          "name": "Commit and Push Changes",
          "description": "Ensure all build changes are committed and pushed",
          "skill": "fractary-repo:commit-creator",
          "config": {
            "push_after_commit": true,
            "conventional_commits": true,
            "link_to_issue": true
          }
        }
      ]
    },
    "evaluate": {
      "enabled": true,
      "description": "Test and review implementation",
      "max_retries": 3,
      "pre_steps": [
        {
          "id": "issue-review",
          "name": "Review Issue Implementation",
          "description": "Verify implementation completeness against issue requirements",
          "skill": "fractary-faber:issue-reviewer"
        }
      ],
      "steps": [],
      "post_steps": [
        {
          "id": "commit-and-push-evaluate",
          "name": "Commit and Push Fixes",
          "description": "Ensure evaluation fixes are committed",
          "skill": "fractary-repo:commit-creator",
          "config": {
            "push_after_commit": true
          }
        },
        {
          "id": "create-pr",
          "name": "Create Pull Request",
          "description": "Create PR for the implementation (skips if PR already exists)",
          "skill": "fractary-repo:pr-manager",
          "config": {
            "action": "create",
            "auto_link_issue": true,
            "skip_if_exists": true
          }
        },
        {
          "id": "review-pr-checks",
          "name": "Review PR CI Checks",
          "description": "Wait for and review CI/CD pipeline results",
          "skill": "fractary-repo:pr-manager",
          "config": {
            "action": "review",
            "wait_for_ci": true
          }
        }
      ]
    },
    "release": {
      "enabled": true,
      "description": "Merge PR and complete workflow",
      "require_approval": true,
      "pre_steps": [],
      "steps": [],
      "post_steps": [
        {
          "id": "merge-pr",
          "name": "Merge Pull Request",
          "description": "Merge the PR and delete branch",
          "skill": "fractary-repo:pr-manager",
          "config": {
            "action": "merge",
            "delete_branch": true
          }
        }
      ]
    }
  },
  "autonomy": {
    "level": "guarded",
    "description": "Pauses before release for approval - recommended for production",
    "require_approval_for": ["release"]
  }
}
```

## Skip Steps Mechanism

Workflows can skip specific steps from parent workflows:

```json
{
  "id": "no-auto-pr",
  "extends": "fractary-faber:default",
  "skip_steps": ["create-pr", "review-pr-checks", "merge-pr"],
  "phases": { ... }
}
```

**Behavior:**
- Steps listed in `skip_steps` are removed from the merged workflow
- Step IDs can be from any ancestor in the inheritance chain
- Validation ensures skipped step IDs actually exist in ancestors

## Workflow Resolution Process

When loading a workflow:

### Step 1: Parse Inheritance Chain

```python
def resolve_inheritance_chain(workflow_id):
    chain = []
    current = load_workflow(workflow_id)

    while current:
        chain.append(current)
        if current.extends:
            current = load_workflow(current.extends)
        else:
            current = None

    return chain  # [child, parent, grandparent, ...]
```

### Step 2: Merge Into Single Workflow

```python
def merge_workflow(chain):
    merged = empty_workflow()

    for phase in PHASES:
        # Collect all steps in execution order
        all_pre_steps = []
        all_steps = []
        all_post_steps = []

        # Process from root ancestor to child
        for workflow in reversed(chain):
            phase_def = workflow.phases.get(phase, {})
            all_pre_steps.extend(phase_def.get('pre_steps', []))

        # Child's main steps go in the middle
        child = chain[0]
        all_steps = child.phases.get(phase, {}).get('steps', [])

        # Post-steps in reverse order (child first, then up to root)
        for workflow in chain:
            phase_def = workflow.phases.get(phase, {})
            all_post_steps.extend(phase_def.get('post_steps', []))

        merged.phases[phase].steps = all_pre_steps + all_steps + all_post_steps

    # Apply skip_steps
    skip = chain[0].get('skip_steps', [])
    for phase in PHASES:
        merged.phases[phase].steps = [
            s for s in merged.phases[phase].steps
            if s['id'] not in skip
        ]

    return merged
```

### Step 3: Validate Merged Workflow

```python
def validate_merged_workflow(merged):
    all_step_ids = []

    for phase in PHASES:
        for step in merged.phases[phase].steps:
            if step['id'] in all_step_ids:
                raise ValidationError(f"Duplicate step ID: {step['id']}")
            all_step_ids.append(step['id'])

    return True
```

## Self-Contained Steps

Steps must be self-contained and handle their own conditional logic internally:

**Example: create-pr step**
- Checks if PR already exists before creating
- Returns success with "PR already exists" message if so
- No external conditional logic needed

**Example: commit-and-push step**
- Checks if there are uncommitted changes
- Returns success with "Nothing to commit" if clean
- No need for `only_if_commits` conditional

This approach:
- Keeps workflow definitions simple
- Makes steps reusable across workflows
- Centralizes logic in skills where it belongs

## Implementation Plan

### Phase 1: Schema Updates

1. **Update Workflow Schema** (`plugins/faber/config/workflow.schema.json`)
   - Add `extends` field
   - Add `skip_steps` field
   - Add `pre_steps` and `post_steps` to phase definition
   - Remove `hooks` section (deprecated)

2. **Update Config Schema** (`plugins/faber/config/config.schema.json`)
   - Add workflow namespace resolution paths
   - Remove hooks-related configuration

### Phase 2: Workflow Loading

3. **Create Workflow Resolver** (in `faber-config` skill)
   - Parse inheritance chain
   - Merge workflows into single definition
   - Validate step ID uniqueness
   - Apply skip_steps

4. **Add Namespace Resolution**
   - Resolve `fractary-faber:*` to plugin directory
   - Resolve `project:*` to project directory
   - Handle unnamespaced workflow IDs

### Phase 3: Manager Integration

5. **Update faber-manager Agent** (`plugins/faber/agents/faber-manager.md`)
   - Remove hardcoded automatic primitives
   - Use merged workflow from resolver
   - Execute steps in order (pre → main → post already merged)

6. **Update faber-director Skill** (`plugins/faber/skills/faber-director/SKILL.md`)
   - Call workflow resolver before invoking manager
   - Pass fully merged workflow to manager

### Phase 4: Default Workflow

7. **Create Default Workflow** (`plugins/faber/workflows/default.json`)
   - Implement all primitives as pre/post steps
   - Make steps self-contained (skip-if-exists logic)

8. **Update Skills for Self-Containment**
   - `pr-manager`: Add `skip_if_exists` logic
   - `commit-creator`: Handle "nothing to commit" gracefully
   - `issue-reviewer`: Handle missing context gracefully

### Phase 5: Migration

9. **Update faber:init Command**
   - Don't copy default workflow to project
   - Create minimal config.json pointing to defaults
   - Provide option to create custom workflow scaffold

10. **Create Migration Guide**
    - Document hooks → pre/post steps migration
    - Provide examples for common patterns
    - Create `fractary-faber:migrate` command

### Phase 6: Documentation

11. **Update Documentation**
    - Update CLAUDE.md with inheritance model
    - Create workflow authoring guide
    - Document namespacing conventions
    - Remove hooks documentation

## Backward Compatibility

### Workflows Without `extends`

Workflows without an `extends` field work standalone:
- All steps execute as defined
- No parent pre/post steps added
- Suitable for completely custom workflows

### Automatic Primitives Deprecation

Current automatic primitives will be:
1. **v2.2**: Deprecated with warning, still functional
2. **v3.0**: Removed entirely

Migration path:
- Add `"extends": "fractary-faber:default"` to get equivalent behavior
- Or manually add needed steps to workflow

### Hooks Deprecation

Existing hooks will be:
1. **v2.2**: Deprecated with warning, converted to steps internally
2. **v3.0**: Removed from schema

Migration:
- Convert `pre_<phase>` hooks to `phases.<phase>.pre_steps`
- Convert `post_<phase>` hooks to `phases.<phase>.post_steps`

## Benefits

1. **Centralized Defaults**: Default workflow in plugin, all projects benefit from updates
2. **Clean Inheritance**: Single `extends` field, intuitive nesting
3. **Flexibility**: Skip specific steps, create custom workflows
4. **Simplicity**: No separate template concept, unified model
5. **No Hooks Complexity**: Pre/post steps are clearer and more powerful
6. **Self-Contained Steps**: Logic where it belongs, simpler workflows
7. **Namespacing**: Clear ownership and conflict resolution

## Success Criteria

- [ ] Workflow schema updated with `extends`, `skip_steps`, `pre_steps`, `post_steps`
- [ ] Hooks removed from schema
- [ ] Workflow resolver implements inheritance chain parsing
- [ ] Workflow resolver implements merge logic
- [ ] Step ID uniqueness validated across merged workflow
- [ ] Namespace resolution implemented
- [ ] Default workflow created with all primitives
- [ ] Skills updated to be self-contained
- [ ] faber-manager uses merged workflow
- [ ] Backward compatibility maintained
- [ ] Documentation updated
- [ ] Migration guide created

## Related Issues

- #238: Create default workflow and workflow template concepts (this issue)
- #189: Automatic workflow primitives (to be replaced by default workflow)

## References

- Current workflow schema: `plugins/faber/config/workflow.schema.json`
- Current config schema: `plugins/faber/config/config.schema.json`
- faber-manager agent: `plugins/faber/agents/faber-manager.md`
- Automatic primitives (to be replaced): `<AUTOMATIC_PRIMITIVES>` section in faber-manager.md
