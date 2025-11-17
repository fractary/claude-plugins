---
org: fractary
system: claude-code
title: FABER Agent Plugin Specification - Meta-Plugin for Creating Claude Code Artifacts
description: Specification for faber-agent plugin that codifies all fractary plugin development standards into executable workflows for creating agents, skills, commands, and complete plugins
tags: [faber-agent, meta-plugin, agent-creation, plugin-development, standards, templates]
created: 2025-11-05
updated: 2025-11-05
codex_sync_include: []
codex_sync_exclude: []
visibility: internal
---

# SPEC-00015: FABER Agent Plugin Specification

**Version:** 1.0.0
**Date:** 2025-11-05
**Status:** Draft

---

## Table of Contents

1. [Overview](#overview)
2. [Purpose and Goals](#purpose-and-goals)
3. [Architecture](#architecture)
4. [Plugin Structure](#plugin-structure)
5. [Key Workflows](#key-workflows)
6. [Templates System](#templates-system)
7. [Validation System](#validation-system)
8. [Usage Examples](#usage-examples)
9. [Integration with Ecosystem](#integration-with-ecosystem)
10. [Future Extensibility](#future-extensibility)
11. [Implementation Plan](#implementation-plan)
12. [Success Metrics](#success-metrics)

---

## Overview

### Purpose

The **faber-agent** plugin is a meta-plugin that codifies all Fractary plugin development standards and best practices into executable workflows. It enables consistent, high-quality creation of:
- **Agents** (workflow orchestrators)
- **Skills** (focused execution units)
- **Commands** (entry point routers)
- **Complete Plugins** (full plugin bundles)
- **Handlers** (multi-provider adapters)

### Key Insight

All learnings documented in `docs/standards/FRACTARY-PLUGIN-STANDARDS.md` become executable FABER workflows that generate compliant artifacts automatically.

### Key Benefits

1. **Codifies Standards**: All learnings become executable workflows
2. **Ensures Consistency**: Every generated artifact follows the same high-quality patterns
3. **Reduces Errors**: Validates compliance automatically (XML markup, frontmatter, naming, etc.)
4. **Accelerates Development**: From idea to working plugin in minutes, not hours
5. **Future-Proof**: Architected to support other agentic frameworks (OpenAI, LangChain, etc.)

---

## Purpose and Goals

### Primary Goals

1. **Capture Institutional Knowledge**: Codify all learnings about creating great plugins
2. **Ensure Standards Compliance**: Every artifact follows FRACTARY-PLUGIN-STANDARDS.md
3. **Accelerate Development**: Reduce agent creation time from 30-60 minutes to 5 minutes
4. **Maintain Quality**: Generated artifacts match or exceed hand-crafted quality
5. **Enable Consistency**: Same high-quality patterns across all artifacts

### Secondary Goals

1. **Reduce Cognitive Load**: Developers don't need to remember all standards
2. **Enable Evolution**: Easy to update standards and regenerate artifacts
3. **Support Learning**: New developers learn standards through guided creation
4. **Future Compatibility**: Ready for multi-framework support (OpenAI, LangChain, etc.)

---

## Architecture

### Three-Layer Architecture

Following the established Fractary pattern:

```
Layer 1: Commands (Entry Points)
   └─ create-agent.md, create-skill.md, create-command.md, create-plugin.md
         ↓
Layer 2: Agents (Orchestration)
   └─ agent-creator.md (orchestrates agent creation workflow)
   └─ skill-creator.md (orchestrates skill creation workflow)
   └─ command-creator.md (orchestrates command creation workflow)
   └─ plugin-creator.md (orchestrates complete plugin creation)
         ↓
Layer 3: Skills (Execution)
   └─ gather-requirements (collect info from user)
   └─ generate-from-template (apply templates with substitutions)
   └─ validate-artifact (check standards compliance)
   └─ document-artifact (generate docs)
   └─ test-artifact (run validation tests)
         ↓
Layer 4: Scripts (Deterministic Operations)
   └─ validate-xml-markup.sh
   └─ validate-frontmatter.sh
   └─ lint-command-args.sh
   └─ generate-from-template.sh
```

### Component Responsibilities

**Commands:**
- Parse user input (agent name, type, options)
- Route to appropriate creator agent
- Return results to user

**Agents:**
- Orchestrate complete creation workflow
- Execute FABER phases (Frame → Architect → Build → Evaluate → Release)
- Coordinate skill invocations
- Handle errors and user interaction

**Skills:**
- Perform focused creation tasks
- Execute deterministic operations via scripts
- Validate outputs
- Document results

**Scripts:**
- Template substitution
- Validation checks
- File operations
- Standards enforcement

---

## Plugin Structure

```
plugins/faber-agent/
├── .claude-plugin/
│   └── plugin.json                  # Plugin manifest
│
├── commands/
│   ├── create-agent.md              # /fractary-faber-agent:create-agent
│   ├── create-skill.md              # /fractary-faber-agent:create-skill
│   ├── create-command.md            # /fractary-faber-agent:create-command
│   ├── create-plugin.md             # /fractary-faber-agent:create-plugin
│   └── create-handler.md            # /fractary-faber-agent:create-handler
│
├── agents/
│   ├── agent-creator.md             # Orchestrates agent creation
│   ├── skill-creator.md             # Orchestrates skill creation
│   ├── command-creator.md           # Orchestrates command creation
│   ├── plugin-creator.md            # Orchestrates plugin creation
│   └── handler-creator.md           # Orchestrates handler creation
│
├── skills/
│   ├── gather-requirements/
│   │   ├── SKILL.md
│   │   └── workflow/
│   │       ├── agent.md             # Agent requirements gathering
│   │       ├── skill.md             # Skill requirements gathering
│   │       ├── command.md           # Command requirements gathering
│   │       └── plugin.md            # Plugin requirements gathering
│   │
│   ├── generate-from-template/
│   │   ├── SKILL.md
│   │   ├── workflow/
│   │   │   └── basic.md
│   │   └── scripts/
│   │       └── template-engine.sh
│   │
│   ├── validate-artifact/
│   │   ├── SKILL.md
│   │   ├── workflow/
│   │   │   └── basic.md
│   │   └── scripts/
│   │       ├── validate-xml-markup.sh
│   │       ├── validate-frontmatter.sh
│   │       ├── validate-naming.sh
│   │       └── validate-structure.sh
│   │
│   ├── document-artifact/
│   │   ├── SKILL.md
│   │   └── workflow/
│   │       └── basic.md
│   │
│   └── test-artifact/
│       ├── SKILL.md
│       └── workflow/
│           └── basic.md
│
├── templates/
│   ├── agent/
│   │   ├── manager.md.template      # Manager agent template
│   │   └── handler.md.template      # Handler agent template
│   │
│   ├── skill/
│   │   ├── basic-skill.md.template  # Basic skill template
│   │   ├── workflow-basic.md.template
│   │   └── handler-skill.md.template
│   │
│   ├── command/
│   │   └── command.md.template      # Command template
│   │
│   └── plugin/
│       ├── plugin.json.template
│       └── README.md.template
│
├── standards/
│   ├── xml-markup.md                # XML section standards
│   ├── frontmatter.md               # Frontmatter standards
│   ├── naming-conventions.md        # Naming standards
│   ├── error-handling.md            # Error handling patterns
│   └── documentation.md             # Documentation standards
│
├── validators/
│   ├── xml-validator.sh
│   ├── frontmatter-validator.sh
│   ├── structure-validator.sh
│   └── naming-validator.sh
│
├── docs/
│   ├── README.md
│   ├── usage-guide.md
│   ├── examples/
│   │   ├── creating-agent.md
│   │   ├── creating-skill.md
│   │   └── creating-plugin.md
│   └── architecture.md
│
└── config/
    └── faber-agent.example.toml
```

---

## Key Workflows

### 1. Create Agent Workflow

**Command:** `/fractary-faber-agent:create-agent <name> --type <manager|handler>`

**FABER Phases:**

#### Frame Phase
- Gather requirements (agent name, purpose, domain, workflow type)
- Identify which other agents/skills it will invoke
- Determine if it's a manager (owns workflow) or handler (multi-provider)
- Collect examples of similar agents for reference

**Outputs:**
- Agent name (validated against naming conventions)
- Agent purpose and responsibility
- Agent type (manager vs handler)
- List of skills/agents to invoke
- Domain context

#### Architect Phase
- Choose appropriate template (manager vs handler)
- Design XML structure based on requirements
- Plan skill invocation patterns
- Design error handling strategy
- Identify critical rules to enforce

**Outputs:**
- Selected template
- XML section structure
- Skill invocation plan
- Error handling design
- Critical rules list

#### Build Phase
- Generate agent file from template
- Apply XML markup standards (UPPERCASE tags)
- Include all required sections (CONTEXT, CRITICAL_RULES, INPUTS, WORKFLOW, etc.)
- Add examples based on similar agents
- Generate workflow coordination logic
- Apply frontmatter (name, description, tools, model)

**Outputs:**
- Complete agent markdown file
- Frontmatter properly formatted
- All XML sections present
- Examples included

#### Evaluate Phase
- Validate XML markup completeness
- Check frontmatter format
- Verify CRITICAL_RULES section present
- Test agent can be invoked
- Compare against similar agents for quality
- Run all validators

**Outputs:**
- Validation report
- List of any compliance issues
- Comparison with standards

#### Release Phase
- Save agent to correct location (plugins/*/agents/)
- Generate documentation
- Create example usage
- Update plugin.json manifest (if needed)
- Create git commit

**Outputs:**
- Agent file saved
- Documentation generated
- Examples created
- Plugin manifest updated

---

### 2. Create Skill Workflow

**Command:** `/fractary-faber-agent:create-skill <name> [--handler-type <type>]`

**FABER Phases:**

#### Frame Phase
- Gather requirements (skill name, purpose, inputs/outputs)
- Determine if it needs workflow files
- Identify if it's a handler skill (multi-provider)
- List scripts needed for deterministic operations
- Identify completion criteria

**Outputs:**
- Skill name and purpose
- Input/output specifications
- Handler type (if applicable)
- Script requirements
- Completion criteria

#### Architect Phase
- Choose template (basic vs handler)
- Design XML structure
- Plan workflow steps (if multi-step)
- Design completion criteria
- Plan script interfaces
- Design start/end message formats

**Outputs:**
- Template selection
- XML section design
- Workflow step breakdown
- Script interface definitions
- Message templates

#### Build Phase
- Generate SKILL.md from template
- Create workflow/ directory with workflow files (if needed)
- Generate script stubs in scripts/ directory
- Add start/end message templates
- Include documentation section
- Add error handling patterns

**Outputs:**
- SKILL.md file
- workflow/*.md files (if needed)
- scripts/*.sh stubs
- Complete XML structure

#### Evaluate Phase
- Validate XML markup completeness
- Check completion criteria clarity
- Verify workflow file structure
- Test skill can be invoked
- Validate script interfaces
- Check documentation completeness

**Outputs:**
- Validation report
- Compliance check results

#### Release Phase
- Save skill to correct location (plugins/*/skills/)
- Generate documentation
- Create example invocations
- Update parent agent if needed
- Create git commit

**Outputs:**
- Skill directory created
- Documentation generated
- Examples included

---

### 3. Create Command Workflow

**Command:** `/fractary-faber-agent:create-command <name> --invokes <agent>`

**FABER Phases:**

#### Frame Phase
- Gather requirements (command name, arguments, which agent it invokes)
- Identify subcommands and flags
- Determine argument patterns (space-separated syntax)
- Understand command purpose

**Outputs:**
- Command name (validated)
- Argument specification
- Agent to invoke
- Subcommands (if any)

#### Architect Phase
- Design frontmatter (name, description, argument-hint)
- Plan argument parsing logic (space-separated, not equals)
- Design agent invocation pattern (declarative)
- Plan error messages and validation
- Design usage examples

**Outputs:**
- Frontmatter design
- Parsing logic design
- Agent invocation pattern
- Error message templates

#### Build Phase
- Generate command file from template
- Add frontmatter (name: plugin:command, description, argument-hint)
- Add argument parsing logic (space-separated syntax)
- Add declarative agent invocation
- Include usage examples
- Add error handling

**Outputs:**
- Complete command markdown file
- Proper frontmatter (no leading slashes)
- Space-separated argument syntax
- Declarative agent invocation

#### Evaluate Phase
- Validate frontmatter (name pattern, no leading slashes)
- Check argument syntax (space-separated, not equals)
- Verify agent invocation is declarative (not tool calls)
- Test command can be invoked
- Run frontmatter linter
- Validate against SPEC-00014 (CLI argument standards)

**Outputs:**
- Validation report
- Frontmatter check results
- Argument syntax validation

#### Release Phase
- Save command to correct location (plugins/*/commands/)
- Generate documentation
- Create usage examples
- Update plugin commands list
- Create git commit

**Outputs:**
- Command file saved
- Documentation generated
- Usage guide created

---

### 4. Create Plugin Workflow

**Command:** `/fractary-faber-agent:create-plugin <name> --type <workflow|primitive|utility>`

**FABER Phases:**

#### Frame Phase
- Gather requirements (plugin name, type, purpose, dependencies)
- Identify workflows it will support
- List agents/skills/commands needed
- Determine if multi-provider (needs handlers)
- Understand plugin category

**Outputs:**
- Plugin name (fractary-* or fractary-faber-*)
- Plugin type and category
- Workflow requirements
- Component list (agents, skills, commands)
- Dependencies

#### Architect Phase
- Design directory structure
- Plan agent responsibilities (one per complete workflow)
- Design skill breakdown (focused, single-purpose)
- Plan handler architecture (if needed)
- Design configuration structure
- Plan documentation structure

**Outputs:**
- Directory structure design
- Agent architecture
- Skill architecture
- Handler design (if applicable)
- Configuration schema

#### Build Phase
- Create plugin directory structure
- Generate plugin.json manifest
- Create placeholder agents with proper XML structure
- Create placeholder skills with workflow/ directories
- Create placeholder commands with proper frontmatter
- Generate README.md
- Create config template (.toml or .json)

**Outputs:**
- Complete plugin directory
- plugin.json manifest
- Placeholder agents/skills/commands
- README and config template

#### Evaluate Phase
- Validate directory structure against standards
- Check plugin.json completeness
- Verify dependencies are correct
- Test plugin can be loaded by Claude Code
- Check against FRACTARY-PLUGIN-STANDARDS.md
- Validate naming conventions

**Outputs:**
- Structure validation report
- Manifest validation results
- Standards compliance check

#### Release Phase
- Save plugin to plugins/ directory
- Generate complete documentation
- Create getting-started guide
- Add to main repository README
- Create initial git commit
- Post creation summary

**Outputs:**
- Plugin saved to repository
- Documentation complete
- Getting-started guide
- Git commit created

---

## Templates System

### Template Variables

All templates support variable substitution:

**Common Variables:**
- `{{AGENT_NAME}}` - Agent identifier (e.g., `data-analyzer`)
- `{{AGENT_DISPLAY_NAME}}` - Human-readable name (e.g., `Data Analyzer`)
- `{{AGENT_DESCRIPTION}}` - Brief description
- `{{AGENT_RESPONSIBILITY}}` - Primary responsibility
- `{{PLUGIN_NAME}}` - Plugin identifier
- `{{SKILL_NAME}}` - Skill identifier
- `{{COMMAND_NAME}}` - Command identifier (plugin:command format)
- `{{TOOLS}}` - Tool list (Bash, Skill, etc.)
- `{{WORKFLOW_STEPS}}` - Generated workflow steps
- `{{CRITICAL_RULES}}` - Generated critical rules
- `{{INPUTS}}` - Input specifications
- `{{OUTPUTS}}` - Output specifications
- `{{ERROR_HANDLING}}` - Error handling logic
- `{{EXAMPLES}}` - Usage examples

### Agent Template Structure

**File:** `templates/agent/manager.md.template`

```markdown
---
name: {{AGENT_NAME}}
description: {{AGENT_DESCRIPTION}}
tools: {{TOOLS}}
model: inherit
---

# {{AGENT_DISPLAY_NAME}}

<CONTEXT>
You are the **{{AGENT_DISPLAY_NAME}}**, responsible for {{AGENT_RESPONSIBILITY}}.

{{CONTEXT_DETAILS}}
</CONTEXT>

<CRITICAL_RULES>
**NEVER VIOLATE THESE RULES:**

1. **Never Do Work Directly**
   - ALWAYS delegate to skills
   - NEVER read files or execute commands directly
   - NEVER implement operations yourself

2. **Workflow Coordination**
   - ALWAYS follow the defined workflow sequence
   - ALWAYS validate skill responses
   - ALWAYS handle skill failures gracefully

{{ADDITIONAL_CRITICAL_RULES}}
</CRITICAL_RULES>

<INPUTS>
You receive {{INPUT_TYPE}} requests with:

**Required Parameters:**
{{REQUIRED_PARAMETERS}}

**Optional Parameters:**
{{OPTIONAL_PARAMETERS}}
</INPUTS>

<WORKFLOW>
{{WORKFLOW_STEPS}}
</WORKFLOW>

<COMPLETION_CRITERIA>
{{COMPLETION_CRITERIA}}
</COMPLETION_CRITERIA>

<OUTPUTS>
{{OUTPUTS}}
</OUTPUTS>

<ERROR_HANDLING>
{{ERROR_HANDLING}}
</ERROR_HANDLING>
```

### Skill Template Structure

**File:** `templates/skill/basic-skill.md.template`

```markdown
---
name: {{SKILL_NAME}}
description: |
  {{SKILL_DESCRIPTION}}
tools: {{TOOLS}}
---

# {{SKILL_DISPLAY_NAME}}

<CONTEXT>
You are the **{{SKILL_DISPLAY_NAME}}**, responsible for {{SKILL_RESPONSIBILITY}}.
</CONTEXT>

<CRITICAL_RULES>
**IMPORTANT:** Rules that must never be violated
{{CRITICAL_RULES}}
</CRITICAL_RULES>

<INPUTS>
What this skill receives:
{{INPUTS}}
</INPUTS>

<WORKFLOW>
**OUTPUT START MESSAGE:**
```
🎯 STARTING: {{SKILL_DISPLAY_NAME}}
{{START_MESSAGE_PARAMS}}
───────────────────────────────────────
```

**EXECUTE STEPS:**
{{WORKFLOW_STEPS}}

**OUTPUT COMPLETION MESSAGE:**
```
✅ COMPLETED: {{SKILL_DISPLAY_NAME}}
{{COMPLETION_MESSAGE_PARAMS}}
───────────────────────────────────────
Next: {{NEXT_STEP}}
```

**IF FAILURE:**
```
❌ FAILED: {{SKILL_DISPLAY_NAME}}
{{FAILURE_MESSAGE}}
```
</WORKFLOW>

<COMPLETION_CRITERIA>
This skill is complete when:
{{COMPLETION_CRITERIA}}
</COMPLETION_CRITERIA>

<OUTPUTS>
After successful completion, return:
{{OUTPUTS}}
</OUTPUTS>

<DOCUMENTATION>
After completing work:
{{DOCUMENTATION_STEPS}}
</DOCUMENTATION>

<ERROR_HANDLING>
{{ERROR_HANDLING}}
</ERROR_HANDLING>
```

### Command Template Structure

**File:** `templates/command/command.md.template`

```markdown
---
name: {{COMMAND_NAME}}
description: {{COMMAND_DESCRIPTION}}
argument-hint: {{ARGUMENT_HINT}}
---

# {{COMMAND_DISPLAY_NAME}}

<CONTEXT>
You are the **{{COMMAND_DISPLAY_NAME}}** command router.
Your role is to parse user input and invoke the {{AGENT_NAME}} agent.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse command arguments from user input
- Invoke the {{AGENT_NAME}} agent
- Pass structured request to the agent
- Return the agent's response to the user

**YOU MUST NOT:**
- Perform any operations yourself
- Invoke skills directly
- Execute platform-specific logic

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   {{PARSING_LOGIC}}

2. **Build structured request**
   {{REQUEST_STRUCTURE}}

3. **Invoke agent**
   {{AGENT_INVOCATION}}

4. **Return response**
   {{RESPONSE_HANDLING}}
</WORKFLOW>

<ARGUMENT_PARSING>
{{ARGUMENT_DETAILS}}
</ARGUMENT_PARSING>

<AGENT_INVOCATION>
After parsing arguments, invoke the agent using declarative syntax:

**Agent**: {{AGENT_REFERENCE}}

**Request structure**:
```json
{{REQUEST_EXAMPLE}}
```
</AGENT_INVOCATION>

<ERROR_HANDLING>
{{ERROR_HANDLING}}
</ERROR_HANDLING>

<EXAMPLES>
{{USAGE_EXAMPLES}}
</EXAMPLES>
```

---

## Validation System

### Automated Validators

The plugin includes comprehensive validators:

#### 1. XML Markup Validator
**File:** `validators/xml-validator.sh`

**Checks:**
- All required sections present (CONTEXT, CRITICAL_RULES, INPUTS, WORKFLOW, OUTPUTS, etc.)
- Proper UPPERCASE tag naming
- Nested structure valid
- Sections in correct order
- No unclosed tags

**Exit Codes:**
- `0` - All checks passed
- `1` - Missing required sections
- `2` - Invalid tag naming
- `3` - Malformed structure

#### 2. Frontmatter Validator
**File:** `validators/frontmatter-validator.sh`

**Checks:**
- Required fields present (name, description)
- Name follows pattern (plugin:command for commands, no leading slashes)
- Multi-line YAML handled correctly
- Tools field appropriate for component type
- Description within character limits

**Exit Codes:**
- `0` - Valid frontmatter
- `1` - Missing required fields
- `2` - Invalid name pattern
- `3` - Malformed YAML

#### 3. Naming Validator
**File:** `validators/naming-validator.sh`

**Checks:**
- Plugin naming follows `fractary-*` or `fractary-faber-*` pattern
- Command naming follows `plugin:command` pattern (no leading slashes)
- File naming follows conventions (kebab-case)
- Directory structure correct
- No namespace collisions

**Exit Codes:**
- `0` - Valid naming
- `1` - Invalid plugin name
- `2` - Invalid command name
- `3` - Invalid file name

#### 4. Structure Validator
**File:** `validators/structure-validator.sh`

**Checks:**
- Agent files in correct location (agents/)
- Skill has SKILL.md and workflow/ directory
- Commands are in commands/
- plugin.json exists and is valid JSON
- Directory structure matches standards

**Exit Codes:**
- `0` - Valid structure
- `1` - Missing directories
- `2` - Files in wrong location
- `3` - Invalid plugin.json

### Validation Integration

All validators are invoked during the **Evaluate** phase of each creation workflow:

```bash
# In skill: validate-artifact
./validators/xml-validator.sh "$ARTIFACT_PATH"
./validators/frontmatter-validator.sh "$ARTIFACT_PATH"
./validators/naming-validator.sh "$ARTIFACT_PATH"
./validators/structure-validator.sh "$ARTIFACT_PATH"
```

---

## Usage Examples

### Example 1: Creating a Simple Manager Agent

```bash
/fractary-faber-agent:create-agent data-analyzer --type manager

# Interactive wizard prompts:
# Name: data-analyzer
# Purpose: Analyze datasets and generate insights
# Workflow: fetch-data → clean-data → analyze → report
# Skills needed: data-fetcher, data-cleaner, data-analyzer, report-generator
# Tools: Bash, Skill

# Output:
# ✅ Agent created: plugins/faber-data/agents/data-analyzer.md
# ✅ Validation passed
# ✅ Documentation generated
# ✅ Examples created
```

**Generated file structure:**
```markdown
---
name: data-analyzer
description: Orchestrates data analysis workflows - fetch, clean, analyze, report
tools: Bash, Skill
model: inherit
---

# Data Analyzer

<CONTEXT>
You are the **Data Analyzer**, responsible for orchestrating complete data analysis workflows.
...
</CONTEXT>

<CRITICAL_RULES>
...
</CRITICAL_RULES>

<WORKFLOW>
...
</WORKFLOW>
...
```

### Example 2: Creating a Skill with Handler Support

```bash
/fractary-faber-agent:create-skill deploy-infrastructure --handler-type iac

# Interactive wizard prompts:
# Name: deploy-infrastructure
# Purpose: Deploy infrastructure using IaC tools
# Handlers: terraform, pulumi, cdk
# Inputs: infrastructure spec, environment, provider config
# Outputs: deployment status, resource IDs
# Scripts needed: validate-spec.sh, apply-changes.sh

# Output:
# ✅ Skill created: plugins/faber-cloud/skills/deploy-infrastructure/
# ✅ SKILL.md generated
# ✅ Handler structure created
# ✅ Scripts stubbed
# ✅ Validation passed
```

**Generated directory:**
```
skills/deploy-infrastructure/
├── SKILL.md
├── workflow/
│   ├── basic.md
│   └── terraform.md          # Handler-specific workflow
├── scripts/
│   ├── validate-spec.sh
│   └── apply-changes.sh
└── docs/
    └── usage.md
```

### Example 3: Creating a Command

```bash
/fractary-faber-agent:create-command analyze --invokes data-analyzer

# Interactive wizard prompts:
# Command name: analyze (will become fractary-faber-data:analyze)
# Agent to invoke: data-analyzer
# Arguments: <dataset-path> [--output <path>] [--format <csv|json>]

# Output:
# ✅ Command created: plugins/faber-data/commands/analyze.md
# ✅ Frontmatter validated (no leading slash)
# ✅ Argument syntax validated (space-separated)
# ✅ Agent invocation validated (declarative)
```

**Generated command:**
```markdown
---
name: fractary-faber-data:analyze
description: Analyze a dataset and generate insights report
argument-hint: <dataset-path> [--output <path>] [--format <csv|json>]
---

# Analyze Dataset

<CONTEXT>
You are the **analyze** command router.
Your role is to parse user input and invoke the data-analyzer agent.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse command arguments from user input
- Invoke the data-analyzer agent
- Pass structured request to the agent

**YOU MUST NOT:**
- Perform any operations yourself
- Invoke skills directly

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>
...
```

### Example 4: Creating a Complete Plugin

```bash
/fractary-faber-agent:create-plugin faber-data --type workflow

# Interactive wizard prompts:
# Plugin name: fractary-faber-data
# Type: workflow (FABER workflow plugin)
# Purpose: Data analysis and transformation workflows
# Workflows: analyze-dataset, transform-data, generate-report
# Dependencies: fractary-faber (core)
# Agents needed: data-director, workflow-manager
# Skills needed: 10+ skills for data operations

# Output:
# ✅ Plugin structure created: plugins/faber-data/
# ✅ plugin.json generated
# ✅ Placeholder agents created (3)
# ✅ Placeholder skills created (10)
# ✅ Placeholder commands created (5)
# ✅ README generated
# ✅ Configuration template created
# ✅ All validators passed
```

**Generated structure:**
```
plugins/faber-data/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── data-director.md
│   └── workflow-manager.md
├── skills/
│   ├── data-fetcher/
│   ├── data-cleaner/
│   ├── data-analyzer/
│   └── ... (7 more)
├── commands/
│   ├── analyze.md
│   ├── transform.md
│   └── ... (3 more)
├── config/
│   └── faber-data.example.toml
├── docs/
│   ├── README.md
│   └── getting-started.md
└── README.md
```

---

## Integration with Ecosystem

### Leverages Existing Primitives

The `faber-agent` plugin integrates seamlessly with existing plugins:

1. **Uses `fractary-work` agent** to create issues for tracking creation progress
   ```markdown
   Use the @agent-fractary-work:work-manager agent to create an issue:
   {
     "operation": "create-issue",
     "parameters": {
       "title": "Create data-analyzer agent",
       "labels": ["faber-agent", "agent-creation"]
     }
   }
   ```

2. **Uses `fractary-repo` agent** to commit generated artifacts
   ```markdown
   Use the @agent-fractary-repo:repo-manager agent to create a commit:
   {
     "operation": "create-commit",
     "parameters": {
       "message": "feat(faber-data): Add data-analyzer agent",
       "files": ["plugins/faber-data/agents/data-analyzer.md"]
     }
   }
   ```

3. **Uses `fractary-file` agent** for template loading and file operations
   ```markdown
   Use the @agent-fractary-file:file-manager agent to read template:
   {
     "operation": "read-file",
     "parameters": {
       "path": "plugins/faber-agent/templates/agent/manager.md.template"
     }
   }
   ```

4. **Uses `fractary-codex`** to sync standards docs and examples
   ```markdown
   Use the @agent-fractary-codex:sync-manager agent to sync standards:
   {
     "operation": "sync-docs",
     "parameters": {
       "pattern": "docs/standards/**/*.md"
     }
   }
   ```

### FABER Workflow Integration

Each creation workflow (agent, skill, command, plugin) follows the FABER framework:
- **Frame**: Gather requirements
- **Architect**: Design structure
- **Build**: Generate from templates
- **Evaluate**: Validate compliance
- **Release**: Save and document

This ensures the meta-plugin itself demonstrates FABER best practices.

---

## Future Extensibility

### Multi-Framework Support Architecture

While focused on Claude Code now, the plugin is architected for future multi-framework support:

```
templates/
├── claude-code/          # Claude Code native (current - Phase 1)
│   ├── agent/
│   ├── skill/
│   └── command/
│
├── openai/               # Future Phase: OpenAI Assistants API
│   ├── assistant/
│   ├── function/
│   └── tool/
│
├── langchain/            # Future Phase: LangChain
│   ├── agent/
│   ├── tool/
│   └── chain/
│
├── autogen/              # Future Phase: AutoGen
│   └── agent/
│
└── generic/              # Framework-agnostic patterns
    ├── workflow.yaml.template
    └── config.yaml.template
```

### Framework Adapter Pattern

```bash
# Future capability (Phase 5+)
/fractary-faber-agent:create-agent data-analyzer --framework openai

# Or convert existing
/fractary-faber-agent:convert agents/data-analyzer.md --to openai --output .openai/
```

### Conversion Strategy

1. **Template Mapping**: Map Claude Code constructs to target framework equivalents
2. **Validation Adaptation**: Adapt validators for framework-specific requirements
3. **Documentation Generation**: Generate framework-specific docs
4. **Testing**: Validate artifacts work in target framework

---

## Implementation Plan

### Phase 1: Foundation (Week 1-2)

**Goals:**
- Create plugin structure
- Build command → agent → skill architecture
- Develop template system
- Create basic validators

**Deliverables:**
1. Plugin directory structure created
2. Basic templates (agent, skill, command)
3. Simple template substitution engine
4. Basic XML and frontmatter validators
5. One working workflow: create-agent (simple)

**Success Criteria:**
- Can create a simple manager agent
- Agent validates successfully
- Generated agent follows standards

---

### Phase 2: Core Workflows (Week 3-4)

**Goals:**
- Complete agent creation workflow
- Complete skill creation workflow
- Complete command creation workflow
- Add comprehensive templates

**Deliverables:**
1. Full agent-creator agent with all FABER phases
2. Full skill-creator agent with all FABER phases
3. Full command-creator agent with all FABER phases
4. Enhanced templates with all variables
5. Interactive requirement gathering
6. Complete validation suite

**Success Criteria:**
- Can create production-quality agents
- Can create skills with workflow files
- Can create commands with proper frontmatter
- All validators working
- Generated artifacts pass all checks

---

### Phase 3: Advanced Features (Week 5-6)

**Goals:**
- Plugin creation workflow
- Handler creation workflow
- Advanced validation
- Quality assurance tools

**Deliverables:**
1. Plugin-creator agent
2. Handler-creator agent
3. Handler templates (multi-provider)
4. Advanced validators (structure, dependencies)
5. Documentation generator
6. Example generator

**Success Criteria:**
- Can create complete plugins
- Can create handler skills
- All validators comprehensive
- Documentation auto-generated
- Examples auto-generated

---

### Phase 4: Polish & Documentation (Week 7-8)

**Goals:**
- Comprehensive documentation
- Example gallery
- Video tutorials
- Best practices guide

**Deliverables:**
1. Complete usage guide
2. API reference for templates
3. Example gallery (10+ examples)
4. Troubleshooting guide
5. Best practices documentation
6. Migration guide (for updating existing artifacts)

**Success Criteria:**
- Documentation complete
- Examples cover all use cases
- Easy for new developers to use
- Clear migration path for existing code

---

### Phase 5: Future Enhancements (Future)

**Goals:**
- Multi-framework template support
- Framework conversion tools
- AI-assisted requirement gathering
- Visual plugin designer

**Potential Deliverables:**
1. OpenAI Assistants templates
2. LangChain templates
3. Conversion tools (Claude → OpenAI, etc.)
4. Enhanced requirement gathering with AI
5. Web-based plugin designer UI
6. Template marketplace

---

## Success Metrics

### Quantitative Metrics

1. **Consistency**: 100% of generated artifacts pass all validators
2. **Speed**: Create new agent in < 5 minutes (vs 30+ minutes manual)
3. **Quality**: Generated artifacts match or exceed hand-crafted quality (subjective but peer-reviewed)
4. **Adoption**: Used for 80%+ of new agent/skill/plugin creation within 3 months
5. **Standards Compliance**: 100% compliance with FRACTARY-PLUGIN-STANDARDS.md

### Qualitative Metrics

1. **Developer Satisfaction**: Surveys show improved developer experience
2. **Learning Curve**: New developers can create compliant artifacts on day 1
3. **Maintainability**: Easy to update standards and regenerate artifacts
4. **Evolution**: Standards evolve based on learnings, templates updated accordingly
5. **Documentation Quality**: Generated docs are clear and helpful

### Comparison Metrics

**Before `faber-agent`:**
- Read 120+ pages of standards docs
- Copy/paste from similar agents
- Manual XML structure creation
- Easy to forget critical sections
- Validation by manual review
- Inconsistent patterns emerge over time
- 30-60 minutes per agent

**After `faber-agent`:**
- Answer wizard questions (5-10 questions)
- Automatic template application
- Guaranteed XML compliance
- All critical sections included automatically
- Automatic validation with clear errors
- Perfect consistency across all artifacts
- 5 minutes per agent

**Improvement:**
- **6-12x faster** artifact creation
- **100% standards compliance** (vs ~80% manual)
- **Zero forgotten sections** (vs common mistakes)
- **Consistent quality** across all developers

---

## Key Innovations

1. **Standards as Code**: All documentation becomes executable workflows
2. **Wizard-Driven Creation**: Interactive creation with smart defaults
3. **Template Inheritance**: Base templates + specialized variants
4. **Automatic Validation**: Catch errors before they're committed
5. **Self-Documenting**: Generates docs as it generates code
6. **Framework-Agnostic Design**: Ready for multi-framework future
7. **Meta-FABER**: The plugin itself demonstrates FABER principles

---

## Risk Mitigation

### Risks and Mitigations

**Risk 1: Templates become outdated as standards evolve**
- **Mitigation**: Version templates, provide migration tools, regular reviews

**Risk 2: Generated code lacks flexibility for edge cases**
- **Mitigation**: Support template overrides, manual editing post-generation

**Risk 3: Validation too strict, slows development**
- **Mitigation**: Warnings vs errors, ability to skip validation with flag

**Risk 4: Complexity for simple use cases**
- **Mitigation**: Provide "quick" mode with minimal prompts and smart defaults

**Risk 5: Framework conversion quality varies**
- **Mitigation**: Start with Claude Code only, add frameworks incrementally with thorough testing

---

## Appendices

### Appendix A: Command Reference

```bash
# Create agent
/fractary-faber-agent:create-agent <name> --type <manager|handler>

# Create skill
/fractary-faber-agent:create-skill <name> [--handler-type <type>]

# Create command
/fractary-faber-agent:create-command <name> --invokes <agent>

# Create plugin
/fractary-faber-agent:create-plugin <name> --type <workflow|primitive|utility>

# Create handler
/fractary-faber-agent:create-handler <name> --handler-type <hosting|iac|etc>

# Validate existing artifact
/fractary-faber-agent:validate <path>

# Regenerate from template (update to new standards)
/fractary-faber-agent:regenerate <path>
```

### Appendix B: Template Variable Reference

See [Templates System](#templates-system) for complete variable reference.

### Appendix C: Validator Reference

See [Validation System](#validation-system) for complete validator reference.

### Appendix D: Related Documents

- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md` - Core standards document
- `specs/SPEC-00002-faber-architecture.md` - FABER architecture
- `specs/SPEC-00014-cli-argument-standards.md` - CLI argument standards
- `scripts/lint-command-frontmatter.sh` - Existing frontmatter linter

---

## Conclusion

The `faber-agent` plugin represents a **meta-level application of the FABER philosophy**:

- **Frame**: Centralize learnings about creating great plugins
- **Architect**: Design a system that codifies these learnings
- **Build**: Create workflows that generate compliant artifacts
- **Evaluate**: Validate every artifact against standards
- **Release**: Make consistent, high-quality plugin creation effortless

It ensures that every future plugin, agent, skill, and command benefits from all the wisdom accumulated in the fractary ecosystem, while maintaining the flexibility to evolve as new patterns emerge.

**This is not just a code generator—it's a system for perpetually improving plugin quality across the entire ecosystem.**

---

**End of Specification**
