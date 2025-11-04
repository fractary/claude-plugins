# Implementation Plan: Command Argument Syntax Standardization (UPDATED)

**Issue:** Inconsistent argument parsing across plugins
**Solution:** Adopt space-separated syntax (`--flag value`) as industry standard
**Timeline:** 3-4 days
**Status:** Ready to implement
**Updated:** 2025-11-04 based on user feedback

## Executive Summary

Based on industry standards research (Git, npm, Docker, kubectl, AWS CLI, GNU tools), we're adopting **space-separated syntax** (`--flag value`) across all Fractary plugins.

**Key Decisions:**
- ✅ Space-separated syntax (90%+ industry standard)
- ✅ Inline parsing (no shared script dependency)
- ✅ Helpful error detection for incorrect syntax
- ✅ No backward compatibility (clean break)
- ✅ Fast implementation (3-4 days)

## Rationale

### Why Space-Separated?

**Industry Standard (Research shows):**
- Git, npm, Docker, kubectl, AWS CLI: All use space-separated
- POSIX/GNU standards recommend space-separated
- 90%+ of major CLI tools use this pattern
- Developer expectation and familiarity

**Claude Code Parsing Reliability:**
- ✅ Shell handles tokenization automatically
- ✅ Clear token boundaries
- ✅ Easy error detection
- ✅ Simpler implementation = fewer bugs

See `RESEARCH-CLI-ARGUMENT-STANDARDS.md` for complete analysis.

### Why Inline Parsing?

**Distribution Problem:**
- Docs folder not distributed with plugins
- Cross-plugin script references unclear
- No shared library architecture yet

**Solution:**
- Each plugin contains own parsing code
- Use consistent pattern from docs
- Copy-paste approach with standard template
- Future: migrate to fractary-core when available

See `SOLUTION-SHARED-PARSING.md` for complete analysis.

## Standard Parsing Pattern

This pattern will be copied into each command that needs argument parsing:

```bash
#!/bin/bash
# Standard argument parsing pattern
# Source: docs/standards/COMMAND-ARGUMENT-SYNTAX.md

# Initialize variables
ENV=""
AUTO_APPROVE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            # Flag with value - validate next arg exists and isn't a flag
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --env requires a value" >&2
                echo "" >&2
                echo "Usage: /command --env <environment>" >&2
                echo "" >&2
                echo "Examples:" >&2
                echo "  ✅ /command --env test" >&2
                echo "  ✅ /command --env prod" >&2
                echo "  ❌ /command --env" >&2
                exit 2
            fi
            ENV="$2"
            shift 2
            ;;

        --auto-approve)
            # Boolean flag (no value)
            AUTO_APPROVE="true"
            shift
            ;;

        --*=*)
            # DETECT EQUALS SYNTAX - Reject with helpful error
            FLAG_NAME="${1%%=*}"
            FLAG_VALUE="${1#*=}"
            echo "Error: Use space-separated syntax, not equals syntax" >&2
            echo "" >&2
            echo "You used: $1" >&2
            echo "Use instead: $FLAG_NAME $FLAG_VALUE" >&2
            echo "" >&2
            echo "Examples:" >&2
            echo "  ✅ /command $FLAG_NAME test" >&2
            echo "  ❌ /command $1" >&2
            echo "" >&2
            echo "For multi-word values, use quotes:" >&2
            echo "  ✅ /command --description \"multi word value\"" >&2
            exit 2
            ;;

        --*)
            # Unknown flag
            echo "Error: Unknown flag: $1" >&2
            echo "" >&2
            echo "Valid flags:" >&2
            echo "  --env <value>        Environment (test, staging, prod)" >&2
            echo "  --auto-approve       Skip confirmation prompts" >&2
            exit 2
            ;;

        *)
            # Positional argument or error
            echo "Error: Unexpected argument: $1" >&2
            exit 2
            ;;
    esac
done

# Validate required arguments
if [[ -z "$ENV" ]]; then
    echo "Error: --env is required" >&2
    echo "" >&2
    echo "Usage: /command --env <environment>" >&2
    exit 2
fi
```

## Goals

1. ✅ Unified syntax across all plugins (space-separated)
2. ✅ Clear documentation with quote handling
3. ✅ Consistent user experience
4. ✅ Maintainable inline parsing logic
5. ✅ Helpful error messages (detect equals syntax)
6. ✅ Fast implementation (no shared library needed)

## Plugins Affected

### No Changes Needed (Already Compliant)
- ✅ `faber` - Uses space-separated syntax
- ✅ `work` - Uses space-separated syntax with excellent docs
- ✅ `repo` - Uses space-separated syntax with excellent docs
- ✅ `codex` - Uses space-separated syntax
- ✅ `faber-article` - Uses space-separated syntax

### Require Migration (Currently Use Equals)
- ⚠️ `faber-cloud` - 13 commands + 3 scripts
- ⚠️ `helm` - 4 commands
- ⚠️ `helm-cloud` - 4 commands

**Total:** 21 commands + 3 scripts to update

## Phase 1: Documentation (2 hours)

### Task 1.1: Update Standard Document ✅ COMPLETE
- [x] Created `docs/standards/COMMAND-ARGUMENT-SYNTAX.md`
- [x] Added industry research basis
- [x] Added standard parsing pattern (copy-paste ready)
- [x] Added error message examples

### Task 1.2: Update Plugin Standards Document

**File:** `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`

**Changes:**
```markdown
## Command Argument Syntax

All commands MUST use space-separated syntax: `--flag value`

**Reference:** See [COMMAND-ARGUMENT-SYNTAX.md](./COMMAND-ARGUMENT-SYNTAX.md)

**Key Rules:**
- Use `--flag value` (NOT `--flag=value`)
- Multi-word values MUST use quotes: `--body "multi word"`
- Boolean flags have no value: `--auto-approve`
- Reject equals syntax with helpful errors

**Standard Pattern:**
Copy the parsing pattern from COMMAND-ARGUMENT-SYNTAX.md when creating new commands.
```

**Estimated Time:** 30 minutes

**Deliverable:**
- Updated plugin standards document with argument syntax section
- Cross-reference to COMMAND-ARGUMENT-SYNTAX.md

### Task 1.3: Add Standard Pattern to docs/standards/COMMAND-ARGUMENT-SYNTAX.md

**Already complete** - pattern is in the document

**Estimated Time:** 0 minutes (done)

**Phase 1 Total:** 30 minutes

## Phase 2: Update faber-cloud Plugin (1.5 days)

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

**For each command (15 min each = 3.25 hours):**

1. **Update frontmatter:**
   ```markdown
   # Before
   argument-hint: "--env=<environment> [--auto-approve]"

   # After
   argument-hint: "--env <environment> [--auto-approve]"
   ```

2. **Add ARGUMENT_SYNTAX section:**
   ```markdown
   <ARGUMENT_SYNTAX>
   ## Command Argument Syntax

   This command follows the standard space-separated syntax:
   - Format: `--flag value` (NOT `--flag=value`)
   - Multi-word values MUST use quotes: `--description "multi word value"`
   - Boolean flags have no value: `--auto-approve`

   ### Examples
   ```bash
   # Correct ✅
   /fractary-faber-cloud:deploy-apply --env test
   /fractary-faber-cloud:deploy-apply --env prod --auto-approve

   # Incorrect ❌
   /fractary-faber-cloud:deploy-apply --env=test
   ```
   </ARGUMENT_SYNTAX>
   ```

3. **Update all command examples** throughout the file

4. **Add inline parsing code** if command contains workflow with argument parsing

**Estimated Time:** 3.5 hours

**Deliverable:**
- 13 updated command files with consistent syntax

### Task 2.2: Update Parsing Scripts

**Scripts to update (3 files):**
1. `plugins/faber-cloud/skills/cloud-common/scripts/generate-deployed-doc.sh`
2. `plugins/faber-cloud/skills/cloud-common/scripts/log-resolution.sh`
3. `plugins/faber-cloud/skills/cloud-common/scripts/update-registry.sh`

**For each script (30 min each = 1.5 hours):**

**Before:**
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

**After:**
```bash
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --environment requires a value" >&2
                exit 2
            fi
            ENVIRONMENT="$2"
            shift 2
            ;;
        --*=*)
            # Reject equals syntax
            FLAG_NAME="${1%%=*}"
            echo "Error: Use space-separated syntax" >&2
            echo "Use: $FLAG_NAME <value>" >&2
            echo "Not: $1" >&2
            exit 2
            ;;
    esac
done
```

**Estimated Time:** 1.5 hours

**Deliverable:**
- 3 updated parsing scripts with helpful error messages

### Task 2.3: Update Agent & Skill Documentation

**Files to scan and update:**
- `agents/infra-manager.md`
- All `skills/*/SKILL.md` files with command examples

**Changes:**
- Update command examples from equals to space-separated
- ~10 files to review

**Estimated Time:** 1.5 hours

**Deliverable:**
- Consistent command examples across all faber-cloud documentation

### Task 2.4: Update README and Guides

**Files:**
- `plugins/faber-cloud/README.md`
- `plugins/faber-cloud/docs/guides/*.md`
- `plugins/faber-cloud/docs/reference/commands.md`

**Changes:**
- Update all command examples
- Fix quick-start sections
- Update troubleshooting examples

**Estimated Time:** 1 hour

**Deliverable:**
- Consistent examples across all user-facing documentation

### Task 2.5: Test faber-cloud Commands

**Test matrix for each command:**
- [ ] Single-word flag values work
- [ ] Multi-word flag values with quotes work
- [ ] Boolean flags work
- [ ] Multiple flags work
- [ ] Equals syntax rejected with helpful error
- [ ] Error messages are clear

**Test examples:**
```bash
# Should work ✅
/fractary-faber-cloud:deploy-apply --env test
/fractary-faber-cloud:deploy-apply --env prod --auto-approve
/fractary-faber-cloud:design "S3 bucket with versioning"

# Should show helpful error ❌
/fractary-faber-cloud:deploy-apply --env=test
# Expected: "Use: --env <value>, Not: --env=test"
```

**Estimated Time:** 2 hours

**Deliverable:**
- All faber-cloud commands tested and working
- Error messages validated

**Phase 2 Total:** 10 hours (1.5 days)

## Phase 3: Update helm Plugin (0.5 days)

### Task 3.1: Update Command Documentation

**Commands (4 total):**
1. `commands/status.md`
2. `commands/issues.md`
3. `commands/dashboard.md`
4. `commands/escalate.md`

**Process:** Same as Phase 2, Task 2.1

**Estimated Time:** 1 hour

### Task 3.2: Update Documentation

**Estimated Time:** 30 minutes

### Task 3.3: Test helm Commands

**Estimated Time:** 30 minutes

**Phase 3 Total:** 2 hours (0.5 days)

## Phase 4: Update helm-cloud Plugin (0.5 days)

### Task 4.1: Update Command Documentation

**Commands (4 total):**
1. `commands/health.md`
2. `commands/investigate.md`
3. `commands/audit.md`
4. `commands/remediate.md`

**Process:** Same as Phase 2, Task 2.1

**Estimated Time:** 1 hour

### Task 4.2: Update Documentation

**Estimated Time:** 30 minutes

### Task 4.3: Test helm-cloud Commands

**Estimated Time:** 30 minutes

**Phase 4 Total:** 2 hours (0.5 days)

## Phase 5: Integration Testing & Documentation Review (0.5 days)

### Task 5.1: Cross-Plugin Testing

**Test scenarios:**
1. All updated commands work with space-separated syntax
2. Equals syntax rejected with helpful errors
3. Multi-word values work with quotes
4. Error messages are consistent and helpful

**Test checklist:**
- [ ] faber-cloud: 13 commands tested
- [ ] helm: 4 commands tested
- [ ] helm-cloud: 4 commands tested

**Estimated Time:** 2 hours

### Task 5.2: Documentation Cross-Reference Check

**Verify:**
- [ ] All command examples use correct syntax
- [ ] Agent documentation matches
- [ ] Skill documentation matches
- [ ] README examples match
- [ ] Guide examples match

**Estimated Time:** 1 hour

**Phase 5 Total:** 3 hours (0.5 days)

## Phase 6: Commit and Push (0.5 hours)

### Task 6.1: Create Commits

**Commit structure:**

```bash
# Commit 1: Research and standards
git add RESEARCH-CLI-ARGUMENT-STANDARDS.md
git add SOLUTION-SHARED-PARSING.md
git add docs/standards/COMMAND-ARGUMENT-SYNTAX.md
git add docs/standards/FRACTARY-PLUGIN-STANDARDS.md
git commit -m "docs: Add command argument syntax standards based on industry research

- Add CLI standards research (Git, npm, Docker, kubectl, AWS CLI, GNU)
- Document space-separated syntax as industry standard
- Create comprehensive COMMAND-ARGUMENT-SYNTAX.md standard
- Document inline parsing approach (no shared library)
- Add standard parsing pattern (copy-paste ready)
- Add helpful error message templates"

# Commit 2: faber-cloud updates
git add plugins/faber-cloud/
git commit -m "feat(faber-cloud)!: Standardize to space-separated argument syntax

BREAKING CHANGE: Commands now use --flag value instead of --flag=value

Updated:
- 13 command files with new syntax
- 3 parsing scripts with error detection
- Agent and skill documentation
- README and user guides
- Added helpful error messages for old syntax

Migration:
- Change --env=test to --env test
- Change --provider=aws to --provider aws
- Use quotes for multi-word values: --description \"text here\"

See docs/standards/COMMAND-ARGUMENT-SYNTAX.md for details"

# Commit 3: helm updates
git add plugins/helm/
git commit -m "feat(helm)!: Standardize to space-separated argument syntax

BREAKING CHANGE: Commands now use --flag value instead of --flag=value"

# Commit 4: helm-cloud updates
git add plugins/helm-cloud/
git commit -m "feat(helm-cloud)!: Standardize to space-separated argument syntax

BREAKING CHANGE: Commands now use --flag value instead of --flag=value"

# Commit 5: Analysis (already committed)
# ANALYSIS-COMMAND-ARGUMENT-SYNTAX.md
# IMPLEMENTATION-PLAN-ARGUMENT-SYNTAX.md
```

**Estimated Time:** 30 minutes

## Timeline Summary

| Phase | Tasks | Hours | Days |
|-------|-------|-------|------|
| 1 | Documentation standards | 0.5 | 0.1 |
| 2 | Update faber-cloud | 10 | 1.5 |
| 3 | Update helm | 2 | 0.25 |
| 4 | Update helm-cloud | 2 | 0.25 |
| 5 | Integration testing | 3 | 0.5 |
| 6 | Commit and push | 0.5 | 0.1 |
| **Total** | | **18 hours** | **3-4 days** |

**Faster than original estimate** (was 5-7 days) because:
- ✅ No shared library to create
- ✅ Inline parsing is simpler
- ✅ No backward compatibility concerns
- ✅ Pattern is copy-paste ready

## Success Criteria

- ✅ All commands use space-separated syntax: `--flag value`
- ✅ All commands reject equals syntax with helpful errors
- ✅ All documentation shows correct syntax
- ✅ Error messages are consistent and helpful
- ✅ All examples use correct syntax
- ✅ Multi-word value handling is documented and working
- ✅ All tests pass

## Breaking Changes

**For faber-cloud users:**
```bash
# Old syntax (no longer works)
/fractary-faber-cloud:deploy-apply --env=test
/fractary-faber-cloud:init --provider=aws --iac=terraform

# New syntax (required)
/fractary-faber-cloud:deploy-apply --env test
/fractary-faber-cloud:init --provider aws --iac terraform
```

**For helm users:**
```bash
# Old syntax (no longer works)
/fractary-helm:status --domain=infrastructure --env=prod

# New syntax (required)
/fractary-helm:status --domain infrastructure --env prod
```

**For helm-cloud users:**
```bash
# Old syntax (no longer works)
/fractary-helm-cloud:health --env=prod

# New syntax (required)
/fractary-helm-cloud:health --env prod
```

**Helpful error messages will guide users:**
```
Error: Use space-separated syntax, not equals syntax

You used: --env=test
Use instead: --env test

Examples:
  ✅ /command --env test
  ❌ /command --env=test
```

## Migration Guide for Users

**What Changed:**
- Command argument syntax changed from `--flag=value` to `--flag value`

**What You Need to Do:**
1. Replace `=` with space: `--env=test` → `--env test`
2. Use quotes for multi-word values: `--description "multi word value"`
3. Boolean flags stay the same: `--auto-approve`

**Examples:**
```bash
# Before
/fractary-faber-cloud:deploy-apply --env=test --auto-approve
/fractary-faber-cloud:init --provider=aws

# After
/fractary-faber-cloud:deploy-apply --env test --auto-approve
/fractary-faber-cloud:init --provider aws
```

## Key Improvements

1. **Industry Standard**
   - Matches Git, npm, Docker, kubectl
   - 90%+ of CLI tools use this pattern
   - Developers already familiar

2. **Better Error Messages**
   - Detects old syntax automatically
   - Shows correct syntax example
   - Clear and actionable

3. **Clearer Documentation**
   - Explicit quote rules
   - Comprehensive examples
   - Standard pattern to copy

4. **More Reliable**
   - Shell handles tokenization
   - Fewer edge cases
   - Easier to maintain

## Post-Implementation

### Documentation Updates
- [x] RESEARCH-CLI-ARGUMENT-STANDARDS.md created
- [x] SOLUTION-SHARED-PARSING.md created
- [x] docs/standards/COMMAND-ARGUMENT-SYNTAX.md created
- [ ] docs/standards/FRACTARY-PLUGIN-STANDARDS.md to update
- [ ] All command files to update
- [ ] All plugin READMEs to update

### Testing Checklist
- [ ] All faber-cloud commands tested
- [ ] All helm commands tested
- [ ] All helm-cloud commands tested
- [ ] Error messages validated
- [ ] Documentation cross-referenced
- [ ] Edge cases tested

### Communication
- [ ] CHANGELOG entries created
- [ ] Breaking change documented
- [ ] Migration guide provided
- [ ] PR description written

## Questions Resolved

1. **Shared script distribution?**
   - ✅ Solved: Use inline parsing with standard pattern

2. **Which syntax to use?**
   - ✅ Decided: Space-separated (industry standard)

3. **Error messages?**
   - ✅ Yes: Detect equals syntax and suggest correct usage

4. **Timeline?**
   - ✅ 3-4 days (faster due to inline approach)

5. **Backward compatibility?**
   - ✅ No: Clean break with helpful errors

## Implementation Checklist

**Phase 1: Documentation**
- [ ] Update FRACTARY-PLUGIN-STANDARDS.md

**Phase 2: faber-cloud**
- [ ] 13 commands updated
- [ ] 3 scripts updated
- [ ] Agent docs updated
- [ ] Skill docs updated
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

**Phase 5: Integration**
- [ ] Cross-plugin testing
- [ ] Documentation review
- [ ] Error message validation

**Phase 6: Finalization**
- [ ] Commits created
- [ ] Pushed to branch
- [ ] Ready for PR

## Conclusion

This updated plan provides a **faster, simpler** implementation (3-4 days vs 5-7 days) by using **inline parsing** instead of shared libraries, while maintaining **consistency** through a standard pattern that developers copy from documentation.

**Key advantages of updated plan:**
- ✅ Faster implementation (3-4 days)
- ✅ No shared library complexity
- ✅ Based on industry research
- ✅ Helpful error detection
- ✅ Self-contained plugins
- ✅ Clear migration path

**Ready to implement immediately.**
