# SPEC-00219: FABER Planner Workflow Overview Enhancement

**Issue:** #349
**Status:** Draft
**Created:** 2025-12-10
**Author:** FABER Workflow

## Summary

Enhance the faber-planner to provide a more detailed workflow overview in the Plan Summary output and improve the user prompt flow for reviewing and executing plans.

## Problem Statement

Currently, the faber-planner output shows a minimal summary:

```
Plan Summary:
- Plan ID: fractary-claude-plugins-faber-workflow-issues-20251210T152812
- Items: 1 issue (fix/348-faber-workflow-issues branch)
- Phases: Frame -> Architect -> Build -> Evaluate -> Release
- Autonomy Level: guarded
```

This leaves the user without visibility into:
1. What steps will be executed in each phase
2. The workflow inheritance chain being used
3. Easy access to plan details without leaving Claude

Additionally, the AskUserQuestion prompt that was previously used has been lost. Users want:
1. Option to execute immediately
2. Option to review plan details (showing plan contents inline)
3. Option to do something else (blank)

## Requirements

### 1. Enhanced Workflow Overview

**Current:** Single line showing phase names
**Desired:** Expandable view showing phases with their steps

**New Output Format:**

```
Workflow: fractary-faber:default (extends fractary-faber:core)
Autonomy: guarded

Phases & Steps:
  Frame
    - Fetch or Create Issue (core)
    - Switch or Create Branch (core)
  Architect
    - Generate Specification
    - Refine Specification
  Build
    - Implement Solution
    - Commit and Push Changes (core)
  Evaluate
    - Review Issue Implementation (core)
    - Commit and Push Fixes (core)
    - Create Pull Request (core)
    - Review PR CI Checks (core)
  Release
    - Merge Pull Request (core)

Items (1):
  1. #349 faber planner should give overview of workflow... -> feat/349-faber-planner-workflow-overview [new]
```

Key elements:
- Show inheritance chain in workflow line
- List each phase with its steps as bullet points
- Mark steps from parent workflows (e.g., "core")
- Keep the items section as-is

### 2. Enhanced AskUserQuestion Prompt

**Options to present:**

| Option | Label | Description | Action |
|--------|-------|-------------|--------|
| 1 | "Execute now" | Run the workflow immediately | Return `execute: true` |
| 2 | "Review plan details" | Show full plan JSON inline | Display plan contents, then re-prompt |
| 3 | "Exit" | Do nothing | Return `execute: false` |

**Flow for Option 2 (Review):**

When user selects "Review plan details":
1. Output the execute command for reference
2. Read and display the plan JSON file contents (formatted)
3. Re-prompt with the same AskUserQuestion (without option 2 this time)

### 3. Implementation Details

#### 3.1 Workflow Overview Generation

Add a new section in Step 8 of faber-planner.md to generate the detailed workflow overview:

```python
def generate_workflow_overview(resolved_workflow):
    lines = []

    # Header with inheritance
    if len(resolved_workflow.inheritance_chain) > 1:
        extends = " (extends " + resolved_workflow.inheritance_chain[1] + ")"
    else:
        extends = ""
    lines.append(f"Workflow: {resolved_workflow.id}{extends}")
    lines.append(f"Autonomy: {plan.autonomy}")
    lines.append("")
    lines.append("Phases & Steps:")

    # Each phase
    for phase_name, phase_data in resolved_workflow.phases.items():
        lines.append(f"  {phase_name.capitalize()}")
        for step in phase_data.steps:
            source_marker = f" ({step.source.split(':')[1]})" if step.source != resolved_workflow.id else ""
            lines.append(f"    - {step.name}{source_marker}")

    return "\n".join(lines)
```

#### 3.2 AskUserQuestion Modification

Update the AskUserQuestion call in Step 8:

```
AskUserQuestion(
  questions=[{
    "question": "What would you like to do?",
    "header": "FABER Plan Ready",
    "options": [
      {"label": "Execute now", "description": "Run: /fractary-faber:execute {plan_id}"},
      {"label": "Review plan details", "description": "Show full plan contents before deciding"},
      {"label": "Exit", "description": "Do nothing, plan is saved for later"}
    ],
    "multiSelect": false
  }]
)
```

#### 3.3 Review Plan Flow

When "Review plan details" is selected:

```markdown
**Execute Command:**
/fractary-faber:execute {plan_id}

**Plan Location:**
logs/fractary/plugins/faber/plans/{plan_id}.json

**Plan Contents:**
```json
{full plan JSON contents}
```

[Re-prompt with options 1 and 3 only]
```

## Files to Modify

| File | Changes |
|------|---------|
| `plugins/faber/agents/faber-planner.md` | Update Step 8 output format, AskUserQuestion, add review flow |

## Acceptance Criteria

1. [ ] Plan summary shows workflow inheritance chain
2. [ ] Plan summary lists all phases with their steps as bullets
3. [ ] Steps from parent workflows are marked with source (e.g., "core")
4. [ ] AskUserQuestion presents 3 options: Execute, Review, Exit
5. [ ] Selecting "Review" displays plan JSON inline
6. [ ] After review, user is re-prompted to execute or exit
7. [ ] Execute option returns `execute: true` for downstream handling

## Out of Scope

- Modifying the plan JSON structure
- Changes to faber-executor
- Changes to faber-manager
- Multi-select options in the prompt

## Testing

1. Run `/fractary-faber:plan --work-id 349` and verify:
   - Workflow overview shows phases and steps
   - Inheritance chain is displayed
   - AskUserQuestion appears with 3 options

2. Select "Review plan details" and verify:
   - Execute command is shown
   - Full plan JSON is displayed
   - Re-prompt appears without review option

3. Select "Execute now" and verify:
   - Response includes `execute: true`
