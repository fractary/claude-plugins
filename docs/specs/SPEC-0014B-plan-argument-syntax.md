# Implementation Plan: Command Argument Syntax Standardization

**Issue:** Inconsistent argument parsing across plugins
**Solution:** Adopt space-separated syntax (`--flag value`) as standard
**Timeline:** 5-7 days
**Status:** Ready to implement

## Overview

Standardize all command argument parsing to use space-separated syntax (`--flag value`) instead of mixed patterns. This affects 3 plugins (faber-cloud, helm, helm-cloud) that currently use equals syntax (`--flag=value`).

## Goals

1. ✅ Unified syntax across all plugins
2. ✅ Clear documentation with quote handling
3. ✅ Consistent user experience
4. ✅ Maintainable parsing logic
5. ✅ Helpful error messages

## Plugins Affected

### No Changes Needed (Already Compliant)
- ✅ `faber` - Uses space-separated syntax
- ✅ `work` - Uses space-separated syntax with explicit docs
- ✅ `repo` - Uses space-separated syntax with explicit docs
- ✅ `codex` - Uses space-separated syntax
- ✅ `faber-article` - Uses space-separated syntax

### Require Migration (Currently Use Equals)
- ⚠️ `faber-cloud` - 13 commands to update
- ⚠️ `helm` - 4 commands to update
- ⚠️ `helm-cloud` - 4 commands to update

## Phase 1: Documentation Standards (Day 1)

### Task 1.1: Create Standard Document ✅ COMPLETE
- [x] Created `docs/standards/COMMAND-ARGUMENT-SYNTAX.md`
- [x] Defined space-separated syntax as standard
- [x] Documented quote rules
- [x] Provided examples and templates

### Task 1.2: Update Plugin Standards Document
- [ ] Add reference to `COMMAND-ARGUMENT-SYNTAX.md` in `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`
- [ ] Add section on argument parsing requirements
- [ ] Update command development guidelines

**Estimated Time:** 1 hour

**Deliverable:**
- Updated `docs/standards/FRACTARY-PLUGIN-STANDARDS.md` with argument syntax section

## Phase 2: Update faber-cloud Plugin (Days 2-3)

### Task 2.1: Update Command Documentation

**Commands to update (13 total):**
1. `commands/deploy-apply.md`
2. `commands/deploy-plan.md`
3. `commands/init.md`
4. `commands/configure.md`
5. `commands/validate.md`
6. `commands/test.md`
7. `commands/debug.md`
8. `commands/design.md`
9. `commands/status.md`
10. `commands/resources.md`
11. `commands/teardown.md`
12. `commands/manage.md`
13. `commands/director.md`

**For each command:**
1. Update `argument-hint` from `--flag=<value>` to `--flag <value>`
2. Add `<ARGUMENT_SYNTAX>` section (use template from standard doc)
3. Update all examples to use space-separated syntax
4. Add explicit quote usage examples

**Example change:**

Before:
```markdown
---
argument-hint: "--env=<environment> [--auto-approve]"
---

# Examples
/fractary-faber-cloud:deploy-apply --env=test
```

After:
```markdown
---
argument-hint: "--env <environment> [--auto-approve]"
---

<ARGUMENT_SYNTAX>
This command follows standard space-separated syntax.
Multi-word values MUST use quotes: `--description "multi word"`
</ARGUMENT_SYNTAX>

# Examples
/fractary-faber-cloud:deploy-apply --env test
```

**Estimated Time:** 4 hours (13 commands × ~15-20 min each)

**Deliverable:**
- 13 updated command markdown files with consistent syntax

### Task 2.2: Update Agent Documentation

**Files to update:**
1. `agents/infra-manager.md` - Update command examples throughout

**Changes:**
1. Update all command examples from equals to space-separated
2. Verify skill invocation examples
3. Update workflow examples

**Estimated Time:** 1 hour

**Deliverable:**
- Updated agent with consistent command examples

### Task 2.3: Update Skill Documentation

**Skills with command examples:**
1. `skills/infra-deployer/SKILL.md`
2. `skills/infra-planner/SKILL.md`
3. `skills/infra-validator/SKILL.md`
4. `skills/infra-configurator/SKILL.md`
5. `skills/infra-designer/SKILL.md`
6. Other skills with command examples

**Changes:**
- Update any command examples in skills to use space-separated syntax
- Update workflow documentation

**Estimated Time:** 2 hours

**Deliverable:**
- Updated skill documentation with consistent examples

### Task 2.4: Update Parsing Scripts

**Scripts to update:**
1. `skills/cloud-common/scripts/generate-deployed-doc.sh`
2. `skills/cloud-common/scripts/log-resolution.sh`
3. `skills/cloud-common/scripts/update-registry.sh`
4. Any other scripts that parse command arguments

**Changes for each script:**

Before:
```bash
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment=*)
            ENVIRONMENT="${1#*=}"
            shift
            ;;
    esac
done
```

After:
```bash
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --*=*)
            # Reject equals syntax with helpful error
            echo "Error: Use space-separated syntax" >&2
            echo "Use: ${1%%=*} <value>" >&2
            echo "Not: $1" >&2
            exit 2
            ;;
    esac
done
```

**Estimated Time:** 2 hours

**Deliverable:**
- Updated parsing scripts with space-separated syntax
- Helpful error messages for equals syntax

### Task 2.5: Update README and Documentation

**Files to update:**
1. `plugins/faber-cloud/README.md`
2. `plugins/faber-cloud/docs/guides/getting-started.md`
3. `plugins/faber-cloud/docs/guides/user-guide.md`
4. `plugins/faber-cloud/docs/reference/commands.md`
5. Any other documentation with command examples

**Changes:**
- Update all command examples
- Update quick-start sections
- Update troubleshooting examples

**Estimated Time:** 2 hours

**Deliverable:**
- Consistent documentation across all faber-cloud docs

### Task 2.6: Test faber-cloud Commands

**Test each command:**
1. Single-word flag values
2. Multi-word flag values with quotes
3. Boolean flags
4. Multiple flags
5. Equals syntax (should reject with error)

**Test cases:**
```bash
# Should work ✅
/fractary-faber-cloud:deploy-apply --env test
/fractary-faber-cloud:deploy-apply --env test --auto-approve
/fractary-faber-cloud:design "S3 bucket with versioning"

# Should error ❌
/fractary-faber-cloud:deploy-apply --env=test
/fractary-faber-cloud:design S3 bucket with versioning
```

**Estimated Time:** 2 hours

**Deliverable:**
- All faber-cloud commands working with new syntax
- Helpful error messages for incorrect syntax

**Total Phase 2 Time:** 2 days

## Phase 3: Update helm Plugin (Day 4)

### Task 3.1: Update Command Documentation

**Commands to update (4 total):**
1. `commands/status.md`
2. `commands/issues.md`
3. `commands/dashboard.md`
4. `commands/escalate.md`

**For each command:**
1. Update `argument-hint` from `--flag=<value>` to `--flag <value>`
2. Add `<ARGUMENT_SYNTAX>` section
3. Update examples

**Estimated Time:** 1 hour

### Task 3.2: Update Agent Documentation

**Files to update:**
1. `agents/helm-director.md` (if exists)
2. Any other agent files with command examples

**Estimated Time:** 30 minutes

### Task 3.3: Update Parsing Logic

**Files to review/update:**
- Any scripts in `skills/` that parse command arguments

**Estimated Time:** 1 hour

### Task 3.4: Test helm Commands

**Estimated Time:** 1 hour

**Total Phase 3 Time:** 1 day

## Phase 4: Update helm-cloud Plugin (Day 4)

### Task 4.1: Update Command Documentation

**Commands to update (4 total):**
1. `commands/health.md`
2. `commands/investigate.md`
3. `commands/audit.md`
4. `commands/remediate.md`

**For each command:**
1. Update `argument-hint`
2. Add `<ARGUMENT_SYNTAX>` section
3. Update examples

**Estimated Time:** 1 hour

### Task 4.2: Update Agent Documentation

**Estimated Time:** 30 minutes

### Task 4.3: Update Parsing Logic

**Estimated Time:** 1 hour

### Task 4.4: Test helm-cloud Commands

**Estimated Time:** 1 hour

**Total Phase 4 Time:** 1 day (can overlap with Phase 3)

## Phase 5: Create Shared Parsing Library (Day 5)

### Task 5.1: Create Standard Parser

**File:** `docs/standards/scripts/parse-arguments.sh`

**Contents:**
```bash
#!/bin/bash

# Standard argument parser for Fractary plugins
# Usage: source this file and use parse_* functions

# Parse flags and positional arguments
# Rejects equals syntax with helpful errors
# Handles multi-word values with quotes
# Validates boolean flags

# Function implementations...
```

**Features:**
- Reusable parsing logic
- Error detection for equals syntax
- Helpful error messages
- Quote handling
- Type validation

**Estimated Time:** 3 hours

**Deliverable:**
- Reusable parsing library with tests

### Task 5.2: Update Plugin Template

**File:** `docs/standards/templates/command.md` (if exists)

**Changes:**
- Add parsing template using standard syntax
- Reference shared library
- Include ARGUMENT_SYNTAX section template

**Estimated Time:** 1 hour

**Deliverable:**
- Updated command template for new plugins

## Phase 6: Integration Testing (Day 6)

### Task 6.1: Test All Updated Commands

**Test matrix:**
- [ ] All faber-cloud commands (13)
- [ ] All helm commands (4)
- [ ] All helm-cloud commands (4)

**Test cases for each:**
1. Single-word values
2. Multi-word values with quotes
3. Boolean flags
4. Multiple flags in various orders
5. Special characters (URLs, paths)
6. Equals syntax rejection

**Estimated Time:** 4 hours

**Deliverable:**
- Test results document
- List of any issues found

### Task 6.2: Documentation Review

**Review all updated documentation:**
- [ ] Commands use correct syntax
- [ ] Examples are accurate
- [ ] ARGUMENT_SYNTAX sections present
- [ ] README files updated
- [ ] Guide documents updated

**Estimated Time:** 2 hours

**Deliverable:**
- Documentation review checklist

### Task 6.3: Cross-Reference Check

**Verify:**
- [ ] Agent examples match command syntax
- [ ] Skill documentation matches command syntax
- [ ] README examples match command syntax
- [ ] Quick-start guides match command syntax

**Estimated Time:** 2 hours

**Deliverable:**
- Cross-reference validation report

## Phase 7: Final Review and Commit (Day 7)

### Task 7.1: Final Testing

Run comprehensive tests on all affected plugins:
```bash
# Test each command category
# Verify error messages
# Check edge cases
```

**Estimated Time:** 2 hours

### Task 7.2: Update CHANGELOG

Add entry for each affected plugin:
```markdown
## [Unreleased]

### Changed
- **BREAKING**: Updated command argument syntax to use space-separated format
- Changed from `--flag=value` to `--flag value` syntax
- Added explicit quote requirements for multi-word values
- Added helpful error messages for incorrect syntax

### Migration
See docs/standards/COMMAND-ARGUMENT-SYNTAX.md for migration guide.
```

**Estimated Time:** 30 minutes

### Task 7.3: Create Commits

**Commit structure:**
```bash
# Commit 1: Documentation standards
git add docs/standards/COMMAND-ARGUMENT-SYNTAX.md
git add ANALYSIS-COMMAND-ARGUMENT-SYNTAX.md
git commit -m "docs: Add command argument syntax standard"

# Commit 2: Update faber-cloud
git add plugins/faber-cloud/
git commit -m "feat(faber-cloud): Standardize to space-separated argument syntax

BREAKING CHANGE: Command arguments now use --flag value instead of --flag=value

- Updated all command documentation
- Updated parsing scripts
- Added ARGUMENT_SYNTAX sections
- Added helpful error messages for old syntax"

# Commit 3: Update helm
git add plugins/helm/
git commit -m "feat(helm): Standardize to space-separated argument syntax

BREAKING CHANGE: Command arguments now use --flag value instead of --flag=value"

# Commit 4: Update helm-cloud
git add plugins/helm-cloud/
git commit -m "feat(helm-cloud): Standardize to space-separated argument syntax

BREAKING CHANGE: Command arguments now use --flag value instead of --flag=value"

# Commit 5: Shared library
git add docs/standards/scripts/
git commit -m "feat: Add shared argument parsing library"
```

**Estimated Time:** 1 hour

### Task 7.4: Push and Create PR

**PR Title:** "Standardize command argument syntax across all plugins"

**PR Description:**
```markdown
## Summary
Standardizes command argument parsing to use space-separated syntax (`--flag value`)
across all plugins, replacing the mixed use of equals syntax (`--flag=value`).

## Changes
- Created `docs/standards/COMMAND-ARGUMENT-SYNTAX.md` standard document
- Updated 3 plugins: faber-cloud, helm, helm-cloud
- Updated 21 command files
- Updated parsing scripts
- Added helpful error messages
- Comprehensive testing

## Breaking Changes
Commands in faber-cloud, helm, and helm-cloud now require space-separated syntax:

**Before:**
```bash
/fractary-faber-cloud:deploy-apply --env=test
```

**After:**
```bash
/fractary-faber-cloud:deploy-apply --env test
```

## Migration Guide
See `docs/standards/COMMAND-ARGUMENT-SYNTAX.md` for complete migration guide.

## Testing
- [x] All commands tested with new syntax
- [x] Error messages tested
- [x] Documentation reviewed
- [x] Cross-references validated

## Closes
Fixes #[issue-number]
```

**Estimated Time:** 30 minutes

## Success Criteria

- ✅ All plugins use consistent space-separated syntax
- ✅ All commands have ARGUMENT_SYNTAX sections
- ✅ All examples use correct syntax
- ✅ Parsing scripts updated and tested
- ✅ Helpful error messages for incorrect syntax
- ✅ Documentation is comprehensive and clear
- ✅ All tests pass
- ✅ No regressions in existing commands

## Rollback Plan

If issues are discovered:

1. **Revert commits** in reverse order
2. **Document issues** found
3. **Fix issues** in separate branch
4. **Re-test** thoroughly
5. **Re-apply** changes

## Post-Implementation

### Monitoring

Watch for:
- User confusion about new syntax
- Error reports
- Documentation requests

### Follow-up Tasks

1. Monitor GitHub issues for syntax questions
2. Update any missed documentation
3. Create video tutorial if needed
4. Update plugin templates for new plugins

## Timeline Summary

| Phase | Tasks | Duration | Days |
|-------|-------|----------|------|
| 1 | Documentation standards | 1 hour | 0.5 |
| 2 | Update faber-cloud | 13 hours | 2 |
| 3 | Update helm | 4 hours | 0.5 |
| 4 | Update helm-cloud | 4 hours | 0.5 |
| 5 | Shared library | 4 hours | 0.5 |
| 6 | Integration testing | 8 hours | 1 |
| 7 | Final review & commit | 4 hours | 0.5 |
| **Total** | | **38 hours** | **5-7 days** |

## Resources Needed

- Developer time: 1 person, 5-7 days
- Testing environment: All plugins installed
- Documentation review: Optional second reviewer

## Risks and Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing workflows | High | Clear documentation, helpful errors |
| User confusion | Medium | Comprehensive examples, error messages |
| Missed edge cases | Medium | Thorough testing, rollback plan |
| Documentation gaps | Low | Systematic review process |

## Questions for Discussion

1. **Deprecation period?** Should we support both syntaxes temporarily?
   - **Recommendation:** No, clean break is clearer

2. **Announcement?** How to notify users of changes?
   - **Recommendation:** Release notes, CHANGELOG, error messages

3. **Version bump?** Major version increase for breaking change?
   - **Recommendation:** Yes, following semver

## Approval Checklist

Before starting implementation:
- [ ] Plan reviewed by team
- [ ] Timeline approved
- [ ] Breaking change accepted
- [ ] Testing strategy confirmed
- [ ] Documentation approach validated

## Implementation Checklist

Track progress during implementation:

**Phase 1: Documentation**
- [ ] Standard document created
- [ ] Plugin standards updated

**Phase 2: faber-cloud**
- [ ] 13 commands updated
- [ ] Agent documentation updated
- [ ] Skills updated
- [ ] Parsing scripts updated
- [ ] README updated
- [ ] Testing complete

**Phase 3: helm**
- [ ] 4 commands updated
- [ ] Documentation updated
- [ ] Testing complete

**Phase 4: helm-cloud**
- [ ] 4 commands updated
- [ ] Documentation updated
- [ ] Testing complete

**Phase 5: Shared Library**
- [ ] Parser library created
- [ ] Template updated

**Phase 6: Testing**
- [ ] All commands tested
- [ ] Documentation reviewed
- [ ] Cross-references validated

**Phase 7: Finalization**
- [ ] Final testing complete
- [ ] CHANGELOG updated
- [ ] Commits created
- [ ] PR submitted

## Conclusion

This implementation plan provides a systematic approach to standardizing command argument syntax across all Fractary plugins. The space-separated syntax provides consistency, clarity, and a better user experience.

**Key Benefits:**
- ✅ Consistent user experience
- ✅ Clear documentation
- ✅ Maintainable code
- ✅ Better error messages
- ✅ Industry-standard approach

**Timeline:** 5-7 days of focused work

**Result:** Unified, professional command interface across all plugins
