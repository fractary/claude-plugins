# Migration Guide: Agent Chains → Manager-as-Agent + Skills

## Overview

**Anti-pattern**: Sequential agent invocations (Agent Chain)
**Correct pattern**: Manager-as-Agent orchestrating Skills

This guide shows how to convert agent chains into the Manager-as-Agent pattern.

---

## The Problem: Agent Chains

### What is an Agent Chain?

An agent chain is when one agent invokes another agent sequentially:

```markdown
## Agent A
1. Do work A
2. Invoke Agent B with results
3. Wait for Agent B completion

## Agent B
1. Receive results from Agent A
2. Do work B
3. Invoke Agent C with results

## Agent C
1. Receive results from Agent B
2. Do work C
3. Return final results
```

### Why is this an Anti-pattern?

**Context Accumulation:**
- Agent A context: ~10K tokens
- Agent B context: Agent A context + 10K = ~20K tokens
- Agent C context: A + B + 10K = ~30K tokens
- **Total: 60K tokens** for work that could be 15K

**State Management Issues:**
- Each agent needs previous agent's state
- Error recovery is complex
- Rollback requires coordinating multiple agents

**Ownership Confusion:**
- Who owns the workflow?
- Where is state persisted?
- Which agent handles errors?

**Example Anti-pattern:**

```markdown
---
name: data-fetcher
tools: Bash, Skill
---

## Workflow
1. Fetch data from API
2. Invoke @agent-data-validator to validate
3. Wait for validation results
4. If valid: Invoke @agent-data-processor
5. Return final results
```

---

## The Solution: Manager-as-Agent + Skills

### Architecture

```
Manager Agent (orchestrator)
├─ Skill 1 (data-fetcher)
├─ Skill 2 (data-validator)
└─ Skill 3 (data-processor)
```

**Single context**: Manager + all skills = ~15K tokens (not 60K)

### Conversion Steps

#### Step 1: Identify the Orchestrator

**Question**: Which agent owns the complete workflow?

In the example:
- `data-fetcher` starts the workflow
- Invokes `data-validator`
- Then invokes `data-processor`

**Answer**: `data-fetcher` owns the workflow → becomes Manager Agent

#### Step 2: Convert Other Agents to Skills

Agents B and C become skills invoked by Manager:

**Before (Agent B):**
```markdown
---
name: data-validator
description: Validates data
tools: Bash, Read
---
```

**After (Skill):**
```markdown
---
skill: data-validator
purpose: Validate data structure and content
---

<OPERATIONS>

## validate-data

Validate data structure and content.

**Input:**
- `data_file`: Path to data file
- `schema_file`: Path to validation schema

**Process:**
1. Execute: `scripts/validate-data.sh "$data_file" "$schema_file"`
2. Parse validation results
3. Return validation report

**Output:**
```json
{
  "status": "success",
  "validation": {
    "valid": true,
    "errors": [],
    "warnings": [],
    "record_count": 1000
  }
}
```
</OPERATIONS>
```

#### Step 3: Create Manager Agent

The orchestrator becomes a Manager Agent with full tool access:

```markdown
---
name: data-processor-manager
description: Orchestrates data fetching, validation, and processing
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
model: inherit
---

<CONTEXT>
You are a Manager Agent orchestrating data processing workflows.

You coordinate:
- Data fetching (data-fetcher skill)
- Data validation (data-validator skill)
- Data processing (data-processor skill)
</CONTEXT>

<CRITICAL_RULES>
1. **Full Orchestration**
   - YOU own the complete workflow
   - YOU manage state across phases
   - YOU handle errors and rollback

2. **Delegate Execution**
   - NEVER do work directly
   - ALWAYS invoke skills for execution
   - Skills return results to YOU

3. **User Approval**
   - ALWAYS present validation results before processing
   - ALWAYS use AskUserQuestion for decisions
   - NEVER proceed without approval on critical steps
</CRITICAL_RULES>

<WORKFLOW>

## Phase 1: FETCH (Data Retrieval)

Use @skill-fractary-faber-agent:data-fetcher to fetch data:

```json
{
  "operation": "fetch-data",
  "parameters": {
    "api_endpoint": "{{API_ENDPOINT}}",
    "output_file": "/tmp/data-{{TIMESTAMP}}.json"
  }
}
```

Store result:
```json
{
  "state": {
    "phase": "fetch",
    "data_file": "/tmp/data-2025-01-11.json",
    "record_count": 1000,
    "timestamp": "2025-01-11T16:30:00Z"
  }
}
```

## Phase 2: VALIDATE (Data Validation)

Use @skill-fractary-faber-agent:data-validator to validate:

```json
{
  "operation": "validate-data",
  "parameters": {
    "data_file": "{{state.data_file}}",
    "schema_file": "schemas/data-schema.json"
  }
}
```

Store result:
```json
{
  "state": {
    "phase": "validate",
    "validation": {
      "valid": true,
      "errors": [],
      "warnings": ["missing optional field: metadata"]
    }
  }
}
```

## Phase 3: PRESENT (Show Results)

Present validation results to user:

```
📊 Data Validation Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Valid: true
✓ Records: 1000
⚠ Warnings: 1
  - Missing optional field: metadata

Errors: None
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Phase 4: APPROVE (Get User Decision)

Use AskUserQuestion:

```json
{
  "questions": [{
    "question": "Data validation complete with 1 warning. Proceed with processing?",
    "header": "Process data",
    "multiSelect": false,
    "options": [
      {
        "label": "Yes, process data",
        "description": "Continue to data processing phase"
      },
      {
        "label": "No, fix warnings first",
        "description": "Abort and address warnings"
      }
    ]
  }]
}
```

## Phase 5: PROCESS (Data Processing)

If approved, use @skill-fractary-faber-agent:data-processor:

```json
{
  "operation": "process-data",
  "parameters": {
    "data_file": "{{state.data_file}}",
    "output_dir": "/output/processed/",
    "processing_options": {
      "normalize": true,
      "deduplicate": true
    }
  }
}
```

Store result:
```json
{
  "state": {
    "phase": "process",
    "processing": {
      "input_records": 1000,
      "output_records": 985,
      "duplicates_removed": 15,
      "output_file": "/output/processed/data-2025-01-11.json"
    }
  }
}
```

## Phase 6: VERIFY (Validation Check)

Verify processing results:

1. Check output file exists
2. Validate output record count
3. Run integrity checks

## Phase 7: REPORT (Summary)

```
✅ COMPLETED: Data Processing
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fetch: 1000 records retrieved
Validate: 1 warning (non-blocking)
Process: 985 records (15 duplicates removed)
Output: /output/processed/data-2025-01-11.json
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

</WORKFLOW>

</CONTEXT>
```

#### Step 4: Extract Scripts to Skills

Move deterministic operations to skills:

**Manager Agent (before):**
```markdown
## Phase 1: Fetch Data
1. Use Bash: curl -X GET {{API_ENDPOINT}} > /tmp/data.json
2. Parse JSON response
3. Count records
```

**Skill (after):**
```markdown
## fetch-data

**Process:**
1. Execute: `scripts/fetch-api-data.sh "{{API_ENDPOINT}}" "{{OUTPUT_FILE}}"`
2. Parse script output
3. Return fetch results
```

**scripts/fetch-api-data.sh:**
```bash
#!/bin/bash
set -euo pipefail

API_ENDPOINT="${1:?Error: API endpoint required}"
OUTPUT_FILE="${2:?Error: Output file required}"

# Fetch data
curl -X GET "$API_ENDPOINT" \
  -H "Accept: application/json" \
  -o "$OUTPUT_FILE" \
  --fail --silent --show-error

# Count records
RECORD_COUNT=$(jq '. | length' "$OUTPUT_FILE")

# Output JSON
cat <<EOF
{
  "status": "success",
  "fetch": {
    "output_file": "$OUTPUT_FILE",
    "record_count": $RECORD_COUNT,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
```

---

## Complete Example: Before & After

### Before (Agent Chain - 60K tokens)

```
Agent A (data-fetcher) - 10K tokens
  ├─ Fetch data
  ├─ Invoke Agent B
  └─ Wait
      └─ Agent B (data-validator) - 10K + A's context = 20K
          ├─ Validate data
          ├─ Invoke Agent C
          └─ Wait
              └─ Agent C (data-processor) - 10K + A + B = 30K
                  ├─ Process data
                  └─ Return

Total context: 60K tokens
Total agents: 3
Coordination: Complex
```

### After (Manager + Skills - 15K tokens)

```
Manager Agent (data-processor-manager) - 8K tokens
  ├─ Phase 1: Skill (data-fetcher) - 2K
  ├─ Phase 2: Skill (data-validator) - 2K
  ├─ Phase 3: Present results
  ├─ Phase 4: Get approval
  ├─ Phase 5: Skill (data-processor) - 3K
  ├─ Phase 6: Verify
  └─ Phase 7: Report

Total context: ~15K tokens (60% reduction)
Total agents: 1 Manager
Skills: 3 (invoked, not chained)
Coordination: Centralized in Manager
```

---

## Migration Checklist

### Pre-Migration

- [ ] Identify all agents in the chain
- [ ] Determine which agent owns the workflow (becomes Manager)
- [ ] Map data flow between agents
- [ ] Identify user approval points
- [ ] Document state transitions

### Conversion

- [ ] Create Manager Agent with full tools
- [ ] Convert non-orchestrator agents to Skills
- [ ] Extract bash operations to skill scripts
- [ ] Add <WORKFLOW> with 7-phase structure
- [ ] Add state management in Manager
- [ ] Add user approval with AskUserQuestion

### Validation

- [ ] Run workflow-validator on Manager
- [ ] Verify Manager is in agents/ directory
- [ ] Verify Manager has all 7 tools
- [ ] Verify Skills are in skills/ directory
- [ ] Verify Skills have scripts/ directory
- [ ] Test complete workflow end-to-end

### Testing

- [ ] Test successful path (all phases complete)
- [ ] Test error handling (validation fails)
- [ ] Test user cancellation (approval declined)
- [ ] Test rollback scenarios
- [ ] Verify state persistence across phases

---

## Common Mistakes

### Mistake 1: Converting Orchestrator to Skill

**Wrong:**
```markdown
---
skill: data-processor-manager  # ❌ Orchestrator as Skill
---
```

**Correct:**
```markdown
---
name: data-processor-manager   # ✓ Orchestrator as Agent
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
---
```

### Mistake 2: Keeping Agent Chain Logic

**Wrong:**
```markdown
## Phase 5: Process
1. Invoke @agent-data-processor  # ❌ Still invoking agents
2. Wait for completion
```

**Correct:**
```markdown
## Phase 5: Process
Use @skill-fractary-faber-agent:data-processor:  # ✓ Invoke skill

```json
{
  "operation": "process-data",
  "parameters": {...}
}
```
```

### Mistake 3: Skills with Orchestration Logic

**Wrong (Skill):**
```markdown
## process-data

1. Validate input
2. If invalid: Invoke validator skill  # ❌ Skill orchestrating
3. Process data
4. Invoke reporting skill
```

**Correct (Skill):**
```markdown
## process-data

1. Execute: `scripts/process-data.sh`
2. Return processing results
```

**Correct (Manager orchestrates):**
```markdown
## Phase 2: VALIDATE
Use validator skill

## Phase 5: PROCESS
Use processor skill

## Phase 7: REPORT
Use reporting skill
```

---

## Results

**Context Reduction**: 55-60% typical reduction
**State Management**: Centralized in one Manager
**Error Handling**: Single point of coordination
**User Approval**: Clear approval gates
**Maintainability**: Each skill is independently testable

---

## Next Steps

After converting agent chains:

1. Run `/fractary-faber-agent:audit` to find other anti-patterns
2. Review [Hybrid Agent Splitting](hybrid-agent-splitting.md) guide
3. Review [Script Extraction](script-extraction.md) guide
4. Update tests for new Manager-as-Agent structure
5. Document workflow phases and state transitions
