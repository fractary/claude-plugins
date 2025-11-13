# Plugin Manifest Schema Reference

**Last Updated**: 2025-11-13
**Status**: Active

## Overview

The `.claude-plugin/plugin.json` manifest file defines the plugin's metadata and structure for Claude Code. This document provides the **canonical reference** for the manifest schema to prevent validation errors.

## Critical Rules

1. **Use ONLY the fields defined in this schema** - Any unrecognized fields will cause validation errors
2. **Commands and Skills use directory paths, not arrays** - Point to directories, not individual files
3. **Agents use an array of file paths** - Explicitly list each agent markdown file
4. **No dependency declarations** - The `requires` field is not supported in the schema

## Schema Definition

### Minimal Valid Manifest

```json
{
  "name": "fractary-example",
  "version": "1.0.0",
  "description": "Example plugin description"
}
```

### Full Valid Manifest

```json
{
  "name": "fractary-example",
  "version": "1.0.0",
  "description": "Example plugin with all optional fields",
  "commands": "./commands/",
  "agents": [
    "./agents/manager.md",
    "./agents/helper.md"
  ],
  "skills": "./skills/"
}
```

## Field Reference

### Required Fields

#### `name` (string)
- **Format**: `fractary-{plugin-name}` (lowercase, hyphenated)
- **Examples**: `fractary-repo`, `fractary-work`, `fractary-faber-cloud`
- **Purpose**: Unique identifier for the plugin

#### `version` (string)
- **Format**: Semantic versioning (`MAJOR.MINOR.PATCH`)
- **Examples**: `1.0.0`, `2.1.3`, `0.1.0-beta`
- **Purpose**: Plugin version tracking

#### `description` (string)
- **Format**: Brief, single-line description
- **Examples**:
  - `"Source control operations across GitHub, GitLab, Bitbucket, etc."`
  - `"Work item management across GitHub, Jira, Linear, etc."`
- **Purpose**: User-facing description of plugin functionality

### Optional Fields

#### `commands` (string)
- **Format**: Relative path to commands directory (must end with `/`)
- **Example**: `"./commands/"`
- **Purpose**: Directory containing command markdown files (`.md`)
- **Auto-discovery**: All `.md` files in this directory are registered as commands
- **Common mistake**: Using an array instead of a string path

#### `agents` (array of strings)
- **Format**: Array of relative paths to agent markdown files
- **Examples**:
  - `["./agents/repo-manager.md"]`
  - `["./agents/director.md", "./agents/workflow-manager.md"]`
- **Purpose**: Explicit list of agent files to load
- **Note**: Unlike commands/skills, agents must be explicitly listed

#### `skills` (string)
- **Format**: Relative path to skills directory (must end with `/`)
- **Example**: `"./skills/"`
- **Purpose**: Directory containing skill subdirectories
- **Auto-discovery**: Each subdirectory with a `SKILL.md` file is registered as a skill
- **Common mistake**: Using an array instead of a string path

## Invalid Fields

These fields are **NOT part of the schema** and will cause validation errors:

### `author` ❌
- **Error**: `Expected object, received string`
- **Reason**: Not recognized by the schema
- **Alternative**: Document authorship in README.md or package metadata

### `license` ❌
- **Error**: `Unrecognized key(s) in object: 'license'`
- **Reason**: Not recognized by the schema
- **Alternative**: Include LICENSE file in plugin root

### `requires` ❌
- **Error**: `Unrecognized key(s) in object: 'requires'`
- **Reason**: Not recognized by the schema
- **Alternative**: Document dependencies in README.md

### `hooks` ❌
- **Error**: `Invalid input`
- **Reason**: Not recognized by the schema
- **Alternative**: Hooks are configured in project `.claude/hooks/`, not in plugin manifest

### Array format for `commands` or `skills` ❌
```json
{
  "commands": [
    {
      "name": "example",
      "description": "Example command",
      "path": "commands/example.md"
    }
  ]
}
```
- **Error**: `Invalid input`
- **Reason**: Schema expects a string path, not an array
- **Correct**: `"commands": "./commands/"`

## Working Examples

### Simple Plugin (No Agents)

```json
{
  "name": "fractary-status",
  "version": "1.0.0",
  "description": "Custom Claude Code status line",
  "commands": "./commands/",
  "skills": "./skills/"
}
```

### Plugin with Single Agent

```json
{
  "name": "fractary-repo",
  "version": "2.2.0",
  "description": "Source control operations across GitHub, GitLab, Bitbucket, etc.",
  "commands": "./commands/",
  "agents": ["./agents/repo-manager.md"],
  "skills": "./skills/"
}
```

### Plugin with Multiple Agents

```json
{
  "name": "fractary-faber",
  "version": "2.0.0",
  "description": "Universal SDLC workflow framework",
  "commands": "./commands/",
  "agents": [
    "./agents/director.md",
    "./agents/workflow-manager.md"
  ],
  "skills": "./skills/"
}
```

### Minimal Plugin (Commands Only)

```json
{
  "name": "fractary-helper",
  "version": "1.0.0",
  "description": "Simple utility commands",
  "commands": "./commands/"
}
```

## Validation Checklist

Before committing a new plugin manifest, verify:

- [ ] Only uses fields from the schema (name, version, description, commands, agents, skills)
- [ ] `name` follows `fractary-{name}` format
- [ ] `version` uses semantic versioning
- [ ] `description` is a single-line string
- [ ] `commands` is a string path (if present), not an array
- [ ] `skills` is a string path (if present), not an array
- [ ] `agents` is an array of strings (if present)
- [ ] No `author`, `license`, `requires`, or `hooks` fields
- [ ] Valid JSON syntax (no trailing commas, proper quotes)

## Template

Use this template when creating new plugins:

```json
{
  "name": "fractary-{plugin-name}",
  "version": "1.0.0",
  "description": "Brief description of what this plugin does",
  "commands": "./commands/",
  "agents": ["./agents/{agent-name}.md"],
  "skills": "./skills/"
}
```

Template file: `docs/templates/plugin.json.template`

## Migration Guide

If you have an invalid manifest, follow these steps:

### Step 1: Remove Invalid Fields

Remove these fields if present:
- `author`
- `license`
- `requires`
- `hooks`

### Step 2: Fix Commands/Skills Format

Change from array format:
```json
"commands": [
  {
    "name": "example",
    "description": "...",
    "path": "commands/example.md"
  }
]
```

To string path:
```json
"commands": "./commands/"
```

### Step 3: Validate Structure

Ensure remaining fields match the schema:
- `name`, `version`, `description` are strings
- `commands`, `skills` are string paths (if present)
- `agents` is an array of strings (if present)

### Step 4: Test

Reload Claude Code and verify no plugin errors appear.

## Common Errors and Solutions

### Error: `author: Expected object, received string`

**Cause**: `author` field is not part of the schema

**Solution**: Remove the `author` field entirely

```diff
{
  "name": "fractary-example",
  "version": "1.0.0",
  "description": "Example plugin",
- "author": "Fractary",
  "commands": "./commands/"
}
```

### Error: `Unrecognized key(s) in object: 'requires'`

**Cause**: `requires` field is not part of the schema

**Solution**: Remove the `requires` field. Document dependencies in README.md instead.

```diff
{
  "name": "fractary-example",
  "version": "1.0.0",
  "description": "Example plugin",
- "requires": ["fractary-repo"],
  "commands": "./commands/"
}
```

### Error: `commands: Invalid input`

**Cause**: Using array format instead of string path

**Solution**: Change to directory path string

```diff
{
  "name": "fractary-example",
  "version": "1.0.0",
  "description": "Example plugin",
- "commands": [
-   {
-     "name": "install",
-     "description": "Install command",
-     "path": "commands/install.md"
-   }
- ]
+ "commands": "./commands/"
}
```

### Error: `hooks: Invalid input`

**Cause**: `hooks` field is not part of the schema

**Solution**: Remove the `hooks` field. Configure hooks in `.claude/hooks/` instead.

```diff
{
  "name": "fractary-example",
  "version": "1.0.0",
  "description": "Example plugin",
  "commands": "./commands/",
- "hooks": {
-   "templates": ["hooks/status-line.json"]
- }
}
```

## References

- Template: `docs/templates/plugin.json.template`
- Working examples: All manifests in `plugins/*/.claude-plugin/plugin.json`
- Plugin standards: `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`

## Changelog

- **2025-11-13**: Initial schema documentation based on validation error analysis
