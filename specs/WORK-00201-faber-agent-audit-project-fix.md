---
spec_id: WORK-00201-faber-agent-audit-project-fix
work_id: 201
issue_url: https://github.com/fractary/claude-plugins/issues/201
title: Fix faber-agent audit-project false positive compliance
type: bug
status: draft
created: 2025-12-02
author: jmcwilliam
validated: false
severity: high
source: conversation+issue
---

# Bug Fix Specification: Fix faber-agent audit-project false positive compliance

**Issue**: [#201](https://github.com/fractary/claude-plugins/issues/201)
**Type**: Bug Fix
**Severity**: High
**Status**: Draft
**Created**: 2025-12-02

## Summary

The `/fractary-faber-agent:audit-project` command returns false positive compliance results (100% / 20 of 20 checks passing) when significant architectural issues exist in the audited project. The audit fails to detect missing workflow logging, direct skill command exposure, and non-standard Director command argument patterns.

## Bug Description

### Observed Behavior

The audit-project command reports:
- 100% compliance score (20/20 checks)
- 0 anti-patterns detected
- 5 correct patterns found
- "Exemplary adherence to Fractary architectural standards"

When the following issues actually exist:
1. Manager/Agent doesn't implement workflow change log tracking
2. Workflow-specific skills expose direct commands instead of routing through Director -> Manager
3. Director command's action argument doesn't support comma-separated list of multiple steps
4. Missing standard format for `--agent <workflow_steps>` argument

### Expected Behavior

The audit should:
1. Detect missing workflow logging implementation in Manager agents
2. Flag skills that expose direct commands bypassing the Director pattern
3. Check Director command argument patterns against standards
4. Report non-compliance for recent best practice enhancements
5. Return accurate compliance scores reflecting actual architectural state

### Impact
- **Severity**: High
- **Affected Users**: All users running project audits to verify compliance
- **Affected Features**: Project audit, compliance verification, best practices validation

## Reproduction Steps

1. Run `/fractary-faber-agent:audit-project` on a project with missing workflow logging
2. Observe 100% compliance reported
3. Verify project actually lacks:
   - Workflow change log tracking in Manager
   - Director-only command routing for workflow skills
   - Multi-step action argument support
   - Standard `--agent <workflow_steps>` format

**Frequency**: Always (deterministic)
**Environment**: Any project using faber-agent plugin

## Root Cause Analysis

### Investigation Findings

The audit rules in `plugins/faber-agent/skills/project-auditor/audit-rules/` likely:
1. Missing rules for workflow logging requirements
2. Not checking skill command exposure patterns
3. Not validating Director command argument patterns
4. Not updated with recent best practice enhancements

### Root Cause

The audit rule set is incomplete - it validates basic structural patterns but misses newer requirements:
1. **Workflow logging**: No rule checks for fractary-logs integration in Managers
2. **Command routing**: No rule validates that workflow skills only expose through Director
3. **Argument patterns**: No rule checks Director command supports multi-step actions
4. **Best practices**: Recent enhancements not reflected in audit rules

### Why It Wasn't Caught Earlier

The audit was designed before these best practices were established. Rules were added for initial patterns but not updated as the architecture evolved.

## Technical Analysis

### Affected Components

- `plugins/faber-agent/skills/project-auditor/`: Core audit logic
- `plugins/faber-agent/skills/project-auditor/audit-rules/`: Rule definitions
- `plugins/faber-agent/skills/project-auditor/scripts/`: Audit execution scripts

### Stack Trace
```
N/A - Logic error, not runtime exception
```

### Related Code
- `plugins/faber-agent/skills/project-auditor/SKILL.md`: Skill definition
- `plugins/faber-agent/skills/project-auditor/audit-rules/*.yaml`: Rule definitions
- `plugins/faber-agent/skills/project-auditor/scripts/run-audit.sh`: Audit execution

## Proposed Fix

### Solution Approach

1. **Add workflow logging rules**: Create audit rules to check Manager agents for fractary-logs integration
2. **Add command routing rules**: Verify workflow skills don't expose direct commands
3. **Add argument pattern rules**: Validate Director command supports multi-step actions and standard argument format
4. **Update rule documentation**: Document new rules and expected patterns

### Code Changes Required

- `audit-rules/workflow-logging.yaml`: New rule for workflow log tracking
- `audit-rules/command-routing.yaml`: New rule for Director-only command exposure
- `audit-rules/director-arguments.yaml`: New rule for argument pattern validation
- `SKILL.md`: Update to reference new rules

### Why This Fix Works

By adding explicit rules for the missing checks, the audit will:
1. Detect when Manager agents lack workflow logging
2. Flag skills that bypass Director command routing
3. Validate Director command argument patterns
4. Accurately report compliance against current best practices

### Alternative Solutions Considered

- **Hardcode checks in script**: Less maintainable, violates YAML rule pattern
- **Warning-only mode**: Doesn't fix false positive issue
- **Separate advanced audit**: Fragments audit functionality

## Files to Modify

- `plugins/faber-agent/skills/project-auditor/audit-rules/workflow-logging.yaml`: Add workflow logging rules
- `plugins/faber-agent/skills/project-auditor/audit-rules/command-routing.yaml`: Add command routing rules
- `plugins/faber-agent/skills/project-auditor/audit-rules/director-arguments.yaml`: Add argument pattern rules
- `plugins/faber-agent/skills/project-auditor/SKILL.md`: Document new rules
- `plugins/faber-agent/skills/project-auditor/scripts/run-audit.sh`: Ensure new rules are executed

## Testing Strategy

### Regression Tests

Run existing audit tests to ensure current checks still pass on compliant projects.

### New Test Cases

- `test-missing-workflow-logging`: Verify audit detects missing fractary-logs integration
- `test-direct-skill-commands`: Verify audit flags skills with direct command exposure
- `test-director-argument-patterns`: Verify audit validates multi-step action support
- `test-combined-violations`: Verify audit correctly scores multiple violations

### Manual Testing Checklist

- [ ] Run audit on compliant project - should pass all checks
- [ ] Run audit on project missing workflow logging - should detect and report
- [ ] Run audit on project with direct skill commands - should detect and report
- [ ] Run audit on project with non-standard Director arguments - should detect and report
- [ ] Verify compliance score accurately reflects detected issues
- [ ] Verify anti-pattern count matches detected issues

## Risk Assessment

### Risks of Fix

- **Breaking change**: Existing projects may fail audits that previously passed
  - **Mitigation**: Document new rules, provide migration guidance
- **Over-detection**: Rules may be too strict
  - **Mitigation**: Test against known-good projects before release

### Risks of Not Fixing

Projects with architectural issues will pass audits, undermining trust in the audit system and allowing anti-patterns to proliferate.

## Dependencies

- Understanding of current audit rule format and execution
- Access to known-good and known-bad project examples for testing
- Understanding of fractary-logs integration patterns

## Acceptance Criteria

- [ ] Audit correctly detects missing workflow logging in Manager agents
- [ ] Audit correctly flags skills that expose direct commands
- [ ] Audit correctly validates Director command argument patterns
- [ ] Compliance score accurately reflects detected issues
- [ ] Anti-pattern count matches detected issues
- [ ] Existing compliant projects still pass all checks
- [ ] New rules are documented in SKILL.md

## Prevention Measures

### How to Prevent Similar Bugs

- Establish process to update audit rules when new best practices are added
- Include audit rule updates in definition of done for architecture changes
- Add integration tests that verify audit catches known issues

### Process Improvements

- Create checklist for architecture changes that includes audit rule updates
- Review audit rules quarterly against current best practices
- Add audit validation to CI/CD for architecture-related PRs

## Implementation Notes

The audit system uses YAML-based rules that are processed by the run-audit.sh script. New rules should follow the existing pattern:

```yaml
id: rule-id
name: Human-readable name
description: What this rule checks
severity: error|warning|info
category: architecture|patterns|structure
check:
  type: file|content|structure
  pattern: regex or glob pattern
  expected: what should be found
  message: failure message
```

Consider grouping related new rules in a single file or creating separate files per concern based on existing conventions.
