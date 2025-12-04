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
│     /fractary-faber:init, /fractary-faber:run, /fractary-faber:status     │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                   Orchestration                          │
│               director (Skill - Lightweight Router)      │
│    Routes requests to workflow-manager with full context │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                 Workflow Manager                         │
│              workflow-manager (Agent)                    │
│  Orchestrates all 5 phases with continuous context       │
│  Frame → Architect → Build → Evaluate → Release          │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                    Phase Skills                          │
│  frame, architect, build, evaluate, release (Skills)     │
│  Each with workflow/basic.md (batteries-included)        │
│  Domain plugins can override with workflow/{domain}.md   │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                 Primitive Managers                       │
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
- `director` - Lightweight router, parses input, routes to workflow-manager
- `workflow-manager` - Orchestrates complete FABER workflow across all 5 phases
- Phase skills (via workflow-manager):
  - `frame` - Work fetching, classification, branch creation
  - `architect` - Specification generation
  - `build` - Solution implementation
  - `evaluate` - Testing, review, GO/NO-GO decisions
  - `release` - PR creation, deployment
- Primitive managers (invoked by phase skills):
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
- Phase skills - Frame, Architect, Build, Evaluate, Release
  - Each has `SKILL.md` + `workflow/basic.md` (batteries-included)
  - Domain plugins can provide `workflow/{domain}.md` overrides
- Primitive manager skills:
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

**Before (Multi-Agent Architecture)**:
```
director loads: ~26K tokens
+ frame-manager: ~12K tokens
+ architect-manager: ~14K tokens
+ build-manager: ~14K tokens
+ evaluate-manager: ~16K tokens
+ release-manager: ~16K tokens
Total orchestration: ~98K tokens
```

**After (Single Workflow-Manager Architecture)**:
```
director loads: ~15K tokens (lightweight router)
+ workflow-manager: ~25K tokens (all 5 phases)
Total orchestration: ~40K tokens
Savings: ~60% context reduction!

Additional benefits:
- Continuous context across all phases
- Single point of orchestration logic
- Easier to maintain and debug
```

## Component Hierarchy

### Full Component Tree

```
User
  └─ /fractary-faber:* (Commands)
      ├─ /fractary-faber:init (Command)
      │   └─ Auto-detects project settings
      ├─ /fractary-faber:run (Command)
      │   └─ faber-director (Skill - Lightweight Router)
      │       └─ faber-manager (Agent - Orchestrates all 5 phases)
      │           ├─ frame (Skill)
      │           │   ├─ workflow/basic.md (batteries-included)
      │           │   ├─ work-manager (Agent via @agent mention)
      │           │   │   └─ work-manager (Skill)
      │           │   │       ├─ scripts/github/fetch-issue.sh
      │           │   │       ├─ scripts/github/classify-issue.sh
      │           │   │       └─ ...
      │           │   └─ repo-manager (Agent via @agent mention)
      │           │       └─ repo-manager (Skill)
      │           │           ├─ scripts/github/generate-branch-name.sh
      │           │           ├─ scripts/github/create-branch.sh
      │           │           └─ ...
      │           ├─ architect (Skill)
      │           │   ├─ workflow/basic.md
      │           │   ├─ repo-manager (Agent)
      │           │   └─ file-manager (Agent)
      │           ├─ build (Skill)
      │           │   ├─ workflow/basic.md
      │           │   └─ repo-manager (Agent)
      │           ├─ evaluate (Skill)
      │           │   ├─ workflow/basic.md
      │           │   └─ repo-manager (Agent)
      │           └─ release (Skill)
      │               ├─ workflow/basic.md
      │               ├─ work-manager (Agent)
      │               └─ repo-manager (Agent)
      └─ /fractary-faber:status (Command)
          └─ Reads workflow state and logs
```

### Invocation Chain Example

```
User: /fractary-faber:run --work-id 123
  ↓
/fractary-faber:run (command)
  ↓ Parses arguments, invokes
faber-director skill
  ↓ Fetches issue, detects labels, routes to
faber-manager agent
  ↓ Phase 1: Frame
workflow-manager invokes frame skill
  ↓ Reads workflow/basic.md
frame skill → Uses @agent-fractary-work:work-manager
  ↓ fetch issue
work-manager → scripts/github/fetch-issue.sh
  ↓ Returns JSON
{title: "Add auth", labels: ["feature"]}
  ↓ Back to frame skill
frame skill classifies work → feature
  ↓ Uses @agent-fractary-repo:repo-manager
repo-manager → scripts/github/create-branch.sh
  ↓ Returns
"Branch created: feat/123-add-auth"
  ↓ Back to faber-manager
faber-manager → Frame complete, proceed to Architect
  ↓ Phase 2: Architect (with full Frame context)
faber-manager invokes architect skill...
  ↓ Phase 3: Build (with Frame + Architect context)
  ↓ Phase 4: Evaluate (with all previous context)
  ↓ Phase 5: Release (with complete workflow context)
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

3. State Creation
   └─ .fractary/plugins/faber/state.json
       ├─ work_id
       ├─ metadata (source, domain, timestamps)
       ├─ current_phase
       ├─ phases (frame, architect, build, evaluate, release)
       └─ history []

4. Phase Execution
   Each phase:
   ├─ Update state (phase → started)
   ├─ Execute phase operations
   ├─ Generate outputs
   ├─ Update state (phase → completed, data)
   ├─ Create workflow log entry (fractary-logs)
   └─ Post status card

5. State Updates
   After each phase:
   ├─ .fractary/plugins/faber/state.json (current state)
   │   ├─ phases.frame.status = "completed"
   │   ├─ phases.frame.data = {work_type, branch_name}
   │   ├─ phases.architect.status = "completed"
   │   ├─ phases.architect.data = {spec_file, spec_url}
   │   └─ ...
   └─ fractary-logs workflow entry (historical audit trail)

6. Final Output
   ├─ Pull request created
   ├─ State file preserved (current workflow state)
   ├─ Workflow log preserved (complete audit trail)
   └─ Status cards posted
```

### Configuration Flow

```
1. Configuration File (.fractary/plugins/faber/config.json)
   ├─ schema_version: "2.0"
   ├─ workflows[]: Array of workflow configurations
   ├─ integrations: Plugin references (work, repo, spec, logs)
   ├─ logging: Workflow logging configuration
   └─ safety: Protected paths and confirmation rules

2. Config Loader (skills/core/scripts/config-loader.sh)
   ├─ Reads JSON file from .fractary/plugins/faber/config.json
   ├─ Validates schema version and required fields
   ├─ Expands environment variables
   └─ Returns validated JSON

3. Config Consumption
   Agents/Skills read config:
   ├─ WORKFLOW=$(echo $CONFIG | jq -r '.workflows[0]')
   ├─ WORK_PLUGIN=$(echo $CONFIG | jq -r '.integrations.work_plugin')
   └─ Use config values to make decisions

4. Platform Routing
   Skill uses config to route:
   ├─ Determine platform from primitive plugin config
   └─ "@agent-fractary-repo:repo-manager" handles routing internally
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

### Why JSON for Configuration?

**Decision**: Use JSON format for `.fractary/plugins/faber/config.json` (v2.0)

**Rationale**:
- Native processing without conversion (direct jq usage)
- Standard plugin configuration format across all Fractary plugins
- Supports complex nested structures (workflows array, phase configurations)
- Easy validation with JSON Schema
- No parsing errors from indentation or special characters
- Consistent with plugin ecosystem standards

**Evolution from v1.x**:
- v1.x used TOML (`.faber.config.toml`) for human-readability
- v2.0 switched to JSON for consistency, validation, and zero-conversion overhead
- Migration guide available at MIGRATION-v2.md

**Alternatives Considered**:
- TOML: Requires Python conversion, inconsistent with plugin ecosystem
- YAML: Indentation issues, complex spec, parsing complexity
- Custom format: Non-standard, reinventing wheel

### Why Dual-State Tracking?

**Decision**: Use both current state file and historical workflow logs (v2.0)

**Rationale**:
- **Current State** (`.fractary/plugins/faber/state.json`):
  - Single-workflow state for resume/retry
  - Lightweight, always current
  - Enables workflow continuation after interruption
- **Historical Logs** (fractary-logs plugin):
  - Complete audit trail across all workflows
  - Searchable history with timestamps
  - Compliance and debugging support
  - Parallel workflow tracking

**Benefits of Dual Approach**:
- Separation of concerns (current vs historical)
- No state file accumulation (only one current state)
- Rich historical data without state file bloat
- Integration with logging infrastructure

**Alternatives Considered**:
- Session files per workflow (v1.x): Accumulation problem, no centralized history
- In-memory only: Lost on crash
- Database: Overkill, adds dependency
- Git commits: Clutters history

See [STATE-TRACKING.md](STATE-TRACKING.md) for detailed implementation.

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

### Why Prompt Customization?

**Decision**: Support custom execution patterns in phase prompts (v2.0)

**Rationale**:
- Different teams have different workflow preferences
- Some phases benefit from guided step-by-step execution
- Flexible prompt patterns without code changes
- Supports autonomous, guided, and step-by-step execution modes

**Supported Patterns**:
- **Autonomous**: Phase executes completely without user interaction
- **Guided**: Phase executes with periodic user confirmation
- **Step-by-step**: Each operation requires explicit user approval
- **Custom**: Project-specific patterns defined in configuration

**Benefits**:
- Configurable autonomy level per phase
- No skill code changes needed
- Project-specific workflow customization
- Guardrails for production changes

See [PROMPT-CUSTOMIZATION.md](PROMPT-CUSTOMIZATION.md) for detailed implementation.

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

**Step 3: Update Repo Plugin Configuration**
```json
// .fractary/plugins/repo/config.json
{
  "platform": "gitlab",
  "gitlab": {
    "url": "${GITLAB_URL}",
    "token": "${GITLAB_TOKEN}"
  }
}
```

Note: Platform-specific configuration lives in the primitive plugin (fractary-repo), not in FABER config.

**Step 4: Test**
```bash
# Update repo plugin configuration
# Edit .fractary/plugins/repo/config.json to set platform = "gitlab"

# Run workflow - automatically uses GitLab scripts!
/fractary-faber:run --work-id 123
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
```json
// .fractary/plugins/faber/config.json
{
  "workflows": [{
    "id": "design-workflow",
    "description": "Design-focused FABER workflow"
  }]
}
```

**Step 3: Domain-Specific Workflows**
```bash
/fractary-faber:run --work-id 123 --workflow design
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
- State file: Single file, ~1-2KB (one active workflow)
- Workflow logs: ~1KB per workflow (managed by fractary-logs plugin)
- Concurrent workflows: Limited by LLM rate limits
- Repository size: No hard limit (uses git)

**Future Scaling**:
- Multi-workflow state management for parallel workflows
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

- Complete workflow history via fractary-logs plugin
- All operations logged with timestamps
- Git commits traceable to work items
- Dual-state tracking for current and historical data

## See Also

- [Configuration Guide](configuration.md) - Configure FABER
- [Workflow Guide](workflow-guide.md) - Workflow details
- [README](../README.md) - Quick start
