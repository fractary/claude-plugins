---
title: Add fractary-spec:refine skill step after spec:create step in default faber workflow
work_id: "310"
issue_url: https://github.com/fractary/claude-plugins/issues/310
created: 2025-12-09T14:24:00Z
template: feature
source: conversation+issue
status: draft
---

# Add Spec Refine Step to Default FABER Workflow

## Overview

Add a `refine-spec` step to the FABER default workflow that invokes the `fractary-spec:spec-refiner` skill immediately after the `generate-spec` step in the Architect phase. This enables iterative refinement of specifications through critical review and user Q&A before implementation begins.

## Context

### Current State
- The default FABER workflow (`plugins/faber/config/workflows/default.json`) extends `fractary-faber:core`
- The Architect phase has one step: `generate-spec` which invokes `fractary-spec:spec-generator`
- The `fractary-spec:spec-refiner` skill already exists and is fully implemented
- No spec refinement occurs automatically in the workflow

### Problem
Generated specifications may have gaps, ambiguities, or require clarification before implementation. Without automatic refinement, teams must manually invoke `/fractary-spec:refine` or proceed with potentially incomplete specs.

### Solution
Add a `refine-spec` step after `generate-spec` in the Architect phase of the default workflow. This step will:
1. Invoke `fractary-spec:spec-refiner` skill
2. Generate questions/suggestions based on the just-created spec
3. Present questions to user for answers
4. Apply refinements based on feedback
5. Post Q&A summary to GitHub issue

## Requirements

### Functional Requirements

1. **Add refine-spec step to default.json workflow**
   - Step ID: `refine-spec`
   - Step Name: `Refine Specification`
   - Skill: `fractary-spec:spec-refiner`
   - Position: After `generate-spec` step in Architect phase
   - Config: Use work_id from workflow context

2. **Step Configuration**
   - Must pass `work_id` to the skill via arguments
   - Should enable iterative refinement if meaningful questions remain
   - Default behavior: proceed to build even if user doesn't answer all questions (best-effort)

3. **Workflow Inheritance**
   - The step should be in the `default.json` workflow (not `core.json`)
   - Core workflow remains generic; spec refinement is software-development specific

### Non-Functional Requirements

1. **Backward Compatibility**
   - Existing workflows extending `default` should still work
   - Projects can skip this step via `skip_steps` if desired

2. **Graceful Degradation**
   - If spec was skipped in generate-spec step (already exists), refine should still work
   - If no spec found, refine should return appropriate status

## Implementation

### File Changes

**File:** `plugins/faber/config/workflows/default.json`

Add the following step after `generate-spec` in the Architect phase:

```json
{
  "id": "refine-spec",
  "name": "Refine Specification",
  "description": "Critically review spec and gather clarifications from user",
  "skill": "fractary-spec:spec-refiner",
  "config": {
    "allow_iterative_rounds": true,
    "best_effort_on_no_answers": true
  },
  "arguments": {
    "work_id": "{work_id}"
  }
}
```

### Expected Workflow After Change

**Architect Phase Steps (in order):**
1. `generate-spec` - Create technical specification from issue context
2. `refine-spec` - Critically review spec and gather clarifications

### Verification

The change is complete when:
- [ ] `default.json` contains `refine-spec` step after `generate-spec`
- [ ] Step uses correct skill name: `fractary-spec:spec-refiner`
- [ ] Step passes `work_id` via arguments
- [ ] Workflow validation passes (schema validation)
- [ ] Running `/fractary-faber:run` on a test issue invokes both generate and refine steps

## Acceptance Criteria

1. When running a FABER workflow with work_id, the Architect phase executes:
   - First: `generate-spec` step
   - Then: `refine-spec` step
2. The `refine-spec` step presents questions to the user (if any are generated)
3. The workflow continues to Build phase after refinement completes (or is skipped)
4. Users can skip the refine step via `skip_steps: ["refine-spec"]` in their custom workflow

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Refine step blocks workflow on user input | Low | Medium | Skill uses best-effort for unanswered questions |
| Spec not found causes step failure | Low | Low | Refiner handles missing spec gracefully |
| Workflow changes break existing configs | Very Low | Low | Step is additive; skip_steps available |

## Related Issues

- Issue #310: This specification
- spec-refiner skill: `plugins/spec/skills/spec-refiner/SKILL.md`
- spec-generator skill: `plugins/spec/skills/spec-generator/SKILL.md`

---

## Changelog

- 2025-12-09: Initial specification created
