# SPEC-0029-09: Spec Lifecycle Management

**Issue**: #29
**Phase**: 3 (fractary-spec Plugin)
**Dependencies**: SPEC-0029-08
**Status**: Draft
**Created**: 2025-01-15

## Overview

Implement spec-generator and spec-validator skills to manage the active lifecycle of specifications: creation from issues, validation against implementation, and status tracking.

## Spec Lifecycle States

```
Draft → In Progress → Validated → Archived
  ↓          ↓            ↓           ↓
Created   Building    Complete   Cloud Storage
```

## spec-generator Skill

### Generation Process

1. **Fetch Issue**: Get issue details from GitHub/Jira/Linear via fractary-work
2. **Classify Type**: Determine spec template (bug, feature, infrastructure)
3. **Extract Requirements**: Parse issue body for requirements
4. **Generate Spec**: Fill template with issue data
5. **Save Local**: Write to `/specs/spec-{issue}-{slug}.md`
6. **Link to Issue**: Comment on GitHub with spec location

### Issue Parsing

Extract from issue body:
- Title → Spec title
- Description → Summary
- Acceptance criteria (checklist items) → Acceptance criteria section
- Labels → Tags/type
- Assignees → Author field

### Multi-Spec Support

For large issues requiring multiple phases:

```bash
# Generate phase 1
/fractary-spec:generate 123 --phase 1 --title "User Authentication"

# Generate phase 2
/fractary-spec:generate 123 --phase 2 --title "OAuth Integration"

# Results:
# /specs/spec-123-phase1-user-auth.md
# /specs/spec-123-phase2-oauth.md
```

### Templates by Work Type

- **bug**: Focus on reproduction steps, root cause, fix approach
- **feature**: Focus on user stories, acceptance criteria, implementation
- **infrastructure**: Focus on architecture, resources, deployment
- **refactor**: Focus on current state, improvements, migration

## spec-validator Skill

### Validation Checks

1. **Requirements Coverage**: Are all requirements implemented?
2. **Acceptance Criteria**: Are all criteria met?
3. **Files Modified**: Were expected files changed?
4. **Tests Added**: Does testing strategy match implementation?
5. **Documentation Updated**: Are docs current?

### Validation Process

```bash
/fractary-spec:validate 123

# Output:
Validating spec-123-user-auth.md...

Requirements: ✓ 8/8 implemented
Acceptance Criteria: ✓ 5/5 met
Files Modified: ✓ Expected files changed
Tests: ⚠ 2/3 test cases added
Documentation: ✗ Docs not updated

Overall: Partial - address items above before archiving
```

### Validation Status

Update spec front matter:
```yaml
validated: true|false|partial
validation_date: "2025-01-15"
validation_notes: "Tests incomplete, docs needed"
```

## Commands

### /fractary-spec:generate

```markdown
Generate specification from GitHub issue

Usage:
  /fractary-spec:generate <issue_number> [--phase <n>] [--title "<title>"]

Examples:
  /fractary-spec:generate 123
  /fractary-spec:generate 123 --phase 1 --title "Phase 1: Auth"
```

### /fractary-spec:validate

```markdown
Validate implementation against specification

Usage:
  /fractary-spec:validate <issue_number> [--phase <n>]

Examples:
  /fractary-spec:validate 123
  /fractary-spec:validate 123 --phase 1
```

## GitHub Integration

### Spec Creation Comment

```markdown
📋 Specification Created

Specification generated for this issue:
- [spec-123-user-auth.md](/specs/spec-123-user-auth.md)

This spec will guide implementation and be validated before archival.
```

### Validation Comment

```markdown
✅ Specification Validated

Implementation validated against spec:
- Requirements: ✓ Complete
- Acceptance Criteria: ✓ Met
- Tests: ✓ Added
- Documentation: ✓ Updated

Ready for archival after PR merge.
```

## Success Criteria

- [ ] Generate specs from GitHub issues
- [ ] Support multi-spec per issue
- [ ] Classify work type automatically
- [ ] Validate implementation against spec
- [ ] Update spec status
- [ ] Comment on issues with spec location
- [ ] Templates for all work types

## Timeline

**Estimated**: 1 week

## Next Steps

- **SPEC-0029-10**: Archive workflow implementation
