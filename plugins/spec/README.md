# Fractary Spec Plugin

**Ephemeral Specifications with Lifecycle-Based Archival**

The fractary-spec plugin manages point-in-time specifications tied to work items. Unlike documentation (living state), specs are temporary requirements that become stale once work completes. This plugin handles the full lifecycle: generation from issues, validation against implementation, and archival to cloud storage.

## Philosophy

**Specs ≠ Docs**

- **Specs**: Ephemeral, point-in-time requirements. Archived when complete.
- **Docs**: Living state, continuously updated. Never archived.

Keeping old specs in the workspace pollutes context. This plugin archives completed specs to cloud storage and removes them locally, keeping only active specifications in the workspace.

## Specification Creation

### The `/fractary-spec:create` Command

**When to use**:
- After planning discussions with Claude
- Rich design conversations about architecture, approach, tradeoffs
- Want to capture the full planning context, not just issue text
- Working on issue-tied branches (auto-detects issue ID)
- Exploratory work (standalone specs)

**How it works**:
- Uses full conversation context as primary source
- **Auto-detects work ID** from branch name (e.g., `feat/123-name` → issue #123)
- Optionally enriches with issue data (when work_id detected or provided via `--work-id`)
- Directly invokes skill to preserve context
- Auto-detects template from conversation
- Naming: `WORK-*` (with work_id) or `SPEC-*` (standalone)

**Key Feature**: If you're on a branch tied to an issue (e.g., `feat/123-auth`), the command automatically detects and links to that issue - no need to specify `--work-id` manually.

## Features

- ✅ **Context Preservation**: Direct skill invocation preserves planning discussions
- ✅ **Auto-Detection**: Automatically detects issue ID from branch name (via repo plugin)
- ✅ **Issue Enrichment**: Fetches full issue data (description + all comments)
- ✅ **Smart Templates**: Auto-selects template based on work type or context
- ✅ **Validation**: Checks implementation completeness
- ✅ **Lifecycle Archival**: Archives when issue closes or PR merges
- ✅ **Cloud Storage**: Uses fractary-file for archival
- ✅ **GitHub Integration**: Comments on issues/PRs with spec links
- ✅ **FABER Integration**: Automatic workflow in FABER phases
- ✅ **Read from Cloud**: Access archived specs without download

## Installation

### Prerequisites

- `fractary-repo` plugin (GitHub integration, issue fetching)
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

### 1. Create Specification

#### Recommended: On Issue Branch (Auto-Detection)

```bash
# Create/checkout issue branch
/repo:branch-create "implement auth" --work-id 123

# Discuss and plan with Claude
# ... conversation about approach, design, requirements ...

# Create spec (auto-detects issue #123 from branch)
/fractary-spec:create
```

- Auto-detects issue #123 from branch `feat/123-implement-auth`
- Uses full conversation context as primary source
- Enriches with issue data (description + all comments)
- Creates `/specs/WORK-00123-implement-auth.md`
- Comments on issue #123

#### With Explicit Work ID

```bash
/fractary-spec:create --work-id 123
```

- Explicitly links to issue #123 (overrides branch detection)
- Use when you want to link to a different issue

#### Standalone Spec (No Issue)

```bash
/fractary-spec:create
```

- Uses only conversation context
- Creates `/specs/SPEC-20250115143000-feature.md`
- No GitHub linking

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
| `/fractary-spec:create [--work-id <id>]` | Create spec from conversation context (auto-detects issue from branch) |
| `/fractary-spec:validate <issue>` | Validate implementation |
| `/fractary-spec:archive <issue>` | Archive to cloud |
| `/fractary-spec:read <issue>` | Read archived spec |

### Key Features of `create`

- **Auto-Detection**: Automatically detects issue ID from current branch name (via repo plugin)
- **Context Preservation**: Direct skill invocation preserves full conversation context
- **Issue Enrichment**: Optionally fetches issue data when work_id detected or provided
- **Flexible Naming**: `WORK-{id:05d}-*` (with issue) or `SPEC-{timestamp}-*` (standalone)
- **Template Auto-Selection**: Infers template from conversation and issue context

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
spec_command = "create"  # or "create-from-issue" for issue-centric

[workflow.evaluate]
validate_spec = true

[workflow.release]
archive_spec = true
```

### Phases

- **Architect**: Generate spec (from context or issue)
- **Evaluate**: Validate implementation
- **Release**: Archive to cloud

### Configuration

```toml
spec_command = "create"
```

The `create` command automatically:
- Uses conversation context as primary source
- Auto-detects issue ID from branch name
- Enriches with issue data when available
- Preserves full planning context

No manual commands needed in FABER workflow!

## GitHub Integration

### Spec Creation Comment

```markdown
📋 Specification Created

Specification generated for this issue:
- [WORK-00123-feature.md](/specs/WORK-00123-feature.md)

Source: Conversation context + Issue data

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
│   ├── create.md              # Spec creation (context + auto-detection)
│   ├── validate.md
│   ├── archive.md
│   └── read.md
├── skills/
│   ├── spec-generator/
│   │   ├── SKILL.md
│   │   ├── templates/
│   │   ├── workflow/
│   │   │   └── generate-from-context.md    # Context + auto-detection workflow
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

- **fractary-repo**: GitHub integration (issue fetch with comments, PR operations, issue comments)
- **fractary-file**: Cloud storage (upload, read)

### Optional

- **faber**: Automatic workflow integration

## Workflow Examples

### Example 1: Context-Based (Planning Session)

```bash
# 1. Initialize
/fractary-spec:init

# 2. Have planning discussion with Claude
# User: "Let's design a user authentication system with OAuth2..."
# Claude: [discusses requirements, architecture, approach...]

# 3. Create spec from conversation context
/fractary-spec:create --work-id 123

# Output: /specs/WORK-00123-user-auth-oauth.md
# - Captures full planning discussion
# - Enriched with issue #123 data
# - GitHub comment added

# 4. Implement following spec
# ... development work ...

# 5. Validate implementation
/fractary-spec:validate 123

# 6. Archive when complete
/fractary-spec:archive 123

# 7. Later: read archived spec
/fractary-spec:read 123
```

### Example 2: Issue-Based (Traditional)

```bash
# 1. Initialize
/fractary-spec:init

# 2. Create/checkout issue branch
/repo:branch-create "implement feature" --work-id 123

# 3. Create spec (auto-detects issue #123 from branch)
/fractary-spec:create

# Output: /specs/WORK-00123-implement-feature.md
# - Auto-detected issue #123 from branch feat/123-implement-feature
# - Uses conversation context
# - Enriches with issue description + all comments
# - Auto-detects template
# - GitHub comment added

# 4. Implement following spec
# ... development work ...

# 5. Validate implementation
/fractary-spec:validate 123

# 6. Archive when complete
/fractary-spec:archive 123

# 7. Later: read archived spec
/fractary-spec:read 123
```

### Example 3: Standalone Exploratory Spec

```bash
# After design discussion (no work item yet)
/fractary-spec:create

# Output: /specs/SPEC-20250115143000-api-design.md
# - Standalone spec
# - No GitHub linking
# - For reference/planning
```

## Best Practices

### Spec Generation

**Recommended Workflow**:
1. Create/checkout issue branch using `/repo:branch-create --work-id <id>`
2. Discuss and plan with Claude (capture requirements, architecture, approach)
3. Run `/fractary-spec:create` (auto-detects issue from branch)
4. Spec is created with full conversation context + issue enrichment

**When to Use `--work-id` Explicitly**:
- You want to link to a different issue than the current branch
- You're on `main` or a non-issue branch but want to link to an issue
- You're overriding the auto-detected issue

**General Tips**:
- Generate specs early (Architect phase)
- Work on issue-tied branches for automatic detection
- Let auto-classification choose template
- Override template if needed with `--template`

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

## Archive Index: Two-Tier Storage

To prevent data loss, the archive index uses a **two-tier storage system**:

### Why Two-Tier?

The `.fractary` directory is git-ignored. If you lose your local environment (new machine, deleted directory), you lose the index of all archived specs. Without the index, you can't look up where specs are stored in the cloud.

### How It Works

**Tier 1: Local Cache**
- Location: `.fractary/plugins/spec/archive-index.json`
- Purpose: Fast lookups during normal operations
- Status: Git-ignored, not backed up
- Risk: Lost if local environment lost

**Tier 2: Cloud Backup**
- Location: `archive/specs/.archive-index.json` (in cloud storage)
- Purpose: Durable backup, recoverable
- Status: Automatically synced during archival
- Recovery: Synced on init if local missing

### Archival Process

When you archive specs:
1. ✅ Specs uploaded to cloud
2. ✅ Local index updated
3. ✅ **Index backed up to cloud** ← Prevents data loss
4. ✅ Local specs removed

### Recovery Process

If you lose your local environment:
1. Clone repo on new machine
2. Run `/fractary-spec:init`
3. **Index automatically synced from cloud**
4. All archived specs accessible via `/fractary-spec:read`

### Example: Recovering After Data Loss

```bash
# Scenario: New machine, lost .fractary directory

# Initialize plugin
/fractary-spec:init

# Output:
# 🎯 Initializing fractary-spec plugin...
# Syncing archive index from cloud...
# ✓ Archive index synced from cloud
# ✓ Recovered 15 archived specs from cloud index!

# Now you can read any archived spec
/fractary-spec:read 123
```

### Fallback Behavior

If fractary-file plugin not available:
- ⚠️ Cloud sync disabled
- ⚠️ Index only stored locally
- ⚠️ Recommendation: Backup `.fractary` directory manually
- ⚠️ Or implement cloud sync when fractary-file available

### Configuration

```json
{
  "storage": {
    "archive_index": {
      "local_cache": ".fractary/plugins/spec/archive-index.json",
      "cloud_backup": "archive/specs/.archive-index.json"
    }
  }
}
```

