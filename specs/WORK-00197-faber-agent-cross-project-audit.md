---
spec_id: WORK-00197-faber-agent-cross-project-audit
work_id: 197
issue_url: https://github.com/fractary/claude-plugins/issues/197
title: Better way to leverage faber-agent best practices
type: feature
status: draft
created: 2025-12-02
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: Better way to leverage faber-agent best practices

**Issue**: [#197](https://github.com/fractary/claude-plugins/issues/197)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-02

## Summary

Enable the faber-agent plugin to audit and analyze custom Claude Code components (commands, agents, skills, hooks) in any project, compare them against current best practices, identify gaps, and generate actionable remediation plans - all without requiring direct access to the plugin's internal documentation files.

## Background

The faber-agent plugin contains robust documentation and standards for creating quality agents, including:
- Director/Agent/Workflow skills agentic architecture patterns
- `/{project}-direct` command pattern with `--action` argument
- Director as Skill (not Agent) for parallel execution
- Manager as the only Agent per project
- Skills for all workflow steps
- Builder skill documentation requirements
- Debugger skill knowledge base pattern
- Required plugin integrations (fractary-docs, fractary-specs, fractary-logs, etc.)

Issue #194 enhanced these best practices further. However, when working in another project:
1. The docs are part of the faber-agent plugin and not directly referenceable
2. Users must hack references to the claude root user plugins directory (not ideal)
3. There's no clear way to audit the current state of custom Claude components
4. No automated way to generate improvement recommendations

## User Stories

### Cross-Project Audit
**As a** Claude Code user working on a project with custom agents/skills
**I want** to audit my project's Claude components against best practices
**So that** I can identify gaps and create a plan to improve them

**Acceptance Criteria**:
- [ ] Can run audit from any project directory
- [ ] Audit discovers all custom commands, agents, skills, hooks in `.claude/`
- [ ] Audit compares each component against best practices
- [ ] Audit generates report with findings and recommendations

### Remediation Planning
**As a** Claude Code user with identified gaps
**I want** to generate a prioritized remediation plan
**So that** I can systematically bring my components into alignment

**Acceptance Criteria**:
- [ ] Plan includes specific tasks for each gap
- [ ] Tasks are ordered by priority/dependency
- [ ] Plan can be exported as GitHub issues or work items

### Best Practices Access
**As a** Claude Code user
**I want** to access current best practices without navigating plugin internals
**So that** I can understand what "good" looks like before building

**Acceptance Criteria**:
- [ ] Best practices accessible via command or skill
- [ ] Content dynamically loaded from plugin (stays up-to-date)
- [ ] Examples included for each pattern

## Functional Requirements

- **FR1**: Audit command that scans `.claude/` directory for custom components
- **FR2**: Component classifier that identifies type (command, agent, skill, hook)
- **FR3**: Pattern matcher that compares components against best practices rules
- **FR4**: Gap analyzer that identifies deviations from best practices
- **FR5**: Recommendation generator that suggests specific fixes
- **FR6**: Remediation planner that creates prioritized task list
- **FR7**: Best practices retriever that exposes documentation via command/skill

## Non-Functional Requirements

- **NFR1**: Audit should complete in < 30 seconds for typical project (performance)
- **NFR2**: Audit should work offline (cached best practices) (reliability)
- **NFR3**: No modification of audited files without explicit user action (safety)
- **NFR4**: Clear, actionable output format (usability)

## Technical Design

### Architecture Approach

Two potential approaches:

#### Option A: Direct Plugin Access (Simpler)
- faber-agent plugin exposes audit commands that work cross-project
- Commands read `.claude/` from current working directory
- Best practices rules embedded in plugin skills
- Audit results returned to user

```
User Project                     faber-agent Plugin
.claude/
├── commands/        ─────────►  /faber-agent:audit
├── agents/                      └── project-auditor agent
├── skills/                          ├── component-scanner skill
└── hooks/                           ├── pattern-matcher skill
                                     ├── gap-analyzer skill
                                     └── report-generator skill
```

#### Option B: Codex Integration (More Complex, Better Long-term)
- Best practices stored in Codex knowledge base
- faber-agent plugin fetches from Codex at audit time
- Enables versioning and cross-org standardization
- Requires Codex plugin configured

### Recommended: Option A (Direct Plugin Access)

Reasons:
1. Simpler implementation
2. No additional dependencies (Codex)
3. Plugin already installed = access to best practices
4. Can evolve to Option B later if needed

### Component Detection

Scan current project's `.claude/` directory:

```
.claude/
├── commands/*.md          → Command components
├── agents/*.md            → Agent components
├── skills/*/SKILL.md      → Skill components
├── skills/*/scripts/      → Skill scripts
├── hooks/hooks.json       → Hook definitions
└── settings.json          → Project settings
```

### Best Practices Rules Engine

Rules defined in plugin:

```yaml
rules:
  command:
    - id: CMD-001
      name: "Command routes to agent"
      check: "Contains 'MUST' invoke agent"
      severity: error
    - id: CMD-002
      name: "No direct work in command"
      check: "No Bash/Read/Write tool usage"
      severity: error

  agent:
    - id: AGT-001
      name: "Single manager agent"
      check: "Only one *-manager agent per domain"
      severity: warning
    - id: AGT-002
      name: "Agent delegates to skills"
      check: "Contains Skill invocations"
      severity: error

  skill:
    - id: SKL-001
      name: "Director is skill not agent"
      check: "Director components in skills/ not agents/"
      severity: error
    - id: SKL-002
      name: "Scripts in scripts/ directory"
      check: "Bash logic in scripts/ not inline"
      severity: warning
    - id: SKL-003
      name: "Builder updates documentation"
      check: "Builder skill references fractary-docs"
      severity: warning
```

### Audit Report Format

```markdown
# Claude Components Audit Report

**Project**: /path/to/project
**Date**: 2025-12-02
**Components Scanned**: 15
**Issues Found**: 7

## Summary

| Category | Count | Errors | Warnings |
|----------|-------|--------|----------|
| Commands | 3     | 1      | 0        |
| Agents   | 2     | 0      | 1        |
| Skills   | 8     | 2      | 2        |
| Hooks    | 2     | 0      | 1        |

## Findings

### Errors (Must Fix)

#### CMD-001: Command doing direct work
- **File**: `.claude/commands/deploy.md`
- **Issue**: Command executes Bash directly instead of invoking agent
- **Fix**: Route to deploy-manager agent

#### SKL-001: Director implemented as agent
- **File**: `.claude/agents/batch-director.md`
- **Issue**: Director should be a skill to enable parallel execution
- **Fix**: Move to `.claude/skills/batch-director/SKILL.md`

### Warnings (Should Fix)

#### AGT-002: Multiple manager agents
- **Files**: `api-manager.md`, `data-manager.md`, `file-manager.md`
- **Issue**: Consider consolidating to single domain manager
- **Suggestion**: Review if domains are truly separate

## Remediation Plan

### Priority 1: Critical Fixes
1. [ ] Convert `batch-director` from agent to skill
2. [ ] Refactor `deploy.md` command to route to agent

### Priority 2: Improvements
3. [ ] Extract inline Bash from `processor` skill to scripts/
4. [ ] Add documentation update to builder skill
5. [ ] Review manager agent consolidation
```

## Implementation Plan

### Phase 1: Component Scanner
Build skill to scan `.claude/` and identify all components

**Tasks**:
- [ ] Create `component-scanner` skill
- [ ] Implement file discovery for commands, agents, skills, hooks
- [ ] Parse component metadata (frontmatter, structure)
- [ ] Return structured component inventory

### Phase 2: Rules Engine
Implement best practices rules and pattern matching

**Tasks**:
- [ ] Define rules YAML/JSON format
- [ ] Create `pattern-matcher` skill
- [ ] Implement rule evaluation logic
- [ ] Support regex and structural checks

### Phase 3: Gap Analyzer
Compare components against rules and identify gaps

**Tasks**:
- [ ] Create `gap-analyzer` skill
- [ ] Implement comparison logic
- [ ] Generate findings with severity levels
- [ ] Include fix suggestions

### Phase 4: Report Generator
Generate human-readable audit reports

**Tasks**:
- [ ] Create `report-generator` skill
- [ ] Implement markdown report template
- [ ] Generate remediation plan section
- [ ] Support JSON output for tooling

### Phase 5: Command Integration
Expose via user-facing commands

**Tasks**:
- [ ] Create `/faber-agent:audit` command
- [ ] Create `/faber-agent:best-practices` command (show patterns)
- [ ] Add `--fix` flag for auto-remediation (future)
- [ ] Update plugin documentation

## Files to Create/Modify

### New Files

- `plugins/faber-agent/skills/component-scanner/SKILL.md`: Scan project components
- `plugins/faber-agent/skills/component-scanner/scripts/scan-project.sh`: Discovery script
- `plugins/faber-agent/skills/pattern-matcher/SKILL.md`: Match against rules
- `plugins/faber-agent/skills/gap-analyzer/SKILL.md`: Identify gaps
- `plugins/faber-agent/skills/report-generator/SKILL.md`: Generate reports
- `plugins/faber-agent/skills/report-generator/templates/audit-report.md.template`: Report template
- `plugins/faber-agent/config/best-practices-rules.yaml`: Rules definitions
- `plugins/faber-agent/commands/audit.md`: Audit command
- `plugins/faber-agent/commands/best-practices.md`: Best practices viewer

### Modified Files

- `plugins/faber-agent/agents/project-auditor.md`: Enhance with new skills
- `plugins/faber-agent/.claude-plugin/plugin.json`: Register new commands
- `plugins/faber-agent/README.md`: Document new capabilities

## Testing Strategy

### Unit Tests
- Test component scanner with mock `.claude/` structures
- Test rule evaluation with sample components
- Test report generation with known findings

### Integration Tests
- Run audit on `claude-plugins` repository itself
- Verify all findings are valid
- Confirm report format is correct

### E2E Tests
- Create test project with intentional issues
- Run full audit workflow
- Verify remediation suggestions are actionable

## Dependencies

- Existing faber-agent plugin structure
- Best practices documentation (docs/BEST-PRACTICES.md)
- Pattern documentation (docs/patterns/*.md)

## Risks and Mitigations

- **Risk**: Rules become outdated as best practices evolve
  - **Likelihood**: Medium
  - **Impact**: Low
  - **Mitigation**: Rules in single config file, easy to update; version rules

- **Risk**: False positives in pattern matching
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Conservative severity levels; allow rule suppression

- **Risk**: Audit performance on large projects
  - **Likelihood**: Low
  - **Impact**: Low
  - **Mitigation**: Lazy loading; optional depth limits

## Documentation Updates

- `plugins/faber-agent/README.md`: Add audit and best-practices commands
- `plugins/faber-agent/docs/BEST-PRACTICES.md`: Reference audit capability
- `plugins/faber-agent/docs/guides/audit-usage-guide.md`: Detailed usage guide

## Success Metrics

- Users can audit any project in < 30 seconds
- Audit findings are actionable (> 80% lead to clear fix)
- Cross-project usage increases (tracked via opt-in telemetry if available)
- Reduction in pattern violations in new plugins

## Implementation Notes

This feature extends the existing faber-agent audit capabilities (which currently focus on anti-pattern detection within the plugin itself) to work across any project. The key insight is that the plugin is already installed globally and can access any project's `.claude/` directory - we just need to expose this capability through user-facing commands.

The `/faber-agent:audit` command will become the single entry point for analyzing Claude components, whether in the claude-plugins repo or any other project.
