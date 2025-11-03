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
/faber:init
```

This auto-detects your project settings and creates `.faber.config.toml`.

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
/faber:run 123
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

### Quick Setup with Presets

Choose a preset based on your needs:

```bash
# Conservative (pauses before release)
cp plugins/fractary-faber/presets/software-basic.toml .faber.config.toml

# Balanced (recommended - pauses at release)
cp plugins/fractary-faber/presets/software-guarded.toml .faber.config.toml

# Fully automated (⚠️ use with caution)
cp plugins/fractary-faber/presets/software-autonomous.toml .faber.config.toml
```

Then edit placeholders (marked with `<...>`) in `.faber.config.toml`.

### Auto-detection

Let FABER detect your project settings:

```bash
/faber:init
```

This creates `.faber.config.toml` with auto-detected values for:
- Project name and repository
- Issue tracking system (GitHub, Jira, Linear)
- Source control system (GitHub, GitLab, Bitbucket)
- File storage preferences (R2, S3, local)
- Domain (engineering, design, writing, data)

### Manual Configuration

See [`config/faber.example.toml`](config/faber.example.toml) for all available options.

## Usage

### GitHub Integration (NEW in v1.1.0)

**Trigger FABER directly from GitHub issues** using `@faber` mentions:

```
@faber run this issue        # Execute full workflow
@faber just design this      # Design only, no implementation
@faber test this             # Run tests only
@faber status                # Check workflow status
@faber approve               # Approve release (guarded mode)
```

**Setup** (one-time):
1. Add `.github/workflows/faber.yml` to your repository
2. Add `CLAUDE_CODE_OAUTH_TOKEN` secret
3. Create `.faber.config.toml` in repository root
4. Mention `@faber` in any issue!

Status updates post automatically to GitHub issues. See [GitHub Integration Guide](docs/github-integration.md) for complete setup instructions and examples.

### CLI Commands

```bash
# Initialize FABER in a project
/faber:init

# Run workflow for an issue
/faber:run 123

# Check workflow status
/faber:status

# Get help
/faber help
```

### Advanced Usage

```bash
# Override domain
/faber:run 123 --domain design

# Override autonomy level
/faber:run 123 --autonomy autonomous

# Enable auto-merge
/faber:run 123 --auto-merge

# Dry-run (simulation only)
/faber:run 123 --autonomy dry-run

# Check specific workflow
/faber:status abc12345

# Show failed workflows
/faber:status --failed
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

Set default in `.faber.config.toml`:

```toml
[defaults]
autonomy = "guarded"
```

Override per workflow:

```bash
/faber:run 123 --autonomy autonomous
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
- `/faber` - Main entry point with intelligent routing
- `/faber:init` - Initialize FABER in a project
- `/faber:run` - Execute workflow
- `/faber:status` - Show workflow status

## Domain Support

FABER supports multiple work domains:

### Engineering ✅ (Implemented)
- Software development workflows
- Code implementation and testing
- Pull requests and code review

**Usage**: `/faber:run 123 --domain engineering`

### Design 🚧 (Future)
- Design brief generation
- Asset creation
- Design review and publication

**Usage**: `/faber:run 123 --domain design`

### Writing 🚧 (Future)
- Content outlines
- Writing and editing
- Content review and publication

**Usage**: `/faber:run 123 --domain writing`

### Data 🚧 (Future)
- Pipeline design and implementation
- Data quality checks
- Pipeline deployment

**Usage**: `/faber:run 123 --domain data`

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
/faber:init

# Run workflow for GitHub issue #123
/faber:run 123

# FABER executes:
# 1. Frame: Fetches issue, creates branch
# 2. Architect: Generates specification
# 3. Build: Implements solution
# 4. Evaluate: Runs tests (retries if needed)
# 5. Release: Creates PR, waits for approval

# Check status
/faber:status abc12345

# Approve and merge (manual)
# - Review PR
# - Merge via GitHub UI
```

### Example 2: Autonomous Workflow

```bash
# Run with full automation
/faber:run 456 --autonomy autonomous --auto-merge

# FABER executes all phases and merges PR automatically
# ⚠️ Use only for non-critical changes!
```

### Example 3: Design Workflow (Future)

```bash
# Design workflow for Jira ticket
/faber:run PROJ-789 --domain design

# FABER executes:
# 1. Frame: Fetches design brief
# 2. Architect: Creates design spec
# 3. Build: Generates design assets
# 4. Evaluate: Design review
# 5. Release: Publishes assets
```

## Monitoring and Troubleshooting

### Check Workflow Status

```bash
# Show all active workflows
/faber:status

# Show specific workflow
/faber:status abc12345

# Show failed workflows
/faber:status --failed

# Show workflows waiting for approval
/faber:status --waiting
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
**Solution**: Run `/faber:init` or copy a preset

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
/faber:run 123 --autonomy dry-run
```

## Safety Features

FABER includes multiple safety mechanisms:

### Protected Paths
Prevents modification of critical files:

```toml
[safety]
protected_paths = [
    ".git/",
    "node_modules/",
    ".env",
    "*.key",
    "*.pem"
]
```

### Confirmation Gates
Requires approval before critical operations:

```toml
[safety]
require_confirmation = [
    "release"  # Pause before creating PR
]
```

### Audit Trail
All workflow steps are logged in session files.

### Retry Limits
Prevents infinite loops with configurable retry limits:

```toml
[workflow]
max_evaluate_retries = 3
```

## Documentation

- [Configuration Guide](docs/configuration.md) - Detailed configuration reference
- [Workflow Guide](docs/workflow-guide.md) - In-depth workflow documentation
- [Architecture](docs/architecture.md) - System architecture and design
- [Presets](presets/README.md) - Pre-configured workflow presets
- [Configuration Example](config/faber.example.toml) - Full configuration example

## Development

### Project Structure

```
fractary-faber/
├── agents/           # Decision-making agents
│   ├── director.md
│   ├── frame-manager.md
│   ├── architect-manager.md
│   ├── build-manager.md
│   ├── evaluate-manager.md
│   ├── release-manager.md
│   ├── work-manager.md
│   ├── repo-manager.md
│   └── file-manager.md
├── skills/           # Platform adapters
│   ├── core/   # Core utilities
│   ├── work-manager/ # Work tracking adapters
│   ├── repo-manager/ # Source control adapters
│   └── file-manager/ # File storage adapters
├── commands/         # User commands
│   ├── faber.md      # Main entry point
│   ├── init.md
│   ├── run.md
│   └── status.md
├── config/           # Configuration templates
│   └── faber.example.toml
├── presets/          # Quick-start presets
│   ├── software-basic.toml
│   ├── software-guarded.toml
│   └── software-autonomous.toml
├── docs/             # Documentation
└── README.md         # This file
```

### Adding a New Platform Adapter

To add support for a new platform (e.g., GitLab):

1. **Create adapter scripts** in `skills/<manager>/scripts/<platform>/`
2. **Update skill documentation** in `skills/<manager>/SKILL.md`
3. **Add platform configuration** to `config/faber.example.toml`
4. **Test thoroughly** with real workflows

Example: Adding GitLab support to repo-manager:

```bash
# Create scripts
mkdir -p skills/repo-manager/scripts/gitlab/
# Implement: generate-branch-name.sh, create-branch.sh, etc.

# Update skill
vim skills/repo-manager/SKILL.md

# Add config
vim config/faber.example.toml
```

No agent changes required! The 3-layer architecture isolates platform-specific logic.

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

### v1.1.0 (Current - 2025-10-31)
- ✅ Core FABER workflow
- ✅ **GitHub `@faber` mention integration**
- ✅ **Intent parsing** (full workflow, single phase, status, control)
- ✅ **Status card posting** to GitHub issues
- ✅ Cloudflare R2 storage
- ✅ Engineering domain
- ✅ Configuration presets
- ✅ Autonomy levels (dry-run, assist, guarded, autonomous)

### v1.2 (Planned)
- 🚧 Jira integration
- 🚧 Linear integration
- 🚧 AWS S3 storage
- 🚧 GitLab mention integration

### v2.0 (Future)
- 🚧 Design domain
- 🚧 Writing domain
- 🚧 Data domain
- 🚧 GitLab/Bitbucket support
- 🚧 Team collaboration features

## Credits

FABER is built on the [Claude Code](https://claude.com/claude-code) platform by Anthropic.

---

**Made with ❤️ by Fractary**

*Automate your workflow. Ship faster. Focus on what matters.*
