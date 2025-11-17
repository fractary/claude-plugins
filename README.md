# Fractary Claude Code Plugins

A collection of interconnected plugins that implement the FABER (Frame → Architect → Build → Evaluate → Release) workflow framework and supporting primitives for AI-assisted development with Claude Code.

## Quick Start

### Automatic Installation (Recommended)

When you clone this repository and trust the folder in Claude Code, the Fractary marketplace is **automatically installed** via the `extraKnownMarketplaces` configuration in `.claude/settings.json`. No manual steps required!

Additionally, the `fractary-repo` plugin provides a SessionStart hook that keeps the marketplace up-to-date in all projects. This means any project using the repo plugin automatically gets marketplace updates.

### Manual Installation

If you need to install manually:

```bash
# Add the Fractary marketplace
/plugin marketplace add fractary/claude-plugins

# Install specific plugins (or enable in .claude/settings.json)
/plugin install fractary-faber@fractary
/plugin install fractary-work@fractary
/plugin install fractary-repo@fractary
```

## Plugin Ecosystem

### Workflow Orchestrators

- **faber/** - Core FABER workflow orchestration (Frame → Architect → Build → Evaluate → Release)
- **faber-app/** - Application development FABER workflows
- **faber-cloud/** - Cloud infrastructure FABER workflows (AWS, Terraform)

### Primitive Managers

- **work/** - Work item management (GitHub Issues, Jira, Linear)
- **repo/** - Source control operations (GitHub, GitLab, Bitbucket)
- **file/** - File storage operations (R2, S3, local filesystem)
- **codex/** - Memory and knowledge management across projects
- **docs/** - Living documentation management
- **logs/** - Operational log management
- **spec/** - Specification generation from issues

## Architecture

All plugins follow a consistent **3-layer architecture**:

```
Commands (Entry Points)
   ↓
Agents/Managers (Workflow Orchestration)
   ↓
Skills (Execution Units)
   ↓
Scripts (Deterministic Operations)
```

This separation reduces context usage by 55-60% by keeping deterministic operations outside LLM context.

## Using FABER Workflows

### Initialize Configuration

```bash
# Copy a preset to get started
cp plugins/faber/presets/software-guarded.toml .faber.config.toml

# Or run interactive setup
/faber init
```

### Run a Workflow

```bash
# Dry-run mode (no actual changes)
/faber run 123 --autonomy dry-run

# Assisted mode (stops before release)
/faber run 123 --autonomy assist

# Guarded mode (pauses at release) - RECOMMENDED
/faber run 123 --autonomy guarded

# Check status
/faber status
```

## Using Primitive Managers

### Work Management

```bash
# Create an issue
/work:issue-create "Add CSV export" --type feature

# List issues
/work:issue-list --state open

# Add labels
/work:label-add 123 urgent
```

### Repository Operations

```bash
# Create a branch
/repo:branch-create "add csv export" --work-id 123

# Create a commit
/repo:commit "Add export feature" --type feat --work-id 123

# Create a PR
/repo:pr-create "Add CSV Export" --work-id 123
```

### File Storage

```bash
# Upload to R2/S3
/file:upload ./report.pdf --provider r2

# Download from storage
/file:download report.pdf --provider r2
```

## Configuration

Plugin configurations are stored in project directories and **should be committed to version control**:

- **FABER**: `.faber.config.toml` in project root
- **Plugins**: `.fractary/plugins/{plugin}/config.json`

All configurations use environment variables for secrets (never hardcoded), making them safe to commit.

See [Version Control Guide](docs/VERSION-CONTROL-GUIDE.md) for best practices.

## Documentation

### Getting Started

- [Plugin Standards](docs/standards/FRACTARY-PLUGIN-STANDARDS.md) - Development patterns and guidelines
- [FABER Architecture](specs/SPEC-00002-faber-architecture.md) - Workflow framework specification
- [Version Control Guide](docs/VERSION-CONTROL-GUIDE.md) - Configuration best practices

### Plugin Documentation

- [FABER Plugin](plugins/faber/README.md) - Core workflow orchestration
- [Work Plugin](plugins/work/README.md) - Work item management
- [Repo Plugin](plugins/repo/README.md) - Source control operations
- [File Plugin](plugins/file/README.md) - File storage operations
- [Codex Plugin](plugins/codex/README.md) - Memory and knowledge management

## Development

### Adding a New Platform Adapter

To add support for a new platform (e.g., GitLab to repo plugin):

1. Create platform scripts in `plugins/{plugin}/skills/{skill}/scripts/{platform}/`
2. Implement required operations (match existing platforms)
3. Update skill documentation
4. Test with the new platform

No agent changes needed! The 3-layer architecture isolates platform logic.

### Creating a New Plugin

Follow these steps:

1. Read [Plugin Standards](docs/standards/FRACTARY-PLUGIN-STANDARDS.md)
2. Reference [faber-cloud](plugins/faber-cloud/) as canonical example
3. Define manager agents (workflow orchestration)
4. Define skills (execution units)
5. Implement scripts (deterministic operations)
6. Add XML markup and documentation

## Key Design Principles

1. **Commands never do work** - Always immediately invoke an agent
2. **Agents never do work** - Always delegate to skills
3. **Skills read workflow files** - Multi-step workflows in `workflow/*.md`
4. **Scripts are deterministic** - Idempotent and well-documented
5. **Documentation is atomic** - Skills document their own work
6. **Defense in depth** - Critical rules enforced at multiple levels

## Command Failure Protocol

When commands or skills fail:

1. **STOP immediately** - Do not attempt workarounds
2. **Report the failure** - Show error to user
3. **Wait for instruction** - User decides next steps
4. **NEVER bypass** - Do not use bash/git/gh CLI directly

This ensures architectural boundaries are respected and users maintain control.

## Contributing

See [CLAUDE.md](CLAUDE.md) for detailed guidance on:
- Repository structure
- Development workflows
- Testing procedures
- Documentation requirements

## Tool Philosophy

The Fractary ecosystem addresses fundamental challenges in agentic AI development:

- **Codex** - Memory fabric solving the agent memory problem
- **FABER** - Universal maker workflow orchestration
- **Primitives** - Focused managers for work, repo, file, storage

Future tools: Forge (authoring), Caster (distribution), Helm (monitoring)

## License

MIT License - See [LICENSE](LICENSE) for details

## Support

- [Documentation](docs/)
- [Issue Tracker](https://github.com/fractary/claude-plugins/issues)
- [Discussions](https://github.com/fractary/claude-plugins/discussions)
