# Fractary Plugin Development Standards

**Version:** 1.0.0
**Last Updated:** 2025-10-28
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
8. [Documentation Standards](#documentation-standards)
9. [XML Markup Standards](#xml-markup-standards)
10. [Example: DevOps Plugin](#example-devops-plugin)

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
