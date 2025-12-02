---
spec_id: WORK-00197-faber-agent-cross-project-audit
work_id: 197
issue_url: https://github.com/fractary/claude-plugins/issues/197
title: Improve faber-agent audit to be actionable across projects
type: feature
status: draft
created: 2025-12-02
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: Improve faber-agent audit to be actionable across projects

**Issue**: [#197](https://github.com/fractary/claude-plugins/issues/197)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-02

## Summary

Improve the existing `/fractary-faber-agent:audit-project` command and `project-auditor` agent to produce **actionable output** when auditing any project's Claude Code components. The current audit exists but produces results that are not useful for understanding gaps or planning remediation. The improved audit should clearly show what IS vs what SHOULD BE, with specific proposed changes.

## Background

### What Exists Today

The faber-agent plugin already has:
- `/fractary-faber-agent:audit-project` command (routes to agent)
- `project-auditor` agent (7-phase workflow: Inspect → Analyze → Present → Approve → Execute → Verify → Report)
- `project-analyzer` skill (detects anti-patterns)
- Output to `logs/audits/{timestamp}-architecture-audit.[md|json]`
- Detection of: Manager-as-Skill, Agent Chains, Director-as-Agent, Hybrid Agents, Inline Logic

### The Problem

When running the audit, the output is **not actionable**:
1. Findings are too abstract ("Manager-as-Skill detected")
2. No clear comparison of "current state" vs "best practice"
3. No specific file-level proposals for changes
4. Recommendations are generic ("migrate to agent") without showing what that means
5. User can't take the report and execute a plan

### What's Needed

A point-in-time audit report that:
1. Lists each component with its current state
2. Compares against specific best practices rules
3. Shows exactly what changes would bring it into alignment
4. Provides a prioritized remediation plan with file-level tasks
5. Lives in `/logs/` with timestamps (run multiple times as practices evolve)

## User Stories

### Actionable Audit Report
**As a** Claude Code user working on any project
**I want** to run an audit that shows me exactly what's wrong and how to fix it
**So that** I can create a concrete plan to improve my components

**Acceptance Criteria**:
- [ ] For each finding, shows "Current" vs "Should Be" comparison
- [ ] Provides file-level proposed changes (not just "migrate this")
- [ ] Groups findings by component with clear status (compliant/non-compliant)
- [ ] Includes remediation checklist that can be executed as tasks

### Cross-Project Usage
**As a** Claude Code user in a different organization/project
**I want** to audit my project's components against latest best practices
**So that** I can benefit from faber-agent patterns without being in the claude-plugins repo

**Acceptance Criteria**:
- [ ] Audit works from any project directory with `.claude/` components
- [ ] Best practices rules are embedded in faber-agent plugin (no external deps)
- [ ] Report saved to project's `/logs/` directory with timestamp

### Trackable Progress
**As a** Claude Code user improving my components over time
**I want** audit reports with timestamps in `/logs/`
**So that** I can track progress as I remediate issues and as best practices evolve

**Acceptance Criteria**:
- [ ] Reports saved to `/logs/audits/{timestamp}-faber-agent-best-practices.md`
- [ ] Each report is self-contained (can compare across runs)
- [ ] Summary shows compliance score/percentage

## Functional Requirements

- **FR1**: Enhance `project-auditor` to produce component-by-component analysis
- **FR2**: Add "Current vs Should Be" comparison for each finding
- **FR3**: Generate specific file-level remediation proposals
- **FR4**: Create prioritized remediation checklist
- **FR5**: Output to `/logs/audits/{timestamp}-faber-agent-best-practices.md`
- **FR6**: Include compliance score/percentage for tracking
- **FR7**: Embed best practices rules in plugin (no Codex dependency)

## Non-Functional Requirements

- **NFR1**: Audit should complete in < 30 seconds for typical project (performance)
- **NFR2**: Audit should work offline - rules embedded in plugin (reliability)
- **NFR3**: No modification of audited files (read-only analysis)
- **NFR4**: Output format is immediately actionable (usability)

## Technical Design

### Enhanced Audit Report Format

The key improvement is the report format. Each component gets analyzed with specific comparisons:

```markdown
# Best Practices Audit Report

**Project**: /path/to/my-project
**Date**: 2025-12-02T14:30:00Z
**Auditor**: faber-agent v0.5.0
**Compliance Score**: 45% (9/20 checks passing)

---

## Executive Summary

| Category | Components | Compliant | Non-Compliant | Score |
|----------|------------|-----------|---------------|-------|
| Commands | 4          | 2         | 2             | 50%   |
| Agents   | 3          | 1         | 2             | 33%   |
| Skills   | 8          | 5         | 3             | 63%   |
| Hooks    | 1          | 1         | 0             | 100%  |
| **Total**| **16**     | **9**     | **7**         | **56%**|

---

## Component Analysis

### Commands

#### ✅ `.claude/commands/init.md` - COMPLIANT

All checks passing:
- [x] Routes to agent (invokes init-manager)
- [x] No direct work (no Bash/Read/Write)
- [x] Has proper frontmatter

---

#### ❌ `.claude/commands/deploy.md` - NON-COMPLIANT

**Issues Found**: 2

##### Issue 1: Command does direct work

| Aspect | Current State | Best Practice |
|--------|---------------|---------------|
| Pattern | Command executes `Bash` tool directly | Commands MUST only route to agents |
| Location | Lines 45-67 | N/A |
| Impact | Bypasses orchestration layer | |

**Current Code** (lines 45-67):
```markdown
<WORKFLOW>
1. Run deployment script
   Bash: ./scripts/deploy.sh $environment
2. Verify deployment
   Bash: ./scripts/verify.sh
</WORKFLOW>
```

**Proposed Change**:
```markdown
<WORKFLOW>
1. Invoke deploy-manager agent
   Agent: deploy-manager
   Request: {"operation": "deploy", "environment": "$environment"}
</WORKFLOW>
```

**Remediation**:
- [ ] Create `deploy-manager` agent if not exists
- [ ] Move deployment logic to agent workflow
- [ ] Update command to route to agent

---

##### Issue 2: Missing agent invocation pattern

| Aspect | Current State | Best Practice |
|--------|---------------|---------------|
| Pattern | No `Agent:` or `@agent-` reference | Commands MUST invoke agents |
| Evidence | Grep for "Agent:" returns empty | |

**Remediation**:
- [ ] Add agent invocation in `<WORKFLOW>` section

---

### Agents

#### ❌ `.claude/agents/data-processor.md` - NON-COMPLIANT

**Issues Found**: 1

##### Issue 1: Agent does work directly (Hybrid Agent)

| Aspect | Current State | Best Practice |
|--------|---------------|---------------|
| Pattern | Agent contains `Bash:` commands | Agents MUST delegate to skills |
| Location | Lines 78-95 | N/A |
| Impact | Context bloat, not reusable | |

**Current Code** (lines 78-95):
```markdown
<WORKFLOW>
1. Validate input
   Bash: jq '.data | length' input.json
2. Process records
   Bash: ./process.sh
3. Generate report
   Bash: ./report.sh > output.md
</WORKFLOW>
```

**Proposed Change**:
```markdown
<WORKFLOW>
1. Validate input
   Skill: data-validator
   Input: {"file": "input.json"}

2. Process records
   Skill: data-processor
   Input: {"source": "input.json"}

3. Generate report
   Skill: report-generator
   Input: {"format": "markdown"}
</WORKFLOW>
```

**Remediation**:
- [ ] Create `data-validator` skill with validation script
- [ ] Create `data-processor` skill with process.sh
- [ ] Create `report-generator` skill with report.sh
- [ ] Update agent to invoke skills instead of Bash

---

### Skills

#### ❌ `.claude/skills/batch-coordinator/SKILL.md` - NON-COMPLIANT

**Issues Found**: 1

##### Issue 1: Director implemented as wrong component type

| Aspect | Current State | Best Practice |
|--------|---------------|---------------|
| Pattern | Coordinator logic in skill | Directors should be skills (✓) but this one tries to invoke agents |
| Evidence | Contains `Task:` tool usage to spawn agents | Directors invoke managers, not vice versa |
| Impact | Agent nesting, context explosion | |

**Analysis**: This skill is acting as a director (batch coordination) but is trying to spawn agents from within a skill, which inverts the control flow.

**Proposed Architecture**:
```
Current (Wrong):
  Command → Skill (batch-coordinator) → Agent × N

Correct:
  Command → Director Skill (batch-coordinator) → Manager Agent × N
                                                      ↓
                                                   Worker Skills
```

**Remediation**:
- [ ] Rename to `batch-director` to clarify role
- [ ] Ensure it only expands patterns and returns entity list
- [ ] Manager agents handle individual entity processing
- [ ] Skills under manager do actual work

---

## Remediation Plan

### Priority 1: Critical (Breaks Architecture)
1. [ ] **Convert `deploy.md` command to route to agent**
   - File: `.claude/commands/deploy.md`
   - Create: `.claude/agents/deploy-manager.md`
   - Effort: 2 hours

2. [ ] **Split hybrid agent `data-processor.md` into agent + skills**
   - File: `.claude/agents/data-processor.md`
   - Create: `.claude/skills/data-validator/`, `.claude/skills/data-processor/`, `.claude/skills/report-generator/`
   - Effort: 4 hours

### Priority 2: Important (Best Practice Violations)
3. [ ] **Fix director control flow in `batch-coordinator`**
   - File: `.claude/skills/batch-coordinator/SKILL.md`
   - Rename and restructure
   - Effort: 2 hours

### Priority 3: Recommended (Improvements)
4. [ ] **Extract inline scripts to scripts/ directories**
   - Multiple skills have inline Bash
   - Effort: 3 hours

---

## Best Practices Reference

The following best practices were checked (from faber-agent v0.5.0):

### Commands
- CMD-001: Commands route to agents (not do work directly)
- CMD-002: Commands have proper frontmatter
- CMD-003: Commands use space-separated argument syntax

### Agents
- AGT-001: One manager agent per domain
- AGT-002: Agents delegate to skills (no direct Bash/Read/Write)
- AGT-003: Agents have 7-phase workflow structure

### Skills
- SKL-001: Directors are skills (not agents)
- SKL-002: Scripts in scripts/ directory (not inline)
- SKL-003: Builder skills update documentation
- SKL-004: Skills have SKILL.md with proper structure

### Architecture
- ARC-001: /{project}-direct command as primary entry point
- ARC-002: --action argument for workflow step selection
- ARC-003: Plugin integrations (fractary-docs, fractary-specs, etc.)

---

*Report generated by faber-agent project-auditor*
*Best practices version: 2025-12-02 (post-#194)*
```

### Best Practices Rules Definition

Embed rules in plugin as structured data:

**File**: `plugins/faber-agent/config/best-practices-rules.yaml`

```yaml
version: "2025-12-02"
description: "Best practices rules for Claude Code components"

rules:
  commands:
    - id: CMD-001
      name: "Command routes to agent"
      description: "Commands must invoke agents, not do work directly"
      severity: critical
      check:
        type: content_pattern
        pattern: "(Agent:|@agent-|invoke.*agent)"
        must_match: true
      anti_check:
        type: content_pattern
        pattern: "^\\s*(Bash:|Read:|Write:|Edit:)"
        must_not_match: true
      remediation: "Remove direct tool usage, add agent invocation"

    - id: CMD-002
      name: "Proper frontmatter"
      description: "Commands must have name and description in frontmatter"
      severity: warning
      check:
        type: frontmatter
        required_fields: [name, description]

  agents:
    - id: AGT-001
      name: "Single manager per domain"
      description: "Each domain should have one manager agent"
      severity: warning
      check:
        type: naming_pattern
        pattern: "*-manager.md"
        max_per_directory: 1

    - id: AGT-002
      name: "Agent delegates to skills"
      description: "Agents must not do work directly"
      severity: critical
      check:
        type: content_pattern
        pattern: "(Skill:|@skill-)"
        must_match: true
      anti_check:
        type: content_pattern
        pattern: "^\\s*Bash:"
        must_not_match: true
      remediation: "Create skills for work, invoke from agent"

  skills:
    - id: SKL-001
      name: "Director is skill not agent"
      description: "Director/coordinator components must be skills"
      severity: critical
      check:
        type: location
        pattern: "*director*"
        must_be_in: "skills/"
        must_not_be_in: "agents/"

    - id: SKL-002
      name: "Scripts externalized"
      description: "Bash logic should be in scripts/ not inline"
      severity: warning
      check:
        type: directory_structure
        requires: "scripts/"
      anti_check:
        type: content_pattern
        pattern: "```(bash|sh)\\n[^`]{100,}"
        must_not_match: true
      remediation: "Move bash code to scripts/*.sh, reference from SKILL.md"

    - id: SKL-003
      name: "Builder updates docs"
      description: "Builder/engineer skills must update documentation"
      severity: warning
      check:
        type: content_pattern
        applies_to: "*builder*|*engineer*"
        pattern: "(fractary-docs|documentation|docs-manager)"
        must_match: true
```

### Output Location

Reports go to `/logs/audits/` with timestamps:

```
logs/
└── audits/
    ├── 2025-12-02T143000-faber-agent-best-practices.md
    ├── 2025-12-02T143000-faber-agent-best-practices.json
    ├── 2025-12-15T091500-faber-agent-best-practices.md
    └── 2025-12-15T091500-faber-agent-best-practices.json
```

This allows:
- Running audits multiple times as project evolves
- Comparing compliance scores over time
- Tracking remediation progress

## Implementation Plan

### Phase 1: Enhanced Report Template
Update report generation to produce actionable format

**Tasks**:
- [ ] Create new report template with "Current vs Should Be" format
- [ ] Add component-by-component analysis section
- [ ] Add specific code snippets for findings
- [ ] Add proposed change snippets

### Phase 2: Best Practices Rules Engine
Formalize rules as structured data

**Tasks**:
- [ ] Create `best-practices-rules.yaml` with all rules
- [ ] Update `project-analyzer` skill to use rules file
- [ ] Add rule version tracking
- [ ] Include rule reference in report

### Phase 3: Remediation Plan Generator
Generate actionable checklist

**Tasks**:
- [ ] Group findings by priority
- [ ] Calculate effort estimates
- [ ] Generate checkbox-style task list
- [ ] Link tasks to specific files/lines

### Phase 4: Output to /logs/
Update output path and format

**Tasks**:
- [ ] Change default output to `/logs/audits/{timestamp}-faber-agent-best-practices.md`
- [ ] Add compliance score calculation
- [ ] Ensure JSON output matches markdown structure
- [ ] Add report metadata (auditor version, rules version)

## Files to Modify

### Modified Files

- `plugins/faber-agent/agents/project-auditor.md`: Update Phase 7 (Report) to use new template
- `plugins/faber-agent/skills/project-analyzer/SKILL.md`: Add rules-based checking
- `plugins/faber-agent/templates/reports/best-practices-audit.md.template`: New actionable format

### New Files

- `plugins/faber-agent/config/best-practices-rules.yaml`: Formalized rules
- `plugins/faber-agent/skills/remediation-planner/SKILL.md`: Generate prioritized plan

## Testing Strategy

### Integration Tests
- Run audit on `claude-plugins` repository itself
- Verify findings match known patterns
- Confirm remediation suggestions are valid

### Cross-Project Tests
- Run audit on external project with intentional issues
- Verify audit works from different directory
- Confirm report saves to correct location

### Regression Tests
- Ensure existing anti-pattern detection still works
- Verify 7-phase workflow unchanged
- Confirm JSON output format compatibility

## Dependencies

- Existing faber-agent plugin structure (no new dependencies)
- Best practices documentation (docs/BEST-PRACTICES.md) - for rule derivation
- Pattern documentation (docs/patterns/*.md) - for rule derivation

## Risks and Mitigations

- **Risk**: Rules become outdated as best practices evolve
  - **Likelihood**: Medium
  - **Impact**: Low
  - **Mitigation**: Rules in single YAML file with version; easy to update

- **Risk**: False positives from pattern matching
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Conservative patterns; show evidence in report for user judgment

- **Risk**: Report too verbose for large projects
  - **Likelihood**: Low
  - **Impact**: Low
  - **Mitigation**: Summary section at top; collapsible sections in detailed view

## Success Metrics

- User can take audit report and execute remediation without additional research
- Compliance score tracks progress over multiple audit runs
- Cross-project audits work without special setup
- Findings include specific "what to change" proposals

## Implementation Notes

This enhancement focuses on **improving the existing audit**, not creating new infrastructure. The core changes are:

1. **Report format**: From abstract findings to specific "Current vs Should Be" comparisons
2. **Rules engine**: From hardcoded detection to structured rules file
3. **Remediation plan**: From generic suggestions to file-level task checklist
4. **Output location**: From console/custom to `/logs/audits/{timestamp}-faber-agent-best-practices.[md|json]`

The existing 7-phase workflow in `project-auditor` remains unchanged - we're enhancing Phase 7 (Report) output quality.
