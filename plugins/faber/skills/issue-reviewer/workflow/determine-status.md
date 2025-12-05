# Determine Status

This workflow step classifies implementation completeness into one of three status codes.

## Overview

Based on specification compliance and code quality analysis, determine the final status:
- **success**: Ready for release
- **warning**: Ready with minor concerns
- **failure**: Not ready, needs work

## Prerequisites

- Specification compliance analysis from `analyze-specification.md`
- Code quality analysis from `analyze-quality.md`

## Status Definitions

### success
**Definition**: Issue/spec implemented as requested, no issues

**Criteria (ALL must be true):**
- Specification coverage = 100%
- No critical quality issues
- No major quality issues
- Test coverage >= 85%
- Documentation adequate

**Message**: "Implementation complete - all requirements met"
**Recommendation**: "Ready for release"

---

### warning
**Definition**: Issue/spec implemented as requested, but minor issues or improvement opportunities identified

**Criteria (ALL must be true):**
- Specification coverage >= 95%
- No critical quality issues
- No major quality issues (OR major issues are non-blocking)
- Test coverage >= 80%
- Only minor quality issues OR improvement suggestions

**Message**: "Implementation complete with minor improvements identified"
**Recommendation**: "Address minor issues before release"

---

### failure
**Definition**: Issue/spec NOT implemented as requested OR medium/major/critical issues found

**Criteria (ANY of these):**
- Specification coverage < 95%
- Any critical quality issue
- Major quality issues that block release
- Test coverage < 80% for new code
- Critical gaps in requirements

**Message**: "Implementation incomplete - critical gaps found"
**Recommendation**: "Return to Build phase to address gaps"

---

## Classification Algorithm

```
function determineStatus(spec_compliance, code_quality):

  # Extract metrics
  coverage = spec_compliance.coverage_percentage
  critical_gaps = spec_compliance.critical_gaps
  major_gaps = spec_compliance.major_gaps

  critical_issues = code_quality.critical_issues
  major_issues = code_quality.major_issues
  minor_issues = code_quality.minor_issues
  test_adequate = code_quality.test_coverage_adequate
  docs_adequate = code_quality.documentation_adequate

  # Check for FAILURE conditions
  IF critical_issues > 0 THEN
    RETURN "failure", "Critical quality issues found", critical_issues

  IF critical_gaps.length > 0 THEN
    RETURN "failure", "Critical requirements not implemented", critical_gaps

  IF coverage < 95 THEN
    RETURN "failure", "Specification coverage below 95%", coverage

  IF major_issues > 0 AND NOT isNonBlocking(major_issues) THEN
    RETURN "failure", "Major quality issues found", major_issues

  IF NOT test_adequate AND hasNewCode() THEN
    RETURN "failure", "Insufficient test coverage for new code", test_coverage

  # Check for SUCCESS conditions
  IF coverage == 100 AND
     critical_issues == 0 AND
     major_issues == 0 AND
     minor_issues == 0 AND
     test_adequate AND
     docs_adequate THEN
    RETURN "success", "All requirements met with no issues"

  # Check for WARNING conditions
  IF coverage >= 95 AND
     critical_issues == 0 AND
     (major_issues == 0 OR isNonBlocking(major_issues)) AND
     test_adequate THEN
    warnings = collectWarnings(minor_issues, major_gaps, docs_adequate)
    RETURN "warning", "Implementation complete with minor concerns", warnings

  # Default to FAILURE if conditions unclear
  RETURN "failure", "Unable to verify complete implementation"
```

---

## Non-Blocking Issue Assessment

Some major issues may be non-blocking for release:

```
function isNonBlocking(issues):
  non_blocking_categories = [
    "documentation",
    "style",
    "minor_performance",
    "future_enhancement"
  ]

  FOR each issue IN issues:
    IF issue.category NOT IN non_blocking_categories THEN
      RETURN false

  RETURN true
```

---

## Confidence Scoring

Calculate confidence in the status determination:

```
function calculateConfidence(analysis):
  factors = {
    "spec_available": spec.found ? 0.2 : 0,
    "full_diff_analyzed": diff.complete ? 0.2 : 0.1,
    "tests_present": tests.exist ? 0.2 : 0.1,
    "clear_requirements": requirements.parseable ? 0.2 : 0.1,
    "model_confidence": average(requirement_confidences) * 0.2
  }

  confidence = sum(factors.values())
  RETURN min(confidence, 1.0)
```

**Confidence Interpretation:**
| Score | Meaning |
|-------|---------|
| >= 0.9 | High confidence in assessment |
| 0.7-0.89 | Moderate confidence, may need verification |
| < 0.7 | Low confidence, recommend manual review |

---

## Output Format

### Success
```json
{
  "status": "success",
  "message": "Implementation complete - all requirements met",
  "details": {
    "spec_coverage": 100,
    "requirements_met": 8,
    "requirements_total": 8,
    "quality_issues": {
      "critical": 0,
      "major": 0,
      "minor": 0
    },
    "test_coverage": 92,
    "documentation_adequate": true
  },
  "confidence": 0.95,
  "recommendation": "Ready for release",
  "next_action": "continue_to_evaluate_steps"
}
```

### Warning
```json
{
  "status": "warning",
  "message": "Implementation complete with minor improvements identified",
  "warnings": [
    "Minor: Consider adding error handling for edge case in line 45",
    "Minor: Documentation could include troubleshooting section"
  ],
  "details": {
    "spec_coverage": 98,
    "requirements_met": 7,
    "requirements_partial": 1,
    "requirements_total": 8,
    "quality_issues": {
      "critical": 0,
      "major": 0,
      "minor": 3
    },
    "test_coverage": 85,
    "documentation_adequate": true
  },
  "confidence": 0.88,
  "recommendation": "Address minor issues before release",
  "next_action": "continue_to_evaluate_steps"
}
```

### Failure
```json
{
  "status": "failure",
  "message": "Implementation incomplete - critical gaps found",
  "errors": [
    "Critical: FR-1 (Automatic invocation) not fully implemented",
    "Major: No tests added for new skill functionality"
  ],
  "details": {
    "spec_coverage": 75,
    "requirements_met": 6,
    "requirements_partial": 1,
    "requirements_not_met": 1,
    "requirements_total": 8,
    "critical_gaps": [
      {
        "requirement": "FR-1",
        "description": "Automatic invocation at evaluate phase not configured",
        "evidence": "faber-manager.md does not contain issue-reviewer call"
      }
    ],
    "quality_issues": {
      "critical": 0,
      "major": 1,
      "minor": 2
    },
    "test_coverage": 0,
    "documentation_adequate": false
  },
  "confidence": 0.92,
  "recommendation": "Return to Build phase to address gaps",
  "next_action": "mark_phase_requires_review"
}
```

---

## FABER Manager Integration

The status code determines how FABER manager proceeds:

| Status | Manager Action |
|--------|----------------|
| success | Continue to evaluate phase steps normally |
| warning | Log warnings, continue to evaluate phase steps |
| failure | Mark phase as REQUIRES_REVIEW, present to user |

**On Failure:**
```
FABER Manager receives: {status: "failure", ...}

Manager action:
1. Update state: phase="evaluate", status="requires_review"
2. Display failure report to user
3. Present options:
   - "Return to Build to fix issues"
   - "Continue anyway (not recommended)"
   - "Stop workflow"
```

---

## Report Generation

After determining status, generate final report:

```bash
scripts/generate-report.sh \
  --work-id "$WORK_ID" \
  --status "$STATUS" \
  --spec-compliance "$SPEC_COMPLIANCE_JSON" \
  --code-quality "$CODE_QUALITY_JSON"
```

**Report saved to:**
`.fractary/plugins/faber/reviews/{work_id}-{timestamp}.md`

**Report Format:**
```markdown
# Issue Review Report

**Work ID**: #233
**Date**: 2025-12-05 15:55:00 UTC
**Status**: {status_emoji} {status}

## Summary
{summary_message}

## Specification Compliance
Coverage: {coverage}%
Requirements: {met}/{total}

### Implemented
- [x] FR-1: ...
- [x] FR-2: ...

### Gaps
- [ ] FR-8: {gap_description}

## Code Quality
Issues: {critical} critical, {major} major, {minor} minor

### Issues Found
1. **[Major]** {description} ({file}:{line})

## Test Coverage
Estimated: {percentage}%
Assessment: {adequate ? "Adequate" : "Needs improvement"}

## Recommendations
1. {recommendation_1}
2. {recommendation_2}

---
*Generated by issue-reviewer skill*
*Model: claude-opus-4-5*
```
