---
spec_id: WORK-00136-standardize-faber-cloud-config
work_id: 136
issue_url: https://github.com/fractary/claude-plugins/issues/136
title: Standardize faber-cloud config file to config.json naming pattern
type: refactor
status: draft
created: 2025-11-18
author: jmcwilliam
validated: false
source: conversation+issue
---

# Specification: Standardize faber-cloud config file to config.json naming pattern

**Issue**: [#136](https://github.com/fractary/claude-plugins/issues/136)
**Type**: refactor
**Status**: Draft
**Created**: 2025-11-18

## Summary

The faber-cloud plugin currently uses a non-standard config filename (`faber-cloud.json`) instead of the standard `config.json` used by other plugins (work, repo, file). This specification outlines the changes needed to standardize the naming convention and provide seamless migration for existing installations.

## Requirements

### Functional Requirements

- FR1: Rename the config file from `faber-cloud.json` to `config.json`
- FR2: Update the faber-cloud init command/skill to reference `config.json`
- FR3: Implement automatic migration logic that detects and renames existing `faber-cloud.json` files
- FR4: Log migration actions to inform users of the conversion
- FR5: Update all documentation references to use the new filename

### Non-Functional Requirements

- NFR1: Migration must be seamless - no manual intervention required from users
- NFR2: Existing configurations must be preserved during migration
- NFR3: Migration should be idempotent - safe to run multiple times
- NFR4: Changes must maintain backward compatibility during transition period

## Technical Approach

### Migration Strategy

The init command will implement the following logic:

1. **Check for existing config**: Look for `faber-cloud.json` in `.fractary/plugins/faber-cloud/`
2. **Conditional migration**:
   - If `faber-cloud.json` exists: Rename to `config.json` (preserving all settings)
   - If `config.json` already exists: Use it (no action needed)
   - If neither exists: Create new `config.json` from template
3. **Logging**: Output clear message indicating migration occurred
4. **Validation**: Verify the renamed/created config is valid JSON

### Implementation Phases

**Phase 1: Update init skill**
- Modify init skill workflow to detect old filename
- Add migration logic before config creation
- Add validation after migration

**Phase 2: Update documentation**
- Search for all references to `faber-cloud.json`
- Replace with `config.json`
- Update examples in README and docs

**Phase 3: Testing**
- Test with existing `faber-cloud.json` (migration path)
- Test with no config (fresh install path)
- Test with existing `config.json` (already migrated path)

## Files to Modify

- `plugins/faber-cloud/skills/init-skill/workflow/initialize.md`: Add migration logic before config creation
- `plugins/faber-cloud/skills/init-skill/scripts/init.sh`: Implement file rename logic
- `plugins/faber-cloud/README.md`: Update config filename references
- `plugins/faber-cloud/docs/**/*.md`: Update any documentation mentioning config filename

## Acceptance Criteria

- [ ] Init command detects existing `faber-cloud.json` and renames to `config.json`
- [ ] Migration preserves all existing configuration values
- [ ] Migration logs clear message: "Migrated faber-cloud.json → config.json"
- [ ] Running init on already-migrated config does not cause errors
- [ ] Fresh installations create `config.json` directly
- [ ] All documentation references updated to `config.json`
- [ ] No breaking changes for users with existing configs

## Testing Strategy

### Manual Testing

1. **Migration path test**:
   - Create `.fractary/plugins/faber-cloud/faber-cloud.json` with sample config
   - Run `/faber-cloud:init`
   - Verify `config.json` exists with same content
   - Verify `faber-cloud.json` no longer exists
   - Check migration message in output

2. **Fresh install test**:
   - Remove all faber-cloud configs
   - Run `/faber-cloud:init`
   - Verify `config.json` created
   - Verify no errors about missing old config

3. **Already migrated test**:
   - Start with `config.json` already present
   - Run `/faber-cloud:init`
   - Verify config preserved
   - Verify no duplicate or error messages

### Automated Testing

- Unit test for file rename logic
- Integration test for init workflow with different starting states
- Validation test for config JSON structure after migration

## Dependencies

- Bash filesystem operations (`mv`, `test -f`)
- JSON validation utilities (jq or equivalent)
- Current faber-cloud init skill structure

## Risks

- **Breaking existing workflows**: Users may have hardcoded references to `faber-cloud.json`
  - *Mitigation*: Migration is automatic, no user action needed. Add deprecation notice in release notes.

- **Config corruption during migration**: File rename could fail mid-operation
  - *Mitigation*: Implement atomic rename operation. Add validation after rename. Keep backup before migration.

- **Documentation lag**: Some docs may not get updated
  - *Mitigation*: Comprehensive grep for all occurrences. Include in PR checklist.

## Implementation Notes

### Migration Script Pattern

```bash
# In init skill script
CONFIG_DIR=".fractary/plugins/faber-cloud"
OLD_CONFIG="$CONFIG_DIR/faber-cloud.json"
NEW_CONFIG="$CONFIG_DIR/config.json"

if [[ -f "$OLD_CONFIG" ]] && [[ ! -f "$NEW_CONFIG" ]]; then
    echo "ℹ Migrating configuration: faber-cloud.json → config.json"
    mv "$OLD_CONFIG" "$NEW_CONFIG"
    echo "✓ Migration complete"
elif [[ -f "$NEW_CONFIG" ]]; then
    echo "✓ Using existing config.json"
else
    echo "ℹ Creating new config.json"
    # Create from template
fi
```

### Validation Approach

After migration or creation, validate the config:
```bash
if jq empty "$NEW_CONFIG" 2>/dev/null; then
    echo "✓ Config validated"
else
    echo "⚠ Warning: Config file may be invalid JSON"
fi
```

### Rollout Strategy

1. Implement changes in feature branch
2. Test with existing faber-cloud installations
3. Document migration in PR description
4. Include migration notes in release changelog
5. Monitor for issues post-merge

### Backward Compatibility Note

While we're standardizing to `config.json`, the init command should handle both filenames gracefully during the transition. Once migration is proven stable, we can deprecate looking for the old filename in a future release.
