# FABER Plugin for Claude Code

**Tool-agnostic SDLC workflow automation**: From work item to production in 5 phases.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude-Code%20Plugin-blue)](https://claude.com/claude-code)

## What is FABER?

FABER is a **tool-agnostic workflow framework** that automates the complete software development lifecycle:

- 📋 **Frame** - Fetch and classify work item
- 📐 **Architect** - Design solution and create specification
- 🔨 **Build** - Implement from specification
- 🧪 **Evaluate** - Test and review with retry loop
- 🚀 **Release** - Deploy and create PR

### Key Features

- **Tool-Agnostic**: Works with GitHub, Jira, Linear, GitLab, Bitbucket, etc.
- **Domain-Agnostic**: Supports engineering, design, writing, and data workflows
- **Context-Efficient**: 3-layer architecture reduces token usage by 55-60%
- **Autonomous**: Configurable automation levels (dry-run, assist, guarded, autonomous)
- **Resilient**: Automatic retry loop for failed evaluations
- **Safe**: Protected paths, confirmation gates, and audit trails

## Quick Start

### 1. Initialize FABER

```bash
cd your-project
/fractary-faber:init
```

This auto-detects your project settings and creates `.fractary/plugins/faber/config.json`.

### 2. Configure Authentication

```bash
# For GitHub
gh auth login

# For Cloudflare R2 (optional)
aws configure
```

### 3. Run Your First Workflow

```bash
# Execute complete workflow for issue #123
/fractary-faber:run --work-id 123
```

That's it! FABER will:
1. Fetch and classify the issue
2. Generate a detailed specification
3. Implement the solution
4. Run tests and reviews
5. Create a pull request

## Installation

### Prerequisites

- Claude Code CLI
- Git
- GitHub CLI (`gh`) for GitHub integration
- Python 3.7+ (for configuration parsing)
- AWS CLI (if using Cloudflare R2/S3 storage)

### Install Plugin

```bash
# Clone the repository
git clone https://github.com/fractary/claude-plugins.git

# Navigate to plugins directory
cd claude-plugins/plugins

# The plugin is now available at:
# fractary-faber/
```

Claude Code will automatically discover the plugin.

## Configuration

**FABER v2.0** uses JSON-based configuration with JSON Schema validation and IDE autocompletion.

### Quick Setup

**Option 1: Auto-Initialize** (Recommended)

```bash
/fractary-faber:init
```

Creates `.fractary/plugins/faber/config.json` with default workflow configuration.

**Option 2: Use Templates**

```bash
# Create config directory
mkdir -p .fractary/plugins/faber

# Choose a template:
# Minimal - Bare essentials
cp plugins/faber/config/templates/minimal.json .fractary/plugins/faber/config.json

# Standard - Recommended for production (includes plugin integrations)
cp plugins/faber/config/templates/standard.json .fractary/plugins/faber/config.json

# Enterprise - Full-featured with hook examples
cp plugins/faber/config/templates/enterprise.json .fractary/plugins/faber/config.json
```

### Configuration Structure

```json
{
  "$schema": "../config.schema.json",
  "schema_version": "2.0",
  "workflows": [{
    "id": "default",
    "phases": {
      "frame": { "enabled": true, "steps": [...] },
      "architect": { "enabled": true, "steps": [...] },
      "build": { "enabled": true, "steps": [...] },
      "evaluate": { "enabled": true, "max_retries": 3, "steps": [...] },
      "release": { "enabled": true, "require_approval": true, "steps": [...] }
    },
    "autonomy": { "level": "guarded" }
  }],
  "integrations": {
    "work_plugin": "fractary-work",
    "repo_plugin": "fractary-repo"
  }
}
```

### Migrating from v1.x

If you have an existing `.faber.config.toml` file, see [MIGRATION-v2.md](docs/MIGRATION-v2.md) for migration instructions.

### Configuration Documentation

- [configuration.md](docs/configuration.md) - Complete configuration reference
- [PROMPT-CUSTOMIZATION.md](docs/PROMPT-CUSTOMIZATION.md) - Workflow customization guide
- [HOOKS.md](docs/HOOKS.md) - Phase-level hooks
- [STATE-TRACKING.md](docs/STATE-TRACKING.md) - Dual-state tracking system

## Usage

### GitHub Integration

**Trigger FABER directly from GitHub issues** using labels:

- Add `faber:run` label to trigger workflow
- Use `faber:workflow=hotfix` label to select workflow
- Use `faber:autonomy=autonomous` label to set autonomy level

**Setup** (one-time):
1. Add `.github/workflows/faber.yml` to your repository
2. Add `CLAUDE_CODE_OAUTH_TOKEN` secret
3. Create `.fractary/plugins/faber/config.json` in repository root
4. Add the `faber:run` label to any issue!

Status updates post automatically to GitHub issues. See [GitHub Integration Guide](docs/github-integration.md) for complete setup instructions and examples.

### CLI Commands

```bash
# Initialize FABER in a project
/fractary-faber:init

# Run workflow for an issue
/fractary-faber:run --work-id 123

# Check workflow status
/fractary-faber:status
```

### Advanced Usage

```bash
# Specify target and work item
/fractary-faber:run customer-analytics --work-id 123

# Override workflow
/fractary-faber:run --work-id 123 --workflow hotfix

# Override autonomy level
/fractary-faber:run --work-id 123 --autonomy autonomous

# Run specific phases
/fractary-faber:run --work-id 123 --phase frame,architect

# Run single step
/fractary-faber:run --work-id 123 --step build:implement

# Dry-run (simulation only)
/fractary-faber:run --work-id 123 --autonomy dry-run

# Add custom instructions
/fractary-faber:run --work-id 123 --prompt "Focus on performance"
```

### Supported Input Formats

FABER accepts multiple issue ID formats:

- **GitHub**: `123`, `#123`, `GH-123`, or full URL
- **Jira**: `PROJ-123` or full URL
- **Linear**: `LIN-123` or full URL

## Workflow Phases

### 1. Frame Phase
- Fetches work item from tracking system (GitHub, Jira, etc.)
- Classifies work type (bug, feature, chore, patch)
- Sets up domain-specific environment
- Creates git branch
- Posts status updates

### 2. Architect Phase
- Analyzes work item and codebase
- Generates detailed implementation specification
- Creates specification file (`.faber/specs/`)
- Commits and pushes specification
- Posts specification URL

### 3. Build Phase
- Implements solution from specification
- Follows domain best practices
- Creates tests/reviews as appropriate
- Commits implementation
- Pushes changes to remote

### 4. Evaluate Phase (with Retry Loop)
- Runs domain-specific tests
- Executes domain-specific review
- Makes GO/NO-GO decision
- **If NO-GO**: Returns to Build phase (up to 3 retries)
- **If GO**: Proceeds to Release
- **If max retries exceeded**: Fails workflow

### 5. Release Phase
- Creates pull request
- Optionally merges PR (if `auto_merge = true`)
- Uploads artifacts to storage
- Posts completion status
- Optionally closes work item

## Autonomy Levels

FABER supports 4 autonomy levels:

| Level | Behavior | Use When |
|-------|----------|----------|
| **dry-run** | Simulates workflow, no changes | Testing setup, debugging |
| **assist** | Stops before Release | Learning, cautious automation |
| **guarded** ⭐ | Pauses at Release for approval | Production workflows (recommended) |
| **autonomous** | Full automation, no pauses | Non-critical changes, internal tools |

⭐ **Recommended**: `guarded` provides the best balance of automation and control.

Set default in `.fractary/plugins/faber/config.json`:

```json
{
  "workflows": [{
    "autonomy": {
      "level": "guarded",
      "pause_before_release": true
    }
  }]
}
```

Override per workflow:

```bash
/fractary-faber:run --work-id 123 --autonomy autonomous
```

## Architecture

FABER uses a **3-layer architecture** for context efficiency:

```
Layer 1: Agents (Decision Logic)
   ↓
Layer 2: Skills (Adapter Selection)
   ↓
Layer 3: Scripts (Deterministic Operations)
```

### Why 3 Layers?

**Problem**: Traditional approaches load all code into LLM context (700+ lines)

**Solution**: Only load decision logic. Scripts execute outside context.

**Result**: 55-60% context reduction per manager invocation.

### Components

#### Agents (Decision Makers)
- `director` - Orchestrates complete workflow
- `frame-manager` - Manages Frame phase
- `architect-manager` - Manages Architect phase
- `build-manager` - Manages Build phase
- `evaluate-manager` - Manages Evaluate phase
- `release-manager` - Manages Release phase
- `work-manager` - Work tracking operations
- `repo-manager` - Source control operations
- `file-manager` - File storage operations

#### Skills (Adapters)
- `core` - Configuration, sessions, status cards
- `work-manager` - GitHub/Jira/Linear adapters
- `repo-manager` - GitHub/GitLab/Bitbucket adapters
- `file-manager` - R2/S3/local storage adapters

#### Commands (User Interface)
- `/fractary-faber:init` - Initialize FABER in a project
- `/fractary-faber:run` - Execute workflow (consolidated command)
- `/fractary-faber:status` - Show workflow status
- `/fractary-faber:audit` - Validate configuration

## Domain Support

FABER supports multiple work domains:

### Engineering ✅ (Implemented)
- Software development workflows
- Code implementation and testing
- Pull requests and code review

**Usage**: `/fractary-faber:run --work-id 123`

### Design 🚧 (Future)
- Design brief generation
- Asset creation
- Design review and publication

**Usage**: `/fractary-faber:run --work-id 123 --workflow design`

### Writing 🚧 (Future)
- Content outlines
- Writing and editing
- Content review and publication

**Usage**: `/fractary-faber:run --work-id 123 --workflow writing`

### Data 🚧 (Future)
- Pipeline design and implementation
- Data quality checks
- Pipeline deployment

**Usage**: `/fractary-faber:run --work-id 123 --workflow data`

## Platform Support

### Work Tracking
- ✅ GitHub Issues (via `gh` CLI)
- 🚧 Jira (future)
- 🚧 Linear (future)

### Source Control
- ✅ GitHub (via `git` + `gh` CLIs)
- 🚧 GitLab (future)
- 🚧 Bitbucket (future)

### File Storage
- ✅ Cloudflare R2 (via AWS CLI)
- ✅ Local filesystem
- 🚧 AWS S3 (future)

## Examples

### Example 1: Basic Workflow

```bash
# Initialize FABER
/fractary-faber:init

# Run workflow for GitHub issue #123
/fractary-faber:run --work-id 123

# FABER executes:
# 1. Frame: Fetches issue, creates branch
# 2. Architect: Generates specification
# 3. Build: Implements solution
# 4. Evaluate: Runs tests (retries if needed)
# 5. Release: Creates PR, waits for approval

# Check status
/fractary-faber:status

# Approve and merge (manual)
# - Review PR
# - Merge via GitHub UI
```

### Example 2: Autonomous Workflow

```bash
# Run with full automation
/fractary-faber:run --work-id 456 --autonomy autonomous

# FABER executes all phases and merges PR automatically
# ⚠️ Use only for non-critical changes!
```

### Example 3: Target-First Workflow

```bash
# Specify target artifact with work item context
/fractary-faber:run customer-analytics --work-id 789

# Run specific phases only
/fractary-faber:run api-refactor --work-id 789 --phase frame,architect

# FABER executes:
# 1. Frame: Fetches issue, classifies
# 2. Architect: Creates design spec
# (Stops after architect - no build/evaluate/release)
```

## Monitoring and Troubleshooting

### Check Workflow Status

```bash
# Show current workflow status
/fractary-faber:status

# Show detailed log history
/fractary-faber:status --logs 20

# Show timing breakdown
/fractary-faber:status --timing
```

### View Session Details

```bash
# Session files are stored in:
.faber/sessions/<work_id>.json

# View session
cat .faber/sessions/abc12345.json | jq .
```

### Common Issues

#### "Configuration file not found"
**Solution**: Run `/fractary-faber:init` or copy a preset

#### "Authentication failed"
**Solution**: Configure platform authentication
- GitHub: `gh auth login`
- R2: `aws configure`

#### "Work item not found"
**Solution**: Verify issue ID and authentication

#### "Evaluate phase failed after 3 retries"
**Solution**: Check test failures in workflow output, review implementation

### Debug Mode

Run with dry-run to see what would happen:

```bash
/fractary-faber:run --work-id 123 --autonomy dry-run
```

## Safety Features

FABER includes multiple safety mechanisms:

### Protected Paths
Prevents modification of critical files:

```json
{
  "safety": {
    "protected_paths": [
      ".git/",
      "node_modules/",
      ".env",
      "*.key",
      "*.pem"
    ]
  }
}
```

### Confirmation Gates
Requires approval before critical operations:

```json
{
  "workflows": [{
    "phases": {
      "release": {
        "require_approval": true
      }
    },
    "autonomy": {
      "pause_before_release": true,
      "require_approval_for": ["release"]
    }
  }]
}
```

### Audit Trail
All workflow steps are logged via fractary-logs plugin with complete history.

### Retry Limits
Prevents infinite loops with configurable retry limits:

```json
{
  "workflows": [{
    "phases": {
      "evaluate": {
        "max_retries": 3
      }
    }
  }]
}
```

## Documentation

- [Configuration Guide](docs/configuration.md) - Detailed configuration reference
- [Prompt Customization](docs/PROMPT-CUSTOMIZATION.md) - Workflow customization guide
- [Workflow Guide](docs/workflow-guide.md) - In-depth workflow documentation
- [Architecture](docs/architecture.md) - System architecture and design
- [Hooks](docs/HOOKS.md) - Phase-level hooks reference
- [State Tracking](docs/STATE-TRACKING.md) - Dual-state system guide
- [Migration Guide](docs/MIGRATION-v2.md) - Upgrade from v1.x to v2.0
- [Error Codes](docs/ERROR-CODES.md) - Complete error reference
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Problem-to-solution guide

## Development

### Project Structure

```
fractary-faber/
├── agents/           # Workflow orchestration
│   ├── faber-director.md     # Command parser & router
│   └── faber-manager.md      # Universal workflow manager
├── skills/           # Phase execution & core utilities
│   ├── frame/        # Frame phase skill
│   ├── architect/    # Architect phase skill
│   ├── build/        # Build phase skill
│   ├── evaluate/     # Evaluate phase skill
│   ├── release/      # Release phase skill
│   └── core/         # Core scripts (validation, audit, state, hooks)
├── commands/         # User commands
│   ├── init.md       # Initialize configuration
│   ├── run.md        # Execute workflow
│   └── audit.md      # Validate configuration
├── config/           # Configuration & schemas
│   ├── config.schema.json    # JSON Schema v7
│   ├── templates/            # Configuration templates
│   │   ├── minimal.json
│   │   ├── standard.json
│   │   └── enterprise.json
│   └── error-codes.json      # Error catalog
├── docs/             # Comprehensive documentation
│   ├── configuration.md
│   ├── PROMPT-CUSTOMIZATION.md
│   ├── workflow-guide.md
│   ├── HOOKS.md
│   ├── STATE-TRACKING.md
│   ├── MIGRATION-v2.md
│   ├── ERROR-CODES.md
│   └── TROUBLESHOOTING.md
└── README.md         # This file
```

### Adding a New Platform Adapter

FABER v2.0 uses companion plugins for platform operations:

- **fractary-work** - Work tracking (GitHub, Jira, Linear)
- **fractary-repo** - Source control (GitHub, GitLab, Bitbucket)
- **fractary-spec** - Specification generation
- **fractary-logs** - Workflow logging

To extend platform support, contribute to the respective plugin. FABER orchestrates via configuration.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

- **Issues**: [GitHub Issues](https://github.com/fractary/claude-plugins/issues)
- **Discussions**: [GitHub Discussions](https://github.com/fractary/claude-plugins/discussions)
- **Documentation**: [docs/](docs/)

## Roadmap

### v2.0 (Current - 2025-11-20)
- ✅ **JSON-based configuration** with JSON Schema validation
- ✅ **Prompt customization** for flexible workflow control
- ✅ **Dual-state tracking** (current + historical logs)
- ✅ **Phase-level hooks** (10 hooks: pre/post for each phase)
- ✅ **Error handling system** (28 categorized error codes)
- ✅ **Validation & audit tools** (scoring, recommendations)
- ✅ **Atomic state management** with file locking
- ✅ Core FABER workflow (Frame → Architect → Build → Evaluate → Release)
- ✅ GitHub integration with work/repo/spec plugins
- ✅ Autonomy levels (dry-run, assist, guarded, autonomous)

### v2.1 (Planned)
- 🚧 Jira integration (fractary-work plugin)
- 🚧 Linear integration (fractary-work plugin)
- 🚧 GitLab support (fractary-repo plugin)
- 🚧 Bitbucket support (fractary-repo plugin)
- 🚧 AWS S3 storage (fractary-file plugin)

### v3.0 (Future)
- 🚧 Multi-domain support (design, writing, data)
- 🚧 Team collaboration features
- 🚧 Workflow templates library
- 🚧 Analytics and reporting
- 🚧 Web UI (optional)

## Credits

FABER is built on the [Claude Code](https://claude.com/claude-code) platform by Anthropic.

---

**Made with ❤️ by Fractary**

*Automate your workflow. Ship faster. Focus on what matters.*
