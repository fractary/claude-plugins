---
spec_id: WORK-00158-review-faber-workflow-config
work_id: 158
issue_url: https://github.com/fractary/claude-plugins/issues/158
title: Review faber workflow configuration / definition ability
type: feature
status: draft
created: 2025-11-19
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: Review faber workflow configuration / definition ability

**Issue**: [#158](https://github.com/fractary/claude-plugins/issues/158)
**Type**: Feature Enhancement
**Status**: Draft
**Created**: 2025-11-19

## Summary

Review and finalize the FABER workflow configuration and definition capabilities to enable project-specific workflow customization, comprehensive workflow documentation, and reliable automated execution. This work will establish a universal framework for documenting workflows across all FABER plugin types (general, faber-cloud, faber-app, etc.) and enable GitHub-based workflow control through issue mentions.

The goal is to transform the FABER workflow system from a basic scaffolding tool into a fully-featured workflow orchestration platform with:
1. Standardized workflow documentation for easy reference across projects
2. Reliable automated workflow execution with proper checks and balances
3. GitHub issue management as a universal control plane via @fractary/@faber mentions

## User Stories

### Story 1: Workflow Documentation Reference
**As a** developer working across multiple projects
**I want** a consistent place to view each project's workflow steps and conventions
**So that** I don't forget project-specific requirements and can onboard quickly

**Acceptance Criteria**:
- [ ] Workflow configuration stored in standard location (`.faber.config.toml` or similar)
- [ ] Configuration includes all workflow phases and custom steps
- [ ] Configuration is human-readable and self-documenting
- [ ] Configuration format is consistent across all FABER plugin types

### Story 2: Automated Workflow Execution
**As a** developer using FABER workflows
**I want** to reliably execute complete workflows from start to finish
**So that** I have confidence all proper checks, documentation, and steps are completed

**Acceptance Criteria**:
- [ ] Director and manager agents read from workflow configuration
- [ ] Workflows execute in proper phase order (Frame → Architect → Build → Evaluate → Release)
- [ ] Required checks and validations are enforced at each phase
- [ ] Workflow state is tracked and reportable
- [ ] Error handling and recovery mechanisms are in place

### Story 3: GitHub-Based Workflow Control
**As a** project maintainer
**I want** to trigger and control workflows via GitHub issue comments (e.g., @fractary, @faber)
**So that** GitHub issues become my universal control plane for all projects

**Acceptance Criteria**:
- [ ] GitHub app/integration responds to @fractary or @faber mentions
- [ ] Natural language commands are parsed and mapped to workflow operations
- [ ] Workflow execution status is reported back to the issue
- [ ] Approval prompts are handled through GitHub comments
- [ ] Integration works across all repository types

## Functional Requirements

- **FR1**: Support workflow configuration in `.faber.config.toml` or `.fractary/plugins/faber/config.json` with complete phase definitions
- **FR2**: Enable custom workflow step definitions within each phase (Frame, Architect, Build, Evaluate, Release)
- **FR3**: Support hooks system for pre/post phase execution (similar to faber-cloud implementation)
- **FR4**: Provide workflow validation to ensure configuration completeness and correctness
- **FR5**: Enable workflow state tracking and status reporting (`/faber status` command)
- **FR6**: Support workflow initialization command (`/faber init`) that analyzes project and generates baseline configuration
- **FR7**: Provide workflow audit command that assesses project alignment with FABER workflow expectations
- **FR8**: Enable director and manager agents to read and execute based on workflow configuration
- **FR9**: Support workflow customization across all FABER plugin types (general faber, faber-cloud, faber-app, etc.)
- **FR10**: Provide GitHub integration for @fractary/@faber mention-based workflow triggering

## Non-Functional Requirements

- **NFR1**: Configuration format must be backward-compatible with existing FABER v2.0 architecture (maintainability)
- **NFR2**: Workflow execution should maintain context efficiency (target: <50K tokens for full orchestration) (performance)
- **NFR3**: Configuration validation should complete in <1 second (performance)
- **NFR4**: GitHub integration should respond to mentions within 30 seconds (responsiveness)
- **NFR5**: Workflow documentation should be self-explanatory without external references (usability)
- **NFR6**: Configuration format should support comments and documentation inline (usability)

## Technical Design

### Architecture Changes

The current FABER v2.0 architecture uses a single `workflow-manager.md` that orchestrates all 5 phases. This work will enhance that architecture with:

1. **Configuration-Driven Workflow Execution**:
   - Workflow-manager reads phase definitions from `.faber.config.toml`
   - Each phase can specify custom steps, validation rules, and hooks
   - Skills are selected based on configuration (e.g., `workflow.skills.architect = "cloud"`)

2. **Enhanced Director Agent**:
   - Director parses user commands and workflow requests
   - Routes to workflow-manager with configuration context
   - Handles GitHub mention parsing (@fractary, @faber)

3. **Workflow State Management**:
   - Track current phase and step
   - Maintain execution history
   - Enable resume/retry capabilities
   - Store state in `.fractary/plugins/faber/state.json`

4. **Hooks System Integration**:
   - Pre-phase hooks: Execute before phase starts
   - Post-phase hooks: Execute after phase completes
   - Hook types: script, skill, or document (context injection)
   - Configuration format:
     ```toml
     [workflow.hooks]
     pre_architect = ["script:./hooks/prepare-arch.sh", "skill:context-loader"]
     post_build = ["skill:code-review", "script:./hooks/quality-check.sh"]
     ```

### Data Model

**Workflow Configuration Schema** (`.faber.config.toml`):

```toml
[workflow]
version = "2.0"
name = "project-name"
type = "software" # or "infrastructure", "application", etc.

[workflow.skills]
frame = "basic"        # Skill workflow to use for Frame phase
architect = "basic"    # Skill workflow to use for Architect phase
build = "basic"        # Skill workflow to use for Build phase
evaluate = "basic"     # Skill workflow to use for Evaluate phase
release = "basic"      # Skill workflow to use for Release phase

[workflow.phases.frame]
enabled = true
steps = ["fetch-work", "classify", "setup-env"]
validation = ["work-item-exists", "branch-created"]

[workflow.phases.architect]
enabled = true
generate_spec = true
spec_plugin = "fractary-spec"
spec_command = "create"
validation = ["spec-created", "spec-reviewed"]

[workflow.phases.build]
enabled = true
steps = ["implement", "commit"]
validation = ["tests-pass", "code-reviewed"]

[workflow.phases.evaluate]
enabled = true
max_retries = 3
steps = ["test", "review", "fix"]
validation = ["all-tests-pass", "review-approved"]

[workflow.phases.release]
enabled = true
steps = ["create-pr", "deploy", "document"]
require_approval = true
validation = ["pr-created", "ci-pass"]

[workflow.hooks]
pre_architect = []
post_architect = []
pre_build = []
post_build = []
pre_release = ["skill:final-review"]

[workflow.autonomy]
level = "guarded"  # dry-run, assist, guarded, autonomous
pause_before_release = true
require_approval_for = ["deploy", "merge-pr"]
```

**Workflow State Schema** (`.fractary/plugins/faber/state.json`):

```json
{
  "work_id": "158",
  "workflow_version": "2.0",
  "current_phase": "architect",
  "current_step": "generate-spec",
  "status": "in_progress",
  "started_at": "2025-11-19T10:00:00Z",
  "phases": {
    "frame": {
      "status": "completed",
      "completed_at": "2025-11-19T10:05:00Z",
      "artifacts": ["branch: feat/158-review-faber-workflow-config"]
    },
    "architect": {
      "status": "in_progress",
      "started_at": "2025-11-19T10:05:00Z",
      "artifacts": []
    }
  },
  "errors": [],
  "retries": 0
}
```

### Workflow Commands

Enhanced command set:

- `/faber init [--template <type>] [--analyze]` - Initialize workflow configuration
  - Analyzes project structure if --analyze flag provided
  - Creates `.faber.config.toml` from template
  - Detects project type (software, infrastructure, etc.)

- `/faber audit` - Audit project workflow alignment
  - Checks for required configuration files
  - Validates workflow configuration completeness
  - Reports missing integrations (work, repo, spec plugins)
  - Suggests improvements

- `/faber status [work-id]` - Show workflow status
  - Display current phase and progress
  - Show completed phases and artifacts
  - List pending approvals
  - Report any errors or blockers

- `/faber run <work-id> [--autonomy <level>] [--from <phase>]` - Execute workflow
  - `--autonomy`: dry-run, assist, guarded, autonomous
  - `--from`: Resume from specific phase (frame, architect, build, evaluate, release)

### GitHub Integration Design

**GitHub App/Integration**:
1. Listen for issue comments containing @fractary or @faber mentions
2. Parse natural language command (e.g., "@faber implement this feature")
3. Map to workflow operation (e.g., `/faber run 158 --autonomy guarded`)
4. Execute workflow with project-specific configuration
5. Report progress back to issue via comments
6. Handle approval requests via issue comments (👍 reaction or "approve" comment)

**Example Interaction**:
```
User: @faber please implement this feature
Bot: 🤖 Starting FABER workflow for issue #158
     Phase: Frame ✓ Complete
     Phase: Architect ✓ Spec created
     Phase: Build ⏳ In progress...

User: @faber status
Bot: 📊 Workflow Status for #158
     Current: Build (Step 2/3 - committing changes)
     Completed: Frame ✓, Architect ✓
     Pending: Evaluate, Release

User: @faber pause
Bot: ⏸️ Workflow paused at Build phase
     Use "@faber resume" to continue
```

## Implementation Plan

### Phase 1: Configuration Framework
Review and finalize the configuration schema and loading mechanism

**Tasks**:
- [ ] Review existing `.faber.config.toml` schema in `plugins/faber/config/`
- [ ] Validate schema covers all workflow customization needs
- [ ] Implement configuration validation logic
- [ ] Add support for hooks configuration
- [ ] Document configuration format with examples
- [ ] Create configuration templates for different project types

### Phase 2: Workflow State Management
Implement workflow state tracking and persistence

**Tasks**:
- [ ] Design state schema (JSON format)
- [ ] Implement state persistence to `.fractary/plugins/faber/state.json`
- [ ] Add state read/write functions to workflow-manager
- [ ] Implement phase transition tracking
- [ ] Add error and retry tracking
- [ ] Create `/faber status` command to read and display state

### Phase 3: Enhanced Director and Manager
Update director and workflow-manager to use configuration

**Tasks**:
- [ ] Modify director to load and pass configuration to workflow-manager
- [ ] Update workflow-manager to read phase definitions from config
- [ ] Implement hooks execution in workflow-manager
- [ ] Add validation enforcement based on config
- [ ] Implement autonomy level handling (dry-run, assist, guarded, autonomous)
- [ ] Add approval prompt logic for release phase

### Phase 4: Initialization and Audit Commands
Create tools to set up and validate workflow integration

**Tasks**:
- [ ] Implement `/faber init` command with project analysis
- [ ] Create project type detection logic
- [ ] Generate configuration from templates based on detected type
- [ ] Implement `/faber audit` command
- [ ] Add configuration completeness checks
- [ ] Add plugin integration checks (work, repo, spec)
- [ ] Create suggestions for improvements

### Phase 5: Testing and Documentation
Validate the framework works across FABER plugin types

**Tasks**:
- [ ] Test with general faber plugin
- [ ] Test with faber-cloud plugin
- [ ] Test with faber-app plugin (if available)
- [ ] Create comprehensive documentation
- [ ] Update CLAUDE.md with configuration guidance
- [ ] Create tutorial for new projects
- [ ] Document hooks system

### Phase 6: GitHub Integration (Future)
Implement GitHub app for mention-based control

**Tasks**:
- [ ] Design GitHub app architecture
- [ ] Implement webhook listener for issue comments
- [ ] Create natural language command parser
- [ ] Build workflow execution bridge
- [ ] Implement progress reporting to issues
- [ ] Add approval handling via reactions/comments
- [ ] Deploy and configure GitHub app
- [ ] Document GitHub integration usage

## Files to Create/Modify

### New Files
- `.fractary/plugins/faber/state.json`: Workflow execution state (generated at runtime)
- `plugins/faber/skills/config-validator/`: Configuration validation skill
- `plugins/faber/skills/project-analyzer/`: Project analysis skill (for `/faber init`)
- `plugins/faber/skills/workflow-auditor/`: Workflow audit skill (for `/faber audit`)
- `plugins/faber/commands/audit.md`: Audit command implementation
- `plugins/faber/docs/CONFIGURATION.md`: Comprehensive configuration documentation
- `plugins/faber/docs/HOOKS.md`: Hooks system documentation
- `plugins/faber/config/templates/`: Configuration templates for different project types

### Modified Files
- `plugins/faber/agents/director.md`: Enhanced to handle `/faber init`, `/faber audit`, and future GitHub mentions
- `plugins/faber/agents/workflow-manager.md`: Enhanced to read configuration and execute hooks
- `plugins/faber/commands/init.md`: Enhanced with project analysis capabilities
- `plugins/faber/commands/run.md`: Enhanced with autonomy level handling
- `plugins/faber/commands/status.md`: Enhanced to read and display workflow state
- `plugins/faber/config/faber.example.toml`: Updated with all new configuration options
- `CLAUDE.md`: Updated with workflow configuration guidance
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`: Document workflow configuration patterns

## Testing Strategy

### Unit Tests
- Configuration schema validation
- State persistence and retrieval
- Hooks execution logic
- Command argument parsing
- Project type detection

### Integration Tests
- Full workflow execution with custom configuration
- Hooks triggering at correct phases
- State updates throughout workflow
- `/faber init` generating valid configuration
- `/faber audit` detecting misconfigurations
- Workflow resume from saved state

### End-to-End Tests
- Complete workflow from issue #158
- Test across multiple FABER plugin types (general, cloud, app)
- Test with different autonomy levels
- Test workflow interruption and resume
- Test approval prompts and handling
- Validate all artifacts created correctly

### Manual Testing
- Real-world project workflow setup
- Configuration customization for specific needs
- Hooks integration with custom scripts
- Multi-project workflow management
- GitHub integration (when implemented)

## Dependencies

**Existing Plugin Dependencies**:
- `fractary-work`: Work item management (fetch, update, comment)
- `fractary-repo`: Source control operations (branch, commit, PR)
- `fractary-spec`: Specification generation (architect phase)
- `fractary-file`: File storage (if using cloud archival)

**External Dependencies**:
- None for core functionality
- GitHub API/App (for future GitHub integration phase)

**Configuration Files**:
- `.faber.config.toml`: Project-specific workflow configuration
- `.fractary/plugins/faber/config.json`: Plugin-level settings
- `.fractary/plugins/faber/state.json`: Runtime workflow state

## Risks and Mitigations

- **Risk**: Configuration format becomes too complex for users to manage
  - **Likelihood**: Medium
  - **Impact**: High (reduces adoption)
  - **Mitigation**: Provide good defaults, comprehensive documentation, and `/faber init` to generate configurations. Support multiple complexity levels (simple → advanced).

- **Risk**: Workflow state corruption leads to inability to resume workflows
  - **Likelihood**: Low
  - **Impact**: High (workflow failures)
  - **Mitigation**: Implement state validation on load, maintain state backups, provide recovery commands

- **Risk**: Hooks system allows unsafe or malicious code execution
  - **Likelihood**: Low
  - **Impact**: High (security)
  - **Mitigation**: Document security best practices, validate hook paths, consider sandboxing for script execution

- **Risk**: Backward compatibility breaks existing FABER workflows
  - **Likelihood**: Medium
  - **Impact**: High (disrupts current users)
  - **Mitigation**: Maintain v2.0 compatibility, use gradual rollout, provide migration guide, support fallback to defaults

- **Risk**: GitHub integration becomes maintenance burden
  - **Likelihood**: Medium
  - **Impact**: Medium (technical debt)
  - **Mitigation**: Keep GitHub integration as separate phase, ensure core functionality works without it, use well-documented GitHub APIs

## Documentation Updates

- `plugins/faber/README.md`: Update with new commands and workflow customization capabilities
- `plugins/faber/docs/CONFIGURATION.md`: Comprehensive guide to workflow configuration (new file)
- `plugins/faber/docs/HOOKS.md`: Hooks system documentation (new file)
- `plugins/faber/docs/MIGRATION-v2.md`: Update with v2.x → v2.x migration guidance
- `CLAUDE.md`: Add section on FABER workflow configuration
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`: Document workflow configuration patterns for plugin authors

## Rollout Plan

### Stage 1: Configuration and State (Low Risk)
- Release configuration validation and state management
- Enable `/faber status` command
- No changes to existing workflow execution
- Users can start adding configurations without impact

### Stage 2: Enhanced Workflow Execution (Medium Risk)
- Release configuration-driven workflow execution
- Enable hooks system
- Release enhanced `/faber init` and new `/faber audit` commands
- Existing workflows continue to work (defaults used if no config)
- Power users can customize workflows

### Stage 3: Testing and Refinement (Low Risk)
- Gather feedback from real-world usage
- Refine configuration schema based on feedback
- Improve documentation and examples
- Fix bugs and edge cases

### Stage 4: GitHub Integration (Future, High Value)
- Implement GitHub app/integration
- Beta test with select projects
- Full release once stable
- This is optional - core functionality is complete without it

## Success Metrics

- **Configuration Adoption**: 80% of active FABER projects have `.faber.config.toml` within 3 months
- **Workflow Reliability**: 95% of workflows complete without manual intervention (for autonomy level "guarded" or higher)
- **Time Savings**: 50% reduction in time spent on workflow step lookup/documentation
- **GitHub Control Plane**: 70% of workflow initiations happen via GitHub mentions (post-integration)
- **Documentation Quality**: Zero questions about workflow configuration in community channels after reading docs
- **Audit Pass Rate**: 90% of projects pass `/faber audit` after initial configuration

## Implementation Notes

### Existing Work to Review

The issue mentions that "some initial work was done to scaffold this ability into the Faber plugin." Priority tasks:

1. Review `plugins/faber/config/faber.example.toml` for existing configuration structure
2. Check if hooks system is already implemented in faber-cloud and needs porting
3. Identify any existing workflow validation or audit logic
4. Review director and workflow-manager for configuration integration points
5. Check for existing state management or tracking mechanisms

### Design Philosophy

This enhancement should maintain the FABER architecture principles:
- **Context efficiency**: Configuration should reduce context, not increase it
- **Defense in depth**: Critical rules enforced at multiple levels
- **Provider agnostic**: Configuration format works across all FABER types
- **Graceful degradation**: Missing configuration uses sensible defaults
- **Documentation as code**: Configuration file is self-documenting

### Integration with Existing Plugins

The workflow configuration should seamlessly integrate with:
- **fractary-work**: Use for work item operations in Frame phase
- **fractary-repo**: Use for branch/commit/PR operations throughout
- **fractary-spec**: Use for specification generation in Architect phase
- **fractary-file**: Use for artifact storage if configured

Configuration should allow specifying which plugins to use and how to invoke them.

### Future Extensibility

Design the configuration system to support future enhancements:
- Custom phase definitions (beyond the 5 standard phases)
- Conditional workflow paths based on work type
- Parallel phase execution where appropriate
- Workflow templates/presets for common scenarios
- Integration with additional work/repo/spec plugins
