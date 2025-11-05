# Fractary Spec Plugin

**Ephemeral Specifications with Lifecycle-Based Archival**

The fractary-spec plugin manages point-in-time specifications tied to work items. Unlike documentation (living state), specs are temporary requirements that become stale once work completes. This plugin handles the full lifecycle: generation from issues, validation against implementation, and archival to cloud storage.

## Philosophy

**Specs ≠ Docs**

- **Specs**: Ephemeral, point-in-time requirements. Archived when complete.
- **Docs**: Living state, continuously updated. Never archived.

Keeping old specs in the workspace pollutes context. This plugin archives completed specs to cloud storage and removes them locally, keeping only active specifications in the workspace.

## Features

- ✅ **Issue-Centric**: Specs tied to GitHub issues
- ✅ **Multi-Spec Support**: Multiple specs per issue (phases)
- ✅ **Smart Templates**: Auto-selects template based on work type
- ✅ **Validation**: Checks implementation completeness
- ✅ **Lifecycle Archival**: Archives when issue closes or PR merges
- ✅ **Cloud Storage**: Uses fractary-file for archival
- ✅ **GitHub Integration**: Comments on issues/PRs with spec links
- ✅ **FABER Integration**: Automatic workflow in FABER phases
- ✅ **Read from Cloud**: Access archived specs without download

## Installation

### Prerequisites

- `fractary-work` plugin (GitHub integration)
- `fractary-file` plugin (cloud storage)

### Initialize

```bash
/fractary-spec:init
```

Creates:
- Configuration file
- `/specs` directory
- Archive index

## Quick Start

### 1. Generate Spec from Issue

```bash
/fractary-spec:generate 123
```

Creates `/specs/spec-123-feature.md` and comments on issue.

### 2. Implement Following Spec

Use spec as guide during development.

### 3. Validate Implementation

```bash
/fractary-spec:validate 123
```

Checks:
- Requirements coverage
- Acceptance criteria
- Files modified
- Tests added
- Docs updated

### 4. Archive When Complete

```bash
/fractary-spec:archive 123
```

When issue closes or PR merges:
- Uploads to cloud
- Updates archive index
- Comments on GitHub
- Removes from local

### 5. Read Archived Spec

```bash
/fractary-spec:read 123
```

Streams from cloud without local download.

## Commands

| Command | Description |
|---------|-------------|
| `/fractary-spec:init` | Initialize plugin |
| `/fractary-spec:generate <issue>` | Generate spec from issue |
| `/fractary-spec:validate <issue>` | Validate implementation |
| `/fractary-spec:archive <issue>` | Archive to cloud |
| `/fractary-spec:read <issue>` | Read archived spec |

See `commands/*.md` for detailed usage.

## Templates

### Auto-Selected Based on Work Type

- **basic**: General-purpose (default)
- **feature**: User stories, UI/UX, rollout plans
- **infrastructure**: Resources, deployment, monitoring
- **api**: Endpoints, models, authentication
- **bug**: Root cause, fix approach, prevention

### Classification Rules

| Type | Detection |
|------|-----------|
| Bug | Labels: "bug", "defect", "hotfix" |
| Feature | Labels: "feature", "enhancement" |
| Infrastructure | Labels: "infrastructure", "devops", "cloud" |
| API | Labels: "api", "endpoint", "rest" |

Override with `--template` option.

## Multi-Spec Support

For large issues, create multiple specs:

```bash
/fractary-spec:generate 123 --phase 1 --title "Authentication"
/fractary-spec:generate 123 --phase 2 --title "OAuth Integration"
```

Creates:
- `spec-123-phase1-authentication.md`
- `spec-123-phase2-oauth-integration.md`

All archived together when issue completes.

## Validation

Before archiving, validate implementation:

```bash
/fractary-spec:validate 123
```

### Checks

- **Requirements**: All implemented?
- **Acceptance Criteria**: All met? (checkboxes)
- **Files Modified**: Expected files changed?
- **Tests Added**: Test coverage adequate?
- **Docs Updated**: Documentation current?

### Validation Status

- **Complete** ✓: All checks pass
- **Partial** ⚠: Most pass, some warnings
- **Incomplete** ✗: Critical failures

## Archival

When work completes:

```bash
/fractary-spec:archive 123
```

### Pre-Archive Checks

**Required**:
- Issue closed OR PR merged
- Specs exist

**Warnings** (prompt if fail):
- Documentation updated?
- Validation complete?

### Archival Process

1. Collect all specs for issue
2. Check conditions
3. Upload to cloud (fractary-file)
4. Update archive index
5. Comment on GitHub (issue + PR)
6. Remove from local
7. Git commit

### Archive Location

```
Cloud: archive/specs/{year}/{issue_number}.md
Index: .fractary/plugins/spec/archive-index.json
```

## Configuration

Edit `.fractary/plugins/spec/config.json`:

```json
{
  "storage": {
    "local_path": "/specs",
    "cloud_archive_path": "archive/specs/{year}/{issue_number}.md"
  },
  "archive": {
    "auto_archive_on": {
      "issue_close": true,
      "pr_merge": true,
      "faber_release": true
    },
    "pre_archive": {
      "check_docs_updated": "warn",
      "prompt_user": true
    }
  }
}
```

## FABER Integration

### Automatic Workflow

In `.faber.config.toml`:

```toml
[workflow.architect]
generate_spec = true
spec_plugin = "fractary-spec"

[workflow.evaluate]
validate_spec = true

[workflow.release]
archive_spec = true
```

### Phases

- **Architect**: Generate spec from issue
- **Evaluate**: Validate implementation
- **Release**: Archive to cloud

No manual commands needed in FABER workflow!

## GitHub Integration

### Spec Creation Comment

```markdown
📋 Specification Created

Specification generated for this issue:
- [spec-123-feature.md](/specs/spec-123-feature.md)

This spec will guide implementation and be validated before archival.
```

### Archive Comment

```markdown
✅ Work Archived

This issue has been completed and archived!

**Specifications**:
- [Phase 1: Authentication](https://storage.example.com/specs/2025/123-phase1.md) (15.4 KB)
- [Phase 2: OAuth](https://storage.example.com/specs/2025/123-phase2.md) (18.9 KB)

**Archived**: 2025-01-15 14:30 UTC
**Validation**: All specs validated ✓

These specifications are permanently stored in cloud archive for future reference.
```

## Architecture

### 3-Layer Pattern

```
Commands (Entry Points)
    ↓
Agent (spec-manager)
    ↓
Skills (generator, validator, archiver, linker)
    ↓
Scripts (Shell scripts for deterministic operations)
```

### Skills

- **spec-generator**: Create specs from issues
- **spec-validator**: Validate implementation
- **spec-archiver**: Archive to cloud
- **spec-linker**: Link specs to issues/PRs

### Agent

- **spec-manager**: Orchestrates full lifecycle

## Directory Structure

```
plugins/spec/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── spec-manager.md
├── commands/
│   ├── init.md
│   ├── generate.md
│   ├── validate.md
│   ├── archive.md
│   └── read.md
├── skills/
│   ├── spec-generator/
│   │   ├── SKILL.md
│   │   ├── templates/
│   │   ├── workflow/
│   │   ├── scripts/
│   │   └── docs/
│   ├── spec-validator/
│   ├── spec-archiver/
│   └── spec-linker/
├── config/
│   └── config.example.json
└── README.md
```

## Dependencies

### Required

- **fractary-work**: GitHub integration (issue fetch, comments)
- **fractary-file**: Cloud storage (upload, read)

### Optional

- **faber**: Automatic workflow integration

## Workflow Example

```bash
# 1. Initialize
/fractary-spec:init

# 2. Generate spec from issue
/fractary-spec:generate 123

# 3. Implement following spec
# ... development work ...

# 4. Validate implementation
/fractary-spec:validate 123

# 5. Archive when complete
/fractary-spec:archive 123

# 6. Later: read archived spec
/fractary-spec:read 123
```

## Best Practices

### Spec Generation

- Generate specs early (Architect phase)
- Use multi-spec for large issues
- Let auto-classification choose template
- Override template if needed

### During Development

- Refer to spec regularly
- Update acceptance criteria checkboxes
- Keep spec in sync with reality

### Validation

- Validate before archival
- Address warnings promptly
- Use validation as checklist

### Archival

- Archive when work complete
- Don't skip pre-archive checks
- Update docs before archiving
- Let FABER handle automatically

### Reading Archives

- Read for reference only
- Don't maintain local copies
- Link to archived specs in docs

## Troubleshooting

### Spec Generation Issues

**Issue not found**:
- Check issue number
- Verify GitHub access

**Template not found**:
- Falls back to basic template
- Check plugin installation

### Validation Issues

**Spec not found**:
- Generate spec first
- Check issue number

**Git errors**:
- Some checks require git
- Manual verification needed

### Archival Issues

**Upload failed**:
- Check cloud storage config
- Verify fractary-file plugin
- Retry after fixing

**Index update failed**:
- Critical error
- Manual index update needed

**Pre-checks failed**:
- Close issue or merge PR
- Or use --force to override

## Advanced Usage

### Custom Templates

Add custom templates to `skills/spec-generator/templates/`.

### Configuration Overrides

Override defaults per project in config file.

### Integration with CI/CD

```bash
# In CI pipeline
/fractary-spec:validate $ISSUE_NUMBER
```

Fail build if validation incomplete.

## Contributing

Contributions welcome! See main repository for guidelines.

## License

Same as parent repository.

## Support

- GitHub Issues: Report bugs and feature requests
- Documentation: See `/docs` directory
- FABER Integration: See FABER documentation

## Version

1.0.0 - Initial release

## Changelog

See CHANGELOG.md for version history.
