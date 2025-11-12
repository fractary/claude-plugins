---
org: fractary
system: claude-plugins
title: Manager-as-Agent Architectural Pattern
description: Complete explanation of why Manager must be an Agent and Director must be a Skill, with implementation guidance and trade-off analysis
tags: [architecture, manager, director, agent, skill, patterns, best-practices]
created: 2025-01-15
updated: 2025-01-15
version: 1.0
codex_sync_include: [*]
codex_sync_exclude: []
visibility: internal
---

# Manager-as-Agent Architectural Pattern

## Executive Summary

**Manager MUST be an Agent. Director MUST be a Skill.**

This is the **PRIMARY architectural pattern** for agentic control planes. Getting this wrong results in poor user experience, broken workflows, and limited capabilities.

**Quick Decision Guide:**
- **Manager**: Orchestrates workflow for ONE entity → **AGENT** with full tool access
- **Director**: Expands patterns for batch operations → **SKILL** for lightweight pattern parsing
- **Specialists**: Execute focused tasks → **SKILLS** with script abstraction

**Context Load Trade-offs:**
- Single operations (69% of usage): 2 context loads (NO CHANGE from any architecture)
- Batch operations (31% of usage): 20-112 context loads (higher, but 5x faster wall-clock time)

**Trade-off Justified:** Primary use case (single-entity) is optimized. Batch operations are rare but gain parallelism.

---

## Table of Contents

1. [Core Principles](#core-principles)
2. [Why Manager Must Be an Agent](#why-manager-must-be-an-agent)
3. [Why Director Must Be a Skill](#why-director-must-be-a-skill)
4. [Architecture Comparison](#architecture-comparison)
5. [Context Load Analysis](#context-load-analysis)
6. [Implementation Guide](#implementation-guide)
7. [Testing Strategy](#testing-strategy)
8. [Common Mistakes](#common-mistakes)
9. [Migration Path](#migration-path)
10. [Real-World Examples](#real-world-examples)

---

## Core Principles

### The Pattern

```
Single Entity Operation (PRIMARY - 69% of usage):
User → Command → Manager Agent → Specialist Skills → Results
                 (full tools)    (script-backed)
Context Loads: 2 (optimal)

Batch Operation (SECONDARY - 31% of usage):
User → Command → Director Skill → Core Claude Agent
                 (pattern expand)  ↓ (parallel invocations, max 5)
                                   ├─ Manager Agent #1 → Skills
                                   ├─ Manager Agent #2 → Skills
                                   ├─ Manager Agent #3 → Skills
                                   └─ ... → Aggregate Results
Context Loads: 20-112 (depends on parallelism factor)
Wall-Clock Time: 5x faster due to parallel execution
```

### Critical Rules

1. **Manager = AGENT** (orchestration with full capabilities)
   - Location: `.claude/agents/project/{name}-manager.md`
   - Tools: `[Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]`
   - Responsibility: Orchestrate 7-phase workflow for ONE entity
   - State: Maintains context across workflow phases
   - User Interaction: Natural approvals, error handling, decision points

2. **Director = SKILL** (simple pattern expansion)
   - Location: `.claude/skills/{name}-director/`
   - Responsibility: Parse patterns (`*`, `dataset/*`, `a,b,c`), expand wildcards, return list
   - Does NOT orchestrate: Returns to Core Claude Agent for parallel Manager invocations
   - No workflow logic: Pure pattern matching and expansion

3. **Specialists = SKILLS** (focused execution)
   - Location: `.claude/skills/{name}/`
   - Responsibility: Execute ONE specific task with script abstraction
   - Script-backed: Deterministic operations in `scripts/` directory
   - Minimal context: Focused interface, no orchestration logic

---

## Why Manager Must Be an Agent

### The 7 Reasons

#### 1. Complex Orchestration Requires Persistent State

**The Problem with Manager-as-Skill:**
```markdown
# Manager as Skill (❌ WRONG)
- Invoked per operation
- State lost between skill calls
- Can't track workflow progress
- No memory of previous phases
```

**Manager-as-Agent Solution:**
```markdown
# Manager as Agent (✅ CORRECT)
---
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---

## 7-Phase Workflow

Phase 1: INSPECT
- Invoke inspector skill
- Store results in workflow state ← STATE PERSISTS

Phase 2: ANALYZE
- Read workflow state from Phase 1 ← STATE AVAILABLE
- Invoke debugger if issues found

Phase 3: PRESENT
- Show analysis to user
- Reference state from Phases 1-2 ← STATE AVAILABLE

Phase 4: APPROVE
- Get user decision via AskUserQuestion ← AGENT CAPABILITY
- Store approval in workflow state

Phase 5: EXECUTE
- Invoke builder skills
- Track execution state

Phase 6: VERIFY
- Re-invoke inspector
- Compare with Phase 1 results ← STATE COMPARISON

Phase 7: REPORT
- Comprehensive report using all phase state ← FULL STATE CONTEXT
```

**Why This Matters:** Skills have no persistent state. Agents maintain context across the entire workflow.

#### 2. User Interaction Requires Agent Capabilities

**The Problem:**
```markdown
# Skill trying to get approval (❌ UNNATURAL)
Skill: "Operation requires approval. Please approve."
Core Agent: "The skill returned: 'needs approval'"
User: "approved"
Core Agent: "Invoking skill again with approval..."
Skill: "Approved, executing..."
```

**Agent Solution:**
```markdown
# Agent getting approval (✅ NATURAL)
Manager Agent: "I've analyzed the changes. Here's what will happen:
- Update 3 catalog tables
- Sync 14 data files
- Run 2 validation tests

This operation will modify production infrastructure.

Do you want to proceed?"

[User clicks "Proceed" or "Cancel"]

Manager Agent: "Proceeding with execution..."
```

**Why This Matters:** AskUserQuestion tool only works naturally in agent context. Skills can't have conversational interaction.

#### 3. Error Handling Needs Full Tool Access

**Manager-as-Skill (❌ LIMITED):**
```markdown
# Skill encounters error
- Can't read log files (limited Read access)
- Can't check system state (limited Bash access)
- Can't propose fixes (no AskUserQuestion)
- Returns error string, hope someone handles it
```

**Manager-as-Agent (✅ FULL CAPABILITIES):**
```markdown
# Agent encounters error

1. READ error context:
   - Bash: Check system state, read logs
   - Read: Examine configuration files
   - Grep: Search for error patterns

2. ANALYZE:
   - Invoke debugger skill with full context
   - Cross-reference knowledge base
   - Calculate confidence score

3. PROPOSE solution:
   - AskUserQuestion: "I found issue X. I can fix it by doing Y.
                      Confidence: 85%. Proceed with auto-fix?"

4. EXECUTE fix:
   - Write: Update configuration
   - Bash: Run repair commands
   - Skill: Invoke builder to apply fix

5. VERIFY:
   - Re-invoke inspector
   - Confirm resolution
```

**Why This Matters:** Error recovery requires investigation, decision-making, and execution across multiple tools. Skills can't do this.

#### 4. State Management Requires File Operations

**The Pattern:**
```json
// state.json - Workflow state tracked by Manager
{
  "entity": "dataset/users",
  "workflow_phase": "verify",
  "phases_completed": ["inspect", "analyze", "present", "approve", "execute"],
  "inspection_results": {
    "issues_found": ["missing_schema_version"],
    "fix_confidence": 0.85
  },
  "execution_results": {
    "files_updated": ["catalog.json", "schema.sql"],
    "tests_passed": true
  },
  "approval": {
    "user": "approved",
    "timestamp": "2025-01-15T14:30:00Z"
  }
}
```

**Manager-as-Agent Can:**
- Read: Load state.json at workflow start
- Write: Update state after each phase
- Edit: Modify specific state fields
- Bash: Atomic file locking for concurrent safety

**Manager-as-Skill Cannot:**
- Limited/no Write access
- No persistent state between invocations
- State management becomes external coordination problem

**Why This Matters:** Workflow orchestration REQUIRES state management. Agents can do this naturally.

#### 5. Skill Coordination Needs Sequential Control Flow

**7-Phase Workflow Must Execute in Order:**
```
INSPECT → ANALYZE → PRESENT → APPROVE → EXECUTE → VERIFY → REPORT
```

**Manager-as-Agent (✅ ENFORCES ORDER):**
```markdown
def orchestrate_workflow(entity):
    # Phase 1: INSPECT (mandatory first)
    inspection = invoke_skill("inspector", operation="full-check")
    state["inspection"] = inspection

    # Phase 2: ANALYZE (conditional on issues)
    if inspection["issues_found"]:
        analysis = invoke_skill("debugger", issues=inspection["issues_found"])
        state["analysis"] = analysis

    # Phase 3: PRESENT (show user what will happen)
    present_plan_to_user(state)

    # Phase 4: APPROVE (get user decision)
    approval = ask_user_question("Proceed with execution?")
    if not approval:
        return "Workflow cancelled by user"
    state["approval"] = approval

    # Phase 5: EXECUTE (only if approved)
    execution = invoke_skill("builder", operation=analysis["recommended_fix"])
    state["execution"] = execution

    # Phase 6: VERIFY (re-inspect to confirm)
    verification = invoke_skill("inspector", operation="full-check")
    state["verification"] = verification

    # Phase 7: REPORT (comprehensive results)
    generate_report(state)
```

**Manager-as-Skill (❌ COORDINATION PROBLEM):**
- External orchestrator must coordinate skill calls
- State passed externally between skill invocations
- Order enforcement becomes caller's responsibility
- Error handling distributed across callers

**Why This Matters:** Agents have control flow. Skills are stateless execution units.

#### 6. Retry Logic and Recovery Need Decision-Making

**Scenario: Test Fails After Execution**

**Manager-as-Agent (✅ INTELLIGENT RECOVERY):**
```markdown
Phase 6: VERIFY
- Re-invoke inspector
- Inspector reports: "Test failed: data_validation_error"

Manager Decision Logic:
1. Check confidence score of original fix
2. If confidence was high (≥80%), likely new issue
   → Invoke debugger to analyze failure
   → Present options to user

3. If confidence was low (<80%), might be expected
   → Ask user: "Test failed. This fix had 65% confidence.
                Options: 1) Try alternative fix, 2) Manual intervention, 3) Rollback"

4. Based on user choice:
   → Retry with alternative (invoke builder again)
   → Wait for manual fix (pause workflow)
   → Rollback changes (invoke builder with rollback operation)
```

**Manager-as-Skill (❌ NO RECOVERY LOGIC):**
- Skill returns failure
- External caller must decide what to do
- No access to confidence scores or historical context
- No natural way to ask user for decision
- Retry logic external, fragile

**Why This Matters:** Complex workflows fail. Agents can recover intelligently.

#### 7. Single Responsibility: ONE Entity Per Workflow

**Manager's Job:**
- Orchestrate complete lifecycle for **ONE** entity
- Maintain full context for that entity throughout workflow
- Make decisions specific to that entity's state
- Coordinate all skills for that entity's operations

**Why Agent, Not Skill:**
- Entity lifecycle is complex (7 phases)
- Requires persistent state across phases
- Needs user interaction at decision points
- Must coordinate multiple specialist skills
- Error recovery specific to entity state

**Batch Operations:**
- Core Claude Agent invokes Manager N times (parallel)
- Each Manager instance handles ONE entity independently
- Proper isolation: One entity's failure doesn't affect others
- Natural parallelism: Core Agent manages concurrent execution

---

## Why Director Must Be a Skill

### The 5 Reasons

#### 1. Director's Job Is Simple Pattern Expansion

**ALL Director Does:**
```markdown
Input: Pattern string from user
- Examples: "*", "dataset/*", "ipeds/hd,ipeds/ic,nces/ccd"

Operations:
1. Parse pattern (identify wildcard vs. comma-separated)
2. Expand wildcards (glob matching against available entities)
3. Validate entities exist
4. Return list of entity identifiers

Output:
{
  "entities": ["dataset/users", "dataset/orders", "dataset/products"],
  "parallelism_recommendation": 5
}
```

**That's It.** No orchestration. No workflow logic. No state management. Pure pattern matching.

**Why Skill:** This is a focused, stateless transformation. Perfect for skill abstraction.

#### 2. Director Should NOT Orchestrate

**Wrong (Director as Agent doing orchestration):**
```markdown
# Director Agent (❌ OVER-ENGINEERED)

def handle_batch_request(pattern):
    # Expand pattern
    entities = expand_pattern(pattern)

    # Loop over entities (WRONG - prevents parallelism)
    results = []
    for entity in entities:
        result = invoke_manager_agent_via_task_tool(entity)  # Sequential!
        results.append(result)

    # Aggregate results
    return aggregate(results)
```

**Problems:**
- Sequential execution (slow)
- Can't leverage Core Agent's parallel invocation capability
- Over-engineered for simple pattern expansion
- Agent overhead for stateless operation

**Correct (Director as Skill, Core Agent orchestrates):**
```markdown
# Director Skill (✅ LIGHTWEIGHT)

def expand_pattern(pattern):
    if "*" in pattern:
        return glob_match(pattern, available_entities())
    elif "," in pattern:
        return pattern.split(",")
    else:
        return [pattern]

# Core Claude Agent then invokes Manager agents in parallel
```

**Why Skill:** Director should just expand patterns, not orchestrate. Core Agent handles parallelism better.

#### 3. Core Claude Agent Is Better at Parallelism

**Built-in Capabilities:**
- Core Agent can invoke up to 5 agents concurrently via Task tool
- Proper error isolation between parallel executions
- Natural aggregation of results
- No custom parallelism code needed

**Director-as-Agent Limitations:**
- Agents can't spawn parallel agent invocations easily
- Would need custom threading/async code
- Error handling becomes complex
- Result aggregation manual

**Pattern:**
```
Director Skill returns: ["entity1", "entity2", "entity3", "entity4", "entity5"]

Core Agent automatically does:
Task(manager-agent, entity="entity1") ← Parallel
Task(manager-agent, entity="entity2") ← Parallel
Task(manager-agent, entity="entity3") ← Parallel
Task(manager-agent, entity="entity4") ← Parallel
Task(manager-agent, entity="entity5") ← Parallel

Waits for all to complete, aggregates results
```

**Why Skill:** Leverage Core Agent's built-in parallelism instead of reimplementing it.

#### 4. Director Is Underutilized (31% of Operations)

**Usage Statistics:**
- **69% of operations**: Single entity (skip Director entirely)
- **31% of operations**: Batch (use Director for pattern expansion)

**Implication:** Director is SECONDARY pattern, not primary

**Architecture Priority:**
1. **Optimize for primary use case** (single-entity via Manager Agent) → 2 context loads
2. **Secondary use case acceptable** (batch via Director Skill) → Higher context loads but 5x faster

**Why Skill:** Don't over-engineer underutilized component. Keep it lightweight.

#### 5. No State Management Needed

**Director Has No State:**
- Pattern expansion is stateless transformation
- Input: pattern string
- Output: list of entity IDs
- No workflow to track
- No decisions to make
- No user interaction needed
- No error recovery logic

**Why Skill:** Stateless operations are perfect for skills. Don't waste agent overhead.

---

## Architecture Comparison

### Manager-as-Skill + Director-as-Agent (❌ INVERTED)

```
Location:
- .claude/skills/myproject-manager/  (WRONG)
- .claude/agents/project/director.md (WRONG)

Single Entity Operation:
Command → Director Agent → Manager Skill → Specialist Skills
          (unnecessary)    (limited tools)

Problems:
- Manager can't use AskUserQuestion naturally
- Manager has no persistent state
- Manager has limited tool access
- Director unnecessary for single operations
- Extra context load from Director agent

Batch Operation:
Command → Director Agent → (sequential loop)
                           ├─ Manager Skill #1
                           ├─ Manager Skill #2
                           └─ Manager Skill #3

Problems:
- Sequential execution (no parallelism)
- Director doing orchestration (wrong layer)
- Manager skills have no state isolation
- Slow wall-clock time
```

### Manager-as-Agent + Director-as-Skill (✅ CORRECT)

```
Location:
- .claude/agents/project/myproject-manager.md (CORRECT)
- .claude/skills/myproject-director/          (CORRECT)

Single Entity Operation (PRIMARY - 69%):
Command → Manager Agent → Specialist Skills
          (full tools)    (script-backed)

Benefits:
- Manager has full agent capabilities
- Natural user interaction
- Persistent state across workflow
- Optimal context usage (2 loads)
- No Director overhead

Batch Operation (SECONDARY - 31%):
Command → Director Skill → Core Claude Agent
          (pattern expand) ↓ (parallel, max 5)
                           ├─ Manager Agent #1 → Skills
                           ├─ Manager Agent #2 → Skills
                           ├─ Manager Agent #3 → Skills
                           └─ ... → Aggregate

Benefits:
- Parallel execution (5x faster)
- Manager instances have full capabilities
- Proper error isolation
- Core Agent handles orchestration
- Director stays lightweight
```

---

## Context Load Analysis

### Single Entity Operations (69% of Usage)

**All Architectures (Including Manager-as-Agent):**
```
User → Command → Manager → Skills → Results
Context Loads: 2 (Command load + Manager load)
```

**Conclusion:** **NO CHANGE** from any architecture. Optimized.

### Batch Operations (31% of Usage)

**Manager-as-Skill + Director-as-Agent (Sequential):**
```
Context Loads: 2 (Command + Director)
Wall-Clock Time: N × single_operation_time (sequential)
Parallelism: None

Example (10 entities):
- Context: 2 loads total
- Time: 10 × 45 seconds = 450 seconds (7.5 minutes)
```

**Manager-as-Agent + Director-as-Skill (Parallel):**
```
Context Loads: 1 (Command) + 1 (Director Skill) + N (Manager Agents)
               = 2 + N context loads

Parallelism: Up to 5 concurrent Manager invocations
Wall-Clock Time: ⌈N / 5⌉ × single_operation_time

Example (10 entities, 5 parallel):
- Context: 2 + 10 = 12 loads total (vs 2 in sequential)
- Time: ⌈10 / 5⌉ × 45 seconds = 2 × 45 = 90 seconds (1.5 minutes)
- Speedup: 7.5 min → 1.5 min = 5x faster
```

**Trade-off Analysis:**

| Factor | Sequential (Inverted) | Parallel (Correct) | Winner |
|--------|----------------------|-------------------|---------|
| Context Loads (Single) | 2 | 2 | Tie ✅ |
| Context Loads (Batch) | 2 | 2 + N | Inverted |
| Wall-Clock Time (Batch) | N × T | ⌈N/5⌉ × T | Correct ✅ |
| Primary Use Case (69%) | Optimal | Optimal | Tie ✅ |
| Manager Capabilities | Limited (Skill) | Full (Agent) | Correct ✅ |
| User Experience | Poor | Excellent | Correct ✅ |

**Verdict:** Manager-as-Agent wins on what matters:
- Primary use case (69%) unaffected ✅
- Batch operations 5x faster despite higher context ✅
- Manager has full capabilities ✅
- Better user experience ✅

Context load increase for batch (31% of operations) is acceptable trade-off for massive performance gain.

---

## Implementation Guide

### Step 1: Create Manager Agent

**File:** `.claude/agents/project/{project}-{domain}-manager.md`

```markdown
---
name: {project}-{domain}-manager
description: Orchestrates {domain} workflows for single entities with 7-phase process
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---

# {Project} {Domain} Manager

<CONTEXT>
You are the {Domain} Manager for {Project}. You orchestrate complete workflows
for a **single {entity}** using the 7-phase pattern: Inspect → Analyze → Present
→ Approve → Execute → Verify → Report.

You maintain state throughout the workflow and coordinate specialist skills.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS maintain workflow state in state.json
2. ALWAYS use specialist skills for execution (never do work directly)
3. ALWAYS get user approval before making changes (via AskUserQuestion)
4. ALWAYS verify after execution (re-invoke inspector)
5. NEVER proceed after failures without user decision
</CRITICAL_RULES>

<WORKFLOW>

## Phase 1: INSPECT
- Invoke {project}-{domain}-inspector skill
- Store inspection results in workflow state

## Phase 2: ANALYZE
- If issues found, invoke {project}-{domain}-debugger skill
- Calculate confidence scores
- Determine recommended fixes

## Phase 3: PRESENT
- Show user what will be done
- Explain confidence levels
- Highlight risks

## Phase 4: APPROVE
- Use AskUserQuestion to get user decision
- Options: proceed, modify, or cancel
- Store approval in workflow state

## Phase 5: EXECUTE
- Invoke {project}-{domain}-builder skill(s)
- Track execution progress
- Handle errors gracefully

## Phase 6: VERIFY
- Re-invoke inspector to confirm success
- Compare with Phase 1 results
- Validate all changes applied correctly

## Phase 7: REPORT
- Comprehensive summary of all phases
- Show before/after state
- Propose next steps if any

</WORKFLOW>

<STATE_MANAGEMENT>
Use state.json to track:
- entity: Current entity being processed
- workflow_phase: Current phase (inspect/analyze/present/approve/execute/verify/report)
- phases_completed: List of completed phases
- inspection_results: From Phase 1
- analysis_results: From Phase 2 (if issues)
- approval: User decision from Phase 4
- execution_results: From Phase 5
- verification_results: From Phase 6
</STATE_MANAGEMENT>

<AVAILABLE_SKILLS>
- {project}-{domain}-inspector: Check entity state
- {project}-{domain}-debugger: Analyze issues, recommend fixes
- {project}-{domain}-builder: Execute operations
- {project}-{domain}-tester: Validate results
</AVAILABLE_SKILLS>
```

### Step 2: Create Director Skill (Optional, for Batch Operations)

**File:** `.claude/skills/{project}-{domain}-director/SKILL.md`

```markdown
---
skill: {project}-{domain}-director
purpose: Expand batch patterns for parallel Manager invocation
layer: Pattern Expander
---

# {Project} {Domain} Director

## Purpose

Lightweight pattern expansion for batch operations. Parses patterns like `*`,
`domain/*`, `a,b,c` and returns list of entity IDs for Core Claude Agent to
invoke Manager agents in parallel.

## Operations

### expand-pattern

Parse and expand batch pattern to entity list.

**Invocation:**
```json
{
  "operation": "expand-pattern",
  "pattern": "dataset/*"
}
```

**Implementation:**
```bash
# Invoke pattern expansion script
scripts/expand-pattern.sh --pattern "$pattern" --entities-dir "path/to/entities"
```

**Output:**
```json
{
  "entities": ["dataset/users", "dataset/orders", "dataset/products"],
  "count": 3,
  "parallelism_recommendation": 3
}
```

**Script:** `scripts/expand-pattern.sh`

## Critical Constraints

- Does NOT invoke Manager agents (Core Claude Agent does this)
- Does NOT orchestrate workflows
- Does NOT aggregate results
- Pure pattern expansion only

## Usage Pattern

1. Command receives batch pattern from user
2. Command invokes Director skill to expand pattern
3. Director returns entity list to Core Claude Agent
4. Core Agent invokes Manager agent for each entity (parallel, max 5)
5. Core Agent aggregates results and returns to user
```

---

## Testing Strategy

**Manager Agent Tests:**
1. Test each workflow phase independently
2. Verify state management (state.json updates)
3. Test error handling in each phase
4. Verify skill invocation parameters
5. Test user interaction flows (AskUserQuestion)

**Director Skill Tests:**
1. Test wildcard expansion (`*`, `domain/*`)
2. Test comma-separated parsing (`a,b,c`)
3. Test entity validation
4. Test error handling (invalid patterns)
5. Verify parallelism recommendations

**Integration Tests:**
1. Single entity workflow end-to-end
2. Batch workflow with 2-3 entities
3. Batch workflow with 10+ entities (test parallelism)
4. Error recovery scenarios
5. State persistence across phases

---

## Common Mistakes

### Mistake 1: Implementing Manager as Skill

**Symptom:** `.claude/skills/myproject-manager/`

**Problem:** Manager has no agent capabilities, workflows broken

**Fix:** Move to `.claude/agents/project/myproject-manager.md`, add `allowed_tools`

### Mistake 2: Implementing Director as Agent

**Symptom:** Director in `.claude/agents/` doing orchestration

**Problem:** Sequential execution, prevents parallelism, over-engineered

**Fix:** Convert to `.claude/skills/myproject-director/`, return entity list to Core Agent

### Mistake 3: Manager Doing Execution Work

**Problem:** Manager should orchestrate, not execute

**Fix:** Create specialist skills for execution, Manager invokes via Skill tool

### Mistake 4: Not Using AskUserQuestion

**Problem:** No user interaction, no approval workflow

**Fix:** Use AskUserQuestion tool properly in Manager agent

### Mistake 5: No State Management

**Problem:** No context across phases, can't verify changes

**Fix:** Implement state.json management in Manager agent

---

## Migration Path

See companion document: `agent-to-skill-migration.md`

**Quick Migration:**
1. Identify if Manager is currently a skill
2. Move Manager to `.claude/agents/project/`
3. Add `allowed_tools` declaration
4. Implement state management
5. Add user interaction flows
6. If Director exists as agent, demote to skill
7. Update command routing
8. Test thoroughly

---

## Summary

**Manager-as-Agent Pattern Is Mandatory Because:**

1. **Complex Orchestration** - 7-phase workflow needs persistent state
2. **User Interaction** - AskUserQuestion only works naturally in agents
3. **Full Tool Access** - Error handling requires complete tool suite
4. **State Management** - Workflow state must persist across phases
5. **Skill Coordination** - Sequential control flow with decision points
6. **Retry Logic** - Intelligent recovery needs agent capabilities
7. **Single Responsibility** - ONE entity per workflow with full context

**Director-as-Skill Pattern Is Mandatory Because:**

1. **Simple Job** - Pure pattern expansion, no orchestration
2. **Should Not Orchestrate** - Core Agent better at parallelism
3. **Core Agent Parallelism** - Built-in parallel invocation
4. **Underutilized** - Only 31% of operations use batch
5. **No State** - Stateless transformation

**Context Trade-offs Are Justified:**
- Primary use case (69%): Optimized
- Secondary use case (31%): Higher context but 5x faster
- User experience: Excellent
- Maintainability: Clear separation of concerns
