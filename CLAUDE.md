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
   - `repo/` - Source control operations (GitHub, GitLab, Bitbucket)
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

### Plugin Dependencies

Plugins declare dependencies in `.claude-plugin/plugin.json`:

```json
{
  "name": "fractary-faber",
  "requires": ["fractary-work", "fractary-repo", "fractary-file"]
}
```

The `faber` plugin orchestrates workflows using the primitive manager plugins (work, repo, file).

## Directory Structure

```
plugins/
├── faber/              # Core FABER workflow orchestration
│   ├── agents/         # Workflow orchestration (director, workflow-manager)
│   ├── skills/         # Phase skills (frame, architect, build, evaluate, release) + core utilities
│   ├── commands/       # User commands (/faber, /faber:init, /faber:run, /faber:status)
│   ├── presets/        # Quick-start configuration presets
│   └── config/         # Configuration templates
├── faber-app/          # Application development workflows
├── faber-cloud/        # Cloud infrastructure workflows (AWS, Terraform)
├── work/               # Work tracking primitive (GitHub, Jira, Linear)
│   ├── agents/         # work-manager agent
│   └── skills/         # Platform-specific scripts (github/, jira/, linear/)
├── repo/               # Source control primitive (GitHub, GitLab, Bitbucket)
│   ├── agents/         # repo-manager agent
│   └── skills/         # Platform-specific scripts (github/, gitlab/)
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

Plugin configurations are stored in project directories (not committed to git):

- **FABER**: `.faber.config.toml` in project root
- **DevOps**: `.fractary/plugins/devops/config/devops.json`

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
- `docs/specs/SPEC-0002-faber-architecture.md` - FABER framework specification
- `docs/conversations/2025-10-22-cli-tool-reorganization-faber-details.md` - Tool philosophy and vision

### Example Implementations
- `plugins/faber-cloud/` - Complete reference implementation with all patterns
- `plugins/faber-cloud/docs/specs/` - Comprehensive DevOps plugin documentation
- `plugins/faber/` - Core FABER workflow implementation

### Configuration Examples
- `plugins/faber/config/faber.example.toml` - Complete FABER configuration
- `plugins/faber/presets/*.toml` - Quick-start presets for different autonomy levels

## Common Development Tasks

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

FABER v2.0 uses a **single workflow-manager architecture** for improved context efficiency:

**Architecture**:
```
director.md (lightweight router)
  └─ workflow-manager.md (orchestrates all 5 phases)
      ├─ frame (skill with workflow/basic.md)
      ├─ architect (skill with workflow/basic.md)
      ├─ build (skill with workflow/basic.md)
      ├─ evaluate (skill with workflow/basic.md)
      └─ release (skill with workflow/basic.md)
```

**Key improvements**:
- **60% context reduction** (from ~98K to ~40K tokens for orchestration)
- **Continuous context** across all phases
- **Skill overrides** via configuration (`[workflow.skills]`)
- **Domain customization** through `workflow/{domain}.md` files

**Configuration example**:
```toml
[workflow.skills]
frame = "basic"        # Use FABER default
architect = "cloud"    # Use cloud-specific override
build = "cloud"        # Use cloud-specific override
evaluate = "cloud"     # Use cloud-specific override
release = "basic"      # Use FABER default
```

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
