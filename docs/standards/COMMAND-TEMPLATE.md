# Command Template - Router Pattern

This template demonstrates the correct pattern for commands that route to manager agents.

## Structure

```markdown
---
name: plugin-name:command-name
description: Brief description of what the command does
argument-hint: subcommand <args> | subcommand2 <args>
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
- Invoke skills directly (agents handle skill invocation)
- Execute platform-specific logic (that's the agent's job)

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - Extract subcommand (create, fetch, update, etc.)
   - Parse required and optional arguments
   - Validate required arguments are present

2. **Build structured request**
   - Map subcommand to operation name
   - Package parameters

3. **Invoke agent**
   - Use declarative invocation: "Invoke [plugin-name:agent-name] agent"
   - Pass the structured request
   - Example: Invoke fractary-work:work-manager agent with the request

4. **Return response**
   - The agent will handle the operation and return results
   - Display results to the user
</WORKFLOW>

<ARGUMENT_PARSING>
## Subcommands

### subcommand-name <arg1> [--option value]
**Purpose**: Brief description

**Required Arguments**:
- `arg1`: Description

**Optional Arguments**:
- `--option`: Description (default: value)

**Maps to**: operation-name

**Example**:
```
/plugin:command subcommand-name "value" --option foo
→ Invoke agent with {"operation": "operation-name", "parameters": {"arg1": "value", "option": "foo"}}
```

[Repeat for each subcommand]
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Example 1
/plugin:command subcommand "arg"

# Example 2
/plugin:command subcommand "arg" --option value

# Example 3
/plugin:command subcommand2 --filter criteria
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the agent using declarative syntax:

**Syntax**: "Invoke [plugin-name:agent-name] agent"

**Alternative syntax**: "Invoke @agent-[plugin-name]:[agent-name]"

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
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing required argument**:
```
Error: <arg> is required
Usage: /plugin:command subcommand <arg> [options]
```

**Invalid subcommand**:
```
Error: Unknown subcommand: <subcommand>
Available: subcommand1, subcommand2, subcommand3
```

**Invalid argument format**:
```
Error: Invalid <arg> format
Expected: <format description>
```
</ERROR_HANDLING>
```

## Key Principles

1. **Commands are routers** - They parse and route, they don't do work
2. **Agent invocation is declarative** - State "Invoke [plugin:agent] agent"
3. **Agents handle skills** - Commands never invoke skills directly
4. **Keep it concise** - Detailed docs go in `/docs/commands/`, not the command file
5. **Structure is consistent** - All commands follow this XML-tagged pattern

## Invocation Flow

```
User
  ↓ types /plugin:command subcommand args
Command file
  ↓ expands in context with instructions
Claude
  ↓ parses arguments per <ARGUMENT_PARSING>
  ↓ builds request per <AGENT_INVOCATION>
  ↓ invokes agent: "Invoke plugin:agent-name agent"
Agent (plugin:agent-name)
  ↓ receives structured request
  ↓ routes to appropriate skill
  ↓ returns results
Claude
  ↓ displays results to user
```

## What Goes Where

**In the command file** (this template):
- Frontmatter (name, description, argument-hint)
- CONTEXT, CRITICAL_RULES, WORKFLOW sections
- Argument parsing logic
- Brief usage examples
- Agent invocation instructions

**In `/docs/commands/[command-name].md`** (detailed reference):
- Extensive documentation (300-500 lines)
- Detailed subcommand descriptions
- Platform-specific behavior notes
- Integration details
- Advanced usage examples
- Best practices
- Troubleshooting

**In the agent file**:
- Operation routing logic
- Skill selection/invocation
- Workflow orchestration

**In skill files**:
- Actual implementation
- Platform-specific scripts
- Error handling

## See Also

- [FRACTARY-PLUGIN-STANDARDS.md](FRACTARY-PLUGIN-STANDARDS.md) - Full plugin standards
- [fractary-faber-architecture.md](../specs/fractary-faber-architecture.md) - Architecture overview
