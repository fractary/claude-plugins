# Fractary FABER Plugin Implementation Plan

**Date**: 2025-01-22
**Purpose**: Complete specification for implementing the fractary-faber plugin
**Workflow**: Frame → Architect → Build → Evaluate → Release (FABER)

## Executive Summary

This document provides a complete implementation plan for the fractary-faber plugin, a tool-agnostic SDLC workflow framework that orchestrates the complete software development lifecycle from issue intake through deployment. The plugin implements the FABER workflow model where FABER stands for:

- **F**rame - Fetch and classify work items, prepare environment
- **A**rchitect - Design the solution and create specifications
- **B**uild - Implement the solution according to specification
- **E**valuate - Test and review with auto-resolution
- **R**elease - Deploy/publish and create pull requests

## Key Architectural Principles

### 1. Tool-Agnostic Design
FABER is **not** Fractary-specific. It's a standalone SDLC workflow framework that:
- Works with any issue tracker (GitHub, Jira, Linear)
- Works with any source control (GitHub, GitLab, Bitbucket)
- Works with any file storage (R2, S3, local)
- Can be used independently without other Fractary tools

### 2. Separation of Concerns

**Generic Manager Agents** (Reusable Primitives):
- `work-manager` - Issue tracking operations (fetch, comment, classify, update)
- `repo-manager` - Source control operations (branch, commit, push, PR, merge)
- `file-manager` - File storage operations (upload, download, delete, list, get_url)

**FABER Stage Manager Agents**:
- `frame-manager` - Frame phase orchestration
- `architect-manager` - Architect phase orchestration
- `build-manager` - Build phase orchestration
- `evaluate-manager` - Evaluate phase orchestration
- `release-manager` - Release phase orchestration

**Director Agent**:
- `faber-director` - Orchestrates all 5 FABER stages, manages retry logic

### 3. Adapters as Embedded Resources
- Adapters live as **docs + scripts** within skills
- Managers select adapters based on config (e.g., `work_system: "github"`)
- Adding new platforms = adding new scripts/docs to skills
- No code changes to agents required

### 4. Context Efficiency Strategy

**Agents** (Decision logic, minimal code):
- 100-300 lines
- Focus on decision-making, orchestration
- Call skills for actual work

**Skills** (Orchestration, adapter selection):
- 50-150 lines
- Load config, determine which adapter to use
- Call scripts for deterministic operations

**Scripts** (All deterministic operations):
- Bash/Python scripts in `skills/*/scripts/`
- Only script **output** enters context, not code
- Massive context savings

**Docs** (Reference material):
- API documentation, examples
- Loaded into context only when needed by agents

### 5. User Interaction Model

**One Command Pattern**: `/faber {freeform-response}`

Examples:
- `/faber ship to staging`
- `/faber explain risk around email service`
- `/faber proceed with unit tests only`
- `/faber reject — scope creep; split into two issues`

**Status Cards**: Posted to issues with current state and options
```markdown
**FABER** • Stage: Evaluate
Build is green. Ready to roll to staging.
Options: "ship to staging", "hold", "reject"

```yaml
session: faber-issue-123-v5
stage: evaluate
next_allowed: [ship_to_staging, hold, reject]
requires_confirmation: true
context_refs: [pr#87, ci:build-20251022.3]
```
```

### 6. Safety and Autonomy

**Autonomy Levels**:
- `dry-run` - Simulate, write plan, do nothing
- `assist` - Open PRs/drafts, never merge/deploy
- `guarded` - Proceed until gates, pause for approvals
- `autonomous` - No pauses, still logs everything

**Safety Features**:
- Protected paths (e.g., `secrets/**`, `infra/prod/**`)
- Confirmation gates for dangerous actions (release, deploy, tag)
- Idempotency via session tokens
- Complete audit trail in work state

## Existing Assets

The following have already been created in `plugins/fractary-faber/`:

✅ **Agents**:
- `work-manager.md` - Issue tracking interface
- `file-manager.md` - Storage interface
- `repo-manager.md` - Source control interface
- `frame-manager.md` - Frame phase manager
- `architect-manager.md` - Architect phase manager (needs Analyze → Architect update)
- `build-manager.md` - Build phase manager
- `evaluate-manager.md` - Evaluate phase manager
- `release-manager.md` - Release phase manager

✅ **Commands**:
- `faber.md` - Main entry point command

✅ **Skills**:
- `agent-builder/SKILL.md` - (May not be directly relevant to FABER workflow)

## What Needs to be Done

### Phase 1: Core Infrastructure

#### 1.1 Create Configuration System

**File**: `config/faber.example.toml`

```toml
[project]
name = "my-project"
issue_system = "github"      # github | jira | linear | manual
source_control = "github"    # github | gitlab | bitbucket
file_system = "r2"           # r2 | s3 | local

[auth]
ISSUE_TOKEN = "env:GITHUB_TOKEN"
GIT_TOKEN = "env:GITHUB_TOKEN"
CI_TOKEN = "env:GITHUB_TOKEN"
FILE_STORAGE_TOKEN = "env:R2_TOKEN"

[defaults]
preset = "software-guarded"           # software-basic | software-guarded | software-autonomous
autonomy = "guarded"                  # dry-run | assist | guarded | autonomous
branch_naming = "feat/{issue_id}-{slug}"

[director]
type = "default"                      # default | custom
agent_ref = "agents/faber-director.md"
model = "claude-3.7"
max_tokens = 4096

[safety]
protected_paths = ["secrets/**", "infra/prod/**"]
require_confirm_for = ["release", "deploy", "tag"]

[workflow]
max_evaluate_retries = 3
auto_merge = false

[systems.work_config]
# GitHub-specific
repo = "owner/repo"
api_url = "https://api.github.com"

[systems.repo_config]
default_branch = "main"

[systems.file_config]
# R2-specific
account_id = "..."
bucket_name = "..."
public_url = "https://..."
```

#### 1.2 Create FABER Core Skill

**File**: `skills/faber-core/SKILL.md`

```markdown
---
name: faber-core
description: Core utilities for FABER workflow management - config loading, session management, status cards
---

# FABER Core Skill

Provides core utilities for FABER workflows.

## Operations

### Load Configuration
```bash
./scripts/config-loader.sh
```
Returns parsed `.faber.config.json` as JSON.

### Create Session
```bash
./scripts/session-create.sh <work_id> <issue_id> <domain>
```
Creates new workflow session.

### Update Session
```bash
./scripts/session-update.sh <session_id> <stage> <status>
```
Updates session state.

### Post Status Card
```bash
./scripts/status-card-post.sh <session_id> <issue_id> <stage> <message> <options_json>
```
Posts status card to issue.

### Pattern Substitution
```bash
./scripts/pattern-substitute.sh <template> <work_id> <issue_id> <environment>
```
Replaces patterns like `{work_id}`, `{issue_id}`, `{environment}` in template.
```

**Scripts to Create**:
- `skills/faber-core/scripts/config-loader.sh` - Load and parse config file
- `skills/faber-core/scripts/session-create.sh` - Create workflow session
- `skills/faber-core/scripts/session-update.sh` - Update session state
- `skills/faber-core/scripts/status-card-post.sh` - Post status card to issue
- `skills/faber-core/scripts/pattern-substitute.sh` - Replace template variables

**Templates**:
- `skills/faber-core/templates/faber-config.toml.template` - Config template
- `skills/faber-core/templates/status-card.template.md` - Status card template

**Docs**:
- `skills/faber-core/docs/status-cards.md` - Status card format spec
- `skills/faber-core/docs/session-management.md` - Session tracking spec
- `skills/faber-core/docs/configuration.md` - Configuration reference

#### 1.3 Update Architect Manager

**Task**: Update all references from "Analyze" to "Architect" in `agents/architect-manager.md`

**Changes**:
- Update description to emphasize solution design (not just analysis)
- Update comments/documentation to reflect architectural focus
- No functional changes, just naming/clarity

### Phase 2: Extract Manager Logic to Skills

#### 2.1 Work Manager Skill

**File**: `skills/work-manager/SKILL.md`

```markdown
---
name: work-manager
description: Issue tracking operations across GitHub, Jira, Linear, etc.
---

# Work Manager Skill

Provides issue tracking operations.

## Configuration

Reads `work_system` from config to determine which adapter to use.

## Operations

### Fetch Issue
```bash
./scripts/<adapter>/fetch-issue.sh <issue_id>
```

### Create Comment
```bash
./scripts/<adapter>/create-comment.sh <issue_id> <work_id> <author> <message>
```

### Classify Issue
```bash
./scripts/<adapter>/classify-issue.sh <issue_json>
```

### Update Status
```bash
./scripts/<adapter>/update-status.sh <issue_id> <status> <work_id>
```

Where `<adapter>` is: `github`, `jira`, or `linear`
```

**Scripts to Create**:
- `skills/work-manager/scripts/github/fetch-issue.sh` - Fetch GitHub issue via `gh` CLI
- `skills/work-manager/scripts/github/create-comment.sh` - Post comment to GitHub issue
- `skills/work-manager/scripts/github/set-label.sh` - Set labels on GitHub issue
- `skills/work-manager/scripts/github/classify-issue.sh` - Classify issue type from labels/content
- `skills/work-manager/scripts/jira/fetch-issue.sh` - Fetch Jira issue (future)
- `skills/work-manager/scripts/jira/create-comment.sh` - Post comment to Jira (future)
- `skills/work-manager/scripts/linear/fetch-issue.sh` - Fetch Linear issue (future)
- `skills/work-manager/scripts/linear/create-comment.sh` - Post comment to Linear (future)

**Docs**:
- `skills/work-manager/docs/github-api.md` - GitHub API reference
- `skills/work-manager/docs/jira-api.md` - Jira API reference
- `skills/work-manager/docs/linear-api.md` - Linear API reference

**Agent Update**: Refactor `agents/work-manager.md` to:
- Remove inline bash code
- Call work-manager skill operations
- Focus on decision logic (which operation to perform based on input)

#### 2.2 Repo Manager Skill

**File**: `skills/repo-manager/SKILL.md`

```markdown
---
name: repo-manager
description: Source control operations across GitHub, GitLab, Bitbucket, etc.
---

# Repo Manager Skill

Provides source control operations.

## Configuration

Reads `repo_system` from config to determine which adapter to use.

## Operations

### Generate Branch Name
```bash
./scripts/<adapter>/generate-branch-name.sh <work_id> <issue_id> <work_type> <title>
```

### Create Branch
```bash
./scripts/<adapter>/create-branch.sh <branch_name>
```

### Create Commit
```bash
./scripts/<adapter>/create-commit.sh <work_id> <author> <issue_id> <work_type> <message>
```

### Push Branch
```bash
./scripts/<adapter>/push-branch.sh <branch_name> <force> <set_upstream>
```

### Create PR
```bash
./scripts/<adapter>/create-pr.sh <work_id> <branch_name> <issue_id> <title> <body>
```

### Merge PR
```bash
./scripts/<adapter>/merge-pr.sh <source_branch> <target_branch> <strategy> <work_id> <issue_id>
```

Where `<adapter>` is: `github`, `gitlab`, or `bitbucket`
```

**Scripts to Create**:
- `skills/repo-manager/scripts/github/generate-branch-name.sh` - Generate semantic branch name
- `skills/repo-manager/scripts/github/create-branch.sh` - Create git branch
- `skills/repo-manager/scripts/github/create-commit.sh` - Create semantic commit
- `skills/repo-manager/scripts/github/push-branch.sh` - Push to remote
- `skills/repo-manager/scripts/github/create-pr.sh` - Create PR via `gh` CLI
- `skills/repo-manager/scripts/github/merge-pr.sh` - Merge PR with strategy
- `skills/repo-manager/scripts/gitlab/` - GitLab adapters (future)
- `skills/repo-manager/scripts/bitbucket/` - Bitbucket adapters (future)

**Docs**:
- `skills/repo-manager/docs/github-git.md` - GitHub + Git reference
- `skills/repo-manager/docs/gitlab-git.md` - GitLab + Git reference

**Agent Update**: Refactor `agents/repo-manager.md` to:
- Remove inline bash code
- Call repo-manager skill operations
- Focus on decision logic

#### 2.3 File Manager Skill

**File**: `skills/file-manager/SKILL.md`

```markdown
---
name: file-manager
description: File storage operations across R2, S3, local filesystem, etc.
---

# File Manager Skill

Provides file storage operations.

## Configuration

Reads `file_system` from config to determine which adapter to use.

## Operations

### Upload File
```bash
./scripts/<adapter>/upload.sh <local_path> <remote_path> <public>
```

### Download File
```bash
./scripts/<adapter>/download.sh <remote_path> <local_path>
```

### Delete File
```bash
./scripts/<adapter>/delete.sh <remote_path>
```

### List Files
```bash
./scripts/<adapter>/list.sh <prefix> <max_results>
```

### Get URL
```bash
./scripts/<adapter>/get-url.sh <remote_path> <expires_in>
```

Where `<adapter>` is: `r2`, `s3`, or `local`
```

**Scripts to Create**:
- `skills/file-manager/scripts/r2/upload.sh` - Upload to Cloudflare R2
- `skills/file-manager/scripts/r2/download.sh` - Download from R2
- `skills/file-manager/scripts/r2/delete.sh` - Delete from R2
- `skills/file-manager/scripts/r2/list.sh` - List R2 files
- `skills/file-manager/scripts/r2/get-url.sh` - Get public URL from R2
- `skills/file-manager/scripts/s3/` - S3 adapters (future)
- `skills/file-manager/scripts/local/` - Local filesystem adapters (future)

**Docs**:
- `skills/file-manager/docs/r2-api.md` - Cloudflare R2 API reference
- `skills/file-manager/docs/s3-api.md` - AWS S3 API reference

**Agent Update**: Refactor `agents/file-manager.md` to:
- Remove inline bash code
- Call file-manager skill operations
- Focus on decision logic

### Phase 3: Director & Commands

#### 3.1 Create FABER Director Agent

**File**: `agents/faber-director.md`

```markdown
---
name: faber-director
description: Orchestrates the complete FABER workflow (Frame → Architect → Build → Evaluate → Release)
tools: Bash, SlashCommand
model: inherit
---

# FABER Director

You are the **FABER Director**, orchestrating the complete software development lifecycle workflow.

## Your Mission

Execute the 5-phase FABER workflow:
1. **Frame** - Fetch and classify work, prepare environment
2. **Architect** - Design solution and create specification
3. **Build** - Implement solution from specification
4. **Evaluate** - Test and review (with retry loop)
5. **Release** - Deploy/publish and create PR

## Input Parameters

- `work_id` - FABER work identifier
- `source_type` - Issue tracker (github, jira, linear)
- `source_id` - Issue ID
- `work_domain` - Domain (engineering, design, writing, data)
- `auto_merge` - Auto-merge on release (true/false)

## Workflow

### Phase 1: Frame
Invoke frame-manager to fetch work item, classify, and prepare environment.

### Phase 2: Architect
Invoke architect-manager to generate implementation specification.

### Phase 3: Build
Invoke build-manager to implement solution from specification.

### Phase 4: Evaluate (with retry loop)
Invoke evaluate-manager to test and review.

**Retry Logic**:
- Max retries: 3 (configurable via config)
- If evaluate returns "no-go": retry Build → Evaluate
- If retries exhausted: fail workflow

### Phase 5: Release
Invoke release-manager to deploy/publish.

## Session Management

- Create session at start
- Update session after each phase
- Post status cards to issue tracking system
- Track session state for resume/retry

## Autonomy Enforcement

- Read autonomy level from config
- Enforce confirmation gates based on autonomy
- Post appropriate status cards based on autonomy level

## Error Handling

- Catch errors from each phase manager
- Post error status cards
- Update session with failure state
- Do not proceed to next phase on error

## Output

Final workflow summary including:
- Work ID
- All phase results
- PR URL (if applicable)
- Overall success/failure
```

**Implementation Notes**:
- This agent calls the 5 phase managers in sequence
- Implements the Evaluate → Build retry loop
- Manages session state via faber-core skill
- Posts status cards via faber-core skill
- Reads configuration via faber-core skill

#### 3.2 Create Commands

**File**: `commands/faber-init.md`

```markdown
---
description: Initialize FABER in the current project
allowed-tools: Bash, SlashCommand
---

# Initialize FABER

Creates `.faber.config.json` in the current project with auto-discovered settings.

## What it does

1. Detects project metadata (name, org, repo)
2. Detects issue tracker (GitHub, Jira, Linear)
3. Detects source control system
4. Creates `.faber.config.json` with defaults
5. Prompts for any missing configuration

## Usage

```bash
/faber-init
```

## Auto-Discovery

- Project name: from git remote or directory name
- Issue tracker: from installed CLIs (gh, jira)
- Source control: from git remote
- File storage: defaults to local, prompts for R2/S3 if desired
```

**File**: `commands/faber-run.md`

```markdown
---
description: Execute FABER workflow from an issue
allowed-tools: Bash, SlashCommand
---

# Run FABER Workflow

Execute the complete FABER workflow for a work item.

## Usage

```bash
/faber-run <issue_id> [autonomy_level]
```

## Parameters

- `issue_id` - Issue/ticket ID to process
- `autonomy_level` (optional) - Override config default: dry-run | assist | guarded | autonomous

## What it does

1. Loads configuration
2. Generates work ID
3. Creates session
4. Invokes faber-director agent
5. Posts workflow summary to issue

## Examples

```bash
# Run with default autonomy from config
/faber-run 123

# Run with specific autonomy level
/faber-run 123 autonomous

# Dry run (simulation only)
/faber-run 123 dry-run
```
```

**File**: `commands/faber-status.md`

```markdown
---
description: Show status of current FABER workflow session
allowed-tools: Bash, SlashCommand
---

# FABER Status

Show the current status of a FABER workflow session.

## Usage

```bash
/faber-status [work_id]
```

## Parameters

- `work_id` (optional) - Specific work ID to check. If omitted, shows all active sessions.

## What it shows

- Current phase
- Phase statuses (complete, in_progress, failed)
- Last update time
- Session metadata (issue ID, domain, autonomy level)
- Next steps or actions required

## Examples

```bash
# Show all active sessions
/faber-status

# Show specific session
/faber-status abc12345
```
```

**File**: `commands/faber.md` (refine existing)

Update to be the main entry point that can:
- Accept freeform responses: `/faber {response}`
- Route to appropriate action based on context
- Invoke director if starting new workflow
- Send response to active session if one exists

### Phase 4: Presets & Documentation

#### 4.1 Create Presets

**File**: `presets/software-basic.yaml`

```yaml
name: software-basic
description: Minimal FABER workflow with no gates
agents:
  - faber-director
  - frame-manager
  - architect-manager
  - build-manager
  - evaluate-manager
  - release-manager
  - work-manager
  - repo-manager
  - file-manager
skills:
  - faber-core
  - work-manager
  - repo-manager
  - file-manager
settings:
  autonomy: assist
  auto_merge: false
  max_evaluate_retries: 2
  require_confirm_for: []
```

**File**: `presets/software-guarded.yaml`

```yaml
name: software-guarded
description: FABER workflow with approval gates at Evaluate
agents:
  - faber-director
  - frame-manager
  - architect-manager
  - build-manager
  - evaluate-manager
  - release-manager
  - work-manager
  - repo-manager
  - file-manager
skills:
  - faber-core
  - work-manager
  - repo-manager
  - file-manager
settings:
  autonomy: guarded
  auto_merge: false
  max_evaluate_retries: 3
  require_confirm_for: [release, deploy]
  protected_paths: [secrets/**, infra/prod/**]
```

**File**: `presets/software-autonomous.yaml`

```yaml
name: software-autonomous
description: Fully autonomous FABER workflow with no human gates
agents:
  - faber-director
  - frame-manager
  - architect-manager
  - build-manager
  - evaluate-manager
  - release-manager
  - work-manager
  - repo-manager
  - file-manager
skills:
  - faber-core
  - work-manager
  - repo-manager
  - file-manager
settings:
  autonomy: autonomous
  auto_merge: true
  max_evaluate_retries: 3
  require_confirm_for: []
```

#### 4.2 Create Documentation

**File**: `README.md`

```markdown
# Fractary FABER Plugin

A tool-agnostic SDLC workflow framework for Claude Code that orchestrates the complete software development lifecycle.

## What is FABER?

FABER stands for **Frame → Architect → Build → Evaluate → Release**, a universal workflow for building anything:

1. **Frame** - Fetch work item, classify, prepare environment
2. **Architect** - Design solution, create specification
3. **Build** - Implement solution from specification
4. **Evaluate** - Test and review with auto-resolution
5. **Release** - Deploy/publish and create pull request

## Quick Start

```bash
# Initialize FABER in your project
/faber-init

# Run FABER workflow on an issue
/faber-run 123

# Check workflow status
/faber-status
```

## Features

- **Tool-Agnostic**: Works with GitHub, Jira, Linear, GitLab, etc.
- **One Command**: `/faber {freeform-response}` for all interactions
- **Autonomous Options**: dry-run, assist, guarded, autonomous
- **Safety First**: Protected paths, confirmation gates, audit trails
- **Extensible**: Add new adapters without code changes

## Installation

[Installation instructions]

## Configuration

[Configuration guide]

## Documentation

- [Workflow Guide](docs/workflow-guide.md)
- [Configuration Reference](docs/configuration.md)
- [Adapter Development](docs/adapters.md)
- [Skills vs Scripts](docs/skills-vs-scripts.md)
```

**File**: `docs/configuration.md`

Complete reference for all configuration options, with examples for each platform adapter.

**File**: `docs/workflow-guide.md`

Detailed explanation of the FABER workflow, each phase, and how they interact.

**File**: `docs/adapters.md`

Guide for adding new platform adapters:
- How adapters work (docs + scripts in skills)
- Example: adding a new issue tracker
- Example: adding a new source control system
- Testing adapters

**File**: `docs/skills-vs-scripts.md`

```markdown
# Skills vs Scripts: Context Efficiency

## The Pattern

### Agents (Decision-making)
- High-level orchestration
- Decision logic
- Call skills for work
- 100-300 lines

### Skills (Adapter selection)
- Load configuration
- Select appropriate adapter
- Call scripts for deterministic work
- 50-150 lines

### Scripts (Deterministic operations)
- Actual work (API calls, file operations, git commands)
- Only output enters context, not code
- Bash/Python scripts
- Unlimited size (doesn't matter for context)

## Why This Matters

**Without scripts** (inline bash in agents):
- Agent code enters context every invocation
- 500-1000 lines per agent × multiple invocations = massive context usage

**With scripts**:
- Agent: 200 lines (decision logic only)
- Skill: 100 lines (adapter selection)
- Script: 500 lines (doesn't enter context)
- **Only script output enters context** = massive savings

## When to Use Scripts

Use scripts for:
- ✅ API calls (GitHub, Jira, R2, S3)
- ✅ Git operations (branch, commit, push, PR)
- ✅ File operations (upload, download, list)
- ✅ Configuration parsing
- ✅ Data transformation
- ✅ Anything deterministic

Keep in agents/skills:
- ❌ Decision logic
- ❌ Conditional flows
- ❌ Adapter selection
- ❌ Error interpretation
```

## Final Plugin Structure

```
plugins/fractary-faber/
├── README.md
├── agents/
│   ├── faber-director.md              # NEW: Orchestrates 5 FABER stages
│   ├── frame-manager.md               # EXISTING (refactor to use skills)
│   ├── architect-manager.md           # EXISTING (rename Analyze → Architect, use skills)
│   ├── build-manager.md               # EXISTING (refactor to use skills)
│   ├── evaluate-manager.md            # EXISTING (refactor to use skills)
│   ├── release-manager.md             # EXISTING (refactor to use skills)
│   ├── work-manager.md                # EXISTING (refactor to use skills)
│   ├── repo-manager.md                # EXISTING (refactor to use skills)
│   ├── file-manager.md                # EXISTING (refactor to use skills)
│   └── agent-manager.md               # EXISTING (may not be relevant to FABER)
├── commands/
│   ├── faber.md                       # EXISTING (refine for freeform responses)
│   ├── faber-init.md                  # NEW
│   ├── faber-run.md                   # NEW
│   └── faber-status.md                # NEW
├── skills/
│   ├── faber-core/                    # NEW
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   ├── status-cards.md
│   │   │   ├── session-management.md
│   │   │   └── configuration.md
│   │   ├── scripts/
│   │   │   ├── config-loader.sh
│   │   │   ├── session-create.sh
│   │   │   ├── session-update.sh
│   │   │   ├── status-card-post.sh
│   │   │   └── pattern-substitute.sh
│   │   └── templates/
│   │       ├── faber-config.toml.template
│   │       └── status-card.template.md
│   ├── work-manager/                  # NEW
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   ├── github-api.md
│   │   │   ├── jira-api.md
│   │   │   └── linear-api.md
│   │   └── scripts/
│   │       ├── github/
│   │       │   ├── fetch-issue.sh
│   │       │   ├── create-comment.sh
│   │       │   ├── set-label.sh
│   │       │   └── classify-issue.sh
│   │       ├── jira/
│   │       └── linear/
│   ├── repo-manager/                  # NEW
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   ├── github-git.md
│   │   │   └── gitlab-git.md
│   │   └── scripts/
│   │       ├── github/
│   │       │   ├── generate-branch-name.sh
│   │       │   ├── create-branch.sh
│   │       │   ├── create-commit.sh
│   │       │   ├── push-branch.sh
│   │       │   ├── create-pr.sh
│   │       │   └── merge-pr.sh
│   │       └── gitlab/
│   ├── file-manager/                  # NEW
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   ├── r2-api.md
│   │   │   └── s3-api.md
│   │   └── scripts/
│   │       ├── r2/
│   │       │   ├── upload.sh
│   │       │   ├── download.sh
│   │       │   ├── delete.sh
│   │       │   ├── list.sh
│   │       │   └── get-url.sh
│   │       └── s3/
│   └── agent-builder/                 # EXISTING
│       └── SKILL.md
├── config/
│   └── faber.example.toml             # NEW
├── presets/
│   ├── software-basic.yaml            # NEW
│   ├── software-guarded.yaml          # NEW
│   └── software-autonomous.yaml       # NEW
└── docs/
    ├── configuration.md               # NEW
    ├── workflow-guide.md              # NEW
    ├── adapters.md                    # NEW
    └── skills-vs-scripts.md           # NEW
```

## Implementation Checklist

### Phase 1: Core Infrastructure
- [ ] Create `config/faber.example.toml`
- [ ] Create `skills/faber-core/SKILL.md`
- [ ] Create `skills/faber-core/scripts/config-loader.sh`
- [ ] Create `skills/faber-core/scripts/session-create.sh`
- [ ] Create `skills/faber-core/scripts/session-update.sh`
- [ ] Create `skills/faber-core/scripts/status-card-post.sh`
- [ ] Create `skills/faber-core/scripts/pattern-substitute.sh`
- [ ] Create `skills/faber-core/templates/faber-config.toml.template`
- [ ] Create `skills/faber-core/templates/status-card.template.md`
- [ ] Create `skills/faber-core/docs/status-cards.md`
- [ ] Create `skills/faber-core/docs/session-management.md`
- [ ] Create `skills/faber-core/docs/configuration.md`
- [ ] Update `agents/architect-manager.md` (Analyze → Architect)

### Phase 2: Extract Manager Logic to Skills
- [ ] Create `skills/work-manager/SKILL.md`
- [ ] Create `skills/work-manager/scripts/github/*.sh` (4 scripts)
- [ ] Create `skills/work-manager/docs/*.md` (3 docs)
- [ ] Refactor `agents/work-manager.md` to use skill
- [ ] Create `skills/repo-manager/SKILL.md`
- [ ] Create `skills/repo-manager/scripts/github/*.sh` (6 scripts)
- [ ] Create `skills/repo-manager/docs/*.md` (2 docs)
- [ ] Refactor `agents/repo-manager.md` to use skill
- [ ] Create `skills/file-manager/SKILL.md`
- [ ] Create `skills/file-manager/scripts/r2/*.sh` (5 scripts)
- [ ] Create `skills/file-manager/docs/*.md` (2 docs)
- [ ] Refactor `agents/file-manager.md` to use skill
- [ ] Refactor `agents/frame-manager.md` to use skills
- [ ] Refactor `agents/architect-manager.md` to use skills
- [ ] Refactor `agents/build-manager.md` to use skills
- [ ] Refactor `agents/evaluate-manager.md` to use skills
- [ ] Refactor `agents/release-manager.md` to use skills

### Phase 3: Director & Commands
- [ ] Create `agents/faber-director.md`
- [ ] Create `commands/faber-init.md`
- [ ] Create `commands/faber-run.md`
- [ ] Create `commands/faber-status.md`
- [ ] Refine `commands/faber.md` for freeform responses

### Phase 4: Presets & Documentation
- [ ] Create `presets/software-basic.yaml`
- [ ] Create `presets/software-guarded.yaml`
- [ ] Create `presets/software-autonomous.yaml`
- [ ] Create `README.md`
- [ ] Create `docs/configuration.md`
- [ ] Create `docs/workflow-guide.md`
- [ ] Create `docs/adapters.md`
- [ ] Create `docs/skills-vs-scripts.md`

## Testing Strategy

### Unit Testing (Per Component)
- Test each script independently with mock inputs
- Verify script outputs match expected format
- Test error handling in scripts

### Integration Testing (Skills)
- Test skill adapter selection logic
- Verify skills call correct scripts based on config
- Test error propagation from scripts to skills

### End-to-End Testing (Workflow)
- Test complete FABER workflow with mock issue
- Verify all 5 phases execute in sequence
- Test retry logic in Evaluate phase
- Test different autonomy levels
- Test error recovery

### Platform Testing
- Test GitHub adapter end-to-end
- Test with different config combinations
- Verify status cards posted correctly

## Success Criteria

The fractary-faber plugin is complete when:

1. **Functional**:
   - All 5 FABER phases execute successfully
   - Retry logic works (Build ← Evaluate loop)
   - Status cards posted to issues
   - Configuration system functional
   - All adapters (GitHub, R2) working

2. **Well-Structured**:
   - Logic properly separated (agents → skills → scripts)
   - Context-efficient (scripts don't bloat context)
   - Extensible (new adapters can be added easily)

3. **Documented**:
   - README with quick start
   - Complete configuration reference
   - Workflow guide
   - Adapter development guide

4. **Safe**:
   - Autonomy levels enforced
   - Protected paths respected
   - Confirmation gates working
   - Audit trail complete

## Future Enhancements

### Additional Adapters
- Jira work-manager adapter
- Linear work-manager adapter
- GitLab repo-manager adapter
- S3 file-manager adapter

### Additional Domains
- Design domain (design → mockup → review → publish)
- Writing domain (outline → draft → edit → publish)
- Data domain (schema → pipeline → validate → deploy)

### Advanced Features
- Parallel workflow execution (multiple issues)
- Workflow templates (customize FABER stages)
- Plugin marketplace (share custom adapters)
- Analytics dashboard (workflow metrics)

## References

- Architecture conversation: `docs/architecture/conversations/2025-10-22-cli-tool-reorganization-faber-details.md`
- Existing agents: `plugins/fractary-faber/agents/`
- DevOps plugin (reference): `plugins/fractary-devops/`
- Codex plugin (reference): `plugins/fractary-codex/`
