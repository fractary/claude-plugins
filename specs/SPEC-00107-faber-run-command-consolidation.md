# FABER Run Command Consolidation

**Specification ID:** SPEC-00107
**Version:** 1.0.0
**Status:** Draft
**Created:** 2025-12-04
**Author:** System Architecture
**Related Specs:** SPEC-00002 (FABER Architecture), SPEC-00015 (FABER Agent Plugin)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Solution Overview](#solution-overview)
4. [Command Specification](#command-specification)
5. [Target Resolution](#target-resolution)
6. [Step Identification](#step-identification)
7. [Label-Based Configuration](#label-based-configuration)
8. [Custom Instructions](#custom-instructions)
9. [Implementation Requirements](#implementation-requirements)
10. [Backwards Compatibility](#backwards-compatibility)
11. [Examples & Patterns](#examples--patterns)

---

## Executive Summary

### Purpose

Consolidate 7 FABER command entry points into a single, flexible `/fractary-faber:run` command that:

1. **Prioritizes artifacts over work items** - Primary use case is specifying *what* to work on (dataset, blog post, module), with optional work-id context
2. **Enables granular phase control** - `--phase` accepts comma-separated phases instead of separate phase commands
3. **Supports step-level execution** - `--step` allows targeting specific workflow steps for precision control
4. **Detects configuration from issue labels** - Automatically applies `faber:*` labels to set workflow, autonomy, phases, etc.
5. **Accepts custom instructions** - `--prompt` argument guides workflow with additional context
6. **Supports freeform natural language** - Director skill parses intent from natural language requests

### Commands Being Consolidated

| Deprecated | Replaced By |
|-----------|------------|
| `/fractary-faber:direct 158` | `/fractary-faber:run --work-id 158` |
| `/fractary-faber:faber run 158` | `/fractary-faber:run --work-id 158` |
| `/fractary-faber:frame 158` | `/fractary-faber:run --work-id 158 --phase frame` |
| `/fractary-faber:architect 158` | `/fractary-faber:run --work-id 158 --phase frame,architect` |
| `/fractary-faber:build 158` | `/fractary-faber:run --work-id 158 --phase build` |
| `/fractary-faber:evaluate 158` | `/fractary-faber:run --work-id 158 --phase evaluate` |
| `/fractary-faber:release 158` | `/fractary-faber:run --work-id 158 --phase release` |

### Strategic Value

1. **Reduced Maintenance**: Single command to maintain instead of 8
2. **Clearer Mental Model**: Artifacts first, work-ids provide context
3. **Flexible Workflow Control**: Phase selection via arguments instead of separate commands
4. **Configuration as Labels**: Reduces CLI argument verbosity via issue labels
5. **Natural Language Support**: Accept freeform text, not just structured IDs

---

## Problem Statement

### Current State Issues

1. **Command Explosion**: 8 separate commands for slightly different workflows
   - Each command duplicates argument parsing logic
   - Hard to keep consistent across updates
   - Users must learn multiple command names

2. **Work-ID First Design**: `/faber:direct 158` makes it seem work-items are primary
   - Reality: Many users work on artifacts without issue tracking
   - Violates "default use case" principle

3. **Phase Commands are Rigid**: Can't easily skip phases or execute single steps
   - No way to do: `frame → architect → (skip build) → evaluate`
   - No way to execute just the `implement` step in build phase

4. **No Configuration Inheritance**: Every invocation requires CLI arguments
   - `--autonomy`, `--workflow` specified repeatedly
   - Issue labels ignored for configuration

5. **No Freeform Support**: Router command (`/faber`) exists but unused
   - Users who think in natural language have no way to express it
   - "Just implement the dashboard" requires parsing

---

## Solution Overview

### Single Entry Point

```bash
/fractary-faber:run <target> [options]
```

**Arguments:**
- `<target>` (optional): The thing to work on (artifact name, blog post, dataset, or natural language request)

**Options:**
- `--work-id <id>`: Link to issue for context and configuration
- `--workflow <id>`: Override workflow selection
- `--autonomy <level>`: Override autonomy level
- `--phase <phases>`: Comma-separated phases to execute (no spaces)
- `--step <step-id>`: Execute specific step (format: `phase:step-name`)
- `--prompt "<text>"`: Additional custom instructions

### Design Principles

1. **Target-First**: Artifact/request is primary argument, not work-id
2. **Optional Tracking**: Work-id enriches with context but isn't required
3. **Configuration Stacking**: CLI args > labels > config defaults
4. **Explicit Phases**: No auto-inclusion of prerequisites (frame must be explicit)
5. **Label Extensibility**: Pattern `faber:<key>=<value>` supports future arguments

---

## Command Specification

### Syntax

```bash
/fractary-faber:run <target> [options]
```

### Arguments

| Argument | Type | Required | Description |
|----------|------|----------|-------------|
| `<target>` | string | No | The thing to work on: artifact name, blog post title, dataset name, code module, or freeform natural language. If omitted, requires `--work-id` and target is inferred from issue. |

### Options

| Option | Type | Default | Values | Description |
|--------|------|---------|--------|-------------|
| `--work-id` | string | - | GitHub #, Jira ID, Linear ID | Work item ID. Triggers issue fetch and label detection. |
| `--workflow` | string | `default` | Configured workflow IDs | Which workflow to execute. Can be detected from labels. |
| `--autonomy` | string | `guarded` | `dry-run`, `assist`, `guarded`, `autonomous` | Autonomy level. Can be detected from labels. |
| `--phase` | string | all phases | Comma-separated phase names | Phases to execute (e.g., `frame,architect,build`). No spaces. |
| `--step` | string | - | `phase:step-name` | Execute single step (e.g., `build:implement`). Mutually exclusive with `--phase`. |
| `--prompt` | string | - | Any text | Additional instructions for workflow. Can also be in issue body as fenced block. |

---

## Target Resolution

### Definition

The `<target>` argument specifies **what** to work on. This is intentionally flexible:

- **Artifact identifier**: Dataset name, blog post title, module name, feature name
- **Natural language request**: "Build the authentication module", "Design the data pipeline"
- **Omitted**: Target inferred from issue title/description when `--work-id` provided

### Resolution Priority

1. **Explicit target**: If provided, use as-is (may be parsed for natural language intent)
2. **Freeform parsing**: If target contains natural language, director skill extracts:
   - Artifact name
   - Work item references (issue numbers)
   - Phase intent (keywords like "architect", "build", "test")
   - Instructions
3. **Issue inference**: If no target but `--work-id` provided, use issue title as target

### Examples

```bash
# Artifact-first use case
/fractary-faber:run customer-analytics-v2 --work-id 158

# Freeform natural language
/fractary-faber:run "implement the authentication feature from issue 158"

# Simple dataset (no issue tracking)
/fractary-faber:run customer-pipeline

# Blog post with workflow override
/fractary-faber:run "2024-12-product-launch" --workflow content

# Work-id only (target inferred from issue)
/fractary-faber:run --work-id 158
```

### Freeform Parsing Examples

When `<target>` is natural language, director extracts intent:

| Input | Extracted |
|-------|-----------|
| `"implement the auth feature from issue 158"` | target=auth feature, work_id=158, intent=build |
| `"just design the data pipeline"` | target=data pipeline, intent=architect |
| `"test the changes for issue 200"` | work_id=200, intent=evaluate |
| `"create and release the dashboard"` | target=dashboard, intent=build,evaluate,release |

---

## Step Identification

### Step ID Format

Steps are uniquely identified in the format:

```
<phase>:<step-name>
```

Where:
- `<phase>`: One of `frame`, `architect`, `build`, `evaluate`, `release`
- `<step-name>`: Step name from workflow configuration (e.g., `implement`, `commit`, `test`)

### Examples

From `plugins/faber/config/workflows/default.json`:

**Frame phase:**
- `frame:fetch-work`
- `frame:classify`
- `frame:setup-env`

**Architect phase:**
- `architect:generate-spec`

**Build phase:**
- `build:implement`
- `build:commit`

**Evaluate phase:**
- `evaluate:test`
- `evaluate:review`
- `evaluate:fix`

**Release phase:**
- `release:update-project-docs`
- `release:create-pr`

### Workflow Configuration Integration

Workflow configs define steps with `name` property. This becomes the step ID suffix:

```json
{
  "phases": {
    "build": {
      "steps": [
        { "name": "implement", "description": "..." },
        { "name": "commit", "description": "..." }
      ]
    }
  }
}
```

Step IDs: `build:implement`, `build:commit`

### Logging Integration

Step IDs are captured in workflow logs for traceability:

```json
{
  "type": "workflow",
  "work_id": "158",
  "phase": "build",
  "step": "implement",
  "step_id": "build:implement",
  "status": "completed",
  "duration_ms": 45000,
  "timestamp": "2025-12-04T14:30:00Z"
}
```

---

## Phase Selection

### `--phase` Argument

Accepts comma-separated phase names (no spaces between phases):

```bash
# Single phase
/fractary-faber:run target --phase frame

# Multiple phases
/fractary-faber:run target --phase frame,architect

# Non-sequential phases (assume prior phases complete)
/fractary-faber:run target --phase build,evaluate,release
```

### Phase Dependencies & Validation

**Important**: Specifying phases does NOT auto-include prerequisites.

| Specified | Executes | Note |
|-----------|----------|------|
| `--phase architect` | Architect only | Assumes frame already complete |
| `--phase frame,architect` | Frame, then Architect | Explicit chain |
| `--phase evaluate` | Evaluate only | Assumes frame, architect, build complete |
| `--phase build,release` | Build, then Release | Evaluate is skipped |

The director skill **validates** that prerequisite phases are complete before proceeding. If a prerequisite is missing:

```
Error: Cannot proceed with build phase
Reason: Architect phase not complete
Solution: Run with --phase frame,architect,build
```

### `--phase` vs `--step`

| Argument | Scope | Example |
|----------|-------|---------|
| `--phase build` | All steps in phase | Runs `implement` + `commit` |
| `--step build:implement` | Single step | Runs only `implement`, skips `commit` |

---

## Label-Based Configuration

### Motivation

When `--work-id` is provided, issue labels provide default configuration values. This reduces CLI verbosity:

**Without labels:**
```bash
/fractary-faber:run target --work-id 158 --workflow hotfix --autonomy autonomous --phase frame,architect
```

**With labels** (`faber:workflow=hotfix`, `faber:autonomy=autonomous`, `faber:phase=frame,architect`):
```bash
/fractary-faber:run target --work-id 158
```

### Label Format

Pattern: `faber:<argument>=<value>`

### Supported Labels

| Label | Argument | Example | Values |
|-------|----------|---------|--------|
| `faber:workflow=<id>` | `--workflow` | `faber:workflow=hotfix` | Configured workflow IDs |
| `faber:autonomy=<level>` | `--autonomy` | `faber:autonomy=autonomous` | `dry-run`, `assist`, `guarded`, `autonomous` |
| `faber:phase=<phases>` | `--phase` | `faber:phase=frame,architect` | Comma-separated phase names |
| `faber:step=<step-id>` | `--step` | `faber:step=build:implement` | `phase:step-name` format |
| `faber:target=<name>` | `<target>` | `faber:target=customer-pipeline` | Any artifact identifier |
| `faber:skip-phase=<phase>` | (exclusion) | `faber:skip-phase=evaluate` | Phase name to skip |

### Extensible Pattern

The `faber:<key>=<value>` pattern is extensible. Future arguments can be configured via labels without spec changes:

```
faber:prompt=<text>
faber:custom-arg=<value>
```

### Legacy Label Support

For backwards compatibility, also recognize:
- `workflow:<id>` → maps to `faber:workflow=<id>`
- `autonomy:<level>` → maps to `faber:autonomy=<level>`

### Priority Order

When multiple sources provide the same configuration, apply in order (highest wins):

1. **CLI argument** (e.g., `--workflow hotfix`) - Highest priority
2. **Issue label** (`faber:workflow=hotfix`)
3. **Legacy label** (`workflow:hotfix`)
4. **Workflow config default** (from `.fractary/plugins/faber/config.json`)
5. **Hardcoded fallback** (e.g., `guarded` for autonomy) - Lowest priority

### Example

Issue #158 has labels:
- `faber:workflow=hotfix`
- `faber:autonomy=guarded`
- `faber:phase=frame,architect`

**Scenario 1: Use labels**
```bash
/fractary-faber:run target --work-id 158
# Result: workflow=hotfix, autonomy=guarded, phase=frame,architect
```

**Scenario 2: Override workflow**
```bash
/fractary-faber:run target --work-id 158 --workflow default
# Result: workflow=default (CLI wins), autonomy=guarded, phase=frame,architect
```

**Scenario 3: Override multiple**
```bash
/fractary-faber:run target --work-id 158 --autonomy autonomous --phase build,evaluate
# Result: workflow=hotfix (from label), autonomy=autonomous (CLI), phase=build,evaluate (CLI)
```

---

## Custom Instructions

### `--prompt` Argument

Allows embedding additional instructions to guide the workflow:

```bash
/fractary-faber:run dataset-pipeline --work-id 200 \
  --prompt "Focus on data validation first. Use Pydantic for schema validation."
```

### How Prompts Are Used

1. Passed to faber-manager agent
2. Appended to workflow context (not replacing existing context)
3. Available to all phase skills as `additional_instructions`
4. Logged in workflow session for audit trail

### Prompt Sources (Priority Order)

When multiple prompt sources exist:

1. **`--prompt` CLI argument** (highest priority)
2. **`faber-prompt` code block in issue body**
3. **No additional instructions** (lowest priority)

CLI argument wins if both CLI and issue body prompts exist.

### Fenced Block in Issue Body

If `--prompt` not provided but `--work-id` is, director checks for `faber-prompt` code block:

```markdown
## Implementation Notes

```faber-prompt
Focus on performance optimization.
Use caching where appropriate.
Skip visualization steps for now.
```
```

### Examples

```bash
# Simple prompt
/fractary-faber:run api-refactor --work-id 300 \
  --prompt "This is a breaking change. Update all dependent services."

# Multi-line prompt
/fractary-faber:run data-model --work-id 301 \
  --prompt "Use PostgreSQL for new tables. Consider GraphQL schema design patterns. Add indexes on high-cardinality columns."

# With phase selection
/fractary-faber:run dashboard --work-id 302 \
  --phase architect \
  --prompt "Design for mobile-first responsive layout. Include accessibility (WCAG 2.1 AA) from the start."
```

---

## Implementation Requirements

### 1. Create New Command: `commands/run.md`

- Parse `<target>` argument (optional)
- Parse all options
- Validate `--phase` doesn't contain spaces
- Validate `--step` format (`phase:step-name`)
- Immediately invoke `faber-director` skill
- Pass all context to director

### 2. Update Skill: `skills/faber-director/SKILL.md`

**New responsibilities:**

1. **Parse target**: Determine if artifact ID, work ID, or freeform text
2. **Fetch issue** (if `--work-id`): Get details + all comments
3. **Extract labels**: Check for `faber:*` labels
4. **Detect arguments from labels**: Apply label values (respecting priority)
5. **Validate phases**: Ensure prerequisites are specified or complete
6. **Resolve step**: If `--step` provided, identify step in workflow config
7. **Inject prompt**: Add `--prompt` or `faber-prompt` block to context
8. **Spawn manager(s)**: Invoke `faber-manager` with complete context

**New inputs:**
- `target` (string, optional)
- `workflow_override` (string, optional)
- `autonomy_override` (string, optional)
- `phases` (string, optional) - comma-separated
- `step_id` (string, optional)
- `prompt` (string, optional)

**New outputs:**
- All label-detected values merged with CLI overrides
- Resolved step ID (if specified)
- Validated phase list

### 3. Update Skill: `skills/faber-manager/SKILL.md`

**Changes:**

1. Accept `phases` list (instead of inferring from state)
2. Accept `step_id` (execute single step if specified)
3. Accept `additional_instructions` (prompt)
4. Skip phases not in provided list
5. Skip steps after `step_id` if specified

### 4. Update Workflow Config Schema

Include step IDs in logging:

```json
{
  "type": "workflow",
  "work_id": "158",
  "phase": "build",
  "step": "implement",
  "step_id": "build:implement",
  "status": "completed",
  "duration_ms": 45000,
  "timestamp": "2025-12-04T14:30:00Z"
}
```

### 5. Deprecate Old Commands

Create deprecation wrappers that:
1. Show migration notice with equivalent new command
2. Execute the requested operation (backward compatible)
3. Will be removed in future major version

**Commands to deprecate:**
- `commands/faber-direct.md`
- `commands/faber.md` (remove, don't deprecate)
- `commands/frame.md`
- `commands/architect.md`
- `commands/build.md`
- `commands/evaluate.md`
- `commands/release.md`

---

## Backwards Compatibility

### Deprecated Commands

All old commands continue to work with deprecation warnings:

```
⚠️  Deprecation Notice
This command is deprecated. Use:
  /fractary-faber:run --work-id 158 --phase frame
```

### Timeline

1. **This release**: New `/fractary-faber:run` available alongside old commands
2. **Next major version**: Consider deprecation warnings
3. **Future major version**: Remove deprecated commands

### Breaking Change Mitigation

Users relying on old commands:
- Still work during transition period
- Clear migration path provided
- New command is more flexible and powerful

---

## Examples & Patterns

### Basic Usage Patterns

```bash
# Artifact-first approach (no issue tracking)
/fractary-faber:run customer-analytics-v2

# Artifact with issue context
/fractary-faber:run customer-analytics-v2 --work-id 158

# Work-id only (target inferred from issue)
/fractary-faber:run --work-id 158

# Natural language request
/fractary-faber:run "build the dashboard component for issue 200"

# Freeform with custom instructions
/fractary-faber:run data-pipeline --work-id 300 \
  --prompt "Optimize for 100M+ rows. Use batch processing."
```

### Phase Control Patterns

```bash
# Design phase only
/fractary-faber:run target --work-id 158 --phase frame,architect

# Implementation (assumes design done)
/fractary-faber:run target --work-id 158 --phase build

# Testing only
/fractary-faber:run target --work-id 158 --phase evaluate

# Skip evaluation (build → release)
/fractary-faber:run target --work-id 158 --phase build,release
```

### Step-Level Patterns

```bash
# Execute single step
/fractary-faber:run target --work-id 158 --step build:implement

# Debug specific step
/fractary-faber:run target --work-id 158 --step evaluate:test --autonomy dry-run

# Resume from step
/fractary-faber:run target --work-id 158 --step build:commit
```

### Configuration Patterns

**Pattern 1: Labels handle everything**
```
Issue #158 has labels:
- faber:workflow=hotfix
- faber:autonomy=autonomous
- faber:phase=frame,architect,build

Command:
/fractary-faber:run target --work-id 158
```

**Pattern 2: Mix labels and CLI overrides**
```
Issue #158 labels: faber:workflow=hotfix, faber:autonomy=guarded

Command:
/fractary-faber:run target --work-id 158 --autonomy autonomous
# Result: workflow=hotfix (from label), autonomy=autonomous (CLI)
```

**Pattern 3: No labels, full CLI control**
```
Command:
/fractary-faber:run target --work-id 158 --workflow default --autonomy guarded --phase frame,architect
```

### Real-World Examples

```bash
# Data pipeline (artifact-first)
/fractary-faber:run customer-analytics-etl --work-id 200

# Design approval before building
/fractary-faber:run api-redesign --work-id 201 --phase frame,architect --autonomy assist

# Quick test of implementation
/fractary-faber:run bugfix --work-id 202 --step evaluate:test --autonomy dry-run

# Content publishing workflow
/fractary-faber:run "2024-12-product-launch" --workflow content --autonomy autonomous

# Complex feature with instructions
/fractary-faber:run authentication-v2 --work-id 203 \
  --prompt "This changes the auth flow. Update all OAuth clients. Add migration guide."

# Resume from step
/fractary-faber:run feature --work-id 204 --step build:commit
```

---

## Open Questions & Decisions

| Question | Decision | Rationale |
|----------|----------|-----------|
| Phase prerequisites auto-include? | No, explicit only | More predictable, easier to debug |
| Step terminology | "step" (not task/action/operation) | Already used in workflow configs |
| Target precedence over work-id? | Target wins | Work-id is context enrichment only |
| Prompt source priority | CLI > issue body | CLI is explicit intent |
| Multiple work-ids | Not supported | Director spawns one manager per work-id |
| Phase order validation | Director validates | Prevents invalid phase sequences |

---

## Migration Path

### For Users

1. Learn new command: `run` replaces all phase commands
2. Use labels to reduce CLI verbosity: `faber:workflow=`, `faber:autonomy=`
3. Optional: Try freeform syntax for natural language requests

### For Developers

1. Implement new command: `commands/run.md`
2. Update director skill with new parsing logic
3. Create deprecation wrappers for old commands
4. Update documentation and examples
5. Add integration tests for label detection and phase validation

---

## References

- SPEC-00002: FABER Architecture
- SPEC-00015: FABER Agent Plugin Specification
- Workflow Configuration: `plugins/faber/config/workflows/default.json`
- Director Skill: `plugins/faber/skills/faber-director/SKILL.md`
