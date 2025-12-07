# FABER Agent Best Practices

**Authoritative guide to creating project-specific skills and FABER workflow configurations**

Version: 2.0.0
Last Updated: 2025-12-07

---

## Overview

This document codifies the current best practices for creating agentic workflows using the faber-agent plugin. These patterns leverage the core FABER orchestration system for workflow management, allowing projects to focus on domain-specific skills.

---

## Core Architecture Principle

> **Projects create Skills. FABER handles orchestration.**

This simple rule eliminates architectural complexity and ensures consistency across all projects.

### What This Means

| Component | Who Creates It | Where It Lives |
|-----------|---------------|----------------|
| **Director** | Core FABER plugin | `plugins/faber/skills/faber-director/` |
| **Manager** | Core FABER plugin | `plugins/faber/skills/faber-manager/` |
| **Workflow orchestration** | Core FABER plugin | Via workflow configuration |
| **Domain skills** | Your project | `plugins/{project}/skills/` |
| **Scripts** | Your project | `plugins/{project}/skills/*/scripts/` |
| **Workflow definitions** | Your project | `.fractary/plugins/faber/workflows/` |

---

## 1. What Projects SHOULD Create

### Domain-Specific Skills

Projects create **skills** that perform domain-specific operations. These skills are invoked BY the core faber-manager, not by project-specific orchestration.

```
plugins/{project}/skills/
├── {project}-validator/      # Validation logic
│   ├── SKILL.md
│   └── scripts/
│       └── validate.sh
├── {project}-processor/      # Processing logic
│   ├── SKILL.md
│   └── scripts/
│       └── process.sh
├── {project}-reporter/       # Reporting logic
│   ├── SKILL.md
│   └── scripts/
│       └── generate-report.sh
└── {project}-inspector/      # Observation logic
    ├── SKILL.md
    └── scripts/
        └── inspect.sh
```

### Skill Anatomy

```markdown
---
skill: {project}-{operation}
purpose: {What this skill accomplishes}
---

# {Skill Name}

<CONTEXT>
{Role in the workflow - invoked by faber-manager}
</CONTEXT>

<CRITICAL_RULES>
1. {Skill-specific rules}
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

### Scripts for Deterministic Operations

All deterministic operations should be in shell scripts, not inline in skill files:

```
plugins/{project}/skills/{skill-name}/scripts/
├── validate.sh
├── process.sh
├── fetch-data.sh
└── generate-output.sh
```

**Benefits:**
- Independently testable
- No LLM context usage for deterministic logic
- Reusable across skills
- Version controllable

### Commands Routing to FABER

Projects can create convenience commands that **route to FABER**, not to project-specific orchestration:

```markdown
# /{project}-run Command

<CONTEXT>
Convenience command that routes to FABER workflow execution.
</CONTEXT>

<WORKFLOW>
1. Parse arguments
2. Invoke: /faber run {work_id} --workflow {project}-workflow
</WORKFLOW>
```

**Important:** These commands are thin wrappers. They MUST NOT contain orchestration logic.

### FABER Workflow Configurations

Define project-specific workflows as JSON configuration files:

```
.fractary/plugins/faber/workflows/
├── {project}-full.json        # Complete workflow
├── {project}-validate.json    # Validation-only workflow
└── {project}-deploy.json      # Deployment workflow
```

See [Section 4: FABER Workflow Configuration](#4-faber-workflow-configuration) for details.

---

## 2. What Projects MUST NOT Create (Anti-Patterns)

### Anti-Pattern: Project-Specific Directors

**DO NOT** create director skills for your project:

```
# WRONG - Creates project-specific orchestration
plugins/{project}/skills/{project}-director/SKILL.md
```

**Why this is wrong:**
- Duplicates core FABER functionality
- Prevents consistent workflow management
- Adds maintenance burden
- Wastes context on orchestration logic

**Instead:** Use the core `faber-director` via `/faber run`.

### Anti-Pattern: Project-Specific Managers

**DO NOT** create manager agents for your project:

```
# WRONG - Creates project-specific orchestration
plugins/{project}/agents/{project}-manager.md
```

**Why this is wrong:**
- FABER's universal manager already handles all workflows
- Project managers duplicate orchestration logic
- Creates inconsistency across projects
- Complicates maintenance and updates

**Instead:** Use the core `faber-manager` with workflow configuration.

### Anti-Pattern: `/{project}-direct` Commands

**DO NOT** create direct-style commands:

```bash
# WRONG - Bypasses FABER orchestration
/{project}-direct item-123 --action validate,build
```

**Why this is wrong:**
- Requires project-specific director skill
- Bypasses centralized workflow management
- Loses FABER benefits (hooks, logging, state tracking)

**Instead:**
```bash
# CORRECT - Uses FABER orchestration
/faber run 123 --workflow {project}-workflow --phases build
```

### Anti-Pattern: Custom Orchestration Logic

**DO NOT** put workflow orchestration logic in project files:

```markdown
# WRONG - Orchestration logic in project skill
<WORKFLOW>
1. If batch pattern (* or ,):
   - For each entity (parallel, max 5):
     - Invoke {project}-manager
2. Aggregate results
</WORKFLOW>
```

**Why this is wrong:**
- Orchestration belongs in FABER, not projects
- Parallel execution is handled by FABER
- State management is handled by FABER

**Instead:** Define workflow steps in FABER configuration, let FABER orchestrate.

---

## 3. The Transformation: Old vs New

### Before (Project-Specific Orchestration)

```
/{project}-direct (Command)
  └─► {project}-director (Skill) ← ANTI-PATTERN
        └─► {project}-manager (Agent) ← ANTI-PATTERN
              ├─► {project}-validator (Skill)
              ├─► {project}-processor (Skill)
              └─► {project}-reporter (Skill)
```

### After (FABER Orchestration)

```
/faber run (Command)
  └─► faber-director (Core FABER)
        └─► faber-manager (Core FABER)
              ├─► {project}-validator (Skill) ← Your project
              ├─► {project}-processor (Skill) ← Your project
              └─► {project}-reporter (Skill) ← Your project
```

### What Changes

| Old Approach | New Approach |
|--------------|--------------|
| `/{project}-direct item-123` | `/faber run 123 --workflow {project}` |
| `{project}-director` skill | Core `faber-director` |
| `{project}-manager` agent | Core `faber-manager` |
| Orchestration in project | Workflow config in `.fractary/` |

### What Stays the Same

- Domain skills (validator, processor, reporter, etc.)
- Scripts in `scripts/` directories
- Plugin integrations (fractary-docs, fractary-specs, etc.)
- Documentation requirements

---

## 4. FABER Workflow Configuration

Define project-specific workflows as JSON configuration files.

### Location

```
.fractary/plugins/faber/workflows/{project}-{workflow-name}.json
```

### Structure

```json
{
  "id": "{project}-workflow",
  "description": "Description of this workflow",
  "phases": {
    "frame": {
      "enabled": true,
      "steps": []
    },
    "architect": {
      "enabled": false
    },
    "build": {
      "enabled": true,
      "steps": [
        {"id": "validate", "skill": "{project}:{project}-validator"},
        {"id": "process", "skill": "{project}:{project}-processor"},
        {"id": "report", "skill": "{project}:{project}-reporter"}
      ]
    },
    "evaluate": {
      "enabled": true,
      "steps": [
        {"id": "test", "skill": "{project}:{project}-tester"}
      ]
    },
    "release": {
      "enabled": false
    }
  },
  "autonomy": {
    "level": "guarded",
    "require_approval_for": ["release"]
  }
}
```

### Multiple Workflows

Define multiple workflows for different operations:

```json
// {project}-validate-only.json
{
  "id": "{project}-validate-only",
  "description": "Run validation without processing",
  "phases": {
    "build": {
      "enabled": true,
      "steps": [
        {"id": "validate", "skill": "{project}:{project}-validator"}
      ]
    }
  }
}
```

### Invocation

```bash
# Full workflow
/faber run 123 --workflow {project}-workflow

# Validation only
/faber run 123 --workflow {project}-validate-only

# Specific phases
/faber run 123 --workflow {project}-workflow --phases build,evaluate
```

### Convenience Aliases

If you want short command aliases, create thin wrappers:

```markdown
# /{project} Command (Thin Wrapper)

<WORKFLOW>
1. Parse work_id from first argument
2. Invoke: /faber run {work_id} --workflow {project}-workflow
</WORKFLOW>
```

---

## 5. Skills: Documentation Requirement

### Critical Rule

> **Skills that make changes MUST update documentation as part of their execution.**

This is non-negotiable. Every implementation step must include documentation updates.

### What to Update

| Document Type | When to Update |
|--------------|----------------|
| Architecture docs | When structure changes |
| Technical design docs | When implementation approach changes |
| Component documentation | When adding/modifying components |
| API documentation | When endpoints change |
| README files | When usage changes |

### Skill Template with Documentation Requirement

```markdown
<WORKFLOW>
## Phase 1: Execute
Perform the main work.

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
2. Documentation updates are part of the work, not optional
3. Use fractary-docs plugin for all documentation changes
</CRITICAL_RULES>
```

---

## 6. Debugger Skill Pattern

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
plugins/{project}/skills/{project}-debugger/
├── SKILL.md
├── scripts/
│   ├── search-kb.sh
│   ├── add-solution.sh
│   └── update-solution.sh
└── knowledge-base/
    ├── index.json
    └── solutions/
        ├── KB-0001-*.md
        └── KB-0002-*.md
```

---

## 7. Required Plugin Integrations

### Mandatory Integrations

All projects SHOULD integrate with these plugins:

| Plugin | Purpose | When to Use |
|--------|---------|-------------|
| `fractary-docs` | Documentation management | All doc updates |
| `fractary-spec` | Specification writing | Architect phase |
| `fractary-logs` | Log writing and maintenance | All phases |
| `fractary-file` | Cloud storage operations | Artifact storage |
| `faber-cloud` | IaC/infrastructure/AWS | Deployments |

### Integration in Skills

```markdown
<AVAILABLE_INTEGRATIONS>
## Fractary Plugin Skills (Required Integrations)
- fractary-docs:docs-manager    # Documentation updates
- fractary-spec:spec-generator  # Specification creation
- fractary-logs:log-manager     # Logging operations
- fractary-file:file-manager    # Cloud storage
- faber-cloud:infra-manager     # Infrastructure (if applicable)
</AVAILABLE_INTEGRATIONS>
```

### When to Use Each

**fractary-docs**:
- Skills updating technical docs
- Release phase updating user docs
- Any documentation changes

**fractary-spec**:
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

## 8. Complete Architecture Example

### Project Structure

```
plugins/{project}/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── {project}-validator/
│   │   ├── SKILL.md
│   │   └── scripts/validate.sh
│   ├── {project}-processor/
│   │   ├── SKILL.md
│   │   └── scripts/process.sh
│   ├── {project}-reporter/
│   │   ├── SKILL.md
│   │   └── scripts/generate-report.sh
│   └── {project}-debugger/
│       ├── SKILL.md
│       ├── scripts/
│       └── knowledge-base/
├── commands/
│   └── {project}.md           # Thin wrapper to FABER
└── README.md
```

### Workflow Configuration

```
.fractary/plugins/faber/workflows/
└── {project}-workflow.json    # Defines step sequence
```

### Invocation Flow

```
User: /faber run 123 --workflow {project}-workflow

faber-director (Core)
  │
  └─► faber-manager (Core)
        │
        ├─► Step: validate
        │   └─► {project}:{project}-validator (Your Skill)
        │
        ├─► Step: process
        │   └─► {project}:{project}-processor (Your Skill)
        │
        ├─► Step: report
        │   └─► {project}:{project}-reporter (Your Skill)
        │         └─► fractary-docs:docs-manager (Integration)
        │
        └─► Step: test
            └─► {project}:{project}-tester (Your Skill)
```

---

## 9. Migration Checklist

If updating an existing project from old patterns:

### Remove Anti-Patterns

- [ ] Delete `{project}-director` skill (if exists)
- [ ] Delete `{project}-manager` agent (if exists)
- [ ] Delete `/{project}-direct` command (if exists)
- [ ] Remove any orchestration logic from skills

### Create FABER Configuration

- [ ] Create `.fractary/plugins/faber/workflows/{project}.json`
- [ ] Define phases and steps referencing your skills
- [ ] Test with `/faber run <id> --workflow {project}`

### Update Commands (if needed)

- [ ] Convert direct commands to thin wrappers
- [ ] Ensure commands route to `/faber run`

### Verify Skills

- [ ] Skills contain only domain logic (no orchestration)
- [ ] Scripts are in `scripts/` directories
- [ ] Documentation updates are required in relevant skills

### Run Audit

- [ ] Run `/fractary-faber-agent:audit` on your project
- [ ] Fix any detected anti-patterns
- [ ] Verify compliance with new standards

---

## Anti-Patterns to Avoid (Summary)

| Anti-Pattern | Why It's Wrong | Correct Approach |
|--------------|----------------|------------------|
| Project-specific director | Duplicates FABER, adds maintenance | Use core `faber-director` |
| Project-specific manager | Duplicates FABER, inconsistent | Use core `faber-manager` |
| `/{project}-direct` command | Requires project orchestration | Use `/faber run --workflow` |
| Orchestration in skills | Wrong layer, duplicates FABER | Workflow config + domain skills |
| Inline scripts in skills | Untestable, wastes context | Scripts in `scripts/` directory |
| Skipping documentation | Incomplete work | Always update docs |
| Not using plugin integrations | Inconsistent, duplicates effort | Use fractary-* plugins |

---

## Related Documentation

- **FABER Configuration** - `/plugins/faber/docs/CONFIGURATION.md`
- **FABER Workflow Format** - `/plugins/faber/docs/WORKFLOW-FORMAT.md`
- **Plugin Standards** - `/docs/standards/FRACTARY-PLUGIN-STANDARDS.md`

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0 | 2025-12-07 | **Major rewrite**: Removed project-specific director/manager patterns. All orchestration now via core FABER with workflow configs. |
| 1.1.0 | 2025-12-02 | Added workflow event logging, multiple workflows, deprecated direct skill commands |
| 1.0.0 | 2025-12-02 | Initial best practices document |
