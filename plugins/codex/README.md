# Fractary Codex Plugin

**Documentation and knowledge sync across organization projects** - A memory fabric for AI agents.

The codex plugin provides tooling for synchronizing documentation between projects and a central codex repository. This creates a shared "memory fabric" where common standards, guides, and documentation are accessible across all projects in an organization.

## Overview

### The Problem

AI agents working across multiple projects need consistent access to:
- Shared standards and guidelines
- Common documentation
- System interfaces for integration
- Project-specific context

Without centralized sync, this knowledge becomes fragmented and inconsistent.

### The Solution

The codex plugin maintains a central repository (the "codex") that syncs bidirectionally with all projects:

```
Project A  ←→  Codex  ←→  Project B
Project C  ←→         ←→  Project D
```

**Key benefits:**
- Shared docs distributed automatically to all projects
- Project-specific docs aggregated in codex for visibility
- Bidirectional sync keeps everything up-to-date
- Pattern-based routing for fine-grained control

## Quick Start

### 1. Initialize Configuration

```bash
/fractary-codex:init
```

This will:
- Auto-detect your organization from git remote
- Help you specify the codex repository
- Create configuration files with sensible defaults

### 2. Sync Your Project

```bash
# Sync current project (bidirectional)
/fractary-codex:sync-project

# Sync specific project
/fractary-codex:sync-project my-project

# Preview changes first (recommended)
/fractary-codex:sync-project --dry-run

# Sync only one direction
/fractary-codex:sync-project --to-codex
/fractary-codex:sync-project --from-codex
```

### 3. Sync Entire Organization (Optional)

```bash
# Preview organization-wide sync
/fractary-codex:sync-org --dry-run

# Sync all projects
/fractary-codex:sync-org
```

## Features

### Bidirectional Sync

- **Project → Codex**: Pull project-specific docs into codex
- **Codex → Projects**: Push shared docs from codex to projects
- **Bidirectional**: Both directions in sequence

### Pattern-Based Routing

Control what syncs using glob patterns:

```json
{
  "sync_patterns": [
    "docs/**",
    "CLAUDE.md",
    "README.md",
    ".claude/**"
  ],
  "exclude_patterns": [
    "docs/private/**",
    "docs/drafts/**"
  ]
}
```

### Frontmatter Routing (Advanced)

Embed sync rules directly in markdown files:

```markdown
---
codex_sync_include: ["docs/api/**", "docs/guides/**"]
codex_sync_exclude: ["docs/internal/**"]
---
```

### Safety Features

- **Deletion Thresholds**: Blocks syncs that would delete too many files
- **Dry-Run Mode**: Preview changes before applying
- **Validation**: Post-sync checks for integrity
- **Audit Logging**: Track all sync operations

### Parallel Execution

Organization-wide syncs process multiple projects simultaneously:
- Configurable parallelism (default: 5 concurrent)
- Proper phase sequencing (projects→codex, then codex→projects)
- Graceful error handling (continues with other projects if one fails)

## Architecture

### 3-Layer Design

The plugin follows Fractary's standard 3-layer architecture:

```
Commands (Entry Points)
   ↓
Agents (Orchestration)
   ↓
Skills (Execution)
   ↓
Scripts (Deterministic Operations)
```

This design minimizes LLM context usage by moving deterministic operations into bash scripts.

### Handler Pattern

Sync mechanisms are abstracted via handlers:

- **handler-sync-github**: Script-based sync (current)
- **handler-sync-vector**: Vector database sync (future)
- **handler-sync-mcp**: MCP server integration (future)

Switching handlers is just a configuration change.

### Integration with Fractary-Repo

All git operations (clone, commit, push) are delegated to the `fractary-repo` plugin:
- Clean separation of concerns
- Reuses existing authentication
- Platform-agnostic (GitHub, GitLab, Bitbucket)

## Commands

### `/fractary-codex:init`

Initialize codex plugin configuration.

**Usage:**
```bash
/fractary-codex:init                    # Initialize both global and project config
/fractary-codex:init --global           # Initialize only global config
/fractary-codex:init --project          # Initialize only project config
/fractary-codex:init --org fractary --codex codex.fractary.com
```

**Auto-detection:**
- Extracts organization from git remote URL
- Searches for `codex.*` repositories in organization
- Prompts for confirmation

### `/fractary-codex:sync-project`

Sync a single project with codex.

**Usage:**
```bash
/fractary-codex:sync-project                       # Current project, bidirectional
/fractary-codex:sync-project my-project            # Specific project
/fractary-codex:sync-project --dry-run             # Preview changes
/fractary-codex:sync-project --to-codex            # Only pull to codex
/fractary-codex:sync-project --from-codex          # Only push from codex
/fractary-codex:sync-project --patterns "docs/**,CLAUDE.md"
```

**Auto-detection:**
- Extracts project name from git remote if not specified

### `/fractary-codex:sync-org`

Sync all projects in organization with codex (parallel execution).

**Usage:**
```bash
/fractary-codex:sync-org                           # Sync all projects
/fractary-codex:sync-org --dry-run                 # Preview changes
/fractary-codex:sync-org --exclude "archive-*"     # Exclude archived repos
/fractary-codex:sync-org --parallel 10             # Sync 10 at a time
/fractary-codex:sync-org --to-codex                # Only pull to codex
```

**Performance:**
- Processes multiple projects concurrently (default: 5)
- Sequential phases: projects→codex completes before codex→projects starts
- Continues on individual failures, reports aggregate results

## Configuration

### Global Configuration

**Location**: `~/.config/fractary/codex/config.json`

**Purpose**: Organization-wide defaults

```json
{
  "version": "1.0",
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "default_sync_patterns": [
    "docs/**",
    "CLAUDE.md",
    "README.md",
    ".claude/**"
  ],
  "default_exclude_patterns": [
    "**/.git/**",
    "**/node_modules/**",
    "**/.env*"
  ],
  "handlers": {
    "sync": {
      "active": "github",
      "options": {
        "github": {
          "parallel_repos": 5,
          "deletion_threshold": 50,
          "deletion_threshold_percent": 20
        }
      }
    }
  }
}
```

### Project Configuration

**Location**: `.fractary/plugins/codex/config/codex.json`

**Purpose**: Project-specific overrides

```json
{
  "version": "1.0",
  "sync_patterns": [
    "docs/**",
    "standards/**"
  ],
  "exclude_patterns": [
    "docs/private/**"
  ],
  "sync_direction": "bidirectional"
}
```

### Configuration Priority

1. Project configuration (if exists)
2. Global configuration (if exists)
3. Auto-detection fallback

## Codex Repository Structure

The central codex repository typically follows this structure:

```
codex.organization.com/
├── projects/
│   ├── project1/
│   │   ├── docs/
│   │   └── CLAUDE.md
│   ├── project2/
│   │   ├── docs/
│   │   └── CLAUDE.md
├── shared/
│   ├── standards/
│   ├── guides/
│   └── templates/
└── systems/
    └── interfaces/
```

- **projects/**: Project-specific documentation aggregated from all projects
- **shared/**: Common documentation distributed to all projects
- **systems/**: System interfaces and integration docs

## Use Cases

### 1. Shared Standards

Maintain coding standards, style guides, and best practices in codex. Automatically distribute to all projects.

**Setup:**
1. Create `shared/standards/` in codex
2. Add docs: `coding-standards.md`, `git-workflow.md`, etc.
3. Run `/fractary-codex:sync-org --from-codex`
4. All projects receive standards automatically

### 2. API Documentation

Keep API documentation synced across service boundaries.

**Setup:**
1. Each service syncs its API docs to codex: `systems/interfaces/service-name/`
2. Consuming services pull interface docs from codex
3. Changes propagate automatically

### 3. Project Onboarding

New project setup with organization knowledge.

**Setup:**
1. Clone new project
2. Run `/fractary-codex:init`
3. Run `/fractary-codex:sync-project --from-codex`
4. Project receives all shared documentation

### 4. Documentation Aggregation

Aggregate project-specific docs for organization-wide visibility.

**Setup:**
1. Each project has unique docs in `docs/`
2. Run `/fractary-codex:sync-org --to-codex`
3. Codex has complete view of all project documentation

## Troubleshooting

### Configuration Not Found

```
⚠️ Configuration required
Run: /fractary-codex:init
```

**Resolution**: Initialize configuration with init command

### Authentication Failed

```
❌ Failed to clone repository: authentication required
```

**Resolution**: Ensure `fractary-repo` plugin is configured with authentication

### Deletion Threshold Exceeded

```
⚠️ Deletion threshold exceeded
Would delete: 75 files (threshold: 50)
```

**Resolution**:
- Review deletion list carefully
- Adjust threshold in config if intentional
- Fix sync patterns if unintentional

### Project Not Detected

```
❌ Cannot detect project from git remote
```

**Resolution**: Specify project name explicitly:
```bash
/fractary-codex:sync-project my-project
```

### Codex Repository Not Found

```
❌ Codex repository not found: codex.fractary.com
```

**Resolution**:
- Verify codex repository exists
- Check naming convention: `codex.{organization}.{tld}`
- Update configuration with correct name

## Best Practices

1. **Run dry-run first**: Always preview changes before first sync
   ```bash
   /fractary-codex:sync-project --dry-run
   ```

2. **Start with single project**: Test with one project before org-wide sync

3. **Review deletion thresholds**: Adjust based on your repo sizes and patterns

4. **Use exclude patterns**: Don't sync private, generated, or temporary files

5. **Document your patterns**: Keep a record of why certain patterns are included/excluded

6. **Monitor sync results**: Review commits after sync to ensure correctness

7. **Automate in CI/CD**: Set up automatic syncs on documentation changes

## Development

### Directory Structure

```
plugins/codex/
├── .claude-plugin/
│   ├── plugin.json              # Plugin metadata
│   └── config.schema.json       # Configuration schema
├── agents/
│   └── codex-manager.md         # Main orchestration agent
├── commands/
│   ├── init.md                  # Init command
│   ├── sync-project.md          # Project sync command
│   └── sync-org.md              # Organization sync command
├── skills/
│   ├── repo-discoverer/         # Repository discovery
│   ├── project-syncer/          # Single project sync
│   ├── org-syncer/              # Organization sync
│   └── handler-sync-github/     # GitHub sync handler
├── config/
│   ├── codex.example.json       # Example global config
│   └── codex.project.example.json # Example project config
└── docs/
    ├── setup-guide.md
    └── sync-mechanics.md
```

### Standards Compliance

This plugin follows [Fractary Plugin Standards](../../docs/standards/FRACTARY-PLUGIN-STANDARDS.md):
- 3-layer architecture (command → agent → skill → script)
- Handler pattern for provider abstraction
- XML markup in all agents and skills
- Deterministic operations in bash scripts
- Comprehensive error handling

## Dependencies

### Required

- **fractary-repo**: Source control operations (clone, commit, push)

### Optional

- **yq**: YAML parsing for frontmatter (falls back to basic parsing)
- **jq**: JSON processing (used throughout)
- **GNU parallel**: Parallel execution (falls back to sequential)

## Version History

### v2.0.0 (Current)

- Complete refactoring to Fractary standards
- Organization-agnostic implementation
- 3-layer architecture with handler pattern
- Local execution (no GitHub Actions dependency)
- Parallel organization sync
- Comprehensive configuration system
- Safety features (deletion thresholds, dry-run)

### v1.0.x (Deprecated)

- OmniDAS-specific implementation
- GitHub Actions workflows
- Limited to GitHub platform

## License

Part of the Fractary Claude Code Plugins ecosystem.

## Support

- **Documentation**: See `docs/` directory
- **Issues**: Report via repository issue tracker
- **Standards**: See [Fractary Plugin Standards](../../docs/standards/FRACTARY-PLUGIN-STANDARDS.md)

---

**Memory fabric for AI agents** - Keep documentation synchronized across your organization with the codex plugin.
