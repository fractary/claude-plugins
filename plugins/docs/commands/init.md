---
name: fractary-docs:init
description: Initialize and configure the fractary-docs plugin
---

# Docs Plugin Initialization

Initialize the fractary-docs plugin with configuration for documentation management.

<CONTEXT>
You are the init command for the fractary-docs plugin. Your role is to parse arguments and create initial configuration for documentation operations.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments
2. NEVER do configuration work directly without user awareness
3. ALWAYS create necessary directories for documentation
4. NEVER overwrite existing configuration without confirmation
</CRITICAL_RULES>

<INPUTS>
Command-line arguments (all optional):
- `--global`: Save configuration to user-wide location (~/.config/fractary/docs/)
- `--template-dir <path>`: Custom template directory for project-specific templates
- `--docs-root <path>`: Override default documentation root (default: docs/)
- `--no-codex-sync`: Disable codex sync in front matter
- `--non-interactive`: Use defaults without prompts

Examples:
```bash
# Interactive setup with defaults
/fractary-docs:init

# Setup with custom docs location
/fractary-docs:init --docs-root documentation/

# Setup globally with custom templates
/fractary-docs:init --global --template-dir .templates/docs/

# Non-interactive with defaults
/fractary-docs:init --non-interactive
```
</INPUTS>

<WORKFLOW>

## Step 1: Welcome Message

Display welcome banner:
```
📚 Fractary Docs Plugin Configuration
───────────────────────────────────────────

This wizard will configure documentation management for your project.

Features:
  • 10+ document templates (ADRs, design docs, runbooks, API specs, etc.)
  • Document updating with structure preservation
  • Validation and quality checks
  • Cross-reference management and indexing
  • Codex integration for knowledge management

Press Ctrl+C at any time to cancel.
───────────────────────────────────────────
```

## Step 2: Parse Arguments

Extract from user input:
- `config_scope`: "global" or "project" (default: "project")
- `docs_root`: documentation root path (default: "docs")
- `template_dir`: custom template directory or null
- `codex_sync`: enable codex sync (default: true)
- `interactive`: true or false (default: true)

Validation:
- Validate paths are safe (no path traversal)
- If `docs_root` is outside project, warn user
- If `template_dir` specified, verify it exists or will be created

## Step 3: Check Existing Configuration

Check if configuration already exists:
- Project: `.fractary/plugins/docs/config.json`
- Global: `~/.config/fractary/docs/config.json`

If exists:
- Display current configuration
- Ask: "Configuration already exists. [O]verwrite, [U]pdate, or [C]ancel?"
- If overwrite: Proceed with new configuration
- If update: Merge with existing (preserve handler configs)
- If cancel: Exit

## Step 4: Prompt for Settings (if interactive)

If interactive mode, ask:

1. **Documentation Root**:
   ```
   Where should documentation be stored?
   [docs] (default):
   ```

2. **Custom Templates**:
   ```
   Do you want to use custom templates? [y/N]:
   If yes, enter template directory [.templates/docs]:
   ```

3. **Codex Sync**:
   ```
   Enable codex sync for documentation? [Y/n]:
   ```

4. **Validation on Generate**:
   ```
   Validate documentation after generation? [Y/n]:
   ```

5. **Auto-Update Index**:
   ```
   Automatically update documentation index? [Y/n]:
   ```

## Step 5: Create Configuration

Build configuration object:
```json
{
  "schema_version": "1.0",
  "output_paths": {
    "documentation": "{docs_root}",
    "adrs": "{docs_root}/architecture/adrs",
    "designs": "{docs_root}/architecture/designs",
    "runbooks": "{docs_root}/operations/runbooks",
    "api_docs": "{docs_root}/api",
    "guides": "{docs_root}/guides",
    "testing": "{docs_root}/testing",
    "deployments": "{docs_root}/deployments"
  },
  "templates": {
    "custom_template_dir": "{template_dir}",
    "use_project_templates": true
  },
  "frontmatter": {
    "always_include": true,
    "codex_sync": {codex_sync},
    "default_fields": {
      "author": "Claude Code",
      "generated": true
    }
  },
  "validation": {
    "lint_on_generate": true,
    "check_links_on_generate": false,
    "required_sections": {
      "adr": ["Status", "Context", "Decision", "Consequences"],
      "design": ["Overview", "Architecture", "Implementation"],
      "runbook": ["Purpose", "Prerequisites", "Steps", "Troubleshooting"]
    }
  },
  "linking": {
    "auto_update_index": true,
    "check_broken_links": true,
    "generate_graph": true
  }
}
```

## Step 6: Create Directories

Create documentation directory structure:
```bash
{docs_root}/
├── architecture/
│   ├── adrs/
│   └── designs/
├── operations/
│   └── runbooks/
├── api/
├── guides/
├── testing/
└── deployments/
```

If directories exist, skip with message.

## Step 7: Save Configuration

Save configuration to:
- Project: `.fractary/plugins/docs/config.json`
- Global: `~/.config/fractary/docs/config.json`

Create parent directories if needed:
- Project: `.fractary/plugins/docs/`
- Global: `~/.config/fractary/docs/`

## Step 8: Create Initial Documentation Index

Create initial `{docs_root}/INDEX.md`:
```markdown
# Documentation Index

Last Updated: {current_date}

## Architecture

(No documents yet)

## Operations

(No documents yet)

## API

(No documents yet)

## Guides

(No documents yet)

## Testing

(No documents yet)

---

Generated by fractary-docs plugin
```

## Step 9: Display Results

Show final summary:
```
✅ Configuration complete!

Documentation Root: {docs_root}/
Configuration: {config_path}
Codex Sync: {enabled/disabled}
Templates: {built-in or custom_dir}

Created directories:
  ✓ {docs_root}/architecture/adrs/
  ✓ {docs_root}/architecture/designs/
  ✓ {docs_root}/operations/runbooks/
  ✓ {docs_root}/api/
  ✓ {docs_root}/guides/
  ✓ {docs_root}/testing/
  ✓ {docs_root}/deployments/

Next steps:
  • Generate an ADR: /fractary-docs:generate adr "Your decision title"
  • Generate a design doc: /fractary-docs:generate design "Feature name"
  • View configuration: cat {config_path}
  • See all templates: plugins/docs/skills/doc-generator/templates/

Documentation: plugins/docs/README.md
```

</WORKFLOW>

<ERROR_HANDLING>
- Invalid path arguments: Display error with safe path examples
- Permission denied: Show fix commands (chmod, mkdir with sudo if needed)
- Configuration directory creation fails: Show manual creation steps
- Docs root outside project: Warn and ask for confirmation
- Template directory doesn't exist: Offer to create it
</ERROR_HANDLING>

<OUTPUTS>
Success: Configuration saved message with directory structure and next steps
Failure: Error message with troubleshooting guidance
</OUTPUTS>
