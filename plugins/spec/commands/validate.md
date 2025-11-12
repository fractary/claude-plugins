---
name: fractary-spec:validate
description: Validate implementation against specification
argument-hint: <issue_number> [--phase <n>]
---

Validate that implementation matches specification by checking requirements coverage, acceptance criteria, file modifications, tests, and documentation.

## Usage

```bash
/fractary-spec:validate <issue_number> [options]
```

## Arguments

- `<issue_number>`: GitHub issue number (required)

## Options

- `--phase <n>`: Validate specific phase for multi-spec issues

## Examples

### Single Spec

```bash
/fractary-spec:validate 123
```

### Multi-Spec (Specific Phase)

```bash
/fractary-spec:validate 123 --phase 1
```

### All Phases

```bash
/fractary-spec:validate 123
```

Validates all specs for issue #123.

## What It Checks

### 1. Requirements Coverage
- Are all requirements implemented?
- Are expected features present?

### 2. Acceptance Criteria
- Are checkboxes marked `[x]`?
- Total met vs. total criteria

### 3. Files Modified
- Were expected files created/modified?
- Do git logs show relevant changes?

### 4. Tests Added
- Were test files added/modified?
- Does coverage match testing strategy?

### 5. Documentation Updated
- Were docs updated after spec creation?
- Do README, API docs reflect changes?

## Output

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
1. One acceptance criterion not met: Password reset
2. E2E tests missing
3. Documentation needs update

✅ COMPLETED: Spec Validator
Validation Result: Partial
───────────────────────────────────────
Next: Address issues above or proceed with archival
```

## Validation Status

### Complete ✓
- Requirements: 100% implemented
- Acceptance Criteria: 100% met
- Files: All modified
- Tests: Full coverage
- Docs: Updated

**Action**: Ready for archival

### Partial ⚠
- Requirements: 80-100% covered
- Acceptance Criteria: 80-100% met
- Files: Most modified
- Tests: Some coverage
- Docs: May or may not be updated

**Action**: Review issues, decide if acceptable

### Incomplete ✗
- Requirements: <80% covered
- Acceptance Criteria: <80% met
- Files: Missing critical files
- Tests: No coverage
- Docs: Required but missing

**Action**: Complete implementation first

## Spec Update

After validation, spec frontmatter is updated:

```yaml
---
validated: true|false|partial
validation_date: "2025-01-15"
validation_notes: "Tests incomplete, docs needed"
---
```

## FABER Integration

In FABER workflow, validation runs automatically during Evaluate phase:

```toml
[workflow.evaluate]
validate_spec = true
```

If validation fails, workflow loops back to Build phase.

## Manual Validation

Some aspects require manual review:
- Code quality
- Business logic correctness
- User experience
- Performance
- Security

Use validation output as a checklist, apply human judgment.

## Troubleshooting

**Error: Spec not found**:
- Generate spec first: `/fractary-spec:generate <issue>`
- Check issue number is correct

**Warning: Git not available**:
- Some checks require git
- Manual verification needed

**All checks pass but manually incomplete**:
- Automated checks are heuristics
- Review implementation yourself
- Mark criteria manually in spec file
