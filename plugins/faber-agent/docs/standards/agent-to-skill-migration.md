---
org: fractary
system: claude-plugins
title: Agent-to-Skill Migration Guide
description: Step-by-step guide for migrating from anti-patterns (Manager-as-Skill, Director-as-Agent, Agent Chains) to Manager-as-Agent architecture
tags: [migration, refactoring, manager, director, agent-chains, pre-skills, best-practices]
created: 2025-01-15
updated: 2025-01-15
version: 1.0
codex_sync_include: [*]
codex_sync_exclude: []
visibility: internal
---

# Agent-to-Skill Migration Guide

## Overview

This guide provides step-by-step migration paths for converting projects from architectural anti-patterns to the correct **Manager-as-Agent** architecture.

**Common Anti-Patterns:**
1. Manager as Skill (inverted)
2. Director as Agent (over-engineered)
3. Agent Chains (pre-skills era)
4. Hybrid Agents (orchestration + execution)
5. No Script Abstraction (inline deterministic logic)

**Target Architecture:**
- Manager = **AGENT** (orchestration with full capabilities)
- Director = **SKILL** (lightweight pattern expansion)
- Specialists = **SKILLS** (script-backed execution)

---

## Table of Contents

1. [Migration Overview](#migration-overview)
2. [Migration 1: Manager-as-Skill → Manager-as-Agent](#migration-1-manager-as-skill--manager-as-agent)
3. [Migration 2: Director-as-Agent → Director-as-Skill](#migration-2-director-as-agent--director-as-skill)
4. [Migration 3: Agent Chains → Manager + Skills](#migration-3-agent-chains--manager--skills) ⭐ CRITICAL
5. [Migration 4: Hybrid Agents → Separated Concerns](#migration-4-hybrid-agents--separated-concerns)
6. [Migration 5: Script Extraction](#migration-5-script-extraction)
7. [Testing & Validation](#testing--validation)
8. [Rollback Procedures](#rollback-procedures)

---

## Migration Overview

### Pre-Migration Checklist

Before starting any migration:

- [ ] **Backup current implementation**
  ```bash
  git checkout -b backup-before-migration-$(date +%Y%m%d)
  git push origin backup-before-migration-$(date +%Y%m%d)
  ```

- [ ] **Document current behavior**
  - List all commands and their expected outcomes
  - Capture sample workflows
  - Note any edge cases or quirks

- [ ] **Measure baseline metrics**
  - Context usage (tokens per operation)
  - Wall-clock time (workflow duration)
  - Success rate (percentage of successful completions)
  - User experience (ease of approval, error clarity)

- [ ] **Identify dependencies**
  - Which components call each other?
  - What external systems are involved?
  - Are there any integration points?

- [ ] **Plan testing strategy**
  - How will you validate each migration step?
  - Can you run old and new in parallel?
  - What constitutes success?

### Migration Strategy

**Recommended Approach: Incremental Migration**

1. **Start with lowest-risk component** (often Director)
2. **Migrate one component at a time**
3. **Test thoroughly after each migration**
4. **Run parallel (old + new) for validation period**
5. **Full cutover only after confidence built**

**Timeline:** 2-4 weeks depending on complexity

---

## Migration 1: Manager-as-Skill → Manager-as-Agent

### When to Use This Migration

**Symptoms:**
- Manager located in `.claude/skills/myproject-manager/`
- Limited tool access (no AskUserQuestion, restricted Read/Write/Bash)
- Awkward approval workflows
- State management problems
- Error handling feels unnatural

**Impact:** HIGH - This is the most critical migration

**Effort:** Medium (3-5 days)

### Step-by-Step Migration

#### Step 1: Analysis (Day 1)

**Analyze current Manager skill:**

```bash
# 1. Find Manager skill
find .claude/skills -name "*manager*" -type d

# 2. Analyze Manager implementation
cat .claude/skills/myproject-manager/SKILL.md

# 3. Identify all operations
grep -n "^### " .claude/skills/myproject-manager/SKILL.md

# 4. Check tool usage patterns
grep -E "(Read|Write|Bash|Skill)" .claude/skills/myproject-manager/SKILL.md
```

**Document findings:**
- [ ] What operations does Manager currently support?
- [ ] How is state currently managed (if at all)?
- [ ] Where does user interaction happen (if at all)?
- [ ] What skills does Manager invoke?
- [ ] Are there any workflow files?

#### Step 2: Create New Manager Agent Structure (Day 2)

**Create agent directory:**

```bash
mkdir -p .claude/agents/project
```

**Create Manager agent file:**

`.claude/agents/project/myproject-manager.md`

```markdown
---
name: myproject-manager
description: Orchestrates {domain} workflows for single entities with 7-phase process
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---

# MyProject Manager

<CONTEXT>
You are the Manager for MyProject. You orchestrate complete workflows
for a **single {entity}** using the 7-phase pattern: Inspect → Analyze
→ Present → Approve → Execute → Verify → Report.

You maintain state throughout the workflow and coordinate specialist skills.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS maintain workflow state
2. ALWAYS use specialist skills for execution (never do work directly)
3. ALWAYS get user approval before making changes
4. ALWAYS verify after execution
5. NEVER proceed after failures without user decision
</CRITICAL_RULES>

<INPUTS>
You receive:
- entity: Entity identifier to operate on
- operation: Operation to perform (create, update, validate, etc.)
- Additional parameters specific to operation
</INPUTS>

<WORKFLOW>

## Phase 1: INSPECT
- Invoke myproject-inspector skill
- Store inspection results in workflow state
- Determine if issues exist

## Phase 2: ANALYZE (conditional)
- If issues found, invoke myproject-debugger skill
- Calculate confidence scores
- Determine recommended fixes
- Skip if no issues

## Phase 3: PRESENT
- Show user what will be done
- Explain confidence levels if applicable
- Highlight any risks or impacts
- Be clear and concise

## Phase 4: APPROVE
- Use AskUserQuestion to get user decision
- Options: proceed, modify parameters, or cancel
- Store approval decision in workflow state
- Respect user's choice

## Phase 5: EXECUTE
- Invoke appropriate builder skill(s) based on operation
- Track execution progress
- Handle errors gracefully
- Update workflow state with execution results

## Phase 6: VERIFY
- Re-invoke inspector to confirm success
- Compare with Phase 1 results
- Validate all expected changes applied
- Check for unexpected side effects

## Phase 7: REPORT
- Comprehensive summary of all phases
- Show before/after state comparison
- List any warnings or recommendations
- Propose logical next steps if applicable

</WORKFLOW>

<STATE_MANAGEMENT>
Maintain workflow state tracking:
- entity: Current entity being processed
- operation: Operation being performed
- workflow_phase: Current phase name
- phases_completed: Array of completed phase names
- inspection_results: Output from Phase 1
- analysis_results: Output from Phase 2 (if ran)
- user_approval: Decision from Phase 4
- execution_results: Output from Phase 5
- verification_results: Output from Phase 6

Store state in: .myproject/state/{entity}/workflow-state.json
</STATE_MANAGEMENT>

<AVAILABLE_SKILLS>
- myproject-inspector: Check entity state and identify issues
- myproject-debugger: Analyze issues and recommend fixes with confidence scores
- myproject-builder: Execute operations (create, update, delete, etc.)
- myproject-validator: Validate entity configuration and data
</AVAILABLE_SKILLS>

<ERROR_HANDLING>
When errors occur:
1. STOP immediately (don't continue workflow)
2. Analyze error using available tools (Read logs, Grep patterns, etc.)
3. If error is known/simple: Propose fix to user via AskUserQuestion
4. If error is complex/unknown: Report to user with diagnostic info, ask for guidance
5. Never guess or assume - always involve user in error resolution
</ERROR_HANDLING>

<OUTPUTS>
Return structured workflow summary:
- Status: success | partial | failure
- Phases completed: List of phase names
- Entity state: before and after
- Issues found: From inspection
- Changes made: From execution
- Verification status: From re-inspection
- Next steps: Recommendations for user
</OUTPUTS>
```

**Key Changes from Skill:**
- ✅ Added `allowed_tools` with full suite
- ✅ Added 7-phase workflow structure
- ✅ Added `<STATE_MANAGEMENT>` section
- ✅ Added `<ERROR_HANDLING>` section with agent capabilities
- ✅ Uses AskUserQuestion for approval
- ✅ Structured as agent conversation, not skill interface

#### Step 3: Migrate State Management (Day 2)

**Old (Skill - probably no state):**
```markdown
# Manager skill had no persistent state
- Each invocation started fresh
- State passed externally
```

**New (Agent - proper state):**
```markdown
# Manager agent maintains state in workflow-state.json

<STATE_MANAGEMENT>
Store state in: .myproject/state/{entity}/workflow-state.json

Use Write tool to save state after each phase:
```json
{
  "entity": "user-service",
  "operation": "validate",
  "workflow_phase": "verify",
  "phases_completed": ["inspect", "analyze", "present", "approve", "execute"],
  "started_at": "2025-01-15T10:30:00Z",
  "inspection_results": {
    "status": "issues_found",
    "issues": ["missing_config_version", "schema_outdated"]
  },
  "analysis_results": {
    "recommended_fixes": ["update_config_version", "migrate_schema"],
    "confidence": 0.92
  },
  "user_approval": {
    "decision": "approved",
    "timestamp": "2025-01-15T10:32:15Z"
  },
  "execution_results": {
    "status": "success",
    "changes_made": ["config.json updated", "schema.sql migrated"]
  }
}
```

Use Read tool to load state at workflow start
Use Edit tool to update specific state fields during workflow
```
</STATE_MANAGEMENT>
```

#### Step 4: Migrate User Interaction (Day 3)

**Old (Skill - awkward):**
```markdown
# Skill couldn't naturally interact with user
Operation: validate

If issues found:
  Return: "Issues found: X, Y, Z. Approval needed."

External caller had to:
  1. Parse skill output
  2. Ask user somehow
  3. Re-invoke skill with approval parameter
```

**New (Agent - natural):**
```markdown
## Phase 3: PRESENT

Show user comprehensive plan:

"I've inspected {entity} and found 2 issues:

1. **Missing config version** (Confidence: 95%)
   - Issue: config.json lacks version field
   - Fix: Add 'version: 1.0' to config
   - Impact: Low risk, required for deployment

2. **Schema outdated** (Confidence: 88%)
   - Issue: Database schema is v1.2, code expects v1.3
   - Fix: Run migration script: migrate-schema-v1.2-to-v1.3.sql
   - Impact: Medium risk, requires database write access

Estimated time: 2 minutes
Rollback available: Yes (schema migrations are reversible)"

## Phase 4: APPROVE

Use AskUserQuestion:
"Do you want to proceed with these fixes?"

Options:
- "Yes, proceed with both fixes"
- "Proceed with #1 only (skip schema migration)"
- "Let me review first (cancel for now)"

[User selects option]

Store decision and proceed based on user choice.
```

#### Step 5: Update Command Routing (Day 3)

**Old (routed to skill):**

`.claude/commands/myproject-validate.md`
```markdown
**Single Entity:**
Invoke Skill: myproject-manager
Operation: validate
Entity: {entity}

**Batch:**
Invoke Agent: myproject-director
Pattern: {pattern}
```

**New (routed to agent):**

`.claude/commands/myproject-validate.md`
```markdown
**Single Entity:**
Invoke Agent: myproject-manager (task tool)
Input:
  entity: {entity}
  operation: validate

**Batch:**
1. Invoke Skill: myproject-director
   Input: pattern: {pattern}

2. Director returns: list of entities

3. Core Claude Agent invokes myproject-manager for each entity (parallel)
```

#### Step 6: Parallel Testing (Days 4-5)

**Run old and new side-by-side:**

```bash
# Test old Manager (skill)
Skill: myproject-manager
Input: {entity: "user-service", operation: "validate"}

# Test new Manager (agent)
Agent: myproject-manager
Input: {entity: "user-service", operation: "validate"}

# Compare:
- Context usage (should be similar for single operation)
- Wall-clock time (should be similar)
- User experience (new should be MUCH better)
- Approval flow (new should feel natural)
- Error handling (new should be more robust)
```

**Validation Criteria:**
- ✅ New Manager completes all 7 phases
- ✅ State persists across phases (verify workflow-state.json)
- ✅ User approval works naturally via AskUserQuestion
- ✅ Error handling is more comprehensive
- ✅ All original operations still work

#### Step 7: Cleanup and Cutover (Day 5)

**Archive old Manager skill:**

```bash
mkdir -p .claude/archive/pre-migration-$(date +%Y%m%d)
mv .claude/skills/myproject-manager .claude/archive/pre-migration-$(date +%Y%m%d)/
```

**Update documentation:**
- Update README with new Manager agent location
- Update any diagrams showing architecture
- Add migration notes to CHANGELOG

**Announce cutover:**
- Notify team of changes
- Provide examples of new workflow
- Document any breaking changes

### Migration Validation

**Success Criteria:**
- ✅ Manager is an agent in `.claude/agents/project/`
- ✅ Manager has `allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]`
- ✅ Manager implements 7-phase workflow
- ✅ Manager maintains state in workflow-state.json
- ✅ User approval flows work naturally
- ✅ Error handling is comprehensive
- ✅ All operations from old Manager still work
- ✅ Metrics show improvement (or at worst, parity)

---

## Migration 2: Director-as-Agent → Director-as-Skill

### When to Use This Migration

**Symptoms:**
- Director located in `.claude/agents/project/director.md`
- Director does pattern expansion + orchestration
- Director loops over entities sequentially
- No parallelism for batch operations

**Impact:** MEDIUM - Improves batch performance

**Effort:** Low (1-2 days)

### Step-by-Step Migration

#### Step 1: Analysis (Day 1 Morning)

**Analyze current Director agent:**

```bash
# Find Director
cat .claude/agents/project/*director*.md

# Identify what it does
# Should find: pattern expansion + sequential Manager invocations
```

**Expected pattern:**
```markdown
# Current Director Agent (WRONG)

1. Parse pattern (*, dataset/*, a,b,c)
2. Expand to entity list
3. FOR EACH entity:
     Invoke Manager via Task tool (SEQUENTIAL)
4. Aggregate results
5. Return to user
```

**Problems identified:**
- Sequential execution (slow)
- Over-engineered (Agent for simple task)
- Prevents Core Agent parallelism

#### Step 2: Create Director Skill (Day 1 Afternoon)

**Create skill structure:**

```bash
mkdir -p .claude/skills/myproject-director/scripts
```

**Create skill file:**

`.claude/skills/myproject-director/SKILL.md`

```markdown
---
skill: myproject-director
purpose: Expand batch patterns for parallel Manager invocation
layer: Pattern Expander
---

# MyProject Director

## Purpose

Lightweight pattern expansion for batch operations. Returns list of
entities for Core Claude Agent to invoke Manager agents in parallel.

**What this skill does:**
- Parse patterns: `*`, `domain/*`, `a,b,c`
- Expand wildcards to entity lists
- Validate entities exist
- Return list + parallelism recommendation

**What this skill does NOT do:**
- ❌ Does NOT invoke Manager agents
- ❌ Does NOT orchestrate workflows
- ❌ Does NOT aggregate results
- ❌ Does NOT loop over entities

## Operations

### expand-pattern

Parse batch pattern and return entity list.

**Invocation:**
```json
{
  "operation": "expand-pattern",
  "pattern": "dataset/*",
  "base_path": ".myproject/entities"
}
```

**Implementation:**
Invoke script: `scripts/expand-pattern.sh --pattern "$pattern" --base-path "$base_path"`

**Output:**
```json
{
  "status": "success",
  "entities": ["dataset/users", "dataset/orders", "dataset/products"],
  "count": 3,
  "parallelism_recommendation": 3,
  "pattern_used": "dataset/*"
}
```

## Scripts

### expand-pattern.sh

Pattern expansion logic (deterministic, outside LLM context).

**Implementation:** `scripts/expand-pattern.sh`

```bash
#!/bin/bash
# Expand pattern to entity list

set -euo pipefail

PATTERN=""
BASE_PATH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --pattern) PATTERN="$2"; shift 2;;
    --base-path) BASE_PATH="$2"; shift 2;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

if [[ -z "$PATTERN" ]] || [[ -z "$BASE_PATH" ]]; then
  echo "Error: --pattern and --base-path required"
  exit 1
fi

# Expand pattern
if [[ "$PATTERN" == *"*"* ]]; then
  # Wildcard pattern
  ENTITIES=$(find "$BASE_PATH" -type f -path "*${PATTERN/\*/\*}*" | sort)
elif [[ "$PATTERN" == *","* ]]; then
  # Comma-separated list
  IFS=',' read -ra ENTITIES <<< "$PATTERN"
else
  # Single entity
  ENTITIES=("$PATTERN")
fi

# Validate entities exist
VALID_ENTITIES=()
for entity in "${ENTITIES[@]}"; do
  if [[ -e "$BASE_PATH/$entity" ]] || [[ -e "$entity" ]]; then
    VALID_ENTITIES+=("$entity")
  fi
done

# Output JSON
cat <<EOF
{
  "status": "success",
  "entities": [$(printf '"%s",' "${VALID_ENTITIES[@]}" | sed 's/,$//')]
  "count": ${#VALID_ENTITIES[@]},
  "parallelism_recommendation": $((${#VALID_ENTITIES[@]} < 5 ? ${#VALID_ENTITIES[@]} : 5)),
  "pattern_used": "$PATTERN"
}
EOF
```

## Usage by Core Claude Agent

After Director skill returns entity list, Core Claude Agent:

1. Receives entity list from Director skill
2. Invokes Manager agent for each entity in parallel (max 5 concurrent):
   ```
   Task(myproject-manager, entity="dataset/users")
   Task(myproject-manager, entity="dataset/orders")
   Task(myproject-manager, entity="dataset/products")
   ```
3. Waits for all to complete
4. Aggregates results
5. Returns to user
```

#### Step 3: Update Command Routing (Day 1)

**Old (invoked Director Agent):**
```markdown
**Batch:**
Invoke Agent: myproject-director
Pattern: {pattern}
```

**New (invoke Director Skill, Core Agent handles parallelism):**
```markdown
**Batch:**
1. Invoke Skill: myproject-director
   Operation: expand-pattern
   Pattern: {pattern}

2. Skill returns entity list

3. Core Claude Agent invokes myproject-manager agent for each (parallel)

4. Core Agent aggregates and returns results
```

#### Step 4: Test (Day 2)

**Test pattern expansion:**
```bash
# Test wildcard
Skill: myproject-director
Input: {operation: "expand-pattern", pattern: "dataset/*"}
Expected: List of all entities matching dataset/*

# Test comma-separated
Skill: myproject-director
Input: {operation: "expand-pattern", pattern: "a,b,c"}
Expected: ["a", "b", "c"]

# Test single entity
Skill: myproject-director
Input: {operation: "expand-pattern", pattern: "single"}
Expected: ["single"]
```

**Test parallel execution:**
```bash
# Batch operation should now be parallel
Command: /myproject-validate dataset/*

Observe:
- Director skill expands pattern quickly (< 1 second)
- Core Agent launches 5 Manager agents in parallel
- Wall-clock time is ~N/5 (5x speedup)
```

#### Step 5: Cleanup (Day 2)

```bash
# Archive old Director agent
mv .claude/agents/project/*director*.md .claude/archive/pre-migration-$(date +%Y%m%d)/

# Verify new Director skill in place
ls .claude/skills/myproject-director/
```

### Migration Validation

**Success Criteria:**
- ✅ Director is a skill in `.claude/skills/`
- ✅ Director only does pattern expansion (no orchestration)
- ✅ Pattern expansion script works for `*`, `domain/*`, `a,b,c`
- ✅ Core Agent invokes Managers in parallel
- ✅ Batch operations are 3-5x faster (wall-clock time)

---

## Migration 3: Agent Chains → Manager + Skills

⭐ **CRITICAL MIGRATION** - Most common for pre-skills projects

### When to Use This Migration

**Symptoms:**
- No `.claude/skills/` directory
- Workflow implemented as Agent1 → Agent2 → Agent3 → Agent4
- Each agent invokes next agent via Task tool
- Heavy context usage (4+ agents × 45K tokens each)
- No script abstraction

**Impact:** CRITICAL - Major architecture change

**Effort:** High (2-3 weeks)

### Step-by-Step Migration

#### Phase 1: Analysis (Days 1-3)

**Map the agent chain:**

```bash
# 1. Find all agents
ls -la .claude/agents/

# 2. Build dependency graph
for agent in .claude/agents/*.md; do
  echo "=== $agent ==="
  grep -n "Task tool" "$agent" || echo "No Task calls"
done

# 3. Identify chain start (entry point from command)
cat .claude/commands/*.md | grep -A5 "Invoke"
```

**Document chain structure:**

Example output:
```
Command: /myproject-process
  ↓
Agent: validate-input-agent.md
  → Invokes: transform-data-agent.md (line 145)

Agent: transform-data-agent.md
  → Invokes: save-results-agent.md (line 230)

Agent: save-results-agent.md
  → Invokes: notify-completion-agent.md (line 98)

Agent: notify-completion-agent.md
  → Returns final results
```

**Classify each agent:**

| Agent | Role | Should Become | Reason |
|-------|------|---------------|--------|
| validate-input-agent | Executor | Skill | Does validation work |
| transform-data-agent | Executor | Skill | Transforms data |
| save-results-agent | Executor | Skill | Saves files |
| notify-completion-agent | Executor | Skill | Sends notifications |
| (None found) | Orchestrator | Manager Agent | Need to create |

**Key Insight:** No orchestrator exists - orchestration is distributed across all agents!

**Identify deterministic logic for script extraction:**

```bash
# Find file operations
grep -rn "cp\|mv\|mkdir\|rm" .claude/agents/*.md

# Find data transformations
grep -rn "jq\|sed\|awk" .claude/agents/*.md

# Find API calls
grep -rn "curl\|wget\|aws\|gh" .claude/agents/*.md
```

Example findings:
- `validate-input-agent.md` lines 45-67: File validation → Extract to script
- `transform-data-agent.md` lines 23-89: jq transformations → Extract to script
- `save-results-agent.md` lines 12-34: File copy operations → Extract to script

#### Phase 2: Create Manager Agent (Days 4-6)

**Design Manager workflow:**

Based on agent chain analysis, design 7-phase workflow:

```markdown
Phase 1: INSPECT
  - Check if input files exist and are valid
  - Invoke: myproject-input-inspector skill

Phase 2: ANALYZE
  - If validation issues, analyze what's wrong
  - Invoke: myproject-input-debugger skill

Phase 3: PRESENT
  - Show user what will be transformed
  - Display input files, output plan

Phase 4: APPROVE
  - Get user confirmation to proceed
  - AskUserQuestion

Phase 5: EXECUTE
  - Invoke: myproject-data-transformer skill
  - Invoke: myproject-result-saver skill
  - Invoke: myproject-notifier skill

Phase 6: VERIFY
  - Re-invoke inspector to confirm output correct

Phase 7: REPORT
  - Comprehensive summary
```

**Create Manager agent:**

`.claude/agents/project/myproject-process-manager.md`

```markdown
---
name: myproject-process-manager
description: Orchestrates data processing workflow (validate → transform → save → notify)
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---

# MyProject Process Manager

<CONTEXT>
You orchestrate the complete data processing workflow for a single input dataset.

Original workflow (now consolidated):
- validate-input-agent → transform-data-agent → save-results-agent → notify-completion-agent

Now managed as single agent with 7 phases invoking specialist skills.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS validate input before transformation
2. ALWAYS get user approval before executing transformations
3. ALWAYS verify output after transformation
4. NEVER skip validation steps
</CRITICAL_RULES>

<WORKFLOW>

## Phase 1: INSPECT
Invoke: myproject-input-validator skill
Check: Input files exist, format correct, schema valid

## Phase 2: ANALYZE
If validation fails:
  Invoke: myproject-input-debugger skill
  Determine: What's wrong, can it be auto-fixed?

## Phase 3: PRESENT
Show user:
- Input files to process
- Transformation plan
- Expected output location
- Estimated processing time

## Phase 4: APPROVE
AskUserQuestion: "Proceed with data transformation?"
Options: Yes, No, Modify parameters

## Phase 5: EXECUTE
Invoke skills in sequence:
1. myproject-data-transformer: Apply transformations
2. myproject-result-saver: Save transformed data
3. myproject-notifier: Send completion notification

Track progress, handle errors

## Phase 6: VERIFY
Re-invoke: myproject-input-validator on OUTPUT
Confirm: Output has expected structure and content

## Phase 7: REPORT
Summary:
- Input processed: X files
- Transformations applied: Y operations
- Output saved: Z location
- Notifications sent: Recipients list

</WORKFLOW>

<AVAILABLE_SKILLS>
- myproject-input-validator: Check input/output data quality
- myproject-input-debugger: Analyze validation failures
- myproject-data-transformer: Apply transformations (script-backed)
- myproject-result-saver: Save results to storage (script-backed)
- myproject-notifier: Send notifications (script-backed)
</AVAILABLE_SKILLS>
```

#### Phase 3: Convert Agents to Skills (Days 7-12)

For each executor agent, create corresponding skill.

**Example: validate-input-agent → myproject-input-validator skill**

Old agent structure:
```
.claude/agents/validate-input-agent.md (450 lines)
- Contains validation logic
- Contains file operation code
- Invokes next agent in chain
```

New skill structure:
```
.claude/skills/myproject-input-validator/
├── SKILL.md (80 lines)
├── scripts/
│   ├── check-file-format.sh
│   ├── validate-schema.sh
│   └── check-completeness.sh
└── README.md
```

**Create skill:**

`.claude/skills/myproject-input-validator/SKILL.md`

```markdown
---
skill: myproject-input-validator
purpose: Validate input data files for processing
layer: Validator
---

# MyProject Input Validator

## Purpose
Validates input data files for format, schema, and completeness.

**Extracted from:** validate-input-agent.md (lines 1-450)

## Operations

### validate

Check input files for issues.

**Invocation:**
```json
{
  "operation": "validate",
  "input_path": "data/input",
  "checks": ["format", "schema", "completeness"]
}
```

**Implementation:**
```bash
# Run validation scripts
scripts/check-file-format.sh --input "$input_path"
scripts/validate-schema.sh --input "$input_path"
scripts/check-completeness.sh --input "$input_path"
```

**Output:**
```json
{
  "status": "success" | "failure",
  "valid": true | false,
  "issues": [
    {"type": "schema_error", "file": "data.csv", "details": "Missing column: id"}
  ],
  "checks_passed": 2,
  "checks_failed": 1
}
```

## Scripts

### check-file-format.sh

Extracted from validate-input-agent.md lines 45-67.

**Purpose:** Validate file format (CSV, JSON, etc.)

**Implementation:** `scripts/check-file-format.sh`

```bash
#!/bin/bash
# Validate file format
# Extracted from: validate-input-agent.md lines 45-67

set -euo pipefail

INPUT_PATH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --input) INPUT_PATH="$2"; shift 2;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

# Validate CSV format
for file in "$INPUT_PATH"/*.csv; do
  if ! head -1 "$file" | grep -q ","; then
    echo "Error: $file not valid CSV format"
    exit 1
  fi
done

echo "Format validation passed"
exit 0
```
```

**Repeat for remaining agents:**
- transform-data-agent → myproject-data-transformer skill
- save-results-agent → myproject-result-saver skill
- notify-completion-agent → myproject-notifier skill

#### Phase 4: Update Command Routing (Day 13)

**Old (invoked first agent in chain):**
```markdown
Command: /myproject-process
  ↓
Invoke Agent: validate-input-agent
```

**New (invoke Manager agent):**
```markdown
Command: /myproject-process
  ↓
Invoke Agent: myproject-process-manager
  Input: {input_path: "data/input"}
```

#### Phase 5: Cleanup & Validation (Days 14-15)

**Archive old agents:**
```bash
mkdir -p .claude/archive/agent-chain-$(date +%Y%m%d)
mv .claude/agents/validate-input-agent.md .claude/archive/agent-chain-$(date +%Y%m%d)/
mv .claude/agents/transform-data-agent.md .claude/archive/agent-chain-$(date +%Y%m%d)/
mv .claude/agents/save-results-agent.md .claude/archive/agent-chain-$(date +%Y%m%d)/
mv .claude/agents/notify-completion-agent.md .claude/archive/agent-chain-$(date +%Y%m%d)/
```

**Test end-to-end:**
```bash
# Run new workflow
Command: /myproject-process data/input

# Verify:
- Manager agent orchestrates properly
- All 7 phases execute
- Skills are invoked correctly
- Scripts run successfully
- User approval works
- Output is correct
```

**Parallel testing (1 week):**
- Run old workflow (from archive) and new workflow side-by-side
- Compare outputs
- Measure context reduction (should be 40-60% less)
- Measure wall-clock time (should be similar or faster)
- Collect user feedback on new approval flow

### Migration Validation

**Success Criteria:**
- ✅ Manager agent exists in `.claude/agents/project/`
- ✅ Manager has full tool access
- ✅ Manager implements 7-phase workflow
- ✅ Skills exist for each former executor agent
- ✅ Scripts contain deterministic logic (outside LLM context)
- ✅ Command routes to Manager (not first agent in chain)
- ✅ End-to-end workflow produces same outputs
- ✅ Context usage reduced by 40-60%
- ✅ User experience improved (natural approvals)

---

## Migration 4: Hybrid Agents → Separated Concerns

### When to Use This Migration

**Symptoms:**
- Agent does both orchestration AND execution
- Agent has `Task/Skill` tool calls (orchestration) AND `Bash/Read/Write` operations (execution)
- Violates single responsibility principle
- Hard to test and maintain

**Impact:** MEDIUM - Improves maintainability

**Effort:** Low-Medium (2-4 days)

### Step-by-Step Migration

**Identify hybrid pattern:**
```markdown
# Hybrid Agent (WRONG)
Agent: myproject-deployer.md

Phase 1: Check deployment status (EXECUTION - should be skill)
  - Run: bash commands to check infrastructure
  - Read: configuration files

Phase 2: Decide what to deploy (ORCHESTRATION - correct for agent)
  - Analyze results from Phase 1
  - AskUserQuestion for approval

Phase 3: Deploy (EXECUTION - should be skill)
  - Run: bash commands to deploy
  - Write: deployment logs

Phase 4: Verify (EXECUTION - should be skill)
  - Run: bash commands to check deployment
  - Read: logs
```

**Split into Manager + Skill:**

Manager Agent (orchestration only):
```markdown
Agent: myproject-deploy-manager.md

Phase 1: INSPECT
  Invoke skill: myproject-infrastructure-inspector

Phase 2: ANALYZE
  Analyze inspection results

Phase 3: PRESENT
  Show deployment plan to user

Phase 4: APPROVE
  AskUserQuestion: "Deploy to production?"

Phase 5: EXECUTE
  Invoke skill: myproject-deployer

Phase 6: VERIFY
  Invoke skill: myproject-infrastructure-inspector (re-check)

Phase 7: REPORT
  Summary of deployment
```

Execution Skill (deployment work):
```markdown
Skill: myproject-deployer

Operation: deploy

Implementation:
  scripts/deploy-infrastructure.sh
  scripts/run-healthchecks.sh
  scripts/update-deployment-logs.sh
```

---

## Migration 5: Script Extraction

### When to Use This Migration

**Symptoms:**
- Deterministic logic embedded in agent/skill prompts
- File operations (`cp`, `mv`, `mkdir`, `rm`) in prompts
- Data transformations (`jq`, `sed`, `awk`) in prompts
- API calls (`curl`, `aws cli`, `gh cli`) in prompts
- Heavy context usage

**Impact:** MEDIUM - Reduces context load

**Effort:** Low-Medium (varies by amount of logic)

### Common Extractions

#### Extract File Operations

**Before:**
```markdown
# In agent/skill prompt

Step 3: Setup output directory
```bash
mkdir -p output/data
mkdir -p output/logs
cp input/*.csv output/data/
chmod 644 output/data/*.csv
```

Copy all input files to output directory
```

**After:**
```markdown
# In skill SKILL.md

Step 3: Setup output directory
Invoke: scripts/setup-output-directory.sh --input input --output output
```

**Script:** `scripts/setup-output-directory.sh`
```bash
#!/bin/bash
set -euo pipefail

INPUT=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --input) INPUT="$2"; shift 2;;
    --output) OUTPUT="$2"; shift 2;;
  esac
done

mkdir -p "$OUTPUT/data"
mkdir -p "$OUTPUT/logs"
cp "$INPUT"/*.csv "$OUTPUT/data/"
chmod 644 "$OUTPUT/data"/*.csv

echo "Output directory setup complete"
```

**Context Savings:** ~120 tokens removed from prompt, script runs outside LLM

#### Extract Data Transformations

**Before:**
```markdown
# In agent/skill prompt

Step 2: Transform data
```bash
jq '.[] | {
  id: .user_id,
  name: .full_name,
  email: .email_address,
  created: .created_at
}' input.json > output.json
```
```

**After:**
```markdown
# In skill SKILL.md

Step 2: Transform data
Invoke: scripts/transform-user-data.sh --input input.json --output output.json
```

**Script:** `scripts/transform-user-data.sh`
```bash
#!/bin/bash
set -euo pipefail

INPUT=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --input) INPUT="$2"; shift 2;;
    --output) OUTPUT="$2"; shift 2;;
  esac
done

jq '.[] | {
  id: .user_id,
  name: .full_name,
  email: .email_address,
  created: .created_at
}' "$INPUT" > "$OUTPUT"

echo "Data transformation complete"
```

#### Extract API Calls

**Before:**
```markdown
# In agent/skill prompt

Step 4: Upload results
```bash
curl -X POST https://api.example.com/data \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d @output/results.json
```
```

**After:**
```markdown
# In skill SKILL.md

Step 4: Upload results
Invoke: scripts/upload-results.sh --file output/results.json --endpoint data
```

**Script:** `scripts/upload-results.sh`
```bash
#!/bin/bash
set -euo pipefail

FILE=""
ENDPOINT=""
API_TOKEN="${API_TOKEN:-}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --file) FILE="$2"; shift 2;;
    --endpoint) ENDPOINT="$2"; shift 2;;
  esac
done

if [[ -z "$API_TOKEN" ]]; then
  echo "Error: API_TOKEN environment variable required"
  exit 1
fi

curl -X POST "https://api.example.com/$ENDPOINT" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d @"$FILE" \
  -w "\nHTTP Status: %{http_code}\n"
```

---

## Testing & Validation

### Testing Strategy

**Unit Tests (Per Component):**
1. Test Manager agent phases independently
2. Test each skill operation in isolation
3. Test scripts with various inputs
4. Test error handling

**Integration Tests (End-to-End):**
1. Single entity workflow completion
2. Batch workflow with parallelism
3. Error scenarios (validation failures, execution errors)
4. State persistence across phases
5. User approval flows

**Performance Tests:**
1. Measure context load (before/after)
2. Measure wall-clock time (before/after)
3. Measure success rate
4. Measure user experience quality

### Validation Checklist

**Architecture:**
- [ ] Manager is AGENT in `.claude/agents/project/`
- [ ] Manager has `allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]`
- [ ] Director (if exists) is SKILL in `.claude/skills/`
- [ ] Specialists are SKILLS in `.claude/skills/`
- [ ] No agent chains (Agent → Agent via Task tool)
- [ ] No hybrid agents (orchestration + execution separated)

**Implementation:**
- [ ] Manager implements 7-phase workflow
- [ ] Manager maintains state in workflow-state.json
- [ ] Skills are script-backed (deterministic logic in scripts/)
- [ ] User approval uses AskUserQuestion naturally
- [ ] Error handling is comprehensive

**Performance:**
- [ ] Context usage reduced (or same for single ops)
- [ ] Batch operations use parallelism (5x faster)
- [ ] Success rate maintained or improved
- [ ] User experience improved

**Testing:**
- [ ] All original operations still work
- [ ] End-to-end workflows produce correct outputs
- [ ] Error scenarios handled gracefully
- [ ] Parallel testing shows parity or improvement

---

## Rollback Procedures

### If Migration Fails

**Immediate Rollback:**
```bash
# 1. Checkout backup branch
git checkout backup-before-migration-YYYYMMDD

# 2. Verify old implementation works
# Test commands, verify outputs

# 3. If verified, keep backup active
# Investigate migration issues before retrying
```

**Partial Rollback:**
```bash
# If only one component problematic, restore just that component
git checkout backup-before-migration-YYYYMMDD -- .claude/agents/project/myproject-manager.md
git checkout backup-before-migration-YYYYMMDD -- .claude/skills/problematic-skill/

# Test with partial rollback
# Fix issues, then re-migrate component
```

### Post-Migration Issues

**Issue: Context usage increased unexpectedly**

Diagnosis:
- Check if all deterministic logic extracted to scripts
- Verify skills aren't loading unnecessary context
- Review workflow files - split if needed

**Issue: Batch operations slower than expected**

Diagnosis:
- Verify Director is skill (not agent)
- Confirm Core Agent invoking Managers in parallel
- Check parallelism factor (should be 5 max)

**Issue: User approval flow confusing**

Diagnosis:
- Review AskUserQuestion prompts for clarity
- Ensure options are clear and distinct
- Add more context in PRESENT phase

---

## Summary

**Migration Priorities:**

1. **CRITICAL**: Agent Chains → Manager + Skills (if applicable)
2. **HIGH**: Manager-as-Skill → Manager-as-Agent (if applicable)
3. **MEDIUM**: Director-as-Agent → Director-as-Skill (if applicable)
4. **MEDIUM**: Hybrid Agents → Separated Concerns (if applicable)
5. **LOW**: Script Extraction (incremental, ongoing)

**Expected Timeline:**
- Simple migration (1 component): 1-2 days
- Medium migration (2-3 components): 1 week
- Complex migration (agent chains): 2-3 weeks

**Expected Improvements:**
- Context usage: 40-60% reduction (for agent chains)
- Batch operations: 3-5x faster (with parallelism)
- User experience: Significantly better (natural approvals)
- Maintainability: Much improved (clear separation)
- Success rate: Maintained or improved

**Success Factors:**
- Thorough analysis before migration
- Incremental approach (one component at a time)
- Parallel testing (old + new side-by-side)
- User feedback collection
- Metrics measurement (before/after)
