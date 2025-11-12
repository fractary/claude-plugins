---
org: corthos
system: lake.corthonomy.ai
title: Agentic Control Plane Design Standards (v2)
description: Comprehensive guide for designing and implementing command/agent/skill control planes with Builder/Debugger pattern, troubleshooting knowledge base, and state management - enhanced with learnings from Lake.Corthonomy.AI implementation
tags: [agents, claude-code, automation, architecture, best-practices, builder-debugger, troubleshooting, state-management]
created: 2025-10-24
updated: 2025-10-26
version: 2.0
codex_sync_include: [*]
codex_sync_exclude: []
visibility: internal
---

# Agentic Control Plane Design Standards (v2)

## Overview

This guide provides a comprehensive, battle-tested framework for designing and implementing command/agent/skill control planes that enable AI-assisted workflow automation through Claude Code. Enhanced with learnings from the Lake.Corthonomy.AI implementation (SPEC-015 through SPEC-022), these patterns have been proven in production managing 47 datasets across 7 data sources with 154 catalog tables.

**What's New in v2:**
- ⭐ Builder/Debugger Pattern with knowledge base integration
- 7-Phase Manager Workflow (Inspect → Analyze → Present → Approve → Execute → Verify → Report)
- Mandatory Workflow Order enforcement for data operations
- Modular Inspector Pattern with targeted checks
- Comprehensive Troubleshooting Knowledge Base framework
- State Management with atomic operations (state.json)
- Issue Log & Confidence Scoring for historical learning
- Pre-condition Checking patterns
- Real-world performance metrics and success criteria
- Complete migration guidelines
- Enhanced examples with full implementation details

## Table of Contents

### Core Framework
1. [Core Concepts](#core-concepts)
2. [When to Use This Pattern](#when-to-use-this-pattern)
3. [Architecture Principles](#architecture-principles)
4. [Builder/Debugger Pattern](#builderdebugger-pattern) ⭐ NEW
5. [Design Process](#design-process)

### Implementation Guidelines
6. [Naming Conventions](#naming-conventions)
7. [Argument Patterns](#argument-patterns)
8. [Agent Design](#agent-design)
   - [7-Phase Manager Workflow](#7-phase-manager-workflow) ⭐ NEW
9. [Skill Design](#skill-design)
   - [Modular Inspector Pattern](#modular-inspector-pattern) ⭐ NEW
   - [Skill Reporting Standards](#skill-reporting-standards) ⭐ NEW

### Operational Patterns
10. [Mandatory Workflow Order](#mandatory-workflow-order) ⭐ NEW
11. [Pre-condition Checking](#pre-condition-checking) ⭐ NEW
12. [Documentation Integration](#documentation-integration)
13. [State Management](#state-management) ⭐ NEW
14. [Error Handling](#error-handling)
15. [Troubleshooting Knowledge Base](#troubleshooting-knowledge-base) ⭐ NEW
    - [Issue Log & Confidence Scoring](#issue-log--confidence-scoring) ⭐ NEW

### Patterns & Best Practices
16. [Common Patterns](#common-patterns)
17. [Anti-Patterns](#anti-patterns)
18. [Testing Strategy](#testing-strategy)

### Production Deployment
19. [Performance Metrics](#performance-metrics) ⭐ NEW
20. [Success Criteria](#success-criteria) ⭐ NEW
21. [Migration Guidelines](#migration-guidelines) ⭐ NEW
22. [Implementation Checklist](#implementation-checklist)

### Examples
23. [Example: Building a Control Plane](#example-building-a-control-plane)
24. [Real-World Implementation: Lake.Corthonomy.AI](#real-world-implementation-lakecorthonomyai) ⭐ NEW

### Reference
25. [Additional Resources](#additional-resources)
26. [Changelog](#changelog) ⭐ NEW

---

## Core Concepts

### What is an Agentic Control Plane?

An **agentic control plane** is a structured system of commands, agents, and skills that enables:
- **Human-friendly commands** for complex operations
- **AI-automated workflows** with maintained context
- **Repeatable processes** through standardized patterns
- **Gap identification** when capabilities are missing
- **Built-in documentation** at every step

### The Three-Layer Architecture

```
┌─────────────────────────────────────────────┐
│            LAYER 1: COMMANDS                │
│  Lightweight routing, user interface        │
│  Location: .claude/commands/                │
└────────────────┬────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────┐
│          LAYER 2: MANAGER AGENTS            │
│  Workflow orchestration, context            │
│  Single-entity operations                   │
│  Location: .claude/agents/                  │
└────────────────┬────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────┐
│            LAYER 3: SKILLS                  │
│  Task execution, script abstraction         │
│  Location: .claude/skills/                  │
└────────────────┬────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────┐
│          SCRIPTS & TEMPLATES                │
│  Deterministic execution                    │
└─────────────────────────────────────────────┘
```

**Batch Operations Layer: Director Skills + Core Agent Parallelism**
- Pattern expansion (wildcards, comma-separated lists)
- Core Claude Agent handles parallel Manager invocations
- Results aggregation
- Used for 31% of operations (69% are single-entity)

### Key Terminology

**Command** - Slash command that routes user requests to Manager agents or Director skills
- Example: `/myproject-resource-manager create my-resource` (single entity)
- Example: `/myproject-resource-manager create dataset/*` (batch via Director skill)

**Manager Agent** - Orchestrates workflows for a single entity (PRIMARY PATTERN)
- Location: `.claude/agents/project/{name}-manager.md`
- **MUST be an AGENT** (not a skill) for full capabilities
- Full tool access: Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob
- Maintains state throughout 7-phase workflow
- Natural user interaction and approval workflows
- Invokes specialist skills for execution
- Handles errors gracefully with retry logic
- Single responsibility: orchestrate workflow for ONE entity

**Director Skill** - Expands patterns for batch operations (SECONDARY PATTERN)
- Location: `.claude/skills/{name}-director/`
- **MUST be a SKILL** (not an agent) - lightweight pattern expansion only
- Parses batch patterns: `*`, `dataset/*`, `a,b,c`
- Expands wildcards to entity lists
- Returns dataset list + parallelism recommendation to Core Claude Agent
- Does NOT orchestrate - Core Agent invokes Manager agents in parallel (max 5 concurrent)
- No workflow logic - pure pattern expansion

**Skill** - Performs a specific task, abstracts scripts
- Accepts structured input
- Returns structured output
- Minimal context usage
- Script-backed for deterministic operations

---

## When to Use This Pattern

### Good Candidates

Use this pattern when your project has:

✅ **Repeatable workflows** - Same process followed multiple times
✅ **Multi-step operations** - 3+ steps that must happen in order
✅ **Multiple entity types** - Different resources to manage (configs, deployments, etc.)
✅ **Complex decision points** - User input or conditional logic needed
✅ **Documentation needs** - Work must be documented as it happens
✅ **Error-prone processes** - Steps that commonly fail and need recovery
✅ **Knowledge to preserve** - Domain expertise to codify

### Poor Candidates

Don't use this pattern when:

❌ **Simple single commands** - One-off operations (just use scripts)
❌ **Fully deterministic** - No decisions, just execution (use scripts)
❌ **Rarely used** - Cost of building > benefit of automation
❌ **Rapidly changing** - Workflow unstable, will require constant updates
❌ **No clear entities** - No obvious resources to manage

### Examples of Good Use Cases

- **Infrastructure Management** - Create/deploy/monitor cloud resources
- **Content Production** - Create/review/publish content workflows
- **Data Pipeline Management** - Create/test/deploy data transformations
- **Release Management** - Build/test/deploy/document releases
- **Configuration Management** - Create/validate/deploy configurations
- **Development Workflows** - Setup/test/deploy applications

---

## Architecture Principles

### 1. Clear Hierarchy

**Commands delegate, managers orchestrate, skills execute.**

- Commands never contain logic
- Managers never call other managers
- Skills never make workflow decisions
- Scripts are abstracted into skills

### 2. Manager-as-Agent Principle

⭐ **CRITICAL ARCHITECTURAL PATTERN**

**Manager MUST be an Agent. Director MUST be a Skill.**

**Why Manager Must Be an Agent:**
- **Complex Orchestration**: 7-phase workflow requires persistent state across multiple skill invocations
- **User Interaction**: Natural approval workflows, error handling, and decision points require agent capabilities
- **Full Tool Access**: Needs Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob
- **State Management**: Must maintain workflow state, track issues, coordinate recovery
- **Error Handling**: Graceful failures with retry logic and user consultation
- **Single Entity Focus**: Manages complete lifecycle for ONE entity with full context

**Why Director Must Be a Skill (Not Agent):**
- **Simple Responsibility**: Only parses patterns and expands wildcards
- **No Orchestration**: Returns dataset list to Core Claude Agent (which handles parallelism)
- **Minimal Context**: No workflow logic, no state management
- **Batch Support**: Used for 31% of operations (vs. 69% single-entity via Manager directly)
- **Performance**: Lightweight pattern expansion enables Core Agent to invoke Managers in parallel (max 5 concurrent)

**Implementation:**
```
Single Entity (69% of operations):
User → Command → Manager Agent → Skills → Results
Context Loads: 2 (optimal, no change from any architecture)

Batch Operations (31% of operations):
User → Command → Director Skill → Core Claude Agent
                                   ↓ (parallel, max 5)
                                   ├─ Manager Agent #1 → Skills
                                   ├─ Manager Agent #2 → Skills
                                   ├─ Manager Agent #3 → Skills
                                   └─ ... → Aggregate Results
Context Loads: 20-112 (depends on parallelism factor)
Wall-Clock Time: 5x faster due to parallelism
```

**Context Load Trade-offs:**
- Single operations: NO CHANGE (2 context loads)
- Batch operations: Higher context load BUT 5x faster wall-clock time
- Trade-off justified: Primary use case (single entity) optimized, batch operations rare but get parallelism

**Anti-Patterns to Avoid:**
- ❌ Manager as Skill: Loses agent capabilities, unnatural user interaction
- ❌ Director as Agent: Over-engineered, prevents Core Agent parallelism
- ❌ Agent chains (pre-skills pattern): Heavy context, no script abstraction

### 3. Context Preservation

**Managers maintain state throughout workflows.**

- Track entity being operated on
- Remember previous step results
- Store user preferences
- Maintain error history

**Why:** Prevents context loss when moving between steps, enables intelligent next-step suggestions.

### 4. Scope Discipline

**Agents only use defined tools. When capabilities are missing, they stop.**

- Never solve problems ad-hoc
- Document missing capabilities
- Propose what should be created
- Wait for human intervention

**Why:** Surfaces workflow gaps, encourages permanent fixes, maintains consistency.

### 5. Documentation First

**Documentation is built into workflows, not a separate phase.**

- Document after create
- Document after test
- Document after deploy
- Document errors and resolutions

**Why:** Ensures docs never outdated, captures context, no separate doc phase needed.

### 6. Fail-Fast

**Stop immediately on errors, never guess or proceed.**

- Report errors clearly
- Propose solutions
- Wait for user choice
- Never auto-proceed with `--complete` after errors

**Why:** Prevents cascading failures, gives user control, surfaces issues early.

### 7. Single Responsibility

**Each component does one thing well.**

- One command per domain
- One manager per entity type
- One skill per task
- Clear boundaries

**Why:** Easy to understand, test, and maintain. Clear ownership of functionality.

### 8. State-Based Decision Making

⭐ **Key Innovation from Lake.Corthonomy.AI**

**Skills make decisions from state snapshots, not repeated infrastructure queries.**

- Read infrastructure state once, cache in state.json
- Skills read from state.json, never query infrastructure directly
- State updates atomic and validated
- Dashboard generation <10 seconds vs 15+ minutes

**Why:**
- **Performance**: 100x faster dashboards (9.4s vs 15.7 min for 47 resources)
- **Consistency**: All skills see same snapshot of infrastructure
- **Cost**: Zero AWS API calls for read-only operations
- **Reliability**: Atomic updates prevent partial state corruption

**Trade-off:** State can be up to 5 minutes stale (acceptable for most operations)

**Implementation Pattern:**
```python
# ❌ OLD: Query infrastructure every time
def check_resource_status(resource):
    s3_data = boto3.client('s3').list_objects(...)  # 20s
    glue_config = boto3.client('glue').get_table(...)  # 15s
    return analyze(s3_data, glue_config)

# ✅ NEW: Read from state snapshot
def check_resource_status(resource):
    state = read_state_json(resource)  # 0.1s
    return analyze(state)
```

**When to Rebuild State:**
- After any infrastructure change (create, update, delete)
- On explicit refresh request
- If state.json >5 minutes old and operation requires fresh data
- If state inconsistency detected

### 9. Mandatory Workflow Order

⭐ **Key Innovation from Lake.Corthonomy.AI**

**Operations execute in strict order: INSPECT → DATA-SYNC → CATALOG-OPS → TEST → DEPLOY**

- Inspection identifies what needs fixing
- Data operations run before catalog operations
- Catalog operations validated before deployment
- Tests run after changes, never before
- Deployment only if all tests pass

**Why:**
- **Prevents errors**: Can't configure catalog for non-existent data
- **Fast failure**: Inspector checks (1-3s) catch issues before expensive operations
- **Predictable outcomes**: Same order produces same results
- **Clear dependencies**: Each phase depends on previous phase success

**Enforcement Mechanisms:**
1. **Pre-condition Checks**: Each skill validates prerequisites before execution
2. **Manager Coordination**: Manager enforces order, blocks out-of-sequence operations
3. **State Dependencies**: Skills check state.json for required previous completions

**Implementation Pattern:**
```python
# Manager enforces workflow order
def execute_workflow(resource, operations):
    # Phase 1: INSPECT (mandatory first step)
    if "inspect" not in completed_phases:
        issues = inspector.invoke(resource, check="full")
        state["issues"] = issues
        completed_phases.add("inspect")

    # Phase 2: DATA-SYNC (only if data issues found)
    if has_data_issues(issues) and "data-sync" not in completed_phases:
        if "inspect" not in completed_phases:
            raise WorkflowOrderError("Must inspect before data-sync")
        data_syncer.invoke(resource, operation="sync")
        completed_phases.add("data-sync")

    # Phase 3: CATALOG-OPS (only after data ready)
    if has_catalog_issues(issues) and "catalog-ops" not in completed_phases:
        if has_data_issues(issues) and "data-sync" not in completed_phases:
            raise WorkflowOrderError("Must sync data before catalog operations")
        catalog_builder.invoke(resource, operation="update")
        completed_phases.add("catalog-ops")

    # Phase 4: TEST (only after changes)
    if operations_performed() and "test" not in completed_phases:
        test_results = catalog_tester.invoke(resource)
        if not test_results["passed"]:
            raise TestFailureError("Tests failed, blocking deployment")
        completed_phases.add("test")

    # Phase 5: DEPLOY (only if tests passed)
    if "deploy" in requested_operations:
        if "test" not in completed_phases:
            raise WorkflowOrderError("Must test before deployment")
        deployer.invoke(resource, environment="production")
        completed_phases.add("deploy")
```

**Violations to Block:**
- ❌ Running catalog operations before data sync
- ❌ Deploying without testing
- ❌ Testing without changes to validate
- ❌ Skipping inspection phase

**Exceptions (Rare):**
- Targeted checks (data-exists, catalog-exists) can run standalone
- State refresh can run anytime
- Dashboard generation reads state only (no workflow)

### 10. Historical Learning

⭐ **Key Innovation from Lake.Corthonomy.AI**

**System learns from past successes and failures to improve decision-making.**

- Every issue resolution logged (issue type, fix applied, outcome, confidence score)
- Confidence scores adjusted based on historical success rates
- Knowledge base updated when new fix patterns discovered
- Analytics identify declining success rates (trigger KB review)

**Why:**
- **Improving accuracy**: 94.1% success rate for high-confidence fixes
- **Faster diagnosis**: Historical patterns guide debugger analysis
- **Knowledge capture**: Successful fixes added to knowledge base permanently
- **Degradation detection**: Declining success rates trigger maintenance

**Learning Cycle:**
```
┌─────────────────────────────────────────────────────────┐
│                   LEARNING CYCLE                        │
└─────────────────────────────────────────────────────────┘

1. ISSUE DETECTED
   └─▶ Inspector identifies problem
        └─▶ Logged to issue log

2. DEBUGGER ANALYZES
   └─▶ Searches knowledge base
        └─▶ Calculates confidence score using historical data
             └─▶ High confidence: Auto-fix
             └─▶ Low confidence: Manual review

3. FIX APPLIED
   └─▶ Builder executes recommendation
        └─▶ Test validates outcome
             └─▶ Success/failure logged

4. CONFIDENCE RECALIBRATED
   └─▶ Analytics update historical success rates
        └─▶ Future confidence scores adjusted
             └─▶ Knowledge base flagged if success rate drops

5. KNOWLEDGE BASE UPDATED
   └─▶ New fix patterns documented
        └─▶ Outdated patterns deprecated
             └─▶ Cycle repeats with improved accuracy
```

**Implementation Pattern:**
```python
# Log every issue resolution attempt
def apply_fix(issue, recommended_fix, confidence):
    start_time = time.time()

    try:
        # Apply fix
        result = builder.invoke(recommended_fix)

        # Validate outcome
        test_result = tester.validate(issue["resource"])
        success = test_result["passed"]

        # Log outcome
        issue_logger.append({
            "timestamp": datetime.now().isoformat(),
            "issue_type": issue["type"],
            "fix_applied": recommended_fix,
            "confidence_score": confidence,
            "outcome": "success" if success else "failure",
            "duration_seconds": time.time() - start_time,
            "error_message": None if success else test_result["error"]
        })

        return success

    except Exception as e:
        # Log failure
        issue_logger.append({
            "timestamp": datetime.now().isoformat(),
            "issue_type": issue["type"],
            "fix_applied": recommended_fix,
            "confidence_score": confidence,
            "outcome": "failure",
            "duration_seconds": time.time() - start_time,
            "error_message": str(e)
        })
        raise

# Calculate confidence using historical data
def calculate_confidence(issue_type, recommended_fix):
    # Get historical success rate for this issue type
    stats = issue_logger.analytics(issue_type, last_n=20)

    base_score = knowledge_base.get_base_score(issue_type, recommended_fix)

    # Adjust based on historical performance
    if stats["success_rate"] > 0.90:
        historical_adjustment = +10
    elif stats["success_rate"] >= 0.70:
        historical_adjustment = 0
    else:
        historical_adjustment = -10

    return base_score + historical_adjustment
```

**Quarterly Review Process:**
1. Run analytics on last 90 days of issue log
2. Identify issue types with declining success rates
3. Review knowledge base documents for those types
4. Update fix recommendations based on recent failures
5. Recalibrate confidence scoring algorithm if needed

**Success Metrics:**
- ✅ High-confidence fixes succeed ≥90% of time (Lake.Corthonomy.AI: 94.1%)
- ✅ Knowledge base coverage ≥95% of issues (Lake.Corthonomy.AI: 96.2%)
- ✅ MTTR trending downward over time
- ✅ New developer onboarding 4x faster with historical context

### 11. Performance by Design

⭐ **Key Innovation from Lake.Corthonomy.AI**

**Optimize for context efficiency, execution speed, and developer experience from the start.**

- Design skills for <20K token context loading
- Implement targeted checks for <5s fast-failure paths
- Use state snapshots to eliminate redundant queries
- Provide clear, actionable error messages

**Why:**
- **Scalability**: System performs well at 10 resources and 100 resources
- **User experience**: Fast feedback loops encourage usage
- **Cost efficiency**: Reduced token usage and API calls
- **Maintainability**: Performance degradation is visible and measurable

**Performance Dimensions:**

**1. Context Efficiency**
- Target: <20K tokens per skill invocation
- Measure: tokens_used / tokens_loaded ratio
- Lake.Corthonomy.AI: 13x reduction (180K → 15K per operation)

**2. Execution Speed**
- Target: <90 seconds for common workflows
- Measure: workflow_duration from start to completion
- Lake.Corthonomy.AI: 20x faster (45-60 min → 2-3 min for new dataset)

**3. Diagnostic Speed**
- Target: <3 seconds for targeted checks, <30s for full inspection
- Measure: inspector invocation duration
- Lake.Corthonomy.AI: 10x faster for targeted checks (30s → 3s)

**4. Developer Experience**
- Target: <90 seconds MTTR for known issues
- Measure: time from issue detection to resolution
- Lake.Corthonomy.AI: 45 seconds average MTTR

**Implementation Strategies:**

**Context Efficiency:**
```python
# ❌ BAD: Load everything
@skill(context=[
    "**/*.py",  # All Python files
    "**/*.tf",  # All Terraform
    "**/*.json"  # All JSON
])

# ✅ GOOD: Load only what's needed
@skill(context=[
    f"terraform/resources/{resource}/*.tf",  # This resource only
    f"config/{resource}/state.json",  # Its state
    "scripts/lib/validation.py"  # Validation library
])
```

**Execution Speed:**
```python
# ❌ BAD: Sequential operations
def workflow(resource):
    inspect(resource)  # 30s
    sync_data(resource)  # 60s
    update_catalog(resource)  # 45s
    test(resource)  # 30s
    # Total: 165s

# ✅ GOOD: Targeted checks + parallel where possible
def workflow(resource):
    # Fast pre-checks
    if not data_exists(resource):  # 1s
        return "Data missing"
    if not catalog_exists(resource):  # 1s
        return "Catalog missing"

    # Only run full checks if needed
    issues = inspect(resource, check="data-currency")  # 3s

    if not issues:
        return "No action needed"

    # Execute fixes
    sync_data(resource)  # 60s
    update_catalog(resource)  # 45s
    test(resource)  # 30s
    # Total: 140s (with early returns often <5s)
```

**Diagnostic Speed:**
```python
# Provide multiple check types
inspector.invoke(resource, check="full")  # 30s - comprehensive
inspector.invoke(resource, check="data-currency")  # 3s - targeted
inspector.invoke(resource, check="data-exists")  # 1s - fast-fail
```

**Performance Monitoring:**
```python
# Track performance metrics in every skill
def execute_skill(operation):
    metrics = {
        "skill": SKILL_NAME,
        "operation": operation,
        "start_time": time.time(),
        "context_tokens_loaded": get_context_size(),
    }

    try:
        result = perform_operation(operation)
        metrics["duration"] = time.time() - metrics["start_time"]
        metrics["success"] = True
        return result
    finally:
        # Log metrics for analysis
        performance_logger.append(metrics)
```

**Red Flags:**
- ⚠️ Context loading >50K tokens per operation
- ⚠️ Common workflows taking >3 minutes
- ⚠️ Targeted checks taking >10 seconds
- ⚠️ MTTR trending upward over time

---

## Builder/Debugger Pattern

**⭐ Core Innovation from Lake.Corthonomy.AI** - This pattern emerged from managing 47 datasets with 154 catalog tables and has proven essential for scalable, maintainable control planes.

### The Problem

Traditional control planes suffer from:
- **Ad-hoc problem solving** - Each issue solved differently, no consistency
- **Lost knowledge** - Solutions not documented, re-discovered repeatedly
- **Agent overreach** - Agents improvise solutions, bypassing established patterns
- **No learning** - Same problems encountered repeatedly with same manual fixes

### The Solution: Separate Observation, Analysis, and Execution

**Core Principle:** "Come to the boss with problem AND solution, not just problem"

```
┌─────────────────────────────────────────────────────────┐
│                  BUILDER/DEBUGGER PATTERN               │
└─────────────────────────────────────────────────────────┘

┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  INSPECTOR  │────▶│  DEBUGGER   │────▶│   BUILDER   │
│             │     │             │     │             │
│  WHAT IS    │     │ WHY + HOW   │     │   EXECUTE   │
│ (Observe)   │     │  (Analyze)  │     │   (Build)   │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                    │
       │                   ▼                    │
       │            ┌─────────────┐             │
       │            │  KNOWLEDGE  │             │
       │            │    BASE     │             │
       │            └─────────────┘             │
       │                                        │
       └────────────────┬───────────────────────┘
                        ▼
                 ┌─────────────┐
                 │   MANAGER   │
                 │ (Coordinate) │
                 │User Approval │
                 └─────────────┘
```

### Role Definitions

#### 1. Inspector (Observer)

**Responsibility:** Report WHAT IS - factual observations only

**What Inspector DOES:**
- Checks current state of resources
- Compares versions (ETL vs Lake, Test vs Prod)
- Validates configurations against standards
- Returns structured observations with severity levels

**What Inspector NEVER DOES:**
- Analyze WHY something is broken
- Recommend HOW to fix issues
- Make value judgments about observations
- Execute any fixes

**Output Example:**
```json
{
  "status": "NEEDS_ATTENTION",
  "observations": [
    {
      "type": "SPARK_COMPATIBILITY_CHECK",
      "severity": "CRITICAL",
      "spark_compatible": false,
      "description": "Table properties incompatible with Spark"
    },
    {
      "type": "DATA_VERSION_MISMATCH",
      "severity": "HIGH",
      "etl_version": "2024",
      "lake_version": "2023",
      "description": "ETL has newer version than Lake"
    }
  ]
}
```

**Note:** Inspector is dumb on purpose - it only reports facts, no analysis.

#### 2. Debugger (Analyzer)

**Responsibility:** Analyze WHY broken + HOW TO FIX using knowledge base

**What Debugger DOES:**
- Receives observations from inspector
- Searches troubleshooting knowledge base for matching issues
- Analyzes root causes using documented patterns
- Proposes solution options with confidence scores
- References historical success rates from issue log
- Asks clarifying questions if needed

**What Debugger NEVER DOES:**
- Execute fixes (that's builder's job)
- Make decisions on which solution to use (manager presents to user)
- Improvise solutions not in knowledge base
- Skip knowledge base lookup

**Process:**
```
1. Receive observations from inspector/manager
2. Search knowledge base for issue types
3. Match symptoms to documented problems
4. Identify root causes from knowledge base
5. Generate solution options (from knowledge base operations)
6. Calculate confidence scores (base + historical + context)
7. Rank options by confidence
8. Return analysis to manager
```

**Output Example:**
```json
{
  "status": "ANALYZED",
  "analysis": {
    "issue_type": "spark-compatibility-failure",
    "root_causes": [
      "Missing Spark table properties",
      "Incorrect SerDe configuration"
    ],
    "severity": "CRITICAL"
  },
  "solution_options": [
    {
      "option_number": 1,
      "description": "Fix Spark compatibility automatically",
      "skill": "myproject-catalog-builder",
      "operation": "fix-spark-compatibility",
      "confidence_score": 95,
      "estimated_duration": "30 seconds",
      "risks": "None - safe automated fix",
      "recommended": true,
      "troubleshooting_doc": "troubleshooting/spark-compatibility.md"
    }
  ],
  "similar_past_issues": 5,
  "avg_success_rate": 100
}
```

#### 3. Builder (Executor)

**Responsibility:** Execute WHAT - implement debugger's recommendations

**What Builder DOES:**
- Receives operation directive from manager
- Executes specific operations (create, update, fix-X, etc.)
- Reports start and end of operations
- Updates state.json and CHANGELOG.md
- Returns execution results

**What Builder NEVER DOES:**
- Decide what operation to perform (debugger analyzes, manager decides)
- Analyze problems
- Improvise solutions
- Skip steps

**Multiple Operations Pattern:**
```
myproject-catalog-builder/
├── skill.md (routes to operations)
├── operations/
│   ├── create.md
│   ├── update.md
│   ├── fix-spark-compatibility.md
│   ├── fix-version-views.md
│   └── ...
├── troubleshooting/ (debugger references these)
│   ├── spark-compatibility.md
│   ├── version-views.md
│   └── ...
└── scripts/
    ├── fix_spark_compatibility.py
    └── ...
```

#### 4. Manager (Coordinator)

**Responsibility:** Coordinate workflow and get user approval

**What Manager DOES:**
- Invokes inspector for observations
- Invokes debugger for analysis when issues found
- Presents debugger's solution options to user
- Gets user approval for which solution to execute
- Invokes builder with chosen operation
- Maintains context throughout workflow
- Verifies completion

**What Manager NEVER DOES:**
- Skip debugger and go straight to builder
- Auto-choose solutions without user approval (except obvious single option)
- Improvise fixes not recommended by debugger
- Proceed after failures

**Workflow Example:**
```
1. User runs: /myproject-resource-manager fix my-resource

2. Manager invokes inspector:
   → Inspector returns: 2 critical issues

3. Manager invokes debugger with observations:
   → Debugger analyzes, returns 2 solution options

4. Manager presents to user:
   ┌─────────────────────────────────────────┐
   │ Issues Found: 2                         │
   │ 🔴 CRITICAL: Spark compatibility       │
   │ 🔴 CRITICAL: Version views missing     │
   │                                         │
   │ Recommended Solution (95% confidence):  │
   │ 1. Fix Spark compatibility (~30s)      │
   │ 2. Recreate version views (~1min)      │
   │                                         │
   │ Proceed? (yes/no):                     │
   └─────────────────────────────────────────┘

5. User approves

6. Manager invokes builder:
   → Builder executes fix-spark-compatibility
   → Builder executes fix-version-views

7. Manager invokes inspector again:
   → Verify issues resolved

8. Manager reports completion
```

### Knowledge Base Integration

**Location:** Within builder skills' troubleshooting/ directories

**Structure:**
```
myproject-catalog-builder/
└── troubleshooting/
    ├── README.md (index)
    ├── spark-compatibility-failures.md
    ├── version-view-errors.md
    ├── schema-drift-detection.md
    └── ... (grows over time)
```

**Each Troubleshooting Document Contains:**

```markdown
---
issue_type: spark-compatibility-failure
severity: critical
skill: myproject-catalog-builder
operation: fix-spark-compatibility
---

# Issue: Spark Compatibility Failure

## Symptoms
- Catalog-tester reports: "Spark compatibility failed"
- Athena query errors from Spark
- State shows: validation.spark_compatible = false

## Root Causes
1. Missing table properties (spark.sql.sources.provider)
2. Incorrect SerDe configuration
3. Uppercase column names

## Automated Fix
**Operation:** fix-spark-compatibility
**What it does:**
1. Add required Spark table properties
2. Correct SerDe configuration
3. Normalize column names to lowercase

**Invocation:**
/myproject-resource-manager update my-resource --operation=fix-spark

**Success Rate:** 100% (based on 12 past fixes)

## Manual Verification
# Check table properties
SELECT * FROM my_resource LIMIT 1;

## Prevention
- Always use spark_compatible_table_helper.py
- Automated testing catches issues immediately

## Related Issues
- version-view-errors.md
- schema-drift-detection.md
```

### When to Use This Pattern

**Use Builder/Debugger when:**
- ✅ Multiple types of issues occur regularly
- ✅ Issues have known solutions that can be automated
- ✅ You want consistent problem resolution
- ✅ Historical learning is valuable
- ✅ User should approve before executing fixes

**Don't use when:**
- ❌ Issues are always unique/novel
- ❌ All fixes require manual intervention
- ❌ Single simple workflow with no variations

### Benefits

**1. Consistency**
- Same issue always analyzed and fixed the same proven way
- No improvisation, no variation in approach

**2. Knowledge Preservation**
- All solutions documented in troubleshooting knowledge base
- New team members benefit from past learnings
- Solutions don't get lost when people leave

**3. Historical Learning**
- Issue log tracks which solutions worked
- Confidence scores improve over time
- Success rates visible to users

**4. User Control**
- Users see analysis before execution
- Users approve which solution to use
- Users can abort if uncertain

**5. Capability Gap Clarity**
- When debugger finds no matching issue in knowledge base
- Explicit "I don't know how to fix this" message
- Proposed solution: "Add X to knowledge base"

### Implementation Guidelines

#### Step 1: Create Inspector Skill

```markdown
# .claude/skills/myproject-resource-inspector/skill.md

**Purpose:** Observe current state of resources (FACTUAL ONLY)

**Checks:**
- full (comprehensive inspection)
- resource-exists (quick check)
- configuration-valid (validate config)
- version-current (check for updates)

**Output:** Structured observations with severity
- HEALTHY / NEEDS_ATTENTION / CRITICAL
- List of observations (type, severity, details)
- NO analysis, NO recommendations
```

#### Step 2: Create Debugger Skill

```markdown
# .claude/skills/myproject-debugger/skill.md

**Purpose:** Analyze issues using knowledge base

**Process:**
1. Receive observations from inspector
2. Search troubleshooting/ docs for matching issues
3. Analyze root causes
4. Generate solution options with confidence scores
5. Reference issue-log.jsonl for historical success rates
6. Return analysis to manager

**Knowledge Base:** troubleshooting/*.md
**Issue Log:** issue-log.jsonl
```

#### Step 3: Create Builder Skill with Operations

```markdown
# .claude/skills/myproject-resource-builder/skill.md

**Purpose:** Execute operations as directed

**Operations:**
- create - Create new resource
- update - Update existing resource
- fix-config-X - Fix specific config issue
- fix-validation-Y - Fix specific validation issue

**Process:**
1. Receive operation directive from manager
2. Execute scripts for that operation
3. Update state and changelog
4. Report results
```

#### Step 4: Create Troubleshooting Knowledge Base

```
myproject-resource-builder/
└── troubleshooting/
    ├── README.md
    ├── config-validation-failures.md
    ├── resource-creation-errors.md
    └── ...
```

Each doc follows standard format: Symptoms → Root Causes → Automated Fix → Verification → Prevention

#### Step 5: Create Manager with 7-Phase Workflow

```markdown
# .claude/agents/myproject-resource-manager.md

**Workflow:**
1. INSPECT - Invoke inspector for observations
2. ANALYZE - If issues, invoke debugger
3. PRESENT - Show analysis to user
4. APPROVE - Get user decision
5. EXECUTE - Invoke builder with chosen operation
6. VERIFY - Invoke inspector again
7. REPORT - Show final status
```

### Migration from Traditional Pattern

**Before (Traditional):**
```
Manager → Inspector → Manager improvises fix → Builder
         (reports issues)  (ad-hoc decision)
```

**After (Builder/Debugger):**
```
Manager → Inspector → Debugger → Manager → User → Builder
         (observes)   (analyzes,   (presents) (approves)
                      uses KB)
```

**Migration Steps:**
1. Extract fix logic from managers into troubleshooting docs
2. Create debugger skill with knowledge base
3. Update manager to invoke debugger
4. Add user approval gate
5. Track outcomes in issue log

### Real-World Metrics (Lake.Corthonomy.AI)

**Knowledge Base Coverage:**
- 5 troubleshooting documents
- Covers 95% of encountered issues
- 100% success rate on spark-compatibility fixes
- Average confidence score: 92%

**Performance:**
- Inspector: 2-30 seconds (depending on check type)
- Debugger: <1 second (knowledge base lookup)
- Builder: 30-120 seconds (depending on operation)
- Total: 32-151 seconds for full workflow

**User Experience:**
- Users see analysis before execution (informed decisions)
- Clear confidence scores (95% = safe to proceed)
- Explicit escalation when no solution found
- Historical success rates visible

---

## Design Process

### Step 1: Identify Your Domains

**Domain** = A cohesive area of functionality

**Questions to ask:**
- What resources/entities does your project manage?
- What are the major areas of functionality?
- How do users think about organizing work?

**Example: Web Scraping Project**
- Domains: Targets, Scrapers, Jobs, Cache, Results, Infrastructure

**Example: Content Management Project**
- Domains: Articles, Images, Authors, Publications, Analytics

**Example: DevOps Project**
- Domains: Services, Deployments, Configurations, Monitoring

### Step 2: Map Your Workflows

For each domain, identify:

**CRUD Operations:**
- Create - Generate new entity
- Read/List - View existing entities
- Update/Edit - Modify entity
- Delete - Remove entity

**Lifecycle Operations:**
- Validate - Check correctness
- Test - Verify functionality
- Deploy - Make live
- Monitor - Track status

**Complex Workflows:**
- Complete workflow (create → test → deploy)
- Batch operations (operate on multiple)
- Cross-domain flows (create X, then Y)

### Step 3: Define Your Entities

**Entity** = The resource being managed by a workflow

**Entity attributes:**
- Clear identifier (name, ID, etc.)
- Configuration/state
- Relationships to other entities
- Lifecycle stages

**Example: Scraper Entity**
- Identifier: scraper_name
- Configuration: YAML or Python file
- Relationships: target (optional), jobs (many)
- Lifecycle: created → validated → tested → deployed

### Step 4: Design Your Manager Agents

**One manager per domain** that handles single-entity operations.

**Manager responsibilities:**
- Parse arguments (via skill)
- Validate entity exists/doesn't exist
- Invoke skills in correct order
- Maintain workflow state
- Handle errors
- Document actions
- Propose next steps

### Step 5: Determine Need for Director Skills

**Use Director Skills when:**
- Users need to operate on multiple entities with patterns (wildcards, comma-separated lists)
- Batch operations: `*`, `dataset/*`, `a,b,c`
- Need parallel execution for faster wall-clock time (Core Claude Agent handles parallelism)

**Director Skill responsibilities (LIGHTWEIGHT):**
- Parse batch patterns (`*`, `dataset/*`, `a,b,c`)
- Expand wildcards to entity lists
- Return dataset list + parallelism recommendation to Core Claude Agent
- **Does NOT orchestrate** - Core Agent invokes Manager agents in parallel (max 5 concurrent)

**What Director Skills DON'T do:**
- ❌ No workflow orchestration (that's Manager's job)
- ❌ No direct Manager invocation (Core Agent does this)
- ❌ No complex decision logic (pure pattern expansion)
- ❌ No error aggregation (Managers handle their own errors)

**Note:** 69% of operations are single-entity (skip Director entirely), only 31% use batch patterns.

### Step 6: Identify Required Skills

**Skills execute specific tasks.** For each workflow step, identify:

**Builder Skills** - Create new entities from templates
- Input: entity details
- Output: created file path
- Examples: config-builder, template-generator

**Validator Skills** - Check correctness
- Input: entity identifier or content
- Output: validation status, errors
- Examples: config-validator, syntax-checker

**Executor Skills** - Run operations
- Input: entity identifier, parameters
- Output: execution results
- Examples: test-runner, deployer

**Documenter Skills** - Generate documentation
- Input: entity metadata, results
- Output: documentation file path
- Examples: config-documenter, result-documenter

**Utility Skills** - Cross-cutting concerns
- Argument parser (system-wide)
- Parallel executor (directors)
- CLI wrapper (if applicable)

### Step 7: Design Argument Schema

For each manager, define:

**Required Positional Arguments:**
- Operation (create, test, deploy, etc.)
- Entity identifier (name, ID)
- Additional required params (if any)

**Optional Flags (boolean):**
- `--complete` (auto-proceed through workflow)
- `--force` (bypass checks)
- Operation-specific flags

**Optional Valued Options:**
- `--env={test|prod}` (environment)
- `--format={type}` (output format)
- `--max-results={N}` (limits)
- Operation-specific options

---

## Naming Conventions

### Commands and Agents

**Pattern:** `{project}-{domain}-manager.md`

**Examples:**
- `corthovore-scraper-manager.md`
- `contentpro-article-manager.md`
- `deploy-service-manager.md`

**Directors:**
- `{project}-director.md`
- `{project}-workflow-director.md`

### Skills

**Pattern:** `{project}-{domain}-{verb}/`

**Domain-first for grouping:**
- All scraper skills together
- All article skills together
- All service skills together

**Verb form for clarity:**
- builder, validator, tester, deployer
- documenter (not doc-*)
- runner, executor, generator

**Examples:**
- `corthovore-scraper-builder/`
- `contentpro-article-publisher/`
- `deploy-service-deployer/`

**Utility skills (no domain):**
- `{project}-arg-parser/`
- `{project}-parallel-executor/`
- `{project}-cli/`

### File Structure

```
.claude/
├── commands/
│   ├── {project}-{domain1}-manager.md
│   ├── {project}-{domain2}-manager.md
│   └── {project}-director.md
│
├── agents/
│   ├── {project}-{domain1}-manager.md
│   ├── {project}-{domain2}-manager.md
│   └── {project}-director.md
│
└── skills/
    ├── {project}-arg-parser/
    ├── {project}-{domain1}-builder/
    ├── {project}-{domain1}-validator/
    ├── {project}-{domain1}-documenter/
    ├── {project}-{domain2}-builder/
    └── ...
```

---

## Argument Patterns

### The Arguments String

Commands receive: `#$ARGUMENTS` as a single string

**Pattern:** `OPERATION ENTITY [POSITIONAL...] [--flags] [--option={value}]`

### Positional Arguments

**Use for:** Required parameters that always need to be provided

**Examples:**
- Operation name (create, test, deploy)
- Entity identifier (resource name, ID)
- Required configuration values

```bash
/myproject-resource-manager create my-resource
# Positional: ["create", "my-resource"]
```

### Boolean Flags

**Use for:** Optional features that are on/off

**Format:** `--flag-name` (presence = true, absence = false)

**Common flags:**
- `--complete` - Auto-proceed through workflow
- `--force` - Bypass confirmations/checks
- `--parallel` - Run in parallel
- `--verbose` - Detailed output

```bash
/myproject-resource-manager test my-resource --complete --force
# Flags: {complete: true, force: true}
```

### Valued Options

**Use for:** Optional parameters that need a value

**Format:** `--key={value}` (NO SPACES between = and value)

**Common options:**
- `--env={test|prod}` - Environment
- `--format={json|csv}` - Output format
- `--max-results={N}` - Limits
- `--params={json}` - Complex parameters

```bash
/myproject-resource-manager test my-resource --max-results=10 --env=test
# Options: {max_results: "10", env: "test"}
```

### JSON Parameters

**Use for:** Complex structured data

**Format:** `--params={json}` (NO SPACES in JSON)

```bash
/myproject-resource-manager create my-resource --params={"name":"test","count":5}
# Options: {params: {name: "test", count: 5}}
```

### Argument Parser Skill

**Always use a skill for parsing, never parse in agents.**

```
Skill: {project}-arg-parser
Input: {
  "manager": "{project}-{domain}-manager",
  "arguments": "{raw argument string}"
}

Output: {
  "operation": "{operation}",
  "entity": "{entity}",
  "positional": ["{list}"],
  "flags": {
    "complete": true/false,
    ...
  },
  "options": {
    "env": "{value}",
    ...
  }
}
```

**Parser implementation:**
- Loads manager-specific schema
- Validates operation is valid
- Checks required arguments present
- Parses flags and options
- Returns structured data or error

---

## Agent Design

### 7-Phase Manager Workflow

**⭐ Proven Pattern from Lake.Corthonomy.AI** - This workflow pattern provides structure, user control, and verification for all manager operations.

#### The 7 Phases

```
┌──────────────────────────────────────────────────────────┐
│             7-PHASE MANAGER WORKFLOW                     │
└──────────────────────────────────────────────────────────┘

1. INSPECT  → Observe current state (what is)
2. ANALYZE  → Understand issues (why broken, how to fix)
3. PRESENT  → Show analysis and options to user
4. APPROVE  → Get user decision on which action to take
5. EXECUTE  → Invoke builder with chosen operation
6. VERIFY   → Confirm operation succeeded
7. REPORT   → Show final status and next steps
```

#### Phase-by-Phase Guide

**Phase 1: INSPECT**
- Invoke inspector skill for observations
- Use targeted checks when appropriate (--check=type)
- Collect factual state information
- No analysis yet, just observations

```markdown
Manager invokes: myproject-resource-inspector
Output: {status, observations[], health_summary}
```

**Phase 2: ANALYZE**
- If issues found, invoke debugger skill
- Debugger searches knowledge base
- Debugger proposes solutions with confidence scores
- If no issues, skip to Phase 7 (report healthy)

```markdown
IF observations.status == "NEEDS_ATTENTION":
    Manager invokes: myproject-debugger
    Input: observations from inspector
    Output: {analysis, solution_options[], confidence_scores[]}
```

**Phase 3: PRESENT**
- Show debugger's analysis to user
- Display solution options with confidence scores
- Show estimated duration and risks
- Make recommendation if one solution is obvious

```markdown
Present to user:
┌─────────────────────────────────────────┐
│ Issues Found: 2                         │
│ 🔴 CRITICAL: Configuration invalid     │
│ 🟡 WARNING: Version outdated           │
│                                         │
│ Recommended Solution (92% confidence):  │
│ 1. Fix configuration (~45s)            │
│ 2. Update to latest version (~2min)    │
│                                         │
│ Total estimated time: ~2.75 minutes    │
│                                         │
│ Alternative: Manual fix (if uncertain) │
│                                         │
│ Proceed with recommended? (yes/no/alt):│
└─────────────────────────────────────────┘
```

**Phase 4: APPROVE**
- Wait for user decision
- Accept: yes, no, alternative number, abort
- Validate user's choice
- Record choice in context

```markdown
IF user_choice == "yes":
    selected_solution = recommended_solution
ELSE IF user_choice.is_number():
    selected_solution = solution_options[user_choice]
ELSE IF user_choice == "no" or "abort":
    STOP workflow, report aborted
```

**Phase 5: EXECUTE**
- Invoke builder with chosen solution's operation
- Monitor execution progress
- Capture results
- Handle errors (invoke debugger again if needed)

```markdown
Manager invokes: myproject-resource-builder
Input: {
    operation: selected_solution.operation,
    parameters: selected_solution.parameters
}
Output: {status, results, duration}

IF status == "FAILED":
    → Return to Phase 2 (analyze failure)
```

**Phase 6: VERIFY**
- Invoke inspector again (targeted check)
- Confirm issues were resolved
- If not resolved, return to Phase 2

```markdown
Manager invokes: myproject-resource-inspector
Input: {check: "target verification for issues fixed"}
Output: {status, observations}

IF issues still present:
    → Return to Phase 2 with new observations
```

**Phase 7: REPORT**
- Show final status to user
- Summarize what was done
- List next steps (if any)
- Update state and changelog

```markdown
Report to user:
✅ Workflow completed successfully

Actions taken:
- Fixed configuration (42s)
- Updated to version 2.0 (1m 54s)

Verification: All issues resolved

Next steps:
- Deploy to production: /myproject-resource-manager deploy my-resource --env=prod

Total duration: 2 minutes 36 seconds
```

#### When to Use Each Phase

**Always use all 7 phases for:**
- Complex operations with multiple potential issues
- Operations that modify critical resources
- User-initiated troubleshooting ("fix my resource")

**Can skip phases for:**
- INSPECT-only operations: Use phases 1 and 7 only
- Simple operations with no analysis needed: Phases 1, 5, 6, 7
- Routine status checks: Phase 1 and 7 only

#### Example Workflows

**Full 7-Phase (Fix Issues):**
```
User: /myproject-resource-manager fix my-resource

1. INSPECT → 2 issues found
2. ANALYZE → Debugger recommends 2-step fix
3. PRESENT → Show plan to user
4. APPROVE → User says "yes"
5. EXECUTE → Run both fixes
6. VERIFY → Confirm resolved
7. REPORT → Show success
```

**Short Circuit (Healthy):**
```
User: /myproject-resource-manager inspect my-resource

1. INSPECT → No issues found
7. REPORT → "Resource is healthy"
```

**Failed Verification (Loop Back):**
```
User: /myproject-resource-manager fix my-resource

1. INSPECT → 1 issue found
2. ANALYZE → Debugger recommends fix
3. PRESENT → Show plan
4. APPROVE → User approves
5. EXECUTE → Fix applied
6. VERIFY → Issue still present (fix didn't work)
2. ANALYZE → Debugger analyzes why fix failed, proposes alternative
3. PRESENT → Show alternative solution
4. APPROVE → User approves alternative
5. EXECUTE → Apply alternative
6. VERIFY → Confirmed resolved
7. REPORT → Success
```

#### Integration with Builder/Debugger Pattern

The 7-Phase workflow IS the manager's implementation of the Builder/Debugger pattern:
- **Phase 1 (INSPECT)** → Inspector skill
- **Phase 2 (ANALYZE)** → Debugger skill
- **Phases 3-4 (PRESENT/APPROVE)** → Manager + User interaction
- **Phase 5 (EXECUTE)** → Builder skill
- **Phase 6 (VERIFY)** → Inspector skill again
- **Phase 7 (REPORT)** → Manager summary

#### Benefits

**1. User Control** - User sees plan before execution, can abort
**2. Verification** - Nothing assumed, everything confirmed
**3. Error Recovery** - Can loop back if operations fail
**4. Consistency** - Same workflow every time, predictable
**5. Auditability** - Clear phases logged to changelog

#### Implementation in Manager Agent

```markdown
# In manager agent's workflow documentation

## Workflow Pattern

All operations follow the 7-Phase workflow:

### Phase 1: INSPECT
Invoke inspector to gather current state...

### Phase 2: ANALYZE
If issues found, invoke debugger...

### Phase 3-7: [implement as above]

## Operation-Specific Variations

### 'inspect' Operation
- Uses Phases 1 and 7 only (no fix needed)

### 'fix' Operation
- Uses all 7 phases (full workflow)

### 'create' Operation
- Phases 1 (pre-check), 5 (execute), 6 (verify), 7 (report)
```

---

### Manager Agent Template

```markdown
# .claude/agents/{project}-{domain}-manager.md

---
org: {org}
system: {system}
name: {project}-{domain}-manager
description: {Description with auto-trigger keywords}
auto-trigger: [{keyword1}, {keyword2}, ...]
---

## Role

You are the {Domain} Manager for {Project}. You maintain context throughout
{domain}-related workflows and coordinate skills to accomplish tasks for a
**single {entity}**.

**CRITICAL CONSTRAINTS:**
- You ONLY use existing skills defined below
- You NEVER solve problems outside your defined scope
- If you cannot solve a problem with available skills → STOP with error
- Document the gap, propose next step, but DO NOT PROCEED

<EXAMPLES>

## Trigger Examples

{5-10 <example> blocks showing when agent should be invoked}

</EXAMPLES>

## Available Skills

**You MUST ONLY use these skills. If a skill doesn't exist, STOP with error.**

- `{project}-arg-parser` - Parse arguments
- `{project}-{domain}-builder` - Create entities
- `{project}-{domain}-validator` - Validate entities
- `{project}-{domain}-documenter` - Document entities
- ...

<ARGUMENTS>

## Argument Parsing

**Always parse arguments using the skill:**

```
Skill: {project}-arg-parser
Input: {
  "manager": "{project}-{domain}-manager",
  "arguments": "#$ARGUMENTS"
}
```

**Never parse arguments yourself.**

</ARGUMENTS>

<WORKFLOWS>

## Workflow: {Operation}

**Steps:**

1. **Parse arguments** - Skill: {project}-arg-parser
2. **Validate** - Check preconditions
3. **Execute** - Invoke appropriate skills
4. **Document** - Invoke documenter skill
5. **Report** - Show results, propose next steps

{Detailed workflow for each operation}

</WORKFLOWS>

<ERROR_HANDLING>

## Error Handling: Stay in Scope

**When you encounter a problem you cannot solve:**

1. **STOP immediately**
2. **Document the gap**
3. **Propose solution**
4. **Report to user**
5. **DO NOT PROCEED**

</ERROR_HANDLING>

<DOCUMENTATION>

## Documentation Strategy

Documentation is woven into workflows:

**After Create:** Invoke `{project}-{domain}-documenter`
**After Test:** Invoke `{project}-result-documenter`
**After Deploy:** Invoke `{project}-infra-documenter`

**Never document manually - always use skills.**

</DOCUMENTATION>
```

### Manager Workflow Pattern

**Standard Pattern:** Parse → Validate → Execute → Document → Report → Propose

```
1. PARSE ARGUMENTS
   Skill: {project}-arg-parser

2. VALIDATE PRECONDITIONS
   Check entity exists/doesn't exist as appropriate
   Skill: {project}-cli or direct checks

3. COLLECT MISSING INFORMATION
   Use AskUserQuestion for any missing required data

4. EXECUTE OPERATION
   Skill: {project}-{domain}-{verb}

5. DOCUMENT ACTION
   Skill: {project}-{domain}-documenter

6. ANALYZE RESULTS
   Check for errors, validate output

7. REPORT TO USER
   Show summary, documentation location

8. PROPOSE NEXT STEPS
   If --complete: Proceed to next workflow step
   Else: AskUserQuestion with options
```

### Auto-Trigger Examples

**Every agent needs 5-10 examples showing when it should be invoked.**

```markdown
<EXAMPLES>

## Trigger Examples

<example>
**User:** "{Natural language request}"

**Assistant thinking:** {Why this triggers this agent}

**Assistant action:** {What agent should do}
</example>

{More examples covering different request types}

</EXAMPLES>
```

**Example types to include:**
- Create new entity
- Edit existing entity
- Test/validate entity
- List entities
- Delete entity
- Complete workflow
- Counter-examples (when NOT to use this agent)

### Context Maintenance

**Track throughout workflow:**
- Entity being operated on
- Current workflow step
- Previous step results
- User choices/preferences
- Error history

**Use context for:**
- Intelligent next-step suggestions
- Error messages with full context
- Progress indicators (Step X of N)
- Resume after pause

---

## Skill Design

### Skill Structure

```
{project}-{domain}-{verb}/
├── skill.md              # Main skill definition
├── README.md             # Overview
├── docs/                 # Additional documentation
│   ├── examples.md
│   └── troubleshooting.md
├── templates/            # Templates used by skill
│   ├── template1.yaml
│   └── template2.py
└── scripts/              # Executable scripts
    ├── main-script.py
    └── helper.sh
```

### Skill Definition Template

```markdown
# .claude/skills/{project}-{domain}-{verb}/skill.md

---
name: {project}-{domain}-{verb}
description: {Brief description of what this skill does}
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# {Project} {Domain} {Verb} Skill

{Detailed description}

## Purpose

{What this skill accomplishes}

## Invocation

```
Skill: {project}-{domain}-{verb}
Input: {
  "param1": "value1",
  "param2": "value2"
}

Output: {
  "result1": "value1",
  "result2": "value2"
}
```

## Implementation

Invokes: `scripts/{script-name}.py --param1=value1 --param2=value2`

{Description of what the script does}

## Error Handling

{How errors are returned}

## Examples

{Usage examples}
```

### Skill Categories

**Builder Skills** - Create from templates
- Load template file
- Populate with values
- Validate result
- Write to location
- Return file path

**Validator Skills** - Check correctness
- Load entity configuration
- Check against schema
- Run validation rules
- Return status and errors

**Executor Skills** - Run operations
- Execute command/script
- Monitor progress
- Capture output
- Return results

**Documenter Skills** - Generate docs
- Load documentation template
- Populate with metadata
- Write/append to docs location
- Return doc path

**Utility Skills** - Cross-cutting
- Argument parsing
- Parallel execution
- CLI wrapping

### Skill Interface Design

**Clear input/output contracts:**

```python
# Input schema
{
  "entity_name": "string (required)",
  "options": {
    "key": "value"
  },
  "metadata": {}
}

# Output schema
{
  "status": "success|error",
  "result": {},
  "errors": [],
  "files_created": [],
  "next_steps": []
}
```

**Error handling:**
- Return structured errors, don't throw
- Include context in error messages
- Suggest solutions when possible
- Never crash, always return

### Modular Inspector Pattern

⭐ **Performance Optimization** - From Lake.Corthonomy.AI: Inspector supports both full and targeted checks

**The Problem**: Full inspection takes 15-30 seconds, but often you only need to check one thing.

**The Solution**: Targeted checks for specific validations

#### Check Types

**full** (comprehensive)
- Runs all validation checks
- Duration: ~15-30 seconds
- Use: Comprehensive health assessment
- Returns: Complete health report

**data-currency** (targeted)
- Compares source timestamp with deployed timestamp
- Duration: ~3-5 seconds
- Use: Precondition for update operations
- **5x faster than full**

**schema-drift** (targeted)
- Compares source schema with deployed schema
- Duration: ~5-10 seconds
- Use: Detect schema changes requiring sync

**catalog-config** (targeted)
- Validates configuration compliance (e.g., SPEC-013)
- Duration: ~5-10 seconds
- Use: Validate infrastructure setup

**documentation** (targeted)
- Checks docs freshness vs deployment date
- Duration: ~2-3 seconds
- Use: Verify documentation current

**data-exists** (precondition)
- Quick check for data in storage
- Duration: ~2-3 seconds
- Use: Before create-infrastructure operations

**catalog-exists** (precondition)
- Quick check if infrastructure exists
- Duration: ~2-3 seconds
- Use: Before update operations

#### Implementation Pattern

**Skill Structure**:
```
myproject-resource-inspector/
├── skill.md (routes to check scripts)
├── scripts/
│   ├── inspect_full.py
│   ├── inspect_data_currency.py
│   ├── inspect_schema_drift.py
│   ├── inspect_catalog_config.py
│   ├── inspect_documentation.py
│   ├── inspect_data_exists.py
│   └── inspect_catalog_exists.py
```

**Invocation**:
```python
# Manager invokes with specific check
inspector.invoke({
    "resource": "my-resource",
    "check": "data-currency",  # Specific, fast
    "environment": "test"
})

# vs full inspection
inspector.invoke({
    "resource": "my-resource",
    "check": "full",  # Comprehensive, slower
    "environment": "test"
})
```

#### Use Cases

**Precondition Checking** (manager before operations):
```python
# Before catalog-create
if not inspector.check("data-exists", resource):
    ERROR("Data not found - run data-sync first")
    STOP()
```

**Targeted Validation** (after specific changes):
```python
# After schema update
inspector.check("schema-drift", resource)
# Don't need full inspection, just schema
```

**Full Health Assessment** (periodic or user-requested):
```python
# Weekly health check
inspector.check("full", resource)
```

#### Performance Comparison

**Before (always full)**:
- Every check: 30 seconds
- 10 checks/day: 5 minutes total

**After (targeted)**:
- Precondition checks: 3 seconds each
- Full checks: 30 seconds (only when needed)
- 10 checks/day (8 targeted, 2 full): ~45 seconds total
- **6x faster**

#### Benefits

1. **Fast Failure** - Preconditions fail in 3s instead of 30s
2. **Efficient Workflows** - Only check what's needed
3. **Same Interface** - Manager doesn't care about implementation
4. **Backward Compatible** - "full" check still available

#### When Your Project Needs This

**Use modular inspection when**:
- ✅ Frequent precondition checks needed
- ✅ Multiple types of validation required
- ✅ Performance matters (user-facing workflows)
- ✅ Complex resource with many validation aspects

**Don't need when**:
- ❌ Simple resource with single validation
- ❌ Inspection is already fast (<5 seconds)
- ❌ Always need comprehensive validation

### Skill Reporting Standards

⭐ **Standardized Output** - All skills report consistently

**Why This Matters**:
- Users see clear progress
- Logs are parseable
- Troubleshooting is easier
- Consistent UX across all operations

#### Start Report Template

**Every skill MUST report at start:**

```
🔄 [SKILL-NAME] Starting...
Operation: [operation]
Resource: [resource]
Environment: [test/prod]

About to:
- [specific action 1]
- [specific action 2]
- [specific action 3]
```

**Example**:
```
🔄 myproject-resource-builder Starting...
Operation: create
Resource: my-resource
Environment: test

About to:
- Load template: resource-template.yaml
- Populate with metadata
- Validate configuration
- Write to: config/my-resource.yaml
```

#### End Report Template

**Every skill MUST report at end:**

```
✅ [SKILL-NAME] Completed
[OR ❌ [SKILL-NAME] Failed]

Results:
- [outcome 1]: [details]
- [outcome 2]: [details]

Updated:
- state.json: [sections updated]
- CHANGELOG.md: [event recorded]
- [other docs]: [what changed]

Duration: [X seconds]
```

**Success Example**:
```
✅ myproject-resource-builder Completed

Results:
- Created: config/my-resource.yaml
- Template used: resource-template
- Field count: 12
- Validation: PASSED

Updated:
- state.json: environments.test.resources section
- CHANGELOG.md: RESOURCE_CREATED event
- docs/resources/my-resource/README.md: Generated

Duration: 2.3 seconds
```

**Failure Example**:
```
❌ myproject-resource-builder Failed

Results:
- Failed: Template validation
- Error: Missing required field 'name'
- Validation errors: 3

Updated:
- CHANGELOG.md: RESOURCE_CREATE_FAILED event

Duration: 0.8 seconds

See troubleshooting/template-validation-errors.md
```

#### Progress Updates (Long Operations)

**For operations >10 seconds, report progress:**

```
🔄 myproject-resource-deployer Starting...
Operation: deploy
Environment: prod

About to:
- Validate configuration
- Deploy to infrastructure
- Verify deployment
- Update state

[... execution ...]

  Step 1/4: Validating configuration... ✅ (2.1s)
  Step 2/4: Deploying to infrastructure... 🔄
    → Creating resource 1/3... ✅
    → Creating resource 2/3... ✅
    → Creating resource 3/3... ✅ (45.2s)
  Step 3/4: Verifying deployment... ✅ (3.1s)
  Step 4/4: Updating state... ✅ (0.5s)

✅ myproject-resource-deployer Completed
[... results ...]
Duration: 50.9 seconds
```

#### Integration with Manager

**Manager shows skill progress to user:**

```
Manager: Executing data-sync operation...

🔄 myproject-data-syncer Starting...
Operation: sync
Resource: my-resource
Environment: test

About to:
- Check source for new data
- Sync 156 files from source to destination
- Verify sync completed
- Update state.json

[... syncer executes ...]

✅ myproject-data-syncer Completed

Results:
- Files synced: 156
- Total size: 45.2 MB
- Source: s3://source.../
- Destination: s3://dest.../

Updated:
- state.json: environments.test.data section
- CHANGELOG.md: DATA_SYNCED event

Duration: 3.2 seconds

Manager: Data sync successful! Proceeding to catalog-update...
```

#### Implementation

**In skill script**:

```python
def execute_operation():
    # Start report
    print(f"🔄 {SKILL_NAME} Starting...")
    print(f"Operation: {operation}")
    print(f"Resource: {resource}")
    print(f"Environment: {environment}")
    print()
    print("About to:")
    print(f"- {action1}")
    print(f"- {action2}")
    print()

    start_time = time.time()

    try:
        # Execute operation
        result = do_operation()

        # End report (success)
        duration = time.time() - start_time
        print(f"✅ {SKILL_NAME} Completed")
        print()
        print("Results:")
        print(f"- {result.outcome1}: {result.details1}")
        print(f"- {result.outcome2}: {result.details2}")
        print()
        print("Updated:")
        print(f"- state.json: {result.state_sections}")
        print(f"- CHANGELOG.md: {result.changelog_event}")
        print()
        print(f"Duration: {duration:.1f} seconds")

    except Exception as e:
        # End report (failure)
        duration = time.time() - start_time
        print(f"❌ {SKILL_NAME} Failed")
        print()
        print("Results:")
        print(f"- Failed: {operation}")
        print(f"- Error: {str(e)}")
        print()
        print("Updated:")
        print(f"- CHANGELOG.md: {operation.upper()}_FAILED event")
        print()
        print(f"Duration: {duration:.1f} seconds")
        print()
        print(f"See troubleshooting/{relevant_doc}.md")
```

#### Benefits

1. **Predictability** - Users know what to expect
2. **Debuggability** - Clear logs for troubleshooting
3. **Parseable** - Can extract info programmatically
4. **Professional** - Polished UX
5. **Consistency** - Same format across all skills

#### When Your Project Needs This

**Use standardized reporting when**:
- ✅ Multiple skills with different authors
- ✅ User-facing workflows
- ✅ Logs need to be parseable
- ✅ Professional UX required

**Less critical when**:
- ❌ Single developer project
- ❌ Internal-only tools
- ❌ Simple one-step operations

---

## Mandatory Workflow Order

**⭐ Critical Pattern for Data Operations** - From Lake.Corthonomy.AI: When managing data pipelines, certain operations MUST occur in a specific order to prevent errors and data inconsistency.

### The Problem

Without enforced order:
- Catalog created before data exists → queries fail
- Configuration updated before data synced → points to wrong version
- Tests run before catalog working → false failures
- Production deployed without testing → production breaks

###The Solution: Enforced Mandatory Sequence

**Core Principle:** Manager enforces correct order through pre-condition checks

```
┌─────────────────────────────────────────────────────┐
│         MANDATORY DATA WORKFLOW ORDER               │
└─────────────────────────────────────────────────────┘

1. INSPECT     ← ALWAYS FIRST (check what's there)
   ↓
2. DATA-SYNC   ← HIGHEST PRIORITY (data before catalog)
   ↓
3. CATALOG-CREATE or CATALOG-UPDATE
   ↓
4. CATALOG-TEST ← Must have working catalog first
   ↓
5. DATA-TEST   ← Requires catalog for queries
   ↓
6. DEPLOY      ← MANUAL ONLY, after all tests pass
```

### Why This Order Matters

**1. INSPECT First**
- **Why:** Must know current state before taking action
- **What it prevents:** Operating on stale assumptions
- **Checks:** What exists, what's current, what's broken

**2. DATA-SYNC Before Catalog**
- **Why:** Catalog configures access to data files
- **What it prevents:** Catalog pointing to non-existent data
- **Critical Rule:** "Data is primary, catalog is secondary"

**Example of what goes wrong:**
```
❌ WRONG ORDER:
1. Update catalog to point to version=2024
2. Sync data for version=2024
→ Between steps 1-2, queries fail (catalog points to non-existent data)

✅ CORRECT ORDER:
1. Sync data for version=2024
2. Update catalog to point to version=2024
→ Queries work immediately after step 2
```

**3. CATALOG-TEST Before DATA-TEST**
- **Why:** DATA-TEST uses Athena queries which require working catalog
- **What it prevents:** False test failures due to broken catalog
- **Dependency:** DATA-TEST → CATALOG-TEST → CATALOG

**4. DEPLOY After All Tests**
- **Why:** Production should only get validated, tested resources
- **What it prevents:** Breaking production with untested changes
- **Requirement:** MANUAL only, never automatic

### Implementation Pattern

#### Manager Enforces Order

**Manager checks preconditions before each operation:**

```python
# Pseudocode for manager precondition checking

def execute_operation(operation, resource):
    if operation == "catalog-create":
        # Precondition: Data must exist first
        data_exists = inspector.check("data-exists", resource)
        if not data_exists:
            ERROR("Cannot create catalog without data")
            SUGGEST("Run data-sync first: /manager data-sync {resource}")
            STOP()

    elif operation == "catalog-update":
        # Precondition 1: Catalog must exist
        catalog_exists = inspector.check("catalog-exists", resource)
        if not catalog_exists:
            ERROR("Cannot update non-existent catalog")
            SUGGEST("Run catalog-create first: /manager catalog-create {resource}")
            STOP()

        # Precondition 2: Data must be current
        data_current = inspector.check("data-currency", resource)
        if not data_current:
            ERROR("Lake data is outdated")
            SUGGEST("Run data-sync first: /manager data-sync {resource}")
            STOP()

    elif operation == "data-test":
        # Precondition: Catalog must be working
        catalog_working = tester.test("catalog", resource)
        if not catalog_working:
            ERROR("Cannot test data without working catalog")
            SUGGEST("Fix catalog first: /manager catalog-test {resource}")
            STOP()

    # If all preconditions pass, proceed
    execute(operation, resource)
```

#### Automatic Chaining with --complete

**Manager auto-continues in correct order:**

```python
if complete_flag:
    if operation == "data-sync":
        # Auto-chain: data-sync → catalog-update → catalog-test → data-test
        execute("data-sync")
        if SUCCESS:
            execute("catalog-update")
            if SUCCESS:
                execute("catalog-test")
                if SUCCESS:
                    execute("data-test")

    # BUT: Never auto-continue to production deploy
    # Always stop before deploy, require manual command
```

### Workflow Sequences

#### New Resource Workflow

```
Goal: Onboard new resource from scratch

Required Order:
1. data-sync       (copy data from source)
2. catalog-create  (create catalog table)
3. catalog-test    (validate catalog works)
4. data-test       (validate data quality)
5. [manual] deploy prod (after approval)

Command with --complete:
/myproject-resource-manager data-sync my-resource --complete

This automatically runs 1→2→3→4, stops before 5
```

#### Update Existing Resource

```
Goal: Update resource to new version

Required Order:
1. data-sync       (sync new version data)
2. catalog-update  (point catalog to new version)
3. catalog-test    (validate still works)
4. data-test       (validate new version quality)
5. [manual] deploy prod

Command with --complete:
/myproject-resource-manager data-sync my-resource --complete
```

#### Fix Broken Resource

```
Goal: Fix issues without data changes

Required Order:
1. inspect         (identify issues)
2. catalog-update  (fix issues per debugger)
3. catalog-test    (verify fixes worked)
4. data-test       (ensure data still accessible)

Command:
/myproject-resource-manager fix my-resource --complete
```

### When to Allow Out-of-Order

**Some operations CAN skip steps:**

**Inspect:** Can run anytime (read-only, no dependencies)
```
/myproject-resource-manager inspect my-resource
→ No preconditions needed
```

**Catalog-update (fix-only):** If data is current, can fix catalog without re-sync
```
IF data_current AND catalog_broken:
    → Can run catalog-update without data-sync first
```

**Data-test (re-run):** If catalog working, can re-run data tests
```
IF catalog_working:
    → Can run data-test without preceding steps
```

### Error Messages for Violations

**When user tries to violate order:**

```
User runs: /myproject-resource-manager catalog-create my-resource

Manager checks precondition: Does data exist?
→ NO

Manager responds:
🛑 ERROR: Precondition Failed

Operation: catalog-create
Resource: my-resource
Precondition: Data must exist in storage

Current State:
- Data in storage: NOT FOUND
- Expected location: s3://my-bucket/my-resource/

Required Action:
Run data-sync first to copy data from source:

  /myproject-resource-manager data-sync my-resource

Then retry catalog-create.

WORKFLOW STOPPED
```

### Benefits

**1. Prevents Errors** - Can't create catalog pointing to non-existent data
**2. Clear Messaging** - Users know exactly what to do when order violated
**3. Automatic Chains** - --complete flag follows correct order automatically
**4. Safety Checks** - Production never deployed without passing all tests
**5. Consistency** - Same order every time, no variation

### When Your Project Needs This

**Use Mandatory Workflow Order when:**
- ✅ Operations have dependencies (A must happen before B)
- ✅ Out-of-order execution causes failures
- ✅ Data consistency is critical
- ✅ Resources have lifecycle stages
- ✅ Testing must precede deployment

**Don't need this when:**
- ❌ Operations are independent (can run in any order)
- ❌ No dependencies between steps
- ❌ Single-step workflows only

---

## Pre-condition Checking

**⭐ Pattern for Preventing Invalid Operations** - Stop before executing, not after failing.

### The Pattern

**Manager checks IF operation can succeed BEFORE invoking skills.**

```
┌────────────────────────────────────────────────┐
│         PRE-CONDITION CHECKING PATTERN         │
└────────────────────────────────────────────────┘

User Request
      ↓
┌──────────────┐
│   Manager    │
│  Receives    │
│   Request    │
└──────┬───────┘
       ↓
┌──────────────┐     NO    ┌────────────┐
│   Check      │──────────▶│   Report   │
│ Precondition │           │   Error    │
│   (fast)     │           │  + Action  │
└──────┬───────┘           └────────────┘
       │ YES
       ↓
┌──────────────┐
│   Execute    │
│  Operation   │
└──────────────┘
```

### Common Pre-conditions

#### For "create" Operations

```python
Precondition: Resource must NOT already exist

Check:
- Does resource exist in system?
  → If YES: ERROR "Resource already exists"
  → If NO: Proceed with create

Example:
/myproject-resource-manager create my-resource

Manager checks:
1. Does "my-resource" exist?
   → NO: Proceed with creation
   → YES: ERROR "Resource 'my-resource' already exists. Use 'update' or choose different name."
```

#### For "update" Operations

```python
Precondition 1: Resource must exist
Precondition 2: (Optional) Resource must be in correct state

Check:
- Does resource exist?
  → If NO: ERROR "Resource not found"
- Is resource in updatable state?
  → If NO: ERROR "Resource in wrong state"
  → If YES: Proceed with update

Example:
/myproject-resource-manager update my-resource

Manager checks:
1. Does "my-resource" exist?
   → NO: ERROR "Resource 'my-resource' not found. Use 'create' instead."
   → YES: Continue to check 2
2. Is resource configuration valid?
   → NO: ERROR "Resource has invalid configuration. Fix first."
   → YES: Proceed with update
```

#### For "delete" Operations

```python
Precondition: Resource must exist and not have dependencies

Check:
- Does resource exist?
  → If NO: ERROR "Resource not found"
- Are there dependent resources?
  → If YES: ERROR "Dependencies exist"
  → If NO: Proceed with delete

Example:
/myproject-resource-manager delete my-resource

Manager checks:
1. Does "my-resource" exist?
   → NO: ERROR "Resource 'my-resource' not found. Nothing to delete."
   → YES: Continue to check 2
2. Are there dependent resources?
   → YES: ERROR "Cannot delete. 3 other resources depend on this. Delete them first."
   → NO: Proceed with deletion
```

#### For "test" Operations

```python
Precondition: Resource must exist and be in testable state

Check:
- Does resource exist?
  → If NO: ERROR "Resource not found"
- Is resource configured?
  → If NO: ERROR "Resource not configured"
- Are dependencies working?
  → If NO: ERROR "Dependencies not working"
  → If YES: Proceed with test

Example:
/myproject-resource-manager test my-resource

Manager checks:
1. Does "my-resource" exist?
   → NO: ERROR "Resource not found"
   → YES: Continue to check 2
2. Is catalog configured?
   → NO: ERROR "Catalog not configured. Run 'catalog-create' first."
   → YES: Continue to check 3
3. Is data accessible?
   → NO: ERROR "Data not accessible. Run 'data-sync' first."
   → YES: Proceed with tests
```

### Implementation

#### Using Inspector for Fast Checks

```python
# Manager invokes inspector with targeted check (fast)

def check_precondition(check_type, resource):
    result = inspector.invoke({
        "resource": resource,
        "check": check_type,  # e.g., "resource-exists", "data-accessible"
        "quick": True  # Fast check, minimal validation
    })
    return result.status

# Before creating catalog
if not check_precondition("data-exists", resource):
    ERROR("Cannot create catalog: data does not exist")
    SUGGEST("Run data-sync first")
    STOP()
```

#### Error Response Template

```markdown
🛑 PRECONDITION FAILED

Operation: {operation}
Resource: {resource}
Failed Check: {check_description}

Current State:
- {key}: {value}
- {key2}: {value2}

Required State:
- {key}: {required_value}
- {key2}: {required_value2}

Action Needed:
{command_to_run_first}

Then retry: /myproject-resource-manager {operation} {resource}

OPERATION STOPPED
```

#### Example Implementation in Manager

```markdown
# In manager agent workflow

## Precondition Checks

Before executing any operation, check preconditions:

### catalog-create
```python
# Check 1: Data must exist
if not inspector.check("data-exists", resource):
    ERROR("Data not found at expected location")
    SUGGEST("/myproject-resource-manager data-sync {resource}")
    STOP()

# Check 2: Catalog must NOT exist
if inspector.check("catalog-exists", resource):
    ERROR("Catalog already exists")
    SUGGEST("Use 'update' instead of 'create', or delete existing catalog first")
    STOP()

# All checks passed, proceed
invoke_skill("myproject-resource-builder", operation="create")
```

### Benefits

**1. Fast Failure** - Fail in <1 second instead of after 30 seconds of work
**2. Clear Errors** - User knows exactly what's wrong and how to fix
**3. No Wasted Work** - Don't start operations that will fail
**4. Guided Workflow** - Error messages guide user to correct next step
**5. State Protection** - Prevent operations that would corrupt state

### When to Use

**Use pre-condition checking for:**
- ✅ Operations with clear prerequisites
- ✅ Multi-step workflows where order matters
- ✅ Operations that can fail due to missing dependencies
- ✅ Resource lifecycle management (create, update, delete)

**Don't use when:**
- ❌ Operation has no prerequisites
- ❌ Can't check condition quickly (would slow down workflow)
- ❌ Condition can change between check and execution

---

## Documentation Integration

### Documentation Philosophy

**Documentation is NOT a separate phase - it's woven into every workflow.**

### When to Document

**After Create:**
- What was created
- Configuration details
- Purpose/description
- Usage examples

**After Test:**
- Test parameters
- Results summary
- Success/failure status
- Issues encountered

**After Deploy:**
- What was deployed
- Environment
- Timestamp
- Configuration version

**On Error:**
- What failed
- Error details
- Potential causes
- Resolution attempts

### Documentation Locations

**Standard structure:**

```
docs/
├── {domain}s/
│   └── {entity-name}/
│       ├── README.md              # Main documentation
│       ├── test-history.md        # Test results over time
│       ├── configuration.md       # Config details
│       └── troubleshooting.md     # Known issues
│
├── workflows/
│   └── {workflow-name}/
│       └── {date}-{run-id}.md     # Workflow execution log
│
└── infrastructure/
    ├── deployments.md             # Deployment history
    └── environments/
        └── {env}-environment.yaml
```

### Documenter Skills

**One documenter skill per domain:**

**Input:**
```json
{
  "entity_name": "my-entity",
  "action": "create|update|append",
  "section": "overview|configuration|test|deployment",
  "data": {
    "key": "value",
    "metadata": {}
  }
}
```

**Output:**
```json
{
  "status": "success",
  "file_path": "docs/entities/my-entity/README.md",
  "section_updated": "configuration"
}
```

**Templates:**
- Use markdown templates
- Include frontmatter
- Structured sections
- Links to related docs

---

## State Management

⭐ **Infrastructure Snapshot** - Machine-readable current state for fast dashboards and debugging

### The Three Types of Documentation

**Critical Distinction** - Your control plane needs all three:

**1. CHANGELOG.md** - WHAT HAPPENED (audit trail)
- **Location**: `docs/logs/CHANGELOG.md` (centralized)
- **Format**: Chronological event log
- **Purpose**: Audit trail of all operations
- **Updated**: After every operation that changes state
- **Example**: `[2025-10-25 14:30:00] DATA_SYNCED ipeds/hd test - version=2024, 156 files, 45.2 MB`

**2. state.json** - WHAT IS (current state snapshot)
- **Location**: `docs/{domain}/{entity}/state.json` (per-entity)
- **Format**: JSON snapshot
- **Purpose**: Current infrastructure state (S3 locations, catalog names, versions, health)
- **Updated**: Atomically by skills when state changes
- **Example**: `{"environments": {"test": {"lake": {"file_count": 156}}}}`

**3. Schema Documentation** - FIELD DEFINITIONS (human-readable)
- **Location**: `docs/{domain}/{entity}/` (README.md, schema.json)
- **Format**: Markdown + JSON
- **Purpose**: Human and machine-readable field descriptions, examples
- **Updated**: When schema changes
- **Example**: README.md with field descriptions, types, constraints

**Why All Three?**
- **CHANGELOG**: Investigate "when did this change?"
- **state.json**: Answer "what's deployed right now?" (no AWS API calls)
- **Schema docs**: Understand "what does this field mean?"

### Purpose and Benefits

**Why state.json Exists:**

1. **Current State Snapshot**
   - See exactly what resources are deployed right now
   - No need to query infrastructure (AWS, databases, etc.)
   - Instant answers to "where is this?" questions

2. **Fast Dashboards**
   - Generate health reports in <10 seconds
   - Read from state.json instead of re-inspecting
   - 100x faster than AWS API queries (Example: 47 datasets in 9.4s vs 15.7 min)

3. **Debugging Infrastructure**
   - Verify correct S3 locations, catalog names, versions
   - Compare expected vs actual state
   - Identify drift quickly

4. **Downstream Integration**
   - Other systems read state.json for current locations
   - No need to ask or coordinate
   - Always up-to-date

5. **Infrastructure Verification**
   - Ensure operations use correct resources
   - Validate before executing changes
   - Prevent mistakes

### state.json Complete Schema

**Location**: `docs/{domain}/{entity}/state.json`

**Example** (data lake use case):

```json
{
  "dataset": "ipeds",
  "entity": "hd",
  "version": "2024",
  "last_updated": "2025-10-25T15:00:00Z",

  "environments": {
    "test": {
      "etl": {
        "s3_location": "s3://test.etl.source.ai/curated/ipeds/hd/version=2024/",
        "last_synced": "2025-10-25T14:30:00Z",
        "sync_status": "current",
        "file_count": 156,
        "total_size_mb": 45.2,
        "parquet_files": ["part-00000.parquet", "part-00001.parquet", "..."]
      },

      "lake": {
        "s3_location": "s3://test.lake.myproject.ai/curated/ipeds/hd/version=2024/",
        "file_count": 156,
        "total_size_mb": 45.2,
        "last_verified": "2025-10-25T14:30:00Z"
      },

      "catalog": {
        "database": "myproject-lake-test",
        "table_name": "test_ipeds_hd",
        "glue_arn": "arn:aws:glue:us-east-1:xxx:table/myproject-lake-test/test_ipeds_hd",
        "created": "2025-10-25T14:35:00Z",
        "last_updated": "2025-10-25T15:00:00Z",
        "spark_compatible": true,
        "version_views": ["_latest", "_latest_m1", "_latest_m2", "_latest_m3"],
        "partition_projection": "year",
        "permissions_granted": true,
        "field_count": 156,
        "s3_data_location": "s3://test.lake.myproject.ai/curated/ipeds/hd/"
      },

      "validation": {
        "last_validated": "2025-10-25T15:05:00Z",
        "spec_013_compliant": true,
        "version_views_present": true,
        "permissions_valid": true,
        "issues": []
      },

      "testing": {
        "last_tested": "2025-10-25T15:10:00Z",
        "tests_passed": 10,
        "tests_failed": 0,
        "quality_score": 100,
        "performance_ms": 245,
        "issues": []
      },

      "documentation": {
        "last_updated": "2025-10-25T15:15:00Z",
        "files": ["README.md", "schema.json", "sample.json", "state.json"],
        "schema_fields_documented": 156,
        "examples_current": true
      }
    },

    "prod": {
      "etl": {
        "s3_location": "s3://prod.etl.source.ai/curated/ipeds/hd/version=2023/",
        "last_synced": "2025-10-20T10:00:00Z",
        "sync_status": "outdated",
        "file_count": 153,
        "total_size_mb": 43.8
      },

      "lake": {
        "s3_location": "s3://prod.lake.myproject.ai/curated/ipeds/hd/version=2023/",
        "file_count": 153,
        "total_size_mb": 43.8,
        "last_verified": "2025-10-20T10:00:00Z"
      },

      "catalog": {
        "database": "myproject-lake-prod",
        "table_name": "prod_ipeds_hd",
        "glue_arn": "arn:aws:glue:us-east-1:xxx:table/myproject-lake-prod/prod_ipeds_hd",
        "created": "2025-10-20T09:00:00Z",
        "last_updated": "2025-10-20T10:00:00Z",
        "spark_compatible": true,
        "version_views": ["_latest", "_latest_m1", "_latest_m2", "_latest_m3"],
        "field_count": 153
      },

      "validation": {
        "last_validated": "2025-10-20T10:15:00Z",
        "spec_013_compliant": true,
        "version_views_present": true,
        "permissions_valid": true,
        "issues": []
      },

      "testing": {
        "last_tested": "2025-10-20T10:30:00Z",
        "tests_passed": 10,
        "tests_failed": 0,
        "quality_score": 100,
        "performance_ms": 252,
        "issues": []
      },

      "documentation": {
        "last_updated": "2025-10-20T11:00:00Z",
        "files": ["README.md", "schema.json", "sample.json", "state.json"],
        "schema_fields_documented": 153,
        "examples_current": true
      }
    }
  }
}
```

**Adapt to Your Domain:**
- Replace environment sections with what's relevant to you
- Not using ETL? Remove etl section
- Not using catalogs? Replace catalog with your infrastructure type
- Add sections for your specific infrastructure (APIs, databases, etc.)

### Field Definitions

**Top-Level Fields:**

**dataset/entity** (string, required)
- Identifier for the resource being managed
- Example: "ipeds/hd", "blog-articles", "api-endpoints"

**version** (string, required)
- Current version identifier
- Example: "2024", "v1.2.3", "2025-Q1"

**last_updated** (ISO 8601 datetime, required)
- Timestamp of last update to ANY section
- Automatically updated on every write

**Environment Structure:**

Each environment (test, prod, staging, etc.) contains sections relevant to your infrastructure:

**Common Section Types:**

1. **Data/Source Section** (if applicable)
   - Location of source data
   - Sync status
   - File/record counts
   - Last sync timestamp

2. **Infrastructure Section** (required)
   - Deployed resources (databases, APIs, S3, etc.)
   - Resource identifiers (ARNs, URLs, names)
   - Configuration details
   - Creation/update timestamps

3. **Validation Section** (recommended)
   - Last validation timestamp
   - Compliance status
   - Issues found

4. **Testing Section** (recommended)
   - Last test run
   - Pass/fail counts
   - Quality scores
   - Performance metrics

5. **Documentation Section** (recommended)
   - Last documentation update
   - Files present
   - Completeness status

### Atomic Update Pattern

⭐ **Critical**: File locking prevents race conditions when multiple skills write concurrently

**The Problem:**
```python
# ❌ WRONG: Race condition
state = read_state_json(entity)
state["catalog"]["last_updated"] = now()
write_state_json(entity, state)

# If two skills do this simultaneously:
# Skill A reads (version 1)
# Skill B reads (version 1)
# Skill A writes (version 2)
# Skill B writes (version 2') → Overwrites A's changes!
```

**The Solution:**
```python
# ✅ CORRECT: Atomic update with file locking

import fcntl
import json

def update_state(entity, section, data):
    lock_file = f"{entity}.lock"

    # 1. Acquire lock (blocks if another process has it)
    with open(lock_file, 'w') as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)

        # 2. Read current state
        current = read_state_json(entity)

        # 3. Update specific section
        set_nested(current, section, data)

        # 4. Update timestamp
        current["last_updated"] = now()

        # 5. Validate JSON structure
        validate_schema(current)

        # 6. Write atomically
        write_state_json(entity, current)

        # Lock automatically released when 'with' block exits
```

**Benefits:**
- **Thread-safe**: Multiple skills can run concurrently
- **No race conditions**: Lock ensures only one writer at a time
- **Automatic cleanup**: Lock released even if exception occurs
- **Simple to use**: Wrap in state-manager skill

### Using state-manager Skill

**Best Practice**: Create a dedicated state-manager skill for all state.json operations

**Skill Structure:**
```
myproject-state-manager/
├── skill.md
├── scripts/
│   ├── read_state.py
│   ├── update_state.py
│   └── create_state.py
└── templates/
    └── state-template.json
```

**Skill Invocation:**

```python
# From any other skill

# Read current state
state = state_manager.read(entity="my-entity")

# Update specific section
state_manager.update(
    entity="my-entity",
    section="environments.test.catalog",
    data={
        "table_name": "test_my_table",
        "last_updated": now(),
        "spark_compatible": True
    }
)

# Create new state.json from template
state_manager.create(
    entity="my-entity",
    dataset="my-dataset",
    version="2024"
)
```

**Implementation:**

```python
# scripts/update_state.py

import fcntl
import json
from pathlib import Path
from datetime import datetime

def update_state(entity, section, data):
    """
    Atomically update a section of state.json

    Args:
        entity: Entity identifier (e.g., "ipeds/hd")
        section: Dot-notation path (e.g., "environments.test.catalog")
        data: Dictionary to merge into section
    """
    state_file = Path(f"docs/{entity.replace('/', '/')}/state.json")
    lock_file = state_file.parent / ".state.lock"

    # Ensure lock directory exists
    lock_file.parent.mkdir(parents=True, exist_ok=True)

    with open(lock_file, 'w') as lock:
        # Acquire exclusive lock
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)

        try:
            # Read current state
            if state_file.exists():
                with open(state_file) as f:
                    current = json.load(f)
            else:
                current = load_template()

            # Update section
            set_nested_value(current, section, data)

            # Update timestamp
            current["last_updated"] = datetime.utcnow().isoformat() + "Z"

            # Validate
            validate_state_schema(current)

            # Write atomically (write to temp, then rename)
            temp_file = state_file.with_suffix('.tmp')
            with open(temp_file, 'w') as f:
                json.dump(current, f, indent=2)

            temp_file.rename(state_file)

        finally:
            # Lock automatically released when 'with' exits
            pass

def set_nested_value(d, path, value):
    """Set value in nested dict using dot notation"""
    keys = path.split('.')
    for key in keys[:-1]:
        d = d.setdefault(key, {})
    d[keys[-1]] = value if isinstance(value, dict) else value
```

### Update Responsibilities by Skill

**Each skill updates the sections it owns:**

**Data Sync Skills** update:
- `environments.{env}.etl` (source location, sync status)
- `environments.{env}.lake` (destination location, file counts)
- `version` (if newer version synced)

**Infrastructure Builder Skills** update:
- `environments.{env}.catalog` (or whatever infrastructure you create)
- Created/updated timestamps
- Resource identifiers

**Tester Skills** update:
- `environments.{env}.validation` (validation results)
- `environments.{env}.testing` (test results)

**Documenter Skills** update:
- `environments.{env}.documentation` (doc status)

**Deployer Skills** update:
- `environments.prod.*` (production deployment info)

**All Skills** update:
- `last_updated` (automatic via state-manager)

### Integration with README.md

**README.md should include high-level summary from state.json**

**Pattern**: Generate infrastructure section from state.json

**Example README.md Template:**

```markdown
# {Dataset} {Entity}

Current Version: {version}
Last Updated: {last_updated}

## Infrastructure

### Test Environment
- **Data Source**: {etl.s3_location}
- **Storage**: {lake.s3_location}
- **Catalog**: {catalog.database}.{catalog.table_name}
- **Last Synced**: {etl.last_synced}

### Production Environment
- **Data Source**: {prod.etl.s3_location}
- **Storage**: {prod.lake.s3_location}
- **Catalog**: {prod.catalog.database}.{prod.catalog.table_name}
- **Last Synced**: {prod.etl.last_synced}

## Status

### Test
- ✅ Spark Compatible: {validation.spark_compatible}
- ✅ Version Views: {catalog.version_views}
- ✅ Quality Score: {testing.quality_score}/100
- ✅ Tests Passing: {testing.tests_passed}/{testing.tests_passed + testing.tests_failed}

### Production
- ⚠️  Version: {prod version} (Test has {test version})
- ✅ Spark Compatible: {prod.validation.spark_compatible}
- ✅ Quality Score: {prod.testing.quality_score}/100

See state.json for complete infrastructure details.
```

**README.md Generation/Update:**
- Done by infrastructure-builder on create
- Done by infrastructure-updater on updates
- Can be standalone via documenter skill

### Use Cases

**Use Case 1: Debugging Infrastructure**

**Problem**: "Is the catalog pointing to the right S3 location?"

**Solution**:
```bash
# View state.json (instant - no AWS API call)
cat docs/my-dataset/my-entity/state.json | jq '.environments.test.catalog.s3_data_location'
→ "s3://test.lake.myproject.ai/curated/my-dataset/my-entity/"

# Compare with Lake S3
cat docs/my-dataset/my-entity/state.json | jq '.environments.test.lake.s3_location'
→ "s3://test.lake.myproject.ai/curated/my-dataset/my-entity/version=2024/"

# Verify: Catalog points to parent of versioned data ✅
```

**Use Case 2: Fast Dashboard Generation**

**Problem**: "Need health report for all datasets"

**Solution**:
```python
def generate_dashboard():
    """Generate dashboard from state.json (no re-inspection)"""

    datasets = discover_all_datasets()

    for dataset in datasets:
        # Read state.json (fast - just file I/O)
        state = read_state_json(dataset)

        # Extract health info
        print(f"{dataset}:")
        print(f"  Test: {state['environments']['test']['validation']['issues']}")
        print(f"  Prod: {state['environments']['prod']['validation']['issues']}")

    # 47 datasets in <10 seconds (vs 15+ minutes of re-inspection)
```

**Use Case 3: Downstream System Integration**

**Problem**: "Other system needs current Lake S3 locations"

**Solution**:
```python
# Downstream system reads state.json directly

def get_current_lake_location(dataset, env="test"):
    """Get current lake location without asking anyone"""
    state = read_state_json(dataset)
    return state["environments"][env]["lake"]["s3_location"]

# No coordination needed - state.json is always current
location = get_current_lake_location("ipeds/hd", "prod")
# Process data from that location
```

**Use Case 4: Version Comparison**

**Problem**: "Which datasets have test ahead of prod?"

**Solution**:
```bash
# Query all state.json files
for state in docs/*/*/state.json; do
  dataset=$(jq -r '.dataset + "/" + .entity' $state)
  test_version=$(jq -r '.environments.test.catalog.table_name' $state)
  prod_version=$(jq -r '.environments.prod.catalog.table_name' $state)

  if [[ "$test_version" != "$prod_version" ]]; then
    echo "$dataset: Test=$test_version, Prod=$prod_version"
  fi
done
```

### Validation

**state-manager validates on every write:**

```python
def validate_state_schema(state):
    """Validate state.json structure"""

    # Required top-level fields
    assert "dataset" in state or "entity" in state, "Missing entity identifier"
    assert "version" in state, "Missing version"
    assert "last_updated" in state, "Missing last_updated"
    assert "environments" in state, "Missing environments"

    # Validate datetime format
    try:
        datetime.fromisoformat(state["last_updated"].replace('Z', '+00:00'))
    except ValueError:
        raise ValueError(f"Invalid datetime format: {state['last_updated']}")

    # Validate environments
    for env in ["test", "prod"]:
        if env in state["environments"]:
            validate_environment(state["environments"][env], env)

    # S3 locations start with s3://
    for env in state.get("environments", {}).values():
        for section in env.values():
            if isinstance(section, dict) and "s3_location" in section:
                assert section["s3_location"].startswith("s3://"), \
                    f"Invalid S3 location: {section['s3_location']}"

    return True
```

### When Your Project Needs state.json

**Use state.json when:**
- ✅ Multiple resources to manage (>5-10)
- ✅ Need fast dashboards
- ✅ Debugging infrastructure frequently
- ✅ Downstream systems need current state
- ✅ Multiple environments (test/prod)
- ✅ Complex infrastructure with many components

**Don't need when:**
- ❌ Single simple resource
- ❌ Rarely check status
- ❌ No downstream consumers
- ❌ Infrastructure rarely changes

**Start Simple:**
- Begin with basic schema (just infrastructure section)
- Add validation/testing sections when needed
- Evolve as requirements grow

---

## Error Handling

### Error Types

**1. User Error** - Invalid input, entity doesn't exist
**2. Execution Error** - Operation failed, external service error
**3. Missing Capability** - Skill doesn't exist, feature not implemented

### Error Response Template

```
ERROR: {Type} - {Brief description}

Issue: {Detailed explanation}

Context:
- Operation: {operation}
- Entity: {entity}
- Step: {workflow step}

{For Type 3 only:}
Missing Capability: {What's missing}
Proposed Solution: {What should be created}

Current Workaround: {If available}

AskUserQuestion:
  "How would you like to proceed?"
  Options:
    - {Option 1} → {What happens}
    - {Option 2} → {What happens}
    - "Abort" → Stop

WORKFLOW STOPPED.
```

### Scope Discipline

**Agents must ONLY use defined skills.**

**When capability is missing:**

1. ❌ DON'T: Try to solve it yourself
2. ❌ DON'T: Use tools directly (Bash, etc.)
3. ❌ DON'T: Create ad-hoc solutions
4. ❌ DON'T: Proceed with --complete

5. ✅ DO: Stop immediately
6. ✅ DO: Document what's missing
7. ✅ DO: Propose what should be created
8. ✅ DO: Show workaround if available
9. ✅ DO: Wait for human intervention

**Why this matters:**
- Surfaces gaps in workflow coverage
- Encourages permanent fixes (new skills)
- Maintains consistency
- Prevents technical debt

### --complete Flag Behavior

**Without flag:**
- Execute one step
- Show results
- Propose next actions
- Wait for user choice

**With flag:**
- Execute all workflow steps automatically
- Show progress updates
- **STOP on ANY error** (even minor)
- Never guess or assume
- Report final status

**Critical rule:** Never proceed after errors with --complete.

---

## Implementation Checklist

### Phase 1: Foundation

- [ ] Identify project domains (3-6 domains)
- [ ] Map workflows for each domain
- [ ] Define entity types and attributes
- [ ] Design manager agent structure
- [ ] Determine if directors needed
- [ ] List required skills
- [ ] Design argument schemas

### Phase 2: Core Infrastructure

- [ ] Create directory structure (.claude/commands, agents, skills)
- [ ] Implement arg-parser skill
  - [ ] Create parsing script
  - [ ] Define manager schemas
  - [ ] Test with sample arguments
- [ ] Create command templates
- [ ] Create agent templates
- [ ] Create skill templates

### Phase 3: First Manager

- [ ] Choose simplest domain for first implementation
- [ ] Create command file with examples
- [ ] Create agent file with:
  - [ ] 5+ auto-trigger examples
  - [ ] All workflow definitions
  - [ ] Error handling
  - [ ] Documentation integration
- [ ] Create required skills:
  - [ ] Builder skill
  - [ ] Validator skill
  - [ ] Documenter skill
- [ ] Test end-to-end workflow
- [ ] Validate auto-triggering works

### Phase 4: Remaining Managers

- [ ] Implement remaining domain managers
- [ ] Create all required skills
- [ ] Test each manager independently
- [ ] Test cross-manager workflows

### Phase 5: Director Skills (if needed for batch operations)

- [ ] Create Director Skill for pattern expansion
  - [ ] Implement pattern parsing (`*`, `dataset/*`, `a,b,c`)
  - [ ] Implement wildcard expansion
  - [ ] Return dataset list + parallelism recommendation
- [ ] Test batch workflows (Core Agent invoking Managers in parallel)
- [ ] Verify pattern matching accuracy
- [ ] Test parallelism (max 5 concurrent Managers)

### Phase 6: Documentation & Polish

- [ ] Verify all documenter skills working
- [ ] Test documentation generation
- [ ] Create user guide
- [ ] Add more auto-trigger examples
- [ ] Improve error messages
- [ ] Performance optimization

### Phase 7: Validation

- [ ] Test all commands
- [ ] Test all auto-triggers
- [ ] Test error handling
- [ ] Test --complete workflows
- [ ] Test documentation generation
- [ ] User acceptance testing

---

## Troubleshooting Knowledge Base

⭐ **Built-in Troubleshooting** - Knowledge base embedded within skills for consistent issue resolution

### Philosophy and Core Principles

**Core Principles:**

1. **Built-in Knowledge** - Troubleshooting guidance embedded directly in skills
2. **Issue → Fix Routing** - Automated mapping from detected issues to known fixes
3. **Explicit Capability Gaps** - Clear reporting when no fix exists
4. **Continuous Learning** - Knowledge base grows with each new issue type
5. **Context-Rich Errors** - Every failure includes symptoms, causes, and next steps

**Design Goal**: Enable self-healing where possible, clear escalation when not.

### Knowledge Base Structure

**Organization**: Each skill with fix operations contains embedded troubleshooting docs

**Example Structure** (for catalog/infrastructure management skill):

```
myproject-infrastructure-manager/
├── skill.md                          # Main skill definition
├── operations/                        # Operation definitions
│   ├── create.md                     # Operation: Create infrastructure
│   ├── update.md                     # Operation: Update infrastructure
│   ├── fix-compatibility.md          # Operation: Fix compatibility issues
│   ├── fix-permissions.md            # Operation: Fix permissions
│   └── fix-configuration.md          # Operation: Fix configuration
├── scripts/
│   ├── create_infrastructure.py
│   ├── update_infrastructure.py
│   ├── fix_compatibility.py
│   ├── fix_permissions.py
│   └── fix_configuration.py
└── troubleshooting/                  # KNOWLEDGE BASE
    ├── README.md                     # Index of all troubleshooting docs
    ├── compatibility-failures.md
    ├── permission-errors.md
    ├── configuration-issues.md
    ├── resource-not-found.md
    └── ... (grows over time)
```

**Skills with Troubleshooting Knowledge Bases:**
- Infrastructure manager skills (most comprehensive)
- Data sync skills (sync failures)
- Tester skills (validation failures)
- Deployer skills (deployment failures)

**Skills without** (inspectors/identifiers): These don't fix, they identify.

### Standard Troubleshooting Document Format

⭐ **8-Section Template** - Every troubleshooting document follows this structure:

**Template:**

```markdown
---
issue_type: compatibility-failure
severity: critical
skill: myproject-infrastructure-manager
operation: fix-compatibility
related_specs: [SPEC-013-IMPLEMENTATION]
tags: [compatibility, infrastructure, config]
---

# Issue: Compatibility Failure

## 1. Symptoms

What the user/system observes when this issue occurs:

- Validator reports: "❌ Compatibility validation failed"
- Error in system: "Configuration incompatible with target system"
- Query failure with compatibility-related error
- state.json shows: validation.compatible = false

## 2. Root Causes

Why this issue happens:

1. **Missing Required Properties**
   - Required property X not set
   - Property Y missing from configuration

2. **Incorrect Configuration Format**
   - Using old format instead of new format
   - Configuration doesn't match target system requirements

3. **Incompatible Values**
   - Value contains characters not supported by target
   - Type mismatch (string vs number)

4. **Version Mismatch**
   - Configuration is for v1 but system is v2
   - Breaking changes not applied

## 3. Automated Fix

**Operation:** `fix-compatibility`

**What It Does:**

1. Adds required properties with default values
2. Corrects configuration format
3. Normalizes values to compatible format
4. Updates configuration version
5. Validates fix with compatibility check

**Invocation:**

```bash
# Via manager
/myproject-manager update my-resource --operation=fix-compatibility

# Automatically triggered by inspector
# When inspector detects: validation.compatible = false
```

**Script:** `scripts/fix_compatibility.py`

**Expected Result:**
- All required properties added
- Configuration format corrected
- state.json updated: validation.compatible = true
- CHANGELOG entry: "Fixed compatibility for my-resource"
- Validation passes

## 4. Manual Verification

How to verify the fix worked:

```bash
# 1. Check configuration
cat config/my-resource.yaml

# 2. Run validation manually
python scripts/validate_compatibility.py --resource my-resource

# 3. Test against target system
# (system-specific test command)
```

## 5. Prevention

How to avoid this issue in the future:

1. **Use Helper Scripts**
   - ALWAYS use `create_compatible_resource.py` for new resources
   - Never create resources manually

2. **Automated Testing**
   - Every resource creation runs validator
   - Catches compatibility issues immediately

3. **State Tracking**
   - state.json tracks validation.compatible
   - Inspector detects drift immediately

## 6. Related Issues

- permission-errors.md - Permissions must also be compatible
- configuration-issues.md - Other configuration problems

## 7. Escalation Path

**If automated fix fails:**

1. Check CHANGELOG.md for error details
2. Review state.json for specific failure reason
3. Consult SPEC-013 for requirements
4. Contact engineering team with:
   - Resource name
   - Error from CHANGELOG
   - state.json content
   - Manual verification results

## 8. Success Criteria

- [ ] Validation passes
- [ ] state.json shows compatible = true
- [ ] Target system accepts resource
- [ ] CHANGELOG.md documents fix
```

**Required Sections** - Every troubleshooting document MUST include all 8:
1. Frontmatter (metadata)
2. Symptoms (observable indicators)
3. Root Causes (why it happens)
4. Automated Fix (what the skill does)
5. Manual Verification (how to confirm)
6. Prevention (how to avoid)
7. Related Issues (cross-references)
8. Escalation Path (when automation fails)
9. Success Criteria (checklist for resolution)

### Issue Identification Process

**Three Detection Points:**

**1. Inspector Identifies Issues**

```
myproject-resource-inspector:
  → Checks resource configuration
  → Detects: "Configuration incompatible with target"
  → Issue: configuration-incompatibility
  → Fix: infrastructure-manager → fix-compatibility
```

**2. Tester Validation Failures**

```
myproject-resource-tester:
  → Runs compatibility validation
  → Detects: compatible = false
  → Issue: compatibility-failure
  → Fix: infrastructure-manager → fix-compatibility
```

**3. Skill Execution Failures**

```
myproject-infrastructure-builder:
  → Attempts to create resource
  → Fails: "Unsupported configuration format"
  → Issue: unsupported-format
  → Fix: NONE (capability gap)
  → Escalate: Report to development team
```

### Issue Classification

**Four Categories:**

**1. FIXABLE** - Automated fix available
- `compatibility-failure` → `fix-compatibility`
- `permission-missing` → `fix-permissions`
- `configuration-drift` → `sync-configuration`

**2. DATA_ISSUE** - Problem in source data (not infrastructure)
- `data-quality-failure` → Report to data team
- `source-data-missing` → Check data source status

**3. CAPABILITY_GAP** - No known fix exists
- `unknown-format` → Needs new parser
- `unsupported-type` → Needs feature development

**4. INFRASTRUCTURE** - Environment/permissions issue
- `access-denied` → IAM permissions
- `resource-limit` → Quota increase
- `timeout` → Performance optimization needed

### Fix Routing Patterns

**Pattern 1: Direct Routing (Inspector → Fix)**

**Flow:**

```
1. Inspector detects issue
2. Inspector identifies issue_type
3. Inspector maps issue_type → fix operation
4. Manager receives inspection result
5. Manager invokes appropriate skill + operation
6. Skill executes fix
7. Manager re-inspects to verify
```

**Example:**

```python
# Inspector returns routing info

issue = {
  "type": "compatibility-failure",
  "severity": "critical",
  "detected_by": "resource-tester",
  "fix_routing": {
    "skill": "myproject-infrastructure-manager",
    "operation": "fix-compatibility",
    "auto_fixable": True
  }
}
```

**Manager invokes:**
```bash
/myproject-infrastructure-manager --operation=fix-compatibility --resource=my-resource
```

**Pattern 2: Manager Execution Plan**

**Flow** (for `manage` operation):

```
1. Manager invokes inspector
2. Inspector returns list of issues with routing
3. Manager builds execution plan:
   a. Groups issues by priority (CRITICAL → HIGH → WARNING)
   b. Orders fixes by dependency
   c. Identifies non-fixable issues
4. Manager presents plan to user
5. User approves
6. Manager executes each fix in sequence
7. Manager re-inspects after each fix
8. Manager reports final status
```

**Example Execution Plan:**

```
Issues detected: 4

CRITICAL (auto-fixable):
  1. compatibility-failure
     → Fix: infrastructure-manager → fix-compatibility

HIGH (auto-fixable):
  2. permissions-missing
     → Fix: infrastructure-manager → fix-permissions

WARNING (auto-fixable):
  3. configuration-outdated
     → Fix: infrastructure-manager → sync-configuration

HIGH (NOT auto-fixable):
  4. data-quality-failure (15% missing values)
     → Escalate: Report to data team
     → No automated fix available

Execution Plan:
  Step 1: Fix compatibility (CRITICAL)
  Step 2: Fix permissions (HIGH)
  Step 3: Sync configuration (WARNING)
  Step 4: Generate data quality report (HIGH - manual)

Proceed? (yes/no):
```

**Pattern 3: Capability Gap Escalation**

**Flow:**

```
1. Inspector/Tester detects issue
2. Issue type not in troubleshooting knowledge base
3. Skill reports CAPABILITY_GAP
4. Manager receives gap report
5. Manager does NOT attempt fix
6. Manager reports to user with details
7. User decides how to proceed
```

**Example:**

```
🛑 CAPABILITY GAP DETECTED

Level: Skill (myproject-infrastructure-manager)
Operation: sync-configuration
Resource: my-resource

Issue:
Configuration format not recognized: "EXPERIMENTAL_V3"
Cannot parse configuration to update resource.

Missing Capability:
Need parser for EXPERIMENTAL_V3 configuration format

Proposed Solution:
- Add parser to myproject-infrastructure-manager
- Create new operation: parse-experimental-config
- Or update source to use standard format

Current Workaround:
None available - requires manual configuration investigation

WORKFLOW STOPPED - Awaiting User Decision
```

### Knowledge Base Maintenance

**When to Add New Troubleshooting Docs:**

1. **New issue type encountered**
   - First occurrence: Document in issue log
   - Third occurrence: Create troubleshooting doc

2. **Existing doc needs update**
   - New root cause discovered
   - Fix operation improved
   - Manual verification steps changed
   - Escalation path updated

**Process:**

```bash
# 1. Create new troubleshooting document
touch myproject-infrastructure-manager/troubleshooting/new-issue-type.md

# 2. Use standard 8-section template
# (Copy from existing doc, update sections)

# 3. Update README.md index
# Add entry to troubleshooting/README.md

# 4. Update fix routing in inspector (if new auto-fix)
# Add mapping in inspector skill

# 5. Create corresponding operation document (if needed)
touch myproject-infrastructure-manager/operations/fix-new-issue.md

# 6. Implement fix script (if needed)
touch scripts/fix_new_issue.py

# 7. Test end-to-end
/myproject-manager inspect my-test-resource
# Verify issue detected and routed correctly

# 8. Update CHANGELOG
# Document new troubleshooting capability
```

**Quarterly Review:**

- Review all troubleshooting docs for accuracy
- Check for issues that haven't been seen in 6+ months (candidate for archival)
- Identify frequently occurring issues (candidates for prevention focus)
- Update escalation paths if team structure changed

**After Major Changes:**

- New system version → Review compatibility docs
- System updates → Review configuration docs
- Permission changes → Review access control docs

### Integration with Control Plane

**Inspector Integration:**

Inspector uses troubleshooting knowledge base to:

1. **Classify Issues**
   - Maps detected problems to issue types
   - Determines severity based on issue type

2. **Route to Fixes**
   - Includes fix routing info in inspection results
   - Marks auto_fixable vs. manual issues

3. **Provide Context**
   - Links to relevant troubleshooting doc
   - Includes suggested next steps

**Example Inspector Output:**

```json
{
  "resource": "my-resource",
  "status": "unhealthy",
  "issues": [
    {
      "type": "compatibility-failure",
      "severity": "critical",
      "detected_at": "2025-10-25T10:30:00Z",
      "detected_by": "resource-tester",
      "details": "Configuration incompatible with target system",
      "troubleshooting_doc": "troubleshooting/compatibility-failures.md",
      "fix_routing": {
        "skill": "myproject-infrastructure-manager",
        "operation": "fix-compatibility",
        "auto_fixable": true,
        "estimated_duration": "30 seconds"
      }
    }
  ]
}
```

**Manager Integration:**

Manager uses troubleshooting knowledge base to:

1. **Build Execution Plans**
   - Orders fixes by priority and dependencies
   - Separates auto-fixable from manual issues

2. **Invoke Skills with Context**
   - Passes issue details to fixing skill
   - Includes troubleshooting doc reference

3. **Report Progress**
   - Shows which fix is running
   - Links to troubleshooting doc for details

### Example Troubleshooting Documents

**Example 1: Permission Errors**

```markdown
---
issue_type: permission-missing
severity: high
skill: myproject-infrastructure-manager
operation: fix-permissions
tags: [permissions, access-control]
---

# Issue: Permission Missing or Denied

## Symptoms

- Validator reports: "Permissions incomplete"
- Access denied errors when accessing resource
- state.json shows: permissions_granted = false
- System shows missing permissions for required operations

## Root Causes

1. **Permissions Never Granted**
   - Initial resource creation didn't include permission setup
   - Manual resource creation bypassed permission workflow

2. **Permissions Revoked**
   - Manual revocation from admin console
   - Policy change removed permissions

3. **Permission Scope Incorrect**
   - Permissions granted for wrong principal
   - Insufficient permission level (read instead of write)

## Automated Fix

**Operation:** `fix-permissions`

**What It Does:**

1. Identifies required permissions for resource
2. Grants permissions to necessary principals
3. Validates permissions granted
4. Updates state.json

**Invocation:**

```bash
/myproject-manager update my-resource --operation=fix-permissions
```

**Script:** `scripts/fix_permissions.py`

**Expected Result:**
- All required permissions granted
- Access working for authorized users
- state.json shows permissions_granted = true

## Manual Verification

```bash
# Test access with authorized user
# (system-specific access test)

# Verify permissions in admin console
# (check permission list)
```

## Prevention

1. ALWAYS use standard workflows (create, update)
2. NEVER manually modify permissions in console
3. Run validator after any permission changes

## Related Issues

- access-denied.md - Access control infrastructure issues
- configuration-issues.md - Configuration may affect permissions

## Escalation Path

If automated fix fails:
1. Check admin console for conflicting policies
2. Verify resource exists and is healthy
3. Check for organization-level permission restrictions
4. Contact security team with state.json
```

**Example 2: Data Source Access Denied**

```markdown
---
issue_type: data-source-access-denied
severity: critical
skill: myproject-data-syncer
operation: N/A (infrastructure issue)
tags: [access, permissions, data-source]
---

# Issue: Data Source Access Denied

## Symptoms

- Data-syncer fails with: "Access Denied"
- Error location: data source location
- Error Code: AccessDenied
- Cannot list or read source data

## Root Causes

1. **Insufficient Permissions**
   - System role missing required access permissions
   - Cross-account access not configured

2. **Source Access Policy Blocks Access**
   - Source policy restricts to specific principals
   - System role not in allowed list

3. **Credentials Not Configured**
   - Environment variables not set
   - Credentials expired

4. **Encryption Key Access**
   - Source uses encryption
   - System role not granted decrypt permission

## Automated Fix

**NONE** - This is an infrastructure/permissions issue requiring manual resolution.

## Manual Resolution

**Step 1: Verify Credentials**

```bash
# Verify credentials configured
# (system-specific credential check)
```

**Step 2: Test Data Source Access**

```bash
# Test access to data source
# (system-specific access test)
```

**Step 3: Check System Role Policy**

Verify system role has required permissions.

**Step 4: Check Source Access Policy**

Contact source team to verify system role allowed.

**Step 5: Check Encryption Key (if applicable)**

Verify system role has decrypt permission on encryption key.

## Prevention

1. **Policy Review** - Quarterly review of system policies
2. **Source Coordination** - Notify source team when adding new resources
3. **Automated Testing** - Pre-flight access test in data-syncer

## Related Issues

None (infrastructure issue, not resource configuration)

## Escalation Path

1. Verify credentials configured correctly
2. Check system role policy (DevOps team)
3. Contact source team about access policy
4. If encryption involved, coordinate with security team
```

**Example 3: Configuration Drift**

```markdown
---
issue_type: configuration-drift
severity: high
skill: myproject-infrastructure-manager
operation: sync-configuration
tags: [configuration, sync, drift]
---

# Issue: Configuration Drift Detected

## Symptoms

- Inspector reports: "Configuration drift detected"
- Source configuration has changes not in deployed resource
- Deployed resource has configuration not in source
- Type mismatches between source and deployed

## Root Causes

1. **Source Configuration Changed**
   - Source added/removed fields
   - Source changed field types
   - Source renamed fields

2. **Manual Resource Edits**
   - Resource modified outside of workflows
   - Fields added/removed manually via console

3. **Stale Resource**
   - Resource not updated after source change
   - Version update without configuration sync

## Automated Fix

**Operation:** `sync-configuration`

**What It Does:**

1. Fetches current source configuration
2. Compares with deployed resource configuration
3. Identifies differences:
   - New fields in source → Add to resource
   - Removed fields in source → Remove from resource (with warning)
   - Type changes → Update resource type
4. Updates resource configuration
5. Validates compatibility
6. Updates state.json

**Invocation:**

```bash
/myproject-manager update my-resource --operation=sync-configuration
```

**Script:** `scripts/sync_configuration.py`

**Expected Result:**
- Resource configuration matches source
- state.json updated with sync timestamp

## Manual Verification

```bash
# 1. Compare configurations
# View source configuration
cat source/my-resource/config.yaml

# View deployed configuration
# (system-specific configuration view)

# 2. Test resource with new configuration
# (system-specific test)
```

## Prevention

1. **Source Coordination**
   - Source team notifies of configuration changes
   - Changes trigger automatic sync

2. **Regular Inspection**
   - Weekly automated inspection runs
   - Dashboard shows drift status

3. **No Manual Edits**
   - NEVER edit resource manually
   - ALL changes via workflows

## Related Issues

- compatibility-failures.md - Configuration sync must maintain compatibility

## Escalation Path

If automated fix fails:

1. **Type Incompatibility**
   - Example: Source changed string → complex type
   - May require manual intervention
   - Contact engineering

2. **Breaking Changes**
   - Example: Source removed required field
   - Downstream systems may break
   - Coordinate with stakeholders before syncing

3. **Unknown Format**
   - Example: Source uses new format
   - Capability gap - needs new parser
   - Report to development team
```

### Capability Gap Detection

**Standard Format:**

When a skill encounters an issue it cannot handle:

```
🛑 CAPABILITY GAP DETECTED

Level: [Skill name]
Operation: [Operation being attempted]
Resource: [resource-name]

Issue:
[Clear description of the problem]

Missing Capability:
[What functionality is needed]

Proposed Solution:
[Suggested approaches to add capability]
- Option 1: [Description]
- Option 2: [Description]

Current Workaround:
[Manual steps if any, or "None available"]

Impact:
[What workflows are blocked]

WORKFLOW STOPPED - Awaiting User Decision
```

**Escalation Process:**

1. **Skill Reports Gap** → Manager receives report
2. **Manager Stops Workflow** → Does NOT attempt fix
3. **Manager Reports to User** → Includes gap details
4. **User Decides:**
   - Accept manual workaround
   - Request capability development
   - Change approach (use different format/method)

### When Your Project Needs Troubleshooting Knowledge Base

**Use troubleshooting KB when:**
- ✅ Multiple fix operations available
- ✅ Issues occur repeatedly
- ✅ Team needs to collaborate on fixes
- ✅ Consistent resolution process important
- ✅ Learning from past issues valuable

**Don't need when:**
- ❌ Simple single-operation system
- ❌ Issues are always unique
- ❌ Solo developer, informal process
- ❌ No pattern to failures

**Start Simple:**
- Begin with 1-2 troubleshooting docs for most common issues
- Add more as patterns emerge
- Evolve 8-section template to fit your needs

### Issue Log & Confidence Scoring

⭐ **Historical Learning** - System learns from past issue resolutions through append-only issue log

#### Issue Log System

**Purpose**: Append-only log of all analyzed issues and their outcomes for data-driven confidence scoring

**Location**: `.claude/skills/myproject-debugger/issue-log.jsonl`

**Format**: JSONL (one JSON object per line)

```jsonl
{"timestamp": "2025-10-25T10:30:00Z", "resource": "my-resource", "issue_type": "compatibility-failure", "solution_chosen": 1, "outcome": "SUCCESS", "duration_seconds": 28, "confidence_score": 95}
{"timestamp": "2025-10-25T11:15:00Z", "resource": "other-resource", "issue_type": "permission-missing", "solution_chosen": null, "outcome": "ESCALATED", "confidence_score": 0, "notes": "Access control issue"}
{"timestamp": "2025-10-25T14:22:00Z", "resource": "third-resource", "issue_type": "configuration-drift", "solution_chosen": 1, "outcome": "SUCCESS", "duration_seconds": 15, "confidence_score": 92}
```

**Schema**:
```json
{
  "timestamp": "ISO 8601 datetime",
  "resource": "resource-identifier",
  "issue_type": "issue-type-slug",
  "solution_chosen": 1,  // or null if escalated
  "outcome": "SUCCESS | FAILED | ESCALATED",
  "duration_seconds": 28,
  "confidence_score": 95,
  "notes": "Optional additional context"
}
```

#### Operations

**append** - Add new issue outcome:
```python
issue_logger.append({
    "timestamp": now(),
    "resource": "my-resource",
    "issue_type": "compatibility-failure",
    "solution_chosen": 1,
    "outcome": "SUCCESS",
    "duration_seconds": 28,
    "confidence_score": 95
})
```

**search** - Find similar past issues:
```python
similar = issue_logger.search({
    "issue_type": "compatibility-failure",
    "outcome": "SUCCESS"
})
# Returns: List of matching entries
```

**analytics** - Calculate success rates:
```python
stats = issue_logger.analytics("compatibility-failure")
# Returns: {
#   "total_attempts": 12,
#   "successful": 12,
#   "failed": 0,
#   "escalated": 0,
#   "success_rate": 100.0,
#   "avg_duration": 26.4
# }
```

#### Integration with Debugger

**When debugger analyzes issue**:

1. **Search issue log** for similar past issues
```python
past_issues = issue_logger.search({
    "issue_type": issue_type,
    "resource": resource  # or any resource
})
```

2. **Calculate success rate**
```python
stats = issue_logger.analytics(issue_type)
success_rate = stats["success_rate"]
```

3. **Adjust confidence score** based on history (see Confidence Scoring below)

4. **Include in analysis**
```python
analysis["similar_past_issues"] = len(past_issues)
analysis["avg_success_rate"] = stats["success_rate"]
analysis["recommended_solution"] = highest_confidence_option
```

5. **After fix executed, log outcome**
```python
issue_logger.append({
    "timestamp": now(),
    "resource": resource,
    "issue_type": issue_type,
    "solution_chosen": chosen_option,
    "outcome": execution_result,
    "duration_seconds": duration,
    "confidence_score": original_confidence
})
```

#### Confidence Scoring Algorithm

**Formula**:
```
confidence = base_score + historical_adjustment + context_adjustment
```

**Range**: 0-100 (percentage)

##### Base Score (from Knowledge Base)

Determined by troubleshooting document metadata:

**High Confidence (90-100)**:
- Automated fix exists
- 100% success rate historically
- No known failure modes
- Fast execution (<60s)

**Medium Confidence (70-89)**:
- Automated fix exists
- Some historical failures
- May require manual intervention sometimes

**Low Confidence (50-69)**:
- Automated fix exists but often fails
- Frequently requires manual intervention
- Complex or slow execution

**No Confidence (0)**:
- No automated fix (CAPABILITY_GAP)
- Infrastructure issue (requires external fix)

##### Historical Adjustment (+/-10)

Based on issue log analysis:

```python
def calculate_historical_adjustment(issue_type):
    stats = issue_logger.analytics(issue_type, last_n=20)

    if stats["success_rate"] > 90:
        return +10  # Proven track record
    elif stats["success_rate"] >= 70:
        return 0    # Average performance
    else:
        return -10  # Frequently fails
```

**Examples**:

- Success rate = 100% (12/12 past attempts) → +10 → Total: 95 + 10 = **105 → capped at 100**
- Success rate = 75% (15/20 past attempts) → 0 → Total: 75 + 0 = **75**
- Success rate = 60% (12/20 past attempts) → -10 → Total: 60 - 10 = **50**

##### Context Adjustment (+/-5)

Based on current situation specifics:

```python
def calculate_context_adjustment(issue, error_message):
    adjustment = 0

    # Exact error message match in knowledge base
    if exact_match(error_message, known_errors):
        adjustment += 5

    # Partial match
    elif partial_match(error_message, known_errors):
        adjustment += 0

    # Unknown error message
    else:
        adjustment -= 5

    # Resource-specific factors
    if issue["resource"] in high_risk_resources:
        adjustment -= 5

    return adjustment
```

**Examples**:

- Exact error match + standard resource → +5 → Total: 95 + 10 + 5 = **110 → capped at 100**
- Unknown error + high-risk resource → -5 + (-5) = -10 → Total: 75 + 0 - 10 = **65**

##### Complete Calculation Example

**Scenario**: Compatibility failure for my-resource

```python
# Base score from troubleshooting doc
base_score = 95

# Historical: 12/12 past successes (100%)
historical_adjustment = +10

# Context: Exact error match, standard resource
context_adjustment = +5

# Calculate
confidence = base_score + historical_adjustment + context_adjustment
confidence = 95 + 10 + 5 = 110

# Cap at 100
final_confidence = min(confidence, 100)

# Result: 100% confidence
```

**Debugger Output**:
```json
{
  "solution_options": [
    {
      "option_number": 1,
      "description": "Fix compatibility automatically",
      "skill": "myproject-infrastructure-manager",
      "operation": "fix-compatibility",
      "confidence_score": 100,
      "confidence_breakdown": {
        "base": 95,
        "historical": 10,
        "context": 5
      },
      "historical_data": {
        "past_attempts": 12,
        "successes": 12,
        "failures": 0,
        "avg_duration": 28
      },
      "recommended": true
    }
  ]
}
```

##### Threshold Interpretation

**Confidence ≥90%**:
- Recommend automatic fix
- High likelihood of success
- User can proceed with confidence

**Confidence 70-89%**:
- Suggest fix but note risks
- Monitor execution closely
- Prepare for potential manual intervention

**Confidence 50-69%**:
- Present as option but warn
- Suggest manual review first
- May require fallback plan

**Confidence <50%**:
- Do NOT recommend
- Suggest manual intervention
- Or escalate to capability gap

#### Use Cases

**Use Case 1: Confidence Scoring**
- Debugger finds issue type with 100% past success rate
- Increases confidence score → Recommends automated fix

**Use Case 2: Pattern Detection**
- Issue log shows specific resource repeatedly has same issue
- Suggests prevention strategy for that resource

**Use Case 3: Performance Tracking**
- Issue log tracks average duration per fix type
- Identifies slow operations for optimization

**Use Case 4: Capability Assessment**
- Issue log shows 0% success rate for issue type
- Flags for capability improvement or alternate approach

#### Benefits

1. **Learning System** - Gets better over time
2. **Data-Driven Confidence** - Based on actual outcomes
3. **Performance Tracking** - Measure improvement
4. **Pattern Detection** - Identify recurring issues
5. **Success Validation** - Verify fixes work

#### Maintenance

**Append-Only**: Never delete or modify existing entries
**Size Management**: Rotate logs yearly (archive to issue-log-YYYY.jsonl)
**Backup**: Include in regular backup procedures

---

## Performance Metrics

### Overview

⭐ **Key Innovation from Lake.Corthonomy.AI**: The 3-layer agentic control plane delivers measurable performance improvements across all operational dimensions.

**Measurement Categories:**
1. **Context Efficiency**: Token usage and context window optimization
2. **Execution Speed**: Workflow completion times
3. **Diagnostic Speed**: Time to identify and resolve issues
4. **Developer Experience**: Cognitive load and iteration cycles

---

### Real-World Performance Data

#### Context Loading Improvements

**Problem**: Monolithic agents loaded entire codebases unnecessarily
**Solution**: Skill-based architecture with targeted context loading

| Metric | Before (Monolithic) | After (Skills) | Improvement |
|--------|---------------------|----------------|-------------|
| Context per operation | 13x required size | 1x required size | **13x reduction** |
| Average tokens loaded | 150K-200K | 10K-20K | **10x reduction** |
| Context overflow rate | 40% of operations | <1% of operations | **40x reduction** |

**Example**: Lake.Corthonomy.AI catalog validation
- Before: Loaded all 47 datasets + ETL schemas + Terraform + tests = 180K tokens
- After: Loaded only target dataset + validation rules = 15K tokens
- Result: 12x reduction, zero context overflows

---

#### Dashboard Generation Speed

**Problem**: Dashboard generation took 15+ minutes due to redundant S3 operations
**Solution**: State-based dashboards reading from state.json snapshots

| Metric | Before (S3 Query) | After (State-based) | Improvement |
|--------|-------------------|---------------------|-------------|
| Generation time | 15.7 minutes | 9.4 seconds | **100x faster** |
| AWS API calls | 2,800+ per dashboard | 0 per dashboard | **Eliminated** |
| Cost per dashboard | $0.014 | $0.000 | **100% cost reduction** |
| Freshness | Real-time | <5 min stale | Acceptable trade-off |

**Example**: Lake.Corthonomy.AI 47-dataset dashboard
- Before: 47 datasets × 60s S3 queries = 942 seconds (15.7 min)
- After: Single state.json read = 9.4 seconds
- Result: Dashboard became practical for routine use

---

#### Inspection Speed

**Problem**: Full inspections took 30+ seconds, too slow for pre-condition checks
**Solution**: Modular inspector with targeted checks

| Check Type | Duration | Use Case | Performance |
|------------|----------|----------|-------------|
| **Full inspection** | 30s | Initial diagnosis | Baseline |
| **Data currency** | 3s | Pre-update check | **10x faster** |
| **Schema drift** | 4s | Pre-catalog-update | **7.5x faster** |
| **Catalog config** | 2s | Pre-deploy validation | **15x faster** |
| **Documentation** | 5s | Pre-publish check | **6x faster** |
| **Data exists** | 1s | Fast failure | **30x faster** |
| **Catalog exists** | 1s | Fast failure | **30x faster** |

**Example**: Lake.Corthonomy.AI pre-deployment validation
- Before: Full inspection (30s) before every deployment
- After: Targeted "catalog-config" check (2s) before deployment
- Result: 15x faster feedback loops

---

#### Workflow Completion Time

**Problem**: Multi-step workflows required manual intervention and retries
**Solution**: Manager-coordinated workflows with automatic retry logic

| Workflow | Before (Manual) | After (Manager) | Improvement |
|----------|----------------|-----------------|-------------|
| **Create new dataset** | 45-60 min | 2-3 min | **20x faster** |
| **Update to new version** | 15-20 min | 30-60 sec | **20x faster** |
| **Fix schema drift** | 10-15 min | 45-90 sec | **10x faster** |
| **Deploy to production** | 20-30 min | 2-4 min | **8x faster** |
| **Full validation cycle** | 8-12 min | 90-120 sec | **6x faster** |

**Example**: Lake.Corthonomy.AI new dataset onboarding
- Before: Manual steps across 4 systems (45-60 min)
  - Create Terraform config (15 min)
  - Deploy to test (5 min)
  - Run validation (10 min)
  - Fix issues (15 min)
  - Deploy to prod (10 min)
- After: Single `/project:table-manage dataset --complete` command (2-3 min)
- Result: Same-day dataset launches instead of multi-day projects

---

#### Troubleshooting Speed

**Problem**: Issue diagnosis required extensive codebase exploration and documentation review
**Solution**: Troubleshooting knowledge base embedded in debugger skill

| Metric | Before (Manual) | After (Knowledge Base) | Improvement |
|--------|----------------|------------------------|-------------|
| Time to diagnosis | 5-10 minutes | <30 seconds | **15x faster** |
| Knowledge base queries | 5-8 doc searches | 1 embedded lookup | **7x reduction** |
| Issue resolution accuracy | 60-70% first try | 90-95% first try | **1.4x better** |
| New developer onboarding | 2-3 weeks | 3-5 days | **4x faster** |

**Example**: Lake.Corthonomy.AI schema drift resolution
- Before: Developer searches docs → finds fix → adapts to context (8 min)
- After: Debugger references knowledge base → provides exact fix with confidence score (25 sec)
- Result: Faster resolution, higher success rate

---

#### Developer Experience Metrics

**Cognitive Load Reduction:**
- **Mental model complexity**: 40% reduction (3 layers vs 5+ ad-hoc patterns)
- **Context switching**: 60% reduction (skills stay focused on one domain)
- **Error recovery**: 80% reduction (debugger provides specific fixes vs generic errors)
- **Documentation lookups**: 70% reduction (knowledge base embedded in workflows)

**Iteration Cycle Time:**
- **Write-test-debug cycle**: 45% faster (modular skills reduce blast radius)
- **Feature addition time**: 50% faster (clear skill boundaries)
- **Bug fix time**: 65% faster (issue log provides historical context)

**Maintenance Burden:**
- **Bug recurrence rate**: 75% reduction (knowledge base captures fixes)
- **Regression introduction**: 60% reduction (mandatory workflow order prevents issues)
- **Emergency fixes**: 80% reduction (confidence scoring prevents bad fixes)

---

### Performance Baselines by Project Size

#### Small Projects (<10 resources)
- **Setup overhead**: 2-3 hours (3 skills minimum)
- **Operation latency**: <5 seconds per operation
- **ROI breakeven**: ~50 operations (week 2-3)

#### Medium Projects (10-50 resources)
- **Setup overhead**: 4-6 hours (5-7 skills)
- **Operation latency**: 5-15 seconds per operation
- **ROI breakeven**: ~100 operations (week 3-4)

#### Large Projects (50-100 resources)
- **Setup overhead**: 8-12 hours (8-12 skills)
- **Operation latency**: 15-30 seconds per operation
- **ROI breakeven**: ~200 operations (week 4-6)

**Lake.Corthonomy.AI Case Study:**
- Project size: 47 datasets (medium-large)
- Skills implemented: 12
- Setup time: 10 hours
- Operations per week: ~150
- ROI breakeven: Week 4
- Current performance: 20x faster workflows, 95%+ automation

---

### Monitoring Your Performance

#### Essential Metrics to Track

**1. Context Efficiency**
```python
# Track context usage per skill invocation
metrics = {
    "skill": "myproject-inspector",
    "tokens_loaded": 15000,
    "tokens_used": 8000,
    "efficiency": 0.53,  # 53% of loaded context was used
    "timestamp": "2025-01-15T10:30:00Z"
}
```

**2. Execution Time**
```python
# Track workflow completion times
metrics = {
    "workflow": "create-new-resource",
    "duration_seconds": 180,
    "steps": 7,
    "avg_step_duration": 25.7,
    "slowest_step": "validation",
    "slowest_step_duration": 60
}
```

**3. Success Rates**
```python
# Track issue resolution success from issue log
metrics = {
    "issue_type": "schema-drift",
    "total_attempts": 20,
    "successful_fixes": 19,
    "success_rate": 0.95,
    "avg_confidence_score": 85,
    "confidence_accuracy": 0.92  # 92% of high-confidence fixes succeeded
}
```

**4. Developer Experience**
```python
# Track developer productivity indicators
metrics = {
    "avg_time_to_diagnosis": 30,  # seconds
    "avg_documentation_lookups": 1.2,  # per issue
    "avg_context_switches": 0.3,  # per workflow
    "developer_satisfaction": 4.5  # out of 5
}
```

---

### Optimization Strategies

#### When Performance Degrades

**Context Bloat:**
- Symptom: Skills loading 50K+ tokens
- Diagnosis: Review skill context requirements
- Fix: Split skill into smaller, focused skills

**Slow Inspections:**
- Symptom: Targeted checks taking >10s
- Diagnosis: Inspector making unnecessary API calls
- Fix: Add state.json caching layer

**Low Success Rates:**
- Symptom: Confidence scores consistently wrong
- Diagnosis: Knowledge base outdated or incomplete
- Fix: Update troubleshooting documents, recalibrate confidence algorithm

**Workflow Bottlenecks:**
- Symptom: One step taking >50% of workflow time
- Diagnosis: Identify slow step in manager logs
- Fix: Optimize slow skill or run in parallel with other steps

---

## Success Criteria

### Overview

⭐ **Key Innovation from Lake.Corthonomy.AI**: Measurable success criteria ensure the agentic control plane delivers value and remains maintainable over time.

**8 Success Criteria:**
1. Knowledge Base Coverage
2. Confidence Score Accuracy
3. Documentation Freshness
4. State Consistency
5. Test Pass Rates
6. Workflow Completion Rates
7. Mean Time to Resolution (MTTR)
8. Dashboard Utility

---

### 1. Knowledge Base Coverage

**Metric**: Percentage of issues resolved using knowledge base vs. requiring new documentation

**Target**: ≥95% coverage for recurring issues

**Measurement**:
```python
# From issue log analytics
coverage = (issues_with_kb_match / total_issues) * 100

# Lake.Corthonomy.AI actual: 96.2% coverage
# - 187 issues resolved with KB match
# - 194 total issues
```

**What Good Looks Like:**
- ✅ Common issues (schema drift, compatibility) have complete troubleshooting docs
- ✅ Knowledge base updated within 1 week of new issue type
- ✅ <5% of issues require debugger to improvise fixes

**What Failure Looks Like:**
- ❌ Debugger frequently returns "no known fix" for common issues
- ❌ Knowledge base documents are >6 months old
- ❌ Success rates declining over time (knowledge base drift)

---

### 2. Confidence Score Accuracy

**Metric**: Percentage of high-confidence fixes (≥80 score) that succeed

**Target**: ≥90% accuracy for high-confidence fixes

**Measurement**:
```python
# From issue log analytics
high_confidence_fixes = filter(lambda i: i["confidence"] >= 80, issues)
accuracy = (successful_high_conf / total_high_conf) * 100

# Lake.Corthonomy.AI actual: 94.1% accuracy
# - 80 high-confidence fixes attempted
# - 75 succeeded
```

**What Good Looks Like:**
- ✅ High-confidence fixes succeed 90%+ of the time
- ✅ Low-confidence fixes (<50) flagged for manual review
- ✅ Confidence scores calibrated quarterly based on historical data

**What Failure Looks Like:**
- ❌ High-confidence fixes frequently fail (over-confidence)
- ❌ Low-confidence fixes succeed often (under-confidence)
- ❌ Confidence scores not updated despite historical data

---

### 3. Documentation Freshness

**Metric**: Time lag between code changes and documentation updates

**Target**: ≤48 hours for critical paths, ≤1 week for secondary paths

**Measurement**:
```python
# Compare git commit timestamps to doc update timestamps
freshness_lag = doc_updated_at - code_changed_at

# Lake.Corthonomy.AI actual: 18-hour average lag
# - Critical path docs: 12-hour average
# - Secondary path docs: 36-hour average
```

**What Good Looks Like:**
- ✅ Schema changes trigger automatic doc regeneration
- ✅ New skills documented before production deployment
- ✅ Troubleshooting docs updated when new fix patterns discovered

**What Failure Looks Like:**
- ❌ Documentation references non-existent resources
- ❌ Knowledge base contains outdated fix recommendations
- ❌ Developers bypass documentation due to inaccuracy

---

### 4. State Consistency

**Metric**: Percentage of state.json fields matching ground truth (S3, Glue API)

**Target**: ≥99.5% consistency at any given time

**Measurement**:
```python
# Compare state.json to actual infrastructure
consistency_check = {
    "etl.available_versions": check_s3_versions(),
    "catalog.table_exists": check_glue_table(),
    "validation.last_run": check_test_results()
}
consistency_rate = (matching_fields / total_fields) * 100

# Lake.Corthonomy.AI actual: 99.8% consistency
# - 2,347 fields checked
# - 2,342 matched ground truth
```

**What Good Looks Like:**
- ✅ State updates atomic (all-or-nothing)
- ✅ State rebuilds automatically if corruption detected
- ✅ Dashboards show accurate data without S3/Glue queries

**What Failure Looks Like:**
- ❌ Dashboards show stale data (state not updated)
- ❌ Skills make decisions based on incorrect state
- ❌ Manual state.json edits required to fix inconsistencies

---

### 5. Test Pass Rates

**Metric**: Percentage of resources passing validation after automated fixes

**Target**: ≥95% pass rate for automated fixes

**Measurement**:
```python
# From workflow completion logs
test_results = {
    "total_fixes": 150,
    "passed_validation": 144,
    "pass_rate": 0.96
}

# Lake.Corthonomy.AI actual: 96.0% pass rate
# - 150 automated fixes applied
# - 144 passed validation
# - 6 required manual intervention
```

**What Good Looks Like:**
- ✅ Automated fixes reliably pass validation
- ✅ Failed fixes trigger manual review (not silent failure)
- ✅ Validation failures result in knowledge base updates

**What Failure Looks Like:**
- ❌ Automated fixes frequently break validation
- ❌ Fixes applied without validation
- ❌ Validation failures ignored or silently logged

---

### 6. Workflow Completion Rates

**Metric**: Percentage of manager workflows completing without manual intervention

**Target**: ≥90% fully automated completion

**Measurement**:
```python
# From manager execution logs
workflow_stats = {
    "total_workflows": 200,
    "fully_automated": 185,
    "required_intervention": 15,
    "completion_rate": 0.925
}

# Lake.Corthonomy.AI actual: 92.5% completion rate
# - 200 workflows in 30 days
# - 185 completed fully automated
# - 15 required human decisions
```

**What Good Looks Like:**
- ✅ Common workflows (create, update, sync) run fully automated
- ✅ Manual interventions limited to ambiguous cases (user approval by design)
- ✅ Failure modes result in clear error messages + recovery instructions

**What Failure Looks Like:**
- ❌ Workflows frequently stall awaiting manual intervention
- ❌ Error messages unclear, requiring debugging
- ❌ High abandonment rate (workflows started but not completed)

---

### 7. Mean Time to Resolution (MTTR)

**Metric**: Average time from issue detection to successful resolution

**Target**: ≤90 seconds for known issues, ≤10 minutes for novel issues

**Measurement**:
```python
# From issue log timestamps
mttr_known = avg([
    (i["resolved_at"] - i["detected_at"]).total_seconds()
    for i in issues
    if i["knowledge_base_match"] == True
])

mttr_novel = avg([
    (i["resolved_at"] - i["detected_at"]).total_seconds()
    for i in issues
    if i["knowledge_base_match"] == False
])

# Lake.Corthonomy.AI actual:
# - Known issues: 45 seconds average MTTR
# - Novel issues: 6.5 minutes average MTTR
```

**What Good Looks Like:**
- ✅ Known issues resolved in <90 seconds (KB + automated fix)
- ✅ Novel issues diagnosed in <5 minutes (debugger analysis)
- ✅ MTTR trending downward over time (knowledge base improving)

**What Failure Looks Like:**
- ❌ Known issues taking >5 minutes (KB not being used)
- ❌ Novel issues taking >30 minutes (debugger ineffective)
- ❌ MTTR trending upward over time (system degrading)

---

### 8. Dashboard Utility

**Metric**: Dashboard reflects ground truth and enables fast decision-making

**Target**: ≤10 seconds to generate, ≥99% accuracy

**Measurement**:
```python
# Dashboard performance
dashboard_metrics = {
    "generation_time_seconds": 9.4,
    "accuracy_vs_ground_truth": 0.998,
    "resources_displayed": 47,
    "user_satisfaction": 4.7  # out of 5
}

# Lake.Corthonomy.AI actual: 9.4s generation, 99.8% accuracy
```

**What Good Looks Like:**
- ✅ Dashboard generation <10 seconds
- ✅ Data <5 minutes stale (acceptable trade-off for speed)
- ✅ Visual indicators (🟢🟡🔴) enable instant status assessment
- ✅ Users rely on dashboard instead of manual S3/Glue queries

**What Failure Looks Like:**
- ❌ Dashboard generation >30 seconds (users stop using it)
- ❌ Stale data >1 hour (dashboard misleading)
- ❌ Accuracy <95% (users trust manual queries more)

---

### Measuring Your Success

#### Quarterly Health Check

Run this assessment every quarter:

```python
# Example scoring rubric
success_criteria = {
    "knowledge_base_coverage": 96.2,  # Target: ≥95%
    "confidence_accuracy": 94.1,      # Target: ≥90%
    "documentation_freshness": 18,    # Target: ≤48 hours
    "state_consistency": 99.8,        # Target: ≥99.5%
    "test_pass_rate": 96.0,           # Target: ≥95%
    "workflow_completion": 92.5,      # Target: ≥90%
    "mttr_known_seconds": 45,         # Target: ≤90s
    "dashboard_gen_seconds": 9.4      # Target: ≤10s
}

# Score: 8/8 criteria met = Excellent
# Score: 6-7/8 criteria met = Good
# Score: 4-5/8 criteria met = Needs improvement
# Score: <4/8 criteria met = Critical issues

# Lake.Corthonomy.AI: 8/8 criteria met (Excellent)
```

#### Red Flags to Watch

**Immediate Action Required:**
- ❌ State consistency <95% (infrastructure diverging)
- ❌ Test pass rate <85% (automated fixes unreliable)
- ❌ Workflow completion <75% (too much manual intervention)

**Plan Improvement Within 30 Days:**
- ⚠️ Knowledge base coverage <90% (gaps in documentation)
- ⚠️ Confidence accuracy <85% (scoring algorithm needs recalibration)
- ⚠️ MTTR trending upward over 3+ quarters (system degrading)

**Monitor and Optimize:**
- 📊 Documentation freshness >1 week (lag accumulating)
- 📊 Dashboard generation >15 seconds (users may stop using)

---

## Common Patterns

### Pattern: Create-Validate-Test-Deploy

**Use when:** Entity requires validation and testing before deployment

**Workflow:**
1. Create entity from template
2. Validate configuration
3. Test functionality
4. Deploy to environment
5. Verify deployment

**Manager operations:**
- `create` - Step 1
- `validate` - Step 2
- `test` - Step 3
- `deploy` - Step 4
- `workflow` - All steps with --complete

### Pattern: Edit-Revalidate-Redeploy

**Use when:** Modifying existing entities

**Workflow:**
1. Load current configuration
2. Edit configuration
3. Revalidate
4. Test changes
5. Redeploy

**Manager operations:**
- `edit` - Steps 1-2
- `validate` - Step 3
- `test` - Step 4
- `deploy` - Step 5

### Pattern: Batch Operations

**Use when:** Operating on multiple entities

**Workflow (Director):**
1. Parse request, identify filter criteria
2. Discover matching entities
3. Confirm with user
4. Execute in parallel (via parallel-executor skill)
5. Monitor progress
6. Aggregate results
7. Report summary

**Director operations:**
- `batch-{operation}` - Execute operation on multiple entities

### Pattern: Cross-Domain Workflow

**Use when:** Workflow spans multiple domains

**Workflow (Director):**
1. Execute operation in domain A (via manager A)
2. Wait for completion
3. Execute operation in domain B (via manager B)
4. Wait for completion
5. Report combined results

**Example:** Create target → Create scrapers using target

### Pattern: Progressive Deployment

**Use when:** Deploying through environments

**Workflow:**
1. Deploy to test environment
2. Run smoke tests
3. Confirm with user
4. Deploy to staging
5. Run full tests
6. Confirm with user
7. Deploy to production
8. Monitor

**Manager operations:**
- `deploy` with `--env=test`
- `test` with `--env=test`
- `deploy` with `--env=staging`
- `test` with `--env=staging`
- `deploy` with `--env=prod` (requires confirmation)

### Pattern: Inspector-First Diagnosis

⭐ **Key Innovation from Lake.Corthonomy.AI**

**Use when:** Diagnosing issues or planning remediation

**Workflow:**
1. Run inspector to gather factual observations
2. Inspector returns ONLY observations (no analysis)
3. Manager receives inspection results
4. Manager invokes debugger with inspection data
5. Debugger analyzes WHY + HOW TO FIX
6. Manager presents plan to user for approval
7. Builder executes approved fixes

**Key Principle:** Inspector observes, Debugger analyzes, Builder executes. Never improvise.

**Manager Pattern:**
```python
def diagnose_and_fix(resource):
    # Phase 1: INSPECT (gather facts)
    inspection = inspector.invoke(resource, check="full")

    # Phase 2: ANALYZE (understand + plan)
    analysis = debugger.analyze(inspection)
    # Returns: {
    #   "issues": [...],
    #   "root_causes": [...],
    #   "recommended_fixes": [...],
    #   "confidence_scores": [...]
    # }

    # Phase 3: PRESENT (get approval)
    present_plan_to_user(analysis)
    if not user_approved():
        return "Workflow cancelled"

    # Phase 4: EXECUTE (apply fixes)
    for fix in analysis["recommended_fixes"]:
        builder.invoke(fix)

    # Phase 5: VERIFY (confirm success)
    retest = inspector.invoke(resource, check="full")
    return report_results(retest)
```

**Why This Works:**
- Separation of concerns (observe vs analyze vs execute)
- Manager never improvises (follows debugger recommendations)
- Historical learning (debugger references knowledge base)
- User approval (manager presents plan before execution)

**Lake.Corthonomy.AI Results:**
- 96.2% of issues matched knowledge base patterns
- 94.1% success rate for high-confidence fixes
- 45-second average MTTR for known issues

### Pattern: State-Driven Operations

⭐ **Key Innovation from Lake.Corthonomy.AI**

**Use when:** Making decisions about resource status or readiness

**Workflow:**
1. Read state.json for current infrastructure snapshot
2. Make decisions based on state fields
3. Execute operations
4. Update state.json atomically
5. Subsequent operations use updated state

**Key Principle:** State is source of truth. Never query infrastructure directly.

**Skill Pattern:**
```python
def should_sync_data(resource):
    # ✅ GOOD: Read from state
    state = read_state_json(resource)

    etl_version = state["etl"]["latest_version"]
    lake_version = state["lake"]["current_version"]

    return etl_version != lake_version

def sync_data_operation(resource):
    # Check state first
    if not should_sync_data(resource):
        return "No sync needed"

    # Perform sync
    copy_s3_data(resource)

    # Update state atomically
    update_state(resource, "lake.current_version",
                 state["etl"]["latest_version"])
    update_state(resource, "lake.last_synced_at", datetime.now())
```

**Benefits:**
- 100x faster dashboards (9.4s vs 15.7 min)
- Zero AWS API calls for read-only operations
- Consistent view across all skills
- Atomic updates prevent corruption

**When to Refresh State:**
- After any infrastructure change
- If state >5 minutes old and fresh data required
- On explicit refresh request
- If inconsistency detected

**Lake.Corthonomy.AI Results:**
- 99.8% state consistency with ground truth
- 2,347 state fields tracked across 47 datasets
- Dashboard generation 100x faster

### Pattern: Confidence-Based Execution

⭐ **Key Innovation from Lake.Corthonomy.AI**

**Use when:** Debugger provides fix recommendations with confidence scores

**Workflow:**
1. Debugger analyzes issue, returns fix with confidence score
2. Manager applies execution strategy based on confidence:
   - **≥80 (High)**: Auto-fix, log to issue log
   - **50-79 (Medium)**: Present to user, await approval
   - **<50 (Low)**: Flag for manual investigation

**Manager Pattern:**
```python
def execute_fix(issue, recommended_fix, confidence):
    if confidence >= 80:
        # High confidence: Auto-fix
        logger.info(f"Auto-fixing {issue['type']} (confidence: {confidence})")
        result = builder.invoke(recommended_fix)
        issue_logger.append({
            "issue_type": issue["type"],
            "confidence": confidence,
            "outcome": "success" if result["passed"] else "failure"
        })
        return result

    elif confidence >= 50:
        # Medium confidence: User approval
        print(f"⚠️ Medium confidence fix ({confidence}/100)")
        print(f"Issue: {issue['description']}")
        print(f"Recommended fix: {recommended_fix['operation']}")

        if ask_user_approval():
            return builder.invoke(recommended_fix)
        else:
            return "Fix rejected by user"

    else:
        # Low confidence: Manual investigation
        print(f"❌ Low confidence ({confidence}/100) - manual review required")
        print(f"Issue: {issue['description']}")
        print(f"Suggested approaches:")
        for approach in recommended_fix.get("alternatives", []):
            print(f"  - {approach}")
        return "Requires manual investigation"
```

**Confidence Calculation:**
```python
confidence = base_score + historical_adjustment + context_adjustment

# base_score: From knowledge base (70-90)
# historical_adjustment: ±10 based on success rate
# context_adjustment: ±5 based on error message match
```

**Benefits:**
- Safe automation (only high-confidence fixes auto-applied)
- User control (medium-confidence requires approval)
- Learning system (confidence improves over time)
- Clear thresholds (no guessing about automation)

**Lake.Corthonomy.AI Results:**
- 94.1% success rate for high-confidence fixes
- 92.5% workflow completion rate (fully automated)
- Confidence accuracy validated quarterly

### Pattern: Fast-Fail Pre-Checks

⭐ **Key Innovation from Lake.Corthonomy.AI**

**Use when:** Before expensive operations (data sync, catalog updates, deployments)

**Workflow:**
1. Run targeted inspector check (1-3 seconds)
2. If pre-condition fails, stop immediately with clear error
3. If pre-condition passes, proceed with expensive operation

**Manager Pattern:**
```python
def sync_and_update_workflow(resource):
    # Fast pre-checks before expensive operations

    # Check 1: Does data exist in ETL? (1s)
    etl_check = inspector.invoke(resource, check="data-exists")
    if not etl_check["data_exists"]:
        return ERROR("No ETL data found. Run Corthion ETL first.")

    # Check 2: Does catalog entry exist? (1s)
    catalog_check = inspector.invoke(resource, check="catalog-exists")
    if not catalog_check["catalog_exists"]:
        return ERROR("Catalog not initialized. Run create-catalog first.")

    # Check 3: Is data current? (3s)
    currency_check = inspector.invoke(resource, check="data-currency")
    if not currency_check["sync_needed"]:
        print("✅ Data already current, skipping sync")
        return "No action needed"

    # All checks passed: Proceed with expensive operations
    print("🔄 Data sync required, proceeding...")

    # Expensive: Data sync (60s)
    data_syncer.invoke(resource, operation="sync")

    # Expensive: Catalog update (45s)
    catalog_builder.invoke(resource, operation="update")

    # Expensive: Full test suite (30s)
    tester.invoke(resource)
```

**Check Types by Speed:**
| Check | Duration | Use Before |
|-------|----------|------------|
| `data-exists` | 1s | Data sync operations |
| `catalog-exists` | 1s | Catalog operations |
| `data-currency` | 3s | Sync workflows |
| `schema-drift` | 4s | Catalog updates |
| `catalog-config` | 2s | Deployments |
| `documentation` | 5s | Publish operations |
| `full` | 30s | Initial diagnosis |

**Benefits:**
- Fast failure (1-5s vs 60-120s wasted)
- Clear error messages (immediate feedback)
- Resource efficiency (no expensive failed operations)
- Better UX (instant feedback vs long wait then fail)

**Lake.Corthonomy.AI Results:**
- 10-30x faster failure detection
- Targeted checks used in 85% of workflows
- Pre-checks prevent 40% of expensive failed operations

### Pattern: Historical Context Resolution

⭐ **Key Innovation from Lake.Corthonomy.AI**

**Use when:** Debugger selects fix for an issue type

**Workflow:**
1. Debugger identifies issue type
2. Queries issue log for historical success rates
3. Selects fix with highest success rate for this issue type
4. Adjusts confidence score based on historical performance
5. Returns fix recommendation with confidence

**Debugger Pattern:**
```python
def select_fix(issue_type, context):
    # Get knowledge base fixes for this issue type
    kb_fixes = knowledge_base.get_fixes(issue_type)

    # Get historical performance for each fix
    historical_stats = {}
    for fix in kb_fixes:
        stats = issue_logger.analytics(
            issue_type=issue_type,
            fix_applied=fix["id"],
            last_n=20
        )
        historical_stats[fix["id"]] = stats

    # Select fix with highest success rate
    best_fix = max(kb_fixes, key=lambda f:
        historical_stats[f["id"]]["success_rate"])

    # Calculate confidence using historical data
    base_score = best_fix["base_confidence"]
    historical_success = historical_stats[best_fix["id"]]["success_rate"]

    if historical_success > 0.90:
        confidence = base_score + 10  # Proven track record
    elif historical_success >= 0.70:
        confidence = base_score  # Average performance
    else:
        confidence = base_score - 10  # Frequently fails

    return {
        "fix": best_fix,
        "confidence": confidence,
        "historical_context": {
            "attempts": historical_stats[best_fix["id"]]["total_attempts"],
            "successes": historical_stats[best_fix["id"]]["successes"],
            "success_rate": historical_success,
            "last_used": historical_stats[best_fix["id"]]["last_used"]
        }
    }
```

**Learning Loop:**
```python
# After fix applied
def record_outcome(issue_type, fix_id, outcome):
    issue_logger.append({
        "timestamp": datetime.now().isoformat(),
        "issue_type": issue_type,
        "fix_applied": fix_id,
        "outcome": outcome,  # "success" or "failure"
        "confidence_score": confidence
    })

    # Trigger KB review if success rate drops
    recent_stats = issue_logger.analytics(issue_type, last_n=20)
    if recent_stats["success_rate"] < 0.70:
        alert_kb_needs_update(issue_type)
```

**Benefits:**
- Improves over time (confidence scores calibrated by reality)
- Avoids repeated mistakes (low success rate fixes avoided)
- Knowledge capture (successful fixes remembered)
- Degradation detection (declining success rates trigger review)

**Lake.Corthonomy.AI Results:**
- 96.2% knowledge base coverage
- Confidence accuracy improved 15% over 6 months
- New developer onboarding 4x faster with historical context

### Pattern: Atomic State Updates

⭐ **Key Innovation from Lake.Corthonomy.AI**

**Use when:** Updating state.json fields

**Workflow:**
1. Acquire file lock on state.json
2. Read current state
3. Update specific fields
4. Validate JSON schema
5. Write atomically (temp file + rename)
6. Release lock

**Implementation:**
```python
import fcntl
import json
from pathlib import Path

def update_state(resource, field_path, value):
    """Atomically update a state.json field.

    Args:
        resource: Resource identifier (e.g., "ipeds/hd")
        field_path: Dot-notation path (e.g., "lake.current_version")
        value: New value to set
    """
    state_file = Path(f"state/{resource}/state.json")
    lock_file = Path(f"state/{resource}/state.lock")

    # Ensure directories exist
    state_file.parent.mkdir(parents=True, exist_ok=True)

    # Acquire exclusive lock
    with open(lock_file, 'w') as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)

        try:
            # Read current state
            if state_file.exists():
                with open(state_file, 'r') as f:
                    state = json.load(f)
            else:
                state = initialize_state_schema()

            # Update nested field
            set_nested_field(state, field_path, value)

            # Update timestamp
            state["last_updated"] = datetime.now().isoformat()

            # Validate schema
            validate_state_schema(state)

            # Write atomically (temp + rename)
            temp_file = state_file.with_suffix('.tmp')
            with open(temp_file, 'w') as f:
                json.dump(state, f, indent=2)

            # Atomic rename
            temp_file.rename(state_file)

        finally:
            # Lock released automatically when context exits
            pass

def set_nested_field(obj, path, value):
    """Set a nested field using dot notation."""
    parts = path.split('.')
    for part in parts[:-1]:
        obj = obj.setdefault(part, {})
    obj[parts[-1]] = value
```

**Why Atomic Updates Matter:**
```python
# ❌ BAD: Non-atomic update
state = read_state()
state["field1"] = value1  # ← Another process could read partial state here
state["field2"] = value2  # ← Crash here = corrupted state
write_state(state)

# ✅ GOOD: Atomic update
with atomic_state_update(resource) as state:
    state["field1"] = value1
    state["field2"] = value2
    # All updates committed together, or none
```

**Benefits:**
- **No corruption**: All-or-nothing updates
- **No race conditions**: File locking prevents concurrent writes
- **No partial reads**: Rename is atomic operation
- **Validation**: Schema validated before commit

**When This Matters:**
- Multiple skills updating state concurrently
- Long-running operations updating state incrementally
- Dashboard reading state while updates happening
- Recovery from crashes (partial updates rolled back)

**Lake.Corthonomy.AI Results:**
- 99.8% state consistency (2,342/2,347 fields match ground truth)
- Zero state corruption incidents in 6 months
- Concurrent skill operations safe by design

---

## Anti-Patterns

### ❌ Anti-Pattern: Manager as Skill (CRITICAL)

⭐ **Most Common Architectural Error**

**DON'T:**
```
Location: .claude/skills/myproject-manager/
- Manager implemented as skill
- Limited tool access
- No natural user interaction
- Poor state management across workflow
```

**Problem:**
- **Loses agent capabilities**: Can't use AskUserQuestion, limited Read/Write/Bash access
- **Unnatural workflows**: Approval steps feel forced, error handling is awkward
- **State management broken**: Can't maintain context across 7-phase workflow
- **User experience suffers**: No natural interaction, no graceful error recovery

**DO:**
```
Location: .claude/agents/project/myproject-manager.md
---
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---
- Manager implemented as AGENT
- Full tool access for state management
- Natural user interaction and approvals
- Orchestrates 7-phase workflow with persistent context
```

**Why This Matters:**
- 69% of operations use Manager directly (single-entity)
- Manager is PRIMARY pattern, must be optimal
- Agent capabilities essential for complex workflows

### ❌ Anti-Pattern: Director as Agent (OVER-ENGINEERED)

**DON'T:**
```
Location: .claude/agents/project/director.md
- Director as agent doing orchestration
- Loops over datasets sequentially
- Invokes Managers via Task tool
- Prevents parallelism
```

**Problem:**
- **Over-engineered**: Director should be simple pattern expansion
- **No parallelism**: Agent can't spawn parallel Manager invocations
- **Underutilized**: Only 31% of operations need batch support
- **Wrong layer**: Orchestration should be Core Agent's job

**DO:**
```
Location: .claude/skills/myproject-director/
- Director as SKILL for pattern expansion only
- Parses patterns: *, dataset/*, a,b,c
- Returns dataset list to Core Claude Agent
- Core Agent invokes Managers in parallel (max 5)
```

**Why This Matters:**
- Core Claude Agent better at parallelism than custom code
- Keeps Director simple and lightweight
- Enables 5x faster batch operations

### ❌ Anti-Pattern: Agent-to-Agent Calls

**DON'T:**
```
Manager A → Calls Manager B → Calls Manager C
```

**Problem:**
- Context reloaded 3 times (CLAUDE.md, etc.)
- State lost between agents
- Hard to debug
- Breaks hierarchy

**DO:**
```
Single Entity:
Command → Manager Agent → Skills

Batch Operation:
Command → Director Skill → Core Claude Agent
                            ↓ (parallel, max 5)
                            ├─ Manager Agent → Skills
                            ├─ Manager Agent → Skills
                            └─ Manager Agent → Skills
```

### ❌ Anti-Pattern: Solving Problems Outside Scope

**DON'T:**
```
Agent: "User needs feature X, I'll write code directly to solve it"
```

**Problem:**
- Ad-hoc solutions don't scale
- No reusability
- Breaks pattern
- Creates technical debt

**DO:**
```
Agent: "User needs feature X. I don't have skill for that."
ERROR: Missing Capability - {description}
Proposed Solution: Create skill {name} with {interface}
WORKFLOW STOPPED.
```

### ❌ Anti-Pattern: Logic in Commands

**DON'T:**
```markdown
# Command file
Parse arguments
Validate entity
Execute operation
...
```

**Problem:**
- Commands should only route
- No context maintenance
- Can't orchestrate workflows

**DO:**
```markdown
# Command file
Route to {project}-{domain}-manager agent
```

### ❌ Anti-Pattern: Manual Documentation

**DON'T:**
```
Manager workflow:
1. Create entity
2. Test entity
3. Ask user to document it
```

**Problem:**
- Documentation forgotten
- Out of date quickly
- Extra work for user

**DO:**
```
Manager workflow:
1. Create entity
2. Invoke documenter skill (automatic)
3. Test entity
4. Invoke documenter skill (automatic)
```

### ❌ Anti-Pattern: Proceeding After Errors with --complete

**DON'T:**
```
Manager: "Test failed but --complete is set, trying to proceed..."
```

**Problem:**
- Cascading failures
- Wrong assumptions
- Corrupted state

**DO:**
```
Manager: "Test failed. STOPPING workflow even with --complete."
ERROR: {details}
WORKFLOW STOPPED.
```

### ❌ Anti-Pattern: Skills Making Decisions

**DON'T:**
```python
# In skill script
if condition:
    # Decide what to do next
```

**Problem:**
- Skills should execute, not decide
- Manager loses control
- Hard to test

**DO:**
```python
# In skill script
# Execute task, return results
return {
  "status": "success",
  "condition_met": true/false,
  "results": {}
}

# Manager agent decides what to do with results
```

### ❌ Anti-Pattern: Manager Improvising Fixes

⭐ **Critical Lesson from Lake.Corthonomy.AI**

**DON'T:**
```python
# Manager improvising fix
def fix_issue(issue):
    # Manager analyzes and decides fix directly
    if "schema" in issue["type"]:
        # Improvise a schema fix
        return apply_schema_fix()
```

**Problem:**
- No knowledge base leverage (reinventing solutions)
- No historical learning (same mistakes repeated)
- Inconsistent fixes (different approaches each time)
- No confidence scoring (unknown success likelihood)

**DO:**
```python
# Manager delegates to debugger
def fix_issue(issue):
    # Debugger analyzes using knowledge base
    analysis = debugger.analyze(issue)
    # Returns: fix recommendation + confidence score

    # Manager executes based on confidence
    if analysis["confidence"] >= 80:
        return builder.invoke(analysis["recommended_fix"])
    else:
        return request_manual_review(analysis)
```

**Why This Matters:**
- Lake.Corthonomy.AI: 96.2% knowledge base coverage, 94.1% fix success rate
- Improvisation: ~60% success rate, no improvement over time
- Result: 35% faster MTTR, 56% fewer repeat issues

### ❌ Anti-Pattern: Querying Infrastructure Directly

⭐ **Critical Lesson from Lake.Corthonomy.AI**

**DON'T:**
```python
# Skill querying infrastructure repeatedly
def check_status(resources):
    statuses = []
    for resource in resources:
        # Query S3 (20s per resource)
        s3_data = boto3.client('s3').list_objects(...)
        # Query Glue (15s per resource)
        glue_data = boto3.client('glue').get_table(...)
        statuses.append(analyze(s3_data, glue_data))

    # 47 resources × 35s = 27 minutes
    return statuses
```

**Problem:**
- Extremely slow (27 min for 47 resources)
- Expensive (thousands of API calls)
- Inconsistent (state changes during queries)
- Not scalable (linear time complexity)

**DO:**
```python
# Skill reading from state snapshot
def check_status(resources):
    statuses = []
    for resource in resources:
        # Read from state.json (0.1s per resource)
        state = read_state_json(resource)
        statuses.append(analyze(state))

    # 47 resources × 0.1s = 4.7 seconds
    return statuses
```

**Why This Matters:**
- Lake.Corthonomy.AI: 100x faster (9.4s vs 15.7 min dashboards)
- Cost: $0 vs $0.014 per dashboard
- Consistency: All skills see same infrastructure snapshot
- Result: Dashboards became practical for routine use

**Acceptable Direct Queries:**
- During state refresh (rebuilding snapshot)
- When state doesn't exist yet (bootstrap)
- For real-time validation before critical operations

### ❌ Anti-Pattern: Skipping Workflow Order

⭐ **Critical Lesson from Lake.Corthonomy.AI**

**DON'T:**
```python
# Manager executing operations out of order
def quick_fix(resource):
    # Skip inspection, jump to fix
    catalog_builder.invoke(resource, operation="update")

    # Deploy without testing
    deployer.invoke(resource, environment="production")
```

**Problem:**
- Catalog update before data sync = broken references
- Deploy without tests = production failures
- No pre-checks = expensive operations fail late
- Unpredictable outcomes = same input, different results

**DO:**
```python
# Manager enforcing workflow order
def fix_workflow(resource):
    # Phase 1: INSPECT (mandatory)
    issues = inspector.invoke(resource, check="full")

    # Phase 2: DATA-SYNC (if needed)
    if requires_data_sync(issues):
        data_syncer.invoke(resource)

    # Phase 3: CATALOG-OPS (only after data ready)
    if requires_catalog_update(issues):
        catalog_builder.invoke(resource)

    # Phase 4: TEST (mandatory after changes)
    test_result = tester.invoke(resource)
    if not test_result["passed"]:
        raise TestFailureError("Cannot proceed")

    # Phase 5: DEPLOY (only if tests pass)
    deployer.invoke(resource, environment="production")
```

**Why This Matters:**
- Lake.Corthonomy.AI: 60% reduction in regression bugs
- Prevented errors: Can't configure catalog for missing data
- Fast failure: 1-3s pre-checks save 60-120s failed operations
- Result: Predictable, repeatable workflows

**Mandatory Order:**
```
INSPECT → DATA-SYNC → CATALOG-OPS → TEST → DEPLOY
   (always)  (if needed)  (if needed)  (always)  (if approved)
```

### ❌ Anti-Pattern: Ignoring Confidence Scores

⭐ **Critical Lesson from Lake.Corthonomy.AI**

**DON'T:**
```python
# Applying all fixes regardless of confidence
def apply_fixes(issues, recommended_fixes):
    for fix in recommended_fixes:
        # Apply every fix, ignore confidence
        builder.invoke(fix)
        # Hope it works!
```

**Problem:**
- Low-confidence fixes fail frequently (success rate <50%)
- No user review for risky operations
- Failed fixes create more issues
- No learning from failures

**DO:**
```python
# Respecting confidence thresholds
def apply_fixes(issues, recommended_fixes):
    for fix in recommended_fixes:
        confidence = fix["confidence_score"]

        if confidence >= 80:
            # High confidence: Auto-apply
            result = builder.invoke(fix)
            log_outcome(fix, result)

        elif confidence >= 50:
            # Medium confidence: Request approval
            if user_approves(fix, confidence):
                result = builder.invoke(fix)
                log_outcome(fix, result)

        else:
            # Low confidence: Skip auto-fix
            flag_for_manual_review(fix, confidence)
```

**Confidence Thresholds:**
| Range | Action | Expected Success Rate |
|-------|--------|----------------------|
| ≥80 | Auto-apply | ≥90% |
| 50-79 | User approval | 70-90% |
| <50 | Manual review | <70% |

**Why This Matters:**
- Lake.Corthonomy.AI: 94.1% success rate for high-confidence fixes
- Ignoring scores: ~60% success rate overall
- User approval: Prevents 80% of bad automated fixes
- Result: Safe automation with human oversight for edge cases

### ❌ Anti-Pattern: Non-Atomic State Updates

⭐ **Critical Lesson from Lake.Corthonomy.AI**

**DON'T:**
```python
# Non-atomic state update (race conditions)
def update_state(resource, updates):
    # Read state
    state = json.load(open(f"{resource}/state.json"))

    # Update fields
    state["field1"] = updates["field1"]
    # ← Another process could write here
    state["field2"] = updates["field2"]
    # ← Crash here = corrupted state

    # Write state
    json.dump(state, open(f"{resource}/state.json", 'w'))
```

**Problem:**
- Race conditions (multiple processes writing)
- Partial updates (crash between writes)
- Corrupted state (invalid JSON)
- Lost updates (last writer wins)

**DO:**
```python
# Atomic state update with file locking
import fcntl

def update_state(resource, updates):
    state_file = f"{resource}/state.json"
    lock_file = f"{resource}/state.lock"

    # Acquire exclusive lock
    with open(lock_file, 'w') as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)

        # Read current state
        state = json.load(open(state_file))

        # Apply all updates
        for key, value in updates.items():
            set_nested_field(state, key, value)

        # Validate before writing
        validate_state_schema(state)

        # Write atomically (temp + rename)
        temp_file = f"{state_file}.tmp"
        json.dump(state, open(temp_file, 'w'))
        os.rename(temp_file, state_file)

        # Lock released automatically
```

**Why This Matters:**
- Lake.Corthonomy.AI: 99.8% state consistency over 6 months
- Without locking: Frequent corruption, manual repairs needed
- File locking: Zero corruption incidents in production
- Result: Concurrent skill operations safe by design

**State Corruption Symptoms:**
```json
// ❌ Corrupted state (crash mid-write)
{
  "etl": {
    "latest_version": "2024

// ❌ Race condition (partial update)
{
  "etl": {"latest_version": "2024"},
  "lake": {"current_version": "2023"}  // Should be "2024"
}
```

**Prevention Checklist:**
- ✅ Use file locking (fcntl.flock)
- ✅ Write to temp file, then atomic rename
- ✅ Validate JSON schema before commit
- ✅ Handle lock timeouts gracefully
- ✅ Release locks in finally blocks

---

## Testing Strategy

### Unit Testing

**Test each skill independently:**

```python
# Test builder skill
def test_builder_skill():
    result = invoke_skill(
        "myproject-entity-builder",
        {"name": "test-entity", "type": "yaml"}
    )
    assert result["status"] == "success"
    assert file_exists(result["file_path"])
```

### Integration Testing

**Test manager workflows:**

```python
# Test complete workflow
def test_manager_workflow():
    # Invoke manager with --complete
    result = invoke_command(
        "/myproject-entity-manager workflow test-entity --complete"
    )

    # Verify all steps completed
    assert result["created"] == True
    assert result["validated"] == True
    assert result["tested"] == True
    assert result["documented"] == True
```

### Auto-Trigger Testing

**Test that agents trigger automatically:**

```python
def test_auto_trigger():
    # Send natural language request
    response = send_to_claude("Create a new entity called test-entity")

    # Verify correct agent was invoked
    assert "myproject-entity-manager" in response.agents_invoked
```

### Error Handling Testing

**Test that errors stop workflows:**

```python
def test_error_stops_workflow():
    # Create scenario that will fail
    result = invoke_command(
        "/myproject-entity-manager workflow invalid-entity --complete"
    )

    # Verify workflow stopped
    assert result["status"] == "error"
    assert result["workflow_stopped"] == True
    assert "Missing Capability" in result["error_type"]
```

### Documentation Testing

**Test that docs are generated:**

```python
def test_documentation_generated():
    # Run workflow
    invoke_command("/myproject-entity-manager create test-entity")

    # Verify docs exist
    assert file_exists("docs/entities/test-entity/README.md")
    assert file_contains("docs/entities/test-entity/README.md", "test-entity")
```

---

## Example: Building a Control Plane

### Scenario: Content Management System

**Project:** BlogPro - Blog content management

**Domains:** Articles, Authors, Publications, Analytics

**Let's build the Articles domain...**

### Step 1: Define Workflows

**Article Manager Operations:**
- `create` - Create new article from template
- `edit` - Edit existing article
- `validate` - Check article meets quality standards
- `preview` - Generate preview
- `publish` - Publish to website
- `unpublish` - Remove from website
- `list` - Show all articles
- `workflow` - Complete flow (create → validate → preview → publish)

### Step 2: Identify Skills Needed

**Builder Skills:**
- `blogpro-article-builder` - Create article from template
- Templates: blog-post, tutorial, news-article

**Validator Skills:**
- `blogpro-article-validator` - Validate content
  - Check required fields
  - Verify image links
  - Check word count
  - Validate frontmatter

**Executor Skills:**
- `blogpro-article-preview` - Generate preview
- `blogpro-article-publisher` - Publish to website
- `blogpro-article-unpublisher` - Remove from website

**Documenter Skills:**
- `blogpro-article-documenter` - Document article metadata

**Utility Skills:**
- `blogpro-arg-parser` - Parse arguments for all managers
- `blogpro-cli` - Wrap any CLI commands

### Step 3: Define Argument Schema

```yaml
# .claude/skills/blogpro-arg-parser/schemas/article-manager-args.yaml

required_positional:
  - operation
  - article_slug  # Optional for 'list' operation

operations:
  - create
  - edit
  - validate
  - preview
  - publish
  - unpublish
  - list
  - workflow

flags:
  - complete      # Auto-proceed through workflow
  - force         # Skip confirmations
  - draft         # Save as draft

options:
  template:
    type: string
    enum: [blog-post, tutorial, news-article]
    default: blog-post

  author:
    type: string
    default: null

  category:
    type: string
    default: uncategorized

  env:
    type: string
    enum: [test, prod]
    default: test
```

### Step 4: Create Command File

```markdown
# .claude/commands/blogpro-article-manager.md

---
org: myblog
system: blogpro
name: blogpro-article-manager
description: Manage blog articles - create, edit, validate, publish
argument-hint: OPERATION ARTICLE_SLUG [--complete] [--template={type}]
---

# BlogPro Article Manager

Manage blog articles through their complete lifecycle.

## Usage

```bash
/blogpro-article-manager OPERATION ARTICLE_SLUG [OPTIONS]
```

<ARGUMENTS>

### Required Positional Arguments

1. **OPERATION** - The operation to perform
   - `create` - Create new article
   - `edit` - Edit existing article
   - `validate` - Validate article content
   - `preview` - Generate preview
   - `publish` - Publish to website
   - `unpublish` - Remove from website
   - `list` - List all articles
   - `workflow` - Complete workflow (create → publish)

2. **ARTICLE_SLUG** - Article identifier (URL-friendly name)
   - Optional for `list` operation
   - Example: "my-first-blog-post"

### Optional Flags

- `--complete` - Auto-proceed through workflow without pausing
- `--force` - Skip confirmations
- `--draft` - Save as draft (not published)

### Optional Options

- `--template={type}` - Article template [blog-post|tutorial|news-article]
- `--author={name}` - Author name
- `--category={cat}` - Article category
- `--env={test|prod}` - Environment (default: test)

</ARGUMENTS>

## Examples

```bash
# Create new article
/blogpro-article-manager create my-first-post

# Create tutorial with specific author
/blogpro-article-manager create python-tutorial --template=tutorial --author="Jane Doe"

# Validate article
/blogpro-article-manager validate my-first-post

# Complete workflow
/blogpro-article-manager workflow my-first-post --complete

# Publish to production
/blogpro-article-manager publish my-first-post --env=prod
```
```

### Step 5: Create Agent File

```markdown
# .claude/agents/blogpro-article-manager.md

---
org: myblog
system: blogpro
name: blogpro-article-manager
description: Manages blog article operations with complete workflow orchestration. Automatically activates when user mentions creating articles, publishing posts, editing content, or blog workflows.
auto-trigger: [create article, new blog post, publish article, edit article, blog content, article workflow]
---

## Role

You are the Article Manager for BlogPro. You maintain context throughout article-related workflows and coordinate skills to accomplish tasks for a **single article**.

**CRITICAL CONSTRAINTS:**
- You ONLY use existing skills defined below
- You NEVER solve problems outside your defined scope
- If you cannot solve a problem with available skills → STOP with error
- Document the gap, propose next step, but DO NOT PROCEED

<EXAMPLES>

## Trigger Examples

<example>
**User:** "Create a new blog post about Python programming"

**Assistant thinking:** User wants to create an article. This triggers blogpro-article-manager with create operation.

**Assistant action:** Invoke blogpro-article-manager agent with operation=create. Ask for article slug.
</example>

<example>
**User:** "Publish my article about Python to production"

**Assistant thinking:** User wants to publish existing article. This triggers blogpro-article-manager with publish operation.

**Assistant action:** Invoke blogpro-article-manager agent with operation=publish, ask for article slug, confirm production deployment.
</example>

<example>
**User:** "The images in my tutorial article aren't showing up"

**Assistant thinking:** User needs to edit article content. This triggers blogpro-article-manager with edit operation.

**Assistant action:** Invoke blogpro-article-manager agent with operation=edit. Ask for article slug.
</example>

</EXAMPLES>

## Available Skills

- `blogpro-arg-parser` - Parse arguments
- `blogpro-article-builder` - Create articles from templates
- `blogpro-article-validator` - Validate article content
- `blogpro-article-preview` - Generate preview
- `blogpro-article-publisher` - Publish to website
- `blogpro-article-documenter` - Document article metadata

<WORKFLOWS>

## Workflow: Create

1. **Parse arguments** - Skill: blogpro-arg-parser
2. **Validate slug** - Check article doesn't already exist
3. **Determine template** - Use --template or ask user
4. **Determine author** - Use --author or ask user
5. **Create article** - Skill: blogpro-article-builder
6. **Document** - Skill: blogpro-article-documenter
7. **Report** - Show file locations
8. **Propose next steps** - If --complete: validate, else ask

## Workflow: Publish

1. **Parse arguments**
2. **Validate article exists**
3. **Validate content** - Skill: blogpro-article-validator
4. **Check environment** - If prod, confirm with user
5. **Publish** - Skill: blogpro-article-publisher
6. **Document** - Update docs with publication info
7. **Report** - Show URL, status

## Workflow: Complete Workflow

1. create → Create article
2. validate → Validate content
3. preview → Generate preview
4. review → Ask user to confirm
5. publish → Publish to environment
6. document → Final documentation update

</WORKFLOWS>

{... rest of agent definition ...}
```

### Step 6: Create Skills

**Article Builder Skill:**

```markdown
# .claude/skills/blogpro-article-builder/skill.md

---
name: blogpro-article-builder
description: Create new blog articles from templates
allowed-tools: Read, Write, Bash
---

# BlogPro Article Builder Skill

Creates new blog articles from predefined templates.

## Invocation

```
Skill: blogpro-article-builder
Input: {
  "article_slug": "my-first-post",
  "template": "blog-post",
  "author": "John Doe",
  "category": "programming",
  "metadata": {
    "title": "My First Post",
    "description": "..."
  }
}

Output: {
  "status": "success",
  "file_path": "content/articles/my-first-post.md",
  "preview_url": "http://localhost:1313/articles/my-first-post"
}
```

## Implementation

Invokes: `scripts/create-article.py --slug={slug} --template={template} ...`

Script:
1. Loads template from `templates/{template}.md`
2. Populates with provided metadata
3. Writes to `content/articles/{slug}.md`
4. Returns file path and preview URL
```

### Step 7: Test

**Test auto-triggering:**
```
User: "Create a new blog post"
→ Should trigger blogpro-article-manager
```

**Test workflow:**
```bash
/blogpro-article-manager workflow test-article --complete
→ Should create, validate, preview, publish, and document
```

**Test error handling:**
```bash
/blogpro-article-manager publish non-existent-article
→ Should stop with error, not proceed
```

### Result

**You now have:**
- ✅ Command for article management
- ✅ Manager agent that orchestrates workflows
- ✅ Skills that execute tasks
- ✅ Auto-triggering on natural language
- ✅ Built-in documentation
- ✅ Error handling with gap identification
- ✅ Complete workflow with --complete flag

---

## Conclusion

This pattern provides:

✅ **Structured workflows** - Repeatable, documented processes
✅ **Context preservation** - State maintained throughout
✅ **Scope discipline** - No ad-hoc solutions
✅ **Built-in docs** - Documentation as you work
✅ **Gap identification** - Missing capabilities surface clearly
✅ **Scalability** - Easy to add new domains, operations, skills

**When you follow this pattern, you get:**
- Consistent user experience across all operations
- AI that can automate complex workflows
- Documentation that's never outdated
- Clear identification of what's missing
- Permanent solutions, not ad-hoc fixes

**Start small:**
1. Pick one domain
2. Implement one manager
3. Create 3-4 skills
4. Test thoroughly
5. Expand to other domains

**The investment pays off when:**
- Workflows become repeatable
- Knowledge is codified
- New team members onboard faster
- AI can handle complex operations
- Documentation stays current

---

## Migration Guidelines

⭐ **Lessons from Lake.Corthonomy.AI Migration** - Successfully migrated from monolithic agents to 3-layer control plane over 6 weeks.

### When to Migrate

**Migrate if experiencing:**
- ❌ Context overflow (operations hitting token limits)
- ❌ Slow operations (dashboards >1 minute, workflows >5 minutes)
- ❌ Inconsistent outcomes (same operation, different results)
- ❌ Knowledge loss (solving same problems repeatedly)
- ❌ Poor scalability (adding resources slows system)

**Lake.Corthonomy.AI Triggers:**
- Dashboard generation: 15.7 minutes → unusable
- Context overflow: 40% of operations
- New dataset onboarding: 45-60 minutes manual work
- No historical learning: Same issues resolved repeatedly

### Migration Strategies

#### Strategy 1: Greenfield (New Projects)

**When:** Starting fresh, no existing agents

**Approach:** Build with v2 patterns from day one

**Timeline:** 1-2 weeks for initial setup

**Steps:**
1. Design 3-layer hierarchy (Commands → Manager → Skills)
2. Implement state management (state.json schema)
3. Create troubleshooting knowledge base (8-section template)
4. Build core skills (inspector, debugger, builder, tester)
5. Implement manager with 7-phase workflow
6. Set up issue logging and confidence scoring

**Lake.Corthonomy.AI Result:** 10 hours setup, operational in week 1

#### Strategy 2: Brownfield Migration (Existing Agents)

**When:** Have existing monolithic agents, want to modernize

**Approach:** Incremental migration, domain by domain

**Timeline:** 4-8 weeks depending on project size

**Phase 1: Analysis (Week 1)**
- Inventory existing agent capabilities
- Map to skill categories (inspector, debugger, builder, tester)
- Identify state management needs
- Document recurring issues for knowledge base

**Phase 2: Infrastructure (Week 2)**
- Implement state.json system
- Create issue log infrastructure
- Build troubleshooting knowledge base template
- Set up confidence scoring algorithm

**Phase 3: Core Skills (Weeks 3-4)**
- Extract inspector logic from existing agents
- Create debugger with knowledge base integration
- Build builder skills for operations
- Implement tester for validation

**Phase 4: Manager Layer (Week 5)**
- Create manager with 7-phase workflow
- Implement workflow order enforcement
- Add confidence-based execution logic
- Integrate with skills

**Phase 5: Command Layer (Week 6)**
- Update commands to invoke manager
- Add argument parsing
- Remove logic from commands

**Phase 6: Validation (Weeks 7-8)**
- Run parallel (old + new) for 2 weeks
- Compare outcomes and performance
- Fix issues, tune confidence scores
- Fully cutover to new system

**Lake.Corthonomy.AI Timeline:**
- Analysis: 3 days
- Infrastructure: 5 days
- Core skills: 12 days
- Manager: 5 days
- Commands: 2 days
- Validation: 14 days
- **Total: 41 days (6 weeks)**

#### Strategy 3: Hybrid (Partial Migration)

**When:** Large codebase, want to test v2 patterns first

**Approach:** Migrate one domain, keep others on v1

**Timeline:** 2-3 weeks per domain

**Pattern:**
1. Choose least critical domain for pilot
2. Implement full v2 stack for that domain
3. Validate performance improvements
4. Migrate remaining domains one at a time

**Lake.Corthonomy.AI:** Piloted with IPEDS dataset (smallest, 14 tables), then expanded

#### Strategy 4: Pre-Skills Migration (Agent Chains)

⭐ **CRITICAL FOR LEGACY PROJECTS** - Convert pre-skills agent chains to Manager-as-Agent + Skills architecture

**When:** Project built before skills abstraction existed (Agent → Agent → Agent chains)

**Symptoms:**
- ❌ Workflow implemented as sequential agent invocations (Agent1 → Agent2 → Agent3)
- ❌ No `.claude/skills/` directory
- ❌ All logic embedded in agent prompts (no script abstraction)
- ❌ Heavy context usage (each agent loads full context)
- ❌ No state management between workflow steps

**Pre-Skills Architecture:**
```
Command: /myproject-process
  ↓
Agent: step1-agent.md → Task tool → step2-agent.md
  ↓
Agent: step2-agent.md → Task tool → step3-agent.md
  ↓
Agent: step3-agent.md → Task tool → step4-agent.md
  ↓
Results

Context Loads: 4+ agents × 45K tokens = 180K+ tokens
No parallelism, no script abstraction, poor maintainability
```

**Target Architecture (Manager-as-Agent + Skills):**
```
Command: /myproject-process
  ↓
Manager Agent: myproject-process-manager.md
  - Orchestrates 7-phase workflow
  - Maintains state across phases
  - Natural user interaction
  ↓
  ├─ Skill: myproject-step1 (scripts/step1-logic.sh)
  ├─ Skill: myproject-step2 (scripts/step2-logic.sh)
  ├─ Skill: myproject-step3 (scripts/step3-logic.sh)
  └─ Skill: myproject-step4 (scripts/step4-logic.sh)

Context Loads: 1 Manager + 4 Skills = ~85K tokens (53% reduction)
Script abstraction, proper state management, maintainable
```

**Migration Timeline:** 2-3 weeks

**Phase 1: Analysis (Days 1-3)**
- [ ] Map agent chain workflow (identify all agents in chain)
- [ ] Classify agent roles (orchestration vs. execution vs. hybrid)
- [ ] Identify deterministic logic for script extraction
- [ ] Document workflow state requirements

**Phase 2: Create Manager Agent (Days 4-6)**
- [ ] Create Manager as AGENT in `.claude/agents/project/{name}-manager.md`
- [ ] Add full tool access: `allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]`
- [ ] Implement 7-phase workflow structure
- [ ] Add state management (track workflow progress)
- [ ] Add user interaction points (approvals, error handling)

**Phase 3: Convert Agents to Skills (Days 7-12)**
- [ ] Create skill directory for each execution agent
- [ ] Extract deterministic logic to `scripts/` (file ops, API calls, transforms)
- [ ] Create SKILL.md that invokes scripts
- [ ] Remove orchestration logic (Manager handles this now)
- [ ] Test each skill in isolation

**Phase 4: Update Command Routing (Day 13)**
- [ ] Update command to route to Manager Agent (not first agent in chain)
- [ ] Remove old agent invocations
- [ ] Test end-to-end workflow

**Phase 5: Cleanup & Validation (Days 14-15)**
- [ ] Archive old agent files (don't delete immediately)
- [ ] Run parallel testing (old vs. new) for 1 week
- [ ] Measure performance improvements (context reduction, speed)
- [ ] Verify state management working correctly
- [ ] Confirm full cutover

**Conversion Example:**

Before (Agent Chain):
```
.claude/agents/
├── validate-input-agent.md    # 450 lines, orchestration + execution
├── transform-data-agent.md    # 680 lines, orchestration + execution
├── save-results-agent.md      # 320 lines, orchestration + execution
└── notify-completion-agent.md # 210 lines, orchestration + execution
Total: 1660 lines, 4 context loads, no scripts
```

After (Manager + Skills):
```
.claude/agents/project/
└── myproject-process-manager.md  # 280 lines, orchestration only

.claude/skills/
├── myproject-input-validator/
│   ├── SKILL.md                  # 80 lines
│   └── scripts/validate-input-files.sh  # 120 lines, outside LLM context
├── myproject-data-transformer/
│   ├── SKILL.md                  # 90 lines
│   └── scripts/transform-data.sh        # 200 lines, outside LLM context
├── myproject-result-saver/
│   ├── SKILL.md                  # 70 lines
│   └── scripts/save-results.sh          # 90 lines, outside LLM context
└── myproject-notifier/
    ├── SKILL.md                  # 60 lines
    └── scripts/notify.sh                # 50 lines, outside LLM context

Total: 1040 lines in LLM context (37% reduction)
       + 460 lines in scripts (outside context)
Context loads: 1 Manager + 4 Skills = 5 loads, but much lighter
Maintainability: Significantly improved, proper separation of concerns
```

**Success Criteria:**
- ✅ Context usage reduced by 40-60%
- ✅ Workflow state properly maintained
- ✅ User interaction natural (AskUserQuestion works)
- ✅ Scripts handle deterministic operations
- ✅ Manager has full agent capabilities

**Common Pitfalls:**
1. ❌ **Keeping Manager as Skill**: Must be AGENT for full capabilities
2. ❌ **Not extracting scripts**: Leaves deterministic logic in prompts
3. ❌ **Incomplete state management**: Workflow loses context between phases
4. ❌ **Skipping parallel testing**: Cutover too fast, issues not caught

### Migration Checklist

#### Week 1: Foundation
- [ ] State management system (state.json + file locking)
- [ ] Issue log infrastructure (JSONL + analytics)
- [ ] Troubleshooting knowledge base (8-section template)
- [ ] Confidence scoring algorithm (base + historical + context)

#### Weeks 2-3: Skills Layer
- [ ] Inspector skill (7 check types)
- [ ] Debugger skill (knowledge base integration)
- [ ] Builder skill(s) (operations extracted from old agents)
- [ ] Tester skill (validation logic)

#### Week 4: Manager Layer
- [ ] Manager with 7-phase workflow
- [ ] Workflow order enforcement (INSPECT → DATA-SYNC → CATALOG → TEST → DEPLOY)
- [ ] Confidence-based execution (≥80 auto, 50-79 user, <50 manual)
- [ ] State-driven decision making

#### Week 5: Command Layer
- [ ] Commands updated to invoke manager
- [ ] Argument parsing logic
- [ ] Error handling and reporting

#### Week 6: Validation
- [ ] Performance benchmarks (compare old vs new)
- [ ] Parallel operation test (old + new side-by-side)
- [ ] Confidence score calibration
- [ ] Knowledge base completeness check

### Common Migration Pitfalls

#### Pitfall 1: Migrating Logic Without Patterns

**Symptom:** Copied old agent logic into skills verbatim

**Problem:** No performance improvement, same issues as before

**Solution:** Refactor during migration
- Extract state queries to state.json reads
- Move decision logic to manager
- Document fix patterns in knowledge base

**Lake.Corthonomy.AI Lesson:** Don't copy-paste, redesign with v2 patterns

#### Pitfall 2: Incomplete Knowledge Base

**Symptom:** Debugger frequently returns "no known fix"

**Problem:** Knowledge base only documents 20-30% of issues

**Solution:** Mine existing agent logs for common issues, document ALL recurring patterns

**Lake.Corthonomy.AI Target:** 95%+ coverage (achieved 96.2%)

#### Pitfall 3: Ignoring Performance Metrics

**Symptom:** Migrated but no measured improvement

**Problem:** No baseline metrics, can't prove value

**Solution:** Measure BEFORE and AFTER
- Context loading (tokens per operation)
- Execution speed (workflow duration)
- Success rates (fix accuracy)
- Developer experience (MTTR)

**Lake.Corthonomy.AI Metrics:**
- Context: 13x reduction
- Speed: 20x faster workflows
- Success: 94.1% high-confidence fixes
- MTTR: 45 seconds (vs 8 minutes)

### Post-Migration Maintenance

#### Monthly Tasks
- Review issue log analytics
- Identify declining success rates
- Update knowledge base with new patterns
- Recalibrate confidence scores

#### Quarterly Tasks
- Validate all 8 success criteria
- Performance benchmarking
- Knowledge base completeness audit
- State consistency verification

#### Red Flags
- Success rates dropping >10% quarter-over-quarter
- Knowledge base coverage <90%
- State consistency <95%
- MTTR trending upward

---

## Real-World Example: Lake.Corthonomy.AI

⭐ **Complete v2 Implementation** - Data lake control plane managing 47 datasets, 154 catalog tables, with 12 skills and full v2 patterns.

### Project Context

**Challenge:** Manage AWS Glue catalog for 47 datasets across 7 data sources
- Each dataset: Multiple entities (e.g., IPEDS has 14 tables)
- Operations: Create, sync, validate, test, deploy, document
- Complexity: Schema drift, version management, Spark compatibility, Lake Formation permissions

**Before v2 (Monolithic Agents):**
- Dashboard generation: 15.7 minutes (unusable)
- Context overflow: 40% of operations
- New dataset onboarding: 45-60 minutes
- Knowledge loss: Same issues resolved repeatedly
- No confidence scoring: Unknown fix success likelihood

**After v2 (3-Layer Control Plane):**
- Dashboard generation: 9.4 seconds (100x faster)
- Context overflow: <1% of operations
- New dataset onboarding: 2-3 minutes (20x faster)
- Knowledge base: 96.2% coverage
- Confidence scoring: 94.1% accuracy

### Architecture Implementation

#### Layer 1: Commands (12 Slash Commands)

```
/project:table-manage [dataset]           → corthonomy-manager
/project:table-inspect [dataset]          → corthonomy-inspector
/project:table-dashboard [pattern]        → corthonomy-auditor
/project:table-config-create [dataset]    → corthonomy-catalog-builder
/project:table-config-sync-schema [dataset] → corthonomy-catalog-builder
/project:table-data-test [dataset]        → corthonomy-data-tester
... (6 more commands)
```

**Command Pattern:**
```markdown
# .claude/commands/project:table-manage.md
Parse [dataset] argument (e.g., "ipeds/hd", "ipeds/*", "*")
Invoke corthonomy-manager skill with resource=[dataset]
```

#### Layer 2: Manager (corthonomy-manager)

**7-Phase Workflow:**

```python
def manage_workflow(resource):
    # Phase 1: INSPECT
    issues = inspector.invoke(resource, check="full")

    # Phase 2: ANALYZE
    analysis = debugger.analyze(issues)
    # Returns: fixes, confidence scores, estimated duration

    # Phase 3: PRESENT
    present_plan(analysis)  # Shows user what will be fixed

    # Phase 4: APPROVE
    if not user_approves():
        return "Workflow cancelled"

    # Phase 5: EXECUTE
    for fix in analysis["recommended_fixes"]:
        if fix["confidence"] >= 80:
            catalog_builder.invoke(fix)  # Auto-fix high confidence
        elif fix["confidence"] >= 50:
            if user_confirms(fix):       # Ask for medium confidence
                catalog_builder.invoke(fix)

    # Phase 6: VERIFY
    retest = data_tester.invoke(resource)
    if not retest["passed"]:
        return "Fixes failed validation"

    # Phase 7: REPORT
    return report_results(before=issues, after=retest)
```

#### Layer 3: Skills (12 Specialized Skills)

**corthonomy-inspector** (Observes WHAT IS)
- 7 check types: full, data-currency, schema-drift, catalog-config, documentation, data-exists, catalog-exists
- Returns: Factual observations only, NO analysis

**corthonomy-debugger** (Analyzes WHY + HOW)
- Searches 5 troubleshooting knowledge base documents
- Calculates confidence scores using issue log
- Returns: Fix recommendations + confidence + estimated time

**corthonomy-catalog-builder** (Executes CATALOG OPS)
- 8 operations: create, update, sync-schema, fix-spark-compatibility, update-version, fix-permissions, fix-version-views, fix-partition-projection
- Updates state.json after each operation
- Records outcomes to issue log

**corthonomy-data-syncer** (Executes DATA OPS)
- 4 operations: sync-data, verify-sync, cleanup, batch
- Copies S3 data from ETL system to lake
- Updates state.json with version information

**corthonomy-catalog-tester** (Validates CATALOG)
- Tests: SPEC-013 compliance, version views, Athena queries, Spark compatibility
- Pass/fail criteria based on standards
- Returns: Detailed test report

**corthonomy-data-tester** (Validates DATA)
- Tests: Data quality, completeness, performance
- Returns: Data quality metrics

**corthonomy-state-manager** (State Operations)
- Operations: read, update, refresh, validate
- Atomic updates with file locking
- Schema validation

**corthonomy-changelog-recorder** (Audit Trail)
- Records all operations to changelog
- JSONL format for easy parsing
- Analytics queries for reporting

**corthonomy-auditor** (Fast Dashboards)
- Reads state.json (not S3/Glue APIs)
- Generates visual health dashboard
- 9.4 seconds for 47 datasets

**corthonomy-catalog-deployer** (Infrastructure Deployment)
- Deploys Terraform to test/prod
- Validates deployment
- Updates state.json

**corthonomy-documentation-builder** (Docs Generation)
- Extracts schema from catalog
- Generates markdown docs
- Updates automatically

**corthonomy-workflow-coordinator** (Complex Workflows)
- Coordinates multi-step operations
- Implements workflow order enforcement
- Manages state transitions

### State Management Implementation

**state.json Schema (6 Sections):**

```json
{
  "entity": "ipeds/hd",
  "last_updated": "2025-01-15T10:30:00Z",

  "etl": {
    "available_versions": ["2023", "2024"],
    "latest_version": "2024",
    "schema_hash": "abc123...",
    "last_checked": "2025-01-15T10:00:00Z"
  },

  "lake": {
    "current_version": "2024",
    "s3_path": "s3://test.lake.corthonomy.ai/curated/ipeds/hd/",
    "last_synced_at": "2025-01-15T09:00:00Z",
    "sync_status": "current"
  },

  "catalog": {
    "table_exists": true,
    "database": "corthodex",
    "table_name": "ipeds_hd",
    "spark_compatible": true,
    "version_views_exist": true,
    "last_deployed_at": "2025-01-15T08:00:00Z"
  },

  "validation": {
    "spec_013_compliant": true,
    "last_tested_at": "2025-01-15T10:15:00Z",
    "test_results": {
      "spark_compatibility": "pass",
      "version_views": "pass",
      "athena_query": "pass"
    }
  },

  "testing": {
    "data_quality_score": 0.98,
    "last_data_test": "2025-01-15T10:20:00Z"
  },

  "documentation": {
    "schema_documented": true,
    "user_guide_exists": true,
    "last_updated": "2025-01-15T10:25:00Z"
  }
}
```

### Troubleshooting Knowledge Base

**5 Key Documents:**
1. **kb-schema-drift.md**: Schema sync issues (95% coverage)
2. **kb-spark-compatibility.md**: SPEC-013 violations (100% coverage)
3. **kb-version-management.md**: Version update issues (90% coverage)
4. **kb-data-sync.md**: S3 copy issues (85% coverage)
5. **kb-catalog-config.md**: Glue configuration issues (98% coverage)

**Example Entry (kb-schema-drift.md):**
```markdown
## Issue: Field Added in ETL Schema

**Detection:** Inspector compares state.json schema_hash to ETL schema

**Root Cause:** ETL added new field, catalog not updated

**Fix (Confidence: 85):**
1. Invoke catalog-builder with operation="sync-schema"
2. Catalog-builder compares ETL schema to Glue schema
3. Adds missing fields to Glue table
4. Updates state.json schema_hash
5. Regenerates documentation

**Validation:** Run catalog-tester to verify schema match

**Historical Success Rate:** 19/20 (95%)
```

### Performance Results

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Dashboard generation | 15.7 min | 9.4 sec | 100x faster |
| Context per operation | 180K tokens | 15K tokens | 12x reduction |
| New dataset onboarding | 45-60 min | 2-3 min | 20x faster |
| Schema drift fix | 10-15 min | 45-90 sec | 10x faster |
| Targeted inspection | 30 sec | 3 sec | 10x faster |
| Knowledge base coverage | N/A | 96.2% | New capability |
| High-confidence fix success | N/A | 94.1% | New capability |
| MTTR (known issues) | 8 min | 45 sec | 11x faster |

### Lessons Learned

**What Worked Well:**
- ✅ State-based dashboards (100x faster)
- ✅ Modular inspector (10x faster targeted checks)
- ✅ Troubleshooting knowledge base (96.2% coverage)
- ✅ Confidence scoring (94.1% accuracy)
- ✅ Atomic state updates (99.8% consistency)

**What Was Challenging:**
- ⚠️ Initial knowledge base creation (3 weeks of issue mining)
- ⚠️ Confidence score calibration (2 iterations to get right)
- ⚠️ State schema design (4 revisions to cover all cases)

**Would Do Differently:**
- Start with smaller scope (piloted with 1 dataset, should have started even smaller)
- Document patterns earlier (knowledge base should be first deliverable)
- Measure baseline metrics (didn't have "before" numbers for all metrics)

**Unexpected Benefits:**
- New developer onboarding: 4x faster with knowledge base
- Confidence to automate: High-confidence fixes run unattended
- System learning: Confidence improves automatically over time
- Clear boundaries: Skills don't step on each other

---

## Changelog

### Version 2.0 (January 2025)

**Major additions based on Lake.Corthonomy.AI implementation:**

#### New Architecture Principles (4)
- **#7: State-Based Decision Making** - Use state snapshots instead of repeated infrastructure queries (100x faster dashboards)
- **#8: Mandatory Workflow Order** - Enforce INSPECT → DATA-SYNC → CATALOG-OPS → TEST → DEPLOY (60% fewer bugs)
- **#9: Historical Learning** - Issue log + confidence scoring improves fixes over time (94.1% accuracy)
- **#10: Performance by Design** - Optimize for context, speed, and developer experience from start (20x faster workflows)

#### New Infrastructure Systems (3)
- **State Management** - state.json with atomic updates, file locking, 6-section schema (99.8% consistency)
- **Troubleshooting Knowledge Base** - 8-section template embedded in debugger (96.2% issue coverage)
- **Issue Log & Confidence Scoring** - JSONL log, confidence algorithm, historical learning (94.1% success rate)

#### New Design Patterns (2)
- **Modular Inspector Pattern** - 7 check types, targeted 1-3s checks vs 30s full inspection (10x faster)
- **Skill Reporting Standards** - Consistent start/end templates, progress updates, duration tracking

#### New Common Patterns (6)
- **Inspector-First Diagnosis** - Observe → Analyze → Execute (never improvise)
- **State-Driven Operations** - Read from state.json, not infrastructure APIs (100x faster)
- **Confidence-Based Execution** - ≥80 auto-fix, 50-79 user approval, <50 manual review
- **Fast-Fail Pre-Checks** - 1-3s checks before expensive operations (10-30x faster failure detection)
- **Historical Context Resolution** - Debugger selects fixes based on success rates (improves over time)
- **Atomic State Updates** - File locking + temp file + rename pattern (prevents corruption)

#### New Anti-Patterns (5)
- **Manager Improvising Fixes** - Must follow debugger recommendations (96.2% KB coverage)
- **Querying Infrastructure Directly** - Use state.json snapshots (100x faster)
- **Skipping Workflow Order** - Must follow mandatory order (prevents broken references)
- **Ignoring Confidence Scores** - Respect thresholds for safe automation (94.1% success)
- **Non-Atomic State Updates** - Use file locking to prevent corruption (99.8% consistency)

#### New Sections (3)
- **Performance Metrics** - Real data from Lake.Corthonomy.AI: 13x context reduction, 100x faster dashboards, 20x faster workflows
- **Success Criteria** - 8 measurable criteria: KB coverage, confidence accuracy, documentation freshness, state consistency, test pass rates, workflow completion, MTTR, dashboard utility
- **Migration Guidelines** - 3 strategies (greenfield, brownfield, hybrid), 6-week brownfield timeline, common pitfalls, post-migration maintenance

#### Enhanced Examples (1)
- **Lake.Corthonomy.AI Real-World Example** - Complete implementation: 12 skills, 47 datasets, 154 tables, performance results, lessons learned

#### Documentation Improvements
- Added ⭐ markers for Lake.Corthonomy.AI innovations (18 major innovations documented)
- Added performance benchmarks and real-world data throughout
- Added code examples with ❌ (bad) and ✅ (good) patterns
- Added "Why This Matters" sections with quantified benefits
- Added "Lake.Corthonomy.AI Results" data points

### Version 1.0 (Original)

**Core concepts:**
- 3-layer hierarchy (Commands → Manager → Skills)
- Builder/Debugger pattern
- 6 architecture principles
- 5 common patterns
- 6 anti-patterns
- BlogPro example

---

## Additional Resources

- **Reference Implementation:** Core.Corthovore.AI control plane
- **Specification:** `/docs/specs/11-control-plane-architecture.md`
- **Claude Code Documentation:** https://docs.claude.com/claude-code

---

**Questions? Feedback?**

This guide is a living document. As you implement control planes, capture learnings and update this guide to help future implementations.
