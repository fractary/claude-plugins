# SPEC-00029-11: Spec FABER Integration

**Issue**: #29
**Phase**: 3 (fractary-spec Plugin)
**Dependencies**: SPEC-00029-08, SPEC-00029-09, SPEC-00029-10
**Status**: Draft
**Created**: 2025-01-15

## Overview

Integrate fractary-spec plugin with FABER workflow to automate spec generation in Architect phase and spec archival in Release phase.

## FABER Phase Integration

### Frame Phase
- Issue fetched and linked to workflow session

### Architect Phase → Spec Generation
```
FABER Architect Phase
    ↓
Invoke fractary-spec:generate <issue_number>
    ↓
Spec created: /specs/spec-{issue}-{slug}.md
    ↓
Comment on issue with spec location
    ↓
Proceed to Build phase with spec as guide
```

### Build Phase
- Implementation follows spec
- Spec available as reference

### Evaluate Phase → Spec Validation
```
FABER Evaluate Phase
    ↓
Run tests
    ↓
Invoke fractary-spec:validate <issue_number>
    ↓
Check implementation against spec
    ↓
If validated: Proceed to Release
If not validated: Return to Build with gaps identified
```

### Release Phase → Spec Archival
```
FABER Release Phase
    ↓
Create PR
    ↓
Merge PR
    ↓
Update documentation (permanent state)
    ↓
Invoke fractary-spec:archive <issue_number>
    ├─ Upload specs to cloud
    ├─ Update archive index
    ├─ Comment on issue/PR
    └─ Remove from local
    ↓
Delete branch
    ↓
Close issue
    ↓
Complete
```

## FABER Configuration

Update `.faber.config.toml`:

```toml
[workflow]
phases = ["frame", "architect", "build", "evaluate", "release"]

[workflow.architect]
generate_spec = true
spec_plugin = "fractary-spec"

[workflow.evaluate]
validate_spec = true

[workflow.release]
archive_spec = true
archive_before_branch_delete = true
check_docs_updated = "warn"
```

## Integration Commands

### Architect Phase Command

```markdown
During Architect phase, generate specification:

Use the @agent-fractary-spec:spec-manager agent to generate spec:
{
  "operation": "generate",
  "issue_number": "{{issue_number}}",
  "template": "{{work_type}}"
}
```

### Evaluate Phase Command

```markdown
During Evaluate phase, validate implementation:

Use the @agent-fractary-spec:spec-manager agent to validate:
{
  "operation": "validate",
  "issue_number": "{{issue_number}}"
}
```

### Release Phase Command

```markdown
During Release phase, archive specifications:

Use the @agent-fractary-spec:spec-manager agent to archive:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}",
  "check_docs": true
}
```

## Unified Archive Command

Create `/faber:archive <issue>` that archives both specs AND logs:

```markdown
---
name: faber:archive
description: Archive all specs and logs for completed work
---

Archive all artifacts for a completed issue (specs, logs, sessions).

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

## Success Criteria

- [ ] Spec generation in Architect phase
- [ ] Spec validation in Evaluate phase
- [ ] Spec archival in Release phase
- [ ] FABER config options for spec workflow
- [ ] Unified /faber:archive command
- [ ] Documentation updated after archival

## Timeline

**Estimated**: 3-4 days

## Next Steps

- **SPEC-00029-12**: Begin Phase 4 (fractary-logs plugin)
