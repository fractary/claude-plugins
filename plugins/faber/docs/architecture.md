# FABER Architecture

This document describes the system architecture, design decisions, and implementation details of the FABER plugin.

## Table of Contents

- [System Overview](#system-overview)
- [3-Layer Architecture](#3-layer-architecture)
- [Component Hierarchy](#component-hierarchy)
- [Data Flow](#data-flow)
- [Design Decisions](#design-decisions)
- [Context Efficiency](#context-efficiency)
- [Extensibility](#extensibility)
- [Performance](#performance)

## System Overview

FABER is a **tool-agnostic SDLC workflow framework** built on a 3-layer architecture designed for context efficiency and platform extensibility.

### Core Principles

1. **Context Efficiency**: Minimize token usage through architectural separation
2. **Tool Agnostic**: Support multiple platforms without agent changes
3. **Domain Agnostic**: Support multiple work domains (engineering, design, writing, data)
4. **Composability**: Small, focused components that compose into complete workflows
5. **Resilience**: Automatic retry mechanisms and error recovery

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                        │
│  /faber (router) → /fractary-faber:init, /fractary-faber:run, /fractary-faber:status│
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                   Orchestration                          │
│              director (Agent)                      │
│   Coordinates 5 phase managers + session management      │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                  Phase Managers                          │
│  frame, architect, build, evaluate, release (Agents)     │
│             Make high-level decisions                    │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                 Generic Managers                         │
│        work-manager, repo-manager, file-manager          │
│          Decision logic + platform routing               │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                      Skills                              │
│     Platform adapter selection (GitHub, Jira, R2...)     │
│         Delegates to platform-specific scripts           │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                     Scripts                              │
│    Deterministic operations (fetch, commit, upload...)   │
│        Execute outside LLM context (not loaded)          │
└─────────────────────────────────────────────────────────┘
```

## 3-Layer Architecture

FABER uses a 3-layer architecture to achieve context efficiency:

### Layer 1: Agents (Decision Logic)

**Purpose**: High-level decision making and workflow orchestration

**Characteristics**:
- Written in markdown (prompt engineering)
- Loaded into LLM context
- Make decisions based on inputs
- Delegate deterministic operations to skills
- ~200-400 lines per agent

**Components**:
- `director` - Orchestrates complete workflow
- `frame-manager` - Frame phase decisions
- `architect-manager` - Architect phase decisions
- `build-manager` - Build phase decisions
- `evaluate-manager` - Evaluate phase decisions
- `release-manager` - Release phase decisions
- `work-manager` - Work tracking decisions
- `repo-manager` - Source control decisions
- `file-manager` - File storage decisions

**Example Decision Logic**:
```
Should I retry Build phase?
- Check retry_count < max_evaluate_retries
- Check Evaluate decision = NO-GO
- If yes: Return to Build
- If no: Fail workflow
```

### Layer 2: Skills (Adapter Selection)

**Purpose**: Platform-specific adapter selection and routing

**Characteristics**:
- Thin wrapper around scripts
- Selects correct platform adapter
- ~100-200 lines per skill
- Loaded into context only when needed

**Components**:
- `core` - Configuration, sessions, status cards
- `work-manager` - GitHub/Jira/Linear adapters
- `repo-manager` - GitHub/GitLab/Bitbucket adapters
- `file-manager` - R2/S3/local adapters

**Example Adapter Selection**:
```bash
# Load config to determine platform
FILE_SYSTEM=$(echo "$CONFIG_JSON" | jq -r '.project.file_system')

# Route to platform-specific script
"$SKILL_DIR/scripts/$FILE_SYSTEM/upload.sh" "$LOCAL_PATH" "$REMOTE_PATH"
```

### Layer 3: Scripts (Deterministic Operations)

**Purpose**: Platform-specific deterministic operations

**Characteristics**:
- Bash scripts (deterministic, testable)
- Execute outside LLM context
- Only output enters context (not script code)
- ~50-100 lines per script

**Components**:
- `scripts/github/` - GitHub operations
- `scripts/r2/` - Cloudflare R2 operations
- `scripts/local/` - Local filesystem operations
- (future: jira, linear, s3, gitlab...)

**Example Script**:
```bash
#!/bin/bash
# Upload file to R2

LOCAL_PATH="$1"
REMOTE_PATH="$2"

aws s3 cp "$LOCAL_PATH" "s3://$BUCKET/$REMOTE_PATH" \
  --endpoint-url "$R2_ENDPOINT"

echo "https://$PUBLIC_URL/$REMOTE_PATH"
```

### Context Efficiency Comparison

**Before (Traditional Approach)**:
```
Agent loads:
- Decision logic: 200 lines
- GitHub implementation: 300 lines
- Jira implementation: 300 lines (even if not used!)
- Error handling: 100 lines
- Utility functions: 100 lines
Total: 1000 lines in context
```

**After (3-Layer Architecture)**:
```
Agent loads:
- Decision logic: 200 lines
Skill loads:
- Adapter selection: 100 lines
Scripts execute:
- Platform operations: 0 lines (not loaded!)
- Only output enters context: ~10 lines
Total: 310 lines in context
Savings: 69% context reduction!
```

## Component Hierarchy

### Full Component Tree

```
User
  └─ /faber (Command - Main Router)
      ├─ /fractary-faber:init (Command)
      │   └─ Auto-detects project settings
      ├─ /fractary-faber:run (Command)
      │   └─ director (Agent)
      │       ├─ frame-manager (Agent)
      │       │   ├─ work-manager (Agent)
      │       │   │   └─ work-manager (Skill)
      │       │   │       ├─ scripts/github/fetch-issue.sh
      │       │   │       ├─ scripts/github/classify-issue.sh
      │       │   │       └─ ...
      │       │   └─ repo-manager (Agent)
      │       │       └─ repo-manager (Skill)
      │       │           ├─ scripts/github/generate-branch-name.sh
      │       │           ├─ scripts/github/create-branch.sh
      │       │           └─ ...
      │       ├─ architect-manager (Agent)
      │       │   ├─ work-manager (Agent)
      │       │   ├─ repo-manager (Agent)
      │       │   └─ file-manager (Agent)
      │       │       └─ file-manager (Skill)
      │       │           ├─ scripts/r2/upload.sh
      │       │           ├─ scripts/local/upload.sh
      │       │           └─ ...
      │       ├─ build-manager (Agent)
      │       │   ├─ repo-manager (Agent)
      │       │   └─ file-manager (Agent)
      │       ├─ evaluate-manager (Agent)
      │       │   ├─ repo-manager (Agent)
      │       │   └─ file-manager (Agent)
      │       └─ release-manager (Agent)
      │           ├─ work-manager (Agent)
      │           ├─ repo-manager (Agent)
      │           └─ file-manager (Agent)
      └─ /fractary-faber:status (Command)
          └─ Reads session files
```

### Invocation Chain Example

```
User: /faber run 123
  ↓
/faber (router)
  ↓ Routes to
/fractary-faber:run
  ↓ Parses input, generates work_id
  ↓ Invokes
director "abc12345 github 123 engineering"
  ↓ Phase 1
frame-manager "abc12345 github 123 engineering"
  ↓ Needs to fetch issue
work-manager "fetch github/123"
  ↓ Delegates to skill
work-manager skill → scripts/github/fetch-issue.sh
  ↓ Returns JSON
{title: "Add auth", labels: ["feature"]}
  ↓ Back to frame-manager
frame-manager classifies work → /feature
  ↓ Needs to create branch
repo-manager "create-branch abc12345 /feature"
  ↓ Delegates to skill
repo-manager skill → scripts/github/generate-branch-name.sh
  ↓ Returns
"feat/123-add-auth"
  ↓ Creates branch
repo-manager skill → scripts/github/create-branch.sh
  ↓ Returns
"Branch created: feat/123-add-auth"
  ↓ Back to director
director → Frame complete, proceed to Architect
  ↓ Phase 2
architect-manager ...
```

## Data Flow

### Workflow Data Flow

```
1. User Input
   └─ Issue ID: "123"

2. Command Processing
   ├─ Validate input
   ├─ Generate work_id: "abc12345"
   └─ Load configuration

3. Session Creation
   └─ .faber/sessions/abc12345.json
       ├─ work_id
       ├─ metadata (source, domain, timestamps)
       ├─ stages (frame, architect, build, evaluate, release)
       └─ history []

4. Phase Execution
   Each phase:
   ├─ Update session (stage → started)
   ├─ Execute phase operations
   ├─ Generate outputs
   ├─ Update session (stage → completed, data)
   └─ Post status card

5. Session Updates
   After each phase:
   └─ .faber/sessions/abc12345.json
       ├─ stages.frame.status = "completed"
       ├─ stages.frame.data = {work_type, branch_name}
       ├─ stages.architect.status = "completed"
       ├─ stages.architect.data = {spec_file, spec_url}
       └─ ...

6. Final Output
   ├─ Pull request created
   ├─ Session file preserved
   └─ Status cards posted
```

### Configuration Flow

```
1. Configuration File (.faber.config.toml)
   ├─ [project] metadata
   ├─ [defaults] settings
   ├─ [workflow] behavior
   └─ [systems.*] platform configs

2. Config Loader (skills/core/scripts/config-loader.sh)
   ├─ Reads TOML file
   ├─ Converts to JSON (Python)
   ├─ Validates required fields
   └─ Returns JSON

3. Config Consumption
   Agents/Skills read config:
   ├─ PROJECT=$(echo $CONFIG | jq -r '.project.name')
   ├─ ISSUE_SYS=$(echo $CONFIG | jq -r '.project.issue_system')
   └─ Use config values to make decisions

4. Platform Routing
   Skill uses config to route:
   ├─ FILE_SYSTEM=$(echo $CONFIG | jq -r '.project.file_system')
   └─ "$SKILL_DIR/scripts/$FILE_SYSTEM/upload.sh"
```

### Session State Flow

```
Session State Machine:

pending → started → in_progress → completed
   ↓                                  ↑
   └─────────→ failed ←───────────────┘

Phase Transitions:
1. frame: pending → started → completed
2. architect: pending → started → completed
3. build: pending → started → completed → (retry) → started → completed
4. evaluate: pending → started → in_progress → completed
   └─ If NO-GO: in_progress (stays until GO or max retries)
5. release: pending → started → completed
```

## Design Decisions

### Why Bash Scripts?

**Decision**: Use Bash scripts for Layer 3 (deterministic operations)

**Rationale**:
- Native to Linux/macOS (no installation needed)
- Easy to test independently (`bash script.sh` to run)
- Simple debugging (add `set -x` to trace)
- Execute outside LLM context (zero token cost)
- Familiar to DevOps engineers

**Alternatives Considered**:
- Python: More deps, harder to test in isolation
- Node.js: Requires npm, async complexity
- Inline bash in agents: Context explosion

### Why TOML for Configuration?

**Decision**: Use TOML format for `.faber.config.toml`

**Rationale**:
- Human-readable and editable
- Supports comments (unlike JSON)
- Standard for project config (like Cargo.toml, pyproject.toml)
- Easy conversion to JSON for processing

**Alternatives Considered**:
- JSON: No comments, less readable
- YAML: Indentation issues, complex spec
- Custom format: Non-standard, reinventing wheel

### Why Session Files?

**Decision**: Store workflow state in JSON session files

**Rationale**:
- Persistent across phases
- Debuggable (just read the JSON file)
- Resumable (can continue after failure)
- Audit trail for compliance
- No database needed

**Alternatives Considered**:
- In-memory only: Lost on crash
- Database: Overkill, adds dependency
- Git commits: Clutters history

### Why 3 Layers?

**Decision**: Separate Agents → Skills → Scripts

**Rationale**:
- **Context Efficiency**: 55-69% reduction
- **Platform Extensibility**: Add platforms without agent changes
- **Testability**: Test scripts independently
- **Maintainability**: Clear separation of concerns

**Alternatives Considered**:
- 2 layers (Agents → Scripts): No platform routing layer
- 1 layer (Monolithic agents): Context explosion
- 4+ layers: Over-engineered, too complex

### Why Retry Loop?

**Decision**: Automatic Evaluate → Build retry loop

**Rationale**:
- Tests may fail due to transient issues
- LLM can fix simple errors autonomously
- Reduces manual intervention
- Configurable limit prevents infinite loops

**Alternatives Considered**:
- No retries: Fail immediately (too brittle)
- Unlimited retries: Risk infinite loop
- Manual retry only: More user intervention

## Context Efficiency

### Token Usage Analysis

**Traditional Monolithic Approach**:
```
work-manager agent (monolithic):
- Decision logic: 200 lines
- GitHub fetch code: 100 lines
- GitHub classify code: 80 lines
- Jira fetch code: 100 lines (not used!)
- Jira classify code: 80 lines (not used!)
- Linear fetch code: 100 lines (not used!)
- Error handling: 80 lines
- Utilities: 60 lines
Total: 800 lines in context per invocation
```

**3-Layer Approach**:
```
work-manager agent:
- Decision logic: 200 lines

work-manager skill:
- Adapter selection: 80 lines
- Platform routing: 20 lines

Scripts (NOT in context):
- github/fetch-issue.sh: 50 lines (not loaded)
- github/classify-issue.sh: 40 lines (not loaded)
- Only script OUTPUT in context: ~10 lines

Total: 310 lines in context
Savings: 61% reduction
```

### Context Reduction by Component

| Component | Before | After | Savings |
|-----------|--------|-------|---------|
| work-manager | 800 | 310 | 61% |
| repo-manager | 900 | 350 | 61% |
| file-manager | 700 | 280 | 60% |
| **Average** | **800** | **313** | **61%** |

### Cumulative Impact

For a complete workflow (5 phases, multiple manager invocations):

```
Traditional approach:
- 15 manager invocations × 800 lines = 12,000 lines

3-layer approach:
- 15 manager invocations × 313 lines = 4,695 lines

Total workflow savings: 61% (7,305 lines)
```

## Extensibility

### Adding a New Platform

To add support for a new platform (e.g., GitLab):

**Step 1: Create Scripts** (Layer 3)
```bash
mkdir -p skills/repo-manager/scripts/gitlab/
# Create: generate-branch-name.sh, create-branch.sh, etc.
```

**Step 2: Update Skill** (Layer 2)
```bash
# skills/repo-manager/SKILL.md
# Add GitLab to supported platforms list
# No code changes needed - routing is automatic!
```

**Step 3: Add Configuration** (Config)
```toml
# config/faber.example.toml
[project]
repo_system = "gitlab"  # New option

[systems.repo_config]
gitlab_url = "https://gitlab.com"
gitlab_token = "${GITLAB_TOKEN}"
```

**Step 4: Test**
```bash
# Set config
repo_system = "gitlab"

# Run workflow - automatically uses GitLab scripts!
/faber run 123
```

**No agent changes required!** The skill layer automatically routes to the correct platform.

### Adding a New Domain

To add support for a new domain (e.g., Design):

**Step 1: Create Domain Bundle** (Future)
```bash
mkdir -p domains/design/
# Create domain-specific managers
```

**Step 2: Update Configuration**
```toml
[defaults]
work_domain = "design"
```

**Step 3: Domain-Specific Workflows**
```bash
/faber run 123 --domain design
# Uses design-specific Build and Evaluate logic
```

## Performance

### Workflow Execution Time

Typical workflow (engineering domain, medium complexity):

```
Phase 1: Frame        ~1-2 minutes
Phase 2: Architect    ~2-5 minutes
Phase 3: Build        ~5-15 minutes
Phase 4: Evaluate     ~2-5 minutes (×retries)
Phase 5: Release      ~1-2 minutes
Total:                ~11-29 minutes
```

### Optimization Opportunities

1. **Parallel Phase Execution** (future)
   - Some phases could run in parallel
   - E.g., Architect + Environment setup

2. **Caching** (future)
   - Cache codebase analysis
   - Cache test results

3. **Incremental Operations** (future)
   - Only test changed files
   - Only analyze modified code

### Scalability

**Current Limits**:
- Session files: ~1KB each (1M sessions = 1GB)
- Concurrent workflows: Limited by LLM rate limits
- Repository size: No hard limit (uses git)

**Future Scaling**:
- Session database for large teams
- Distributed execution for parallel workflows
- Caching layer for codebase analysis

## Security Considerations

### Credential Management

- Never commit secrets to config files
- Use environment variables for tokens
- Support for secrets managers (future)

### Protected Paths

- Configurable list of protected files
- Prevents accidental modification
- Includes .git/, credentials, etc.

### Audit Trail

- Complete session history
- All operations logged
- Git commits traceable to work items

## See Also

- [Configuration Guide](configuration.md) - Configure FABER
- [Workflow Guide](workflow-guide.md) - Workflow details
- [README](../README.md) - Quick start
