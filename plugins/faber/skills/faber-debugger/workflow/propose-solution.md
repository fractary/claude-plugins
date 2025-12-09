# Propose Solution

This workflow step generates actionable solutions based on the diagnosis.

## Overview

With root cause analysis complete, generate solutions that can be implemented. Solutions should be:

1. **Actionable** - Clear steps that can be followed
2. **Prioritized** - Ordered by likelihood of success
3. **Contextual** - Adapted to the specific project/workflow
4. **Traceable** - Include source (KB or fresh analysis)

## Steps

### 1. Evaluate Solution Sources

Determine solution strategy based on diagnosis:

**Source Priority:**

| KB Match Score | Strategy |
|----------------|----------|
| >= 0.8 (High) | Use KB solution directly, adapt variables |
| >= 0.6 (Medium) | Use KB as template, modify for context |
| < 0.6 or none | Generate fresh solution from diagnosis |

```json
{
  "solution_strategy": {
    "primary_source": "knowledge_base",
    "kb_entry": "faber-debug-042",
    "kb_score": 0.85,
    "adaptation_required": "variable_substitution",
    "fresh_analysis_needed": false
  }
}
```

---

### 2. Generate Solutions from Knowledge Base

For high/medium KB matches, adapt past solutions:

**Variable Substitution:**
```
Original: "/fractary-faber:run --work-id {id} --step builder"
Adapted:  "/fractary-faber:run --work-id 244 --step builder"

Original: "Fix type in {file}:{line}"
Adapted:  "Fix type in src/auth.ts:45"
```

**Adaptation Process:**
1. Load solution from KB entry
2. Replace `{id}` with current work_id
3. Replace `{file}` with affected file paths
4. Replace `{line}` with actual line numbers
5. Verify steps are applicable to current context

```json
{
  "kb_solution": {
    "source": "faber-debug-042",
    "original_title": "Fix type annotation",
    "adapted_title": "Fix type annotation in src/auth.ts",
    "original_steps": [
      "Check the expected type from spec/API",
      "Update type annotation to match",
      "Run type check: npm run typecheck"
    ],
    "adapted_steps": [
      "Check the expected type from specs/WORK-00244-faber-debugger-skill.md",
      "Update type annotation in src/auth.ts:45 to match",
      "Run type check: npm run typecheck"
    ],
    "faber_command": "/fractary-faber:run --work-id 244 --step builder --prompt 'Fix type errors in src/auth.ts as identified by debugger'",
    "confidence": "high",
    "past_success_rate": "7/7 (100%)"
  }
}
```

---

### 3. Generate Fresh Solutions

If no KB match or low relevance, generate from diagnosis:

**Solution Template by Category:**

**Type System Errors:**
```json
{
  "title": "Fix type annotations",
  "steps": [
    "Identify expected types from specification or API documentation",
    "Update type annotations in affected files: {files}",
    "Run type checker to verify fixes: {typecheck_command}",
    "Run tests to ensure no regressions"
  ],
  "complexity": "simple"
}
```

**Dependency Errors:**
```json
{
  "title": "Install missing dependencies",
  "steps": [
    "Add missing package to dependencies: npm install {package}",
    "If types needed: npm install -D @types/{package}",
    "Update import statements if package name changed",
    "Rebuild project: npm run build"
  ],
  "complexity": "simple"
}
```

**Test Failures:**
```json
{
  "title": "Fix failing tests",
  "steps": [
    "Analyze test output to identify failing assertions",
    "Determine if issue is in test or implementation",
    "If implementation: fix logic in {files}",
    "If test: update expectations in {test_files}",
    "Re-run tests: npm test"
  ],
  "complexity": "moderate"
}
```

---

### 4. Assess Solution Complexity

Evaluate each solution's complexity:

```json
{
  "complexity_assessment": {
    "solution": "Fix type annotations",
    "estimated_steps": 3,
    "files_to_modify": 2,
    "risk_level": "low",
    "requires_new_code": false,
    "requires_testing": true,
    "complexity_class": "simple"
  }
}
```

**Complexity Classes:**

| Class | Criteria | Action |
|-------|----------|--------|
| Simple | 1-2 steps, < 3 files, low risk | Direct solution |
| Moderate | 3-5 steps, 3-6 files, medium risk | Detailed solution |
| Complex | 6+ steps, > 6 files, high risk | Create specification |

---

### 5. Handle Complex Solutions

For complex issues (6+ steps or multiple concerns):

**Create Specification:**
```bash
# Invoke fractary-spec with solution context
/fractary-spec:create \
  --work-id 244 \
  --prompt "Debugger identified the following issues requiring coordinated fixes:
    1. Type errors in auth module
    2. Missing dependency types
    3. Test expectations need update

    This spec should detail the implementation order and testing strategy."
```

**Spec Content:**
```markdown
# Fix Specification: Debugger-Identified Issues

## Issues Identified

1. Type mismatches in src/auth.ts (3 errors)
2. Missing @types/xyz package
3. Test assertions expect old return type

## Implementation Order

### Phase 1: Dependencies
1. Install @types/xyz
2. Verify types are available

### Phase 2: Type Fixes
1. Update src/auth.ts:45 - change return type
2. Update src/utils.ts:12 - fix import type

### Phase 3: Test Updates
1. Update test expectations in tests/auth.test.ts

## Verification

After each phase, run:
- `npm run typecheck`
- `npm test`
```

---

### 6. Rank Solutions

Order solutions by likelihood of success:

**Ranking Factors:**

| Factor | Weight | Description |
|--------|--------|-------------|
| KB Success Rate | 30% | Past resolution success rate |
| Evidence Strength | 25% | How well diagnosis supports this solution |
| Complexity | 20% | Simpler solutions ranked higher |
| Confidence | 15% | Diagnosis confidence level |
| Risk | 10% | Lower risk ranked higher |

```json
{
  "solutions_ranked": [
    {
      "rank": 1,
      "title": "Fix type annotation in src/auth.ts",
      "source": "knowledge_base",
      "kb_id": "faber-debug-042",
      "confidence": "high",
      "complexity": "simple",
      "ranking_score": 0.92,
      "recommended": true
    },
    {
      "rank": 2,
      "title": "Install missing type definitions",
      "source": "fresh_analysis",
      "confidence": "medium",
      "complexity": "simple",
      "ranking_score": 0.75,
      "recommended": false
    }
  ]
}
```

---

### 7. Compile Solution Package

Prepare final solution output:

```json
{
  "solutions": {
    "count": 2,
    "complexity_summary": "simple",
    "spec_created": false,

    "recommended": {
      "title": "Fix type annotation in src/auth.ts",
      "description": "Update the return type annotation to match the actual implementation",
      "source": "knowledge_base (faber-debug-042)",
      "confidence": "high",
      "steps": [
        "Open src/auth.ts and locate line 45",
        "Change return type from `string` to `AuthResult`",
        "Run `npm run typecheck` to verify",
        "Run `npm test` to ensure no regressions"
      ],
      "files_to_modify": ["src/auth.ts"],
      "estimated_complexity": "simple"
    },

    "alternatives": [
      {
        "title": "Install missing type definitions",
        "reason": "May also need @types/xyz if types still missing after primary fix"
      }
    ],

    "continuation": {
      "command": "/fractary-faber:run --work-id 244 --step builder --prompt 'Fix type errors in src/auth.ts as identified by debugger'",
      "phase_to_resume": "build",
      "step_to_resume": "implement"
    }
  }
}
```

## Error Handling

**No Valid Solutions:**
```
IF all solution attempts have high risk or low confidence:
  Recommend manual investigation
  Provide diagnostic summary for human review
  Suggest `/fractary-faber:debug --problem "specific question"`
```

**KB Solution Not Applicable:**
```
IF KB solution steps don't match current context:
  Flag as "partial_match"
  Extract applicable portions
  Supplement with fresh analysis
```

**Multiple Root Causes:**
```
IF diagnosis shows multiple independent issues:
  Generate solution for each
  Order by dependency (fix prereqs first)
  Consider creating spec for coordination
```

## Output

Save solutions for continuation and logging:

```bash
echo "$SOLUTIONS_JSON" >> /tmp/faber-debugger-context.json
```

Return solution summary:

```
Recommended Solution: Fix type annotation in src/auth.ts
Confidence: High (KB match 85%)
Complexity: Simple (3 steps)
Command: /fractary-faber:run --work-id 244 --step builder --prompt '...'
```
