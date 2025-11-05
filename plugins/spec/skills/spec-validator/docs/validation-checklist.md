# Validation Checklist

This document describes the validation checks performed by the spec-validator skill.

## Overview

Validation ensures that implementation matches specification before archival. All checks are automated but can be overridden with `--force` flag.

## Validation Checks

### 1. Requirements Coverage

**What**: Are all requirements from spec implemented?

**How**:
- Parse functional and non-functional requirements from spec
- Check if expected functionality exists in codebase
- Verify expected files were modified

**Pass Criteria**:
- All functional requirements implemented
- All non-functional requirements met
- Related code changes present

**Status Levels**:
- **Pass**: 100% requirements covered
- **Warn**: 80-99% requirements covered
- **Fail**: <80% requirements covered

### 2. Acceptance Criteria

**What**: Are all acceptance criteria checkboxes marked complete?

**How**:
- Parse acceptance criteria section from spec
- Count total criteria
- Count checked `[x]` vs unchecked `[ ]` items

**Pass Criteria**:
- All checkboxes marked `[x]`
- OR all criteria demonstrably met even if not checked

**Status Levels**:
- **Pass**: 100% criteria met
- **Warn**: 80-99% criteria met
- **Fail**: <80% criteria met

### 3. Files Modified

**What**: Were expected files created/modified?

**How**:
- Extract file paths from "Files to Modify" section
- Check if files exist
- Verify files were modified recently (git log)

**Pass Criteria**:
- All listed files exist
- All listed files have recent commits
- File changes align with described modifications

**Status Levels**:
- **Pass**: All expected files modified
- **Warn**: Most files modified, some missing
- **Fail**: Critical files not modified

### 4. Tests Added

**What**: Were tests added for new/changed functionality?

**How**:
- Check for test files modified recently
- Verify test coverage for new code
- Match against testing strategy in spec

**Pass Criteria**:
- Unit tests for new functions/classes
- Integration tests for workflows
- E2E tests if specified
- Test files show recent commits

**Status Levels**:
- **Pass**: All test types covered
- **Warn**: Some tests added, coverage incomplete
- **Fail**: No tests added

### 5. Documentation Updated

**What**: Was documentation updated to reflect changes?

**How**:
- Check for .md file modifications (excluding specs)
- Verify docs modified after spec creation
- Check if README, API docs, etc. updated

**Pass Criteria**:
- Relevant documentation files updated
- Updates made after spec creation
- Changes reflect new functionality

**Status Levels**:
- **Pass**: Docs updated appropriately
- **Warn**: Docs not updated (non-critical features)
- **Fail**: Docs required but not updated (breaking changes, API changes)

## Overall Validation Status

Combine individual checks into overall status:

### Complete ✓

**All checks pass**:
- Requirements: 100% covered
- Acceptance Criteria: 100% met
- Files: All modified as expected
- Tests: Full coverage
- Docs: Updated

**Action**: Ready for archival

### Partial ⚠

**Most checks pass, some warnings**:
- Requirements: 80-100% covered
- Acceptance Criteria: 80-100% met
- Files: Most modified
- Tests: Some coverage
- Docs: May or may not be updated

**Action**: Review warnings, decide if acceptable for archival

### Incomplete ✗

**One or more critical failures**:
- Requirements: <80% covered
- Acceptance Criteria: <80% met
- Files: Missing critical files
- Tests: No coverage
- Docs: Required but missing

**Action**: Complete implementation before archival

## Validation Output

### Console Output

```
🎯 STARTING: Spec Validator
Spec: /specs/spec-123-feature.md
Issue: #123
───────────────────────────────────────

Requirements: ✓ 8/8 implemented
Acceptance Criteria: ✓ 5/6 met
Files Modified: ✓ Expected files changed
Tests: ⚠ 2/3 test cases added
Documentation: ✗ Docs not updated

Overall: Partial

Issues to address:
1. One acceptance criterion not met
2. E2E tests missing
3. Documentation needs update

✅ COMPLETED: Spec Validator
Validation Result: Partial
───────────────────────────────────────
Next: Address issues above or proceed with --skip-warnings
```

### JSON Output

```json
{
  "status": "success",
  "validation_result": "partial",
  "checks": {
    "requirements": {
      "completed": 8,
      "total": 8,
      "percentage": 100,
      "status": "pass"
    },
    "acceptance_criteria": {
      "met": 5,
      "total": 6,
      "percentage": 83,
      "status": "warn"
    },
    "files_modified": {
      "expected": 4,
      "modified": 4,
      "percentage": 100,
      "status": "pass"
    },
    "tests_added": {
      "files_modified": 2,
      "expected": 3,
      "status": "warn"
    },
    "docs_updated": {
      "files_modified": 0,
      "status": "fail"
    }
  },
  "issues": [
    "One acceptance criterion not met: Password reset",
    "E2E tests not added",
    "Documentation not updated"
  ],
  "spec_updated": true
}
```

## Spec Frontmatter Update

After validation, spec frontmatter is updated:

**Before**:
```yaml
---
spec_id: spec-123-feature
issue_number: 123
title: Implement user authentication
type: feature
status: draft
validated: false
---
```

**After (Complete)**:
```yaml
---
spec_id: spec-123-feature
issue_number: 123
title: Implement user authentication
type: feature
status: validated
validated: true
validation_date: "2025-01-15"
---
```

**After (Partial)**:
```yaml
---
spec_id: spec-123-feature
issue_number: 123
title: Implement user authentication
type: feature
status: in_progress
validated: partial
validation_date: "2025-01-15"
validation_notes: "Tests incomplete, docs needed"
---
```

**After (Incomplete)**:
```yaml
---
spec_id: spec-123-feature
issue_number: 123
title: Implement user authentication
type: feature
status: draft
validated: false
validation_date: "2025-01-15"
validation_notes: "Requirements not met, implementation incomplete"
---
```

## Manual Validation

Some aspects require manual review:

1. **Code Quality**: Automated checks don't assess code quality
2. **Business Logic**: Correctness of implementation
3. **User Experience**: UI/UX matches requirements
4. **Performance**: Meets performance requirements
5. **Security**: Security considerations addressed

Use validation output as a checklist, but apply human judgment.

## Overriding Validation

To archive despite warnings:
```bash
/fractary-spec:archive 123 --skip-warnings
```

To skip all checks:
```bash
/fractary-spec:archive 123 --force
```

**Use with caution**: Only override when confident implementation is complete.

## FABER Integration

In FABER workflow:
- **Evaluate Phase**: Validation runs automatically
- **If Incomplete**: Loop back to Build phase
- **If Partial**: Prompt user for decision
- **If Complete**: Proceed to Release phase
