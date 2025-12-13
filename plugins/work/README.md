# Fractary Work Plugin v2.0

Universal work item management across GitHub Issues, Jira Cloud, and Linear.

## Overview

The **Fractary Work Plugin** provides a unified interface for managing issues, tickets, and work items across multiple project management platforms. It abstracts platform-specific differences through a handler pattern, enabling seamless multi-platform support.

**Version:** 2.0.0
**Status:** Production Ready
**Platforms:** GitHub Issues ✅ | Jira Cloud ✅ | Linear ✅

## Key Features

- ✅ **Universal Interface**: Same operations work across all platforms
- ✅ **18 Operations**: Complete CRUD + search + relationships + milestones
- ✅ **100% Feature Parity**: All 3 handlers support identical operations
- ✅ **Normalized Data Model**: Consistent JSON output regardless of platform
- ✅ **Context Efficient**: 3-layer architecture minimizes LLM token usage
- ✅ **Configuration Driven**: Switch platforms without code changes

## Platforms Supported

| Platform | Status | Operations | Features |
|----------|--------|------------|----------|
| **GitHub Issues** | ✅ Complete | 18/18 | gh CLI, label-based states, comment linking |
| **Jira Cloud** | ✅ Complete | 18/18 | REST API v3, ADF format, workflow transitions, JQL |
| **Linear** | ✅ Complete | 18/18 | GraphQL API, native markdown, UUID lookups, cycles |

## Architecture

### 3-Layer Design

```
Layer 1: FABER Workflow Phases / Commands
   ↓
Layer 2: work-manager Agent (Pure Router)
   ↓
Layer 3: Focused Skills (11 skills)
   ↓
Layer 4: Handler Skills (Platform Abstraction)
   ↓
Layer 5: Scripts (Deterministic Operations)
```

**Benefits:**
- Skills focus on single operations (issue-fetcher, state-manager, etc.)
- Handlers centralize platform-specific logic
- Scripts execute outside LLM context (55-60% context reduction)

### Components

#### Agent (1)

**`work-manager`** - Pure JSON router
- Parses operation requests
- Routes to appropriate focused skill
- Returns normalized responses
- Never executes operations directly

#### Focused Skills (11)

1. **issue-fetcher** - Retrieve issue details
2. **issue-classifier** - Determine work type (/bug, /feature, /chore, /patch)
3. **issue-creator** - Create new issues
4. **issue-updater** - Update title/description
5. **state-manager** - Lifecycle state changes (CRITICAL for Release phase)
6. **comment-creator** - Post comments with FABER metadata
7. **label-manager** - Add/remove labels
8. **issue-assigner** - Assign/unassign users
9. **issue-linker** - Create relationships between issues
10. **milestone-manager** - Manage milestones/sprints/cycles
11. **issue-searcher** - Query and list issues

#### Handler Skills (3)

- **handler-work-tracker-github** - GitHub Issues adapter (gh CLI)
- **handler-work-tracker-jira** - Jira Cloud adapter (REST API v3)
- **handler-work-tracker-linear** - Linear adapter (GraphQL)

Each handler implements **18 scripts** for complete operation coverage.

#### Utility Library

**work-common** - Shared utilities
- `config-loader.sh` - Load/validate configuration
- `markdown-to-adf.sh` - Markdown → ADF for Jira
- `jira-auth.sh` - Jira authentication helper
- `jql-builder.sh` - JQL query builder

## Prerequisites

### Fractary CLI (Required)

The work plugin requires the Fractary CLI for core operations:

```bash
# Install Fractary CLI globally
npm install -g @fractary/cli

# Verify installation
fractary --version
```

**Minimum CLI Version:** `@fractary/cli >= 0.3.0`

### Additional Dependencies

- **jq** - JSON parsing (usually pre-installed on most systems)
  ```bash
  # macOS
  brew install jq

  # Ubuntu/Debian
  sudo apt-get install jq

  # Windows (via scoop)
  scoop install jq
  ```

## Installation

```bash
# Install plugin
claude plugin install fractary/work

# Set up authentication
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"        # For GitHub
export JIRA_EMAIL="user@example.com"                  # For Jira
export JIRA_TOKEN="jira_api_token"                    # For Jira
export LINEAR_API_KEY="lin_api_xxxxxxxxxxxxxxxxxxxx"  # For Linear
```

## Configuration

Create `.fractary/plugins/work/config.json`:

```json
{
  "version": "1.0",
  "project": {
    "issue_system": "github",
    "repository": "owner/repo"
  },
  "handlers": {
    "work-tracker": {
      "active": "github",
      "github": {
        "owner": "myorg",
        "repo": "my-project",
        "classification": {
          "feature": ["feature", "enhancement"],
          "bug": ["bug", "fix"],
          "chore": ["chore", "maintenance", "docs"],
          "patch": ["hotfix", "patch", "urgent"]
        },
        "states": {
          "open": "OPEN",
          "in_progress": "OPEN",
          "in_review": "OPEN",
          "done": "CLOSED",
          "closed": "CLOSED"
        },
        "labels": {
          "prefix": "faber-",
          "in_progress": "in-progress",
          "completed": "completed"
        }
      }
    }
  }
}
```

**Template:** See `config/config.example.json` for complete configuration with all platforms.

## Commands

The work plugin provides user-facing commands for common operations:

### Setup

- **`/fractary-work:init`** - Interactive setup wizard
  ```bash
  /fractary-work:init                    # Interactive mode
  /fractary-work:init --platform github  # Specify platform
  /fractary-work:init --force            # Reconfigure
  ```

### Issue Management

- **`/fractary-work:issue`** - Create, fetch, update, search, and manage issues
  ```bash
  /fractary-work:issue create "Add feature" --type feature
  /fractary-work:issue fetch 123
  /fractary-work:issue list --state open --label bug
  /fractary-work:issue update 123 --title "New title"
  /fractary-work:issue assign 123 @me
  /fractary-work:issue search "authentication"
  ```

### Comments

- **`/fractary-work:comment`** - Create and manage comments
  ```bash
  /fractary-work:comment create 123 "Working on this"
  /fractary-work:comment list 123
  ```

### State Management

- **`/fractary-work:state`** - Manage issue lifecycle states
  ```bash
  /fractary-work:state close 123 --comment "Fixed in PR #456"
  /fractary-work:state reopen 123
  /fractary-work:state transition 123 in_progress
  ```

### Labels

- **`/fractary-work:label`** - Add, remove, and manage labels
  ```bash
  /fractary-work:label add 123 bug
  /fractary-work:label remove 123 wontfix
  /fractary-work:label list 123
  /fractary-work:label set 123 bug high-priority
  ```

### Milestones

- **`/fractary-work:milestone`** - Create and manage milestones
  ```bash
  /fractary-work:milestone create "v1.0" --due 2025-12-31
  /fractary-work:milestone list
  /fractary-work:milestone set 123 "v1.0"
  /fractary-work:milestone remove 123
  ```

**Command Documentation:** See `commands/*.md` for detailed command documentation and examples.

## Session Tracking

The work plugin automatically posts progress updates to issues when working on issue-linked branches.

### How It Works

- **Automatic Detection**: When you work on a branch named with an issue ID (e.g., `feat/123-add-auth`), the plugin tracks your progress
- **Incremental Updates**: Only posts comments when meaningful work occurs (commits or changes detected)
- **Smart Summaries**: Generates summaries showing:
  - Commits made since last update
  - Commit type breakdown (feat, fix, docs, etc.)
  - Outstanding work (uncommitted changes, test validation)
  - Recommended next steps
- **Performance Optimized**: Reads issue_id from repo plugin cache (fast), falls back to branch parsing if unavailable

### Branch Naming Requirements

Session tracking requires branches to follow this pattern:

```
<type>/<issue_id>-<description>
```

**Examples:**
```bash
feat/123-add-authentication    # Feature work on issue #123
fix/456-login-bug             # Bug fix for issue #456
hotfix/789-security-patch     # Urgent fix for issue #789
chore/111-update-deps         # Maintenance for issue #111
```

**Supported types:** `feat`, `fix`, `chore`, `hotfix`, `patch`

### Configuration

The session tracking hook is installed automatically and runs on Stop events. No additional configuration required.

**To disable:**
- Remove or modify `plugins/work/hooks/hooks.json`

### Example Output

When you stop a Claude Code session after making commits, the plugin posts a comment like:

```markdown
## 🔄 Work Update

_Changes since last update (from `abc1234`)_

### What Was Done

**2 commit(s) made:**

- `def5678` feat: Add user authentication
- `ghi9012` test: Add auth tests

- ✨ **1** feature(s) added
- ✅ **1** test(s) added/updated
- 📁 **8** file(s) modified

### Outstanding Work

- 🧪 **Test validation** - ensure tests pass before merging

### Recommended Next Steps

1. **Run final tests** to validate changes
2. **Create pull request** for review
3. **Address any review feedback**

---
_🤖 Auto-generated work update • Branch: `feat/123-add-auth` • 2025-11-12 16:49 UTC_
```

### Performance Notes

- **Fast Path**: Reads issue_id from repo plugin cache (~10ms)
- **Fallback**: Parses branch name if cache unavailable (~50ms)
- **Early Exit**: Skips comment if no changes detected (no network call)
- **Cache Cleanup**: Automatically removes stale branch references every 20 executions

### Troubleshooting

**Comment not posted:**
- Verify branch name matches pattern: `<type>/<issue_id>-<description>`
- Check GitHub authentication: `gh auth login`
- Ensure issue exists in repository
- Verify network connectivity

**Issue ID not detected:**
- Repo plugin may not be installed (falls back to branch parsing)
- Update repo cache: Issue ID is cached on UserPromptSubmit hook
- Branch name doesn't match expected pattern

## Agent Usage

### Protocol: JSON Request/Response

Work manager v2.0 uses structured JSON for all operations:

```bash
claude --agent work-manager '{
  "operation": "fetch",
  "parameters": {"issue_id": "123"}
}'
```

### 18 Supported Operations

#### Read Operations
- `fetch` - Get complete issue details
- `classify` - Determine work type
- `list` - Filter issues by criteria
- `search` - Full-text search

#### Create Operations
- `create` - Create new issue

#### Update Operations
- `update` - Modify title/description
- `update-state` - Change lifecycle state

#### State Operations
- `close` - Close/resolve issue (**CRITICAL**)
- `reopen` - Reopen closed issue

#### Communication
- `comment` - Post comment with metadata

#### Metadata Operations
- `add-label` - Add label to issue
- `remove-label` - Remove label from issue
- `assign` - Assign user to issue
- `unassign` - Remove assignee
- `link` - Create relationship between issues

#### Milestone Operations
- `create-milestone` - Create milestone/sprint/cycle
- `update-milestone` - Update milestone properties
- `assign-milestone` - Assign issue to milestone

### Example Operations

#### Fetch Issue
```bash
claude --agent work-manager '{
  "operation": "fetch",
  "parameters": {"issue_id": "123"}
}'
```

**Response:**
```json
{
  "status": "success",
  "operation": "fetch",
  "result": {
    "id": "123",
    "identifier": "#123",
    "title": "Fix login bug",
    "state": "open",
    "labels": ["bug", "urgent"],
    "platform": "github",
    "url": "https://github.com/..."
  }
}
```

#### Close Issue (CRITICAL for FABER Release)
```bash
claude --agent work-manager '{
  "operation": "close",
  "parameters": {
    "issue_id": "123",
    "close_comment": "Fixed in PR #456",
    "work_id": "abc12345"
  }
}'
```

#### Create Issue
```bash
claude --agent work-manager '{
  "operation": "create",
  "parameters": {
    "title": "Add dark mode",
    "description": "Users want dark mode support",
    "labels": "feature,ui",
    "assignees": "username"
  }
}'
```

#### Search Issues
```bash
claude --agent work-manager '{
  "operation": "search",
  "parameters": {
    "query_text": "login crash",
    "limit": 20
  }
}'
```

## Integration with FABER

The work plugin integrates with all FABER workflow phases:

### Frame Phase
- **Fetch** issue details
- **Classify** work type (/bug, /feature, /chore, /patch)
- **Add label** "faber-in-progress"
- **Post comment** "Frame phase started"

### Build Phase
- **Post comment** with phase updates

### Evaluate Phase
- **Post comment** with test results

### Release Phase (CRITICAL)
- **Close issue** (v2.0 fix - actually closes!)
- **Remove label** "faber-in-progress"
- **Add label** "faber-completed"
- **Post comment** with PR link and deployment info

## Directory Structure

```
work/
├── .claude-plugin/
│   └── plugin.json                              # Plugin manifest
├── agents/
│   └── work-manager.md                          # Pure routing agent (574 lines)
├── skills/
│   ├── issue-fetcher/SKILL.md                   # Fetch operations
│   ├── issue-classifier/SKILL.md                # Classification
│   ├── issue-creator/SKILL.md                   # Create operations
│   ├── issue-updater/SKILL.md                   # Update operations
│   ├── state-manager/SKILL.md                   # State changes (CRITICAL)
│   ├── comment-creator/SKILL.md                 # Comments
│   ├── label-manager/SKILL.md                   # Labels
│   ├── issue-assigner/SKILL.md                  # Assignments
│   ├── issue-linker/SKILL.md                    # Relationships
│   ├── milestone-manager/SKILL.md               # Milestones
│   ├── issue-searcher/SKILL.md                  # Query/search
│   ├── work-common/                             # Shared utilities
│   │   ├── SKILL.md
│   │   └── scripts/ (7 scripts)
│   ├── handler-work-tracker-github/             # GitHub adapter
│   │   ├── SKILL.md                             # Handler documentation (426 lines)
│   │   ├── scripts/ (18 scripts)
│   │   └── docs/github-api.md
│   ├── handler-work-tracker-jira/               # Jira adapter
│   │   ├── SKILL.md                             # Handler documentation (271 lines)
│   │   ├── scripts/ (18 scripts)
│   │   └── docs/jira-api.md
│   └── handler-work-tracker-linear/             # Linear adapter
│       ├── SKILL.md                             # Handler documentation
│       ├── scripts/ (18 scripts)
│       └── docs/linear-api.md
├── config/
│   └── config.example.json                      # Configuration template (224 lines)
├── docs/
│   ├── MIGRATION-v1-to-v2.md                    # Migration guide
│   └── TESTING.md                               # Testing guide
└── README.md                                    # This file
```

## Platform Comparison

| Feature | GitHub | Jira | Linear |
|---------|--------|------|--------|
| **API Type** | REST + CLI | REST | GraphQL |
| **States** | 2 (open/closed) | Custom workflows | Team-specific |
| **Labels** | Direct names | Direct names | UUID lookup required |
| **Comments** | Markdown | ADF (converted) | Markdown |
| **Linking** | Via comments | Native API | Native relations |
| **Milestones** | Milestones | Versions/Sprints | Cycles |
| **Cost** | Free (public repos) | $$$ | $$ |
| **Best For** | OSS projects | Enterprise | Modern startups |

## Adding New Platforms

To add support for a new platform:

1. **Create handler directory:**
   ```bash
   mkdir -p skills/handler-work-tracker-{platform}/{scripts,docs}
   ```

2. **Implement 18 scripts** matching existing handlers:
   - Read operations (4): fetch, classify, list, search
   - Create operations (1): create
   - Update operations (2): update, update-state
   - State operations (2): close, reopen
   - Communication (1): comment
   - Metadata (6): add-label, remove-label, assign, unassign, link, assign-milestone
   - Milestone operations (2): create-milestone, update-milestone

3. **Create handler SKILL.md** documenting all operations

4. **Add API reference:** `docs/{platform}-api.md`

5. **Update configuration** template with platform settings

6. **Test all 18 operations** for feature parity

## Migration from v1.x

**Breaking Changes:**
- String protocol → JSON protocol
- Monolithic skill → 11 focused skills
- Configuration moved to `.fractary/plugins/work/config.json`

See `docs/MIGRATION-v1-to-v2.md` for detailed migration guide.

## Testing

See `docs/TESTING.md` for:
- Unit testing per script
- Integration testing (skill → handler)
- Cross-platform consistency tests
- FABER workflow end-to-end tests

## Troubleshooting

### "Issue not found"
- Verify issue ID format (GitHub: 123, Jira: PROJ-123, Linear: TEAM-123)
- Check authentication is valid
- Ensure issue exists in configured repository/project/team

### "Authentication failed"
- Verify environment variables are set
- Check tokens haven't expired
- Test authentication with platform CLI/API

### "Label not found" (Linear)
- Linear requires UUID lookups for labels
- Verify label exists in team settings
- Check label name spelling (case-sensitive)

## Performance

**Benchmarks** (estimated):
- Fetch operation: <500ms
- List operation (50 issues): <2s
- Create/update: <1s

**Optimization:**
- Scripts execute outside LLM context
- Configuration lookups cached where possible
- GraphQL queries optimized (Linear)

## Statistics

**Total Implementation:**
- **15 Skills:** 11 focused + 3 handlers + 1 utilities
- **54 Scripts:** 18 × 3 handlers
- **~8,000 Lines:** Total implementation
- **3 Platforms:** GitHub, Jira, Linear with 100% parity

## Version History

- **v2.0.0** (2025-10-29) - Full rewrite with Linear support, 100% feature parity
- **v1.0.0** (2025-10-22) - Initial MVP with GitHub support

## License

Part of the Fractary plugin ecosystem.

## Related Plugins

- **fractary-faber** - Universal workflow orchestration (uses work plugin)
- **fractary-repo** - Source control management (similar architecture)
- **fractary-file** - File storage operations
- **fractary-codex** - Memory and knowledge management

## Contributing

Follow **Fractary Plugin Standards** when contributing:
- Commands never do work (invoke agents)
- Agents never do work (invoke skills)
- Skills coordinate handlers
- Scripts contain deterministic operations
- Documentation uses UPPERCASE XML tags

## Support

- **Issues**: https://github.com/fractary/claude-plugins/issues
- **Documentation**: `specs/SPEC-00003-work-plugin-specification.md`
- **Standards**: `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`
