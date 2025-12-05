# Analyze Specification Compliance

This workflow step verifies that code changes implement all requirements from the specification.

## Overview

Using the claude-opus-4-5 model, analyze:
1. Requirements from specification (or issue if no spec)
2. Code changes made
3. Coverage of each requirement by implementation

## Prerequisites

- Context gathered from `gather-context.md`
- Issue details available
- Specification content (or issue description as fallback)
- Code diff available

## Steps

### 1. Extract Requirements

Parse requirements from specification:

**If Specification Exists:**
```
Extract from spec:
- Functional Requirements (FR-*)
- Non-Functional Requirements (NFR-*)
- Acceptance Criteria (AC-*)
```

**If No Specification:**
```
Extract from issue description:
- Explicit requirements ("must", "should", "will")
- Implied requirements (from context)
- Success criteria (if mentioned)
```

**Output:**
```json
{
  "requirements": [
    {
      "id": "FR-1",
      "type": "functional",
      "text": "The skill must run automatically as the first step in the evaluate phase",
      "acceptance_criteria": [
        "No configuration entry required in workflow files",
        "Skill invokes before any other evaluate phase steps"
      ],
      "priority": "high"
    },
    {
      "id": "FR-2",
      "type": "functional",
      "text": "The skill must gather all necessary context to perform review",
      "acceptance_criteria": [
        "Fetches issue details",
        "Retrieves specifications",
        "Gathers code changes"
      ],
      "priority": "high"
    }
  ],
  "total_requirements": 8,
  "total_acceptance_criteria": 24
}
```

---

### 2. Analyze Code Changes Against Requirements

For each requirement, analyze if code changes implement it:

**Model Prompt (claude-opus-4-5):**
```
Role: Code Specification Reviewer

You are reviewing code changes against a specification to verify implementation completeness.

SPECIFICATION:
{specification_content}

ISSUE DESCRIPTION:
{issue_body}

ISSUE COMMENTS:
{comments}

CODE CHANGES:
{code_diff}

FILES CHANGED:
{files_summary}

TASK:
For each requirement in the specification, determine:
1. Is it implemented? (yes/no/partial)
2. Where is the evidence? (file:line references)
3. What gaps exist? (if any)

Analyze acceptance criteria as well.

OUTPUT FORMAT (JSON):
{
  "requirements": [
    {
      "id": "FR-1",
      "text": "The skill must run automatically...",
      "implemented": "yes|no|partial",
      "evidence": [
        {"file": "faber-manager.md", "line": "1247-1289", "description": "Automatic invocation logic"}
      ],
      "gaps": [],
      "confidence": 0.95
    }
  ],
  "acceptance_criteria": [
    {
      "id": "AC-1",
      "text": "Skill file created",
      "met": true,
      "evidence": "plugins/faber/skills/issue-reviewer/SKILL.md exists",
      "gaps": []
    }
  ],
  "overall_coverage": {
    "requirements_implemented": 7,
    "requirements_partial": 1,
    "requirements_missing": 0,
    "requirements_total": 8,
    "percentage": 94
  },
  "critical_gaps": [],
  "analysis_notes": "Implementation largely complete..."
}
```

---

### 3. Calculate Coverage Metrics

Aggregate implementation status:

```
coverage_percentage = (fully_implemented + 0.5 * partial) / total * 100

critical_gaps = requirements where:
  - implemented == "no" AND priority == "high"
  - OR multiple acceptance criteria unmet

major_gaps = requirements where:
  - implemented == "partial" AND priority == "high"
  - OR implemented == "no" AND priority == "medium"
```

**Coverage Thresholds:**
| Coverage | Status Impact |
|----------|---------------|
| 100% | Can be "success" |
| 95-99% | Can be "warning" |
| < 95% | Likely "failure" |

---

### 4. Generate Compliance Report

Create detailed compliance analysis:

```json
{
  "compliance_analysis": {
    "timestamp": "2025-12-05T15:45:00Z",
    "model_used": "claude-opus-4-5",
    "coverage": {
      "percentage": 94,
      "fully_implemented": 7,
      "partial": 1,
      "not_implemented": 0,
      "total": 8
    },
    "requirements": [
      {
        "id": "FR-1",
        "text": "Automatic invocation",
        "status": "partial",
        "evidence": ["faber-manager.md:1247-1289"],
        "gaps": ["Hook not yet configured in evaluate phase entry"],
        "confidence": 0.85
      }
    ],
    "acceptance_criteria": {
      "met": 22,
      "unmet": 2,
      "total": 24,
      "details": [...]
    },
    "critical_gaps": [],
    "major_gaps": [
      "FR-1 partial implementation - automatic invocation not fully wired"
    ],
    "minor_gaps": [],
    "summary": "Implementation is largely complete. One requirement (FR-1) needs final integration."
  }
}
```

## Analysis Considerations

### When Spec is Missing

If no specification exists:
1. Use issue description as primary source
2. Extract implicit requirements
3. Be more lenient on coverage thresholds
4. Note in report: "Analyzed against issue description (no spec found)"

### For Large Changes

If diff is very large:
1. Focus on key files first
2. Sample representative files
3. Note limitations in report
4. Lower confidence accordingly

### Confidence Levels

```
High (0.9-1.0): Clear evidence in code, explicit implementation
Medium (0.7-0.89): Implied implementation, requires inference
Low (0.5-0.69): Uncertain, may need manual verification
Very Low (<0.5): Cannot determine, flag for manual review
```

## Output

Pass compliance analysis to next step (analyze-quality.md):

```json
{
  "spec_compliance": {
    "coverage_percentage": 94,
    "critical_gaps": [],
    "major_gaps": ["..."],
    "minor_gaps": [],
    "details": {...}
  }
}
```
