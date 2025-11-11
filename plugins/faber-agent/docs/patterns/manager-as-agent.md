---
pattern: Manager-as-Agent
category: Core Architecture
difficulty: intermediate
tags: [manager, agent, orchestration, workflow]
version: 1.0
---

# Pattern: Manager-as-Agent

## Intent

Implement workflow orchestration for a single entity using an Agent with full capabilities, enabling complex state management, natural user interaction, and intelligent error handling.

## Problem

Orchestrating multi-phase workflows for entities requires:
- Persistent state across workflow phases
- Natural user interaction and approval flows
- Full tool access for investigation and recovery
- Coordination of multiple specialist skills
- Graceful error handling with retry logic

Skills cannot provide these capabilities due to limited tool access and no persistent state.

## Solution

**Create Manager as an AGENT** with full tool suite and implement 7-phase workflow pattern.

```
Location: .claude/agents/project/{project}-{domain}-manager.md

Tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]

Workflow: Inspect → Analyze → Present → Approve → Execute → Verify → Report
```

## Structure

```markdown
---
name: {project}-{domain}-manager
description: Orchestrates {domain} workflows for single entities
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---

# {Project} {Domain} Manager

<CONTEXT>
You orchestrate workflows for a **single {entity}** using 7-phase pattern.
You maintain state and coordinate specialist skills.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS maintain workflow state
2. ALWAYS use skills for execution (never do work directly)
3. ALWAYS get user approval before changes
4. ALWAYS verify after execution
5. NEVER proceed after failures without user decision
</CRITICAL_RULES>

<WORKFLOW>

## Phase 1: INSPECT
Invoke inspector skill, store results in state

## Phase 2: ANALYZE (conditional)
If issues, invoke debugger skill

## Phase 3: PRESENT
Show user the plan

## Phase 4: APPROVE
AskUserQuestion for decision

## Phase 5: EXECUTE
Invoke builder skill(s)

## Phase 6: VERIFY
Re-invoke inspector to confirm

## Phase 7: REPORT
Comprehensive summary

</WORKFLOW>

<STATE_MANAGEMENT>
File: .{project}/state/{entity}/workflow-state.json

Track:
- entity, operation, workflow_phase
- phases_completed
- inspection_results, analysis_results
- user_approval, execution_results
- verification_results
</STATE_MANAGEMENT>

<AVAILABLE_SKILLS>
- {project}-{domain}-inspector
- {project}-{domain}-debugger
- {project}-{domain}-builder
- {project}-{domain}-validator
</AVAILABLE_SKILLS>
```

## Applicability

Use this pattern when:
- ✅ Managing lifecycle of individual entities (users, datasets, services, etc.)
- ✅ Multi-step workflow (3+ phases) required
- ✅ User approval needed at decision points
- ✅ State must persist across workflow
- ✅ Error recovery needs investigation and decision-making
- ✅ 69% of operations are single-entity (this is PRIMARY pattern)

Don't use when:
- ❌ Simple one-step operations (use skill directly)
- ❌ Fully deterministic (no decisions - use script)
- ❌ Batch pattern expansion only (use Director Skill)

## Consequences

**Benefits:**
- ✅ Full agent capabilities (all tools available)
- ✅ Natural user interaction via AskUserQuestion
- ✅ Persistent state across entire workflow
- ✅ Intelligent error handling and recovery
- ✅ Clear separation: Manager orchestrates, Skills execute
- ✅ Optimal context usage for single-entity operations (2 loads)

**Trade-offs:**
- ⚠️ More structure required than simple skill
- ⚠️ Batch operations have higher context load (but 5x faster with parallelism)

**Anti-Patterns to Avoid:**
- ❌ Manager as Skill (loses agent capabilities)
- ❌ Manager doing execution work (use skills instead)
- ❌ No state management (can't track progress)
- ❌ Skipping user approval (violates user control)

## Implementation

### 1. Create Manager Agent File

```bash
# Location
mkdir -p .claude/agents/project
touch .claude/agents/project/myproject-manager.md
```

### 2. Define Tool Access

```yaml
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
```

**Why each tool:**
- Read: Load state, configuration, logs
- Write: Save state, create reports
- Skill: Invoke specialist skills
- AskUserQuestion: Natural user approval
- Bash: System checks, error investigation
- Edit: Update state fields
- Grep: Search logs for patterns
- Glob: Find files matching patterns

### 3. Implement 7-Phase Workflow

**Phase 1: INSPECT** - What IS (facts only)
```markdown
Invoke: {project}-inspector skill
Store: inspection_results in state
```

**Phase 2: ANALYZE** - WHY + HOW (if issues)
```markdown
If issues found:
  Invoke: {project}-debugger skill
  Store: analysis_results with confidence scores
```

**Phase 3: PRESENT** - Show user the plan
```markdown
Display:
- Current entity state
- Issues found (if any)
- Recommended actions
- Confidence levels
- Risks/impacts
```

**Phase 4: APPROVE** - Get user decision
```markdown
AskUserQuestion: "Proceed with {operation}?"
Options: Proceed, Modify, Cancel
Store: user_approval in state
```

**Phase 5: EXECUTE** - Do the work
```markdown
Invoke: {project}-builder skill(s)
Track: execution progress
Handle: errors gracefully
Store: execution_results in state
```

**Phase 6: VERIFY** - Confirm success
```markdown
Re-invoke: {project}-inspector
Compare: with Phase 1 results
Validate: changes applied correctly
```

**Phase 7: REPORT** - Comprehensive summary
```markdown
Show:
- Before/after state
- All phases completed
- Any warnings
- Next steps
```

### 4. Implement State Management

**State File Location:**
```
.{project}/state/{entity}/workflow-state.json
```

**State Structure:**
```json
{
  "entity": "user-service",
  "operation": "validate",
  "workflow_phase": "verify",
  "phases_completed": ["inspect", "analyze", "present", "approve", "execute"],
  "started_at": "2025-01-15T10:30:00Z",
  "inspection_results": {...},
  "analysis_results": {...},
  "user_approval": {...},
  "execution_results": {...},
  "verification_results": {...}
}
```

**State Operations:**
- Load at workflow start: `Read(state.json)`
- Update after each phase: `Edit(state.json)` or `Write(state.json)`
- Use for Phase 6 comparison: `Read(state.json)` → compare inspection_results

## Examples

### Example 1: Data Validation Manager

```markdown
---
name: myproject-data-manager
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---

<WORKFLOW>

## Phase 1: INSPECT
Invoke: myproject-data-inspector
Check: Schema valid, data quality, completeness

## Phase 2: ANALYZE
If issues:
  Invoke: myproject-data-debugger
  Get: Recommended fixes with confidence

## Phase 3: PRESENT
Show: Current state, issues, fixes, risks

## Phase 4: APPROVE
Ask: "Fix {count} issues? (Confidence: {avg_confidence}%)"

## Phase 5: EXECUTE
Invoke: myproject-data-fixer
Apply: Recommended fixes

## Phase 6: VERIFY
Re-invoke: myproject-data-inspector
Confirm: All issues resolved

## Phase 7: REPORT
Summary: Before/after metrics, fixes applied

</WORKFLOW>
```

### Example 2: Deployment Manager

```markdown
<WORKFLOW>

## Phase 1: INSPECT
Invoke: infrastructure-inspector
Check: Current deployment state, health checks

## Phase 2: ANALYZE
If issues:
  Invoke: infrastructure-debugger
  Determine: Safe to deploy?

## Phase 3: PRESENT
Show: Deployment plan, affected services, rollback plan

## Phase 4: APPROVE
Ask: "Deploy to {environment}? This will affect {count} users."

## Phase 5: EXECUTE
Invoke: infrastructure-deployer
Deploy: New version
Monitor: Health checks

## Phase 6: VERIFY
Re-invoke: infrastructure-inspector
Confirm: Deployment successful, all health checks passing

## Phase 7: REPORT
Summary: Deployment status, metrics before/after, next steps

</WORKFLOW>
```

## Related Patterns

- **Director Skill**: For batch operations (wildcards, comma-separated lists)
- **Specialist Skills**: Execution units invoked by Manager
- **Builder/Debugger Pattern**: Specific skill organization pattern

## Known Uses

- **Lake.Corthonomy.AI**: Data management workflows (47 datasets)
  - Manager: corthonomy-table-manager (Agent)
  - Results: 13x context reduction, 94.1% success rate

- **BlogPro**: Content management workflows
  - Manager: blogpro-article-manager (Agent)
  - Results: Natural approval flows, 75% single-article operations

## Tags

`#manager` `#agent` `#orchestration` `#workflow` `#7-phase` `#state-management` `#user-interaction`
