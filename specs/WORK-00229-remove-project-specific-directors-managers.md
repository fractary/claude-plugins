---
spec_id: WORK-00229-remove-project-specific-directors-managers
work_id: 229
issue_url: https://github.com/fractary/claude-plugins/issues/229
title: Update faber-agent standards to not have project specific manager or director
type: refactor
status: draft
created: 2025-12-07
author: claude
validated: false
source: conversation+issue
refined: 2025-12-07
refinement_round: 1
---

# Refactor Specification: Remove Project-Specific Manager/Director Standards

**Issue**: [#229](https://github.com/fractary/claude-plugins/issues/229)
**Type**: Refactor / Standards Update
**Status**: Draft (Refined)
**Created**: 2025-12-07
**Refined**: 2025-12-07

## Summary

Update the faber-agent plugin to remove all recommendations, best practices, and templates that suggest projects should create their own project-specific director or manager components. Instead, all projects should rely on the core FABER director and manager (`faber-director` and `faber-manager`) which are already built into the system. Project-specific workflows should be defined via FABER workflow configuration files, not custom orchestration components.

## Background

### Historical Context

The faber-agent plugin was originally designed to help projects create good agents and skills, including project-specific directors and managers for orchestrating workflows. This made sense when each project needed custom orchestration logic.

### Recent Architecture Change

The Fractary ecosystem has been re-architected so that:

1. **All projects use the core FABER director and manager** - The `faber-director` and `faber-manager` in the core `faber` plugin can effectively manage ANY workflow
2. **Workflows are configuration-driven** - Project-specific behavior is defined in FABER workflow config files (`.fractary/plugins/faber/workflows/*.json`), not custom code
3. **No project-specific orchestration needed** - Projects should NOT have their own director or manager components

### Benefits of the New Approach

| Aspect | Old Approach (Project-Specific) | New Approach (Core FABER) |
|--------|--------------------------------|---------------------------|
| Consistency | Varies by project | Uniform across all projects |
| Maintenance | Each project maintains its own | Single source of truth |
| Updates | Manual per-project updates | Automatic via FABER plugin updates |
| Context | Duplicated orchestration logic | Shared, optimized orchestration |
| Complexity | High (custom code per project) | Low (config files only) |

## What Must Change

### 1. Remove Standards Recommending Project-Specific Directors/Managers

**Current State**: WORK-00194 and related documentation recommend:
- `/{project}-direct` command pattern with project-specific director skill
- Project-specific manager agent
- Director skill containing orchestration logic

**New State**: These patterns should be REMOVED and replaced with:
- Projects use `/faber run` or equivalent core FABER commands
- No project-specific director skill
- No project-specific manager agent
- Workflow logic lives in FABER workflow config files

### 2. Update Documentation

**Codebase Reality Check** (verified during refinement):
- ❌ `plugins/faber-agent/templates/` directory does NOT exist (no templates to delete)
- ✅ `plugins/faber-agent/docs/patterns/director-skill.md` EXISTS (448 lines) - pattern doc to DELETE
- ✅ `plugins/faber-agent/docs/BEST-PRACTICES.md` EXISTS (805 lines) - needs COMPLETE REWRITE
- ✅ `plugins/faber-agent/docs/patterns/manager-as-agent.md` EXISTS - needs review

Files requiring updates:

| File | Action | Notes |
|------|--------|-------|
| `plugins/faber-agent/docs/BEST-PRACTICES.md` | **COMPLETE REWRITE** | 805 lines entirely built around project-specific director/manager pattern. Must be rewritten from scratch around FABER workflow configs. |
| `plugins/faber-agent/docs/patterns/director-skill.md` | **DELETE** | 448 lines describing how to create project-specific directors. No longer valid pattern. |
| `plugins/faber-agent/docs/patterns/manager-as-agent.md` | Review & Update | May need updates to clarify it's about the CORE faber-manager, not project-specific managers |
| `plugins/faber-agent/docs/standards/manager-as-agent-pattern.md` | Review | Check if this duplicates or conflicts |
| `plugins/faber-agent/README.md` | Update | Ensure overview doesn't promote deprecated patterns |
| `plugins/faber-agent/agents/agent-creator.md` | Update | Remove any logic for creating project managers |
| `plugins/faber-agent/agents/skill-creator.md` | Update | Remove any logic for creating director skills |

### 3. Update Project Audit

The `project-auditor` agent should be updated to:

**Detect Anti-Patterns** (as ERROR severity - blocks workflows):
- Project-specific director skills (pattern: `{project}-director` skill files)
- Project-specific manager agents (pattern: `{project}-manager` agent files)
- Custom `/{project}-direct` commands that invoke project-specific orchestration
- Custom orchestration logic that should be FABER workflow config

**Propose Migration** (key deliverable - not tooling, but clear guidance):
When detecting a project-specific manager/director, the auditor should:

1. **Analyze the existing orchestration** - Read the manager/director to understand:
   - What steps/phases it orchestrates
   - What skills it invokes
   - What the workflow logic is

2. **Generate a FABER workflow config proposal** - Output:
   - Equivalent `.fractary/plugins/faber/workflows/{project}.json` configuration
   - Step-by-step mapping of old → new

3. **Provide clear deprecation guidance**:
   - Which files to delete (director skill, manager agent, direct command)
   - How to invoke the new workflow (`/faber run <id> --workflow {project}`)
   - Any command aliases to create for convenience

**Example Audit Output**:
```
❌ ERROR: Project-specific orchestration detected (anti-pattern)

Found:
  - skills/{project}-director/SKILL.md
  - agents/{project}-manager.md
  - commands/{project}-direct.md

This pattern is deprecated. Projects should use core FABER for orchestration.

Proposed Migration:
  1. Create workflow config: .fractary/plugins/faber/workflows/{project}.json
     [generated config shown]

  2. Delete deprecated files:
     - rm skills/{project}-director/
     - rm agents/{project}-manager.md
     - rm commands/{project}-direct.md

  3. Use new invocation:
     Instead of: /{project}-direct item-123 --action validate,build
     Use: /faber run 123 --workflow {project} --phases build

  4. Optional alias (if needed):
     Create /{project} command that routes to /faber run with workflow preset
```

### 4. Migration Approach (No Tooling Required)

**Decision (from refinement)**: Skip automated migration tooling. The audit's clear proposal output is sufficient.

**Rationale**:
- Few/no existing project-specific managers in the wild
- Manual migration is straightforward given clear audit output
- Avoids building tooling that may never be used

**What Projects Need**:
1. Run audit to detect anti-patterns
2. Follow the generated migration proposal
3. Create FABER workflow config manually (simple JSON)
4. Delete deprecated files
5. Update any documentation/README references

## Technical Design

### What Projects SHOULD Have (Skills Only)

Projects can and should still create:

1. **Skills for domain-specific operations**
   - These are invoked BY the core faber-manager
   - Defined in workflow config `steps[].skill` references
   - Example: `myproject:data-validator`, `myproject:report-generator`

2. **Commands for convenience**
   - These should route to core FABER, not custom orchestration
   - Example: `/myproject:deploy` could invoke `/faber run deploy-workflow`

3. **FABER workflow configs**
   - Define the sequence of steps for project-specific workflows
   - Reference project skills in step definitions

### What Projects SHOULD NOT Have

1. ❌ Director skills/agents (use `faber-director`)
2. ❌ Manager agents/skills (use `faber-manager`)
3. ❌ Custom orchestration logic (use workflow config)
4. ❌ Parallel manager spawning logic (FABER handles this)

### FABER Workflow Config as Replacement

Instead of a project-specific manager, define a workflow config:

**Old (project-specific manager agent)**:
```markdown
# my-project-manager.md

<WORKFLOW>
1. Validate input
   Skill: my-project:validator
2. Process data
   Skill: my-project:processor
3. Generate report
   Skill: my-project:reporter
</WORKFLOW>
```

**New (FABER workflow config)**:
```json
{
  "id": "my-project-workflow",
  "description": "My project processing workflow",
  "phases": {
    "frame": { "enabled": true, "steps": [] },
    "architect": { "enabled": false },
    "build": {
      "enabled": true,
      "steps": [
        {"id": "validate", "skill": "my-project:validator"},
        {"id": "process", "skill": "my-project:processor"},
        {"id": "report", "skill": "my-project:reporter"}
      ]
    },
    "evaluate": { "enabled": false },
    "release": { "enabled": false }
  }
}
```

**Invocation**:
```bash
# Instead of: /my-project-direct item123 --action validate,process,report
# Now use:
/faber run 123 --workflow my-project-workflow --phases build
```

## Implementation Plan

### Phase 1: Documentation Deletion & Rewrite

**Priority**: HIGH - This is the core deliverable

**Tasks**:
1. [ ] **DELETE** `plugins/faber-agent/docs/patterns/director-skill.md` (448 lines)
   - This entire file describes the deprecated pattern
   - No archive needed - git history preserves it

2. [ ] **REWRITE** `plugins/faber-agent/docs/BEST-PRACTICES.md` (805 lines → new content)
   - Current document is 100% built around project-specific director/manager
   - New document should cover:
     - What projects CAN create (skills, scripts, templates, commands routing to FABER)
     - What projects MUST NOT create (directors, managers, orchestration)
     - How to define custom workflows via FABER config
     - Plugin integrations (fractary-docs, fractary-specs, etc.) - these sections can be preserved
     - FABER workflow config examples

3. [ ] **Review & Update** `plugins/faber-agent/docs/patterns/manager-as-agent.md`
   - Clarify this refers to core `faber-manager`, not project managers
   - Or DELETE if redundant

4. [ ] **Update** `plugins/faber-agent/README.md`
   - Ensure overview reflects new architecture

### Phase 2: Agent/Creator Updates

**Tasks**:
1. [ ] Update `agents/agent-creator.md` - Remove any guidance for creating project managers
2. [ ] Update `agents/skill-creator.md` - Remove any guidance for creating director skills
3. [ ] Update `agents/project-auditor.md` - Will be enhanced in Phase 3

### Phase 3: Audit Enhancement

**Priority**: HIGH - Enforcement mechanism

**Tasks**:
1. [ ] Add detection rule for project-specific director skills
   - Pattern: `skills/{project}-director/SKILL.md` or similar naming
   - Severity: **ERROR** (blocks)

2. [ ] Add detection rule for project-specific manager agents
   - Pattern: `agents/{project}-manager.md` or similar naming
   - Severity: **ERROR** (blocks)

3. [ ] Add detection rule for `/{project}-direct` commands
   - Pattern: commands with `-direct` suffix invoking project-specific orchestration
   - Severity: **ERROR** (blocks)

4. [ ] Implement migration proposal generation:
   - Read detected manager/director
   - Analyze workflow steps
   - Generate equivalent FABER workflow config JSON
   - Output clear migration steps

5. [ ] Update `plugins/faber-agent/config/best-practices-rules.yaml` (if exists) or equivalent

### Phase 4: REMOVED - No Migration Tooling

**Decision**: Automated migration tooling is NOT needed.

The audit's proposal output provides sufficient guidance for manual migration, which is appropriate given the likely small number of affected projects.

## Files to Create/Modify

### Files to DELETE

| File | Reason |
|------|--------|
| `plugins/faber-agent/docs/patterns/director-skill.md` | 448 lines describing deprecated pattern. DELETE entirely. |

### Files to REWRITE (Major Changes)

| File | Change |
|------|--------|
| `plugins/faber-agent/docs/BEST-PRACTICES.md` | **COMPLETE REWRITE** - 805 lines built around deprecated pattern. New content focused on skills-only + FABER workflow configs. |

### Files to UPDATE (Minor Changes)

| File | Change |
|------|--------|
| `plugins/faber-agent/docs/patterns/manager-as-agent.md` | Clarify refers to core faber-manager, not project managers. Or DELETE if redundant. |
| `plugins/faber-agent/README.md` | Update overview to reflect new architecture |
| `plugins/faber-agent/agents/agent-creator.md` | Remove guidance for creating project managers |
| `plugins/faber-agent/agents/skill-creator.md` | Remove guidance for creating director skills |
| `plugins/faber-agent/agents/project-auditor.md` | Add anti-pattern detection (ERROR severity) + migration proposal generation |
| `plugins/faber-agent/skills/project-analyzer/SKILL.md` | Add director/manager detection logic |

### Files NOT Needed (Corrected from Original Spec)

| File | Status |
|------|--------|
| `plugins/faber-agent/templates/director-skill.md.template` | ❌ Does not exist (no action needed) |
| `plugins/faber-agent/templates/manager.md.template` | ❌ Does not exist (no action needed) |
| `plugins/faber-agent/skills/workflow-migrator/SKILL.md` | ❌ REMOVED - Migration tooling not needed |
| `plugins/faber-agent/docs/MIGRATION-TO-FABER-WORKFLOWS.md` | ❌ REMOVED - Audit proposal output is sufficient |

### Files to CREATE (Optional)

| File | Purpose |
|------|---------|
| `plugins/faber-agent/templates/faber-workflow-config.json.template` | (Optional) Template for custom FABER workflows if skill-creator needs it |

## Acceptance Criteria

### Documentation (Phase 1-2)

- [ ] `director-skill.md` pattern document DELETED from repository
- [ ] `BEST-PRACTICES.md` REWRITTEN with new content:
  - [ ] Clear statement that projects MUST NOT create directors/managers
  - [ ] Guidance on what projects CAN create (skills, scripts, commands routing to FABER)
  - [ ] FABER workflow config examples showing how to define custom workflows
  - [ ] Plugin integration sections preserved/updated
- [ ] `manager-as-agent.md` clarified to reference core faber-manager (or deleted if redundant)
- [ ] `README.md` updated to reflect new architecture
- [ ] Agent/skill creator files updated to not suggest manager/director creation

### Audit (Phase 3)

- [ ] Audit detects project-specific director skills as **ERROR** (blocks)
- [ ] Audit detects project-specific manager agents as **ERROR** (blocks)
- [ ] Audit detects `/{project}-direct` commands as **ERROR** (blocks)
- [ ] Audit generates migration proposal showing:
  - [ ] Equivalent FABER workflow config JSON
  - [ ] Files to delete
  - [ ] New invocation pattern to use
  - [ ] Optional alias command pattern

### NOT Required (Removed from Scope)

- ~~Automated migration tooling~~ - Not needed per refinement
- ~~Template deprecation~~ - Templates don't exist
- ~~Migration guide document~~ - Audit output is sufficient

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking existing projects using custom managers | Low | High | Few/no existing projects use this pattern. Audit provides clear migration path. |
| User confusion about what they CAN create | Medium | Medium | Clear documentation on skills vs orchestration in rewritten BEST-PRACTICES.md |
| Loss of flexibility for complex workflows | Low | Medium | FABER workflow config supports advanced features (hooks, conditionals, multi-workflow) |
| Large doc rewrite introduces errors | Medium | Medium | Review BEST-PRACTICES.md carefully. Test audit rules. |
| Audit ERROR severity too aggressive | Low | Low | Can adjust to WARNING if real-world feedback indicates issues |

## Success Metrics

- All faber-agent documentation reflects new standards (director-skill.md deleted, BEST-PRACTICES.md rewritten)
- Audit correctly identifies project-specific directors/managers as ERROR anti-patterns
- Audit generates actionable migration proposals with FABER workflow config output
- No new project-specific managers/directors created in faber-agent documentation after update

## Related Issues/Specs

- [WORK-00194](./WORK-00194-faber-agent-best-practices.md): Previous best practices (some content to be reversed)
- [WORK-00197](./WORK-00197-faber-agent-cross-project-audit.md): Audit improvements (detection rules to add)
- [SPEC-00015](./SPEC-00015-faber-agent-plugin-specification.md): Original plugin spec (templates section to update)

## Implementation Notes

### Key Message

The core insight is: **workflow configuration replaces workflow code**. 

Previously, if you wanted a custom workflow, you wrote a manager agent with steps. Now, you write a FABER workflow config file with the same steps, and the universal `faber-manager` executes it.

This is analogous to:
- Instead of writing a custom build system, you write a `Makefile`
- Instead of writing a custom CI system, you write a `.github/workflows/` file
- Instead of writing a custom manager, you write a `.fractary/plugins/faber/workflows/` file

### What Projects Still Do

Projects still create valuable components:
1. **Skills** - Domain-specific operations (the actual work)
2. **Scripts** - Deterministic shell operations
3. **Templates** - File generation patterns
4. **Commands** - User-facing entry points (routing to core FABER)

What they don't create:
1. ~~Directors~~ (use core `faber-director`)
2. ~~Managers~~ (use core `faber-manager`)
3. ~~Orchestration logic~~ (use workflow config)

### Backward Compatibility Period

**Updated approach** (per refinement - no timelines, focus on actions):
1. **Phase 1**: Delete pattern doc, rewrite BEST-PRACTICES.md
2. **Phase 2**: Update agent/skill creators
3. **Phase 3**: Add audit detection with ERROR severity + migration proposals
4. **Throughout**: Existing managers continue to work in projects (no runtime breaking changes)

---

## Changelog

### Refinement Round 1 (2025-12-07)

**Questions Asked**:
1. Should BEST-PRACTICES.md be rewritten, deprecated+new doc, or incremental updates? → **Rewrite**
2. What should happen to director-skill.md pattern document? → **Delete entirely**
3. Should we prioritize migration tooling? → **No tooling needed, focus on audit proposal output**
4. How aggressive should audit detection be? → **ERROR severity (blocks)**

**Changes Applied**:
1. **Corrected inaccuracies**: Removed references to template files that don't exist
2. **Updated documentation section**: Changed from "update BEST-PRACTICES.md" to "COMPLETE REWRITE"
3. **Added pattern doc deletion**: `director-skill.md` to be deleted (not archived)
4. **Removed Phase 4 (Migration Tooling)**: No longer needed per user feedback
5. **Enhanced audit section**: Added ERROR severity, detailed migration proposal format, example output
6. **Updated Files to Create/Modify**: Clear DELETE/REWRITE/UPDATE categorization
7. **Updated Acceptance Criteria**: Aligned with refined scope
8. **Updated Risks**: Reflected actual likelihood and mitigations
