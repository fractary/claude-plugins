# Workflow: Validate Against Spec

This workflow describes the detailed steps for validating an implementation against a specification.

## Step 1: Read Spec File

Read the specification file from provided path:
```bash
cat "$SPEC_PATH"
```

Validate file exists and is readable.

## Step 2: Parse Spec Frontmatter

Extract frontmatter (YAML between `---` markers):
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

Extract key fields:
- `issue_number`
- `title`
- `type`
- Current `validated` status

## Step 3: Extract Requirements

Parse spec body for requirements:

### Functional Requirements
Look for sections:
```markdown
## Functional Requirements
- FR1: Description
- FR2: Description

### Functional Requirements
- Requirement 1
- Requirement 2
```

Extract all requirements into array.

### Non-Functional Requirements
Look for sections:
```markdown
## Non-Functional Requirements
- NFR1: Description

### Non-Functional Requirements
- Performance requirements
```

Extract all NFRs into array.

## Step 4: Extract Acceptance Criteria

Look for:
```markdown
## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [x] Criterion 3
```

Parse checkboxes:
- Count total criteria
- Count checked criteria `[x]` or `[X]`
- Count unchecked criteria `[ ]`

## Step 5: Extract Expected Files

Look for sections:
```markdown
## Files to Modify
- `src/auth.ts`: Add auth logic
- `src/models/user.ts`: Add User model

### New Files
- `src/auth/register.ts`: Registration logic

### Modified Files
- `src/routes/api.ts`: Add auth routes
```

Extract file paths from code blocks and lists.

## Step 6: Check Implementation Completeness

### Requirements Coverage

For each requirement, check if implemented:
1. Search codebase for related keywords
2. Check if expected files exist
3. Verify functionality present

**Heuristics**:
- If requirement mentions specific file, check that file exists and was modified
- If requirement mentions function/class, check it exists
- Use git log to see if related changes made

**Result**: X/Y requirements implemented

### Acceptance Criteria Status

Check acceptance criteria checkboxes in spec file:
```markdown
- [x] User can register          # Met
- [x] Email validation works     # Met
- [ ] Password reset works       # Not met
```

Count checked vs unchecked.

**Result**: X/Y criteria met

## Step 7: Verify Files Modified

Check if expected files were actually modified:

```bash
git log --name-only --since="7 days ago" --format="" | sort -u
```

Compare against files listed in spec:
- ✓ File in spec and modified
- ⚠ File in spec but not modified
- ℹ File modified but not in spec

**Result**: Pass if all spec files modified, Warn if some missing

## Step 8: Check Tests Added

Look for test files and changes:

### Find Test Files
```bash
find . -name "*.test.ts" -o -name "*.test.js" -o -name "*.spec.ts" -o -name "*.spec.js"
```

### Check Recent Test Changes
```bash
git log --name-only --since="7 days ago" --format="" | grep -E "\.(test|spec)\.(ts|js)$"
```

### Analyze Testing Strategy

Parse spec for testing requirements:
```markdown
## Testing Strategy
### Unit Tests
- Test user registration
- Test email validation

### Integration Tests
- Test auth flow end-to-end
```

Count:
- Expected test areas (from spec)
- Test files added/modified (from git)

**Result**:
- Pass: All test areas covered
- Warn: Some tests missing
- Fail: No tests added

## Step 9: Check Documentation Updated

Check if documentation files were updated:

### Find Doc Files
```bash
find . -name "*.md" ! -path "./node_modules/*" ! -path "./.git/*"
```

### Check Recent Doc Changes
```bash
git log --name-only --since="7 days ago" --format="" | grep "\.md$" | grep -v "^spec-"
```

### Compare with Spec Creation

Get spec creation date from frontmatter or file mtime.
Check if any docs modified after spec creation (excluding the spec itself).

**Result**:
- Pass: Docs updated after spec
- Warn: No doc updates found
- Fail: Docs explicitly required but not updated

## Step 10: Calculate Validation Score

Combine all checks into overall status:

**Complete** (all pass):
- Requirements: 100% implemented
- Acceptance Criteria: 100% met
- Files: All expected files modified
- Tests: All test areas covered
- Docs: Updated

**Partial** (most pass, some warn):
- Requirements: >80% implemented
- Acceptance Criteria: >80% met
- Files: Most expected files modified
- Tests: Some tests added
- Docs: May or may not be updated

**Incomplete** (any fail):
- Requirements: <80% implemented
- Acceptance Criteria: <80% met
- Files: Missing critical files
- Tests: No tests added
- Docs: Required but missing

## Step 11: Update Spec Frontmatter

Update the spec file with validation results:

```yaml
---
spec_id: spec-123-feature
issue_number: 123
title: Implement user authentication
type: feature
status: in_progress
validated: true|false|partial
validation_date: 2025-01-15
validation_notes: "Tests incomplete, docs needed"
---
```

Update fields:
- `validated`: true (complete) | "partial" (partial) | false (incomplete)
- `validation_date`: Current date
- `validation_notes`: Summary of issues (if any)
- `status`: Update to reflect current state

## Step 12: Generate Validation Report

Create detailed report:

```markdown
Validation Report: spec-123-feature.md
Issue: #123

Requirements: ✓ 8/8 implemented
  - All functional requirements present
  - All non-functional requirements met

Acceptance Criteria: ✓ 5/6 met
  - ✓ User can register
  - ✓ Email validation works
  - ✓ Password strength enforced
  - ✓ Confirmation email sent
  - ✓ User redirected to dashboard
  - ✗ Password reset not yet implemented

Files Modified: ✓ Expected files changed
  - ✓ src/auth/register.ts: Created
  - ✓ src/models/user.ts: Modified
  - ✓ src/routes/auth.ts: Modified
  - ⚠ tests/auth.test.ts: Partially complete

Tests: ⚠ 2/3 test cases added
  - ✓ Unit tests for registration
  - ✓ Integration tests for auth flow
  - ✗ E2E tests not yet added

Documentation: ✗ Docs not updated
  - No updates to README.md or API docs

Overall: Partial
Issues to address:
  1. Complete password reset functionality
  2. Add E2E tests
  3. Update documentation
```

## Step 13: Return Validation Result

Output structured result as JSON (see SKILL.md).

Include:
- Overall validation status
- Detailed check results
- List of issues (if any)
- Whether spec was updated

## Error Recovery

Handle errors gracefully:

1. **Spec file not found**: Return error, suggest checking path
2. **Parse error**: Return error, check spec format
3. **Git not available**: Warn, skip git-based checks
4. **File system error**: Warn, continue with other checks

## Example Execution

```
Input:
  spec_path: /specs/spec-123-feature.md
  issue_number: 123

Steps:
  1. ✓ Spec file read
  2. ✓ Frontmatter parsed
  3. ✓ Requirements extracted: 8 total
  4. ✓ Acceptance criteria extracted: 6 total, 5 checked
  5. ✓ Expected files extracted: 4 files
  6. ✓ Requirements: 8/8 implemented
     ✓ Acceptance criteria: 5/6 met
  7. ✓ Files: 4/4 modified
  8. ⚠ Tests: 2/3 areas covered
  9. ✗ Docs: Not updated
  10. ✓ Overall: Partial
  11. ✓ Spec frontmatter updated
  12. ✓ Report generated
  13. ✓ Result returned

Output:
  {
    "status": "success",
    "validation_result": "partial",
    "checks": {...},
    "issues": ["E2E tests missing", "Docs not updated"],
    "spec_updated": true
  }
```
