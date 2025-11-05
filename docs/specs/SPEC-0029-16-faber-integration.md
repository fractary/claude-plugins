# SPEC-0029-16: FABER Integration

**Issue**: #29
**Phase**: 5 (FABER Integration)
**Dependencies**: All previous specs (0029-01 through 0029-15)
**Status**: Draft
**Created**: 2025-01-15

## Overview

Integrate fractary-docs, fractary-spec, and fractary-logs plugins throughout the FABER workflow. This creates a complete documentation and archival lifecycle for all FABER-managed work.

## FABER Phase Integration Summary

```
Frame Phase
  └─ Start session capture (fractary-logs)

Architect Phase
  ├─ Generate spec (fractary-spec)
  └─ Create design docs (fractary-docs)

Build Phase
  └─ Capture build logs (fractary-logs)

Evaluate Phase
  ├─ Validate spec (fractary-spec)
  ├─ Capture test logs (fractary-logs)
  └─ Generate test reports (fractary-docs)

Release Phase
  ├─ Update documentation (fractary-docs)
  ├─ Generate deployment docs (fractary-docs)
  ├─ Archive specs (fractary-spec)
  ├─ Archive logs (fractary-logs)
  └─ Create PR and close issue
```

## Detailed Phase Integration

### Frame Phase

**Current**:
1. Fetch issue from work tracker
2. Classify work type
3. Setup environment

**Enhanced**:
```markdown
1. Fetch issue from work tracker
2. Classify work type
3. Setup environment
4. **Start session capture**:
   - /fractary-logs:capture {{issue_number}}
   - All subsequent conversation logged
```

### Architect Phase

**Current**:
1. Design solution
2. Create specification

**Enhanced**:
```markdown
1. Design solution
2. **Generate specification** (fractary-spec):
   - Use @agent-fractary-spec:spec-manager
   - Generate from issue: /fractary-spec:generate {{issue_number}}
   - Comment on issue with spec location
3. **Create design docs** (fractary-docs, optional):
   - For complex features: generate ADR
   - For infrastructure: generate design doc
   - Use @agent-fractary-docs:docs-manager
```

**Configuration**:
```toml
[workflow.architect]
generate_spec = true
spec_template = "auto"  # auto-detect based on work type
generate_adr = false    # optional, for architectural decisions
```

### Build Phase

**Current**:
1. Implement solution
2. Follow specification

**Enhanced**:
```markdown
1. Implement solution (following spec)
2. **Capture build logs** (fractary-logs):
   - Compilation logs → /logs/builds/{{issue}}-build.log
   - Test execution → /logs/builds/{{issue}}-test.log
   - Errors/debugging → /logs/debug/{{issue}}-debug.log
```

**Configuration**:
```toml
[workflow.build]
capture_build_logs = true
capture_test_logs = true
log_level = "info"
```

### Evaluate Phase

**Current**:
1. Run tests
2. Review implementation
3. Check quality

**Enhanced**:
```markdown
1. Run tests
2. **Validate against spec** (fractary-spec):
   - Use @agent-fractary-spec:spec-manager
   - /fractary-spec:validate {{issue_number}}
   - Check all acceptance criteria met
3. **Generate test report** (fractary-docs):
   - Use @agent-fractary-docs:docs-manager
   - Generate from test results
   - Include coverage, failures, performance
4. Review implementation

If validation fails:
  - Return to Build phase
  - Update spec if requirements changed
```

**Configuration**:
```toml
[workflow.evaluate]
validate_spec = true
require_all_criteria_met = false  # warn vs block
generate_test_report = true
```

### Release Phase

**Current**:
1. Create PR
2. Merge
3. Close issue

**Enhanced**:
```markdown
1. **Update documentation** (fractary-docs):
   - Update current state docs (NOT specs)
   - Update API docs if changed
   - Update architecture diagrams
   - Use @agent-fractary-docs:docs-manager
2. **Generate deployment doc** (fractary-docs, optional):
   - For infrastructure changes
   - Record what was deployed
3. Create PR
4. Merge PR
5. **Archive specs** (fractary-spec):
   - Check docs updated (warn if not)
   - Upload to cloud via fractary-file
   - Comment on issue/PR
   - Remove from local
6. **Archive logs** (fractary-logs):
   - Collect all logs for issue
   - Compress large logs
   - Upload to cloud
   - Comment on issue/PR
   - Remove from local
7. Delete branch
8. Close issue
```

**Configuration**:
```toml
[workflow.release]
update_documentation = "prompt"  # prompt|auto|skip
generate_deployment_doc = false
archive_specs = true
archive_logs = true
check_docs_updated = "warn"  # warn|block|skip
```

## Unified Archive Command

Create `/faber:archive` command that archives everything:

**commands/archive.md**:
```markdown
---
name: faber:archive
description: Archive all artifacts for completed FABER workflow
---

# Archive FABER Workflow

Archive all specifications, logs, and sessions for a completed issue.

## Usage

    /faber:archive <issue_number>

## What Gets Archived

1. **Specifications** (via fractary-spec):
   - All specs for the issue
   - Upload to cloud storage
   - Remove from local

2. **Logs** (via fractary-logs):
   - Session logs (conversations)
   - Build logs
   - Test logs
   - Debug logs
   - Upload to cloud storage
   - Remove from local

3. **GitHub Updates**:
   - Comment on issue with archive URLs
   - Comment on PR with archive URLs

4. **Local Cleanup**:
   - Remove archived files
   - Update archive indexes
   - Commit index changes

## Example

    /faber:archive 123

    Archiving artifacts for issue #123...

    Specs:
    ✓ Collected 2 specifications
    ✓ Uploaded to cloud
    ✓ Updated index

    Logs:
    ✓ Collected 4 logs (1 session, 2 builds, 1 debug)
    ✓ Compressed 1 large log
    ✓ Uploaded to cloud
    ✓ Updated index

    GitHub:
    ✓ Commented on issue #123
    ✓ Commented on PR #456

    Cleanup:
    ✓ Removed local files
    ✓ Committed index updates

    Archive complete! All artifacts permanently stored.

## Options

    --skip-specs: Don't archive specifications
    --skip-logs: Don't archive logs
    --force: Skip pre-archive checks

## Pre-Archive Checks

Before archiving, the command checks:
- Is issue closed or PR merged?
- Is documentation updated? (warns if not)
- Are specs validated? (warns if not)

You'll be prompted to confirm if warnings are present.
```

## Configuration File Updates

### .faber.config.toml

Add new sections:

```toml
[plugins]
docs = "fractary-docs"
spec = "fractary-spec"
logs = "fractary-logs"
file = "fractary-file"

[workflow.architect]
generate_spec = true
spec_template = "auto"  # auto|basic|infrastructure|api|feature
generate_adr = false
adr_threshold = "architectural"  # when to generate ADR

[workflow.build]
capture_build_logs = true
capture_test_logs = true
log_level = "info"

[workflow.evaluate]
validate_spec = true
require_all_criteria_met = false
generate_test_report = true

[workflow.release]
update_documentation = "prompt"  # prompt|auto|skip
generate_deployment_doc = false
archive_specs = true
archive_logs = true
check_docs_updated = "warn"  # warn|block|skip

[documentation]
output_paths = "/docs"
adrs = "/docs/architecture/adrs"
designs = "/docs/architecture/designs"

[specs]
local_path = "/specs"
archive_on_release = true

[logs]
local_path = "/logs"
retention_days = 30
archive_on_release = true
session_capture = "auto"  # auto|manual|off
```

## Agent Integration Patterns

### From FABER Architect Phase

```markdown
Use the @agent-fractary-spec:spec-manager agent to generate spec:
{
  "operation": "generate",
  "issue_number": "{{issue_number}}",
  "template": "{{work_type}}",
  "link_to_issue": true
}
```

### From FABER Evaluate Phase

```markdown
Use the @agent-fractary-spec:spec-manager agent to validate:
{
  "operation": "validate",
  "issue_number": "{{issue_number}}"
}

If validation reports incomplete criteria:
  - Review gaps with user
  - Update implementation or spec as needed
  - Re-validate before proceeding
```

### From FABER Release Phase

```markdown
Use the @agent-fractary-docs:docs-manager agent to update docs:
{
  "operation": "update",
  "docs_type": "current_state",
  "changes": "{{summary_of_changes}}"
}

Use the @agent-fractary-spec:spec-manager agent to archive specs:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}",
  "check_docs": true
}

Use the @agent-fractary-logs:log-manager agent to archive logs:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}"
}
```

## Success Criteria

- [ ] Session capture in Frame phase
- [ ] Spec generation in Architect phase
- [ ] Build/test log capture during Build phase
- [ ] Spec validation in Evaluate phase
- [ ] Documentation updates in Release phase
- [ ] Unified /faber:archive command
- [ ] Configuration options in .faber.config.toml
- [ ] All phases integrated and tested

## Timeline

**Estimated**: 1 week

## Next Steps

- **SPEC-0029-17**: FABER archive workflow details
- **SPEC-0029-18**: Migration strategy
- **SPEC-0029-19**: Documentation plan
