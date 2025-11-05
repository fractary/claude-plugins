# FABER Integration Guide

This guide describes how to integrate the fractary-spec plugin with the FABER workflow for automatic specification lifecycle management.

## Overview

The fractary-spec plugin integrates with three FABER phases:

1. **Architect Phase**: Generate specification from issue
2. **Evaluate Phase**: Validate implementation against spec
3. **Release Phase**: Archive specification to cloud

## Configuration

### Enable in .faber.config.toml

```toml
[workflow]
phases = ["frame", "architect", "build", "evaluate", "release"]

[workflow.architect]
generate_spec = true
spec_plugin = "fractary-spec"
spec_template = "auto"  # or "basic", "feature", "infrastructure", "api", "bug"

[workflow.evaluate]
validate_spec = true
validation_required = false  # If true, blocks on incomplete validation

[workflow.release]
archive_spec = true
archive_before_branch_delete = true
check_docs_updated = "warn"  # "warn", "error", "skip"
```

## Phase Integration

### Frame Phase

**No spec integration**

Frame phase fetches issue and sets up environment. Spec generation happens in Architect phase.

### Architect Phase

**Generate Specification**

When `generate_spec = true`:

```markdown
During Architect phase, generate specification from issue:

Use the @agent-fractary-spec:spec-manager agent to generate spec:
{
  "operation": "generate",
  "issue_number": "{{issue_number}}",
  "template": "{{spec_template}}"
}
```

**What Happens**:
1. Issue data fetched from GitHub
2. Work type classified (or template from config)
3. Spec generated from template
4. Saved to /specs directory
5. Linked to GitHub issue via comment

**Output**:
- Spec file: `/specs/spec-{issue}-{slug}.md`
- GitHub comment with spec location
- Ready for Build phase

**Multi-Phase Support**:

For large issues, architect can generate multiple specs:

```markdown
Generate Phase 1 spec:
{
  "operation": "generate",
  "issue_number": "{{issue_number}}",
  "phase": 1,
  "title": "Authentication"
}

Generate Phase 2 spec:
{
  "operation": "generate",
  "issue_number": "{{issue_number}}",
  "phase": 2,
  "title": "OAuth Integration"
}
```

### Build Phase

**No direct integration**

Build phase implements following the spec. Spec available as reference at `/specs/spec-{issue}-{slug}.md`.

**Best Practice**: Reference spec during implementation, update acceptance criteria checkboxes as work progresses.

### Evaluate Phase

**Validate Implementation**

When `validate_spec = true`:

```markdown
During Evaluate phase, validate implementation against spec:

Use the @agent-fractary-spec:spec-manager agent to validate:
{
  "operation": "validate",
  "issue_number": "{{issue_number}}"
}
```

**What Happens**:
1. Spec file read and parsed
2. Requirements coverage checked
3. Acceptance criteria verified
4. Files modified validated
5. Tests checked
6. Documentation checked
7. Validation status updated in spec
8. Report generated

**Validation Results**:

- **Complete** ✓: All checks pass → Proceed to Release
- **Partial** ⚠: Most pass → Prompt user or proceed based on config
- **Incomplete** ✗: Critical failures → Return to Build

**Configuration**:

```toml
[workflow.evaluate]
validate_spec = true
validation_required = false  # If true, blocks on partial/incomplete
validation_retry_build = true  # If true, loops back to Build on incomplete
```

**Validation Loop**:

If `validation_retry_build = true` and validation incomplete:

```
Evaluate Phase
    ↓
Validate Spec
    ↓
Incomplete? → Return to Build Phase
    ↓
Complete? → Proceed to Release Phase
```

### Release Phase

**Archive Specification**

When `archive_spec = true`:

```markdown
During Release phase, archive specifications:

Use the @agent-fractary-spec:spec-manager agent to archive:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}",
  "check_docs": true
}
```

**What Happens**:
1. All specs for issue collected
2. Pre-archive checks performed
3. Specs uploaded to cloud storage
4. Archive index updated
5. GitHub issue commented with archive URLs
6. GitHub PR commented with archive URLs
7. Local specs removed
8. Git commit created

**Pre-Archive Checks**:

Based on config:

```toml
[workflow.release]
archive_spec = true
check_docs_updated = "warn"  # "warn", "error", "skip"
```

- `"skip"`: No docs check
- `"warn"`: Warn if not updated, continue
- `"error"`: Block if not updated

**Timing**:

Archive happens:
- After PR created/merged (based on config)
- Before branch deletion (if `archive_before_branch_delete = true`)
- After documentation updated

**Sequence**:

```
Release Phase
    ↓
Create PR
    ↓
Merge PR
    ↓
Update documentation
    ↓
Archive specifications ← Here
    ↓
Delete branch
    ↓
Close issue
```

## Unified Archive Command

Create `/faber:archive` command for archiving both specs and logs:

```markdown
---
name: faber:archive
description: Archive all artifacts for completed work
---

Archive all specs and logs for a completed issue.

Usage:
  /faber:archive <issue_number>

This command:
1. Archives all specifications via fractary-spec
2. Archives all logs via fractary-logs
3. Updates GitHub issue with archive locations
4. Cleans local context

Example:
  /faber:archive 123
```

Implementation:

```markdown
Invoke fractary-spec:archive:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}"
}

Invoke fractary-logs:archive:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}"
}

Comment on GitHub with all archive locations.
```

## Workflow Example

### Automated FABER Run

```bash
/faber run 123 --autonomy guarded
```

**Architect Phase**:
```
Fetching issue #123...
Generating specification...
✓ Spec created: /specs/spec-123-feature.md
✓ GitHub comment added
→ Proceeding to Build
```

**Build Phase**:
```
Implementing based on spec...
[... development work ...]
→ Proceeding to Evaluate
```

**Evaluate Phase**:
```
Running tests...
✓ Tests passed

Validating against spec...
Requirements: ✓ 8/8
Acceptance Criteria: ✓ 6/6
Files: ✓ All modified
Tests: ✓ Added
Docs: ⚠ Not updated

Overall: Partial

Prompt: Continue to Release? [y/N]
```

**Release Phase**:
```
Creating PR...
✓ PR created: #456

Merging PR...
✓ PR merged

Updating documentation...
✓ Docs updated

Archiving specifications...
✓ spec-123-feature.md → cloud storage
✓ Archive index updated
✓ GitHub comments added
✓ Local cleanup complete

Deleting branch...
✓ Branch deleted

Closing issue...
✓ Issue closed

✅ FABER workflow complete!
```

## Configuration Examples

### Strict Workflow

Require full validation and docs update:

```toml
[workflow.evaluate]
validate_spec = true
validation_required = true
validation_retry_build = true

[workflow.release]
archive_spec = true
check_docs_updated = "error"
archive_before_branch_delete = true
```

### Flexible Workflow

Allow partial validation, warn on docs:

```toml
[workflow.evaluate]
validate_spec = true
validation_required = false

[workflow.release]
archive_spec = true
check_docs_updated = "warn"
```

### Manual Archival

Disable automatic archival:

```toml
[workflow.release]
archive_spec = false
```

Then manually:
```bash
/fractary-spec:archive 123
```

## Multi-Spec Workflows

For complex issues with phases:

**Architect Phase**:
```markdown
Generate Phase 1 spec (Authentication):
{
  "operation": "generate",
  "issue_number": "123",
  "phase": 1,
  "title": "Authentication"
}

Generate Phase 2 spec (OAuth):
{
  "operation": "generate",
  "issue_number": "123",
  "phase": 2,
  "title": "OAuth Integration"
}
```

**Build Phase**:
Implement both phases following specs.

**Evaluate Phase**:
```markdown
Validate all phases:
{
  "operation": "validate",
  "issue_number": "123"
}
```

**Release Phase**:
```markdown
Archive all phases together:
{
  "operation": "archive",
  "issue_number": "123"
}
```

All specs archived atomically.

## Error Handling

### Spec Generation Failure

If spec generation fails in Architect:
- Log error
- Continue without spec (FABER can still proceed)
- OR abort workflow (based on config)

### Validation Failure

If validation incomplete in Evaluate:
- Log validation report
- If `validation_required = true`: Return to Build
- If `validation_required = false`: Proceed with warning

### Archival Failure

If archival fails in Release:
- Log error
- Local specs remain
- FABER completes (archival non-critical)
- User can manually retry: `/fractary-spec:archive 123`

## Best Practices

### Architect Phase

1. Generate spec early
2. Review spec before Build
3. Use multi-spec for large issues

### Build Phase

1. Reference spec regularly
2. Update acceptance criteria checkboxes
3. Keep spec in sync with implementation

### Evaluate Phase

1. Run validation before Release
2. Address validation issues
3. Don't skip validation checks

### Release Phase

1. Update docs before archival
2. Review pre-archive warnings
3. Verify archival completed
4. Check GitHub comments

## Monitoring

### FABER Status

```bash
/faber status
```

Shows current phase and spec status:

```
Workflow Status: Issue #123

Phase: Architect
  ✓ Spec generated: /specs/spec-123-feature.md

Phase: Build
  → In progress

Phase: Evaluate
  - Pending

Phase: Release
  - Pending
```

### Spec Status

Check validation status:

```bash
/fractary-spec:validate 123
```

Check archival status:

```bash
cat /specs/.archive-index.json | jq '.archives[] | select(.issue_number == "123")'
```

## Integration Testing

Test full workflow:

```bash
# 1. Initialize
/fractary-spec:init

# 2. Run FABER with specs
/faber run 123 --autonomy guarded

# 3. Verify spec lifecycle
ls /specs/spec-123-*.md  # Should be archived (not exist)
/fractary-spec:read 123  # Should read from cloud

# 4. Check GitHub
# - Issue should have spec creation comment
# - Issue should have archive comment
# - PR should have archive comment
```

## Troubleshooting

### Spec Not Generated

Check config:
```toml
[workflow.architect]
generate_spec = true  # Must be true
```

Check logs:
```
Architect phase: Spec generation enabled?
```

### Validation Not Running

Check config:
```toml
[workflow.evaluate]
validate_spec = true  # Must be true
```

### Archival Not Running

Check config:
```toml
[workflow.release]
archive_spec = true  # Must be true
```

Check pre-conditions:
- Issue closed?
- PR merged?

### Specs Still in Local

Archival may have failed. Check:
```bash
cat /specs/.archive-index.json
```

If not in index, retry:
```bash
/fractary-spec:archive 123
```

## Advanced Configuration

### Custom Validation Rules

```toml
[workflow.evaluate.spec_validation]
require_all_criteria = true
require_all_tests = true
require_docs = true
min_requirements_percentage = 100
```

### Custom Archival Rules

```toml
[workflow.release.spec_archival]
archive_timing = "after_pr_merge"  # or "after_docs_update", "after_branch_delete"
require_validation = true
require_docs_update = true
```

## Version Compatibility

- FABER v2.0+: Full support
- FABER v1.x: Manual integration required

## Migration

### From Manual Specs

If manually managing specs:
1. Move specs to `/specs` directory
2. Rename to `spec-{issue}-{slug}.md`
3. Add frontmatter
4. Initialize plugin: `/fractary-spec:init`
5. Enable FABER integration

### From Other Spec Systems

Create migration script to:
1. Convert to fractary-spec format
2. Add frontmatter
3. Initialize archive index
