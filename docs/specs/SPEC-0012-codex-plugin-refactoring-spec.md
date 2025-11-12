# Codex Plugin Refactoring Specification

**Version:** 2.0.0
**Status:** Planning
**Created:** 2025-11-04
**Purpose:** Transform codex plugin from OmniDAS-specific implementation to Fractary-standard plugin for documentation/knowledge sync across organization projects

---

## Table of Contents

1. [Overview](#overview)
2. [Current State Analysis](#current-state-analysis)
3. [Architecture Decisions](#architecture-decisions)
4. [Refactoring Tasks](#refactoring-tasks)
5. [File Inventory](#file-inventory)
6. [Implementation Plan](#implementation-plan)
7. [Success Criteria](#success-criteria)

---

## Overview

### Purpose

The codex plugin provides tooling for improving memory and context management for AI agents by synchronizing documentation between GitHub projects in an organization. There is often common standards, guides, and documentation that every project needs to reference for Claude to do its job effectively. Furthermore, different projects/systems often interact and must know the interfaces for integration, making shared documentation critical.

### Key Use Cases

1. **Project Sync**: Sync documentation for the current project with codex core
2. **Organization Sync**: Sync all projects in an organization
3. **Bidirectional Sync**: Pull shared docs from codex, push project-specific docs to codex
4. **Configuration**: Initialize codex settings for organization and repository

### Central Repository Pattern

The plugin syncs with a central "codex core" repository that follows the naming pattern:
- `codex.{organization}.{tld}` (e.g., `codex.fractary.com`, `codex.fractary.ai`)
- TLD varies by organization (com, ai, io, etc.)

---

## Current State Analysis

### Existing Components

**Directory Structure:**
```
plugins/codex/
├── .claude-plugin/
│   └── plugin.json
├── .github/workflows/          # GitHub-specific sync workflows
│   ├── sync-codex-claude-to-projects.yml
│   ├── sync-codex-docs-to-projects.yml
│   └── sync-project-docs-to-codex.yml
├── agents/
│   └── sync-manager.md         # OmniDAS-specific agent
├── commands/
│   └── sync-project.md         # Basic command router
├── skills/
│   ├── codex-sync-manager.md   # Documentation (not proper SKILL.md)
│   └── sync-manager/
│       ├── guide.md
│       └── scripts/
│           └── repo-discover.sh
└── README.md                    # OmniDAS-branded
```

### Issues with Current Implementation

1. **OmniDAS-Specific**
   - Hardcoded references to omnidas organization
   - Branding specific to OmniDAS project
   - Not organization-agnostic

2. **Architecture Non-Compliance**
   - Missing proper XML markup in agent/skills
   - Not following 3-layer architecture (command → manager → skill)
   - GitHub workflows instead of portable scripts
   - No proper skill structure with SKILL.md files

3. **Limited Functionality**
   - Only GitHub workflow-based (requires GitHub Actions)
   - No local execution capability
   - Missing init command for configuration
   - No organization-wide sync command

4. **Configuration Issues**
   - No Fractary configuration pattern
   - Hardcoded values in workflows
   - No global/project config split

---

## Architecture Decisions

### Dependencies

**Primary Dependency**: `fractary-repo`
- Use repo plugin for all git/source control operations
- Leverage existing GitHub/GitLab/Bitbucket support
- No need to reimplement git operations

**Hybrid Handler Approach**:
- Use repo plugin for git operations (commits, clones, pushes)
- Have own handlers for sync mechanisms:
  - `handler-sync-github` - Current: script-based sync (converted from workflows)
  - `handler-sync-vector` - Future: vector store sync
  - `handler-sync-mcp` - Future: MCP server integration

### Skills Architecture

**Composable Operation-Based Skills**:
- **repo-discoverer** - Reusable utility to discover repos in org
- **project-syncer** - Core sync logic for single project
- **org-syncer** - Orchestrator that uses repo-discoverer + project-syncer
- **handler-sync-github** - GitHub-specific sync operations

This provides:
- Reusability (repo-discoverer used by org-syncer)
- Single responsibility (each skill does one thing)
- Composability (skills call other skills)

### Sync Mechanism

**Bash Scripts Instead of GitHub Workflows**:
- Scripts execute from plugin directory
- No installation step needed (no `/install-core` command)
- Provider-agnostic (can run locally or in any CI)
- Uses repo plugin for git operations

**Benefits**:
- Simpler architecture
- No workflow installation required
- Works offline/locally
- Easier to test and debug

### Configuration Strategy

**Three-Tier Approach**:
1. **Global Config**: `~/.config/fractary/codex/config.json`
   - Organization-wide settings
   - Default sync patterns
   - Codex repo specification

2. **Project Config**: `.fractary/plugins/codex/config.json`
   - Project-specific overrides
   - Custom sync patterns
   - Exclusion rules

3. **Auto-Discovery**: Fallback when config missing
   - Extract organization from git remote
   - Look for `codex.*` repo in organization
   - Prompt for confirmation

**Codex Repo Specification**:
- Simple, direct: `"codex_repo": "codex.fractary.com"`
- No pattern complexity needed
- Explicit and clear

---

## Refactoring Tasks

### 1. Plugin Metadata & Dependencies

**File**: `.claude-plugin/plugin.json`

**Changes**:
```json
{
  "name": "fractary-codex",
  "requires": ["fractary-repo"],
  "agents": [
    "./agents/codex-manager.md"
  ],
  "commands": [
    "./commands/init.md",
    "./commands/sync-project.md",
    "./commands/sync-org.md"
  ]
}
```

**Create**: Configuration schema
- `.claude-plugin/config.schema.json` - JSON schema for validation
- `config/codex.example.json` - Example global config
- `config/codex.project.example.json` - Example project config

### 2. Agent Refactoring

**File**: `agents/codex-manager.md` (renamed from sync-manager.md)

**Structure**:
```markdown
---
name: codex-manager
description: |
  Manage documentation and knowledge sync across organization projects.
  Coordinates with fractary-repo for git operations.
tools: Bash, Skill
---

<CONTEXT>
You are the codex manager agent for the Fractary codex plugin.
Your responsibility is to orchestrate documentation synchronization between projects and the central codex repository.
</CONTEXT>

<CRITICAL_RULES>
**IMPORTANT:** YOU MUST NEVER do work yourself
- Always delegate to skills
- If no skill exists: stop and inform user
- Never read files or execute git commands directly (use repo plugin via skills)

**IMPORTANT:** Configuration is required
- Global or project config must exist
- Use init operation to create config if missing
- Never hardcode organization/repo names
</CRITICAL_RULES>

<WORKFLOW>
Parse operation and delegate to appropriate skill:

**Operation: init**
- Create global and/or project configuration
- Auto-detect organization from git remote
- Prompt for codex repo name
- Validate configuration

**Operation: sync-project**
- Skill: project-syncer
- Sync single project (current or specified)
- Direction: to-codex | from-codex | bidirectional

**Operation: sync-org**
- Skills: repo-discoverer → project-syncer (for each)
- Sync all projects in organization
- Aggregate results
</WORKFLOW>

<COMPLETION_CRITERIA>
Operation is complete when:
- ✅ Skill successfully executed
- ✅ Results returned to user
- ✅ No errors occurred
</COMPLETION_CRITERIA>

<OUTPUTS>
Return to user:
- Operation summary
- Files synced
- Any errors or warnings
</OUTPUTS>

<ERROR_HANDLING>
  <SKILL_FAILURE>
  If skill fails:
  1. Report exact error to user
  2. Do NOT attempt to solve problem yourself
  3. Ask user how to proceed
  </SKILL_FAILURE>

  <MISSING_CONFIG>
  If configuration missing:
  1. Inform user configuration is required
  2. Suggest running: /fractary-codex:init
  3. Do not proceed without config
  </MISSING_CONFIG>
</ERROR_HANDLING>
```

### 3. Skills Creation

#### Skill 1: repo-discoverer

**File**: `skills/repo-discoverer/SKILL.md`

**Purpose**: Discover all repositories in an organization (reusable utility)

**Key Sections**:
- Uses repo plugin for API calls
- Returns list of repo names/URLs
- Filters out codex core repo
- Handles pagination for large orgs

**Scripts**:
- `scripts/discover-repos.sh` - Port from existing repo-discover.sh

#### Skill 2: project-syncer

**File**: `skills/project-syncer/SKILL.md`

**Purpose**: Sync single project bidirectionally with codex core

**Workflow Steps**:
- `workflow/analyze-patterns.md` - Identify what needs syncing
- `workflow/sync-to-codex.md` - Pull docs from project to codex
- `workflow/sync-from-codex.md` - Push docs from codex to project
- `workflow/validate-sync.md` - Verify sync completed successfully

**Scripts**:
- `scripts/sync-docs.sh` - Main sync script
- `scripts/parse-frontmatter.sh` - Extract sync rules from markdown
- `scripts/validate-sync.sh` - Verify sync integrity

**Handler Usage**:
```markdown
<HANDLERS>
  <SYNC_MECHANISM>
  When config.handlers.sync.active == "github":
    **USE SKILL: handler-sync-github**
    Operation: sync-docs
    Arguments: {direction, patterns, project, codex_repo}
  </SYNC_MECHANISM>
</HANDLERS>
```

#### Skill 3: org-syncer

**File**: `skills/org-syncer/SKILL.md`

**Purpose**: Sync all projects in organization

**Workflow**:
1. Use repo-discoverer to get project list
2. For each project: invoke project-syncer
3. Aggregate results and report summary
4. Handle failures gracefully (continue with other projects)

#### Skill 4: handler-sync-github

**File**: `skills/handler-sync-github/SKILL.md`

**Purpose**: GitHub-specific sync operations (handler pattern)

**Operations**:
- `sync-docs` - Bidirectional documentation sync
- `parse-routing` - Extract frontmatter sync rules
- `validate-patterns` - Ensure patterns are valid

**Workflows**:
- `workflow/sync-to-codex.md` - Pull project docs to codex
- `workflow/sync-from-codex.md` - Push codex docs to projects
- `workflow/parse-frontmatter.md` - Extract routing rules

**Scripts** (ported from GitHub workflows):
- `scripts/sync-to-codex.sh`
- `scripts/sync-from-codex.sh`
- `scripts/parse-frontmatter.sh`

### 4. Convert Workflows to Scripts

Port logic from 3 GitHub workflows to bash scripts:

#### sync-docs.sh

**Source Workflows**:
- `sync-codex-docs-to-projects.yml`
- `sync-project-docs-to-codex.yml`

**Features**:
- Modes: `--to-codex`, `--from-codex`, `--bidirectional`
- Git sparse checkout for efficiency
- Frontmatter parsing for routing
- System files pattern matching
- Safety: dry-run mode, deletion thresholds
- Retry logic for conflicts

**Usage**:
```bash
./sync-docs.sh \
  --project "myproject" \
  --codex "codex.fractary.com" \
  --direction "bidirectional" \
  --patterns "docs/**,CLAUDE.md" \
  --dry-run
```

#### parse-frontmatter.sh

**Source**: Workflow YAML parsing logic

**Features**:
- Extract `codex_sync_include` arrays
- Extract `codex_sync_exclude` patterns
- Handle both inline arrays and YAML lists
- Output JSON for script consumption

#### discover-repos.sh

**Source**: Existing `repo-discover.sh`

**Enhancements**:
- Use repo plugin (gh/gitlab CLI wrapper)
- Support multiple platforms
- Filter patterns
- JSON output

### 5. Commands

#### Command 1: /init (NEW)

**File**: `commands/init.md`

**Structure**:
```markdown
---
name: fractary-codex:init
description: Initialize codex plugin configuration
argument-hint: [--global|--project] [--org <name>] [--codex <repo>]
---

<CONTEXT>
You are the init command router for the codex plugin.
Your role is to guide users through configuration setup.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse command arguments
- Invoke codex-manager agent with init operation
- Pass configuration scope (global/project)

**YOU MUST NOT:**
- Create config files yourself (agent handles this)
- Execute git commands directly
</CRITICAL_RULES>

<WORKFLOW>
1. Parse arguments:
   - Scope: --global or --project (default: both)
   - Organization: --org <name> (auto-detect if missing)
   - Codex repo: --codex <repo> (prompt if missing)

2. Invoke codex-manager agent:
   - Operation: init
   - Parameters: {scope, organization, codex_repo}

3. Return results to user
</WORKFLOW>

<EXAMPLES>
# Initialize both global and project config
/fractary-codex:init

# Initialize only global config
/fractary-codex:init --global --org fractary --codex codex.fractary.com

# Initialize only project config
/fractary-codex:init --project
</EXAMPLES>
```

#### Command 2: /sync-project (REFACTOR)

**File**: `commands/sync-project.md`

**Changes**:
- Add proper XML structure
- Parse direction option
- Support project name argument
- Proper agent invocation

**Usage**:
```bash
/fractary-codex:sync-project                    # Current project, bidirectional
/fractary-codex:sync-project myproject          # Specific project
/fractary-codex:sync-project --to-codex         # Only pull to codex
/fractary-codex:sync-project --from-codex       # Only push from codex
```

#### Command 3: /sync-org (NEW)

**File**: `commands/sync-org.md`

**Purpose**: Sync all projects in organization

**Options**:
- `--dry-run` - Show what would sync without doing it
- `--exclude <pattern>` - Exclude repos matching pattern
- `--direction <dir>` - Sync direction (default: bidirectional)

**Usage**:
```bash
/fractary-codex:sync-org                        # Sync all projects
/fractary-codex:sync-org --dry-run              # Preview
/fractary-codex:sync-org --exclude "archive-*"  # Exclude archived
```

### 6. Configuration System

#### Global Config

**File**: `~/.config/fractary/codex/config.json`

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
    "**/node_modules/**"
  ],
  "handlers": {
    "sync": {
      "active": "github"
    }
  }
}
```

#### Project Config

**File**: `.fractary/plugins/codex/config.json`

```json
{
  "version": "1.0",
  "codex_repo": "codex.fractary.com",
  "sync_patterns": [
    "docs/**",
    "CLAUDE.md",
    "standards/**"
  ],
  "exclude_patterns": [
    "docs/private/**",
    "docs/drafts/**"
  ],
  "auto_sync": false,
  "sync_direction": "bidirectional"
}
```

#### Schema

**File**: `.claude-plugin/config.schema.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Codex Plugin Configuration",
  "type": "object",
  "properties": {
    "version": {
      "type": "string",
      "description": "Configuration version"
    },
    "organization": {
      "type": "string",
      "description": "GitHub/GitLab organization name"
    },
    "codex_repo": {
      "type": "string",
      "description": "Codex core repository name (e.g., codex.fractary.com)"
    },
    "sync_patterns": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Glob patterns for files to sync"
    },
    "exclude_patterns": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Glob patterns for files to exclude"
    },
    "handlers": {
      "type": "object",
      "properties": {
        "sync": {
          "type": "object",
          "properties": {
            "active": {
              "type": "string",
              "enum": ["github"],
              "description": "Active sync handler"
            }
          }
        }
      }
    }
  },
  "required": ["version", "organization", "codex_repo"]
}
```

### 7. Documentation Updates

#### README.md

**Changes**:
- Remove OmniDAS branding
- Add Fractary-neutral overview
- Update usage examples
- Reference new commands

#### Setup Guide

**File**: `docs/setup-guide.md`

**Contents**:
- Prerequisites (repo plugin)
- Installation
- Configuration (init command)
- First sync walkthrough
- Troubleshooting

#### Sync Mechanics

**File**: `docs/sync-mechanics.md`

**Contents**:
- How sync works
- Frontmatter routing
- Pattern matching
- Conflict resolution
- Safety features

### 8. Cleanup

**Delete**:
- `.github/workflows/sync-codex-claude-to-projects.yml`
- `.github/workflows/sync-codex-docs-to-projects.yml`
- `.github/workflows/sync-project-docs-to-codex.yml`
- `skills/codex-sync-manager.md` (old skill file)
- `agents/sync-manager.md` (renamed to codex-manager.md)

**Refactor**:
- `skills/sync-manager/guide.md` → integrate into skill workflows

---

## File Inventory

### New Files (~18 files)

**Configuration** (3 files):
- `.claude-plugin/config.schema.json`
- `config/codex.example.json`
- `config/codex.project.example.json`

**Skills** (4 SKILL.md files):
- `skills/repo-discoverer/SKILL.md`
- `skills/project-syncer/SKILL.md`
- `skills/org-syncer/SKILL.md`
- `skills/handler-sync-github/SKILL.md`

**Skill Workflows** (~6 files):
- `skills/project-syncer/workflow/analyze-patterns.md`
- `skills/project-syncer/workflow/sync-to-codex.md`
- `skills/project-syncer/workflow/sync-from-codex.md`
- `skills/project-syncer/workflow/validate-sync.md`
- `skills/handler-sync-github/workflow/sync-to-codex.md`
- `skills/handler-sync-github/workflow/sync-from-codex.md`

**Scripts** (4 files):
- `skills/repo-discoverer/scripts/discover-repos.sh`
- `skills/project-syncer/scripts/sync-docs.sh`
- `skills/handler-sync-github/scripts/parse-frontmatter.sh`
- `skills/handler-sync-github/scripts/validate-sync.sh`

**Commands** (2 new):
- `commands/init.md`
- `commands/sync-org.md`

**Documentation** (2 files):
- `docs/setup-guide.md`
- `docs/sync-mechanics.md`

### Modified Files (~4 files)

- `.claude-plugin/plugin.json` - Add dependencies, update agents/commands
- `agents/codex-manager.md` - Renamed + restructured from sync-manager.md
- `commands/sync-project.md` - Restructured with proper XML markup
- `README.md` - Remove OmniDAS branding, update examples

### Deleted Files (~5 files)

- `.github/workflows/sync-codex-claude-to-projects.yml`
- `.github/workflows/sync-codex-docs-to-projects.yml`
- `.github/workflows/sync-project-docs-to-codex.yml`
- `skills/codex-sync-manager.md`
- `agents/sync-manager.md` (renamed, not deleted)

---

## Implementation Plan

### Phase 1: Foundation (Configuration & Structure)

**Tasks**:
1. Create configuration schema and examples
2. Update plugin.json with dependencies
3. Create directory structure for new skills
4. Create this specification document

**Deliverables**:
- Configuration files ready
- Directory structure in place
- Dependencies declared

### Phase 2: Agent Refactoring

**Tasks**:
1. Rename sync-manager.md → codex-manager.md
2. Add proper XML structure
3. Remove OmniDAS references
4. Implement operation routing

**Deliverables**:
- Refactored agent following standards
- Organization-agnostic implementation

### Phase 3: Core Skills

**Tasks**:
1. Create repo-discoverer skill + scripts
2. Create project-syncer skill + workflows
3. Create org-syncer skill
4. Port repo-discover.sh script

**Deliverables**:
- 3 core skills operational
- Scripts tested and working

### Phase 4: Handlers & Scripts

**Tasks**:
1. Create handler-sync-github skill
2. Port workflow logic to bash scripts
3. Create parse-frontmatter.sh
4. Create validate-sync.sh

**Deliverables**:
- GitHub handler operational
- All workflows converted to scripts

### Phase 5: Commands

**Tasks**:
1. Create /init command
2. Refactor /sync-project command
3. Create /sync-org command

**Deliverables**:
- All commands working
- Proper routing to agent

### Phase 6: Documentation & Cleanup

**Tasks**:
1. Update README.md
2. Create setup-guide.md
3. Create sync-mechanics.md
4. Delete old workflow files
5. Delete old skill files

**Deliverables**:
- Complete documentation
- Clean codebase

### Phase 7: Testing & Validation

**Tasks**:
1. Test init command
2. Test project sync (single repo)
3. Test org sync (multiple repos)
4. Verify repo plugin integration
5. Validate all XML markup

**Deliverables**:
- All functionality tested
- Standards compliance verified

---

## Success Criteria

### Functional Requirements

✅ **Configuration**
- Init command creates both global and project config
- Auto-discovery works when config missing
- Config follows Fractary patterns

✅ **Sync Operations**
- Project sync works bidirectionally
- Org sync handles multiple repos
- Frontmatter routing preserved
- Pattern matching works correctly

✅ **Integration**
- Repo plugin integration works
- Git operations delegated properly
- No direct git command execution

✅ **Scripts**
- All scripts work locally (no GitHub Actions required)
- Dry-run mode functions
- Safety thresholds enforced

### Standards Compliance

✅ **Architecture**
- Follows 3-layer architecture (command → manager → skill)
- Skills delegate to handlers where appropriate
- No work done in commands/agents

✅ **XML Markup**
- All agents have proper sections (CONTEXT, CRITICAL_RULES, etc.)
- All skills have proper sections (CONTEXT, WORKFLOW, COMPLETION_CRITERIA, etc.)
- Uppercase XML tags used throughout

✅ **Documentation**
- Skills output start/end messages
- Completion criteria clearly defined
- Error handling documented

✅ **Organization-Agnostic**
- No OmniDAS references
- No hardcoded organization names
- Configuration-driven behavior

### Quality Metrics

✅ **Maintainability**
- Clear separation of concerns
- Reusable components
- Well-documented code

✅ **Reliability**
- Error handling at all levels
- Safety features (dry-run, thresholds)
- Validation of operations

✅ **Usability**
- Simple command interface
- Clear error messages
- Good documentation

---

## Future Enhancements

### Handler Expansion

**Vector Store Handler** (`handler-sync-vector`):
- Sync to vector database for semantic search
- MCP server integration
- RAG-ready knowledge base

**MCP Server Handler** (`handler-sync-mcp`):
- Direct MCP server integration
- Real-time context injection
- Query-based retrieval

### Advanced Features

**Selective Sync**:
- Sync specific files/directories
- Tag-based routing
- Conditional sync rules

**Conflict Resolution**:
- Smart merge strategies
- Interactive conflict resolution
- Version tracking

**Analytics**:
- Sync statistics
- Coverage metrics
- Staleness detection

---

## References

### Standards & Patterns

- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md` - Plugin development standards
- `plugins/faber-cloud/` - Reference implementation
- `plugins/repo/` - Repo plugin integration example

### Related Plugins

- **fractary-repo** - Source control operations (dependency)
- **fractary-work** - Work item management (similar patterns)
- **fractary-faber** - FABER workflow orchestration

---

**Document History**:
- 2025-11-04: Initial specification created based on refactoring plan
