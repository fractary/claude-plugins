# Migration Guide: Hybrid Agent Splitting → Manager-as-Agent + Skills

## Overview

**Anti-pattern**: Hybrid Agent (orchestration + execution mixed)
**Correct pattern**: Manager-as-Agent (orchestration only) + Skills (execution only)

This guide shows how to split hybrid agents into proper Manager-as-Agent architecture.

---

## The Problem: Hybrid Agents

### What is a Hybrid Agent?

A hybrid agent mixes orchestration logic with execution work:

```markdown
---
name: deployment-orchestrator
tools: Bash, Skill
---

## Workflow

### Phase 1: Build
1. Run bash: npm run build        # ❌ Agent doing execution
2. Check build output
3. If errors: fix and retry

### Phase 2: Test
1. Invoke test-runner skill       # ✓ Delegating (good)
2. Analyze test results           # ❌ Agent doing analysis

### Phase 3: Deploy
1. Run bash: terraform apply      # ❌ Agent doing execution
2. Run bash: kubectl apply        # ❌ Agent doing execution
3. Verify deployment
```

### Why is this an Anti-pattern?

**Mixed Responsibilities:**
- Agent unclear: Am I orchestrating or executing?
- Violates single responsibility principle
- Hard to test orchestration vs execution separately

**Context Pollution:**
- Execution details (bash commands, output parsing) in orchestration context
- Should be in skill scripts (0 context cost)

**Poor Separation of Concerns:**
- Orchestration: WHAT to do and WHEN
- Execution: HOW to do it
- Hybrid: Mixes both

**Maintenance Issues:**
- Changing execution logic requires changing orchestrator
- Can't reuse execution logic in other workflows
- Can't independently test execution steps

**Example Hybrid Agent:**

```markdown
---
name: code-builder
tools: Bash, Skill, Read, Write
---

<WORKFLOW>

## Phase 1: Lint Code
1. Read package.json
2. Run bash: npm run lint
3. Parse lint output
4. If errors > 0:
   a. Read error file
   b. For each error:
      - Analyze error type
      - Apply automatic fix
      - Write fixed file
5. Re-run lint to verify

## Phase 2: Build
1. Run bash: npm run build
2. Check dist/ directory exists
3. Count output files
4. Verify bundle size < 5MB

## Phase 3: Test
Use @skill-test-runner (delegates properly)

## Phase 4: Report
Generate build report
```

**Problems:**
- Phases 1-2: Agent doing all the work (should delegate to skills)
- Phase 3: Correctly delegating
- Mixed pattern creates confusion

---

## The Solution: Split into Manager + Skills

### Architecture

**Before (Hybrid):**
```
Hybrid Agent
├─ Orchestration logic
├─ Execution work (bash, read, write)
└─ Some skill delegation
```

**After (Clean Separation):**
```
Manager Agent (orchestration only)
├─ Skill: code-linter (execution)
├─ Skill: code-builder (execution)
├─ Skill: test-runner (execution)
└─ Skill: report-generator (execution)
```

### Conversion Steps

#### Step 1: Identify Execution vs Orchestration

**Orchestration (stays in Manager):**
- Workflow phase definitions
- State management
- User approval gates
- Error handling decisions
- Skill coordination
- Progress reporting

**Execution (moves to Skills):**
- Bash commands
- File operations (read, write, parse)
- Data transformations
- API calls
- Build operations
- Test execution

**Marking the Hybrid Agent:**

```markdown
## Phase 1: Lint Code
1. Read package.json                    # EXECUTION
2. Run bash: npm run lint               # EXECUTION
3. Parse lint output                    # EXECUTION
4. If errors > 0:                       # ORCHESTRATION
   a. Read error file                   # EXECUTION
   b. For each error:                   # ORCHESTRATION
      - Analyze error type              # EXECUTION
      - Apply automatic fix             # EXECUTION
      - Write fixed file                # EXECUTION
5. Re-run lint to verify                # EXECUTION
```

**Result**: 90% execution, 10% orchestration → needs split

#### Step 2: Extract Execution to Skills

Create skills for each execution concern:

**Skill 1: code-linter**

```markdown
---
skill: code-linter
purpose: Lint code and apply automatic fixes
---

<OPERATIONS>

## lint-code

Run linter and return results.

**Input:**
- `project_dir`: Project directory
- `auto_fix`: Whether to apply automatic fixes

**Process:**
1. Execute: `scripts/lint-code.sh "$project_dir" "$auto_fix"`
2. Parse lint results
3. Return lint report

**Output:**
```json
{
  "status": "success",
  "lint": {
    "error_count": 3,
    "warning_count": 5,
    "auto_fixed": 2,
    "remaining_errors": 1,
    "errors": [
      {
        "file": "src/index.js",
        "line": 45,
        "rule": "semi",
        "message": "Missing semicolon",
        "fixable": false
      }
    ]
  }
}
```

## fix-lint-errors

Apply fixes to lint errors.

**Input:**
- `project_dir`: Project directory
- `errors`: Array of errors to fix

**Process:**
1. Execute: `scripts/fix-lint-errors.sh "$project_dir" "$errors_json"`
2. Verify fixes applied
3. Return fix results
</OPERATIONS>
```

**scripts/lint-code.sh:**
```bash
#!/bin/bash
set -euo pipefail

PROJECT_DIR="${1:?Error: Project dir required}"
AUTO_FIX="${2:-false}"

cd "$PROJECT_DIR"

# Run linter
if [[ "$AUTO_FIX" == "true" ]]; then
  npm run lint -- --fix > /tmp/lint-output.txt 2>&1 || true
else
  npm run lint > /tmp/lint-output.txt 2>&1 || true
fi

# Parse results
ERROR_COUNT=$(grep -c "error" /tmp/lint-output.txt || echo "0")
WARNING_COUNT=$(grep -c "warning" /tmp/lint-output.txt || echo "0")

# Output JSON
cat <<EOF
{
  "status": "success",
  "lint": {
    "error_count": $ERROR_COUNT,
    "warning_count": $WARNING_COUNT,
    "output_file": "/tmp/lint-output.txt"
  }
}
EOF
```

**Skill 2: code-builder**

```markdown
---
skill: code-builder
purpose: Build code and verify output
---

<OPERATIONS>

## build-code

Build project and verify output.

**Input:**
- `project_dir`: Project directory
- `build_command`: Build command to run

**Process:**
1. Execute: `scripts/build-code.sh "$project_dir" "$build_command"`
2. Verify build artifacts
3. Return build report

**Output:**
```json
{
  "status": "success",
  "build": {
    "success": true,
    "build_time_seconds": 45,
    "output_dir": "dist",
    "file_count": 12,
    "total_size_bytes": 4523891,
    "artifacts": [
      {"file": "dist/bundle.js", "size": 2500000},
      {"file": "dist/bundle.css", "size": 150000}
    ]
  }
}
```
</OPERATIONS>
```

#### Step 3: Create Manager Agent (Orchestration Only)

**Manager delegates ALL execution:**

```markdown
---
name: code-builder-manager
description: Orchestrates code linting, building, testing, and reporting
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
model: inherit
---

<CONTEXT>
You are a Manager Agent orchestrating code build workflows.

You coordinate:
- Code linting (code-linter skill)
- Code building (code-builder skill)
- Test execution (test-runner skill)
- Report generation (report-generator skill)

You NEVER execute work directly - you delegate to skills.
</CONTEXT>

<CRITICAL_RULES>
1. **Orchestration Only**
   - NEVER run bash commands directly
   - NEVER read/write files directly
   - NEVER parse output directly
   - ALWAYS delegate execution to skills

2. **State Management**
   - YOU manage workflow state
   - YOU track phase completion
   - YOU handle errors and decide retry/abort

3. **User Interaction**
   - ALWAYS present lint/build/test results before proceeding
   - ALWAYS use AskUserQuestion for critical decisions
   - NEVER auto-proceed on errors without approval
</CRITICAL_RULES>

<WORKFLOW>

## Phase 1: LINT (Code Quality Check)

Use @skill-fractary-faber-agent:code-linter to lint code:

```json
{
  "operation": "lint-code",
  "parameters": {
    "project_dir": "{{PROJECT_DIR}}",
    "auto_fix": true
  }
}
```

Store result:
```json
{
  "state": {
    "phase": "lint",
    "lint": {
      "error_count": 3,
      "warning_count": 5,
      "auto_fixed": 2,
      "remaining_errors": 1
    }
  }
}
```

If remaining errors > 0:
- Proceed to Phase 2 (PRESENT)
- Get user approval to continue

If no errors:
- Skip to Phase 4 (BUILD)

## Phase 2: PRESENT (Show Lint Results)

Present lint results to user:

```
🔍 Lint Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Auto-fixed: 2 errors
⚠ Remaining errors: 1
  - src/index.js:45 - Missing semicolon (semi)

Total warnings: 5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Phase 3: APPROVE (Get User Decision)

Use AskUserQuestion:

```json
{
  "questions": [{
    "question": "Lint found 1 unfixable error. Proceed with build anyway?",
    "header": "Build",
    "multiSelect": false,
    "options": [
      {
        "label": "Yes, build anyway",
        "description": "Continue despite lint errors"
      },
      {
        "label": "No, fix errors first",
        "description": "Abort and fix lint errors manually"
      }
    ]
  }]
}
```

If user declines → ABORT workflow

## Phase 4: BUILD (Code Compilation)

Use @skill-fractary-faber-agent:code-builder to build:

```json
{
  "operation": "build-code",
  "parameters": {
    "project_dir": "{{PROJECT_DIR}}",
    "build_command": "npm run build"
  }
}
```

Store result:
```json
{
  "state": {
    "phase": "build",
    "build": {
      "success": true,
      "build_time_seconds": 45,
      "file_count": 12,
      "total_size_bytes": 4523891
    }
  }
}
```

If build fails → ABORT workflow

## Phase 5: TEST (Quality Verification)

Use @skill-fractary-faber-agent:test-runner to run tests:

```json
{
  "operation": "run-tests",
  "parameters": {
    "project_dir": "{{PROJECT_DIR}}",
    "test_command": "npm test"
  }
}
```

Store result:
```json
{
  "state": {
    "phase": "test",
    "test": {
      "passed": 45,
      "failed": 0,
      "skipped": 2,
      "coverage_percent": 87
    }
  }
}
```

If tests fail → Proceed to PRESENT/APPROVE for retry decision

## Phase 6: VERIFY (Final Checks)

Verify all phases completed successfully:
- ✓ Lint: errors resolved or approved
- ✓ Build: succeeded
- ✓ Test: all passed
- ✓ Artifacts: created and valid

## Phase 7: REPORT (Summary)

```
✅ COMPLETED: Code Build
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Lint: 2 auto-fixed, 1 approved error
Build: 45s, 12 files, 4.3MB
Test: 45 passed, 0 failed, 87% coverage
Artifacts: dist/ directory
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next: Deploy to staging
```

</WORKFLOW>
```

**Notice:**
- Manager has NO bash commands
- Manager has NO file operations
- Manager ONLY coordinates skills
- Manager ONLY manages state and decisions

---

## Complete Example: Before & After

### Before (Hybrid Agent)

```markdown
---
name: deployment-manager
tools: Bash, Skill, Read
---

## Phase 1: Build
1. Run bash: npm run build
2. Read dist/stats.json
3. Parse bundle size
4. If size > 5MB: warn user

## Phase 2: Deploy
1. Run bash: terraform apply
2. Parse terraform output
3. Extract resource IDs
4. Run bash: kubectl apply -f k8s/
5. Wait for pods ready
```

**Problems:**
- Manager doing all bash execution
- Manager parsing output
- Manager doing verification
- Mixed orchestration with execution

**Context cost**: ~15K tokens (bash commands, output parsing, logic)

### After (Manager + Skills)

**Manager Agent:**
```markdown
---
name: deployment-manager
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
---

## Phase 1: BUILD
Use @skill-code-builder

## Phase 2: VERIFY-BUILD
If bundle size > 5MB → PRESENT + APPROVE

## Phase 3: DEPLOY-INFRASTRUCTURE
Use @skill-infra-deployer

## Phase 4: DEPLOY-APPLICATION
Use @skill-app-deployer

## Phase 5: VERIFY-DEPLOYMENT
Use @skill-deployment-verifier

## Phase 6: REPORT
```

**Skill: code-builder**
```bash
scripts/build-code.sh:
  npm run build
  jq .size dist/stats.json
```

**Skill: infra-deployer**
```bash
scripts/deploy-terraform.sh:
  terraform apply -auto-approve
  terraform output -json
```

**Skill: app-deployer**
```bash
scripts/deploy-k8s.sh:
  kubectl apply -f k8s/
  kubectl wait --for=condition=ready pod -l app=myapp
```

**Context cost**:
- Manager: ~5K tokens (orchestration only)
- Skills: ~2K tokens each (6K total)
- Scripts: 0 tokens (executed, not in context)
- **Total: ~11K tokens (27% reduction)**

---

## Splitting Decision Tree

```
Is the agent doing work directly?
├─ YES → Split required
│   ├─ Identify all execution steps
│   ├─ Group related execution into skills
│   ├─ Extract bash/read/write to skill scripts
│   └─ Manager delegates to skills
└─ NO → Agent is already clean (orchestration only)
    └─ Verify: Are all phases delegating to skills?
        ├─ YES → ✓ Compliant
        └─ NO → Some phases need skill extraction
```

### Quick Test: Is My Agent Hybrid?

Ask these questions:

1. **Does the agent use Bash tool?**
   - If YES: Are ALL bash commands for infrastructure (git, gh) or coordination?
   - If NO to above: HYBRID - extract to skills

2. **Does the agent use Read/Write tools?**
   - If YES: Are ALL reads for configuration/state management?
   - If NO: HYBRID - extract data operations to skills

3. **Does the agent parse output?**
   - If YES: HYBRID - skills should parse and return structured JSON

4. **Does the agent transform data?**
   - If YES: HYBRID - data transformation belongs in skills

5. **Does the agent make API calls?**
   - If YES: HYBRID - API operations belong in skills

**Example (Hybrid Agent):**
```markdown
## Phase 1
1. Run bash: curl -X POST https://api.example.com/deploy  # ❌ Hybrid
2. Read response.json                                      # ❌ Hybrid
3. Parse JSON and extract deploy_id                        # ❌ Hybrid
4. Store deploy_id in state                                # ✓ Orchestration
```

**Example (Clean Manager):**
```markdown
## Phase 1
Use @skill-api-deployer:
```json
{
  "operation": "trigger-deployment",
  "parameters": {"environment": "production"}
}
```

Store result:                                              # ✓ Orchestration
```json
{
  "state": {
    "deploy_id": "{{skill_result.deploy.id}}"
  }
}
```
```

---

## Migration Checklist

### Analysis

- [ ] Read through entire agent workflow
- [ ] Mark every line as ORCHESTRATION or EXECUTION
- [ ] Calculate execution percentage
  - If > 30%: Definitely hybrid (split required)
  - If 10-30%: Likely hybrid (review needed)
  - If < 10%: Probably clean (verify delegation)

### Extraction

- [ ] Group execution steps into logical skills
- [ ] For each skill:
  - [ ] Create skill file (skills/skill-name/SKILL.md)
  - [ ] Create scripts directory (skills/skill-name/scripts/)
  - [ ] Extract bash commands to scripts
  - [ ] Define operations with JSON input/output
  - [ ] Add error handling

### Manager Cleanup

- [ ] Remove all bash commands from Manager
- [ ] Remove all Read/Write operations (except config)
- [ ] Replace execution with skill invocations
- [ ] Add state management for skill results
- [ ] Add user approval gates

### Validation

- [ ] Run workflow-validator on Manager
- [ ] Verify Manager has 0 execution logic
- [ ] Verify all skills have scripts
- [ ] Test each skill independently
- [ ] Test complete workflow end-to-end

---

## Common Mistakes

### Mistake 1: Partial Split

**Wrong:**
```markdown
## Phase 1: BUILD
Use @skill-code-builder  # ✓ Delegating

## Phase 2: DEPLOY
1. Run bash: terraform apply  # ❌ Still doing execution
2. Parse output
```

**Correct:**
```markdown
## Phase 1: BUILD
Use @skill-code-builder  # ✓ Delegating

## Phase 2: DEPLOY
Use @skill-infra-deployer  # ✓ Also delegating
```

### Mistake 2: Skills Still Orchestrating

**Wrong (Skill):**
```markdown
## deploy

1. Deploy infrastructure
2. If deployment succeeds:  # ❌ Skill making decisions
   a. Deploy application
3. Else:
   a. Rollback
```

**Correct (Manager orchestrates):**
```markdown
## Phase 1: DEPLOY-INFRA
Use infra-deployer skill

If deployment failed:  # ✓ Manager makes decisions
  - ROLLBACK
  - ABORT

## Phase 2: DEPLOY-APP
Use app-deployer skill
```

### Mistake 3: Keeping Execution "For Efficiency"

**Temptation:**
```markdown
## Phase 1
# This is just one line, keep it in Manager for efficiency
Run bash: mkdir -p /tmp/build  # ❌ Still execution
```

**Principle:**
```markdown
## Phase 1
# ALL execution goes to skills, even one-liners
Use @skill-build-preparer:
```json
{"operation": "create-directories"}
```  # ✓ Consistent delegation
```

**Why?**
- One-liner today becomes multi-line tomorrow
- Inconsistent pattern creates confusion
- Skills are reusable, embedded bash is not

---

## Results

**Context Reduction**: 20-40% typical reduction
**Maintainability**: Execution logic isolated in testable skills
**Reusability**: Skills can be used in other workflows
**Clarity**: Clear separation of concerns

---

## Next Steps

After splitting hybrid agents:

1. Run `/fractary-faber-agent:audit` to find other hybrids
2. Review [Script Extraction](script-extraction.md) guide for script best practices
3. Review [Agent Chain Migration](agent-chain-to-skills.md) if agent chains exist
4. Test each skill independently
5. Update workflow documentation
