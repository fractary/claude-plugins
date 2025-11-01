# FABER Single Manager Architecture Refactor

**Status**: Proposed
**Date**: 2025-11-01
**Author**: Architecture Discussion
**Related**: [FRACTARY-PLUGIN-STANDARDS.md](../standards/FRACTARY-PLUGIN-STANDARDS.md), [fractary-faber-architecture.md](./fractary-faber-architecture.md)

## Executive Summary

This specification proposes refactoring the `fractary-faber` plugin from a **multi-agent architecture** (5 specialized phase managers) to a **single workflow manager + skills architecture**. This addresses key concerns around context size, workflow continuity, and maintainability while establishing faber as both a framework and batteries-included solution.

## Background

### Current Architecture (Multi-Agent)

```
director.md (26K)
  ↓ sequential invocation
frame-manager.md (12K) → complete
  ↓
architect-manager.md (14K) → complete
  ↓
build-manager.md (14K) → complete
  ↓
evaluate-manager.md (16K) → GO/NO-GO
  ↓ (if NO-GO, retry build)
release-manager.md (16K) → complete
```

**Communication**: Session JSON files (`.faber/sessions/{work_id}.json`)

**Phase Manager Pattern**: All 5 phase managers follow identical structure:
1. Load session state
2. Delegate to domain bundle (not yet implemented)
3. Update session state
4. Post status notification
5. Return control to director

### Problems with Current Architecture

1. **Context Size**: Director + 5 phase managers = significant token usage
2. **Lost Context**: Each phase manager has isolated context, cannot see previous phases
3. **Repetitive Code**: Phase managers duplicate load → delegate → update → notify pattern
4. **Incomplete Implementation**: Domain bundles referenced but not implemented
5. **Limited Flexibility**: Hard to customize workflows or add project-specific phases

### Architectural Goals (From User Input)

1. **Framework Model**: Domain plugins MUST use faber's phase managers/workflow
2. **High Customization for Domains**: Domains can override/skip phases, add custom phases
3. **Per-Project Customization**: Users can customize workflows in `.faber.config.toml`
4. **Batteries Included**: faber/ should include basic software development workflow
5. **Continuous Context**: Each step should have context of all previous steps

## Proposed Architecture

### Three-Agent Pattern

```
director.md
  ↓ routes operations
workflow-manager.md
  ↓ orchestrates phases, maintains context
phase-skill/ (frame, architect, build, evaluate, release)
  ↓ executes phase operations
primitives (work-manager, repo-manager, file-manager)
```

### Component Responsibilities

#### 1. Director (Keep, Modify)

**File**: `plugins/faber/agents/director.md`

**Responsibilities**:
- Parse natural language requests and GitHub mentions
- Route to appropriate workflow manager(s)
- Handle control commands: approve, retry, cancel, skip
- Enforce autonomy level constraints (dry-run, assist, guarded, autonomous)
- Coordinate multiple workflows (future: parallel issue processing)

**Does NOT**:
- Orchestrate phases directly
- Maintain workflow state
- Execute phase operations

**Changes from current**:
- Invoke workflow-manager instead of individual phase managers
- Simplified orchestration logic

#### 2. Workflow Manager (NEW - Consolidates 5 Phase Managers)

**File**: `plugins/faber/agents/workflow-manager.md`

**Responsibilities**:
- Orchestrate all 5 FABER phases sequentially
- Maintain full workflow context across all phases
- Implement Build-Evaluate retry loop
- Manage session state continuously
- Delegate phase operations to skills
- Enforce phase-specific autonomy gates
- Post status updates via work-manager

**Workflow Logic**:
```
1. FRAME Phase
   - Invoke frame-skill
   - Update session with work_item, work_type, environment

2. ARCHITECT Phase
   - Invoke architect-skill with context from Frame
   - Update session with spec_file, commit_sha

3. BUILD Phase (retriable)
   - Invoke build-skill with context from Frame + Architect
   - Update session with implementation commits

4. EVALUATE Phase
   - Invoke evaluate-skill with context from all previous phases
   - Decision: GO (continue) or NO-GO (retry Build)
   - If NO-GO and retries < max_retries: loop to Build
   - Update session with test_results, review_results

5. RELEASE Phase (autonomy gate)
   - Check autonomy level (dry-run/assist stop here)
   - If guarded: request approval
   - Invoke release-skill with full workflow context
   - Update session with pr_url, merge_status, closed_work
```

**Context Management**:
```markdown
<WORKFLOW_CONTEXT>
## Work Item
{work_id}: {title}
Type: {work_type}
Description: {description}

## Frame Results
Environment: {environment_setup}
Classifications: {work_classifications}

## Architecture
Spec File: {spec_file}
Spec Commit: {spec_commit_sha}
Key Decisions: {architecture_decisions}

## Build
Implementation Commits: {build_commits}
Files Changed: {files_changed}
Retry Count: {retry_count}

## Evaluate
Test Results: {test_results}
Review Results: {review_results}
Decision: {go_no_go}
</WORKFLOW_CONTEXT>
```

**Skill Invocation Pattern**:
```
Use the @skill-fractary-faber:frame skill with the following request:
{
  "operation": "execute_frame",
  "work_id": "123",
  "config": {...},
  "context": {...}
}
```

**Session Updates**:
- After each phase completes
- Incremental updates (not full rewrites)
- Maintains audit trail

#### 3. Phase Skills (NEW - Replace Phase Managers)

**Directories**:
- `plugins/faber/skills/frame/`
- `plugins/faber/skills/architect/`
- `plugins/faber/skills/build/`
- `plugins/faber/skills/evaluate/`
- `plugins/faber/skills/release/`

**Each skill structure**:
```
skills/{phase}/
├── SKILL.md                    # Skill instructions
├── scripts/
│   ├── {operation}.sh          # Deterministic operations
│   └── ...
└── workflow/
    ├── basic.md                # Basic implementation (batteries-included)
    └── ...
```

**Skill Pattern** (example for architect-skill):
```markdown
<CONTEXT>
You are the architect-skill, responsible for generating technical specifications
from work items. You receive work item details and context from the workflow-manager
and produce a specification document following the project's standards.
</CONTEXT>

<INPUTS>
- work_id: Work item identifier
- work_item: Full work item details (title, description, acceptance criteria)
- work_type: Classified type (feature, bug, refactor, etc.)
- frame_context: Environment setup and classifications from Frame phase
- config: Project configuration (.faber.config.toml)
</INPUTS>

<WORKFLOW>
1. Load work item and frame context
2. Analyze requirements and acceptance criteria
3. Generate specification document (workflow/basic.md provides template)
4. Save spec to configured location (default: .faber/specs/{work_id}.md)
5. Commit spec via repo-manager
6. Push to remote (if configured)
7. Post status update via work-manager
</WORKFLOW>

<OUTPUTS>
{
  "spec_file": ".faber/specs/123.md",
  "commit_sha": "abc123",
  "key_decisions": ["Use REST API", "PostgreSQL for persistence"],
  "status": "success"
}
</OUTPUTS>
```

**Basic Implementations** (Batteries Included):

1. **frame-skill/workflow/basic.md**:
   - Fetch work item via work-manager
   - Classify work type (feature/bug/refactor/docs/test)
   - Post "Frame started" status card
   - Basic environment checks (git status, branch creation)

2. **architect-skill/workflow/basic.md**:
   - Generate markdown specification from work item
   - Template: Problem, Solution, Technical Approach, Acceptance Criteria
   - Spec-driven development pattern
   - Commit spec to `.faber/specs/{work_id}.md`

3. **build-skill/workflow/basic.md**:
   - Claude-driven implementation guidance
   - Follow spec document
   - Standard commit practices
   - No domain-specific tooling (domains override this)

4. **evaluate-skill/workflow/basic.md**:
   - Run tests if they exist (`npm test`, `pytest`, etc.)
   - Basic code review checks (syntax, lint, security)
   - GO/NO-GO decision based on test results
   - Detailed failure reporting for retries

5. **release-skill/workflow/basic.md**:
   - Create PR via repo-manager
   - Link to work item
   - Add spec to PR body
   - Auto-merge if configured
   - Close work item via work-manager
   - Post completion status

### Configuration-Driven Customization

**Enhanced `.faber.config.toml`**:

```toml
[workflow]
# Workflow type: "standard" uses built-in 5-phase, "custom" allows full customization
type = "standard"

# For standard workflows: phase sequence (future: reordering, conditional phases)
phases = ["frame", "architect", "build", "evaluate", "release"]

# Skill overrides: specify which skills to use for each phase
[workflow.skills]
frame = "fractary-faber:frame"           # Use built-in
architect = "fractary-faber:architect"   # Use built-in
build = "fractary-faber-app:build"       # Use domain override
evaluate = "fractary-faber-app:evaluate" # Use domain override
release = "fractary-faber:release"       # Use built-in

# Custom workflows (type = "custom")
# [workflow.custom]
# phases = [
#   {name = "intake", skill = "myproject:intake"},
#   {name = "design", skill = "myproject:design"},
#   {name = "implement", skill = "myproject:implement"},
#   {name = "validate", skill = "myproject:validate"},
#   {name = "deploy", skill = "myproject:deploy", gate = "approval"}
# ]

[workflow.retry]
max_build_retries = 2
retry_delay_seconds = 5

[workflow.autonomy]
level = "guarded"  # dry-run, assist, guarded, autonomous
stop_at_phase = "release"  # for assist mode

[workflow.release]
auto_merge = false
auto_close = true
delete_branch = true
```

### Domain Plugin Override Pattern

**Example: faber-app overrides**:

```
plugins/faber-app/
├── .claude-plugin/
│   └── plugin.json          # requires: ["fractary-faber"]
├── skills/
│   ├── build/               # Override build phase
│   │   ├── SKILL.md
│   │   ├── workflow/
│   │   │   ├── webapp.md    # Web app build workflow
│   │   │   ├── api.md       # API build workflow
│   │   │   └── cli.md       # CLI build workflow
│   │   └── scripts/
│   │       ├── install-deps.sh
│   │       ├── run-build.sh
│   │       └── check-types.sh
│   └── evaluate/            # Override evaluate phase
│       ├── SKILL.md
│       ├── workflow/
│       │   ├── test.md      # Run tests
│       │   ├── lint.md      # Linting
│       │   ├── security.md  # Security scanning
│       │   └── review.md    # Code review
│       └── scripts/
│           ├── run-tests.sh
│           ├── run-lint.sh
│           └── security-scan.sh
```

**faber-app configuration preset**:
```toml
# .faber-app.preset.toml
[workflow.skills]
build = "fractary-faber-app:build"
evaluate = "fractary-faber-app:evaluate"
```

### Project-Level Customization

**Use case**: Project needs custom evaluation phase

```
my-project/
├── .faber.config.toml
├── .faber/
│   └── skills/
│       └── custom-evaluate/
│           ├── SKILL.md
│           ├── workflow/
│           │   └── comprehensive.md
│           └── scripts/
│               ├── run-integration-tests.sh
│               ├── run-e2e-tests.sh
│               ├── check-coverage.sh
│               └── security-audit.sh
```

**Configuration**:
```toml
[workflow.skills]
evaluate = ".faber/skills/custom-evaluate"  # Local override
```

## Migration Path

### Phase 1: Create Workflow Manager (Non-Breaking)

**Goal**: Introduce new workflow-manager alongside existing phase managers

**Tasks**:
1. Create `plugins/faber/agents/workflow-manager.md`
2. Consolidate orchestration logic from 5 phase managers
3. Implement full context management
4. Add skill invocation pattern
5. Maintain session compatibility

**Testing**: Run workflow-manager in parallel with old architecture, compare outputs

### Phase 2: Create Phase Skills (Non-Breaking)

**Goal**: Implement 5 basic phase skills with batteries-included workflows

**Tasks**:
1. Create skill directories: `plugins/faber/skills/{frame,architect,build,evaluate,release}/`
2. Implement `SKILL.md` for each phase
3. Create `workflow/basic.md` for each phase
4. Implement basic scripts (deterministic operations)
5. Test each skill independently

**Testing**: Invoke skills directly, verify outputs match phase manager behavior

### Phase 3: Update Director (Breaking)

**Goal**: Switch director to use workflow-manager

**Tasks**:
1. Modify `plugins/faber/agents/director.md`
2. Replace phase manager invocations with workflow-manager invocation
3. Simplify control flow logic
4. Update error handling

**Testing**: Full workflow integration tests

### Phase 4: Add Configuration Support (Feature)

**Goal**: Enable workflow customization

**Tasks**:
1. Enhance `.faber.config.toml` schema
2. Implement skill resolution (built-in, domain, project)
3. Add workflow type support (standard, custom)
4. Create configuration validation

**Testing**: Test various override scenarios

### Phase 5: Documentation & Migration (Breaking)

**Goal**: Update all documentation and archive old agents

**Tasks**:
1. Update `CLAUDE.md` with new architecture
2. Create migration guide for domain plugins
3. Update all plugin specs
4. Archive old phase managers to `.archive/pre-single-manager/`
5. Bump version to 2.0.0

**Migration Guide Topics**:
- How workflow-manager differs from phase managers
- How to convert domain bundles to skills
- How to override skills in domain plugins
- How to customize workflows in projects

### Phase 6: Domain Plugin Updates (Post-Release)

**Goal**: Update domain plugins to use new architecture

**Domain plugins to update**:
- `faber-app` - Create build/evaluate skill overrides
- `faber-cloud` - Evaluate if infra workflow fits FABER pattern
- Future domain plugins

## Benefits Analysis

### Context Size Reduction

**Before**:
```
director.md (26K)
+ frame-manager.md (12K)
= 38K tokens for Frame phase

director.md (26K)
+ architect-manager.md (14K)
= 40K tokens for Architect phase

...total across 5 phases ≈ 200K+ tokens
```

**After**:
```
director.md (≈15K, simplified)
+ workflow-manager.md (≈25K, consolidated)
= 40K tokens for ENTIRE workflow
```

**Savings**: ~75-80% reduction in agent context across full workflow

### Continuous Context

**Before**: Each phase manager isolated
```
frame-manager: knows Frame only
architect-manager: knows Architect only (loads session for Frame data)
build-manager: knows Build only (loads session for Architect data)
```

**After**: Workflow manager has full context
```
workflow-manager: knows Frame + Architect + Build + Evaluate + Release
- Can reference earlier decisions
- Can optimize across phases
- Can provide better error context
```

### Maintainability

**Before**: 5 similar agents with duplicated patterns
```
frame-manager.md: load session → delegate → update session → notify
architect-manager.md: load session → delegate → update session → notify
build-manager.md: load session → delegate → update session → notify
evaluate-manager.md: load session → delegate → update session → notify
release-manager.md: load session → delegate → update session → notify
```

**After**: Single manager with clear skill delegation
```
workflow-manager.md: orchestrate phases, maintain context, delegate to skills
frame-skill: focused on Frame operations
architect-skill: focused on Architect operations
...
```

**Benefit**: Changes to orchestration patterns happen in one place

### Extensibility

**Before**: Phase managers reference non-existent domain bundles
```markdown
# In architect-manager.md
claude -p "/fractary/faber/engineering/${work_type#/} ${work_id}"
# These bundles don't exist
```

**After**: Clear skill override mechanism
```toml
[workflow.skills]
architect = "fractary-faber-app:architect"  # Domain override
```

**Benefit**: Domains provide real skill implementations, not hypothetical bundles

### Flexibility

**Before**: Locked into 5-phase sequence, hard to customize

**After**: Multiple levels of customization
1. **Config-level**: Override skills in `.faber.config.toml`
2. **Domain-level**: Domain plugins provide skill implementations
3. **Project-level**: Projects can provide custom skills
4. **Future: Phase-level**: Custom phase sequences, conditional phases

## Risks & Mitigations

### Risk 1: Breaking Changes for Domain Plugins

**Impact**: faber-cloud, faber-app would need updates

**Mitigation**:
- Phase migration in stages (non-breaking first)
- Provide migration guide and examples
- Offer backward compatibility shim (temporary)
- Most domain plugins not yet implemented, so impact minimal

### Risk 2: Workflow Manager Complexity

**Impact**: Single agent becomes large and complex

**Mitigation**:
- Keep manager focused on orchestration only
- Push phase logic into skills (smaller, testable units)
- Use workflow configuration for customization
- Target: workflow-manager ≈ 25K (manageable size)

### Risk 3: Lost Specialization

**Impact**: Phase managers had phase-specific expertise

**Mitigation**:
- Phase skills maintain specialization
- Skills have focused SKILL.md with phase-specific instructions
- Workflow manager provides context, not replacement for expertise
- Domain plugins can override with even more specialized skills

### Risk 4: Session State Management

**Impact**: More complex state updates in workflow manager

**Mitigation**:
- Incremental session updates (not full rewrites)
- Clear state schema in documentation
- Core skill utilities handle session operations
- Automated testing of state transitions

## Success Criteria

1. **Context Reduction**: ≥70% reduction in token usage across full workflow
2. **Context Continuity**: Workflow manager can reference any previous phase in current phase
3. **Maintainability**: Changes to orchestration patterns require only 1 file edit
4. **Extensibility**: Domain plugins successfully override ≥2 skills
5. **Flexibility**: Projects successfully implement custom workflows
6. **Batteries Included**: faber/ can execute basic software workflow without domain plugins
7. **Migration**: Existing .faber.config.toml files continue to work (or clear upgrade path)
8. **Performance**: Workflow execution time ≤ current architecture
9. **Testing**: 100% of integration tests pass
10. **Documentation**: Complete migration guide for domain plugin authors

## Future Enhancements

### Phase Sequence Customization

Allow projects to define custom phase sequences:
```toml
[workflow.custom]
phases = [
  {name = "intake", skill = "faber:frame"},
  {name = "research", skill = "myproject:research"},  # Custom phase
  {name = "design", skill = "faber:architect"},
  {name = "prototype", skill = "myproject:prototype"},  # Custom phase
  {name = "implement", skill = "faber:build"},
  {name = "test", skill = "faber:evaluate"},
  {name = "deploy", skill = "faber:release"}
]
```

### Conditional Phases

Enable phase execution based on conditions:
```toml
[[workflow.custom.phases]]
name = "security_scan"
skill = "myproject:security"
condition = "work_type == 'feature' && touches_auth_code"
```

### Parallel Phase Execution

Allow independent phases to run concurrently:
```toml
[[workflow.custom.phases]]
name = "test_unit"
skill = "myproject:unit-tests"
parallel_group = "testing"

[[workflow.custom.phases]]
name = "test_integration"
skill = "myproject:integration-tests"
parallel_group = "testing"
```

### Phase Dependencies

Define explicit phase dependencies:
```toml
[[workflow.custom.phases]]
name = "deploy_staging"
skill = "myproject:deploy-staging"
depends_on = ["test_unit", "test_integration", "security_scan"]
```

## References

- [FRACTARY-PLUGIN-STANDARDS.md](../standards/FRACTARY-PLUGIN-STANDARDS.md) - Plugin architecture patterns
- [fractary-faber-architecture.md](./fractary-faber-architecture.md) - Original FABER specification
- [faber-cloud plugin](../../plugins/faber-cloud/) - Example of single-manager pattern
- [work plugin](../../plugins/work/) - Example of pure router pattern
- [repo plugin](../../plugins/repo/) - Example of pure router pattern

## Appendix A: File Changes Summary

### New Files
- `plugins/faber/agents/workflow-manager.md` (~25K)
- `plugins/faber/skills/frame/SKILL.md` (~5K)
- `plugins/faber/skills/frame/workflow/basic.md` (~2K)
- `plugins/faber/skills/architect/SKILL.md` (~5K)
- `plugins/faber/skills/architect/workflow/basic.md` (~2K)
- `plugins/faber/skills/build/SKILL.md` (~5K)
- `plugins/faber/skills/build/workflow/basic.md` (~2K)
- `plugins/faber/skills/evaluate/SKILL.md` (~6K)
- `plugins/faber/skills/evaluate/workflow/basic.md` (~3K)
- `plugins/faber/skills/release/SKILL.md` (~6K)
- `plugins/faber/skills/release/workflow/basic.md` (~2K)
- Various `scripts/*.sh` files in each skill directory

### Modified Files
- `plugins/faber/agents/director.md` (simplified, ~15K)
- `plugins/faber/config/faber.example.toml` (add workflow section)
- `plugins/faber/.claude-plugin/plugin.json` (update agents list)
- `.claude-plugin/marketplace.json` (update faber entry)
- `CLAUDE.md` (update architecture documentation)

### Archived Files
- `plugins/faber/.archive/pre-single-manager/agents/frame-manager.md`
- `plugins/faber/.archive/pre-single-manager/agents/architect-manager.md`
- `plugins/faber/.archive/pre-single-manager/agents/build-manager.md`
- `plugins/faber/.archive/pre-single-manager/agents/evaluate-manager.md`
- `plugins/faber/.archive/pre-single-manager/agents/release-manager.md`

### Version Bumps
- `plugins/faber/.claude-plugin/plugin.json`: `1.1.0` → `2.0.0` (breaking)
- `.claude-plugin/marketplace.json`: Update faber entry to `2.0.0`

## Appendix B: Workflow Manager Pseudo-Code

```python
class WorkflowManager:
    def __init__(self, work_id, config):
        self.work_id = work_id
        self.config = config
        self.session = load_or_create_session(work_id)
        self.context = WorkflowContext()

    def execute_workflow(self):
        """Execute full FABER workflow"""
        try:
            # Phase 1: Frame
            self.context.frame = self.execute_phase("frame", frame_skill)
            self.update_session("frame", self.context.frame)
            self.post_status("frame", "completed")

            # Phase 2: Architect
            self.context.architect = self.execute_phase("architect", architect_skill,
                                                        context=self.context)
            self.update_session("architect", self.context.architect)
            self.post_status("architect", "completed")

            # Phase 3: Build (retriable)
            retry_count = 0
            while retry_count <= self.config.max_retries:
                self.context.build = self.execute_phase("build", build_skill,
                                                        context=self.context)
                self.update_session("build", self.context.build)
                self.post_status("build", "completed")

                # Phase 4: Evaluate
                self.context.evaluate = self.execute_phase("evaluate", evaluate_skill,
                                                           context=self.context)
                self.update_session("evaluate", self.context.evaluate)

                if self.context.evaluate.decision == "GO":
                    self.post_status("evaluate", "passed")
                    break
                elif retry_count < self.config.max_retries:
                    retry_count += 1
                    self.post_status("evaluate", f"failed, retry {retry_count}")
                else:
                    self.post_status("evaluate", "failed, max retries")
                    raise EvaluationFailedError()

            # Check autonomy gate
            if self.config.autonomy in ["dry-run", "assist"]:
                self.post_status("workflow", "stopped at autonomy gate")
                return self.session

            # Phase 5: Release (approval gate)
            if self.config.autonomy == "guarded":
                approval = self.request_approval()
                if not approval:
                    self.post_status("release", "awaiting approval")
                    return self.session

            self.context.release = self.execute_phase("release", release_skill,
                                                      context=self.context)
            self.update_session("release", self.context.release)
            self.post_status("release", "completed")
            self.post_status("workflow", "completed")

            return self.session

        except Exception as e:
            self.handle_error(e)
            raise

    def execute_phase(self, phase_name, skill, context=None):
        """Execute a phase by delegating to skill"""
        skill_ref = self.resolve_skill(phase_name)

        request = {
            "operation": f"execute_{phase_name}",
            "work_id": self.work_id,
            "config": self.config,
            "context": context.to_dict() if context else {}
        }

        result = invoke_skill(skill_ref, request)
        return result

    def resolve_skill(self, phase_name):
        """Resolve which skill to use for phase (built-in, domain, or project override)"""
        if self.config.workflow.skills.get(phase_name):
            return self.config.workflow.skills[phase_name]
        else:
            return f"fractary-faber:{phase_name}"  # Default to built-in
```

## Appendix C: Skill Template

```markdown
# {Phase Name} Skill

<CONTEXT>
You are the {phase}-skill, responsible for {phase description}.
You receive {inputs} from the workflow-manager and produce {outputs}.
You have full context of all previous phases in the workflow.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER skip steps - execute workflow completely
2. ALWAYS update session state before returning
3. ALWAYS post status updates via work-manager
4. If operation fails, provide detailed error context
5. Use deterministic scripts for all shell operations
</CRITICAL_RULES>

<INPUTS>
## Required
- work_id: Work item identifier (e.g., "123", "PROJ-456")
- config: Project configuration from .faber.config.toml
- context: Full workflow context from previous phases

## Context Structure
```json
{
  "frame": {
    "work_item": {...},
    "work_type": "feature",
    "environment": {...}
  },
  "architect": {
    "spec_file": ".faber/specs/123.md",
    "commit_sha": "abc123",
    "key_decisions": [...]
  },
  // ... other phases
}
```
</INPUTS>

<WORKFLOW>
## Step 1: Load Context
- Extract relevant information from previous phases
- Load phase-specific configuration
- Validate prerequisites

## Step 2: Execute Phase Operations
- {Phase-specific operations}
- Use workflow/{implementation}.md for domain-specific logic
- Call scripts/ for deterministic operations

## Step 3: Update State
- Compile phase results
- Update session via core-skill
- Prepare output structure

## Step 4: Post Notification
- Create status card
- Post to work item via work-manager
- Include key results and next steps
</WORKFLOW>

<COMPLETION_CRITERIA>
1. All phase operations completed successfully
2. Session state updated with phase results
3. Status notification posted to work item
4. Output structure populated with all required fields
5. Any errors handled and reported
</COMPLETION_CRITERIA>

<OUTPUTS>
Return JSON structure:
```json
{
  "{phase}_specific_field": "value",
  "status": "success|failure",
  "artifacts": ["file1", "file2"],
  "next_phase_recommendations": "..."
}
```
</OUTPUTS>

<HANDLERS>
This skill uses workflow implementations:
- workflow/basic.md - Default implementation (batteries-included)
- workflow/{domain}.md - Domain-specific implementations (from domain plugins)

Load active workflow from config or use basic as fallback.
</HANDLERS>

<DOCUMENTATION>
Upon completion:
1. Log phase completion to session
2. Update status card on work item
3. Return results to workflow-manager
</DOCUMENTATION>

<ERROR_HANDLING>
If phase operations fail:
1. Capture detailed error context
2. Update session with failure state
3. Post error notification to work item
4. Return error structure to workflow-manager
5. Include recovery recommendations if applicable

Do NOT retry automatically - workflow-manager handles retry logic.
</ERROR_HANDLING>
```
