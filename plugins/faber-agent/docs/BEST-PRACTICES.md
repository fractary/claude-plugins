# FABER Agent Best Practices

**Authoritative guide to creating project-specific agents, skills, and workflows**

Version: 1.0.0
Last Updated: 2025-12-02

---

## Overview

This document codifies the current best practices for creating agentic workflows using the faber-agent plugin. These patterns have evolved from real-world experience building production Claude Code plugins and represent the most context-efficient, maintainable architecture.

---

## Core Architecture Principles

### The Golden Rule

> **Directors are Skills. Managers are Agents. Everything else is Skills.**

This simple rule eliminates most architectural anti-patterns.

---

## 1. Primary Entry Point: `/{project}-direct` Command

### Pattern

Every project should have a **single primary entry point** command:

```
/{project}-direct
```

Or for projects managing multiple entity types:

```
/{project}-{entity}-direct
```

### Characteristics

| Aspect | Description |
|--------|-------------|
| **First Argument** | The "thing" being worked on (entity ID, file path, etc.) |
| **--action Flag** | Specifies which workflow step(s) to execute |
| **Implementation** | Lightweight wrapper that immediately invokes director skill |
| **No Logic** | Command does NO work - only parses args and routes |

### Example

```bash
# Process a single dataset
/myproject-direct dataset-123 --action validate,build

# Process all datasets (batch)
/myproject-direct "*" --action refresh

# Run entire workflow (no --action = all steps)
/myproject-direct dataset-123
```

### Command Template

```markdown
# /{project}-direct Command

<CONTEXT>
Entry point for {project} operations. Parses arguments and invokes director skill.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER do work directly - immediately invoke director skill
2. Parse --action as comma-separated list (no spaces)
3. If no --action provided, pass empty to trigger full workflow
</CRITICAL_RULES>

<WORKFLOW>
1. Parse first argument as target entity
2. Parse --action flag (comma-separated, no spaces)
3. Invoke {project}-director skill with parsed parameters
4. Return director's output to user
</WORKFLOW>
```

---

## 2. Actions Argument Behavior

### Format

Actions are specified as a **comma-separated list with no spaces**:

```bash
--action step1,step2,step3
```

### Behavior Matrix

| Input | Behavior |
|-------|----------|
| `--action frame` | Run only frame step |
| `--action frame,architect,build` | Run three steps in order |
| `--action build,evaluate` | Run subset of workflow |
| *(no --action)* | Run **entire workflow** from start to finish |

### Director Behavior When No Action Specified

When `--action` is omitted, the director skill MUST:

1. **State what will happen**: Announce the full workflow that will execute
2. **List all steps**: Show the complete sequence (e.g., "Running: frame → architect → build → evaluate → release")
3. **Identify the target**: State which entity/entities will be processed
4. **Proceed with execution**: Run all steps in sequence

### Example Director Output

```
Starting full workflow for dataset-123:
  1. frame     - Fetch work item, classify, setup
  2. architect - Design solution, create specification
  3. build     - Implement from spec
  4. evaluate  - Test and review
  5. release   - Create PR, document

Proceeding with step 1 of 5: frame...
```

---

## 3. Director is a Skill (Not an Agent)

### Why This Matters

Making the director a **skill** (not an agent) enables:

1. **Parallel Manager Invocations**: Director skill can spawn multiple manager agents concurrently
2. **No Nested Agents**: Avoids agent-calling-agent anti-pattern
3. **Context Efficiency**: Skills use less context than agents
4. **Flexible Orchestration**: Director can batch items and parallelize

### Director Skill Responsibilities

| Do | Don't |
|----|-------|
| Parse and validate input | Do actual work |
| Determine which workflow steps to run | Make business decisions |
| Construct parallel manager invocations | Aggregate complex results |
| Coordinate batch operations | Maintain long-term state |

### Parallel Execution Pattern

```markdown
<WORKFLOW>
1. Parse input from command (entity, actions)
2. If batch pattern (*, comma-separated):
   - Expand pattern to entity list
   - For each entity (parallel, max 5):
     - Invoke {project}-manager agent
   - Collect results
3. If single entity:
   - Invoke {project}-manager agent directly
4. Return aggregated results
</WORKFLOW>
```

### Parallel Limit

Default parallel limit: **5 concurrent manager instances**

This balances:
- Speed (5x faster than sequential)
- Resource usage (reasonable context load)
- Rate limits (API considerations)

---

## 4. Manager Agent: The Only Agent You Need

### Pattern

Each project typically needs **only one agent**: the Manager.

```
{project}-manager (Agent)
  └── {project}-manager-skill (Skill with orchestration logic)
        ├── step-1-skill
        ├── step-2-skill
        └── step-n-skill
```

### Manager Agent Characteristics

| Aspect | Description |
|--------|-------------|
| **Type** | Agent (full tool access) |
| **Scope** | Single entity at a time |
| **Role** | Lightweight wrapper for manager skill |
| **Workflow** | Delegates to skills for each step |

### Manager Agent Template

```markdown
---
name: {project}-manager
description: Orchestrates {project} workflow for single entity
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---

# {Project} Manager

<CONTEXT>
Orchestrates workflow for a single {entity}. Invoked by director skill
(possibly in parallel with other manager instances).
</CONTEXT>

<CRITICAL_RULES>
1. Operate on exactly ONE entity per invocation
2. Delegate ALL work to skills - never do work directly
3. Follow the workflow phases in order
4. Handle errors gracefully with user notification
</CRITICAL_RULES>

<WORKFLOW>
Invoke {project}-manager-skill with entity and requested actions.
The manager skill contains the detailed orchestration logic.
</WORKFLOW>
```

### Why Manager is Agent (Not Skill)

Managers need agent capabilities:
- **AskUserQuestion**: For approval gates
- **Full Tool Access**: For investigation and recovery
- **Persistent Context**: For multi-phase state management
- **Natural Interaction**: For user communication

---

## 5. Skills for All Workflow Steps

### Pattern

Every workflow step is implemented as a **skill**, not an agent.

```
skills/
├── {project}-framer/          # Frame phase
├── {project}-architect/       # Architect phase
├── {project}-builder/         # Build phase
├── {project}-evaluator/       # Evaluate phase
├── {project}-releaser/        # Release phase
├── {project}-inspector/       # Read-only observation
├── {project}-debugger/        # Analysis and troubleshooting
└── {project}-director/        # Batch orchestration
```

### Why Skills (Not Agents) for Steps

1. **Context Efficiency**: Skills load only when needed
2. **Composability**: Skills can be combined in different workflows
3. **Testability**: Skills with scripts are independently testable
4. **Reusability**: Skills can be shared across workflows
5. **Parallelism**: Skills don't block other agent invocations

### Skill Anatomy

```markdown
---
skill: {project}-{step}
purpose: {What this step accomplishes}
---

# {Step Name}

<CONTEXT>
{Role in the workflow}
</CONTEXT>

<CRITICAL_RULES>
1. {Step-specific rules}
</CRITICAL_RULES>

<WORKFLOW>
1. {Step 1}
2. {Step 2}
   Script: scripts/{operation}.sh
3. {Step 3}
</WORKFLOW>

<OUTPUTS>
{What this skill returns}
</OUTPUTS>
```

---

## 6. Builder Skill: Documentation Requirement

### Critical Rule

> **The builder/engineer skill MUST update architecture and technical documentation as part of its execution.**

This is non-negotiable. Every implementation step must include documentation updates.

### What to Update

| Document Type | When to Update |
|--------------|----------------|
| Architecture docs | When structure changes |
| Technical design docs | When implementation approach changes |
| Component documentation | When adding/modifying components |
| API documentation | When endpoints change |
| README files | When usage changes |

### Builder Skill Template (with docs requirement)

```markdown
<WORKFLOW>
## Phase 1: Implement
Execute the build/implementation work.

## Phase 2: Update Documentation (REQUIRED)
Update technical documentation to reflect changes:
- Architecture docs if structure changed
- Component docs for new/modified components
- API docs if endpoints changed
- README if usage changed

Invoke: fractary-docs:docs-manager with changes

## Phase 3: Verify
Confirm implementation and docs are complete.
</WORKFLOW>

<CRITICAL_RULES>
1. NEVER complete without updating documentation
2. Documentation updates are part of the build, not optional
3. Use fractary-docs plugin for all documentation changes
</CRITICAL_RULES>
```

---

## 7. Debugger Skill Pattern

### Purpose

Maintain a **troubleshooting knowledge base** of past issues and solutions.

### Benefits

1. **Avoid Reinventing Solutions**: Reference past fixes for recurring problems
2. **Build Institutional Knowledge**: Capture learnings over time
3. **Speed Up Debugging**: Check known issues before deep investigation
4. **Reduce Token Usage**: Reuse documented solutions

### Usage Pattern

```markdown
<WORKFLOW>
## On Any Error/Issue

1. FIRST: Consult debugger skill
   - Check troubleshooting knowledge base
   - Search for similar past issues
   - Look for documented solutions

2. IF solution found:
   - Apply documented fix
   - Note if fix worked (update KB if needed)

3. IF no solution found:
   - Investigate the issue
   - Document the solution in KB
   - Apply the fix
</WORKFLOW>
```

### Debugger Skill Structure

```
skills/{project}-debugger/
├── SKILL.md                    # Skill definition
├── scripts/
│   ├── search-kb.sh           # Search knowledge base
│   ├── add-solution.sh        # Add new solution
│   └── update-solution.sh     # Update existing solution
└── knowledge-base/
    ├── index.json             # Issue index
    └── solutions/             # Solution documents
        ├── KB-0001-*.md
        └── KB-0002-*.md
```

### Knowledge Base Entry Template

```markdown
---
kb_id: KB-{number}
title: {Issue title}
symptoms: [{symptom1}, {symptom2}]
root_cause: {Why it happens}
solution: {How to fix}
created: {date}
last_used: {date}
use_count: {number}
---

# {Issue Title}

## Symptoms
- {How to recognize this issue}

## Root Cause
{Why this happens}

## Solution
{Step-by-step fix}

## Prevention
{How to avoid in future}
```

---

## 8. Required Plugin Integrations

### Mandatory Integrations

All faber-agent based projects SHOULD integrate with these plugins:

| Plugin | Purpose | When to Use |
|--------|---------|-------------|
| `fractary-docs` | Documentation management | All doc updates |
| `fractary-specs` | Specification writing | Architect phase |
| `fractary-logs` | Log writing and maintenance | All phases |
| `fractary-file` | Cloud storage operations | Artifact storage |
| `faber-cloud` | IaC/infrastructure/AWS | Deployments |

### Integration Pattern

```markdown
<AVAILABLE_SKILLS>
## Core Workflow Skills
- {project}-framer
- {project}-architect
- {project}-builder
- {project}-evaluator
- {project}-releaser

## Fractary Plugin Skills (Required Integrations)
- fractary-docs:docs-manager    # Documentation updates
- fractary-specs:spec-generator # Specification creation
- fractary-logs:log-manager     # Logging operations
- fractary-file:file-manager    # Cloud storage
- faber-cloud:infra-manager     # Infrastructure (if applicable)
</AVAILABLE_SKILLS>
```

### When to Use Each

**fractary-docs**:
- Builder skill updating technical docs
- Release skill updating user docs
- Any documentation changes

**fractary-specs**:
- Architect phase creating specifications
- Design documents
- Technical specifications

**fractary-logs**:
- Workflow execution logs
- Audit trails
- Error logs
- Phase completion records

**fractary-file**:
- Storing artifacts to cloud
- Retrieving shared resources
- Backup operations

**faber-cloud**:
- Infrastructure provisioning
- Deployment operations
- AWS resource management

---

## Complete Architecture Example

```
/{project}-direct (Command)
  │
  └─► {project}-director (Skill)
        │
        ├─► Single entity: Invoke manager directly
        │
        └─► Batch (*,a,b,c): Invoke managers in parallel (max 5)
              │
              └─► {project}-manager (Agent) × N
                    │
                    └─► {project}-manager-skill (Skill)
                          │
                          ├─► {project}-framer (Skill)
                          │     └─► fractary-work:issue-fetcher
                          │
                          ├─► {project}-architect (Skill)
                          │     └─► fractary-specs:spec-generator
                          │
                          ├─► {project}-builder (Skill)
                          │     ├─► [implementation work]
                          │     └─► fractary-docs:docs-manager
                          │
                          ├─► {project}-evaluator (Skill)
                          │     └─► [testing/review]
                          │
                          └─► {project}-releaser (Skill)
                                ├─► fractary-repo:pr-manager
                                └─► fractary-logs:log-manager
```

---

## Anti-Patterns to Avoid

### 1. Director as Agent
**Wrong**: Making director an agent prevents parallel manager execution.
**Right**: Director is always a skill.

### 2. Multiple Agents per Project
**Wrong**: Having frame-agent, build-agent, evaluate-agent.
**Right**: One manager agent, multiple skills.

### 3. Agent Calling Agent
**Wrong**: Manager agent invoking another agent directly.
**Right**: Manager invokes skills; only director spawns managers.

### 4. Inline Scripts in Skills
**Wrong**: Bash code directly in SKILL.md.
**Right**: Scripts in `scripts/` directory, invoked by skill.

### 5. Skipping Documentation Updates
**Wrong**: Builder skill that only implements without updating docs.
**Right**: Documentation updates are mandatory part of build phase.

### 6. Not Using Plugin Integrations
**Wrong**: Custom logging, custom spec format, direct git commands.
**Right**: Use fractary-logs, fractary-specs, fractary-repo plugins.

---

## Migration Checklist

If updating an existing project to follow these best practices:

- [ ] Rename primary command to `/{project}-direct`
- [ ] Add `--action` argument support (comma-separated)
- [ ] Convert director from agent to skill
- [ ] Ensure only one manager agent exists
- [ ] Convert workflow step agents to skills
- [ ] Add documentation update requirement to builder
- [ ] Create debugger skill with knowledge base
- [ ] Add fractary plugin integrations
- [ ] Update all templates to follow patterns

---

## Related Documentation

- **Pattern: Director Skill** - `/docs/patterns/director-skill.md`
- **Pattern: Manager-as-Agent** - `/docs/patterns/manager-as-agent.md`
- **Pattern: Builder/Debugger** - `/docs/patterns/builder-debugger.md`
- **Migration Guides** - `/docs/migration/`
- **Plugin Standards** - `/docs/standards/FRACTARY-PLUGIN-STANDARDS.md`

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-02 | Initial best practices document |
