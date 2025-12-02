---
spec_id: WORK-00194-faber-agent-best-practices
work_id: 194
issue_url: https://github.com/fractary/claude-plugins/issues/194
title: Add new best practices to faber-agent plugin
type: feature
status: draft
created: 2025-12-02
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: Add new best practices to faber-agent plugin

**Issue**: [#194](https://github.com/fractary/claude-plugins/issues/194)
**Type**: Feature / Documentation Enhancement
**Status**: Draft
**Created**: 2025-12-02

## Summary

Update the faber-agent plugin to reflect recent architectural shifts in how project-specific agents, skills, and commands are created and maintained. The key change is a move toward a unified `/{project}-direct` command pattern with director skills (not agents) that can orchestrate parallel manager agent invocations. This ensures future agentic workflows follow consistent, battle-tested patterns.

## Background

The faber-agent plugin helps users create and maintain project-specific agents, skills, and commands. Recent evolution of the Fractary ecosystem has established new patterns that need to be documented and enforced in the plugin's templates and guides.

## Best Practices to Document

### 1. Primary Entry Point Pattern

**Pattern**: `/{project}-direct` or `/{project}-{entity}-direct`

**Key characteristics**:
- Accepts the "thing" being worked on as the primary/first argument
- Has `--action` argument to specify which workflow step(s) to execute
- Command itself is a lightweight wrapper for the director skill
- Director skill contains most orchestration logic
- Can construct one or more parallel calls to manager agent(s)

**Example**:
```bash
/{project}-direct <item> --action <step1,step2,step3>
```

### 2. Director is a Skill (Not an Agent)

**Rationale**:
- Enables launching multiple manager instances in parallel
- Avoids multi-level agent calls (agent calling agent is not ideal)
- Director skill can orchestrate parallel work up to a configured limit

**Responsibilities**:
- Parse and validate input from command
- Determine workflow to execute
- Construct parallel manager invocations
- Aggregate results from managers

### 3. Manager Agent Pattern

**Key characteristics**:
- The **only** agent typically needed per project
- Lightweight wrapper for corresponding manager skill
- Operates on a **single item** at a time
- Leverages skills for each step in the workflow
- Parallel instances can be spawned by director skill

**Structure**:
```
manager-agent (lightweight)
  └── manager-skill (orchestration logic)
        ├── step-1-skill
        ├── step-2-skill
        └── step-n-skill
```

### 4. Skills for Workflow Steps (Not Agents)

**Rationale**:
- Skills are more powerful and context-efficient
- Each workflow step should be a dedicated skill
- Skills can be composed and reused

**Examples of step skills**:
- `framer-skill` - Frame phase logic
- `architect-skill` - Design and specification
- `builder-skill` - Implementation
- `evaluator-skill` - Testing and review
- `releaser-skill` - PR creation and deployment

### 5. Actions Argument Behavior

**Format**: Comma-separated list (no spaces)

**Examples**:
```bash
--action frame,architect,build    # Run specific steps
--action build,evaluate           # Run subset
# (no --action)                   # Run entire workflow
```

**Director behavior**:
- If no `--action` provided: run entire workflow from start to finish
- Always state what will be done and to what
- List all workflow steps when running full workflow

### 6. Engineer/Builder Skill Documentation Requirement

**Critical rule**: The engineer/builder skill MUST update architecture and technical documentation as part of its execution.

**Purpose**: Ensures documentation stays up-to-date and well-maintained with every implementation.

**What to update**:
- Architecture documentation
- Technical design documents
- Component documentation
- API documentation (if applicable)

### 7. Debugger Skill Pattern

**Purpose**: Maintain a troubleshooting log of past issues and solutions.

**Benefits**:
- Avoid reinventing solutions to recurring problems
- Build institutional knowledge
- Speed up debugging by referencing past fixes

**Usage**: Any problem identified should consult the debugger skill first.

### 8. Required Plugin Integrations

All faber-agent based projects should integrate with:

| Plugin | Purpose |
|--------|---------|
| `fractary-docs` | Documentation management |
| `fractary-specs` | Specification writing |
| `fractary-logs` | Log writing and maintenance |
| `fractary-file` | Cloud storage operations |
| `faber-cloud` | IaC/infrastructure/AWS deployments |

## Implementation Plan

### Phase 1: Documentation Updates

**Tasks**:
- [ ] Update faber-agent plugin's implementation guide with new patterns
- [ ] Document the `/{project}-direct` command pattern
- [ ] Document director skill vs agent distinction
- [ ] Document manager agent pattern
- [ ] Add examples for each pattern

### Phase 2: Template Updates

**Tasks**:
- [ ] Update command templates to generate `/{project}-direct` pattern
- [ ] Update skill templates for director skill pattern
- [ ] Update agent templates (now only manager agent)
- [ ] Add debugger skill template
- [ ] Add plugin integration references to templates

### Phase 3: Validation and Testing

**Tasks**:
- [ ] Test template generation with new patterns
- [ ] Validate generated artifacts follow best practices
- [ ] Update any existing faber-agent outputs to new patterns

## Files to Create/Modify

### Modified Files

- `plugins/faber-agent/docs/IMPLEMENTATION-GUIDE.md`: Add best practices sections
- `plugins/faber-agent/docs/PATTERNS.md`: New file documenting architectural patterns
- `plugins/faber-agent/skills/agent-creator/templates/`: Update templates
- `plugins/faber-agent/skills/skill-creator/templates/`: Update templates
- `plugins/faber-agent/skills/command-creator/templates/`: Update templates

### New Files

- `plugins/faber-agent/templates/director-skill.md.template`: Director skill template
- `plugins/faber-agent/templates/debugger-skill.md.template`: Debugger skill template
- `plugins/faber-agent/docs/BEST-PRACTICES.md`: Consolidated best practices

## Acceptance Criteria

- [ ] Documentation clearly explains the `/{project}-direct` command pattern
- [ ] Director skill pattern is documented with examples
- [ ] Manager agent as the only agent pattern is established
- [ ] Skills for workflow steps pattern is documented
- [ ] Actions argument comma-separated behavior is documented
- [ ] Engineer/builder documentation requirement is specified
- [ ] Debugger skill pattern is documented
- [ ] Required plugin integrations are listed
- [ ] Templates generate artifacts following new patterns
- [ ] Existing CLAUDE.md and guides are updated

## Dependencies

- fractary-docs plugin (for documentation management)
- fractary-specs plugin (for specification writing)
- fractary-logs plugin (for logging)
- fractary-file plugin (for cloud storage)
- faber-cloud plugin (for infrastructure)

## Risks and Mitigations

- **Risk**: Breaking changes to existing faber-agent based projects
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Document migration path, maintain backward compatibility where possible

- **Risk**: Confusion between old and new patterns
  - **Likelihood**: Medium
  - **Impact**: Low
  - **Mitigation**: Clear deprecation notices, migration guide

## Documentation Updates

- `plugins/faber-agent/docs/IMPLEMENTATION-GUIDE.md`: Add best practices sections
- `plugins/faber-agent/docs/BEST-PRACTICES.md`: New comprehensive guide
- `plugins/faber-agent/README.md`: Update with pattern overview
- `CLAUDE.md`: Update if faber-agent references exist

## Success Metrics

- All new faber-agent creations follow the new patterns
- Documentation is clear and comprehensive
- No confusion reported about patterns
- Templates generate compliant artifacts

## Implementation Notes

This work affects the **faber-agent plugin** which helps create project-specific Claude Code components. The patterns being documented here are derived from real-world experience with the Fractary plugin ecosystem and represent the current best practices for agentic workflow design.

Key insight: By having the director as a skill rather than an agent, we enable true parallel execution of manager agents - a significant architectural improvement over nested agent calls.
