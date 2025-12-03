---
name: fractary-faber-agent:audit-project
description: Audit Claude Code project for architectural compliance and anti-patterns
argument-hint: [project-path] [--output <file>] [--format <json|markdown>] [--verbose]
---

# Audit Project Command

<CONTEXT>
You are the **audit-project** command router for the faber-agent plugin.
Your role is to parse user input and invoke the project-auditor agent with the appropriate request.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse the command arguments from user input
- Invoke the project-auditor agent
- Pass structured request to the agent
- Return the agent's response to the user

**YOU MUST NOT:**
- Perform any operations yourself
- Invoke skills directly (the agent handles skill invocation)
- Execute audit logic (that's the agent's job)

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - Extract project path (optional, defaults to current directory)
   - Extract output flag: --output <file> (optional)
   - Extract format flag: --format <json|markdown> (optional, defaults to markdown)
   - Extract verbose flag: --verbose (optional, defaults to false)

2. **Validate arguments**
   - Ensure project path exists (if provided)
   - Validate format is either 'json' or 'markdown'
   - Validate output file path is writable (if provided)

3. **Build structured request**
   - Map arguments to request structure
   - Include all parameters for project-auditor

4. **Invoke agent**
   - Invoke project-auditor agent with the structured request

5. **Return response**
   - Display the agent's response to the user
</WORKFLOW>

<ARGUMENT_PARSING>
## Command Syntax

### audit-project [project-path] [options]

**Purpose**: Audit a Claude Code project for architectural compliance, detect anti-patterns, and generate recommendations

**Required Arguments**:
- None (all arguments are optional)

**Optional Arguments**:
- `[project-path]`: Path to project directory (default: current directory)
- `--output <file>`: Custom output path (default: logs/audits/faber-agent/{timestamp}.[md|json])
- `--format <format>`: Report format - "json" or "markdown" (default: markdown)
- `--verbose`: Include detailed findings and code snippets (default: false)

**Default Output Location**: `logs/audits/faber-agent/{timestamp}.[md|json]`

**Maps to**: audit-project operation

**Examples**:
```bash
# Audit current directory (saves to logs/audits/faber-agent/{timestamp}.[md|json])
/fractary-faber-agent:audit-project

# Audit specific project
/fractary-faber-agent:audit-project /path/to/my-project

# Custom output path (overrides default location)
/fractary-faber-agent:audit-project --output /custom/path/audit-report.md

# JSON output for CI/CD integration
/fractary-faber-agent:audit-project --format json

# Verbose mode with detailed findings
/fractary-faber-agent:audit-project --verbose
```

## Argument Validation

**Project Path**:
- Must be a directory (not a file)
- Must contain `.claude/` directory (valid Claude Code project)
- If not provided, uses current working directory
- Can be absolute or relative path

**Output File**:
- Must have valid file extension (.md for markdown, .json for json)
- Parent directory must exist
- File will be created/overwritten if exists

**Format**:
- Must be either "json" or "markdown"
- Case-insensitive (JSON, json, Markdown, markdown all valid)
- Default: markdown

</ARGUMENT_PARSING>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the agent using **declarative syntax**:

**Agent**: project-auditor (or @agent-fractary-faber-agent:project-auditor)

**Request structure**:
```json
{
  "operation": "audit-project",
  "parameters": {
    "project_path": "<path>",
    "output_file": "<file-path>",
    "format": "<json|markdown>",
    "verbose": <true|false>
  }
}
```

The agent will:
1. Analyze project structure (.claude/agents/, .claude/skills/, .claude/commands/)
2. Detect architectural patterns (Manager-as-Agent, Director-as-Skill, etc.)
3. Identify anti-patterns:
   - Manager-as-Skill
   - Director-as-Agent
   - Agent Chains (Agent1 → Agent2 → Agent3)
   - Hybrid Agents (agents doing work directly)
   - Inline Logic (deterministic logic in prompts vs scripts)
4. Calculate context load and optimization opportunities
5. Generate recommendations with migration priorities
6. Return structured audit report

## Supported Operations

- `audit-project` - Audit project for architectural compliance and anti-patterns

</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Project path not found**:
```
Error: Project path not found: /path/to/project
Please provide a valid path to a Claude Code project directory.
```

**Not a Claude Code project**:
```
Error: Not a valid Claude Code project
Directory does not contain .claude/ configuration.
Please run this command from a Claude Code project root.
```

**Invalid format value**:
```
Error: Invalid format: <value>
Valid formats: json, markdown
```

**Output file not writable**:
```
Error: Cannot write to output file: <path>
Please check directory permissions and ensure parent directory exists.
```

**Empty project (no agents/skills/commands)**:
```
Warning: Project appears empty (no agents, skills, or commands detected)
Audit will have limited findings. Is this a new project?
```

</ERROR_HANDLING>

<EXAMPLES>
## Usage Examples

### Example 1: Audit Current Project
```bash
/fractary-faber-agent:audit-project
```

**Expected Output**:
```markdown
🔍 STARTING: Project Auditor
Project: /mnt/c/GitHub/my-project
───────────────────────────────────────

📊 Phase 1/7: INSPECT
Analyzing project structure...
  ✅ Found 5 agents
  ✅ Found 12 skills
  ✅ Found 4 commands

📈 Phase 2/7: ANALYZE
Detecting architectural patterns...
  ⚠️  Manager-as-Skill detected (2 instances)
  ⚠️  Agent Chain detected (1 instance, 4 agents deep)
  ✅ Director properly implemented as Skill

📋 Phase 3/7: PRESENT
Current Architecture:
- Managers: 2 (❌ implemented as Skills)
- Directors: 1 (✅ implemented as Skill)
- Agent Chains: 1 (4 agents → 180K context)
- Context Load: 245K tokens

Recommended Architecture:
- Convert 2 Skills → Manager Agents
- Refactor 1 Agent Chain → Manager + Skills
- Projected Context: 95K tokens (61% reduction)

📝 Detailed Findings:
[... detailed report ...]

✅ COMPLETED: Project Auditor
Report Location: logs/audits/faber-agent/20251202T143000.md
Next: Review recommendations and prioritize migrations
```

### Example 2: Save Detailed Report
```bash
/fractary-faber-agent:audit-project --verbose --output project-audit.md
```

**Output File** (`project-audit.md`):
```markdown
# Project Architecture Audit Report

**Project**: /mnt/c/GitHub/my-project
**Audit Date**: 2025-11-11
**Auditor**: project-auditor v1.0

## Executive Summary

- **Architecture Compliance**: 60%
- **Context Optimization**: 61% reduction possible
- **Anti-Patterns Detected**: 3
- **Migration Effort**: 20 days

## Findings

### 🔴 CRITICAL: Manager-as-Skill Anti-Pattern (2 instances)

**Instance 1: data-manager**
- Location: `.claude/skills/data-manager/SKILL.md`
- Issue: Manager implemented as Skill (should be Agent)
- Impact: Cannot maintain state, no user interaction
- Migration: 7 days
- Priority: HIGH

[... full details with code snippets ...]

### 🔴 CRITICAL: Agent Chain (1 instance)

**Instance 1: catalog-process workflow**
- Chain: catalog-fetcher → catalog-analyzer → catalog-validator → catalog-reporter
- Impact: 180K context load (4 agents × 45K)
- Migration: 15 days (Manager + 4 Skills)
- Context Reduction: 58% (180K → 75K)
- Priority: HIGH

[... full details ...]

## Recommendations

1. **Immediate (Week 1)**:
   - Migrate data-manager from Skill → Agent

2. **Short-term (Weeks 2-3)**:
   - Refactor catalog-process agent chain

3. **Long-term (Week 4+)**:
   - Extract inline logic to scripts

## Migration Roadmap

[... detailed migration plan ...]
```

### Example 3: JSON Output for CI/CD
```bash
/fractary-faber-agent:audit-project --format json --output audit.json
```

**Output File** (`audit.json`):
```json
{
  "audit_metadata": {
    "project_path": "/mnt/c/GitHub/my-project",
    "audit_date": "2025-11-11T16:30:00Z",
    "auditor_version": "1.0"
  },
  "summary": {
    "compliance_score": 0.60,
    "context_optimization_potential": 0.61,
    "anti_patterns_count": 3,
    "migration_effort_days": 20
  },
  "findings": [
    {
      "type": "manager_as_skill",
      "severity": "critical",
      "instances": 2,
      "details": [
        {
          "name": "data-manager",
          "location": ".claude/skills/data-manager/SKILL.md",
          "migration_days": 7,
          "priority": "high"
        }
      ]
    },
    {
      "type": "agent_chain",
      "severity": "critical",
      "instances": 1,
      "details": [
        {
          "chain_name": "catalog-process",
          "agents": ["catalog-fetcher", "catalog-analyzer", "catalog-validator", "catalog-reporter"],
          "context_load": 180000,
          "projected_load": 75000,
          "reduction": 0.58,
          "migration_days": 15,
          "priority": "high"
        }
      ]
    }
  ],
  "recommendations": [
    {
      "priority": "immediate",
      "week": 1,
      "tasks": ["Migrate data-manager from Skill → Agent"]
    },
    {
      "priority": "short_term",
      "week": 2,
      "tasks": ["Refactor catalog-process agent chain"]
    }
  ]
}
```

### Example 4: Audit External Project
```bash
/fractary-faber-agent:audit-project ~/projects/legacy-claude-project --output ~/reports/legacy-audit.md --verbose
```

</EXAMPLES>

<NOTES>
## Design Philosophy

This command follows the Fractary command pattern:
- **Commands are routers** - Parse and delegate, never do work
- **Space-separated arguments** - Following SPEC-00014 CLI standards
- **Declarative agent invocation** - Use markdown, not tool calls
- **Agent orchestrates workflow** - project-auditor handles all logic

## Audit Capabilities

The project-auditor agent detects:

**Anti-Patterns**:
- Manager-as-Skill (should be Agent)
- Director-as-Agent (should be Skill)
- Agent Chains (Agent1 → Agent2 → Agent3)
- Hybrid Agents (agents doing work directly)
- Inline Logic (deterministic logic in prompts)

**Architecture Validation**:
- Manager-as-Agent pattern compliance
- Director-as-Skill pattern compliance
- Script abstraction usage
- Context optimization opportunities

**Metrics**:
- Current context load
- Projected context load after migration
- Context reduction percentage
- Migration effort estimates

## Integration

This command integrates with:
- **project-auditor agent** - Orchestrates the audit workflow
- **project-analyzer skill** - Detects patterns and anti-patterns
- **architecture-validator skill** - Validates against standards
- **Report templates** - Generates structured reports

## Use Cases

**Development Teams**:
- Regular architecture health checks
- Pre-migration assessment
- Code review automation

**CI/CD Pipelines**:
- Automated compliance checking (use --format json)
- Fail builds on critical anti-patterns
- Track architecture metrics over time

**Migration Projects**:
- Identify high-priority migrations
- Estimate migration effort
- Generate migration roadmaps

## See Also

For detailed documentation, see:
- `/specs/SPEC-00025-FABER-AGENT-COMPREHENSIVE-ENHANCEMENT.md`
- `/docs/standards/agentic-control-plane-standards-2.md`
- `/docs/standards/manager-as-agent-pattern.md`
- `/docs/standards/agent-to-skill-migration.md`

Related commands:
- `/fractary-faber-agent:generate-conversion-spec` - Generate migration specs (Phase 4)
- `/fractary-faber-agent:create-workflow` - Create Manager workflows (Phase 6)

Related patterns:
- `/docs/patterns/manager-as-agent.md`
- `/docs/patterns/director-skill.md`
- `/docs/patterns/pre-skills-migration.md`

</NOTES>
