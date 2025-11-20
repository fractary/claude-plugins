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
- [ ] Workflow configuration stored in standard location (`.fractary/plugins/faber/config.json`)
- [ ] Configuration includes all 5 FABER phases with sub-steps
- [ ] Configuration is JSON format, self-documenting with comments where possible
- [ ] Configuration format is consistent across all FABER plugin types

### Story 2: Automated Workflow Execution
**As a** developer using FABER workflows
**I want** to reliably execute complete workflows from start to finish
**So that** I have confidence all proper checks, documentation, and steps are completed

**Acceptance Criteria**:
- [ ] Universal faber-manager agent and skill read from workflow configuration
- [ ] Universal faber-director skill handles freeform commands
- [ ] Workflows execute in proper phase order (Frame → Architect → Build → Evaluate → Release)
- [ ] Required checks and validations are enforced at each phase boundary
- [ ] Workflow state tracked via fractary-logs (historical) and state.json (current)
- [ ] Error handling and recovery mechanisms are in place
- [ ] Configuration allows override of manager/director skills if needed

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

- **FR1**: Support workflow configuration in `.fractary/plugins/faber/config.json` (JSON format, following plugin standards)
- **FR2**: Enable multiple sub-steps within each of the 5 FABER phases (Frame, Architect, Build, Evaluate, Release)
- **FR3**: Support hooks system at phase boundaries (pre_frame, post_frame, pre_architect, post_architect, etc.)
- **FR4**: Provide workflow validation to ensure configuration completeness and correctness
- **FR5**: Enable workflow state tracking via fractary-logs plugin (historical) and `.fractary/plugins/faber/state.json` (current)
- **FR6**: Support workflow initialization command (`/fractary-faber:init`) that analyzes project and generates baseline configuration
- **FR7**: Provide workflow audit command (`/fractary-faber:audit`) that assesses project alignment with FABER workflow
- **FR8**: Create universal faber-manager agent and skill that work across all FABER projects
- **FR9**: Create universal faber-director skill that parses freeform commands and can parallelize workflows
- **FR10**: Support per-phase execution commands (`/fractary-faber:frame`, `/fractary-faber:architect`, etc.)
- **FR11**: Allow configuration override of manager/director skills for custom project needs
- **FR12**: Support workflow customization across all FABER plugin types (general faber, faber-cloud, faber-app, etc.)
- **FR13**: Provide GitHub integration for @fractary/@faber mention-based workflow triggering

## Non-Functional Requirements

- **NFR1**: Workflow execution should maintain context efficiency (target: <50K tokens for full orchestration) (performance)
- **NFR2**: Configuration validation should complete in <1 second (performance)
- **NFR3**: GitHub integration should respond to mentions within 30 seconds (responsiveness)
- **NFR4**: Workflow documentation should be self-explanatory without external references (usability)
- **NFR5**: Universal manager/director should work across all project types without modification (reusability)
- **NFR6**: Phase-level hooks should cover 90%+ of customization needs without requiring sub-step hooks (simplicity)

## Technical Design

### Architecture Changes

This work establishes a **universal FABER workflow framework** that works across all projects through configuration rather than per-project manager/director implementations.

#### Key Architectural Shift

**Previous approach**: Each FABER-based plugin (faber-cloud, faber-app, etc.) implemented its own director and manager agents, leading to duplication and inconsistency.

**New approach**: Single universal `faber-manager` agent + skill and `faber-director` skill in the core FABER plugin that work across all projects via configuration.

#### Architecture Components

1. **Universal faber-manager (Agent + Skill)**:
   - **Agent**: `plugins/faber/agents/faber-manager.md` - Lightweight wrapper that invokes the skill
   - **Skill**: `plugins/faber/skills/faber-manager/` - Contains all orchestration logic
   - Reads configuration from `.fractary/plugins/faber/config.json`
   - Orchestrates multi-step workflows across all 5 FABER phases
   - Executes sub-steps within each phase based on configuration
   - Handles phase boundary transitions with logging and approval prompts
   - Invokes hooks at phase boundaries (pre/post)
   - Tracks state via fractary-logs (historical) and state.json (current)
   - Works for all project types (software, infrastructure, etc.)

2. **Universal faber-director (Skill)**:
   - **Skill**: `plugins/faber/skills/faber-director/` - Freeform command parser
   - NOT an agent - just a skill that can be invoked
   - Parses natural language commands and maps to workflow operations
   - Supports parallelization: can spawn multiple faber-manager agents for multiple work items
   - Examples:
     - "@faber implement issue 123" → `/fractary-faber:run 123`
     - "@faber do the architect phase for 456" → `/fractary-faber:architect 456`
     - "@faber implement issues 100, 101, 102" → Parallel execution with 3 faber-manager agents
   - Handles GitHub mention parsing (@fractary, @faber)

3. **Configuration-Driven Workflow Execution**:
   - Configuration location: `.fractary/plugins/faber/config.json` (standard plugin config location)
   - Each of the 5 FABER phases can define multiple sub-steps
   - Phases are: Frame, Architect, Build, Evaluate, Release
   - Default configuration has one primary sub-step per phase
   - Projects can extend with additional sub-steps as needed
   - Configuration specifies which skills/scripts to use for each sub-step

4. **Phase-Level Hooks System**:
   - Hooks operate at phase boundaries, NOT at sub-step level
   - Available hooks: `pre_frame`, `post_frame`, `pre_architect`, `post_architect`, `pre_build`, `post_build`, `pre_evaluate`, `post_evaluate`, `pre_release`, `post_release`
   - Hook types: `script` (shell script), `skill` (invoke skill), `document` (inject context document)
   - This covers 90%+ of customization needs while keeping the system simple
   - Projects with complex sub-step requirements can implement custom manager skill

5. **Workflow State Management**:
   - **Historical logging**: Via fractary-logs plugin (log type: `workflow`)
     - Phase start/completion events
     - Sub-step execution
     - Errors and retries
     - Approval decisions
     - Artifacts created
   - **Current state**: Via `.fractary/plugins/faber/state.json`
     - Current phase and sub-step
     - Workflow status (in_progress, paused, completed, failed)
     - Pending approvals
     - Enable resume/retry capabilities

6. **Per-Phase Commands**:
   - Execute specific phases: `/fractary-faber:frame`, `/fractary-faber:architect`, `/fractary-faber:build`, `/fractary-faber:evaluate`, `/fractary-faber:release`
   - Each command invokes faber-manager with phase scope
   - Enables incremental workflow execution
   - Supports "just do the architect step" use case
   - Common logging and prompting at phase boundaries

7. **Custom Manager/Director Override**:
   - Configuration allows specifying custom manager or director skills:
     ```json
     {
       "workflow": {
         "manager_skill": "faber-manager",  // default: built-in universal
         "director_skill": "faber-director"  // default: built-in universal
       }
     }
     ```
   - Projects with unique requirements can implement custom skills
   - Custom skills can still leverage universal hooks and state management

### Data Model

**Workflow Configuration Schema** (`.fractary/plugins/faber/config.json`):

```json
{
  "schema_version": "1.0",
  "workflow": {
    "version": "2.0",
    "name": "project-name",
    "type": "software",
    "manager_skill": "faber-manager",
    "director_skill": "faber-director"
  },
  "phases": {
    "frame": {
      "enabled": true,
      "steps": [
        {
          "name": "fetch-work",
          "skill": "fractary-work:issue-fetcher",
          "description": "Fetch work item details"
        },
        {
          "name": "classify",
          "skill": "work-classifier",
          "description": "Classify work type (feature, bug, etc.)"
        },
        {
          "name": "setup-env",
          "skill": "fractary-repo:branch-manager",
          "description": "Create branch and setup environment"
        }
      ],
      "validation": ["work-item-exists", "branch-created"]
    },
    "architect": {
      "enabled": true,
      "steps": [
        {
          "name": "generate-spec",
          "skill": "fractary-spec:spec-generator",
          "description": "Generate technical specification"
        }
      ],
      "validation": ["spec-created", "spec-validated"]
    },
    "build": {
      "enabled": true,
      "steps": [
        {
          "name": "implement",
          "description": "Implement the solution"
        },
        {
          "name": "commit",
          "skill": "fractary-repo:commit-creator",
          "description": "Commit changes"
        }
      ],
      "validation": ["implementation-complete", "tests-pass"]
    },
    "evaluate": {
      "enabled": true,
      "max_retries": 3,
      "steps": [
        {
          "name": "test",
          "description": "Run tests"
        },
        {
          "name": "review",
          "description": "Code review"
        },
        {
          "name": "fix",
          "description": "Fix issues if found"
        }
      ],
      "validation": ["all-tests-pass", "review-approved"]
    },
    "release": {
      "enabled": true,
      "require_approval": true,
      "steps": [
        {
          "name": "create-pr",
          "skill": "fractary-repo:pr-manager",
          "description": "Create pull request"
        },
        {
          "name": "document",
          "skill": "fractary-docs:docs-manager",
          "description": "Update documentation"
        }
      ],
      "validation": ["pr-created", "ci-pass"]
    }
  },
  "hooks": {
    "pre_frame": [],
    "post_frame": [],
    "pre_architect": [],
    "post_architect": [],
    "pre_build": [],
    "post_build": [],
    "pre_evaluate": [],
    "post_evaluate": [],
    "pre_release": [
      {
        "type": "skill",
        "value": "final-review"
      }
    ],
    "post_release": []
  },
  "autonomy": {
    "level": "guarded",
    "pause_before_release": true,
    "require_approval_for": ["release"]
  },
  "logging": {
    "use_logs_plugin": true,
    "log_type": "workflow",
    "log_level": "info"
  }
}
```

**Notes on Configuration**:
- **5 Core Phases**: Frame, Architect, Build, Evaluate, Release (FABER acronym)
- **Sub-steps**: Each phase can have multiple steps, executed in order
- **Skills**: Steps can specify which skill to invoke (defaults to faber-manager's built-in logic)
- **Hooks**: Phase-level only (10 hooks total: pre/post for each of 5 phases)
- **Manager/Director**: Can override default universal skills if needed
- **Autonomy**: Controls approval requirements and execution mode

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

Enhanced command set with per-phase execution:

**Full Workflow Commands**:
- `/fractary-faber:init [--template <type>] [--analyze]` - Initialize workflow configuration
  - Analyzes project structure if --analyze flag provided
  - Creates `.fractary/plugins/faber/config.json` from template
  - Detects project type (software, infrastructure, etc.)

- `/fractary-faber:audit` - Audit project workflow alignment
  - Checks for required configuration files
  - Validates workflow configuration completeness
  - Reports missing integrations (work, repo, spec, logs plugins)
  - Suggests improvements

- `/fractary-faber:status [work-id]` - Show workflow status
  - Display current phase and progress
  - Show completed phases and artifacts
  - List pending approvals
  - Report any errors or blockers
  - Reads from fractary-logs (historical) and state.json (current)

- `/fractary-faber:run <work-id> [--autonomy <level>] [--from <phase>]` - Execute complete workflow
  - `--autonomy`: dry-run, assist, guarded, autonomous
  - `--from`: Resume from specific phase (frame, architect, build, evaluate, release)
  - Invokes universal faber-manager agent

**Per-Phase Commands** (NEW):
- `/fractary-faber:frame <work-id>` - Execute only Frame phase
  - Fetch work item, classify, setup environment

- `/fractary-faber:architect <work-id>` - Execute only Architect phase
  - Generate specification from requirements

- `/fractary-faber:build <work-id>` - Execute only Build phase
  - Implement solution and commit changes

- `/fractary-faber:evaluate <work-id>` - Execute only Evaluate phase
  - Test, review, and validate implementation

- `/fractary-faber:release <work-id>` - Execute only Release phase
  - Create PR, update docs, deploy

**Benefits of Per-Phase Commands**:
- Enables incremental workflow execution
- Supports "just do the architect step" use case from issue #158
- Common logging and prompting at phase boundaries
- Each command invokes faber-manager with specific phase scope

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
Design and implement the JSON configuration schema

**Tasks**:
- [ ] Design configuration schema in `.fractary/plugins/faber/config.json` (JSON format)
- [ ] Define 5 FABER phases with sub-step structure
- [ ] Add phase-level hooks (10 hooks: pre/post for each phase)
- [ ] Add manager/director skill override capability
- [ ] Add autonomy and logging configuration
- [ ] Implement configuration validation logic
- [ ] Create configuration templates for different project types (software, infrastructure, etc.)
- [ ] Document configuration format with comprehensive examples

### Phase 2: Workflow State Management
Implement dual-track state management with fractary-logs + state.json

**Tasks**:
- [ ] Design state schema for `.fractary/plugins/faber/state.json` (current state)
- [ ] Integrate with fractary-logs plugin for historical workflow logging
- [ ] Define workflow log type schema for fractary-logs
- [ ] Implement state persistence for current workflow state
- [ ] Implement phase transition tracking
- [ ] Add error and retry tracking
- [ ] Implement workflow resume/retry from saved state
- [ ] Create `/fractary-faber:status` command to read and display state

### Phase 3: Universal faber-manager (Agent + Skill)
Create the universal workflow orchestration manager

**Tasks**:
- [ ] Create `plugins/faber/agents/faber-manager.md` (lightweight wrapper agent)
- [ ] Create `plugins/faber/skills/faber-manager/` (orchestration skill with all logic)
- [ ] Implement configuration loading from `.fractary/plugins/faber/config.json`
- [ ] Implement phase orchestration (Frame → Architect → Build → Evaluate → Release)
- [ ] Implement sub-step execution within each phase
- [ ] Implement phase boundary logging and prompting
- [ ] Implement hooks execution at phase boundaries (pre/post)
- [ ] Implement autonomy level handling (dry-run, assist, guarded, autonomous)
- [ ] Implement approval prompt logic at phase boundaries
- [ ] Add fractary-logs integration for historical logging
- [ ] Add state.json updates for current state tracking

### Phase 4: Universal faber-director (Skill)
Create the universal freeform command parser

**Tasks**:
- [ ] Create `plugins/faber/skills/faber-director/` (command parser skill)
- [ ] Implement natural language command parsing
- [ ] Implement workflow operation mapping (@faber commands → workflow operations)
- [ ] Implement parallelization support (spawn multiple faber-manager agents)
- [ ] Implement GitHub mention parsing (@fractary, @faber)
- [ ] Add support for per-phase execution ("do the architect phase")
- [ ] Add support for batch execution ("implement issues 100, 101, 102")

### Phase 5: Per-Phase Commands
Create individual commands for each FABER phase

**Tasks**:
- [ ] Create `/fractary-faber:frame` command
- [ ] Create `/fractary-faber:architect` command
- [ ] Create `/fractary-faber:build` command
- [ ] Create `/fractary-faber:evaluate` command
- [ ] Create `/fractary-faber:release` command
- [ ] Implement phase-scoped invocation of faber-manager
- [ ] Add phase boundary logging for all commands
- [ ] Document per-phase command usage

### Phase 6: Initialization and Audit Commands
Create tools to set up and validate workflow integration

**Tasks**:
- [ ] Implement `/fractary-faber:init` command with project analysis
- [ ] Create project type detection logic
- [ ] Generate configuration from templates based on detected type
- [ ] Implement `/fractary-faber:audit` command
- [ ] Add configuration completeness checks
- [ ] Add plugin integration checks (work, repo, spec, logs)
- [ ] Validate phase definitions and hook configuration
- [ ] Create suggestions for improvements

### Phase 7: Testing and Documentation
Validate the universal framework works across all project types

**Tasks**:
- [ ] Test universal faber-manager with software projects
- [ ] Test with infrastructure projects (formerly faber-cloud use cases)
- [ ] Test with application projects (formerly faber-app use cases)
- [ ] Test per-phase commands independently
- [ ] Test faber-director parallelization
- [ ] Test hooks at all phase boundaries
- [ ] Test fractary-logs integration
- [ ] Create comprehensive configuration documentation
- [ ] Update CLAUDE.md with universal workflow guidance
- [ ] Create tutorial for setting up new projects
- [ ] Document hooks system usage

### Phase 8: GitHub Integration (Future)
Implement GitHub app for mention-based control

**Tasks**:
- [ ] Design GitHub app architecture
- [ ] Implement webhook listener for issue comments
- [ ] Integrate faber-director skill for command parsing
- [ ] Build workflow execution bridge
- [ ] Implement progress reporting to issues via fractary-logs
- [ ] Add approval handling via reactions/comments
- [ ] Deploy and configure GitHub app
- [ ] Document GitHub integration usage

## Files to Create/Modify

### New Files

**Core Universal Components**:
- `plugins/faber/agents/faber-manager.md`: Universal workflow manager agent (lightweight wrapper)
- `plugins/faber/skills/faber-manager/`: Universal workflow manager skill (orchestration logic)
- `plugins/faber/skills/faber-director/`: Universal director skill (freeform command parser)

**Configuration and State**:
- `.fractary/plugins/faber/config.json`: Project-specific workflow configuration (JSON format)
- `.fractary/plugins/faber/state.json`: Current workflow execution state (generated at runtime)
- `plugins/faber/config/templates/software.json`: Default config for software projects
- `plugins/faber/config/templates/infrastructure.json`: Default config for infrastructure projects
- `plugins/faber/config/templates/application.json`: Default config for application projects

**Per-Phase Commands**:
- `plugins/faber/commands/frame.md`: Frame phase command
- `plugins/faber/commands/architect.md`: Architect phase command
- `plugins/faber/commands/build.md`: Build phase command
- `plugins/faber/commands/evaluate.md`: Evaluate phase command
- `plugins/faber/commands/release.md`: Release phase command

**Supporting Skills**:
- `plugins/faber/skills/config-validator/`: Configuration validation skill
- `plugins/faber/skills/project-analyzer/`: Project analysis skill (for `/fractary-faber:init`)
- `plugins/faber/skills/workflow-auditor/`: Workflow audit skill (for `/fractary-faber:audit`)

**Documentation**:
- `plugins/faber/docs/CONFIGURATION.md`: Comprehensive configuration documentation
- `plugins/faber/docs/HOOKS.md`: Phase-level hooks system documentation
- `plugins/faber/docs/UNIVERSAL-MANAGER.md`: Universal manager/director architecture guide
- `plugins/faber/docs/PER-PHASE-COMMANDS.md`: Per-phase command usage guide

### Modified Files

**Existing Commands** (update to use universal manager):
- `plugins/faber/commands/init.md`: Enhanced with project analysis and JSON config generation
- `plugins/faber/commands/run.md`: Updated to invoke universal faber-manager agent
- `plugins/faber/commands/status.md`: Enhanced to read from fractary-logs + state.json
- `plugins/faber/commands/audit.md`: Create if doesn't exist, or update to new structure

**Deprecated/Removed Files** (if they exist):
- `plugins/faber/agents/director.md`: REMOVE - replaced by faber-director skill
- `plugins/faber/agents/workflow-manager.md`: REMOVE - replaced by faber-manager agent+skill

**Configuration Examples**:
- `plugins/faber/config/faber.example.json`: Example configuration (convert from TOML if exists)

**Project Documentation**:
- `CLAUDE.md`: Add section on universal FABER workflow configuration
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`: Document universal workflow pattern for plugin authors
- `plugins/faber/README.md`: Update with universal manager/director architecture

**Logs Plugin Integration**:
- `plugins/logs/types/workflow.json`: Define workflow log type schema (if doesn't exist)

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

**Required Plugin Dependencies**:
- `fractary-logs`: Historical workflow logging (workflow log type)

**Optional Plugin Dependencies** (used by default workflow steps):
- `fractary-work`: Work item management (Frame phase - fetch, update, comment)
- `fractary-repo`: Source control operations (Frame/Build/Release phases - branch, commit, PR)
- `fractary-spec`: Specification generation (Architect phase)
- `fractary-docs`: Documentation updates (Release phase)
- `fractary-file`: File storage (if using cloud archival in Release phase)

**External Dependencies**:
- None for core functionality
- GitHub API/App (for future GitHub integration phase)

**Configuration Files**:
- `.fractary/plugins/faber/config.json`: Project-specific workflow configuration (JSON format)
- `.fractary/plugins/faber/state.json`: Current workflow state (generated at runtime)
- Workflow logs stored via fractary-logs plugin (historical logging)

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

- **Risk**: Universal manager doesn't cover all project-specific use cases
  - **Likelihood**: Medium
  - **Impact**: Medium (some projects need custom logic)
  - **Mitigation**: Allow configuration override of manager/director skills. Projects with unique needs can implement custom skills while leveraging universal hooks and state management.

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

### Stage 1: Core Universal Components
- Implement universal faber-manager (agent + skill)
- Implement universal faber-director (skill)
- Implement configuration schema and validation
- Implement state management (fractary-logs + state.json)
- Test basic workflow execution with default configuration

### Stage 2: Phase-Level Features
- Implement per-phase commands (`/fractary-faber:frame`, etc.)
- Implement hooks system at phase boundaries
- Implement phase boundary logging and prompting
- Test incremental workflow execution

### Stage 3: Tooling and Documentation
- Implement `/fractary-faber:init` with project analysis
- Implement `/fractary-faber:audit` with validation
- Create configuration templates for different project types
- Write comprehensive documentation (CONFIGURATION.md, HOOKS.md, etc.)
- Update CLAUDE.md with universal workflow guidance

### Stage 4: Testing Across Project Types
- Test with software projects
- Test with infrastructure projects (replace faber-cloud specifics)
- Test with application projects (replace faber-app specifics)
- Validate universal approach works across all types
- Gather feedback and refine

### Stage 5: GitHub Integration (Future, High Value)
- Implement GitHub app/integration using faber-director
- Beta test with select projects
- Full release once stable
- This is optional - core functionality is complete without it

## Success Metrics

- **Configuration Adoption**: 80% of active FABER projects have `.fractary/plugins/faber/config.json` within 3 months
- **Universal Manager Adoption**: 90% of projects use the universal faber-manager without custom overrides
- **Workflow Reliability**: 95% of workflows complete without manual intervention (for autonomy level "guarded" or higher)
- **Time Savings**: 50% reduction in time spent on workflow step lookup/documentation
- **Per-Phase Usage**: 40% of workflow executions use per-phase commands for incremental work
- **GitHub Control Plane**: 70% of workflow initiations happen via GitHub mentions (post-integration)
- **Documentation Quality**: Zero questions about workflow configuration in community channels after reading docs
- **Audit Pass Rate**: 90% of projects pass `/fractary-faber:audit` after initial configuration
- **Hook Usage**: 60% of projects define at least one phase-level hook for customization

## Implementation Notes

### Existing Work to Review

The issue mentions that "some initial work was done to scaffold this ability into the Faber plugin." Priority tasks:

1. **Check existing config format**: Look for `.faber.config.toml` or any config files - need to convert to `.fractary/plugins/faber/config.json` (JSON)
2. **Review faber-cloud hooks**: Check if hooks system already implemented in faber-cloud and can be generalized
3. **Audit existing agents**: Review current director/workflow-manager implementations before replacing with universal versions
4. **Check for state tracking**: Identify any existing workflow state or tracking mechanisms
5. **Review fractary-logs plugin**: Ensure workflow log type exists or needs to be created

### Key Architectural Decisions

1. **Universal vs. Per-Project Manager/Director**:
   - Decision: Universal manager + director that work across all projects
   - Rationale: Reduces duplication, improves consistency, simplifies maintenance
   - Escape hatch: Configuration allows override for projects with unique needs

2. **Phase-Level Hooks Only**:
   - Decision: Hooks at phase boundaries (10 hooks), not at sub-step level
   - Rationale: Covers 90%+ of use cases while keeping system simple
   - Escape hatch: Projects needing sub-step hooks can implement custom manager skill

3. **JSON over TOML**:
   - Decision: Use `.fractary/plugins/faber/config.json` (JSON format)
   - Rationale: Consistent with all other plugin configurations
   - Note: This is the standard adopted across all Fractary plugins

4. **Dual-Track State Management**:
   - Decision: fractary-logs for historical + state.json for current state
   - Rationale: Logs plugin provides rich historical tracking, state.json enables resume/retry
   - Integration: State transitions written to both

### Design Philosophy

This implementation establishes universal FABER patterns:
- **Context efficiency**: Universal manager reduces token usage compared to per-project implementations
- **Standardization**: Single implementation ensures consistent behavior across all projects
- **Simplicity**: Phase-level abstractions cover most needs without sub-step complexity
- **Flexibility**: Configuration and hooks provide customization without code changes
- **Extensibility**: Custom manager/director skills available for edge cases

### Integration with Existing Plugins

The universal workflow framework integrates with Fractary ecosystem:
- **fractary-work**: Used in Frame phase (fetch work item, update status, comment)
- **fractary-repo**: Used throughout (branch creation, commits, PR management)
- **fractary-spec**: Used in Architect phase (specification generation)
- **fractary-docs**: Used in Release phase (documentation updates)
- **fractary-logs**: Required for historical workflow logging
- **fractary-file**: Optional for artifact storage/archival

### Migration Path for Existing FABER Plugins

Projects using faber-cloud or faber-app with custom manager/director agents:

1. **Option 1 - Migrate to Universal** (recommended):
   - Create `.fractary/plugins/faber/config.json` with project-specific phases/sub-steps
   - Define hooks for any custom logic currently in manager
   - Remove custom director/manager agents
   - Use universal faber-manager + faber-director

2. **Option 2 - Custom Override**:
   - Keep custom manager/director skills
   - Configure `workflow.manager_skill` and `workflow.director_skill` to use custom implementations
   - Still benefit from standard config format, state management, and fractary-logs integration

3. **Hybrid Approach**:
   - Use universal faber-director (most projects don't need custom director)
   - Implement custom manager skill only if needed (rare)
   - Leverage universal hooks and state management

### Future Extensibility

Design supports future enhancements:
- **Custom phase definitions**: Beyond the 5 standard FABER phases (for specialized workflows)
- **Conditional workflow paths**: Based on work type, project type, or custom logic
- **Parallel phase execution**: Where phases don't have dependencies
- **Workflow templates/presets**: Quick-start configs for common scenarios
- **Multi-work-item workflows**: Batch processing with faber-director parallelization
- **Cross-project workflows**: Coordinated workflows across multiple repositories
