# Specifications Directory

This directory contains ephemeral specifications tied to GitHub issues. Specs are automatically generated, validated, and archived when work completes.

## Naming Convention

### Current Standard (WORK-XXXXX)

All new specs use the `WORK-XXXXX` naming format:

**Single spec**:
```
WORK-{issue:05d}-{slug}.md
```
Example: `WORK-00123-user-authentication.md`

**Multi-spec (phases)**:
```
WORK-{issue:05d}-{phase:02d}-{slug}.md
```
Examples:
- `WORK-00123-01-authentication.md`
- `WORK-00123-02-oauth-integration.md`

**Format Rules**:
- `WORK` prefix (uppercase) for issue-based specs
- Issue number zero-padded to 5 digits (e.g., `00123`)
- Phase number zero-padded to 2 digits (e.g., `01`)
- Distinguishes from standalone `SPEC-XXXX-` documentation in `docs/specs/`

### Legacy Specs (spec-XXX)

The following specs use the **old naming convention** (pre-standardization):

- `spec-84-auto-install-fractary-plugins-on-startup.md`
- `spec-92-add-git-worktree-support.md`
- `spec-99-new-status-plugin.md`
- `spec-106-expand-doc-types-custom-skills.md`

**These files are kept for backward compatibility.** Once the associated work is completed and the specs are archived, they will be removed. New specs should not use this format.

## Lifecycle

Specs follow this lifecycle:

1. **Generate**: Created from GitHub issue (`/fractary-spec:generate <issue>`)
2. **Implement**: Used as guide during development
3. **Validate**: Implementation checked against spec (`/fractary-spec:validate <issue>`)
4. **Archive**: Uploaded to cloud storage when work completes (`/fractary-spec:archive <issue>`)
5. **Remove**: Deleted from local after successful archival

## Operations

```bash
# Generate spec from issue
/fractary-spec:generate 123

# Validate implementation
/fractary-spec:validate 123

# Archive completed work
/fractary-spec:archive 123

# Read archived spec
/fractary-spec:read 123
```

## See Also

- Plugin README: `plugins/spec/README.md`
- Spec Format Guide: `plugins/spec/skills/spec-generator/docs/spec-format-guide.md`
- Archive Index: `.fractary/plugins/spec/archive-index.json`
