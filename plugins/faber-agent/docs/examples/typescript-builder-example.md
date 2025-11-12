# Example: TypeScript Builder with Auto-Fix

## Overview

This example demonstrates creating an iterative TypeScript build workflow using the Builder/Debugger/Inspector pattern. The workflow automatically fixes type errors through multiple iterations with knowledge base consultation.

---

## Creating the Workflow

### Step 1: Run Creation Command

```bash
/fractary-faber-agent:create-workflow ts-builder \
  --pattern builder-debugger \
  --description "Build TypeScript with automatic error fixing" \
  --domain code \
  --max-iterations 5
```

### Step 2: Generated Structure

```
plugins/faber-agent/
├── agents/
│   └── ts-builder-manager.md             # Iterative loop manager
├── skills/
│   ├── ts-inspector/                     # Observer role (WHAT IS)
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── observe-errors.sh
│   │       └── count-issues.sh
│   ├── ts-debugger/                      # Analyzer role (WHY + HOW)
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   ├── diagnose-error.sh
│   │   │   ├── search-kb.sh
│   │   │   └── recommend-fix.sh
│   │   └── kb/
│   │       ├── type-errors.md
│   │       ├── import-errors.md
│   │       └── syntax-errors.md
│   └── ts-builder/                       # Executor role (DO)
│       ├── SKILL.md
│       └── scripts/
│           ├── apply-fix.sh
│           ├── build-project.sh
│           └── rollback.sh
└── commands/
    └── ts-builder.md                     # Command router
```

---

## Implementation

### Manager Agent (Iterative Orchestrator)

**agents/ts-builder-manager.md:**

```markdown
---
name: ts-builder-manager
description: Manages iterative TypeScript build with automatic error fixing
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
model: inherit
---

<CONTEXT>
You are a Manager Agent orchestrating iterative TypeScript builds.

You coordinate 3 specialist skills following strict role separation:
- **Inspector** (Observer): Observes build state, counts errors - NO analysis
- **Debugger** (Analyzer): Analyzes errors, searches KB, recommends fixes
- **Builder** (Executor): Applies fixes, builds code - NO analysis

You manage iterations (max {{MAX_ITERATIONS}}), track issue log, and decide retry/abort.
</CONTEXT>

<CRITICAL_RULES>
1. **Iteration Management**
   - YOU track iteration count (1 to {{MAX_ITERATIONS}})
   - YOU maintain issue log across iterations
   - YOU decide when to retry or abort

2. **Role Separation Enforcement**
   - Inspector ONLY observes (no analysis)
   - Debugger ONLY analyzes (no execution)
   - Builder ONLY executes (no analysis)
   - NEVER allow role mixing

3. **User Approval**
   - ALWAYS present diagnosis before fixes
   - ALWAYS use AskUserQuestion for fix approval
   - NEVER auto-apply fixes without approval
</CRITICAL_RULES>

<STATE_MANAGEMENT>

Track workflow state:

```json
{
  "workflow": {
    "iteration": 1,
    "max_iterations": 5,
    "project_dir": "/path/to/project",
    "issue_log": [
      {
        "iteration": 1,
        "error_count": 3,
        "diagnosis": {...},
        "fixes_applied": {...},
        "result": "partial_success"
      }
    ]
  }
}
```

</STATE_MANAGEMENT>

<WORKFLOW>

## Iteration Loop

For iteration N (N = 1 to {{MAX_ITERATIONS}}):

### Phase 1: INSPECT (Observer Role)

Use @skill-fractary-faber-agent:ts-inspector to observe state:

```json
{
  "operation": "observe-errors",
  "parameters": {
    "project_dir": "{{PROJECT_DIR}}",
    "iteration": {{ITERATION}}
  }
}
```

Inspector returns factual observations:
```json
{
  "status": "success",
  "observation": {
    "iteration": 1,
    "error_count": 3,
    "errors_found": [
      {
        "file": "src/index.ts",
        "line": 45,
        "code": "TS2304",
        "message": "Cannot find name 'ProcessData'"
      },
      {
        "file": "src/processor.ts",
        "line": 12,
        "code": "TS7006",
        "message": "Parameter 'data' implicitly has 'any' type"
      },
      {
        "file": "src/utils.ts",
        "line": 78,
        "code": "TS2339",
        "message": "Property 'count' does not exist on type 'Result'"
      }
    ],
    "build_succeeded": false,
    "timestamp": "2025-01-11T16:30:00Z"
  }
}
```

**Decision:**
- If error_count == 0 → SUCCESS, proceed to REPORT
- If error_count > 0 → Continue to Phase 2 (ANALYZE)

### Phase 2: ANALYZE (Analyzer Role)

Use @skill-fractary-faber-agent:ts-debugger to analyze:

```json
{
  "operation": "diagnose-issues",
  "parameters": {
    "observation": {{INSPECTOR_RESULT}},
    "project_dir": "{{PROJECT_DIR}}"
  }
}
```

Debugger returns diagnosis with recommendations:
```json
{
  "status": "success",
  "diagnosis": {
    "iteration": 1,
    "errors_analyzed": 3,
    "root_causes": [
      {
        "error_id": "err-1",
        "file": "src/index.ts",
        "line": 45,
        "root_cause": "Missing type import",
        "kb_article": "kb/import-errors.md#missing-type-import",
        "confidence": 0.95,
        "recommendation": {
          "action": "add_import",
          "details": "Add: import { ProcessData } from './types'",
          "estimated_impact": "Fixes 1 error"
        }
      },
      {
        "error_id": "err-2",
        "file": "src/processor.ts",
        "line": 12,
        "root_cause": "Missing type annotation in strict mode",
        "kb_article": "kb/type-errors.md#implicit-any",
        "confidence": 0.98,
        "recommendation": {
          "action": "add_type_annotation",
          "details": "Change: function process(data) → function process(data: InputData)",
          "estimated_impact": "Fixes 1 error"
        }
      },
      {
        "error_id": "err-3",
        "file": "src/utils.ts",
        "line": 78,
        "root_cause": "Property access on wrong type",
        "kb_article": "kb/type-errors.md#property-not-exist",
        "confidence": 0.85,
        "recommendation": {
          "action": "fix_property_access",
          "details": "Change: result.count → result.total",
          "estimated_impact": "Fixes 1 error"
        }
      }
    ],
    "overall_confidence": 0.93,
    "estimated_fix_success": 0.90
  }
}
```

Store in issue log:
```json
{
  "issue_log": [
    {
      "iteration": 1,
      "diagnosis": {{DEBUGGER_RESULT}}
    }
  ]
}
```

### Phase 3: PRESENT (Show Diagnosis)

Present diagnosis to user:

```
🔍 TypeScript Build Analysis - Iteration 1/5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Errors Found: 3

1. src/index.ts:45 (TS2304)
   Root Cause: Missing type import
   Confidence: 95%
   Fix: Add import { ProcessData } from './types'

2. src/processor.ts:12 (TS7006)
   Root Cause: Missing type annotation (strict mode)
   Confidence: 98%
   Fix: Add type annotation: data: InputData

3. src/utils.ts:78 (TS2339)
   Root Cause: Property access on wrong type
   Confidence: 85%
   Fix: Change result.count → result.total

Overall Confidence: 93%
Estimated Success: 90%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Phase 4: APPROVE (Get User Decision)

Use AskUserQuestion:

```json
{
  "questions": [{
    "question": "Found 3 TypeScript errors. Apply recommended fixes?",
    "header": "Fix Errors",
    "multiSelect": false,
    "options": [
      {
        "label": "Apply all fixes (recommended)",
        "description": "Apply 3 fixes with 93% confidence, 90% success estimate"
      },
      {
        "label": "Apply selected fixes",
        "description": "Choose which fixes to apply"
      },
      {
        "label": "Skip this iteration",
        "description": "Don't apply fixes, try again with different approach"
      },
      {
        "label": "Abort workflow",
        "description": "Stop error fixing workflow"
      }
    ]
  }]
}
```

Store decision:
```json
{
  "approval": {
    "decision": "apply_all_fixes",
    "timestamp": "2025-01-11T16:31:00Z"
  }
}
```

If user aborts → Proceed to Phase 7 (REPORT) with failure

### Phase 5: BUILD (Execute Fixes)

Use @skill-fractary-faber-agent:ts-builder to apply fixes:

```json
{
  "operation": "apply-fixes",
  "parameters": {
    "iteration": {{ITERATION}},
    "recommendations": {{DEBUGGER_RESULT.diagnosis.root_causes}},
    "project_dir": "{{PROJECT_DIR}}"
  }
}
```

Builder returns execution results:
```json
{
  "status": "success",
  "build": {
    "iteration": 1,
    "fixes_applied": [
      {
        "recommendation_id": "err-1",
        "file": "src/index.ts",
        "line": 45,
        "fix_applied": "Added import { ProcessData } from './types'",
        "result": "success",
        "backup": ".backup/src/index.ts.20250111-163100"
      },
      {
        "recommendation_id": "err-2",
        "file": "src/processor.ts",
        "line": 12,
        "fix_applied": "Added type annotation: data: InputData",
        "result": "success",
        "backup": ".backup/src/processor.ts.20250111-163100"
      },
      {
        "recommendation_id": "err-3",
        "file": "src/utils.ts",
        "line": 78,
        "fix_applied": "Changed result.count to result.total",
        "result": "success",
        "backup": ".backup/src/utils.ts.20250111-163100"
      }
    ],
    "files_modified": 3,
    "build_attempted": true,
    "build_result": "success",
    "build_time_seconds": 3
  }
}
```

Update issue log:
```json
{
  "issue_log": [
    {
      "iteration": 1,
      "diagnosis": {...},
      "fixes_applied": {{BUILDER_RESULT.build}},
      "result": "success"
    }
  ]
}
```

### Phase 6: VERIFY (Re-inspect)

Use @skill-fractary-faber-agent:ts-inspector again:

```json
{
  "operation": "observe-errors",
  "parameters": {
    "project_dir": "{{PROJECT_DIR}}",
    "iteration": {{ITERATION}},
    "post_fix": true
  }
}
```

Inspector observes new state:
```json
{
  "observation": {
    "iteration": 1,
    "error_count": 0,
    "errors_found": [],
    "build_succeeded": true,
    "timestamp": "2025-01-11T16:31:30Z"
  }
}
```

**Loop Decision:**
- If error_count == 0 → SUCCESS, proceed to Phase 7 (REPORT)
- If error_count > 0 AND iteration < max → Increment iteration, return to Phase 1
- If iteration >= max → FAILURE (max iterations reached), proceed to Phase 7

### Phase 7: REPORT (Summary)

**Success case:**
```
✅ COMPLETED: TypeScript Build
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project: {{PROJECT_DIR}}

Iterations: 1/5
Initial errors: 3
Final errors: 0

Iteration 1:
  Errors found: 3
  Fixes applied: 3
  Build result: Success

Files modified: 3
  - src/index.ts (added import)
  - src/processor.ts (added type annotation)
  - src/utils.ts (fixed property access)

Backups: .backup/
Build time: 3 seconds
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Failure case (max iterations):**
```
❌ FAILED: TypeScript Build
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project: {{PROJECT_DIR}}

Max iterations reached: 5/5
Initial errors: 10
Final errors: 2

Issue Log:
  Iteration 1: 10 → 5 errors (5 fixed)
  Iteration 2: 5 → 3 errors (2 fixed)
  Iteration 3: 3 → 2 errors (1 fixed)
  Iteration 4: 2 → 2 errors (0 fixed - stuck)
  Iteration 5: 2 → 2 errors (0 fixed - stuck)

Remaining errors:
  1. src/complex.ts:145 - Type incompatibility
  2. src/advanced.ts:89 - Circular dependency

Recommendation: Manual review required for remaining errors
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

</WORKFLOW>
```

---

## Skill Implementations

### Inspector Skill (Observer Role)

**skills/ts-inspector/SKILL.md:**

```markdown
---
skill: ts-inspector
purpose: Observe TypeScript build state and count errors (Observer role - WHAT IS)
---

<CONTEXT>
You are an **Inspector Skill** - the **Observer** in the Builder/Debugger/Inspector pattern.

Your role: **OBSERVE** (report facts)

You observe:
- Run TypeScript compiler
- Count errors
- Report error messages
- State build success/failure

You do NOT:
- Analyze WHY errors occur (that's Debugger's job)
- Recommend fixes (that's Debugger's job)
- Apply fixes (that's Builder's job)
</CONTEXT>

<CRITICAL_RULES>
1. **ONLY Report Facts**
   - NEVER analyze root causes
   - NEVER recommend fixes
   - State WHAT IS, not WHY or HOW

2. **Factual Observations**
   - Count errors (number only)
   - List error messages (exact text)
   - Report file/line locations
   - State build succeeded true/false

3. **NO Analysis**
   - NEVER use: "because", "due to", "caused by"
   - NEVER suggest: "should", "could", "might"
   - ONLY state: "found", "observed", "detected", "count"
</CRITICAL_RULES>

<OPERATIONS>

## observe-errors

Observe TypeScript compilation state.

**Input:**
- `project_dir`: Project directory
- `iteration`: Current iteration number

**Process:**
1. Execute: `scripts/observe-errors.sh "$project_dir" "$iteration"`
2. Parse compilation output
3. Return factual observations

**Output:**
```json
{
  "status": "success",
  "observation": {
    "iteration": 1,
    "error_count": 3,
    "errors_found": [
      {
        "file": "src/index.ts",
        "line": 45,
        "code": "TS2304",
        "message": "Cannot find name 'ProcessData'"
      }
    ],
    "build_succeeded": false,
    "timestamp": "2025-01-11T16:30:00Z"
  }
}
```

</OPERATIONS>
```

**skills/ts-inspector/scripts/observe-errors.sh:**

```bash
#!/bin/bash
set -euo pipefail

PROJECT_DIR="${1:?Error: Project directory required}"
ITERATION="${2:?Error: Iteration number required}"

cd "$PROJECT_DIR"

# Run TypeScript compiler
npx tsc --noEmit > /tmp/tsc-output.txt 2>&1 || true

# Count errors
ERROR_COUNT=$(grep -c "error TS" /tmp/tsc-output.txt || echo "0")

# Parse errors into JSON array
ERRORS_JSON="["
if [[ $ERROR_COUNT -gt 0 ]]; then
  while IFS= read -r line; do
    # Extract file, line, code, message
    # Format: src/index.ts(45,10): error TS2304: Cannot find name...
    FILE=$(echo "$line" | cut -d'(' -f1)
    LINE=$(echo "$line" | cut -d'(' -f2 | cut -d',' -f1)
    CODE=$(echo "$line" | grep -oP 'TS\d+')
    MESSAGE=$(echo "$line" | cut -d':' -f3-)

    if [[ -n "$ERRORS_JSON" && "$ERRORS_JSON" != "[" ]]; then
      ERRORS_JSON+=","
    fi
    ERRORS_JSON+="{\"file\":\"$FILE\",\"line\":$LINE,\"code\":\"$CODE\",\"message\":\"$MESSAGE\"}"
  done < <(grep "error TS" /tmp/tsc-output.txt)
fi
ERRORS_JSON+="]"

# Determine build success
BUILD_SUCCEEDED=$([ $ERROR_COUNT -eq 0 ] && echo "true" || echo "false")

# Output factual observation
cat <<EOF
{
  "status": "success",
  "observation": {
    "iteration": $ITERATION,
    "error_count": $ERROR_COUNT,
    "errors_found": $ERRORS_JSON,
    "build_succeeded": $BUILD_SUCCEEDED,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
```

### Debugger Skill (Analyzer Role)

**skills/ts-debugger/kb/type-errors.md:**

```markdown
# TypeScript Type Errors

## Error: Implicit 'any' Type (TS7006)

**Symptoms:**
- Error TS7006: Parameter implicitly has an 'any' type

**Root Cause:**
- TypeScript strict mode requires explicit type annotations
- Function parameter missing type

**Diagnostic Steps:**
1. Check if tsconfig.json has `"strict": true`
2. Check if parameter has type annotation

**Fix:**
```typescript
// Before
function process(data) { ... }

// After
function process(data: InputData) { ... }
```

**Confidence:** 0.98
**Success Rate:** 99%

## Error: Cannot Find Name (TS2304)

**Symptoms:**
- Error TS2304: Cannot find name 'TypeName'

**Root Causes:**

**Cause 1: Missing Import (70% likelihood)**
- Type is defined in another file but not imported

**Fix:**
```typescript
import { TypeName } from './types'
```

**Confidence:** 0.95
**Success Rate:** 98%

**Cause 2: Typo in Type Name (20% likelihood)**
- Type name misspelled

**Fix:**
```typescript
// Check similar type names in scope
// Correct spelling
```

**Confidence:** 0.85
**Success Rate:** 90%

**Cause 3: Type Not Defined (10% likelihood)**
- Type doesn't exist anywhere

**Fix:**
```typescript
// Define the type
interface TypeName {
  // fields
}
```

**Confidence:** 0.70
**Success Rate:** 95%
```

---

## Usage Examples

### Example 1: Simple Build with Fixes

```bash
/ts-builder /projects/my-app --auto-fix
```

**Execution:**
```
Iteration 1:
  Inspector: Found 3 errors
  Debugger: Diagnosed 3 root causes (confidence: 93%)
  User approves: Apply all fixes
  Builder: Applied 3 fixes successfully
  Verify: 0 errors remaining
  Result: Success in 1 iteration
```

### Example 2: Multiple Iterations

```bash
/ts-builder /projects/complex-app --max-iterations 5
```

**Execution:**
```
Iteration 1:
  Inspector: 10 errors
  Debugger: Fixed 6 high-confidence errors
  Builder: Applied 6 fixes
  Verify: 4 errors remaining

Iteration 2:
  Inspector: 4 errors
  Debugger: Fixed 2 medium-confidence errors
  Builder: Applied 2 fixes
  Verify: 2 errors remaining

Iteration 3:
  Inspector: 2 errors (complex type issues)
  Debugger: Low confidence (60%), recommends manual review
  User: Abort
  Result: Partial success (10 → 2 errors)
```

---

## Results

**Pattern characteristics:**
- **Iterative loop**: Up to N iterations
- **Role separation**: Inspector/Debugger/Builder never mix
- **Knowledge base**: Pattern matching for common errors
- **Confidence scoring**: Debugger rates fix confidence (0.0-1.0)
- **Issue tracking**: Complete log across iterations

**Context efficiency:**
- Manager: ~6K tokens
- Inspector: ~2K tokens
- Debugger: ~3K tokens
- Builder: ~2K tokens
- KB articles: 0 tokens (loaded on-demand)
- Scripts: 0 tokens
- **Total: ~13K tokens**

**Success rate:**
- Simple errors (imports, types): 95-99% success
- Medium errors (property access): 85-90% success
- Complex errors (circular deps): 60-70% success
- Manual review: Required for remaining errors
