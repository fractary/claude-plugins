---
org: corthos
system: lake.corthonomy.ai
title: Manager-as-Agent Architecture Refactor
spec_number: SPEC-024
status: draft
created: 2025-01-15
updated: 2025-01-15
authors: [AI-assisted design]
tags: [architecture, refactoring, manager, director, parallelism, control-plane]
codex_sync_includes: ["*"]
codex_sync_excludes: []
visibility: internal
---

# SPEC-024: Manager-as-Agent Architecture Refactor

## Executive Summary

Refactor the control plane architecture to convert Manager from a skill to an agent while demoting Director to a skill, enabling true parallelism for batch operations while providing Manager with full agent capabilities for its complex 7-phase workflow.

**Current State:**
- Manager is a skill (`.claude/skills/corthonomy-manager/`) with limited capabilities
- Director is an agent (`.claude/agents/project/table-director.md`) for batch coordination
- 69% of operations invoke Manager directly, bypassing Director

**Proposed State:**
- Manager becomes an agent with full state management and tool access
- Director becomes a skill invoked by Core Claude Agent for batch coordination
- Core Claude Agent handles parallel Manager invocations (max 5 concurrent)

**Trade-off:**
- Single operations: NO CHANGE (2 context loads)
- Batch operations: Increase from 2 → 112 loads (for 76 datasets @ 5 parallel)
- Benefit: Better workflow management, proper state handling, improved user interaction

## Background

### Current Architecture

The 3-layer agentic control plane implemented in October 2025 established clear separation of concerns:

```
Layer 1: Director (Commands) → Parse args, invoke Manager
Layer 2: Manager (Skill) → Orchestrate 7-phase workflow
Layer 3: Skills (12 specialists) → Execute operations
```

### Why Manager Was Originally a Skill

**October 2025 Decision Rationale:**
1. **Context Load Efficiency**: Avoid reloading CLAUDE.md multiple times
2. **Single Entry Point**: Director as primary user interface
3. **Batch Optimization**: Director handles wildcards with single context load
4. **Simplicity**: Fewer moving parts

### Why Change Is Needed Now

**Manager's Responsibilities Have Grown:**

1. **Complex State Management**
   - Tracks workflow across 7 phases
   - Manages user interactions and approvals
   - Coordinates multiple skill invocations
   - Requires persistent state across phases

2. **User Interaction Limitations**
   - As a skill, cannot naturally prompt users
   - Approval workflows feel unnatural
   - Error recovery is complex

3. **Tool Access Constraints**
   - Skills have limited tool access
   - Manager needs full Read/Write/Bash capabilities
   - State management requires file operations

4. **Real-World Usage Pattern**
   - 69% of operations are single-dataset (invoke Manager directly)
   - 31% are batch operations (invoke Director)
   - Director is underutilized for its complexity

5. **Director's Limited Value**
   - Most work happens in Manager anyway
   - Director is just a loop + aggregation
   - Could be a skill called by Core Agent
   - Parallelism could be handled by Core Agent

## Problem Statement

### Current Architecture Issues

**Issue #1: Manager Lacks Agent Capabilities**

Manager orchestrates complex workflows but can't:
- Maintain state across multiple skill invocations
- Interact naturally with users for approvals
- Handle errors gracefully with retry logic
- Access full tool suite for state management

**Issue #2: Director is Overengineered**

Director is an agent that primarily:
- Loops over datasets
- Invokes Manager for each
- Aggregates results

This could be a skill invoked by Core Claude Agent.

**Issue #3: No True Parallelism**

Current architecture can't parallelize Manager invocations because:
- Director is single-threaded
- Manager is a skill (can't be invoked in parallel)
- Batch operations are sequential

**Issue #4: Context Load Mismatch**

- Single operations: Manager invoked directly (efficient)
- Batch operations: Director → Manager (less efficient than needed)
- Parallelism would require Core Agent → Multiple Managers

### Usage Statistics

Based on command invocation patterns:

**Single Dataset Operations (50-80% of usage):**
- `/corthonomy-manage ipeds/hd`
- `/corthonomy-config-create ipeds/ic`
- Direct Manager invocation preferred

**Batch Operations (20-50% of usage):**
- `/corthonomy-manage ipeds/*` (14 datasets)
- `/corthonomy-manage *` (76 datasets)
- Pattern matching and parallelism needed

**User Insight:**
> "Core claude agent could be the one to invoke the parallel manage agents, leveraging a command/skill to do so for the director"

## Current Architecture (Detailed)

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                   USER INVOCATION                           │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│              LAYER 1: SLASH COMMANDS (7)                    │
│                                                             │
│  /corthonomy-manage [dataset]                               │
│  /corthonomy-config-create [dataset] [--complete]           │
│  /corthonomy-config-validate [dataset] [--complete]         │
│  /corthonomy-config-sync-schema [dataset] [--complete]      │
│  /corthonomy-config-update-version [dataset] [--complete]   │
│  /corthonomy-config-deploy [env]                            │
│  /corthonomy-config-document [dataset] [--complete]         │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
            ┌─────────┴─────────┐
            │                   │
            ↓                   ↓
┌───────────────────┐   ┌──────────────────┐
│  SINGLE DATASET   │   │   BATCH (*/,)    │
│  (69% of usage)   │   │  (31% of usage)  │
└─────────┬─────────┘   └────────┬─────────┘
          │                      │
          │                      ↓
          │           ┌──────────────────────────┐
          │           │  DIRECTOR AGENT          │
          │           │  (table-director.md)     │
          │           │  - Parse pattern         │
          │           │  - Expand wildcards      │
          │           │  - Loop datasets         │
          │           │  - Invoke Manager        │
          │           │  - Aggregate results     │
          │           └──────────┬───────────────┘
          │                      │
          └──────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│           LAYER 2: MANAGER SKILL (corthonomy-manager)       │
│           Location: .claude/skills/corthonomy-manager/      │
│                                                             │
│  7-Phase Workflow:                                          │
│  1. Inspect → corthonomy-auditor                            │
│  2. Analyze → corthonomy-debugger (if issues)               │
│  3. Present → Show plan to user                             │
│  4. Approve → Wait for user confirmation                    │
│  5. Execute → Invoke builders (catalog/data)                │
│  6. Verify → Re-inspect                                     │
│  7. Report → Comprehensive results                          │
│                                                             │
│  Limitations:                                               │
│  - Skill context (not agent)                                │
│  - Limited tool access                                      │
│  - No persistent state                                      │
│  - User interaction feels unnatural                         │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│             LAYER 3: SPECIALIST SKILLS (12)                 │
│                                                             │
│  Observers:                                                 │
│  - corthonomy-auditor: WHAT IS                              │
│                                                             │
│  Analyzers:                                                 │
│  - corthonomy-debugger: WHY + HOW TO FIX                    │
│                                                             │
│  Builders:                                                  │
│  - corthonomy-catalog-builder: Catalog operations (8 ops)   │
│  - corthonomy-data-syncer: Data operations (4 ops)          │
│                                                             │
│  Testers:                                                   │
│  - corthonomy-catalog-tester: Catalog validation            │
│  - corthonomy-data-tester: Data quality                     │
│                                                             │
│  Infrastructure:                                            │
│  - corthonomy-state-manager: state.json operations          │
│  - corthonomy-changelog-recorder: CHANGELOG.md updates      │
│  - corthonomy-issue-logger: issue-log.jsonl management      │
│  - corthonomy-catalog-deployer: Terraform deployment        │
│  - corthonomy-arg-parser: Argument validation               │
└─────────────────────────────────────────────────────────────┘
```

### Invocation Patterns

**Pattern 1: Single Dataset (Direct Manager)**
```
User → /corthonomy-manage ipeds/hd
     → Manager Skill
         → Auditor (inspect)
         → Debugger (analyze)
         → User Approval
         → Catalog Builder (execute)
         → Auditor (verify)
     ← Results
```

Context Loads: 2 (Command → Manager)

**Pattern 2: Batch Operation (Via Director)**
```
User → /corthonomy-manage ipeds/*
     → Director Agent
         → Parse pattern: ipeds/* → [ipeds/hd, ipeds/ic, ...]
         → For each dataset:
             → Manager Skill
                 → Auditor (inspect)
                 → Debugger (analyze)
                 → Builders (execute)
                 → Auditor (verify)
         → Aggregate results
     ← Consolidated report
```

Context Loads: 2 (Command → Director, Director has all datasets in context)

## Proposed Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                   USER INVOCATION                           │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│              LAYER 1: SLASH COMMANDS (7)                    │
│                                                             │
│  Same commands, but routing changes:                        │
│  - Single dataset → Manager Agent (NEW)                     │
│  - Batch (*/,) → Director Skill → Core Agent (NEW)          │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
            ┌─────────┴─────────┐
            │                   │
            ↓                   ↓
┌───────────────────┐   ┌──────────────────────────────┐
│  SINGLE DATASET   │   │        BATCH (*/,)           │
│  (69% of usage)   │   │       (31% of usage)         │
└─────────┬─────────┘   └────────┬─────────────────────┘
          │                      │
          │                      ↓
          │           ┌──────────────────────────────────┐
          │           │  DIRECTOR SKILL (NEW)            │
          │           │  Location: .claude/skills/       │
          │           │            corthonomy-director/  │
          │           │                                  │
          │           │  Responsibilities:               │
          │           │  - Parse pattern (*, */*, a,b,c) │
          │           │  - Expand wildcards              │
          │           │  - Return dataset list           │
          │           │  - Recommend parallelism config  │
          │           │                                  │
          │           │  Returns to: Core Claude Agent   │
          │           └────────┬─────────────────────────┘
          │                    │
          │                    ↓
          │           ┌────────────────────────────────────┐
          │           │   CORE CLAUDE AGENT                │
          │           │   (Built-in)                       │
          │           │                                    │
          │           │   Receives dataset list from       │
          │           │   Director skill, then invokes:    │
          │           │                                    │
          │           │   For each dataset (max 5 parallel):│
          │           │     → Manager Agent (via Task tool)│
          │           │                                    │
          │           │   Aggregates results               │
          │           └────────┬───────────────────────────┘
          │                    │
          └────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│          LAYER 2: MANAGER AGENT (NEW)                       │
│          Location: .claude/agents/project/                  │
│                    corthonomy-manager.md                    │
│                                                             │
│  Full Agent Capabilities:                                   │
│  - Persistent state across workflow                         │
│  - Full tool access (Read/Write/Bash/Grep/Glob/Edit)        │
│  - Natural user interaction                                 │
│  - Graceful error handling                                  │
│  - Skill invocation via Skill tool                          │
│                                                             │
│  7-Phase Workflow (Enhanced):                               │
│  1. Inspect → corthonomy-auditor skill                      │
│  2. Analyze → corthonomy-debugger skill (if issues)         │
│  3. Present → Natural user prompting                        │
│  4. Approve → Wait for confirmation (uses AskUserQuestion)  │
│  5. Execute → Invoke builders via Skill tool                │
│  6. Verify → Re-inspect via Skill tool                      │
│  7. Report → Rich output with state updates                 │
│                                                             │
│  Benefits:                                                  │
│  - Maintains workflow context                               │
│  - Can be invoked in parallel (by Core Agent)               │
│  - Better error recovery                                    │
│  - Direct file access for state.json                        │
└─────────────────────┬───────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│             LAYER 3: SPECIALIST SKILLS (12)                 │
│                                                             │
│  Same as current architecture                               │
│  (No changes to specialist skills)                          │
└─────────────────────────────────────────────────────────────┘
```

### New Invocation Patterns

**Pattern 1: Single Dataset (Direct Manager Agent)**
```
User → /corthonomy-manage ipeds/hd
     → Manager Agent (NEW: full agent context)
         → Skill: corthonomy-auditor
         → Skill: corthonomy-debugger
         → AskUserQuestion: approval
         → Skill: corthonomy-catalog-builder
         → Skill: corthonomy-auditor (verify)
         → Write: state.json
     ← Results
```

Context Loads: 2 (Command → Manager Agent)
**NO CHANGE from current architecture**

**Pattern 2: Batch Operation (Via Director Skill + Core Agent)**
```
User → /corthonomy-manage ipeds/*
     → Command invokes Director Skill
         → Director Skill returns:
             {
               "datasets": ["ipeds/hd", "ipeds/ic", ...],
               "count": 14,
               "recommended_parallel": 5
             }
     → Core Claude Agent processes response
         → For datasets in batches of 5 (parallel):
             → Task(agent="corthonomy-manager", dataset="ipeds/hd")
             → Task(agent="corthonomy-manager", dataset="ipeds/ic")
             → Task(agent="corthonomy-manager", dataset="ipeds/effy")
             → Task(agent="corthonomy-manager", dataset="ipeds/adm")
             → Task(agent="corthonomy-manager", dataset="ipeds/gr")
         → Wait for batch completion
         → Next batch of 5...
         → Aggregate all results
     ← Consolidated report
```

Context Loads:
- Command → Director Skill: 1
- Core Agent context: 1
- For 14 datasets @ 5 parallel: ~20 loads (14 managers + overhead)
- For 76 datasets @ 5 parallel: ~112 loads (76 managers + overhead)

## Rationale

### Why Manager Needs to be an Agent

**1. Complex State Management**

Manager's 7-phase workflow requires maintaining state across:
- Inspection results
- Debugger analysis
- User approval
- Builder execution tracking
- Verification results

As a skill, this state must be passed explicitly. As an agent, state is natural.

**2. Natural User Interaction**

Manager needs to:
- Present execution plans
- Ask for approval
- Handle "dry-run" vs "execute" modes
- Provide progress updates

Agent context makes this natural. Skill context makes it awkward.

**3. Tool Access**

Manager needs:
- `Read`: Read state.json, configuration files
- `Write`: Update state.json
- `Skill`: Invoke specialist skills
- `AskUserQuestion`: Get approvals
- `Bash`: Occasional script execution
- `Edit`: Update configuration files

Skills have limited tool access. Agents have full access.

**4. Error Recovery**

Manager needs to:
- Retry failed operations
- Roll back partial changes
- Update state on failures
- Provide detailed error context

Agent capabilities make this straightforward.

**5. Parallel Invocation**

Core Agent can invoke multiple Manager agents in parallel via Task tool.
Cannot parallelize skill invocations effectively.

### Why Director Should be a Skill

**1. Director's Responsibilities are Minimal**

Director currently:
- Parses patterns (*, ipeds/*, a,b,c)
- Expands wildcards to dataset list
- Loops over datasets
- Invokes Manager for each
- Aggregates results

Most of this can be done by Core Agent with Director as helper skill.

**2. Core Agent is Better at Parallelism**

Core Claude Agent can:
- Invoke multiple Tasks in parallel
- Aggregate results naturally
- Handle errors gracefully
- Provide progress updates

Director agent adds overhead without value.

**3. Simplifies Architecture**

- One agent type: Manager (focused on single dataset)
- One skill type: Specialists (focused operations)
- Core Agent: Handles coordination and parallelism
- Director Skill: Pattern expansion helper

**4. Better Separation of Concerns**

- Director Skill: Pattern parsing logic
- Core Agent: Orchestration and parallelism
- Manager Agent: Single-dataset workflow
- Specialist Skills: Operations

### Context Load Trade-off Analysis

**Current Architecture:**

| Operation | Datasets | Context Loads | Notes |
|-----------|----------|---------------|-------|
| Single | 1 | 2 | Command → Manager Skill |
| Batch (ipeds/*) | 14 | 2 | Command → Director (has all in context) |
| Batch (*) | 76 | 2 | Command → Director (has all in context) |

**Proposed Architecture:**

| Operation | Datasets | Context Loads | Notes |
|-----------|----------|---------------|-------|
| Single | 1 | 2 | Command → Manager Agent (NO CHANGE) |
| Batch (ipeds/*) | 14 | ~20 | Cmd→Director→Core + 14 Managers + overhead |
| Batch (*) | 76 | ~112 | Cmd→Director→Core + 76 Managers + overhead |

**Analysis:**

For **Single Dataset Operations (69% of usage)**:
- NO CHANGE: 2 context loads
- PRIMARY use case unaffected

For **Batch Operations (31% of usage)**:
- INCREASE: 2 → 20-112 context loads
- BUT: Enables true parallelism (max 5 concurrent)
- AND: Better workflow management per dataset
- AND: Proper state tracking per dataset
- AND: Better error isolation

**Trade-off Justification:**

1. **Single operations are unaffected** (69% of usage)
2. **Batch operations are infrequent** (31% of usage)
3. **Parallelism reduces wall-clock time** (5x speedup with 5 parallel)
4. **Better state management** worth the overhead
5. **Context load cost is one-time** per dataset
6. **Better error handling** prevents re-work

### User Insight Validation

User stated:
> "Core claude agent could be the one to invoke the parallel manage agents, leveraging a command/skill to do so for the director"

This architecture implements exactly that:
- Core Agent invokes parallel Manager agents
- Director becomes a skill (pattern expansion helper)
- Manager gets full agent capabilities
- Parallelism capped at 5 to manage context load

## Implementation Plan

### Phase 1: Manager Agent Creation (Week 1)

**1.1 Create Manager Agent File**

Create `.claude/agents/project/corthonomy-manager.md`:

```markdown
---
name: corthonomy-manager
description: Intelligent workflow orchestrator - coordinates inspector, debugger, and builders
version: 2.0.0
category: orchestration
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---

# corthonomy-manager

**Purpose:** Intelligent orchestrator that coordinates multi-step workflows using the Builder/Debugger pattern

[... rest of content from current skill.md, adapted for agent context ...]
```

**1.2 Add Agent-Specific Capabilities**

Enhance with:
- State management using Read/Write tools
- User approval workflow using AskUserQuestion
- Direct skill invocation using Skill tool
- Error handling with retry logic

**1.3 Create Agent Configuration**

Add to `.claude/agents/project/config.json`:

```json
{
  "agents": {
    "corthonomy-manager": {
      "enabled": true,
      "tools": ["Read", "Write", "Skill", "AskUserQuestion", "Bash", "Edit"],
      "max_iterations": 20,
      "context_management": "stateful"
    }
  }
}
```

**1.4 Test Manager Agent**

Test cases:
- Single dataset workflow
- User approval workflow
- Error handling
- State management
- Skill invocation

**Deliverables:**
- `.claude/agents/project/corthonomy-manager.md` (agent)
- Test results
- Performance benchmarks

### Phase 2: Director Skill Creation (Week 1)

**2.1 Create Director Skill File**

Create `.claude/skills/corthonomy-director/skill.md`:

```markdown
---
skill: corthonomy-director
purpose: Pattern expansion and dataset discovery for batch operations
layer: Utility
dependencies: []
---

# Skill: corthonomy-director

**Purpose:** Expand wildcard patterns to dataset lists for batch coordination

## Operations

### 1. expand-pattern

**Input:**
```json
{
  "operation": "expand-pattern",
  "pattern": "ipeds/*",
  "validate": true
}
```

**Output:**
```json
{
  "datasets": ["ipeds/hd", "ipeds/ic", "ipeds/effy", ...],
  "count": 14,
  "recommended_parallel": 5
}
```

### 2. validate-pattern

**Input:**
```json
{
  "operation": "validate-pattern",
  "pattern": "invalid/*"
}
```

**Output:**
```json
{
  "valid": false,
  "error": "Dataset 'invalid' not found",
  "suggestion": "Available datasets: ipeds, bls, doe, ..."
}
```
```

**2.2 Implement Pattern Expansion Logic**

Support patterns:
- `*` → All datasets
- `ipeds/*` → All entities in dataset
- `ipeds/hd,ipeds/ic` → Comma-separated list
- `ipeds/hd` → Single dataset (pass through)

**2.3 Add Parallelism Recommendations**

Calculate recommended parallelism:
- 1-5 datasets: parallel=1 (sequential)
- 6-20 datasets: parallel=3
- 21-50 datasets: parallel=5
- 51+ datasets: parallel=5 (cap)

**2.4 Test Director Skill**

Test cases:
- All pattern types
- Error handling (invalid patterns)
- Dataset discovery
- Parallelism calculation

**Deliverables:**
- `.claude/skills/corthonomy-director/skill.md`
- `.claude/skills/corthonomy-director/README.md`
- Test results

### Phase 3: Update Commands (Week 2)

Update 7 commands to use new architecture.

**3.1 Update /corthonomy-manage**

**Before:**
```markdown
# Invoke manager skill
Skill: corthonomy-manager
Input: {dataset, entity, dry_run}
```

**After:**
```markdown
# Single dataset: invoke manager agent
If pattern is single dataset (no wildcard/comma):
  Task:
    agent: corthonomy-manager
    dataset: [dataset]
    entity: [entity]
    dry_run: [dry_run]

# Batch: invoke director skill + core agent coordination
Else:
  # Step 1: Expand pattern
  Skill: corthonomy-director
  Operation: expand-pattern
  Pattern: [pattern]

  # Step 2: Get dataset list
  datasets = response.datasets
  parallel = response.recommended_parallel

  # Step 3: Process in batches
  For each batch of [parallel] datasets:
    # Parallel Task invocations
    results = []
    For dataset in batch:
      task = Task(
        agent: corthonomy-manager,
        dataset: dataset.split('/')[0],
        entity: dataset.split('/')[1],
        dry_run: [dry_run]
      )
      results.append(task)

    # Wait for batch completion
    Wait for all tasks in batch

  # Step 4: Aggregate results
  Generate consolidated report
```

**3.2 Update /corthonomy-config-create**

Follow same pattern:
- Single dataset → Manager Agent
- Batch → Director Skill + Core Agent + Manager Agents

**3.3 Update Remaining 5 Commands**

Same pattern for:
- `/corthonomy-config-validate`
- `/corthonomy-config-sync-schema`
- `/corthonomy-config-update-version`
- `/corthonomy-config-deploy`
- `/corthonomy-config-document`

**Deliverables:**
- 7 updated command files
- Before/after examples
- Test results for each

### Phase 4: Parallel Execution Pattern (Week 2)

**4.1 Document Core Agent Coordination Pattern**

Create `docs/guides/parallel-manager-execution.md`:

```markdown
# Parallel Manager Execution Pattern

## Overview

Core Claude Agent coordinates parallel Manager agent invocations for batch operations.

## Pattern

1. Command invokes Director Skill
2. Director returns dataset list + parallelism recommendation
3. Core Agent processes datasets in batches
4. For each batch: parallel Task invocations to Manager agents
5. Wait for batch completion
6. Aggregate results
7. Next batch

## Example

```python
# Pseudo-code for Core Agent coordination

# Step 1: Get dataset list
director_result = Skill(
    skill="corthonomy-director",
    operation="expand-pattern",
    pattern="ipeds/*"
)

datasets = director_result.datasets  # 14 datasets
parallel = director_result.recommended_parallel  # 5

# Step 2: Process in batches
all_results = []
batches = chunk(datasets, parallel)  # [[ds1,ds2,ds3,ds4,ds5], [ds6,...], ...]

for batch in batches:
    # Step 3: Parallel invocations
    tasks = []
    for dataset in batch:
        task = Task(
            agent="corthonomy-manager",
            dataset=dataset.split('/')[0],
            entity=dataset.split('/')[1]
        )
        tasks.append(task)

    # Step 4: Wait for batch
    batch_results = await_all(tasks)
    all_results.extend(batch_results)

# Step 5: Aggregate
report = aggregate_results(all_results)
print(report)
```
```

**4.2 Create Workflow Example**

Document complete workflow for:
- Single dataset operation
- Batch operation (14 datasets)
- Batch operation (76 datasets)

**Deliverables:**
- `docs/guides/parallel-manager-execution.md`
- Workflow diagrams
- Performance projections

### Phase 5: Documentation Updates (Week 3)

**5.1 Update CLAUDE.md**

Update architecture section:
- Manager is now an agent
- Director is now a skill
- Core Agent handles parallelism
- Context load trade-offs documented

**5.2 Update Architecture Docs**

Update:
- `docs/architecture/IMPLEMENTATION_COMPLETE.md`
- `docs/architecture/CONTROL_PLANE_MIGRATION_GUIDE.md`
- `docs/guides/agent-guide.md`

**5.3 Create Migration Guide**

Create `docs/architecture/MANAGER_AS_AGENT_MIGRATION.md`:
- Why the change
- What changed
- Migration steps
- Rollback procedure

**5.4 Update Command Reference**

Update `docs/guides/command-reference.md` with new patterns.

**Deliverables:**
- Updated documentation (5 files)
- Migration guide
- Command examples

## Technical Specifications

### Manager Agent Configuration

**File:** `.claude/agents/project/corthonomy-manager.md`

**Metadata:**
```yaml
---
name: corthonomy-manager
description: Intelligent workflow orchestrator for single-dataset operations
version: 2.0.0
category: orchestration
allowed_tools:
  - Read          # Read state.json, config files
  - Write         # Update state.json
  - Skill         # Invoke specialist skills
  - AskUserQuestion  # User approval workflow
  - Bash          # Script execution
  - Edit          # Config file updates
  - Grep          # Search operations
  - Glob          # File discovery
max_iterations: 20
context_management: stateful
---
```

**Key Capabilities:**

1. **State Management**
   - Read/write state.json directly
   - Track workflow progress
   - Persist between phases

2. **User Interaction**
   - Natural approval prompts
   - Progress updates
   - Error reporting

3. **Skill Coordination**
   - Invoke skills via Skill tool
   - Pass context between skills
   - Handle skill errors

4. **Tool Access**
   - Full Read/Write/Edit capabilities
   - Bash for script execution
   - Grep/Glob for discovery

### Director Skill Configuration

**File:** `.claude/skills/corthonomy-director/skill.md`

**Metadata:**
```yaml
---
skill: corthonomy-director
purpose: Pattern expansion and dataset discovery for batch operations
layer: Utility
dependencies: []
version: 2.0.0
---
```

**Operations:**

1. **expand-pattern**
   - Input: Pattern string (*, ipeds/*, a,b,c)
   - Output: Dataset list + parallelism recommendation
   - Validation: Check datasets exist

2. **validate-pattern**
   - Input: Pattern string
   - Output: Valid/invalid + error message
   - Suggestions: Available datasets if invalid

**Parallelism Calculation:**
```python
def calculate_parallelism(dataset_count):
    if dataset_count <= 5:
        return 1  # Sequential
    elif dataset_count <= 20:
        return 3
    else:
        return 5  # Cap at 5
```

### Command Routing Logic

**Pattern Detection:**
```python
def route_command(pattern):
    """
    Determine routing based on pattern.
    """
    # Single dataset (no wildcard, no comma)
    if '/' in pattern and '*' not in pattern and ',' not in pattern:
        return "MANAGER_AGENT"

    # Batch operation (wildcard or comma)
    if '*' in pattern or ',' in pattern:
        return "DIRECTOR_SKILL"

    raise ValueError(f"Invalid pattern: {pattern}")
```

**Command Template:**
```markdown
# Parse input
pattern = [user_input]

# Route based on pattern
route = route_command(pattern)

if route == "MANAGER_AGENT":
    # Single dataset - direct to Manager Agent
    dataset, entity = pattern.split('/')
    Task(
        agent="corthonomy-manager",
        dataset=dataset,
        entity=entity,
        operation=[operation],
        flags=[flags]
    )

elif route == "DIRECTOR_SKILL":
    # Batch - Director Skill + Core Agent coordination

    # Step 1: Expand pattern
    director_result = Skill(
        skill="corthonomy-director",
        operation="expand-pattern",
        pattern=pattern
    )

    datasets = director_result.datasets
    parallel = director_result.recommended_parallel

    # Step 2: Process in batches
    all_results = []
    for batch_start in range(0, len(datasets), parallel):
        batch = datasets[batch_start:batch_start+parallel]

        # Step 3: Parallel Manager invocations
        batch_results = []
        for dataset_path in batch:
            dataset, entity = dataset_path.split('/')
            result = Task(
                agent="corthonomy-manager",
                dataset=dataset,
                entity=entity,
                operation=[operation],
                flags=[flags]
            )
            batch_results.append(result)

        all_results.extend(batch_results)

    # Step 4: Aggregate and report
    generate_consolidated_report(all_results)
```

## Parallel Execution Pattern

### Workflow Example: Batch Operation

**User Request:**
```bash
/corthonomy-manage ipeds/* --dry-run
```

**Execution Flow:**

```
[1] Command Invocation
    |
    v
[2] Detect Pattern: "ipeds/*" (batch)
    |
    v
[3] Invoke Director Skill
    Skill: corthonomy-director
    Operation: expand-pattern
    Pattern: "ipeds/*"
    |
    v
[4] Director Returns
    {
      "datasets": [
        "ipeds/hd", "ipeds/ic", "ipeds/effy", "ipeds/adm",
        "ipeds/gr", "ipeds/c_a", "ipeds/om", "ipeds/sal_a",
        "ipeds/s", "ipeds/f_f", "ipeds/ef_a", "ipeds/gr200",
        "ipeds/sfa", "ipeds/sfav"
      ],
      "count": 14,
      "recommended_parallel": 5
    }
    |
    v
[5] Core Agent Batching
    Batch 1: [hd, ic, effy, adm, gr]
    Batch 2: [c_a, om, sal_a, s, f_f]
    Batch 3: [ef_a, gr200, sfa, sfav]
    |
    v
[6] Batch 1 Parallel Execution
    ┌─────────┬─────────┬─────────┬─────────┬─────────┐
    │         │         │         │         │         │
    v         v         v         v         v         v
    Task      Task      Task      Task      Task
    (hd)      (ic)      (effy)    (adm)     (gr)
    |         |         |         |         |
    v         v         v         v         v
    Manager   Manager   Manager   Manager   Manager
    Agent     Agent     Agent     Agent     Agent
    |         |         |         |         |
    v         v         v         v         v
    Result    Result    Result    Result    Result
    └─────────┴─────────┴─────────┴─────────┴─────────┘
                        |
                        v
[7] Wait for Batch 1 Completion
    |
    v
[8] Batch 2 Parallel Execution
    (Same pattern as Batch 1)
    |
    v
[9] Batch 3 Parallel Execution
    (Same pattern as Batch 1)
    |
    v
[10] Aggregate All Results
     Success: 14/14
     Failed: 0/14
     Duration: ~3 minutes (vs ~10 minutes sequential)
     |
     v
[11] Consolidated Report to User
```

### Context Load Breakdown

**For 14 datasets @ 5 parallel:**

| Phase | Context Loads | Notes |
|-------|---------------|-------|
| Command → Director Skill | 1 | Pattern expansion |
| Core Agent coordination | 1 | Batch management |
| Batch 1 (5 Managers) | 5 | Parallel execution |
| Batch 2 (5 Managers) | 5 | Parallel execution |
| Batch 3 (4 Managers) | 4 | Parallel execution |
| Aggregation overhead | ~4 | Result collection |
| **Total** | **~20** | **vs 2 in current** |

**For 76 datasets @ 5 parallel:**

| Phase | Context Loads | Notes |
|-------|---------------|-------|
| Command → Director Skill | 1 | Pattern expansion |
| Core Agent coordination | 1 | Batch management |
| 16 batches × 5 Managers | 80 | Parallel execution |
| Aggregation overhead | ~30 | Result collection |
| **Total** | **~112** | **vs 2 in current** |

### Performance Projection

**Current (Sequential via Director):**
- 76 datasets × 2 min/dataset = 152 minutes (~2.5 hours)
- Context loads: 2

**Proposed (5 Parallel):**
- 76 datasets ÷ 5 parallel = 16 batches
- 16 batches × 2 min/batch = 32 minutes (~0.5 hours)
- Context loads: ~112

**Trade-off:**
- **Wall-clock time: 5x faster** (2.5 hours → 0.5 hours)
- **Context loads: 56x more** (2 → 112)
- **Acceptable:** Batch operations are rare (31% of usage)

## Context Load Analysis

### Detailed Cost/Benefit Tables

**Single Dataset Operations (69% of usage):**

| Metric | Current | Proposed | Change |
|--------|---------|----------|--------|
| Context loads | 2 | 2 | ✅ NO CHANGE |
| Wall-clock time | ~2 min | ~2 min | ✅ NO CHANGE |
| User experience | Good | Better | ✅ IMPROVED |
| State management | Limited | Full | ✅ IMPROVED |
| Error handling | Basic | Advanced | ✅ IMPROVED |

**Batch Operations - Small (6-20 datasets, ~15% of usage):**

| Metric | Current | Proposed | Change |
|--------|---------|----------|--------|
| Context loads | 2 | ~25 | ❌ 12.5x increase |
| Wall-clock time | ~30 min | ~10 min | ✅ 3x faster |
| Parallelism | None | 3-5 concurrent | ✅ NEW |
| Error isolation | Poor | Good | ✅ IMPROVED |
| Per-dataset state | None | Full | ✅ NEW |

**Batch Operations - Large (21+ datasets, ~16% of usage):**

| Metric | Current | Proposed | Change |
|--------|---------|----------|--------|
| Context loads | 2 | ~112 | ❌ 56x increase |
| Wall-clock time | ~150 min | ~30 min | ✅ 5x faster |
| Parallelism | None | 5 concurrent | ✅ NEW |
| Error isolation | Poor | Good | ✅ IMPROVED |
| Per-dataset state | None | Full | ✅ NEW |

### When Context Load Increase is Acceptable

**Context loads matter LESS when:**
1. Operations are infrequent (batch is 31% of usage)
2. Wall-clock time matters more (waiting 2.5 hours vs 30 min)
3. Better outcomes justify cost (proper state, error handling)
4. User experience improves (parallel progress, better errors)

**Context loads matter MORE when:**
1. Operations are frequent (NOT the case here)
2. Cost per operation is critical (NOT the case for batch)
3. Alternative patterns exist (no viable alternative for parallelism)

**Conclusion:**
For batch operations (31% of usage, infrequent), the context load increase is acceptable given:
- 5x wall-clock time reduction
- Proper state management per dataset
- Better error isolation
- Improved user experience

## Testing Requirements

### Unit Tests

**Manager Agent Tests:**

1. **State Management**
   - Test: Read/write state.json
   - Test: State persistence across phases
   - Test: Concurrent access handling

2. **User Interaction**
   - Test: Approval workflow
   - Test: Dry-run mode
   - Test: Error reporting

3. **Skill Coordination**
   - Test: Sequential skill invocations
   - Test: Skill error handling
   - Test: Context passing

**Director Skill Tests:**

1. **Pattern Expansion**
   - Test: Wildcard expansion (*)
   - Test: Dataset family expansion (ipeds/*)
   - Test: Comma-separated list (a,b,c)
   - Test: Single dataset pass-through

2. **Validation**
   - Test: Invalid patterns
   - Test: Non-existent datasets
   - Test: Error messages

3. **Parallelism Calculation**
   - Test: 1-5 datasets → parallel=1
   - Test: 6-20 datasets → parallel=3
   - Test: 21+ datasets → parallel=5

### Integration Tests

**Single Dataset Workflow:**

```
Test: /corthonomy-manage ipeds/hd

Expected:
1. Command routes to Manager Agent
2. Manager invokes Auditor skill
3. Manager invokes Debugger skill
4. Manager prompts user approval
5. Manager invokes Builder skill
6. Manager updates state.json
7. Manager returns results

Verify:
- 2 context loads
- State.json updated
- CHANGELOG.md updated
- No errors
```

**Batch Workflow (14 datasets):**

```
Test: /corthonomy-manage ipeds/*

Expected:
1. Command invokes Director skill
2. Director returns 14 datasets
3. Core Agent creates 3 batches (5, 5, 4)
4. Batch 1: 5 parallel Manager invocations
5. Wait for Batch 1 completion
6. Batch 2: 5 parallel Manager invocations
7. Wait for Batch 2 completion
8. Batch 3: 4 parallel Manager invocations
9. Aggregate results
10. Return consolidated report

Verify:
- ~20 context loads
- All 14 datasets processed
- Wall-clock time < 10 minutes
- No cross-contamination between Managers
```

**Batch Workflow (76 datasets):**

```
Test: /corthonomy-manage *

Expected:
1. User confirmation prompt (bulk operation warning)
2. Director expansion to 76 datasets
3. 16 batches of 5 (last batch has 1)
4. Parallel execution per batch
5. Aggregated results

Verify:
- ~112 context loads
- All 76 datasets processed
- Wall-clock time < 40 minutes
- Success/failure report
```

### Performance Tests

**Metrics to Track:**

1. **Context Load Count**
   - Single dataset: Target = 2
   - Batch (14): Target ≤ 25
   - Batch (76): Target ≤ 120

2. **Wall-Clock Time**
   - Single dataset: Target ≤ 3 min
   - Batch (14): Target ≤ 12 min
   - Batch (76): Target ≤ 40 min

3. **Resource Usage**
   - Memory per Manager agent
   - Disk I/O for state.json
   - Network calls to AWS

4. **Error Rates**
   - Manager invocation failures
   - Skill invocation failures
   - State.json corruption

**Test Scenarios:**

1. **Load Test**
   - Run 10 consecutive single-dataset operations
   - Verify consistent performance
   - Check for memory leaks

2. **Concurrency Test**
   - Run 5 parallel Managers simultaneously
   - Verify no state corruption
   - Check error isolation

3. **Failure Recovery Test**
   - Inject skill failures
   - Verify Manager error handling
   - Check state rollback

## Migration Guide

### Step-by-Step Implementation

**Week 1: Manager Agent + Director Skill**

Day 1-2: Manager Agent
- Create `.claude/agents/project/corthonomy-manager.md`
- Migrate content from skill
- Add agent-specific capabilities
- Test single-dataset workflow

Day 3-4: Director Skill
- Create `.claude/skills/corthonomy-director/skill.md`
- Implement pattern expansion
- Implement parallelism calculation
- Test pattern matching

Day 5: Integration Testing
- Test Manager Agent → Specialist Skills
- Test Director Skill → Core Agent
- Verify end-to-end workflows

**Week 2: Command Updates**

Day 1-2: Primary Commands
- Update `/corthonomy-manage`
- Update `/corthonomy-config-create`
- Test routing logic

Day 3-4: Remaining Commands
- Update 5 remaining commands
- Test all command variations
- Document changes

Day 5: Integration Testing
- Test all commands with single dataset
- Test all commands with batch patterns
- Performance benchmarking

**Week 3: Documentation + Rollout**

Day 1-2: Documentation
- Update CLAUDE.md
- Update architecture docs
- Create migration guide

Day 3-4: Testing
- Full regression testing
- Performance validation
- User acceptance testing

Day 5: Rollout
- Archive old Manager skill
- Archive old Director agent
- Announce changes

### Pre-Migration Checklist

- [ ] Backup current `.claude/skills/corthonomy-manager/`
- [ ] Backup current `.claude/agents/project/table-director.md`
- [ ] Backup all 7 command files
- [ ] Document current context load metrics
- [ ] Document current performance benchmarks
- [ ] Tag repository (pre-manager-refactor)

### Post-Migration Verification

- [ ] All single-dataset operations work
- [ ] All batch operations work
- [ ] Context loads match projections
- [ ] Wall-clock time improves for batch
- [ ] No state.json corruption
- [ ] Error handling works correctly
- [ ] Documentation updated
- [ ] Team trained

## Rollback Procedures

### Immediate Rollback (If Critical Issues)

**Trigger Conditions:**
- Manager Agent failures > 25%
- State.json corruption detected
- Context load > 200 per operation
- Data loss or corruption

**Rollback Steps:**

1. **Restore Original Files**
   ```bash
   git checkout pre-manager-refactor -- .claude/skills/corthonomy-manager/
   git checkout pre-manager-refactor -- .claude/agents/project/table-director.md
   git checkout pre-manager-refactor -- .claude/commands/project/
   ```

2. **Remove New Files**
   ```bash
   rm -rf .claude/agents/project/corthonomy-manager.md
   rm -rf .claude/skills/corthonomy-director/
   ```

3. **Verify Functionality**
   ```bash
   /corthonomy-manage ipeds/hd
   /corthonomy-manage ipeds/*
   ```

4. **Notify Team**
   - Post rollback notification
   - Document issues encountered
   - Plan remediation

### Gradual Rollback (If Partial Issues)

**If only certain commands have issues:**

1. Rollback specific commands
2. Keep Manager Agent for working commands
3. Hybrid mode during remediation

**If only batch operations have issues:**

1. Disable Director Skill
2. Keep Manager Agent for single operations
3. Fall back to sequential batch processing

## Success Criteria

### Functional Success

- [ ] Single-dataset operations work identically to current
- [ ] Batch operations complete successfully
- [ ] Parallelism functions correctly (max 5 concurrent)
- [ ] Error handling improves over current
- [ ] State management works reliably

### Performance Success

- [ ] Single dataset: ≤ 2 context loads (same as current)
- [ ] Batch (14 datasets): ≤ 25 context loads
- [ ] Batch (76 datasets): ≤ 120 context loads
- [ ] Wall-clock time for batch: 3-5x faster than current
- [ ] No performance regression for single operations

### Quality Success

- [ ] No state.json corruption
- [ ] No data loss
- [ ] Proper error isolation between parallel Managers
- [ ] User experience improved (better prompts, clearer errors)
- [ ] Documentation complete and accurate

### Adoption Success

- [ ] Team trained on new architecture
- [ ] All 7 commands migrated
- [ ] Old files archived (not deleted)
- [ ] Migration guide published
- [ ] Rollback procedure tested

## Risk Assessment

### High Risks

**Risk 1: State Corruption in Parallel Execution**

**Probability:** Medium
**Impact:** High
**Mitigation:**
- File locking in state-manager skill
- Atomic write operations
- Per-dataset state.json (no shared state)
- Extensive concurrency testing

**Risk 2: Context Load Explosion**

**Probability:** Low
**Impact:** Medium
**Mitigation:**
- Cap parallelism at 5
- Monitor context loads
- Document trade-offs clearly
- User can choose sequential mode

**Risk 3: Manager Agent Complexity**

**Probability:** Medium
**Impact:** Medium
**Mitigation:**
- Comprehensive testing
- Gradual rollout
- Rollback procedure ready
- Documentation and training

### Medium Risks

**Risk 4: User Confusion**

**Probability:** Medium
**Impact:** Low
**Mitigation:**
- Clear documentation
- Migration guide
- Team training
- Gradual adoption

**Risk 5: Incomplete Migration**

**Probability:** Low
**Impact:** Low
**Mitigation:**
- Phased implementation
- Track progress
- Test each command
- Verification checklist

### Low Risks

**Risk 6: Performance Regression**

**Probability:** Low
**Impact:** Low
**Mitigation:**
- Benchmark before/after
- Performance tests
- Monitoring
- Rollback if needed

## Future Enhancements

### Phase 2 Enhancements (Post-Initial Implementation)

**1. Adaptive Parallelism**

Adjust parallelism based on:
- Operation complexity
- Dataset size
- Historical performance
- System load

**2. Smart Batching**

Group datasets by:
- Dependencies
- Size
- Complexity
- Priority

**3. Resume Capability**

If batch fails:
- Resume from failure point
- Skip completed datasets
- Retry failed datasets

**4. Progress Dashboard**

Real-time visual progress:
- Batch status
- Per-dataset status
- Estimated completion time
- Error summary

**5. Result Caching**

Cache successful operations:
- Skip re-processing unchanged datasets
- Incremental batch operations
- Faster re-runs

### Phase 3 Enhancements (Future)

**6. Distributed Execution**

Execute Managers across multiple:
- Claude instances
- Machines
- Cloud functions

**7. Advanced Error Recovery**

Automatic retry with:
- Exponential backoff
- Alternative strategies
- Partial rollback

**8. Machine Learning**

Learn from history:
- Predict operation duration
- Recommend parallelism
- Identify patterns
- Suggest optimizations

## Command Updates (Before/After)

### 1. /corthonomy-manage

**Before:**
```markdown
---
command: /corthonomy-manage
description: Intelligent workflow orchestrator
---

# Parse arguments
dataset = [arg1]
entity = [arg2]
flags = [remaining args]

# Invoke manager skill
Skill: corthonomy-manager
Input:
  dataset: {dataset}
  entity: {entity}
  flags: {flags}

# Return results
```

**After:**
```markdown
---
command: /corthonomy-manage
description: Intelligent workflow orchestrator with parallel batch support
---

# Parse arguments
pattern = [arg1]  # Can be: dataset/entity, dataset/*, *, or a,b,c
flags = [remaining args]

# Route based on pattern
if is_single_dataset(pattern):
    # Single dataset → Manager Agent
    dataset, entity = pattern.split('/')

    Task:
      agent: corthonomy-manager
      prompt: |
        Execute management workflow for {dataset}/{entity}

        Dataset: {dataset}
        Entity: {entity}
        Flags: {flags}

else:
    # Batch operation → Director Skill + Core Agent

    # Step 1: Expand pattern
    director_result = Skill(
      skill: corthonomy-director
      operation: expand-pattern
      pattern: {pattern}
    )

    datasets = director_result.datasets
    parallel_count = director_result.recommended_parallel

    # Step 2: User confirmation for bulk operations
    if pattern == '*':
      confirm = AskUserQuestion(
        question: "Process ALL {len(datasets)} datasets? This is a bulk operation."
        options: ["Yes, proceed", "No, cancel"]
      )

      if confirm != "Yes, proceed":
        exit("Operation cancelled by user")

    # Step 3: Process in batches
    all_results = []
    batches = chunk_list(datasets, parallel_count)

    for batch_num, batch in enumerate(batches):
      print(f"Processing batch {batch_num+1}/{len(batches)}: {len(batch)} datasets")

      # Parallel Task invocations
      batch_tasks = []
      for dataset_path in batch:
        dataset, entity = dataset_path.split('/')

        task = Task(
          agent: corthonomy-manager
          prompt: |
            Execute management workflow for {dataset}/{entity}

            Dataset: {dataset}
            Entity: {entity}
            Flags: {flags}
            Batch: {batch_num+1}/{len(batches)}
        )

        batch_tasks.append(task)

      # Wait for batch completion
      batch_results = await_all(batch_tasks)
      all_results.extend(batch_results)

    # Step 4: Aggregate and report
    generate_consolidated_report(all_results)

# Helper functions
def is_single_dataset(pattern):
  return '/' in pattern and '*' not in pattern and ',' not in pattern

def chunk_list(items, size):
  return [items[i:i+size] for i in range(0, len(items), size)]
```

### 2. /corthonomy-config-create

**Before:**
```markdown
---
command: /corthonomy-config-create
description: Create new catalog table configuration
---

# Parse arguments
dataset = [arg1]
entity = [arg2]
complete = [--complete flag]

# Invoke manager skill
Skill: corthonomy-manager
Input:
  operation: config-create
  dataset: {dataset}
  entity: {entity}
  complete: {complete}

# If --complete, continue to validation and testing
if complete:
  Skill: corthonomy-catalog-tester
  Skill: corthonomy-data-tester
```

**After:**
```markdown
---
command: /corthonomy-config-create
description: Create new catalog table configuration with batch support
---

# Parse arguments
pattern = [arg1]  # Can be: dataset/entity, dataset/*, *, or a,b,c
complete = [--complete flag]

# Route based on pattern
if is_single_dataset(pattern):
    # Single dataset → Manager Agent
    dataset, entity = pattern.split('/')

    Task:
      agent: corthonomy-manager
      prompt: |
        Execute config-create workflow for {dataset}/{entity}

        Operation: config-create
        Dataset: {dataset}
        Entity: {entity}
        Complete: {complete}

        Workflow:
        1. Check preconditions (data exists in ETL)
        2. Create catalog table via catalog-builder
        3. If --complete: validate and test

else:
    # Batch operation → Director Skill + Core Agent

    # Step 1: Expand pattern
    director_result = Skill(
      skill: corthonomy-director
      operation: expand-pattern
      pattern: {pattern}
    )

    datasets = director_result.datasets
    parallel_count = director_result.recommended_parallel

    # Step 2: Confirmation for bulk
    if len(datasets) > 10:
      confirm = AskUserQuestion(
        question: "Create catalog tables for {len(datasets)} datasets?"
        options: ["Yes, proceed", "No, cancel"]
      )

      if confirm != "Yes, proceed":
        exit("Operation cancelled")

    # Step 3: Process in batches
    all_results = []
    batches = chunk_list(datasets, parallel_count)

    for batch_num, batch in enumerate(batches):
      print(f"Batch {batch_num+1}/{len(batches)}")

      batch_tasks = []
      for dataset_path in batch:
        dataset, entity = dataset_path.split('/')

        task = Task(
          agent: corthonomy-manager
          prompt: |
            Execute config-create for {dataset}/{entity}

            Operation: config-create
            Dataset: {dataset}
            Entity: {entity}
            Complete: {complete}
        )

        batch_tasks.append(task)

      batch_results = await_all(batch_tasks)
      all_results.extend(batch_results)

    # Step 4: Report
    generate_consolidated_report(all_results)
```

### 3. /corthonomy-config-validate

**Before:**
```markdown
---
command: /corthonomy-config-validate
description: Validate catalog configuration
---

# Parse arguments
dataset = [arg1]
entity = [arg2]
complete = [--complete flag]

# Invoke manager skill
Skill: corthonomy-manager
Input:
  operation: config-validate
  dataset: {dataset}
  entity: {entity}
  complete: {complete}
```

**After:**
```markdown
---
command: /corthonomy-config-validate
description: Validate catalog configuration with batch support
---

# Parse arguments
pattern = [arg1]
complete = [--complete flag]

# Same routing pattern as /corthonomy-manage
# (Single → Manager Agent, Batch → Director + Core Agent)

# Operation: config-validate
# Complete flag: if true, run full validation suite
```

### 4. /corthonomy-config-sync-schema

**Before:**
```markdown
---
command: /corthonomy-config-sync-schema
description: Sync catalog schema with ETL
---

# Parse arguments
dataset = [arg1]
entity = [arg2]
complete = [--complete flag]

# Invoke manager skill
Skill: corthonomy-manager
Input:
  operation: sync-schema
  dataset: {dataset}
  entity: {entity}
  complete: {complete}
```

**After:**
```markdown
---
command: /corthonomy-config-sync-schema
description: Sync catalog schema with ETL (batch support)
---

# Parse arguments
pattern = [arg1]
complete = [--complete flag]

# Same routing pattern
# Operation: sync-schema
# Complete flag: if true, validate after sync
```

### 5. /corthonomy-config-update-version

**Before:**
```markdown
---
command: /corthonomy-config-update-version
description: Update catalog to new data version
---

# Parse arguments
dataset = [arg1]
entity = [arg2]
complete = [--complete flag]

# Invoke manager skill
Skill: corthonomy-manager
Input:
  operation: update-version
  dataset: {dataset}
  entity: {entity}
  complete: {complete}
```

**After:**
```markdown
---
command: /corthonomy-config-update-version
description: Update catalog to new data version (batch support)
---

# Parse arguments
pattern = [arg1]
complete = [--complete flag]

# Same routing pattern
# Operation: update-version
# Complete flag: if true, test new version
```

### 6. /corthonomy-config-deploy

**Before:**
```markdown
---
command: /corthonomy-config-deploy
description: Deploy catalog infrastructure via Terraform
---

# Parse arguments
env = [arg1]  # test or prod

# Invoke manager skill
Skill: corthonomy-manager
Input:
  operation: deploy
  environment: {env}
```

**After:**
```markdown
---
command: /corthonomy-config-deploy
description: Deploy catalog infrastructure via Terraform
---

# Parse arguments
env = [arg1]  # test or prod

# NOTE: Deploy is always single environment (no batch)
# Invoke Manager Agent directly

Task:
  agent: corthonomy-manager
  prompt: |
    Execute catalog deployment

    Operation: deploy
    Environment: {env}

    Safety checks:
    - If env=prod, require explicit confirmation
    - Never auto-deploy prod with --complete flag
```

### 7. /corthonomy-config-document

**Before:**
```markdown
---
command: /corthonomy-config-document
description: Generate documentation for catalog
---

# Parse arguments
dataset = [arg1]
entity = [arg2]

# Invoke manager skill
Skill: corthonomy-manager
Input:
  operation: document
  dataset: {dataset}
  entity: {entity}
```

**After:**
```markdown
---
command: /corthonomy-config-document
description: Generate documentation for catalog (batch support)
---

# Parse arguments
pattern = [arg1]

# Same routing pattern
# Operation: document
# Can batch-generate docs for all datasets
```

## Summary

This specification defines a comprehensive refactoring of the control plane architecture to:

1. **Convert Manager to an Agent** - Full capabilities for complex workflows
2. **Convert Director to a Skill** - Pattern expansion helper
3. **Enable True Parallelism** - Core Agent orchestrates parallel Managers (max 5)
4. **Accept Context Load Trade-off** - Single ops unchanged, batch ops 56x more loads but 5x faster
5. **Improve User Experience** - Better state management, natural approvals, error handling

**Implementation Timeline:** 3 weeks
**Risk Level:** Medium (mitigated with testing and rollback)
**Expected Benefit:** Significantly improved batch operation performance and better workflow management

---

**Status:** Draft - Ready for Review
**Next Steps:** Team review → Approval → Implementation

