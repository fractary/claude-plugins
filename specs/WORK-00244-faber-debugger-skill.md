---
spec_id: WORK-00244-faber-debugger-skill
issue_number: 244
issue_url: https://github.com/fractary/claude-plugins/issues/244
title: Consider faber universal debugger skill
type: feature
status: draft
created: 2025-12-05
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: Universal Debugger Skill for FABER Framework

**Issue**: [#244](https://github.com/fractary/claude-plugins/issues/244)
**Type**: Feature/Enhancement
**Status**: Draft
**Created**: 2025-12-05

## Summary

Implement a universal debugger skill as a core component of the FABER framework that can diagnose issues identified by other skills and propose solutions while maintaining a persistent troubleshooting knowledge base. This skill should integrate into any FABER workflow to automatically identify and address problems, learning from past solutions to avoid reinventing wheels and improving future issue resolution times.

## Motivation

Currently, individual projects and workflows implement their own debugging/troubleshooting skills with similar patterns but different implementations. The core process of:
1. Accepting problems/issues to troubleshoot
2. Referencing a historical troubleshooting knowledge base
3. Proposing solutions

This pattern is consistent across all projects regardless of domain, technology stack, or project type. Consolidating this into a single, reusable FABER core skill eliminates duplication and creates institutional knowledge that benefits all projects.

## User Stories

### As a Workflow Developer
**I want** to integrate debugging capabilities into any FABER workflow
**So that** I can automatically diagnose and propose solutions for issues without reimplementing the logic

**Acceptance Criteria**:
- [ ] Debugger skill can be added to any FABER workflow configuration
- [ ] Skill can operate in two modes: targeted debugging and automatic error detection
- [ ] Configuration is simple and non-intrusive
- [ ] Workflow template includes the debugger at strategic points

### As a Project Maintainer
**I want** a persistent troubleshooting knowledge base that learns from past issues
**So that** future occurrences of the same issue are resolved faster and consistently

**Acceptance Criteria**:
- [ ] Troubleshooting log is stored in `.fractary/plugins/faber/debugger/` in source control
- [ ] Knowledge base accumulates over time without manual pruning
- [ ] Debugger can search and reference past solutions by similarity
- [ ] Contributors can audit and improve solutions in the knowledge base

### As a Workflow Orchestrator
**I want** the debugger to automatically detect and aggregate warnings/errors from workflow steps
**So that** I can propose fixes without explicit configuration

**Acceptance Criteria**:
- [ ] Debugger can parse warnings and errors from previous workflow steps
- [ ] Automatically proposes solutions without requiring a specific problem input
- [ ] Creates specifications for complex issues
- [ ] Logs findings to both terminal/Claude session and GitHub issue

## Functional Requirements

- **FR1**: Accept diagnosed problems as input (explicit or inferred from workflow errors)
- **FR2**: Maintain a persistent troubleshooting knowledge base in `.fractary/plugins/faber/debugger/`
- **FR3**: Search knowledge base for similar past issues and solutions
- **FR4**: Parse and aggregate warnings/errors from all previous workflow steps
- **FR5**: Propose solutions based on knowledge base and current context
- **FR6**: Create specifications for complex multi-step solutions (using fractary-spec)
- **FR7**: Log findings to GitHub issue with permanent record
- **FR8**: Generate next-step commands in `/faber:run` format for workflow continuation
- **FR9**: Support conditional execution based on workflow results
- **FR10**: Integrate with FABER workflow phases (pre/post hooks)

## Non-Functional Requirements

- **NFR1**: Execution performance: Debugger should complete within 2-3 minutes for typical issues
- **NFR2**: Knowledge base size: Should efficiently handle 100+ troubleshooting entries
- **NFR3**: Reliability: Gracefully degrade if knowledge base is unavailable
- **NFR4**: Searchability: Support semantic similarity search for knowledge base queries
- **NFR5**: Auditability: All debugging decisions should be traceable and reviewable

## Technical Design

### Architecture Changes

The debugger skill will be implemented as a core FABER skill with the following structure:

```
plugins/faber/skills/faber-debugger/
├── SKILL.md                          # Skill documentation
├── workflow/
│   ├── diagnose-issue.md            # Main diagnostic workflow
│   ├── search-knowledge-base.md      # Knowledge base search logic
│   ├── parse-workflow-errors.md      # Error aggregation from previous steps
│   └── propose-solution.md           # Solution generation workflow
├── scripts/
│   ├── search-kb.sh                 # Knowledge base search
│   ├── aggregate-errors.sh           # Parse workflow step outputs
│   ├── generate-command.sh           # Create /faber:run command
│   └── log-to-issue.sh              # GitHub issue logging
└── templates/
    └── solution-command.template     # Template for generated commands
```

Knowledge base structure:

```
.fractary/plugins/faber/debugger/
├── config.json                       # Debugger configuration
├── knowledge-base/
│   ├── index.json                   # Searchable index of all entries
│   ├── {category}/
│   │   └── {issue-id}-{slug}.md    # Troubleshooting entry
│   └── {category}/
└── logs/
    └── {date}.log                   # Diagnostic logs
```

### Data Model

**Troubleshooting Entry**:
```yaml
---
kb_id: "faber-debug-001"
category: "workflow-execution"
issue_pattern: "Phase build failed with unknown error"
symptoms:
  - Pattern matching keywords
  - Error message patterns
keywords:
  - "build phase"
  - "error"
  - "step failed"
root_causes:
  - "Dependency missing"
  - "Permission denied"
solutions:
  - title: "Install missing dependency"
    steps:
      - "npm install"
      - "retry build phase"
    faber_command: "/faber:run --work-id {id} --step builder --prompt 'Retry after dependency resolution'"
status: "verified"
created: 2025-12-05
last_used: 2025-12-05
usage_count: 3
references: ["#240", "#241", "#242"]
---

[Detailed diagnostic process and solution walkthrough]
```

### Integration Points

1. **FABER Phase Hooks**: Execute debugger before/after specific phases
2. **Error Aggregation**: Parse step outputs to detect issues
3. **Specification Creation**: Use `fractary-spec:create` with `--force-new` for complex solutions
4. **GitHub Comments**: Log findings with permanent reference
5. **Workflow Continuation**: Generate continuation commands for next steps

### Configuration

**faber.config.toml**:
```toml
[debugger]
enabled = true
knowledge_base_path = ".fractary/plugins/faber/debugger/knowledge-base"

# Auto-detect errors from previous steps
auto_detect_errors = true

# Execute debugger when steps fail
trigger_on_failure = true

# Create specs for complex issues (3+ solutions)
create_specs_for_complex = true

# Log findings to GitHub
log_to_github = true

# Search similarity threshold (0.0-1.0)
similarity_threshold = 0.7
```

## Implementation Plan

### Phase 1: Core Debugger Infrastructure
**Description**: Build the foundational skill structure and knowledge base management

**Tasks**:
- [ ] Create faber-debugger skill structure
- [ ] Implement knowledge base schema and storage
- [ ] Create search/indexing capability
- [ ] Build error aggregation from workflow steps
- [ ] Implement basic solution proposal logic

### Phase 2: Integration and Workflow Support
**Description**: Integrate debugger into FABER workflows and add orchestration

**Tasks**:
- [ ] Add configuration support to FABER manager
- [ ] Implement phase-level hooks (pre/post)
- [ ] Build `/faber:run` command generation
- [ ] Create error parsing from step outputs
- [ ] Add GitHub issue comment functionality

### Phase 3: Knowledge Base and Learning
**Description**: Build knowledge base management and solution creation

**Tasks**:
- [ ] Create Knowledge Base Manager tool
- [ ] Implement similarity search (semantic matching)
- [ ] Add `/faber:debugger:learn` command for manual entry
- [ ] Build knowledge base validation and cleanup
- [ ] Create knowledge base documentation

### Phase 4: Advanced Features
**Description**: Add specification creation and intelligent routing

**Tasks**:
- [ ] Integrate with fractary-spec for complex issues
- [ ] Build intelligent solution ranking
- [ ] Add retry logic and escalation paths
- [ ] Implement confidence scoring for solutions
- [ ] Create solution success tracking

## Files to Create/Modify

### New Files

- `plugins/faber/skills/faber-debugger/SKILL.md`: Skill documentation
- `plugins/faber/skills/faber-debugger/workflow/diagnose-issue.md`: Main workflow
- `plugins/faber/skills/faber-debugger/workflow/search-knowledge-base.md`: KB search
- `plugins/faber/skills/faber-debugger/workflow/parse-workflow-errors.md`: Error parsing
- `plugins/faber/skills/faber-debugger/workflow/propose-solution.md`: Solution proposal
- `plugins/faber/skills/faber-debugger/scripts/search-kb.sh`: Search implementation
- `plugins/faber/skills/faber-debugger/scripts/aggregate-errors.sh`: Error aggregation
- `plugins/faber/skills/faber-debugger/scripts/generate-command.sh`: Command generation
- `plugins/faber/skills/faber-debugger/scripts/log-to-issue.sh`: GitHub logging
- `plugins/faber/agents/faber-manager.md`: Updates for debugger integration
- `plugins/faber/commands/debugger.md`: New debugger command

### Modified Files

- `plugins/faber/skills/faber-manager/workflow/evaluate.md`: Add debugger execution point
- `plugins/faber/docs/HOOKS.md`: Document debugger hooks
- `.faber.config.toml`: Add debugger configuration
- `plugins/faber/presets/*.toml`: Update presets to include debugger

## Testing Strategy

### Unit Tests

- Knowledge base search accuracy (exact and fuzzy matching)
- Error pattern matching against workflow outputs
- Solution command generation format validation
- Knowledge base entry validation and schema compliance

### Integration Tests

- Debugger execution within FABER workflow phases
- GitHub issue comment creation and formatting
- Specification creation for complex issues
- End-to-end problem detection → solution generation

### E2E Tests

- Full workflow execution with debugger enabled
- Knowledge base accumulation over multiple workflow runs
- Recovery from simulated failures using debugger

### Performance Tests

- Knowledge base search performance (100+ entries)
- Debugger execution time (target: <3 minutes)
- Memory usage with large knowledge bases

## Dependencies

- **fractary-repo**: For issue fetching and GitHub operations
- **fractary-spec**: For specification creation (optional, for complex issues)
- **fractary-work**: For issue linking (optional)
- **Node.js**: For similarity search (npm packages: similarity, levenshtein-distance)
- **bash/jq**: For shell script implementation

## Risks and Mitigations

- **Risk**: Knowledge base becomes outdated or contains incorrect solutions
  - **Likelihood**: Medium
  - **Impact**: High (incorrect fixes applied to issues)
  - **Mitigation**: Implement validation workflow, community review process, success tracking, automatic confidence decay

- **Risk**: Debugger performance degrades with large knowledge bases
  - **Likelihood**: Medium
  - **Impact**: Medium (slower workflows)
  - **Mitigation**: Implement incremental indexing, caching layer, knowledge base archival strategy

- **Risk**: False positives in error detection leading to incorrect diagnoses
  - **Likelihood**: High (initially)
  - **Impact**: Medium (wasted time on incorrect solutions)
  - **Mitigation**: Start with high confidence thresholds, manual review step, success tracking

- **Risk**: Adoption friction if debugger is too complex to configure
  - **Likelihood**: Medium
  - **Impact**: Medium (low adoption rate)
  - **Mitigation**: Sensible defaults, documentation, preset configurations

## Documentation Updates

- `docs/guides/debugger-guide.md`: User guide for using debugger skill
- `docs/knowledge-base-management.md`: How to manage and contribute to KB
- `docs/faber-architecture.md`: Update to include debugger in architecture
- `CLAUDE.md`: Document debugger as core FABER capability

## Rollout Plan

**Phase 1 (Weeks 1-2)**: Complete core infrastructure
- Merge PR with foundational skill structure
- Begin manual knowledge base seeding with 5-10 common issues

**Phase 2 (Weeks 3-4)**: Integration testing
- Test in controlled environment with sample workflows
- Gather feedback from internal team

**Phase 3 (Weeks 5-6)**: Limited release
- Enable for projects that opt-in
- Collect real-world usage data

**Phase 4 (Weeks 7-8)**: Full rollout
- Enable in default workflow configurations
- Monitor effectiveness and refine

## Success Metrics

- **Debugger Adoption**: 80%+ of workflows using debugger within 2 months
- **Knowledge Base Utility**: 60%+ of detected issues resolved using KB references
- **Time Savings**: 30% reduction in time to resolve recurring issues
- **Accuracy**: 80%+ of proposed solutions are correct and implemented
- **Community**: 50+ knowledge base entries after 3 months of use

## Implementation Notes

The debugger skill represents a fundamental capability for the FABER framework - the ability to learn from experience and apply that learning to future problems. This should be positioned as a core strength of AI-assisted development rather than a nice-to-have feature.

Key considerations:
- Start simple with exact pattern matching, evolve to semantic similarity
- Make the knowledge base accessible and reviewable (source control)
- Focus on high-impact, recurring issues first
- Build confidence gradually with success tracking
- Consider the debugger as an educational tool for developers, not just a fix tool

The debugger is designed to be **opt-in initially** but should become a **default part of workflows** as confidence grows. This phased approach allows for validation and refinement before widespread adoption.
