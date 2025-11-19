---
spec_id: WORK-00144-add-skill-frontmatter
work_id: 144
issue_url: https://github.com/fractary/claude-plugins/issues/144
title: Add proper frontmatter to plugin skills
type: chore
status: draft
created: 2025-11-19
author: jmcwilliam
validated: false
source: conversation+issue
---

# Specification: Add proper frontmatter to plugin skills

**Issue**: [#144](https://github.com/fractary/claude-plugins/issues/144)
**Type**: Chore/Documentation
**Status**: Draft
**Created**: 2025-11-19

## Summary

Many plugin skills are missing the standard Claude skill frontmatter that provides the skill's name and description. This frontmatter is critical as it:
1. Gives the skill its official name
2. Enables Claude to identify what the skill does
3. Allows automatic skill selection

This specification outlines the systematic review and addition of proper frontmatter to all plugin skills that are missing it.

## Requirements

### Functional Requirements

- FR1: Review all plugin skills across all plugins (`plugins/*/skills/*/SKILL.md`)
- FR2: Identify skills missing proper frontmatter (name and description)
- FR3: Add standard Claude skill frontmatter to all missing skills
- FR4: Ensure frontmatter follows the established pattern used in other skills
- FR5: Maintain consistency in frontmatter format across all skills

### Non-Functional Requirements

- NFR1: Frontmatter must be at the top of each SKILL.md file
- NFR2: Frontmatter must use YAML format between `---` delimiters
- NFR3: Skill names must be unique and descriptive
- NFR4: Skill descriptions must clearly explain what the skill does to enable automatic selection

## Technical Approach

### Standard Frontmatter Format

Based on existing skills, the standard frontmatter format should be:

```yaml
---
name: skill-name
description: Brief description of what this skill does (1-2 sentences)
---
```

### Discovery Process

1. Find all SKILL.md files: `find plugins -name "SKILL.md" -type f`
2. Check each file for frontmatter presence
3. Identify skills missing name and/or description
4. Categorize by plugin for systematic review

### Implementation Strategy

1. **Audit Phase**: Create comprehensive list of all skills and their frontmatter status
2. **Pattern Analysis**: Review existing skills with proper frontmatter to understand naming conventions
3. **Batch Update**: Add frontmatter to all skills missing it, grouped by plugin
4. **Validation**: Verify all skills now have proper frontmatter

### Naming Conventions

Based on existing patterns:
- Handler skills: `handler-{type}-{provider}` (e.g., `handler-sync-github`)
- Manager skills: `{domain}-manager` (e.g., `repo-manager`, `work-manager`)
- Operation skills: `{operation}-{noun}` (e.g., `branch-creator`, `issue-fetcher`)
- Utility skills: `{function}` (e.g., `config-migrator`, `cache-clear`)

## Files to Modify

All `SKILL.md` files across the plugin ecosystem that are missing frontmatter, including but not limited to:

- `plugins/codex/skills/*/SKILL.md` - Codex plugin skills
- `plugins/docs/skills/*/SKILL.md` - Docs plugin skills
- `plugins/faber/skills/*/SKILL.md` - FABER plugin skills
- `plugins/faber-agent/skills/*/SKILL.md` - FABER Agent plugin skills
- `plugins/faber-cloud/skills/*/SKILL.md` - FABER Cloud plugin skills
- `plugins/file/skills/*/SKILL.md` - File plugin skills
- `plugins/logs/skills/*/SKILL.md` - Logs plugin skills
- `plugins/repo/skills/*/SKILL.md` - Repo plugin skills
- `plugins/spec/skills/*/SKILL.md` - Spec plugin skills
- `plugins/status/skills/*/SKILL.md` - Status plugin skills
- `plugins/work/skills/*/SKILL.md` - Work plugin skills

## Acceptance Criteria

- [ ] All plugin skills have been audited for frontmatter presence
- [ ] Comprehensive list of skills missing frontmatter has been created
- [ ] Standard frontmatter format has been confirmed
- [ ] All skills missing frontmatter now have proper frontmatter added
- [ ] Frontmatter includes both `name` and `description` fields
- [ ] Skill names follow established naming conventions
- [ ] Skill descriptions are clear and enable automatic selection
- [ ] All frontmatter is properly formatted (YAML between `---` delimiters)
- [ ] No duplicate skill names exist
- [ ] Verification pass confirms all skills now have frontmatter

## Testing Strategy

### Verification Steps

1. **Pre-implementation audit**:
   ```bash
   # Count total skills
   find plugins -name "SKILL.md" | wc -l

   # Identify skills with frontmatter
   grep -l "^---" plugins/*/skills/*/SKILL.md | wc -l

   # Calculate missing frontmatter count
   ```

2. **Post-implementation verification**:
   ```bash
   # Verify all skills have frontmatter
   find plugins -name "SKILL.md" -exec sh -c 'head -1 "$1" | grep -q "^---" || echo "$1"' _ {} \;

   # Should return no results
   ```

3. **Frontmatter validation**:
   - Check that all frontmatter has `name` field
   - Check that all frontmatter has `description` field
   - Validate YAML syntax
   - Verify no duplicate skill names

### Sample Check

```bash
# For each SKILL.md file
for skill in $(find plugins -name "SKILL.md"); do
  # Extract frontmatter
  sed -n '/^---$/,/^---$/p' "$skill"

  # Verify has name and description
done
```

## Dependencies

None - this is a documentation/metadata task that doesn't require external dependencies.

## Risks

### Risk 1: Inconsistent Naming
**Description**: Skills may be named inconsistently if not following a clear pattern
**Mitigation**: Review existing well-named skills first, establish naming convention guidelines, apply consistently

### Risk 2: Incomplete Discovery
**Description**: Some skills might be missed during the audit
**Mitigation**: Use comprehensive find command, double-check with grep, verify count before/after

### Risk 3: Description Quality
**Description**: Descriptions might not be clear enough for automatic skill selection
**Mitigation**: Review existing high-quality descriptions, ensure descriptions explain what the skill does and when to use it

### Risk 4: Breaking Changes
**Description**: Adding frontmatter might affect skill loading or parsing
**Mitigation**: Test with a few skills first, verify Claude Code can still load and use skills properly

## Implementation Notes

### Discovery Commands

```bash
# Find all SKILL.md files
find plugins -name "SKILL.md" -type f

# Find skills missing frontmatter (starts with ---)
find plugins -name "SKILL.md" -exec sh -c 'head -1 "$1" | grep -q "^---" || echo "$1"' _ {} \;

# Find skills with frontmatter
grep -l "^---" plugins/*/skills/*/SKILL.md
```

### Example Frontmatter Reference

Good examples from existing skills:
- `plugins/codex/skills/document-fetcher/SKILL.md`
- `plugins/repo/skills/branch-manager/SKILL.md`
- `plugins/work/skills/issue-fetcher/SKILL.md`

### Batch Update Strategy

1. Group skills by plugin for review
2. Start with one plugin as a test (e.g., `codex`)
3. Verify no issues with skill loading
4. Continue with remaining plugins
5. Final verification pass across all plugins

### Post-Implementation

After adding frontmatter:
1. Test skill invocation still works
2. Verify Claude can auto-select skills based on descriptions
3. Update plugin documentation if needed
4. Create PR with all changes
5. Add comment to issue #144 with completion details
