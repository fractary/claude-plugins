# Phase 0 Findings: CLI Spec Module Assessment

**Issue**: #359
**Date**: 2025-12-13
**Phase**: Phase 0 - Prerequisites (BLOCKING)
**Status**: ⚠️ **BLOCKED** - Critical gaps identified

## Executive Summary

The Fractary CLI spec module is **not ready for integration**. While all 8 spec commands are advertised in the CLI help text, they have critical implementation gaps that block the migration work defined in WORK-00359-integrate-spec-plugin-cli.md.

## CLI Version

- **Installed**: v1.0.0 (updated from v0.3.1)
- **Latest**: v1.0.2
- **Package**: `@fractary/faber`

## Command Availability

All 8 spec commands are present in CLI help:

| Command | Status | Notes |
|---------|--------|-------|
| `fractary spec create` | ✅ Listed | Not tested (blocked by config) |
| `fractary spec get` | ✅ Listed | Not tested (blocked by config) |
| `fractary spec list` | ✅ Listed | Tested - blocked by config |
| `fractary spec update` | ✅ Listed | Not tested (blocked by config) |
| `fractary spec validate` | ✅ Listed | Not tested (blocked by config) |
| `fractary spec refine` | ✅ Listed | Not tested (blocked by config) |
| `fractary spec delete` | ✅ Listed | Not tested (blocked by config) |
| `fractary spec templates` | ✅ Listed | Tested - blocked by config |

## Critical Blockers

### 1. JSON Output Mode Not Implemented

**Severity**: 🔴 **BLOCKING**

**Finding**:
```bash
$ fractary spec templates --json
error: unknown option '--json'
```

**Impact**:
- The spec REQUIRES `--json` flag for all CLI invocations
- Plugin skills need structured JSON output for parsing
- Human-readable output cannot be reliably parsed

**Spec Requirement**:
> "Verify JSON output mode works correctly for all commands" (Phase 0)

**Workaround**: None. This is fundamental to the integration pattern.

**Resolution Required**: Implement `--json` flag for all spec commands in @fractary/faber CLI.

### 2. Configuration Required for All Operations

**Severity**: 🟡 **BLOCKING**

**Finding**:
```bash
$ fractary spec list
Error: Configuration validation failed: work: Required, repo: Required, artifacts: Required

$ fractary spec templates
Error: Configuration validation failed: work: Required, repo: Required, artifacts: Required
```

**Impact**:
- Even read-only operations (list, templates) require full configuration
- Configuration schema not documented in CLI help
- Unclear what "work", "repo", "artifacts" configuration entails

**Expected Behavior**:
- Read-only operations should work without configuration
- At minimum, `templates` should list built-in templates without config

**Resolution Required**:
1. Document required configuration schema
2. Make read-only operations work without config OR
3. Provide clear error with config file example

### 3. No Example Configuration Available

**Severity**: 🟡 **BLOCKING**

**Finding**:
- No `fractary init` or `fractary spec init` command
- No example config in documentation
- No hint in error message about where to place config

**Impact**:
- Cannot proceed with CLI testing without knowing config format
- Cannot verify other CLI functionality

**Resolution Required**:
- Add `fractary init` command to generate config
- OR provide example config in error message
- OR document config schema in `--help`

## Testing Summary

| Test | Result | Details |
|------|--------|---------|
| CLI Installation | ✅ Pass | v1.0.0 installed successfully |
| Command Availability | ✅ Pass | All 8 commands present in help |
| JSON Output Mode | ❌ **FAIL** | `--json` flag not recognized |
| Basic Operation (templates) | ❌ **FAIL** | Blocked by config requirement |
| Basic Operation (list) | ❌ **FAIL** | Blocked by config requirement |

## Recommendations

### Option 1: Implement Missing CLI Features (Recommended)

**Approach**: Fix the blockers in @fractary/faber before proceeding with plugin migration.

**Tasks**:
1. Add `--json` flag to all spec commands
2. Make read-only commands work without config
3. Add `fractary init` or provide config example
4. Test all 8 commands end-to-end with JSON output

**Timeline**: Depends on @fractary/faber development velocity

**Pros**:
- Aligns with original spec design
- Creates robust CLI for direct use
- Plugin migration proceeds as planned

**Cons**:
- Delays plugin work
- Requires CLI development resources

### Option 2: Adjust Migration Spec

**Approach**: Revise WORK-00359 spec to work with current CLI limitations.

**Changes**:
1. Parse human-readable output instead of JSON
2. Handle configuration requirements in plugin
3. Reduce scope to working commands only

**Timeline**: Can proceed immediately

**Pros**:
- Unblocks plugin work
- Incremental approach

**Cons**:
- Fragile output parsing
- Not aligned with reference implementation (work plugin)
- Technical debt

### Option 3: Defer Migration

**Approach**: Wait for CLI to mature before migrating plugin.

**Timeline**: Indefinite

**Pros**:
- No wasted effort on workarounds
- Clean implementation when ready

**Cons**:
- Plugin remains with direct implementation
- Maintenance burden continues

## Decision Required

**Question for Product Owner**:

Which option should we pursue?
1. Fix CLI blockers first, then proceed with migration
2. Adjust spec to work with current CLI limitations
3. Defer migration until CLI is ready

## Next Steps (Pending Decision)

### If Option 1 (Fix CLI):
1. Create issues in @fractary/faber for:
   - Add `--json` flag to all spec commands
   - Remove config requirement for read-only ops
   - Add `fractary init` command
2. Wait for CLI updates
3. Resume Phase 0 testing

### If Option 2 (Adjust Spec):
1. Update WORK-00359 spec with revised approach
2. Document output parsing strategy
3. Proceed to Phase 1 with limitations

### If Option 3 (Defer):
1. Close this implementation work
2. Create tracking issue for future migration
3. Continue maintaining current plugin impl

## References

- Main Spec: [WORK-00359-integrate-spec-plugin-cli.md](WORK-00359-integrate-spec-plugin-cli.md)
- CLI Package: [@fractary/faber on npm](https://www.npmjs.com/package/@fractary/faber)
- Reference Implementation: Work plugin CLI migration (#356, #358)
