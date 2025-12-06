---
spec_id: WORK-00262-default-build-skill-planning-and-autonomy
work_id: 262
issue_url: https://github.com/fractary/claude-plugins/issues/262
title: Default build skill planning and autonomy
type: feature
status: draft
created: 2025-12-06
author: fractary
validated: false
source: conversation+issue
---

# Feature Specification: Default Build Skill Planning and Autonomy

**Issue**: [#262](https://github.com/fractary/claude-plugins/issues/262)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-06

## Summary

Enhance or create a default build skill in the FABER plugin that implements specs with high autonomy. The skill should encourage Claude to think deeply about implementation planning before executing, run to completion without unnecessary pauses, and provide meaningful progress checkpoints through spec updates, commits, and issue comments. This addresses the current limitations of hook-based progress tracking (auto-commit on stop, auto-comment on stop) which are inefficient for long-running autonomous sessions.

## Problem Statement

### Current Issues with Hook-Based Progress Tracking

1. **Inefficient Hook Execution**: The current `commit-on-stop` and `comment-on-stop` hooks run on every stop event, even when:
   - No code changes were made
   - There's nothing meaningful to commit or comment on
   - This wastes significant time and context

2. **Inadequate for Autonomous Sessions**: In long-running autonomous sessions:
   - There are no natural "stops" to trigger hooks
   - More work accumulates than is ideal between commits
   - Progress goes unreported until session ends

3. **Claude's Tendency to Stop Prematurely**: Claude frequently:
   - Stops when context is running low
   - Suggests "pausing for now and picking it up later"
   - Proposes "breaking into a future phase"
   - This undermines autonomous workflow goals

## User Stories

### US1: Autonomous Spec Implementation
**As a** developer using FABER workflows
**I want** the build skill to implement specs completely without stopping
**So that** I can trust autonomous sessions to run to completion without manual intervention

**Acceptance Criteria**:
- [ ] Build skill reads spec and creates detailed implementation plan before coding
- [ ] Build skill continues implementation without asking for confirmation at each step
- [ ] Build skill handles context compaction gracefully and continues
- [ ] Build skill does not suggest "stopping for now" or "future phases"

### US2: Meaningful Progress Checkpoints
**As a** developer monitoring autonomous sessions
**I want** regular progress updates through commits and issue comments
**So that** I can track what's being done without interrupting the session

**Acceptance Criteria**:
- [ ] Spec is updated to reflect implementation progress
- [ ] Commits are made after meaningful work chunks (not on every stop)
- [ ] Issue comments summarize progress and next steps
- [ ] Progress tracking doesn't rely on session stop events

### US3: Efficient Resource Usage
**As a** developer running autonomous workflows
**I want** progress tracking to be efficient
**So that** context and time aren't wasted on empty commits/comments

**Acceptance Criteria**:
- [ ] No empty commits when no code changes exist
- [ ] No redundant comments when nothing new to report
- [ ] Progress checkpoints occur at logical implementation boundaries

## Functional Requirements

- **FR1**: Build skill MUST read the latest spec before implementation
- **FR2**: Build skill MUST create a detailed step-by-step implementation plan
- **FR3**: Build skill MUST execute the plan without stopping for confirmation
- **FR4**: Build skill MUST NOT suggest "pausing" or "future phases" due to context limits
- **FR5**: Build skill MUST update spec progress using fractary-spec plugin after meaningful work
- **FR6**: Build skill MUST commit code using fractary-repo plugin after meaningful implementation chunks
- **FR7**: Build skill MUST comment on issue using fractary-work plugin with progress summary
- **FR8**: Progress checkpoints MUST be triggered by implementation milestones, not stop events

## Non-Functional Requirements

- **NFR1**: Context efficiency - Progress tracking should minimize context consumption (performance)
- **NFR2**: Autonomy - Build skill should complete full spec without human intervention (usability)
- **NFR3**: Resilience - Build skill should handle context compaction and continue (reliability)
- **NFR4**: Observability - Progress should be visible through git history and issue timeline (observability)

## Technical Design

### Architecture Changes

The build skill will be structured as a SKILL.md file in the FABER plugin that:
1. Uses a "think hard" prompting pattern to encourage deep planning
2. Implements progress checkpoints at logical milestones (not on stops)
3. Integrates with spec, repo, and work plugins for progress reporting

```
plugins/faber/skills/build-implementer/
├── SKILL.md                    # Main skill definition with autonomy-focused prompts
├── workflow/
│   ├── implement-from-spec.md  # Step-by-step implementation workflow
│   └── progress-checkpoint.md  # Checkpoint workflow (update spec, commit, comment)
└── templates/
    └── progress-comment.md.template  # Template for issue progress comments
```

### Core Prompt Design

The key prompt elements to encourage autonomy:

```markdown
<CRITICAL_RULES>
1. Read the latest spec and think DEEPLY about a detailed step-by-step plan
2. Document your complete implementation plan BEFORE writing any code
3. Execute the plan IN ITS ENTIRETY without stopping for confirmation
4. NEVER suggest "pausing for now" or "breaking into phases" - complete the full spec
5. If context runs low, let auto-compaction happen and CONTINUE working
6. After completing meaningful implementation chunks, trigger progress checkpoint
</CRITICAL_RULES>
```

### Progress Checkpoint Integration

The build skill will call progress checkpoints at logical boundaries:

```markdown
## Progress Checkpoint Trigger Points

Trigger a checkpoint after:
1. Completing a major feature component
2. Finishing a phase from the implementation plan
3. Every 3-5 files modified (configurable)
4. Before starting a significantly different area of work

## Checkpoint Actions

1. **Update Spec Progress** (via fractary-spec:spec-updater)
   - Mark completed items in implementation plan
   - Add "Implementation Notes" section with decisions made

2. **Commit Changes** (via fractary-repo:commit-creator)
   - Stage all changed files
   - Create semantic commit message summarizing work
   - Include work_id reference

3. **Comment on Issue** (via fractary-work:comment-creator)
   - Summarize what was implemented since last checkpoint
   - List files created/modified
   - Describe next steps in plan
```

### Data Model

No new data models required. Uses existing:
- Spec files in `/specs/WORK-{id}-*.md`
- Git commits via repo plugin
- Issue comments via work plugin

### API Design

No external API changes. Internal skill invocation:

- `fractary-spec:spec-updater` - Update spec with progress
- `fractary-repo:commit-creator` - Create commits
- `fractary-work:comment-creator` - Post issue comments

### UI/UX Changes

No UI changes. Progress visible through:
- Git commit history
- GitHub issue timeline
- Updated spec file

## Implementation Plan

### Phase 1: Create Build Skill Structure
Create the basic skill structure with autonomy-focused prompting.

**Tasks**:
- [ ] Create `plugins/faber/skills/build-implementer/` directory structure
- [ ] Write SKILL.md with autonomy-focused CRITICAL_RULES
- [ ] Include "think hard" planning prompt pattern
- [ ] Add explicit instructions to never suggest stopping/pausing

### Phase 2: Implement Planning Workflow
Add workflow for reading spec and creating detailed implementation plan.

**Tasks**:
- [ ] Create `workflow/implement-from-spec.md` workflow file
- [ ] Define spec reading and analysis steps
- [ ] Define plan creation with explicit step documentation
- [ ] Add plan-before-code enforcement

### Phase 3: Implement Progress Checkpoints
Add checkpoint logic that doesn't depend on stop events.

**Tasks**:
- [ ] Create `workflow/progress-checkpoint.md` workflow file
- [ ] Define checkpoint trigger conditions
- [ ] Implement spec update integration
- [ ] Implement commit creation integration
- [ ] Implement issue comment integration
- [ ] Create `templates/progress-comment.md.template`

### Phase 4: Integrate with Default Workflow
Ensure the build skill is used in the FABER default workflow.

**Tasks**:
- [ ] Update default workflow to reference build-implementer skill
- [ ] Verify skill is invoked during build phase
- [ ] Test full FABER workflow with new skill

### Phase 5: Documentation and Testing
Document the skill and test thoroughly.

**Tasks**:
- [ ] Document skill usage in plugin docs
- [ ] Test with various spec types (small, medium, large)
- [ ] Verify checkpoint frequency is appropriate
- [ ] Confirm no empty commits/comments

## Files to Create/Modify

### New Files
- `plugins/faber/skills/build-implementer/SKILL.md`: Main skill definition with autonomy prompts
- `plugins/faber/skills/build-implementer/workflow/implement-from-spec.md`: Implementation workflow
- `plugins/faber/skills/build-implementer/workflow/progress-checkpoint.md`: Checkpoint workflow
- `plugins/faber/skills/build-implementer/templates/progress-comment.md.template`: Comment template

### Modified Files
- `plugins/faber/skills/faber-manager/workflow/phase-build.md`: Reference new build-implementer skill
- `plugins/faber/.claude-plugin/plugin.json`: Add new skill to manifest (if needed)
- `plugins/faber/config/faber.example.toml`: Document build skill configuration options

## Testing Strategy

### Unit Tests
- Verify SKILL.md parses correctly
- Verify workflow files have valid structure
- Verify template renders correctly

### Integration Tests
- Test skill invocation from FABER workflow
- Test spec update integration
- Test commit creation integration
- Test issue comment integration

### E2E Tests
- Run full FABER workflow with small spec
- Run full FABER workflow with medium spec (multiple checkpoints)
- Verify commits appear at expected intervals
- Verify issue comments reflect actual progress

### Performance Tests
- Measure context consumption of checkpoints
- Compare to hook-based approach
- Verify no regression in implementation speed

## Dependencies

- fractary-spec plugin (spec-updater skill) - for updating spec progress
- fractary-repo plugin (commit-creator skill) - for creating commits
- fractary-work plugin (comment-creator skill) - for posting issue comments
- FABER plugin (faber-manager) - for workflow orchestration

## Risks and Mitigations

- **Risk**: Claude may still suggest stopping despite prompts
  - **Likelihood**: Medium
  - **Impact**: High - defeats purpose of autonomy
  - **Mitigation**: Multiple reinforcing prompt elements, explicit NEVER rules, testing and iteration

- **Risk**: Checkpoints too frequent, consuming excess context
  - **Likelihood**: Low
  - **Impact**: Medium - reduces efficiency
  - **Mitigation**: Configurable checkpoint frequency, smart trigger logic

- **Risk**: Checkpoints too infrequent, losing work on failure
  - **Likelihood**: Medium
  - **Impact**: Medium - work loss on context overflow
  - **Mitigation**: Default to reasonable frequency, monitor and adjust

- **Risk**: spec-updater/commit-creator/comment-creator skills don't exist yet
  - **Likelihood**: High - needs verification
  - **Impact**: High - blocks implementation
  - **Mitigation**: Verify skill availability first, create stubs if needed

## Documentation Updates

- `plugins/faber/docs/BUILD-SKILL.md`: New documentation for build skill usage
- `plugins/faber/docs/AUTONOMY.md`: Document autonomy patterns and configuration
- `plugins/faber/README.md`: Reference new build skill

## Rollout Plan

1. **Alpha**: Create skill with basic functionality, test internally
2. **Beta**: Enable in development workflows, gather feedback
3. **GA**: Enable as default build skill in FABER plugin

## Success Metrics

- Autonomous completion rate: >90% of specs completed without manual intervention
- Checkpoint efficiency: <5% context overhead per checkpoint
- Commit frequency: 1 commit per major implementation unit (not per stop)
- Issue visibility: Clear progress trail in issue timeline

## Implementation Notes

### Key Insight: Think-First Pattern

The core innovation is the "think hard and plan first" prompt pattern:

```
"Read the latest spec and think hard about a detailed step by step plan
to implement the spec and then proceed to implement the spec in its
entirety without stopping."
```

This encourages:
1. Deep analysis before coding
2. Complete planning visible in output
3. Autonomous execution of the plan
4. No premature stopping

### Anti-Patterns to Avoid

The skill explicitly counters Claude's tendency to:
- Stop when context is low ("let's pause here")
- Split work into phases ("we can do this next time")
- Ask for confirmation at each step ("should I proceed?")
- Suggest incremental approaches ("let's start with X and see")

### Context Management

Rather than fighting context limits, the skill:
- Accepts that auto-compaction will happen
- Trusts Claude's compaction to preserve necessary context
- Explicitly instructs to continue after compaction
- Uses checkpoints to persist progress externally (git, issues)

### Checkpoint vs Hook Comparison

| Aspect | Hook-based (current) | Checkpoint-based (proposed) |
|--------|---------------------|----------------------------|
| Trigger | Every stop event | Implementation milestones |
| Efficiency | Low (many empty runs) | High (only when meaningful) |
| Autonomous sessions | Ineffective | Designed for |
| Context cost | Consistent overhead | Only when triggered |
| Work visibility | Sporadic | Regular, meaningful |
