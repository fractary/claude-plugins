---
pattern: Pre-Skills Migration
category: Migration Strategy
difficulty: advanced
tags: [migration, legacy, agent-chains, refactoring, architecture]
version: 1.0
---

# Pattern: Pre-Skills Migration (Agent Chains → Manager + Skills)

## Intent

Migrate legacy "pre-skills" agent chain architectures (Agent1 → Agent2 → Agent3) to the modern Manager-as-Agent + Skills pattern, achieving 53% context reduction and eliminating chain complexity.

## Problem

Legacy projects built before the Skills abstraction used **agent chains** where agents invoked other agents sequentially:

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
```

**Problems with this architecture:**
- **Massive context load**: 4 agents × 45K tokens = 180K+ tokens
- **No state persistence**: Each agent starts fresh, must re-read context
- **No user interaction**: Cannot get approval mid-workflow
- **Sequential only**: Cannot parallelize independent steps
- **Fragile**: Single agent failure breaks entire chain
- **Hard to debug**: Error could be in any agent in chain
- **No rollback**: Cannot undo partial chain execution

## Solution

**Refactor to Manager-as-Agent + Skills architecture:**

```
Command: /myproject-process
  ↓
Manager Agent: myproject-process-manager.md
  - Orchestrates 7-phase workflow
  - Maintains state across all phases
  - Natural user interaction with AskUserQuestion
  ↓
  ├─ Skill: myproject-step1 (scripts/step1-logic.sh)
  ├─ Skill: myproject-step2 (scripts/step2-logic.sh)
  ├─ Skill: myproject-step3 (scripts/step3-logic.sh)
  └─ Skill: myproject-step4 (scripts/step4-logic.sh)

Context Load: 1 Manager + 4 Skills = ~85K tokens (53% reduction)
```

## Structure

### Before: Agent Chain Architecture

```markdown
# Old: step1-agent.md
<CONTEXT>
You perform step 1 of the workflow.
</CONTEXT>

<WORKFLOW>
1. Do step 1 work
2. Invoke step2-agent via Task tool
3. Wait for step2-agent result
4. Return combined result
</WORKFLOW>
```

**Problems:**
- ❌ Agent doing work directly (no script abstraction)
- ❌ Chaining via Task tool (context explosion)
- ❌ No state management
- ❌ No user approval workflow

### After: Manager + Skills Architecture

```markdown
---
name: myproject-process-manager
description: Orchestrates multi-step process workflow
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---

# MyProject Process Manager

<CONTEXT>
You orchestrate the complete process workflow for a **single entity**.
You maintain state and coordinate specialist skills.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS maintain workflow state in .myproject/state/{entity}/workflow-state.json
2. ALWAYS use skills for execution (never do work directly)
3. ALWAYS get user approval before making changes
4. ALWAYS verify after execution
5. NEVER proceed after failures without user decision
</CRITICAL_RULES>

<WORKFLOW>

## Phase 1: INSPECT
Invoke: myproject-inspector skill
Store: Current state in workflow state file

## Phase 2: ANALYZE
Invoke: myproject-analyzer skill
Store: Analysis results with recommendations

## Phase 3: PRESENT
Show user:
- Current state from Phase 1
- Analysis from Phase 2
- Proposed actions
- Risks and impacts

## Phase 4: APPROVE
Use AskUserQuestion:
- "Proceed with {operation} on {entity}?"
- Options: Proceed, Modify Plan, Cancel
Store: User decision in workflow state

## Phase 5: EXECUTE
Invoke skills sequentially:
1. myproject-step1 skill → Store result
2. myproject-step2 skill → Store result
3. myproject-step3 skill → Store result
4. myproject-step4 skill → Store result

Track: Progress in workflow state
Handle: Errors gracefully with user decision

## Phase 6: VERIFY
Re-invoke: myproject-inspector skill
Compare: Phase 1 (before) vs Phase 6 (after)
Validate: Changes applied correctly

## Phase 7: REPORT
Show:
- Before/after state comparison
- All steps completed
- Any warnings or issues
- Next recommended actions

</WORKFLOW>

<STATE_MANAGEMENT>
File: .myproject/state/{entity}/workflow-state.json

Structure:
{
  "entity": "entity-name",
  "operation": "process",
  "workflow_phase": "verify",
  "phases_completed": ["inspect", "analyze", "present", "approve", "execute"],
  "started_at": "2025-01-15T10:30:00Z",
  "inspection_results": {...},
  "analysis_results": {...},
  "user_approval": {"decision": "proceed", "timestamp": "..."},
  "execution_results": {
    "step1": {...},
    "step2": {...},
    "step3": {...},
    "step4": {...}
  },
  "verification_results": {...}
}
</STATE_MANAGEMENT>

<AVAILABLE_SKILLS>
- myproject-inspector: Observe current state (facts only)
- myproject-analyzer: Analyze issues and recommend fixes
- myproject-step1: Execute step 1 logic
- myproject-step2: Execute step 2 logic
- myproject-step3: Execute step 3 logic
- myproject-step4: Execute step 4 logic
</AVAILABLE_SKILLS>

<ERROR_HANDLING>
If skill invocation fails:
1. Store error in workflow state
2. Present error to user with context
3. AskUserQuestion: "How to proceed?"
   - Retry
   - Skip step
   - Manual intervention
   - Abort workflow
4. NEVER proceed without user decision
</ERROR_HANDLING>
```

**Benefits:**
- ✅ Single Manager orchestrates entire workflow
- ✅ Persistent state across all phases
- ✅ Natural user approval workflow
- ✅ Skills abstract execution logic
- ✅ Scripts extract deterministic operations
- ✅ 53% context reduction (180K → 85K tokens)

## Applicability

Use this migration when:
- ✅ Legacy project uses agent chains (Agent1 → Agent2 → Agent3)
- ✅ 4+ agents in chain (high context load)
- ✅ No user approval workflow currently
- ✅ No state persistence across steps
- ✅ Want to modernize architecture
- ✅ Need better error handling and recovery

Don't migrate when:
- ❌ Single agent doing simple task (no chain)
- ❌ Already using Skills abstraction
- ❌ Chain is actually parallel workflow (different pattern)

## Consequences

**Benefits:**
- ✅ **53% context reduction**: 180K → 85K tokens (4-agent chain example)
- ✅ **Persistent state**: All phases share state via workflow-state.json
- ✅ **User control**: Natural approval workflows with AskUserQuestion
- ✅ **Better error handling**: Single point of failure handling
- ✅ **Easier debugging**: All logic in one Manager + clear skill boundaries
- ✅ **Scriptable logic**: Deterministic operations in scripts
- ✅ **Parallel-ready**: Can invoke independent skills in parallel

**Migration Cost:**
- ⚠️ **15-day migration** for typical 4-agent chain
- ⚠️ **Requires understanding** of current agent responsibilities
- ⚠️ **Must extract scripts** from agent logic
- ⚠️ **State schema design** needed

**Trade-offs:**
- 📊 More upfront design (state schema, workflow phases)
- 📊 Initial time investment pays off in maintainability
- 📊 Testing changes (test Manager + Skills, not agent chains)

## Implementation

### Step 1: Analyze Current Agent Chain (2 days)

**Identify chain structure:**

```bash
# Find all agents in project
ls .claude/agents/project/*.md

# For each agent, identify:
# - What work it does
# - What data it reads
# - What data it passes to next agent
# - What decisions it makes
```

**Document chain flow:**

```markdown
# Agent Chain Analysis

## Current Chain
1. step1-agent.md
   - Reads: config.json
   - Does: Validation
   - Passes: validation_results
   - Next: step2-agent

2. step2-agent.md
   - Reads: validation_results (from step1)
   - Does: Processing
   - Passes: processed_data
   - Next: step3-agent

3. step3-agent.md
   - Reads: processed_data (from step2)
   - Does: Storage
   - Passes: storage_results
   - Next: step4-agent

4. step4-agent.md
   - Reads: storage_results (from step3)
   - Does: Reporting
   - Returns: final_report

## Context Load
- step1-agent: 45K tokens
- step2-agent: 45K tokens
- step3-agent: 45K tokens
- step4-agent: 45K tokens
- **Total: 180K tokens**

## State Flow
- No persistent state
- Each agent re-reads context
- Data passed via Task tool results

## User Interaction
- None (fully autonomous)
- No approval workflow
- No error recovery
```

### Step 2: Design Target Architecture (3 days)

**Design Manager workflow:**

```markdown
# Target Architecture Design

## Manager Agent
Name: myproject-process-manager.md
Tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]

## 7-Phase Workflow

Phase 1: INSPECT
- Skill: myproject-inspector
- Checks: Configuration valid, dependencies available
- Stores: inspection_results

Phase 2: ANALYZE
- Skill: myproject-analyzer
- Analyzes: Issues found in Phase 1
- Stores: analysis_results with recommendations

Phase 3: PRESENT
- Shows user: Current state, issues, proposed fixes
- No skill invocation

Phase 4: APPROVE
- AskUserQuestion: "Proceed with processing {entity}?"
- Stores: user_approval

Phase 5: EXECUTE
- Skill 1: myproject-validator (was step1-agent)
- Skill 2: myproject-processor (was step2-agent)
- Skill 3: myproject-storer (was step3-agent)
- Skill 4: myproject-reporter (was step4-agent)
- Stores: execution_results for each

Phase 6: VERIFY
- Re-invoke: myproject-inspector
- Compare: Phase 1 vs Phase 6 state
- Stores: verification_results

Phase 7: REPORT
- Show: Before/after comparison, all steps completed

## State Schema
File: .myproject/state/{entity}/workflow-state.json

{
  "entity": "entity-name",
  "operation": "process",
  "workflow_phase": "current-phase",
  "phases_completed": ["inspect", "analyze", ...],
  "started_at": "timestamp",
  "inspection_results": {...},
  "analysis_results": {...},
  "user_approval": {...},
  "execution_results": {
    "validation": {...},
    "processing": {...},
    "storage": {...},
    "reporting": {...}
  },
  "verification_results": {...}
}

## Skills to Create
1. myproject-inspector (observer)
2. myproject-analyzer (analyzer)
3. myproject-validator (executor - from step1-agent)
4. myproject-processor (executor - from step2-agent)
5. myproject-storer (executor - from step3-agent)
6. myproject-reporter (executor - from step4-agent)

## Context Load Estimate
- Manager: 45K tokens
- 6 Skills: 6 × 5K = 30K tokens
- Scripts: 0K (executed outside LLM context)
- **Total: ~75K tokens (58% reduction)**
```

### Step 3: Extract Logic to Scripts (5 days)

**For each agent, extract deterministic logic:**

**Example: step1-agent.md doing validation**

```markdown
# Old: step1-agent.md
<WORKFLOW>
1. Read config.json
2. Check required fields exist
3. Validate field formats
4. Return validation results
</WORKFLOW>
```

**Extract to script:**

```bash
#!/bin/bash
# scripts/validate-config.sh
set -euo pipefail

CONFIG_FILE="$1"
ENTITY="$2"

# Check file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "{\"status\": \"error\", \"message\": \"Config file not found\"}"
  exit 1
fi

# Validate required fields
REQUIRED_FIELDS=("name" "type" "connection_string")
MISSING=()

for field in "${REQUIRED_FIELDS[@]}"; do
  if ! jq -e ".${field}" "$CONFIG_FILE" > /dev/null 2>&1; then
    MISSING+=("$field")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  MISSING_JSON=$(printf ',"%s"' "${MISSING[@]}")
  MISSING_JSON="[${MISSING_JSON:1}]"
  echo "{\"status\": \"issues_found\", \"missing_fields\": $MISSING_JSON}"
  exit 0
fi

# All validations passed
echo "{\"status\": \"success\", \"message\": \"All validations passed\"}"
```

**New skill using script:**

```markdown
---
skill: myproject-validator
purpose: Validate entity configuration
layer: Executor
---

# MyProject Validator

<CONTEXT>
Validate entity configuration using deterministic checks.
</CONTEXT>

<OPERATIONS>

## validate

Validate configuration file for entity.

**Input:**
- entity: Entity name
- config_file: Path to config.json

**Process:**
1. Execute: scripts/validate-config.sh
2. Parse JSON result
3. Return validation results

**Output:**
{
  "status": "success" | "issues_found" | "error",
  "missing_fields": [...],
  "message": "..."
}

</OPERATIONS>

<CRITICAL_RULES>
1. ALWAYS use scripts/validate-config.sh (never inline logic)
2. ALWAYS return structured JSON output
3. NEVER modify configuration (read-only)
</CRITICAL_RULES>
```

**Repeat for all agents in chain.**

### Step 4: Create Manager Agent (3 days)

```bash
# Create Manager agent file
mkdir -p .claude/agents/project
cat > .claude/agents/project/myproject-process-manager.md <<'EOF'
---
name: myproject-process-manager
description: Orchestrates multi-step process workflow
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---

# MyProject Process Manager

<CONTEXT>
You orchestrate the complete process workflow for a **single entity**.
You maintain state and coordinate specialist skills.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS maintain workflow state in .myproject/state/{entity}/workflow-state.json
2. ALWAYS use skills for execution (never do work directly)
3. ALWAYS get user approval before making changes
4. ALWAYS verify after execution
5. NEVER proceed after failures without user decision
</CRITICAL_RULES>

<WORKFLOW>
[Include full 7-phase workflow from design]
</WORKFLOW>

<STATE_MANAGEMENT>
[Include state schema and operations]
</STATE_MANAGEMENT>

<AVAILABLE_SKILLS>
- myproject-inspector
- myproject-analyzer
- myproject-validator
- myproject-processor
- myproject-storer
- myproject-reporter
</AVAILABLE_SKILLS>

<ERROR_HANDLING>
[Include error handling procedures]
</ERROR_HANDLING>
EOF
```

### Step 5: Update Command Routing (1 day)

```markdown
# Old: /myproject-process command

Immediately invokes: step1-agent.md via Task tool

# New: /myproject-process command

Immediately invokes: myproject-process-manager agent

**Examples:**

```bash
# Single entity
/myproject-process dataset-name

# Batch (with Director Skill)
/myproject-process dataset/*
```

The Manager handles single-entity workflows.
For batch operations, add Director Skill (separate pattern).
```

### Step 6: Testing (1 day)

**Test each component:**

```bash
# Test scripts independently
bash scripts/validate-config.sh config.json test-entity

# Test skills via Skill tool
Skill: myproject-validator
Input: {entity: "test-entity", config_file: "config.json"}

# Test Manager workflow
/myproject-process test-entity

# Verify state management
cat .myproject/state/test-entity/workflow-state.json
```

**Validation checklist:**
- ✅ All scripts return structured JSON
- ✅ Skills invoke scripts correctly
- ✅ Manager maintains state across phases
- ✅ User approval workflow works
- ✅ Verify phase compares before/after state
- ✅ Error handling prompts user decisions
- ✅ Context load reduced by 50%+

## Examples

### Example 1: 4-Agent Chain (Lake.Corthonomy.AI)

**Before:**
```
/corthonomy-catalog → catalog-fetcher-agent
  ↓
catalog-analyzer-agent
  ↓
catalog-validator-agent
  ↓
catalog-reporter-agent

Context: 4 × 45K = 180K tokens
```

**After:**
```
/corthonomy-catalog → corthonomy-catalog-manager (Agent)
  ├─ corthonomy-inspector (Skill)
  ├─ corthonomy-debugger (Skill)
  ├─ corthonomy-catalog-builder (Skill)
  └─ corthonomy-reporter (Skill)

Context: 1 × 45K + 4 × 5K = 65K tokens (64% reduction)
```

**Results:**
- Context reduction: 64% (180K → 65K)
- User approval: Added (didn't exist before)
- State persistence: Added (didn't exist before)
- Error recovery: Improved (user decision at each failure)

### Example 2: 6-Agent Chain (Infrastructure Deployment)

**Before:**
```
/deploy → env-checker-agent
  ↓
dependency-resolver-agent
  ↓
build-agent
  ↓
test-agent
  ↓
deploy-agent
  ↓
verify-agent

Context: 6 × 45K = 270K tokens
```

**After:**
```
/deploy → deployment-manager (Agent)
  ├─ infra-inspector (Skill)
  ├─ dependency-resolver (Skill)
  ├─ builder (Skill)
  ├─ tester (Skill)
  ├─ deployer (Skill)
  └─ verifier (Skill)

Context: 1 × 45K + 6 × 5K = 75K tokens (72% reduction)
```

**Results:**
- Context reduction: 72% (270K → 75K)
- Deployment approval: Added (critical for production)
- Rollback capability: Added (state tracking enables rollback)
- Parallel testing: Enabled (Manager can invoke tests in parallel)

## Related Patterns

- **Manager-as-Agent**: Core pattern for single-entity workflows
- **Director-as-Skill**: For batch operations (wildcards, comma-separated)
- **Builder/Debugger**: Separation of concerns within skills
- **7-Phase Workflow**: Standard workflow pattern for Managers

## Common Mistakes

### Mistake 1: Converting Agent Chain to Skill Chain

**Wrong:**
```
Manager → Skill1 (invokes Skill2) → Skill2 (invokes Skill3) → Skill3
```

**Why wrong:** Still a chain, same problems

**Right:**
```
Manager orchestrates all skills directly:
  ├─ Skill1
  ├─ Skill2
  └─ Skill3
```

### Mistake 2: Keeping Logic in Manager

**Wrong:**
```markdown
<WORKFLOW>
## Phase 5: EXECUTE
1. Read config.json
2. Validate fields (do validation directly)
3. Process data (do processing directly)
</WORKFLOW>
```

**Why wrong:** Manager doing work instead of delegating to skills

**Right:**
```markdown
<WORKFLOW>
## Phase 5: EXECUTE
1. Invoke: myproject-validator skill
2. Invoke: myproject-processor skill
3. Store: Results in workflow state
</WORKFLOW>
```

### Mistake 3: No State Management

**Wrong:** Manager tracks nothing, re-invokes inspector every phase

**Right:** Manager maintains workflow-state.json, references inspection_results from Phase 1 in later phases

### Mistake 4: Skipping User Approval

**Wrong:** Manager auto-executes without user decision

**Right:** Manager ALWAYS gets user approval in Phase 4 before execution

## Testing

**Unit Tests:**
```bash
# Test each script independently
for script in scripts/*.sh; do
  echo "Testing $script..."
  bash "$script" test-input
done

# Test each skill independently
Skill: myproject-validator
Input: {entity: "test-entity"}
Expected: {status: "success"}
```

**Integration Tests:**
```bash
# Test full Manager workflow
/myproject-process test-entity

# Verify state created
test -f .myproject/state/test-entity/workflow-state.json

# Verify all phases completed
jq '.phases_completed' .myproject/state/test-entity/workflow-state.json
# Expected: ["inspect", "analyze", "present", "approve", "execute", "verify"]

# Verify state includes all results
jq 'keys' .myproject/state/test-entity/workflow-state.json
# Expected: entity, operation, workflow_phase, phases_completed, started_at,
#           inspection_results, analysis_results, user_approval,
#           execution_results, verification_results
```

**Context Load Tests:**
```bash
# Measure context before
echo "Old agent chain context load: [measure tokens]"

# Measure context after
echo "New Manager + Skills context load: [measure tokens]"

# Calculate reduction
echo "Reduction: [percentage]%"

# Target: 50-70% reduction
```

## Migration Timeline

**Typical 4-agent chain migration: 15 days**

- Day 1-2: Analyze current agent chain
- Day 3-5: Design target architecture (Manager, Skills, State)
- Day 6-10: Extract logic to scripts (1 day per agent)
- Day 11-13: Create Manager agent with 7-phase workflow
- Day 14: Update command routing
- Day 15: Testing and validation

**Larger chains (6+ agents): 20-25 days**

**Complexity factors:**
- More agents = more scripts to extract
- Complex state = more design time
- External dependencies = more testing needed

## Known Uses

- **Lake.Corthonomy.AI**: Migrated 4-agent catalog chain → Manager + Skills (64% context reduction)
- **Infrastructure projects**: Migrated 6-agent deployment chain → Manager + Skills (72% context reduction)
- **Legacy Claude Code projects**: Multiple pre-skills projects migrated with 50-70% context reduction

## Tags

`#migration` `#legacy` `#agent-chains` `#refactoring` `#manager-as-agent` `#context-optimization` `#pre-skills`
