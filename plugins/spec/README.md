# Fractary Spec Plugin

**Ephemeral Specifications with Lifecycle-Based Archival**

The fractary-spec plugin manages point-in-time specifications tied to work items. Unlike documentation (living state), specs are temporary requirements that become stale once work completes. This plugin handles the full lifecycle: generation from issues, validation against implementation, and archival to cloud storage.

## Philosophy

**Specs ≠ Docs**

- **Specs**: Ephemeral, point-in-time requirements. Archived when complete.
- **Docs**: Living state, continuously updated. Never archived.

Keeping old specs in the workspace pollutes context. This plugin archives completed specs to cloud storage and removes them locally, keeping only active specifications in the workspace.

## Two Creation Modes

### Context-Based Creation (`/fractary-spec:create`)

**When to use**:
- After planning discussions with Claude
- Rich design conversations about architecture, approach, tradeoffs
- Want to capture the full planning context, not just issue text
- Exploratory work (standalone specs)

**How it works**:
- Uses full conversation context as primary source
- Optionally enriches with issue data via `--work-id`
- Directly invokes skill to preserve context
- Auto-detects template from conversation
- Naming: `WORK-*` (with work-id) or `SPEC-*` (standalone)

### Issue-Based Creation (`/fractary-spec:create-from-issue`)

**When to use**:
- Issue has complete requirements in description/comments
- Straightforward implementation from issue data
- Multi-phase work (supports `--phase` flag)
- Traditional workflow

**How it works**:
- Fetches full issue data (description + all comments)
- Uses issue content as primary source
- Goes through agent (standard pattern)
- Auto-detects template from labels/title
- Naming: `WORK-*` with zero-padded issue numbers

## Features

- ✅ **Dual Creation Modes**: From issues OR conversation context
- ✅ **Context Preservation**: Direct skill invocation preserves planning discussions
- ✅ **Issue Enrichment**: Fetches full issue data (description + all comments)
- ✅ **Multi-Spec Support**: Multiple specs per issue (phases)
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

### Two Ways to Create Specs

#### Option A: From Conversation Context (Recommended for Planning Sessions)

After a planning discussion:

```bash
/fractary-spec:create --work-id 123
```

- Uses full conversation context as primary source
- Enriches with issue data (description + all comments)
- Preserves all planning decisions discussed
- Creates `/specs/WORK-00123-feature.md`
- Comments on issue

**Standalone spec** (no issue):
```bash
/fractary-spec:create
```

Creates `/specs/SPEC-20250115143000-feature.md` (no GitHub linking).

#### Option B: From GitHub Issue (Traditional)

```bash
/fractary-spec:create-from-issue 123
```

- Fetches issue data (description + all comments)
- Creates spec primarily from issue content
- Creates `/specs/WORK-00123-feature.md`
- Comments on issue

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
| `/fractary-spec:create [--work-id <id>]` | Create spec from conversation context (optional issue enrichment) |
| `/fractary-spec:create-from-issue <issue>` | Create spec from GitHub issue data |
| `/fractary-spec:validate <issue>` | Validate implementation |
| `/fractary-spec:archive <issue>` | Archive to cloud |
| `/fractary-spec:read <issue>` | Read archived spec |

### Command Comparison

| Aspect | `create` | `create-from-issue` |
|--------|----------|---------------------|
| Primary Source | Conversation context | Issue data |
| Context Preserved | ✓ Yes | ✗ No |
| Issue Fetch | Optional (with `--work-id`) | Required |
| Use Case | Planning discussions | Issue-driven work |
| Naming (no issue) | `SPEC-{timestamp}-*` | N/A |
| Naming (with issue) | `WORK-{id:05d}-*` | `WORK-{id:05d}-*` |

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

For large issues, create multiple specs (issue-based mode only):

```bash
/fractary-spec:create-from-issue 123 --phase 1 --title "Authentication"
/fractary-spec:create-from-issue 123 --phase 2 --title "OAuth Integration"
```

Creates:
- `WORK-00123-01-authentication.md`
- `WORK-00123-02-oauth-integration.md`

All archived together when issue completes.

**Note**: Multi-spec with phases only supported in `create-from-issue` mode. For context-based creation, use multiple calls to `/fractary-spec:create` with different context.

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

### Command Options

**Context-based** (recommended for planning sessions):
```toml
spec_command = "create"
```
Uses conversation context with optional issue enrichment.

**Issue-based** (traditional):
```toml
spec_command = "create-from-issue"
```
Uses issue data as primary source.

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
│   ├── create.md              # Context-based creation
│   ├── create-from-issue.md   # Issue-based creation
│   ├── validate.md
│   ├── archive.md
│   └── read.md
├── skills/
│   ├── spec-generator/
│   │   ├── SKILL.md
│   │   ├── templates/
│   │   ├── workflow/
│   │   │   ├── generate-from-issue.md      # Issue-based workflow
│   │   │   └── generate-from-context.md    # Context-based workflow
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

# 2. Create spec from issue data
/fractary-spec:create-from-issue 123

# Output: /specs/WORK-00123-feature-name.md
# - Uses issue description + all comments
# - Auto-detects template from labels
# - GitHub comment added

# 3. Implement following spec
# ... development work ...

# 4. Validate implementation
/fractary-spec:validate 123

# 5. Archive when complete
/fractary-spec:archive 123

# 6. Later: read archived spec
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

**Choosing the Right Mode**:
- Use `/fractary-spec:create` after planning discussions to capture rich context
- Use `/fractary-spec:create-from-issue` for straightforward issue-driven work
- Add `--work-id` to context-based specs to link them to issues

**General Tips**:
- Generate specs early (Architect phase)
- Use multi-spec for large issues (issue-based mode only)
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

