# Fractary Plugin Development Standards

**Version:** 1.0.0
**Last Updated:** 2025-11-05
**Purpose:** Universal patterns and best practices for all Fractary Claude Code plugins

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Patterns](#architecture-patterns)
3. [Manager Pattern](#manager-pattern)
4. [Skill Pattern](#skill-pattern)
5. [Handler Pattern](#handler-pattern)
6. [Command Pattern](#command-pattern)
7. [Configuration Pattern](#configuration-pattern)
8. [Hook Pattern](#hook-pattern)
9. [Documentation Standards](#documentation-standards)
10. [XML Markup Standards](#xml-markup-standards)
11. [Example: DevOps Plugin](#example-devops-plugin)
12. [Checklist for New Plugins](#checklist-for-new-plugins)
13. [Development Tools](#development-tools)
14. [Best Practices Summary](#best-practices-summary)

---

## Overview

Fractary plugins follow consistent architectural patterns to ensure:
- **Predictability**: Similar structure across all plugins
- **Maintainability**: Clear separation of concerns
- **Reusability**: Patterns transfer across domains
- **Quality**: Consistent standards and best practices

### Core Principles

1. **Workflow-Oriented**: Managers own complete domain workflows
2. **Single-Purpose Skills**: Each skill performs one focused task
3. **Provider Abstraction**: Handler skills centralize provider-specific logic
4. **Configuration-Driven**: Behavior determined by configuration
5. **Documentation-First**: Work and documentation happen atomically
6. **Defense in Depth**: Critical rules enforced at multiple levels

---

## Architecture Patterns

### Three-Layer Architecture

```
Layer 1: Entry Points (Commands, Director)
           ↓
Layer 2: Workflow Orchestrators (Managers)
           ↓
Layer 3: Execution Units (Skills)
           ↓
Layer 4: Provider Adapters (Handler Skills - optional)
```

### Component Responsibilities

**Commands:**
- Lightweight entry points
- Parse arguments
- **Immediately invoke agents**
- NEVER do work directly

**Director:**
- Natural language router
- Determine intent
- Route to appropriate manager
- NEVER invoke skills directly
- NEVER do work directly

**Managers:**
- Own complete domain workflows
- Coordinate skill invocations
- Handle skill results
- Manage workflow state
- NEVER do work directly (delegate to skills)

**Skills:**
- Perform focused tasks
- Execute actual work
- Document their work
- Return results to manager

**Handler Skills** (if multi-provider):
- Centralize provider-specific logic
- Abstract provider differences
- Invoked by execution skills

---

## Manager Pattern

### When to Use

Create a manager for each **complete domain workflow**.

**Examples:**
- `infra-manager`: Infrastructure lifecycle (design → deploy)
- `ops-manager`: Runtime operations (monitor → remediate)
- `content-manager`: Content lifecycle (draft → publish)
- `campaign-manager`: Marketing campaigns (plan → launch)

### Manager Structure

```yaml
---
name: domain-manager
description: |
  [Primary responsibility] - [key workflows]

  This agent MUST be triggered for: [trigger keywords]

  Examples:

  <example>
  user: "[Natural language trigger]"
  assistant: "I'll use the domain-manager agent to [action]."
  <commentary>
  [What happens behind the scenes]
  </commentary>
  </example>

  <example>
  [More examples]
  </example>
tools: Bash, SlashCommand
---
```

### Manager File Structure

```markdown
# Manager Name

<CRITICAL_RULES>
**IMPORTANT:** Rules that must never be violated
- Rule 1
- Rule 2

**IMPORTANT:** YOU MUST NEVER do work yourself
- Always delegate to skills
- If no skill exists: stop and inform user
- Never read files or execute commands directly
</CRITICAL_RULES>

<CRITICAL_PRODUCTION_RULES>
**IMPORTANT:** Production safety rules
- Never operate on production without explicit request
- Always require confirmation for production
- Default to test/dev environment
</CRITICAL_PRODUCTION_RULES>

<WORKFLOW>
Parse command and delegate to appropriate skill:

Command: [command-name]
Skills to invoke: [skill-list]
Workflow: [step-by-step]
</WORKFLOW>

<SKILL_ROUTING>
<COMMAND_1>
Trigger: [keywords]
Skills: [skill-names]
Workflow: [steps]
</COMMAND_1>

<COMMAND_2>
Trigger: [keywords]
Skills: [skill-names]
Workflow: [steps]
</COMMAND_2>
</SKILL_ROUTING>

<UNKNOWN_OPERATION>
If command does not match any known operation:
1. Stop immediately
2. Inform user: "Unknown operation. Available: [list]"
3. Do NOT attempt to perform operation yourself
</UNKNOWN_OPERATION>

<SKILL_FAILURE>
If skill fails:
1. Report exact error to user
2. Do NOT attempt to solve problem yourself
3. Ask user how to proceed
</SKILL_FAILURE>
```

---

## Skill Pattern

### When to Use

Create a skill for each **focused execution task** within a workflow.

**Examples:**
- `infra-architect`: Design infrastructure (one step)
- `infra-deployer`: Execute deployment (one step)
- `content-writer`: Write content (one step)
- `campaign-analyzer`: Analyze campaign performance (one step)

### Skill Description (1024 char limit)

```yaml
description: |
  [Primary action verb] - [key operations with distinct keywords]
  [Expanded description including outcomes and what makes this skill unique]
  [Include trigger keywords that distinguish from other skills]
```

**Example:**
```yaml
description: |
  Execute infrastructure deployments - authenticate cloud providers, apply
  terraform/pulumi changes, verify deployed resources, update registries,
  generate AWS Console links. Handles permission errors by delegating to
  permission-manager, implements production safety with mandatory confirmations,
  enforces AWS profile separation, maintains complete deployment history.
```

### Standard Skill Structure

```markdown
---
name: skill-name
description: |
  [Action-oriented description with keywords, up to 1024 chars]
tools: [Only required tools]
---

# Skill Name

<CONTEXT>
You are [role]. Your responsibility is [primary function].
</CONTEXT>

<CRITICAL_RULES>
**IMPORTANT:** Rules that must never be violated
- Rule 1
- Rule 2
</CRITICAL_RULES>

<INPUTS>
What this skill receives:
- input_1: Description
- input_2: Description
- config: Configuration from .fractary/plugins/{plugin}/config/
</INPUTS>

<WORKFLOW>
**OUTPUT START MESSAGE:**
```
🎯 STARTING: [Skill Name]
[Key parameters]
───────────────────────────────────────
```

**EXECUTE STEPS:**
1. Read: workflow/step-1.md
   └─ Output: "✓ Step 1 complete: [result]"
2. Read: workflow/step-2.md
   └─ Output: "✓ Step 2 complete: [result]"

**OUTPUT COMPLETION MESSAGE:**
```
✅ COMPLETED: [Skill Name]
[Key results summary]
[Artifacts created with paths]
───────────────────────────────────────
Next: [What to do next]
```

**IF FAILURE:**
```
❌ FAILED: [Skill Name]
Step: [Which step failed]
Error: [Error summary]
Resolution: [How to proceed]
───────────────────────────────────────
```
</WORKFLOW>

<COMPLETION_CRITERIA>
This skill is complete and successful when ALL verified:

✅ **1. [Criterion Category]**
- Specific requirement 1
- Specific requirement 2

✅ **2. [Criterion Category]**
- Specific requirement 1
- Specific requirement 2

---

**FAILURE CONDITIONS - Stop and report if:**
❌ Condition 1 (action to take)
❌ Condition 2 (action to take)

**PARTIAL COMPLETION - Not acceptable:**
⚠️ Incomplete state 1 → Return to step X
⚠️ Incomplete state 2 → Return to step Y
</COMPLETION_CRITERIA>

<OUTPUTS>
After successful completion, return to agent:

1. **Output Name**
   - Location: [path]
   - Format: [format]
   - Contains: [description]

Return to agent: [Primary output for next step]
</OUTPUTS>

<HANDLERS>
  <HANDLER_TYPE_1>
  When config.handlers.type.active == "provider":
    **USE SKILL: handler-type-provider**
    Operation: [operation-name]
    Arguments: [arguments]
  </HANDLER_TYPE_1>
</HANDLERS>

<DOCUMENTATION>
After completing work:
Execute: ../common/scripts/update-docs.sh
</DOCUMENTATION>

<ERROR_HANDLING>
  <ERROR_CATEGORY_1>
  Pattern: [Detection pattern]
  Action: [Handling steps]
  Delegate: [Skill to invoke if needed]
  </ERROR_CATEGORY_1>
</ERROR_HANDLING>

<EXAMPLES>
<example>
Input: [Example input]
Start: [Start message shown]
Process: [Steps executed]
Completion: [Completion message shown]
Output: [What's returned]
</example>
</EXAMPLES>
```

### Skill Directory Structure

```
skills/skill-name/
├── SKILL.md              # Main skill definition
├── workflow/             # Workflow step files
│   ├── step-1.md
│   ├── step-2.md
│   └── step-3.md
├── docs/                 # Reference documentation
│   ├── guidelines.md
│   └── best-practices.md
├── templates/            # Reusable templates
│   └── output.template
├── standards/            # Standards to follow
│   └── conventions.md
└── scripts/              # Deterministic operations
    ├── script-1.sh
    └── script-2.py
```

---

## Handler Pattern

### When to Use

Use handlers when your plugin needs to work with **multiple providers/tools** for the same operation.

**Examples:**
- Hosting providers: AWS, GCP, Azure
- IaC tools: Terraform, Pulumi, CDK
- Source control: GitHub, GitLab, Bitbucket
- Issue trackers: GitHub Issues, Jira, Linear

### Handler Organization

```
handlers/
├── hosting/              # Cloud providers
│   ├── aws/
│   ├── gcp/
│   └── azure/
├── iac/                  # IaC tools
│   ├── terraform/
│   ├── pulumi/
│   └── cdk/
└── [other-types]/
```

### Handler Skill Structure

```
skills/handler-{type}-{provider}/
├── SKILL.md
├── workflow/
│   ├── operation-1.md
│   └── operation-2.md
├── docs/
│   └── best-practices.md
└── scripts/
    ├── operation-1.sh
    └── operation-2.sh
```

### Configuration

```json
{
  "handlers": {
    "hosting": {
      "active": "aws",
      "aws": { ... },
      "gcp": { ... }
    },
    "iac": {
      "active": "terraform",
      "terraform": { ... },
      "pulumi": { ... }
    }
  }
}
```

### Invocation Pattern

```markdown
<EXECUTE_OPERATION>
Determine which handler to use:

handler_type = config.handlers.{type}.active

**USE SKILL: handler-{type}-${handler_type}**
Operation: [operation-name]
Arguments: [arguments]
</EXECUTE_OPERATION>
```

---

## Command Pattern

### Command Structure

Commands are **router files** that parse user input and declaratively invoke manager agents. They do NOT execute operations themselves.

```markdown
---
name: plugin-name:command-name
description: Brief description of what the command does
argument-hint: subcommand <args> [options] | subcommand2 <args>
---

<CONTEXT>
You are the [command-name] command router for the [plugin-name] plugin.
Your role is to parse user input and invoke the [agent-name] agent with the appropriate request.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse the command arguments from user input
- Invoke the [plugin-name:agent-name] agent (or @agent-[plugin-name]:[agent-name])
- Pass structured request to the agent
- Return the agent's response to the user

**YOU MUST NOT:**
- Perform any operations yourself
- Invoke skills directly (the agent handles skill invocation)
- Execute platform-specific logic (that's the agent's job)

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - Extract subcommand and arguments
   - Parse required and optional arguments
   - Validate required arguments are present

2. **Build structured request**
   - Map subcommand to operation name
   - Package parameters

3. **Invoke agent**
   - Invoke [plugin-name:agent-name] agent with the request

4. **Return response**
   - The agent will handle the operation and return results
   - Display results to the user
</WORKFLOW>

<ARGUMENT_PARSING>
## Subcommands

### subcommand <arg1> [--option <value>]
**Purpose**: What this subcommand does

**Required Arguments**:
- `arg1`: Description

**Optional Arguments**:
- `--option`: Description (default: value)

**Maps to**: operation-name

**Example**:
```
/plugin:command subcommand "value" --option foo
→ Invoke agent with {"operation": "operation-name", "parameters": {"arg1": "value", "option": "foo"}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Example 1
/plugin:command subcommand "arg"

# Example 2
/plugin:command subcommand "arg" --option value
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the agent using **declarative syntax**:

**Agent**: [plugin-name:agent-name] (or @agent-[plugin-name]:[agent-name])

**Request structure**:
```json
{
  "operation": "operation-name",
  "parameters": {
    "param1": "value1",
    "param2": "value2"
  }
}
```

The agent will:
1. Receive the request
2. Route to appropriate skill based on operation
3. Execute platform-specific logic
4. Return structured response

## Supported Operations

- `operation-name` - Description of operation
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing required argument**:
```
Error: <arg> is required
Usage: /plugin:command subcommand <arg>
```

**Invalid subcommand**:
```
Error: Unknown subcommand: invalid
Available: subcommand1, subcommand2
```
</ERROR_HANDLING>

<NOTES>
Brief notes about platform support, integration, related commands, etc.

## See Also

For detailed documentation, see: [/docs/commands/plugin-command.md](...)

Related commands:
- `/plugin:other-command` - Description
</NOTES>
```

### Command Argument Syntax

**All commands MUST use space-separated syntax for arguments.**

**Standard:** `--flag value` (NOT `--flag=value`)

**Reference:** See [COMMAND-ARGUMENT-SYNTAX.md](./COMMAND-ARGUMENT-SYNTAX.md) for complete specification.

#### Key Rules

1. **Flags with values:** `--flag value`
   - Single-word values: `--env test`
   - Multi-word values: `--description "multi word value"` (MUST use quotes)

2. **Boolean flags:** `--flag` (no value)
   - Example: `--auto-approve`, `--dry-run`, `--force`
   - Never: `--flag true` or `--flag=true`

3. **Positional arguments:**
   - Single-word: `argument`
   - Multi-word: `"argument with spaces"` (MUST use quotes)

#### Error Detection

Commands MUST reject equals syntax with helpful errors:

```bash
# In parsing logic
--*=*)
    FLAG_NAME="${1%%=*}"
    echo "Error: Use space-separated syntax, not equals syntax" >&2
    echo "Use: $FLAG_NAME <value>" >&2
    echo "Not: $1" >&2
    exit 2
    ;;
```

#### Example Command Usage

```bash
# Correct ✅
/plugin:command "argument" --flag value --boolean-flag
/plugin:command "multi word arg" --description "multi word value"

# Incorrect ❌
/plugin:command argument --flag=value
/plugin:command multi word arg --description multi word value
```

#### Standard Parsing Pattern

Copy this pattern when creating command parsing logic:

```bash
#!/bin/bash
# Standard argument parsing pattern

# Initialize variables
FLAG_VALUE=""
BOOLEAN_FLAG=""
POSITIONAL=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --flag)
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --flag requires a value" >&2
                echo "Usage: /command --flag <value>" >&2
                exit 2
            fi
            FLAG_VALUE="$2"
            shift 2
            ;;
        --boolean-flag)
            BOOLEAN_FLAG="true"
            shift
            ;;
        --*=*)
            # Reject equals syntax
            FLAG_NAME="${1%%=*}"
            echo "Error: Use space-separated syntax" >&2
            echo "Use: $FLAG_NAME <value>" >&2
            echo "Not: $1" >&2
            exit 2
            ;;
        --*)
            echo "Error: Unknown flag: $1" >&2
            exit 2
            ;;
        *)
            POSITIONAL="$1"
            shift
            ;;
    esac
done
```

#### Rationale

**Industry Standard:**
- Git, npm, Docker, kubectl, AWS CLI all use space-separated syntax
- POSIX/GNU standards recommend space-separated for long options
- 90%+ of major CLI tools use this pattern

**Parsing Reliability:**
- Shell handles tokenization automatically
- Clear token boundaries
- Easy error detection
- Fewer edge cases

**Developer Familiarity:**
- Matches developer expectations
- Consistent with familiar tools
- Clear when quotes are needed

See [SPEC-0014: CLI Argument Standards](../specs/SPEC-0014-cli-argument-standards.md) for detailed analysis.

### Agent Invocation Syntax

Commands invoke agents using **declarative statements** in markdown. Claude Code automatically routes to registered agents in `marketplace.json`.

**Correct invocation patterns:**
- `Invoke fractary-work:work-manager agent`
- `Invoke @agent-fractary-work:work-manager`

**Agent registration** (in `.claude-plugin/marketplace.json`):
```json
{
  "name": "fractary-work",
  "agents": [
    "./agents/work-manager.md"
  ]
}
```

**Important:**
- Commands do NOT use `tools:` frontmatter (that's for agents/skills)
- Commands do NOT invoke skills directly
- Commands do NOT execute bash scripts
- Commands are pure routers that expand instructions for agent invocation

---

## Configuration Pattern

### Configuration Location

`.fractary/plugins/{plugin-name}/config/{plugin}.json`

**NOT committed to Git** (contains secrets, profiles)

### Configuration Structure

```json
{
  "version": "1.0",

  "project": {
    "name": "project-name",
    "subsystem": "subsystem-name",
    "organization": "org-name"
  },

  "handlers": {
    "{type}": {
      "active": "{provider}",
      "{provider}": {
        "specific": "config"
      }
    }
  },

  "resource_naming": {
    "pattern": "{project}-{subsystem}-{environment}-{resource}",
    "separator": "-"
  },

  "environments": {
    "test": { ... },
    "prod": { ... }
  }
}
```

### Pattern Substitution

**Available variables:**
- `{project}`: Project name
- `{subsystem}`: Subsystem name
- `{environment}`: Current environment
- `{resource}`: Resource name
- `{organization}`: Organization name

**Example:** `{project}-{subsystem}-{environment}-{resource}`
→ `myproject-core-test-database`

---

## Hook Pattern

### When to Use Hooks

Hooks enable **project-specific customization** without requiring code changes or wrapper commands. Use hooks when:

- Projects need to inject project-specific context (standards, patterns, constraints)
- Different environments require different behavior (dev vs prod)
- Custom validation or setup is needed before/after operations
- External systems need to be notified of lifecycle events

### Hook Types

**Four hook types supported:**

1. **Context Hooks**: Inject documentation and standards into agent context
2. **Prompt Hooks**: Inject short reminders or warnings
3. **Script Hooks**: Execute shell scripts at lifecycle points
4. **Skill Hooks**: Invoke Claude Code skills for complex operations

### Hook Configuration Structure

**Location:**
- FABER: `.faber.config.toml` → `[hooks]` section
- Plugins: `.fractary/plugins/{plugin}/config.json` → `hooks` object

**TOML Format (FABER):**

```toml
[[hooks.{phase}.{timing}]]
type = "context" | "prompt" | "script" | "skill"
name = "hook-name"
required = true | false
failureMode = "stop" | "warn"
timeout = 300
environments = ["dev", "test", "prod"]  # Optional: filter by environment

# Context hook fields
prompt = "Apply these standards when..."
references = [
  { path = "docs/STANDARDS.md", description = "Project standards" },
  { path = "docs/PATTERNS.md", description = "Patterns", sections = ["API Design"] }
]
weight = "critical" | "high" | "medium" | "low"

# Prompt hook fields
content = "⚠️  PRODUCTION - Extra caution required"
weight = "critical"

# Script hook fields
path = "./scripts/setup.sh"
description = "Setup environment"

# Skill hook fields
# (name is used as skill name)
description = "Run validation checks"
```

**JSON Format (Plugin Configs):**

```json
{
  "hooks": {
    "{phase}": {
      "pre": [
        {
          "type": "context",
          "name": "standards",
          "references": [{"path": "docs/STANDARDS.md", "description": "Standards"}],
          "weight": "high"
        }
      ],
      "post": [
        {
          "type": "script",
          "name": "notify",
          "path": "./scripts/notify.sh",
          "required": false
        }
      ]
    }
  }
}
```

### Hook Timing

**Pre-phase hooks**: Execute **before** phase/operation starts
- Context injection (standards, patterns, constraints)
- Prompt injection (reminders, warnings)
- Setup scripts (environment prep, validation)
- Pre-flight checks

**Post-phase hooks**: Execute **after** phase/operation completes
- Validation scripts (quality gates, tests)
- Notification scripts (Slack, email, status updates)
- Cleanup scripts
- Post-operation validation

### Hook Execution Order

**Pre-phase**:
1. Context hooks (by weight: critical → high → medium → low)
2. Prompt hooks (by weight: critical → high → medium → low)
3. Script hooks (in declared order)
4. Skill hooks (in declared order)

**Post-phase**:
1. Script hooks (in declared order)
2. Skill hooks (in declared order)

### Context Hook Pattern (NEW)

**Purpose**: Inject project-specific documentation and standards into agent context

**Configuration**:
```toml
[[hooks.architect.pre]]
type = "context"
name = "architecture-standards"
prompt = "Follow our architecture patterns when designing solutions."
references = [
  {
    path = "docs/ARCHITECTURE.md",
    description = "Architecture standards",
    sections = ["Microservices", "API Design"]  # Optional: extract specific sections
  }
]
weight = "high"
```

**Result**: Agent receives formatted context block:
```markdown
═══════════════════════════════════════════════════════════
📋 PROJECT CONTEXT: architecture-standards
Priority: high
═══════════════════════════════════════════════════════════

Follow our architecture patterns when designing solutions.

## Referenced Documentation

### Architecture standards
**Source**: `docs/ARCHITECTURE.md`
**Sections**: Microservices, API Design

[... content of docs/ARCHITECTURE.md, sections extracted ...]

═══════════════════════════════════════════════════════════
```

**Use Cases**:
- Coding standards for build phase
- Architecture patterns for design phase
- Testing requirements for evaluate phase
- Release checklists for release phase

### Prompt Hook Pattern (NEW)

**Purpose**: Inject short reminders or critical warnings

**Configuration**:
```toml
[[hooks.release.pre]]
type = "prompt"
name = "production-warning"
content = """
⚠️  PRODUCTION DEPLOYMENT

Verify:
- All tests pass
- Migrations are backward compatible
- Team notified in #deployments
"""
weight = "critical"
environments = ["prod"]  # Only for production!
```

**Result**: Agent receives formatted prompt:
```markdown
─────────────────────────────────────────────────────────
⚠️  CRITICAL PROMPT: production-warning
Priority: critical
─────────────────────────────────────────────────────────

⚠️  PRODUCTION DEPLOYMENT

Verify:
- All tests pass
- Migrations are backward compatible
- Team notified in #deployments

─────────────────────────────────────────────────────────
```

**Use Cases**:
- Environment-specific warnings
- Critical safety reminders
- Quick guidance without external files
- Technology constraints

### Script Hook Pattern

**Purpose**: Execute shell scripts at lifecycle points

**Configuration**:
```toml
[[hooks.build.post]]
type = "script"
name = "run-tests"
path = "./scripts/run-tests.sh"
description = "Run test suite"
required = true
failureMode = "stop"
timeout = 600
```

**Environment Variables Passed**:
```bash
FABER_PHASE="build"
FABER_HOOK_TYPE="post"
FABER_ENVIRONMENT="dev"
FABER_WORK_ITEM_ID="123"
FABER_PROJECT_ROOT="/path/to/project"
FABER_CONFIG_PATH="/path/to/.faber.config.toml"
```

**Use Cases**:
- Build scripts
- Test execution
- Deployment preparation
- Notifications
- Cleanup

### Skill Hook Pattern

**Purpose**: Invoke Claude Code skills for complex validation or operations

**Configuration**:
```toml
[[hooks.evaluate.post]]
type = "skill"
name = "security-scanner"
description = "Run security scanning on code"
required = true
failureMode = "stop"
timeout = 600
```

**Skill Interface**: Skills receive WorkflowContext JSON:
```json
{
  "workflowType": "faber",
  "workflowPhase": "evaluate",
  "hookType": "post",
  "pluginName": "faber",
  "environment": "dev",
  "projectRoot": "/path/to/project",
  "workItem": {
    "id": "123",
    "type": "feature"
  },
  "flags": {
    "dryRun": false,
    "autonomyLevel": "guarded"
  }
}
```

**Skill Response**: Skills return WorkflowResult JSON:
```json
{
  "success": true,
  "message": "Security scan passed",
  "data": {
    "vulnerabilities": 0
  },
  "errors": []
}
```

**Use Cases**:
- Complex validation requiring AI
- Custom code review checks
- Architecture compliance validation
- Data quality checks

### Environment Filtering

**Filter hooks by environment**:

```toml
[[hooks.release.pre]]
type = "prompt"
name = "production-warning"
content = "⚠️  PRODUCTION - Extra caution!"
environments = ["prod", "production"]  # Only for these environments
```

**Behavior**:
- If `environments` specified: Hook only executes if current environment in list
- If `environments` empty/null: Hook executes in all environments
- Common values: `["dev"]`, `["test", "staging"]`, `["prod"]`

### Failure Handling

**Required vs Optional**:
- `required: true` → Hook must succeed for workflow to continue
- `required: false` → Hook failure logged but workflow continues

**Failure Modes**:
- `failureMode: "stop"` → Stop workflow, return error
- `failureMode: "warn"` → Log warning, continue workflow

**Combinations**:
- `required: true, failureMode: "stop"` → Critical hook, must pass
- `required: true, failureMode: "warn"` → Important hook, log if fails but continue
- `required: false, failureMode: "warn"` → Optional hook, always continue

### Weight/Priority System

**For context and prompt hooks**:

- `critical` → Always included, shown first, never pruned
- `high` → Always included, high priority
- `medium` → Included (default), medium priority
- `low` → Included if context budget allows, may be pruned

**Use critical for**:
- Production safety warnings
- Absolute must-follow rules
- Critical security requirements

**Use high for**:
- Architecture standards
- Coding standards
- Important patterns

**Use medium for**:
- General guidance (default)
- Nice-to-have context

**Use low for**:
- Optional context that may be pruned

### Hook Executor Skill

**Every plugin with hooks needs a hook executor skill**:

**File**: `skills/hook-executor/SKILL.md`

**Responsibilities**:
1. Validate hook configuration
2. Filter hooks by environment
3. Execute hooks in correct order
4. Load referenced documents (context hooks)
5. Format context/prompt injection blocks
6. Execute scripts with proper environment
7. Invoke skills with WorkflowContext
8. Handle failures per configuration
9. Track execution state
10. Return results to manager

**Reusable Implementation**:
- FABER implementation: `plugins/faber/skills/hook-executor/`
- Can be adapted/reused by other plugins
- Scripts: `load-context.sh`, `execute-script-hook.sh`, `format-context-injection.sh`

### Manager Integration

**Managers must**:

1. Load hooks configuration
2. Execute pre-phase hooks before phase execution
3. Capture context injection from hooks
4. Pass injected context to phase skills
5. Execute post-phase hooks after phase completion
6. Handle hook failures
7. Update session/state with hook results

**Example integration pattern**:

```bash
# Before phase execution
execute_phase_hooks "architect" "pre" "$PHASE_CONTEXT"
HOOK_EXIT=$?
if [ $HOOK_EXIT -ne 0 ]; then
    echo "❌ Pre-architect hooks failed"
    exit 1
fi

# Get context injection
CONTEXT_INJECTION=$(get_hook_context_injection)

# Execute phase with injected context
Use skill with context and injected_context

# After phase execution
execute_phase_hooks "architect" "post" "$PHASE_CONTEXT"
```

### Skill Modifications for Hooks

**Skills that receive injected context must**:

1. Accept `injected_context` parameter in inputs
2. Document injected context in `<CONTEXT>` section
3. Apply injected context when executing
4. Add "Step 0: Process Injected Context" to workflow

**Example**:

```markdown
<INPUTS>
... existing inputs ...

**Optional**:
- `injected_context` (string): Project-specific context from hooks
</INPUTS>

<WORKFLOW>
## Step 0: Process Injected Context

If `injected_context` provided:
1. Read the injected context carefully
2. Apply project-specific guidance/standards/constraints
3. Treat as authoritative project requirements

## Step 1: ... (continue with normal workflow)
```

### Benefits

**For Users**:
- No wrapper commands needed
- Configuration-driven customization
- Environment-specific behavior
- Discoverable (explicit in config)

**For Plugin Authors**:
- Separation of concerns (core vs project-specific)
- Reusable across projects
- Easy maintenance
- Testable

**For the Ecosystem**:
- Consistent hook pattern across plugins
- Reduced custom code
- Better defaults with project customization

### Example: FABER with Hooks

**Complete example**: See `plugins/faber/config/faber.example-with-hooks.toml`

**Guides**:
- Hook integration: `plugins/faber/docs/guides/HOOKS_INTEGRATION_GUIDE.md`
- Eliminating wrappers: `plugins/faber/docs/guides/ELIMINATING_WRAPPER_COMMANDS.md`

**Specification**: See `docs/specs/SPEC-0026-unified-hooks-context-injection.md`

---

## Documentation Standards

### Embedded Documentation

**Principle:** Skills document their own work as the final step.

**Implementation:**
```markdown
<DOCUMENTATION>
After completing work:
Execute: ../common/scripts/update-docs.sh --skill={skill-name}

Update:
- Registry of created/modified items
- Human-readable documentation
- Change history log
</DOCUMENTATION>
```

### Documentation Types

**1. Registry** (Machine-readable)
- JSON format
- Complete metadata
- Used by other skills

**2. Human Docs** (Markdown)
- Clear, readable format
- Links to resources
- Purpose and context

**3. History Logs** (JSON)
- Timestamped changes
- Attribution
- Stored in S3 for large logs

### What to Commit

**✅ Commit:**
- Design documents
- Registry files
- Human-readable docs
- Audit trails
- Config templates

**❌ NOT Commit:**
- Config files (secrets)
- Large log files (S3-backed)
- Temporary files

---

## XML Markup Standards

### Standard Sections (Required)

```markdown
<CONTEXT>Who you are, what you do</CONTEXT>
<CRITICAL_RULES>Must-never-violate rules</CRITICAL_RULES>
<INPUTS>What you receive</INPUTS>
<WORKFLOW>Steps to execute</WORKFLOW>
<COMPLETION_CRITERIA>How to know you're done</COMPLETION_CRITERIA>
<OUTPUTS>What you return</OUTPUTS>
<DOCUMENTATION>How to document work</DOCUMENTATION>
<ERROR_HANDLING>How to handle errors</ERROR_HANDLING>
```

### Optional Sections

```markdown
<HANDLERS>Handler skills to use</HANDLERS>
<EXAMPLES>Usage examples</EXAMPLES>
<TEMPLATES>Templates available</TEMPLATES>
<STANDARDS>Standards to follow</STANDARDS>
```

### Uppercase Convention

**Use UPPERCASE for XML tags:**
- Visually distinct from text
- Easy to reference in instructions
- Clear section boundaries

**Example reference in text:**
```markdown
Follow the steps in <WORKFLOW> section.
Ensure all criteria in <COMPLETION_CRITERIA> are met.
```

### Nested Structure

```markdown
<HANDLERS>
  <HOSTING>
  When hosting == "aws":
    **USE SKILL: handler-hosting-aws**
  </HOSTING>

  <IAC>
  When iac == "terraform":
    **USE SKILL: handler-iac-terraform**
  </IAC>
</HANDLERS>
```

---

## Example: DevOps Plugin

**Reference implementation demonstrating all patterns.**

### Architecture

- **2 Managers**: infra-manager, ops-manager
- **10 Skills**: architect, engineer, validator, tester, previewer, deployer, permission-manager, debugger, monitor, investigator, responder, auditor
- **4 Handler Skills**: handler-hosting-aws, handler-hosting-gcp, handler-iac-terraform, handler-iac-pulumi

### Key Patterns Demonstrated

1. **Workflow-Oriented Managers**
   - infra-manager: design → deploy workflow
   - ops-manager: monitor → remediate workflow

2. **Single-Purpose Skills**
   - Each skill does one thing well
   - Clear completion criteria
   - Embedded documentation

3. **Handler Abstraction**
   - Provider-specific logic centralized
   - Easy to add new providers
   - Skills remain provider-agnostic

4. **Configuration-Driven**
   - Single config file
   - Pattern substitution
   - Handler selection via config

5. **Documentation-First**
   - Resource registry
   - Deployment docs
   - Issue log (debugger)

6. **Defense in Depth**
   - Production safety at multiple levels
   - Permission separation enforced everywhere
   - Critical rules repeated

### Files to Study

- **Overview**: `plugins/fractary-devops/docs/specs/fractary-devops-overview.md`
- **Architecture**: `plugins/fractary-devops/docs/specs/fractary-devops-architecture.md`
- **Configuration**: `plugins/fractary-devops/docs/specs/fractary-devops-configuration.md`
- **Handlers**: `plugins/fractary-devops/docs/specs/fractary-devops-handlers.md`
- **Permissions**: `plugins/fractary-devops/docs/specs/fractary-devops-permissions.md`
- **Documentation**: `plugins/fractary-devops/docs/specs/fractary-devops-documentation.md`
- **Implementation**: `plugins/fractary-devops/docs/specs/fractary-devops-implementation-phases.md`

---

## Checklist for New Plugins

### Planning Phase

- [ ] Identify domain workflows
- [ ] Define managers (one per complete workflow)
- [ ] Define skills (one per focused task)
- [ ] Determine if multi-provider (need handlers?)
- [ ] Design configuration structure
- [ ] Plan documentation strategy

### Architecture Phase

- [ ] Create plugin directory structure
- [ ] Define manager responsibilities
- [ ] Define skill responsibilities
- [ ] Define handler interfaces (if needed)
- [ ] Design workflow orchestration
- [ ] Design error handling strategy

### Implementation Phase

- [ ] Implement managers with examples
- [ ] Implement skills with XML markup
- [ ] Implement handlers (if needed)
- [ ] Implement commands
- [ ] Implement configuration system
- [ ] Implement documentation system
- [ ] Add start/end logging to skills
- [ ] Add completion criteria to skills

### Quality Phase

- [ ] Test complete workflows end-to-end
- [ ] Verify critical rules enforced
- [ ] Verify documentation accuracy
- [ ] Verify error handling
- [ ] Write user documentation
- [ ] Write architecture documentation
- [ ] Performance optimization
- [ ] Security review

### Release Phase

- [ ] Create README.md
- [ ] Create ARCHITECTURE.md
- [ ] Create user guides
- [ ] Create reference documentation
- [ ] Version and release
- [ ] Gather user feedback
- [ ] Iterate based on feedback

---

## Development Tools

### Command Frontmatter Linter

A validation script is available to catch common frontmatter errors in command files:

```bash
./scripts/lint-command-frontmatter.sh [OPTIONS] [path]
```

#### Options

- `--verbose` - Show detailed output including files that pass
- `--quiet` - Only show summary, no file-by-file output
- `--fix` - Automatically fix issues where possible (e.g., leading slashes)
- `--help` - Show usage information

#### What it validates

**Errors (must fix):**
- Missing frontmatter structure (must start with `---`)
- Missing required `name` field
- Leading slashes in `name` field (e.g., `/fractary-faber:run` → should be `fractary-faber:run`)
  - **Auto-fixable with `--fix` flag**

**Warnings (recommended to fix):**
- `name` field doesn't follow `plugin-name:command-name` pattern
- Missing recommended `description` field

#### Frontmatter Name Pattern Requirements

The linter enforces strict naming patterns for command frontmatter:

**Required Pattern:** `plugin-name:command-name`

- **Plugin name**: Lowercase alphanumeric with hyphens (e.g., `fractary-repo`, `faber-cloud`)
- **Command name**: Lowercase alphanumeric with hyphens (e.g., `commit`, `branch-create`)
- **Separator**: Single colon (`:`)
- **No leading slashes**: The name should never start with `/`

**Valid examples:**
```yaml
name: fractary-repo:commit
name: fractary-work:issue-create
name: faber-cloud:deploy-execute
name: faber:run
```

**Invalid examples:**
```yaml
name: /fractary-repo:commit        # Leading slash
name: FractaryRepo:Commit          # Uppercase letters
name: fractary_repo:commit         # Underscores
name: commit                       # Missing plugin prefix
name: fractary-repo/commit         # Wrong separator
```

**Pattern strictness rationale:**
- Ensures consistent naming across all plugins
- Makes command names predictable and discoverable
- Prevents namespace collisions
- Enables tooling and automation
- Matches slash command invocation pattern (e.g., `/fractary-repo:commit`)

#### Multi-line YAML Support

The linter properly handles multi-line YAML values using `>` or `|` syntax:

```yaml
name: plugin:command
description: >
  This is a long description
  that spans multiple lines
  and will be properly parsed
```

#### Usage in Development

**Before committing:**
```bash
./scripts/lint-command-frontmatter.sh plugins/your-plugin/
```

**Auto-fix issues:**
```bash
./scripts/lint-command-frontmatter.sh --fix plugins/
```

**CI/CD Integration:**
The linter is integrated into GitHub Actions (`.github/workflows/lint-frontmatter.yml`) and runs automatically on PRs that modify command files.

**See also:** `scripts/README.md` for full documentation and `tests/test-lint-frontmatter.sh` for test suite.

This tool was created to prevent issues like those fixed in commit `b7f661e` where 7 command files had incorrect leading slashes in their frontmatter name fields.

---

## Best Practices Summary

1. **Managers own workflows** - Complete domain from start to finish
2. **Skills execute tasks** - Focused, single-purpose, well-defined
3. **Handlers abstract providers** - Centralized provider logic
4. **Configuration drives behavior** - No code changes to switch providers
5. **Document atomically** - Skills document their own work
6. **Enforce critical rules** - Multiple levels of defense
7. **Log start and end** - Visibility into workflow progress
8. **Clear completion criteria** - Know when skill is done
9. **Uppercase XML tags** - Visual distinction and clarity
10. **Learn from DevOps** - Reference implementation for patterns

---

## Questions or Contributions

For questions about these standards or to propose changes, please refer to the DevOps plugin implementation as the canonical example.

**DevOps Plugin Specs:** `plugins/fractary-devops/docs/specs/`

---

**Version History:**
- 1.0.0 (2025-10-28): Initial standards based on DevOps plugin architecture
