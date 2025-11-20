# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the **Fractary Claude Code Plugins** repository, containing a collection of interconnected plugins that implement the FABER (Frame → Architect → Build → Evaluate → Release) workflow framework and supporting primitives for AI-assisted development.

## Architecture

### Plugin Ecosystem

The repository is organized around a **modular plugin architecture** with two types of plugins:

1. **Workflow Orchestrators** - Manage complete domain workflows
   - `faber/` - Core FABER workflow orchestration (Frame → Architect → Build → Evaluate → Release)
   - `faber-app/` - Application development FABER workflows
   - `faber-cloud/` - Cloud infrastructure FABER workflows (formerly fractary-devops)

2. **Primitive Managers** - Handle specific infrastructure concerns
   - `work/` - Work item management (GitHub Issues, Jira, Linear)
   - `repo/` - Source control operations (GitHub, GitLab, Bitbucket) + Git worktree management
   - `file/` - File storage operations (R2, S3, local filesystem)
   - `codex/` - Memory and knowledge management across projects

### Three-Layer Architecture Pattern

All plugins follow a consistent **3-layer architecture** for context efficiency:

```
Layer 1: Commands (Entry Points)
   ↓
Layer 2: Agents/Managers (Decision Logic & Workflow Orchestration)
   ↓
Layer 3: Skills (Adapter Selection & Execution)
   ↓
Layer 4: Scripts (Deterministic Operations - executed outside LLM context)
```

**Key Benefit**: This separation reduces context usage by 55-60% by keeping deterministic operations (shell scripts) out of the LLM context.

### Component Responsibilities

- **Commands** (`commands/*.md`): Lightweight entry points that parse arguments and immediately invoke agents. Never do work directly.
- **Agents** (`agents/*.md`): Workflow orchestrators that own complete domain workflows, coordinate skill invocations, and manage state. Never do work directly.
- **Skills** (`skills/*/SKILL.md`): Focused execution units that perform specific tasks by reading workflow steps and executing scripts. Document their work upon completion.
- **Scripts** (`skills/*/scripts/**/*.sh`): Deterministic operations executed via Bash, outside LLM context.

### Plugin Manifest Format

**CRITICAL**: The `.claude-plugin/plugin.json` manifest has a **strict, minimal schema**. Use only these fields:

```json
{
  "name": "fractary-{plugin-name}",
  "version": "1.0.0",
  "description": "Brief description",
  "commands": "./commands/",
  "agents": ["./agents/{agent-name}.md"],
  "skills": "./skills/"
}
```

**Required fields**:
- `name` (string) - Plugin identifier (format: `fractary-{name}`)
- `version` (string) - Semantic version
- `description` (string) - Brief description

**Optional fields**:
- `commands` (string) - Path to commands directory (e.g., `"./commands/"`)
- `agents` (array) - Array of agent file paths (e.g., `["./agents/manager.md"]`)
- `skills` (string) - Path to skills directory (e.g., `"./skills/"`)

**DO NOT USE** these fields in plugin.json (they will cause validation errors):
- ❌ `author` (belongs in marketplace.json only)
- ❌ `license` (belongs in marketplace.json only)
- ❌ `requires` (not part of schema)
- ❌ `hooks` (belongs in marketplace.json only)
- ❌ Array format for `commands` or `skills` (must be strings pointing to directories)

**Reference template**: `docs/templates/plugin.json.template`

**Common mistake**: Using detailed object arrays for commands/skills instead of simple directory paths. The plugin system auto-discovers files in the specified directories.

### Plugin Hooks (Marketplace-Level)

Hooks are registered in `.claude-plugin/marketplace.json`, NOT in the plugin manifest:

```json
{
  "plugins": [{
    "name": "fractary-status",
    "hooks": "./hooks/hooks.json"
  }]
}
```

**Hook Definition** (`plugins/{plugin}/hooks/hooks.json`):
```json
{
  "description": "Plugin hooks description",
  "hooks": {
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/script-name.sh"
      }]
    }]
  }
}
```

**Key Features**:
- `${CLAUDE_PLUGIN_ROOT}` - Variable that resolves to plugin root directory (works in hooks array)
- Scripts stay in plugin, no per-project copying needed
- Plugin updates automatically propagate to all projects
- Hooks auto-activate when plugin installed

**Variable Expansion Behavior**:
- ✅ **Hooks array**: `${CLAUDE_PLUGIN_ROOT}` is supported and expands at runtime
- ❌ **statusLine property**: `${CLAUDE_PLUGIN_ROOT}` NOT supported in hooks.json
- ℹ️ **statusLine configuration**: Must be set in project's `.claude/settings.json` using absolute path

**StatusLine Configuration** (in project's `.claude/settings.json`, NOT in hooks.json):
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/plugins/marketplaces/{marketplace}/plugins/{plugin}/scripts/status-line.sh"
  }
}
```

Note: The install script for status-related plugins should write this configuration to the project's settings.json.

**Examples**: See `plugins/repo/hooks/hooks.json` and `plugins/status/hooks/hooks.json`

## Directory Structure

```
plugins/
├── faber/              # Core FABER workflow orchestration
│   ├── agents/         # Workflow orchestration (faber-director, faber-manager)
│   ├── skills/         # Phase skills (frame, architect, build, evaluate, release) + core utilities
│   ├── commands/       # User commands (/faber, /faber:init, /faber:run, /faber:status)
│   ├── presets/        # Quick-start configuration presets
│   └── config/         # Configuration templates
├── faber-app/          # Application development workflows
├── faber-cloud/        # Cloud infrastructure workflows (AWS, Terraform)
├── work/               # Work tracking primitive (GitHub, Jira, Linear)
│   ├── agents/         # work-manager agent
│   ├── skills/         # Platform-specific scripts (github/, jira/, linear/)
│   └── hooks/          # Plugin-level hooks (auto-comment, etc.)
├── repo/               # Source control primitive (GitHub, GitLab, Bitbucket) + worktrees
│   ├── agents/         # repo-manager agent
│   ├── skills/         # Platform-specific scripts (github/, gitlab/) + worktree-manager
│   ├── scripts/        # Plugin-level scripts (auto-commit, status-cache)
│   └── hooks/          # Plugin-level hooks (SessionStart, Stop, UserPromptSubmit)
├── status/             # Custom status line display
│   ├── skills/         # Status line manager
│   ├── scripts/        # Plugin-level scripts (status-line.sh, capture-prompt.sh)
│   ├── hooks/          # Plugin-level hooks (UserPromptSubmit, statusLine)
│   └── commands/       # Installation command
├── file/               # File storage primitive (R2, S3, local)
│   ├── agents/         # file-manager agent
│   └── skills/         # Storage-specific scripts (r2/, s3/)
└── codex/              # Memory and knowledge management
    ├── agents/         # sync-manager agent
    └── skills/         # Sync and memory operations

docs/
├── standards/          # Plugin development standards
├── specs/              # Technical specifications
└── conversations/      # Architecture discussions
```

## Working with Plugins

### Configuration Files

Plugin configurations are stored in project directories and **SHOULD be committed to version control**:

- **FABER**: `.faber.config.toml` in project root
- **Plugins**: `.fractary/plugins/{plugin}/config.json`

All configurations use environment variables for secrets (never hardcoded), making them safe to commit.

**Important**: See [Version Control Guide](docs/VERSION-CONTROL-GUIDE.md) for best practices.

Use presets as starting points:
```bash
cp plugins/faber/presets/software-guarded.toml .faber.config.toml
```

### Testing Workflows

To test a FABER workflow:
```bash
# Initialize configuration
/faber init

# Dry-run mode (no actual changes)
/faber run 123 --autonomy dry-run

# Assisted mode (stops before release)
/faber run 123 --autonomy assist

# Guarded mode (pauses at release for approval) - RECOMMENDED
/faber run 123 --autonomy guarded

# Check status
/faber status
```

### How to Invoke Agents

Agents are invoked using **declarative natural language**, not tool calls.

**Correct invocation**:
```
Use the @agent-fractary-repo:repo-manager agent to create a commit with the following request:
{
  "operation": "create-commit",
  "parameters": {
    "message": "Add CSV export",
    "type": "feat",
    "work_id": "123"
  }
}
```

**Incorrect invocation**:
- ❌ Skill tool with agent name
- ❌ Task tool with agent name
- ❌ Direct skill invocation (bypassing agent)

The plugin system automatically routes when you state you're using an agent. Simply declare that you're using the agent in natural language, and the system handles the rest.

**Agent types**:
- **@agent-fractary-repo:repo-manager** - Repository operations (commits, branches, PRs, tags)
- **@agent-fractary-work:work-manager** - Work item management (issues, labels, milestones)
- **@agent-fractary-file:file-manager** - File storage operations (R2, S3, local)

### Command Failure Protocol

When commands or skills fail:

1. **STOP immediately** - Do not attempt workarounds
2. **Report the failure** - Show the error to the user
3. **Wait for instruction** - User decides next steps
4. **NEVER bypass** - Do not use bash/git/gh CLI directly as fallback

**Examples:**
- ❌ Command fails → use git CLI directly
- ❌ Skill fails → invoke different skill
- ✅ Command fails → report error, wait for user

This ensures architectural boundaries are respected and users maintain control over how failures are handled.

### Provider Abstraction (Handler Pattern)

Multi-provider plugins use **handler skills** to centralize provider-specific logic:

```
skills/
├── core-skill/              # Invokes handler based on config
└── handler-type-provider/   # Provider-specific implementation
    ├── workflow/            # Operation-specific instructions
    └── scripts/             # Provider-specific scripts
```

Example from `faber-cloud`:
- `skills/infra-deployer/` - Core deployment logic
- `skills/handler-iac-terraform/` - Terraform-specific operations
- `skills/handler-hosting-aws/` - AWS-specific operations

Configuration determines which handler is active:
```json
{
  "handlers": {
    "iac": {"active": "terraform"},
    "hosting": {"active": "aws"}
  }
}
```

## Development Standards

### XML Markup Standards

All agent and skill files use **UPPERCASE XML tags** for structure:

```markdown
<CONTEXT>Who you are, what you do</CONTEXT>
<CRITICAL_RULES>Must-never-violate rules</CRITICAL_RULES>
<INPUTS>What you receive</INPUTS>
<WORKFLOW>Steps to execute</WORKFLOW>
<COMPLETION_CRITERIA>How to know you're done</COMPLETION_CRITERIA>
<OUTPUTS>What you return</OUTPUTS>
<HANDLERS>Handler skills to use (if applicable)</HANDLERS>
<DOCUMENTATION>How to document work</DOCUMENTATION>
<ERROR_HANDLING>How to handle errors</ERROR_HANDLING>
```

### Skills Must Output Start/End Messages

Skills output structured messages for visibility:

```markdown
🎯 STARTING: [Skill Name]
[Key parameters]
───────────────────────────────────────

[... execution ...]

✅ COMPLETED: [Skill Name]
[Key results summary]
[Artifacts created with paths]
───────────────────────────────────────
Next: [What to do next]
```

### Critical Design Principles

1. **Commands never do work** - Always immediately invoke an agent
2. **Agents never do work** - Always delegate to skills
3. **Skills read workflow files** - Multi-step workflows split into `workflow/*.md` files
4. **Scripts are deterministic** - All shell scripts should be idempotent and well-documented
5. **Documentation is atomic** - Skills document their own work as the final step
6. **Defense in depth** - Critical rules (e.g., production safety) are enforced at multiple levels

## Key Files to Reference

### Standards & Architecture
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md` - **Read this first** for plugin development patterns
- `specs/SPEC-00002-faber-architecture.md` - FABER framework specification
- `docs/conversations/2025-10-22-cli-tool-reorganization-faber-details.md` - Tool philosophy and vision

### Example Implementations
- `plugins/faber-cloud/` - Complete reference implementation with all patterns
- `plugins/faber-cloud/docs/specs/` - Comprehensive DevOps plugin documentation
- `plugins/faber/` - Core FABER workflow implementation

### Configuration Examples
- `plugins/faber/config/faber.example.toml` - Complete FABER configuration
- `plugins/faber/presets/*.toml` - Quick-start presets for different autonomy levels

## Common Development Tasks

### Working with Git Worktrees

Git worktrees enable parallel development on multiple branches simultaneously. The repo plugin provides seamless worktree management.

**Create branch with worktree:**
```bash
# Single command creates both branch and worktree
/repo:branch-create "implement auth" --work-id 123 --worktree

# Result:
# - Branch: feat/123-implement-auth (created)
# - Worktree: ../repo-wt-feat-123-implement-auth (created)
# - Ready for parallel Claude Code instance
```

**Naming Convention:**
- Pattern: `{repo-name}-wt-{branch-slug}`
- Location: Sibling directory to main repository
- Example: `claude-plugins-wt-feat-92-add-git-worktree-support`

**List active worktrees:**
```bash
/repo:worktree-list

# Output:
# 1. feat/123-implement-auth
#    Path: ../repo-wt-feat-123-implement-auth
#    Work Item: #123
#    Created: 2025-11-12
#    Status: Active
```

**Remove specific worktree:**
```bash
/repo:worktree-remove feat/123-implement-auth

# Safety checks:
# - Warns if uncommitted changes exist
# - Requires --force to override
# - Prevents removal from within worktree directory
```

**Cleanup merged/stale worktrees:**
```bash
# Clean up merged branches
/repo:worktree-cleanup --merged

# Clean up stale worktrees (30+ days inactive)
/repo:worktree-cleanup --stale --days 30

# Dry run to preview
/repo:worktree-cleanup --merged --stale --dry-run
```

**Automatic cleanup on PR merge:**
```bash
# Explicit cleanup
/repo:pr-merge 123 --worktree-cleanup

# Without flag - prompts if worktree exists:
/repo:pr-merge 123
# Displays:
#   🧹 Worktree Cleanup Reminder
#   Would you like to clean up this worktree?
#   1. Yes, remove it now
#   2. No, keep it for now
#   3. Show me the cleanup command
```

**Parallel development workflow:**
```bash
# Terminal 1: Work on feature A
/repo:branch-create "feature A" --work-id 100 --worktree
cd ../repo-wt-feat-100-feature-a
claude

# Terminal 2: Work on feature B (simultaneously)
/repo:branch-create "feature B" --work-id 101 --worktree
cd ../repo-wt-feat-101-feature-b
claude

# Both Claude instances work independently in separate worktrees
```

**Best Practices:**
- Use `--worktree` flag for parallel work on multiple features
- Clean up worktrees after PR merge to free disk space
- Use `/repo:worktree-cleanup --merged` regularly to prevent accumulation
- Worktree metadata tracked in `.fractary/plugins/repo/worktrees.json`

### Adding a New Platform Adapter

To add support for a new platform (e.g., GitLab to repo plugin):

1. Create platform scripts:
   ```bash
   mkdir -p plugins/repo/skills/repo-manager/scripts/gitlab/
   ```

2. Implement required operations (matching existing platforms):
   ```bash
   # Study existing platform first
   ls plugins/repo/skills/repo-manager/scripts/github/

   # Implement equivalent scripts
   touch plugins/repo/skills/repo-manager/scripts/gitlab/create-branch.sh
   touch plugins/repo/skills/repo-manager/scripts/gitlab/create-pr.sh
   # ... etc
   ```

3. Update skill documentation:
   ```bash
   vim plugins/repo/skills/repo-manager/SKILL.md
   # Add GitLab-specific handler section
   ```

4. No agent changes needed! The 3-layer architecture isolates platform logic.

### Creating a New Plugin

Follow the plugin standards document (`docs/standards/FRACTARY-PLUGIN-STANDARDS.md`) and reference the DevOps plugin (`plugins/faber-cloud/`) as the canonical example.

Key steps:
1. Define manager agents (one per complete workflow)
2. Define skill units (one per focused task)
3. Determine if multi-provider (need handlers?)
4. Create configuration structure
5. Implement 3-layer architecture
6. Add XML markup to all agents/skills
7. Document with start/end messages

### Understanding the FABER Workflow

The FABER workflow is a universal creation lifecycle:

1. **Frame** - Fetch work item, classify, setup environment
2. **Architect** - Design solution, create specification
3. **Build** - Implement from spec
4. **Evaluate** - Test and review (with retry loop)
5. **Release** - Create PR, deploy, document

This pattern applies to:
- Software engineering (implemented in `faber/`)
- Infrastructure (implemented in `faber-cloud/`)
- Design, writing, data (planned)

### FABER v2.0 Architecture (Current)

FABER v2.0 uses a **universal workflow-manager architecture** with configuration-driven behavior.

**Architecture**:
```
faber-director (lightweight command parser)
  └─ faber-manager (universal orchestrator)
      ├─ frame (phase skill)
      ├─ architect (phase skill)
      ├─ build (phase skill)
      ├─ evaluate (phase skill)
      └─ release (phase skill)
```

**Key Features**:
- **Universal Manager** - Single faber-manager works across ALL projects via configuration
- **JSON Configuration** - Located at `.fractary/plugins/faber/config.json`
- **Dual-State Tracking** - Current state (state.json) + historical logs (fractary-logs)
- **Phase-Level Hooks** - 10 hooks total (pre/post for each of 5 phases)
- **60% context reduction** - From ~98K to ~40K tokens for orchestration

**Configuration Location** (v2.0):
```
.fractary/plugins/faber/config.json  # JSON format (NEW)
```

**Old Location** (v1.x - NO LONGER USED):
```
.faber.config.toml  # TOML format (DEPRECATED)
```

**Configuration Structure**:
```json
{
  "schema_version": "2.0",
  "workflows": [
    {
      "id": "default",
      "description": "Standard FABER workflow (Issue → Branch → Spec)",
      "phases": {
        "frame": { "enabled": true, "steps": [...], "validation": [...] },
        "architect": { "enabled": true, "steps": [...], "validation": [...] },
        "build": { "enabled": true, "steps": [...], "validation": [...] },
        "evaluate": { "enabled": true, "steps": [...], "validation": [...] },
        "release": { "enabled": true, "steps": [...], "validation": [...] }
      },
      "hooks": {
        "pre_frame": [], "post_frame": [],
        "pre_architect": [], "post_architect": [],
        "pre_build": [], "post_build": [],
        "pre_evaluate": [], "post_evaluate": [],
        "pre_release": [], "post_release": []
      },
      "autonomy": {
        "level": "guarded",
        "pause_before_release": true,
        "require_approval_for": ["release"]
      }
    }
  ],
  "integrations": {
    "work_plugin": "fractary-work",
    "repo_plugin": "fractary-repo",
    "spec_plugin": "fractary-spec",
    "logs_plugin": "fractary-logs"
  },
  "logging": {
    "use_logs_plugin": true,
    "log_type": "workflow"
  },
  "safety": {
    "protected_paths": [],
    "require_confirm_for": []
  }
}
```

**Dual-State Tracking**:
- **Current State**: `.fractary/plugins/faber/state.json` (for workflow resume/retry)
- **Historical Logs**: `fractary-logs` plugin with workflow log type (complete audit trail)

**Initialization**:
```bash
# Generate default FABER configuration
/fractary-faber:init

# Creates .fractary/plugins/faber/config.json with baseline workflow
```

**Validation**:
```bash
# Validate configuration
/fractary-faber:audit

# Check completeness score and get suggestions
/fractary-faber:audit --verbose
```

**Documentation**:
- `plugins/faber/docs/CONFIGURATION.md` - Complete configuration guide
- `plugins/faber/docs/HOOKS.md` - Phase-level hooks guide
- `plugins/faber/docs/STATE-TRACKING.md` - Dual-state tracking guide
- `plugins/faber/docs/MIGRATION-v2.md` - Migration from v1.x

**Migration**: See `plugins/faber/docs/MIGRATION-v2.md` for upgrading from v1.x

## Tool Philosophy

The Fractary ecosystem addresses fundamental challenges in agentic AI development:

- **Forge** (future) - Maker's workbench for authoring primitives and bundles
- **Caster** (future) - Distribution and packaging to registries
- **Codex** - Memory fabric solving the agent memory problem
- **FABER** - Universal maker workflow orchestration
- **Helm** (future) - Runtime monitoring, evaluation, and governance

Current focus: FABER workflow + primitive managers (work, repo, file, codex)

## Important Notes

- **Context Efficiency**: The 3-layer architecture is designed to minimize token usage. Keep deterministic operations in scripts, not in agent/skill prompts.
- **Provider Agnostic**: Plugins work with multiple platforms via handler abstraction. Never hardcode platform-specific logic in agents.
- **Safety First**: Production operations require explicit confirmation. Multiple layers enforce critical safety rules.
- **Configuration-Driven**: Behavior is determined by configuration files, not code changes.
