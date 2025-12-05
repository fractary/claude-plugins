# Diagnose Issue

This workflow step performs root cause analysis of the problem.

## Overview

With debug context gathered and knowledge base searched, now we diagnose the root cause of the issue. The diagnosis considers:

1. Error messages and patterns
2. Workflow state at time of failure
3. Knowledge base insights (if matches found)
4. Explicit problem description (if targeted mode)

## Steps

### 1. Analyze Error Patterns

Examine collected errors for patterns and commonalities:

**Error Classification:**

| Pattern | Likely Category | Common Causes |
|---------|-----------------|---------------|
| `Type error:` | Type System | Incorrect annotations, API changes |
| `Import error:` / `Module not found` | Dependencies | Missing package, wrong path |
| `Permission denied` | Access | File permissions, auth issues |
| `Timeout` | Performance | Slow operations, deadlocks |
| `Connection refused` | Network | Service down, wrong port |
| `Assertion failed` | Testing | Logic error, wrong expectations |
| `Syntax error` | Code Quality | Typos, malformed code |

**Pattern Extraction:**
```bash
# Group errors by pattern type
errors=$(jq -r '.errors[].message' /tmp/faber-debugger-context.json)

# Categorize each error
for error in $errors; do
  if echo "$error" | grep -qi "type error"; then
    category="type_system"
  elif echo "$error" | grep -qi "import\|module not found"; then
    category="dependencies"
  elif echo "$error" | grep -qi "timeout"; then
    category="performance"
  # ... more patterns
  fi
done
```

**Expected Output:**
```json
{
  "error_analysis": {
    "total_errors": 5,
    "by_category": {
      "type_system": 3,
      "dependencies": 2
    },
    "unique_patterns": [
      "Type error: Expected string, got int",
      "Import error: Module 'xyz' not found"
    ],
    "most_frequent": "type_system",
    "affected_files": [
      "src/auth.ts",
      "src/utils.ts"
    ]
  }
}
```

---

### 2. Correlate with Workflow State

Analyze the workflow execution context:

**State Analysis Points:**
1. Which phase failed?
2. Which step within the phase?
3. What completed successfully before failure?
4. Are there related warnings from earlier steps?

**Correlation Logic:**
```
IF failed_phase == "build" AND failed_step == "implement":
  Check architect phase for spec quality warnings
  Check if dependencies were installed

IF failed_phase == "evaluate" AND failed_step == "test":
  Check build phase for implementation warnings
  Check if test files were created

IF failed_phase == "release" AND failed_step == "create-pr":
  Check for uncommitted changes
  Check branch status
```

**Expected Output:**
```json
{
  "state_correlation": {
    "failed_phase": "build",
    "failed_step": "implement",
    "completed_before_failure": ["frame", "architect"],
    "preceding_warnings": [
      {
        "phase": "architect",
        "message": "Specification may be incomplete"
      }
    ],
    "correlation_notes": [
      "Architect phase had incomplete spec warning",
      "Build failed on first implementation attempt"
    ]
  }
}
```

---

### 3. Apply Knowledge Base Insights

If knowledge base matches were found, incorporate them:

**High Relevance Match (score >= 0.8):**
```json
{
  "kb_insight": {
    "match_type": "high_relevance",
    "kb_id": "faber-debug-042",
    "past_diagnosis": "Type mismatch typically occurs when API response types change",
    "past_root_cause": "API contract changed without updating types",
    "confidence_boost": "+20%",
    "recommendation": "Apply verified solution from knowledge base"
  }
}
```

**Medium Relevance Match (score >= 0.6):**
```json
{
  "kb_insight": {
    "match_type": "medium_relevance",
    "kb_id": "faber-debug-031",
    "past_diagnosis": "Missing dependency often caused by incomplete package.json",
    "applicability": "Partial - problem similar but context differs",
    "recommendation": "Adapt solution to current context"
  }
}
```

---

### 4. Generate Root Cause Hypothesis

Synthesize analysis into root cause hypothesis:

**Hypothesis Structure:**
```json
{
  "root_cause_analysis": {
    "primary_cause": {
      "description": "Type annotations in auth module are incorrect",
      "category": "type_system",
      "location": "src/auth.ts",
      "evidence": [
        "3 type errors in auth.ts",
        "KB match suggests API type change"
      ],
      "confidence": "high"
    },
    "contributing_factors": [
      {
        "factor": "Incomplete specification",
        "evidence": "Architect phase warning about incomplete spec"
      },
      {
        "factor": "Missing type definitions",
        "evidence": "Import error for 'xyz' module types"
      }
    ],
    "timeline": [
      "Architect phase produced incomplete spec",
      "Build started without complete type information",
      "Implementation failed on type mismatches"
    ]
  }
}
```

**Confidence Levels:**

| Confidence | Criteria |
|------------|----------|
| High | KB match >= 0.8 OR 3+ pieces of evidence OR clear single cause |
| Medium | KB match >= 0.6 OR 2 pieces of evidence OR likely cause |
| Low | No KB match AND < 2 pieces of evidence OR multiple possible causes |

---

### 5. Identify Scope of Problem

Determine how extensive the issue is:

```json
{
  "problem_scope": {
    "severity": "moderate",
    "files_affected": 3,
    "estimated_fix_complexity": "simple",
    "blocking_workflow": true,
    "requires_spec_revision": false,
    "requires_architecture_change": false
  }
}
```

**Severity Classification:**

| Severity | Criteria |
|----------|----------|
| Critical | Fundamental architecture issue, requires major rework |
| Major | Multiple files affected, moderate complexity fix |
| Moderate | Single area affected, straightforward fix |
| Minor | Isolated issue, quick fix |

**Complexity Estimation:**

| Complexity | Criteria |
|------------|----------|
| Simple | 1-2 files, clear fix, < 10 lines |
| Moderate | 3-5 files, needs careful implementation |
| Complex | 6+ files OR requires new code OR uncertain fix |

---

### 6. Document Diagnosis

Compile complete diagnosis:

```json
{
  "diagnosis": {
    "mode": "automatic",
    "timestamp": "2025-12-05T16:00:00Z",

    "summary": "Build failed due to type mismatches in auth module, likely caused by incomplete specification in architect phase",

    "problem_statement": "Type errors preventing build completion",

    "root_cause": {
      "primary": "Incorrect type annotations in src/auth.ts",
      "confidence": "high",
      "category": "type_system"
    },

    "contributing_factors": [
      "Incomplete specification from architect phase",
      "Missing type definitions for 'xyz' module"
    ],

    "evidence": [
      "3 type errors in src/auth.ts",
      "1 import error for missing module",
      "KB match (score 0.85) with verified solution"
    ],

    "scope": {
      "severity": "moderate",
      "complexity": "simple",
      "files_affected": ["src/auth.ts", "src/utils.ts"]
    },

    "kb_reference": {
      "used": true,
      "entry_id": "faber-debug-042",
      "match_score": 0.85
    }
  }
}
```

## Error Handling

**No Clear Pattern:**
```
IF error patterns don't match known categories:
  Set confidence = "low"
  List all errors as potential causes
  Recommend manual investigation
```

**Conflicting Evidence:**
```
IF KB match suggests different cause than pattern analysis:
  Present both hypotheses
  Rank by evidence strength
  Set confidence = "medium"
```

**Insufficient Context:**
```
IF critical context missing (state, errors):
  Use explicit problem description
  Set confidence = "low"
  Recommend gathering more information
```

## Output

Save diagnosis for solution proposal:

```bash
echo "$DIAGNOSIS_JSON" >> /tmp/faber-debugger-context.json
```

Return diagnosis summary for immediate feedback:

```
Root Cause: Type mismatches in auth module
Confidence: High
KB Match: faber-debug-042 (85% similar)
Scope: Moderate (3 files, simple fix)
```
