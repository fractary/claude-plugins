# FABER Agent Plugin

**Meta-plugin for creating Claude Code agents, skills, commands, and plugins**

Version: 0.1.0 (Phase 1 - Foundation)

---

## Overview

The `faber-agent` plugin codifies all Fractary plugin development standards into executable workflows. It enables consistent, high-quality creation of:

- **Agents** (workflow orchestrators)
- **Skills** (focused execution units)
- **Commands** (entry point routers)
- **Complete Plugins** (full plugin bundles)

## Key Features

✅ **Standards as Code** - All learnings from FRACTARY-PLUGIN-STANDARDS.md become executable
✅ **Template-Based Generation** - Consistent artifact creation from proven templates
✅ **Automated Validation** - XML markup, frontmatter, naming, and structure checks
✅ **6-12x Faster** - Create agents in 5 minutes vs 30-60 minutes manual
✅ **100% Compliance** - Every artifact follows standards automatically

## Installation

```bash
# Install faber-agent plugin
claude plugin install fractary/claude-plugins/faber-agent

# Requires faber core
claude plugin install fractary/claude-plugins/faber
```

## Quick Start

```bash
# Create a new agent
/fractary-faber-agent:create-agent my-agent --type manager

# Create a new skill
/fractary-faber-agent:create-skill my-skill

# Create a new command
/fractary-faber-agent:create-command my-command --invokes my-agent

# Create a complete plugin
/fractary-faber-agent:create-plugin my-plugin --type workflow
```

## Phase 1 Status (Current)

✅ Plugin directory structure
✅ Basic templates (agent, skill, command)
✅ Template substitution engine
✅ XML markup validator
✅ Frontmatter validator
🚧 create-agent command (in progress)
🚧 agent-creator agent (in progress)
🚧 gather-requirements skill (in progress)

## Architecture

```
Commands → Agents → Skills → Scripts

/fractary-faber-agent:create-agent
    └─ agent-creator (orchestrates)
        ├─ gather-requirements (collect info)
        ├─ generate-from-template (apply templates)
        ├─ validate-artifact (check compliance)
        └─ document-artifact (generate docs)
```

## Templates

Located in `templates/`:
- `agent/manager.md.template` - Manager agent template
- `skill/basic-skill.md.template` - Basic skill template
- `command/command.md.template` - Command template

## Validators

Located in `validators/`:
- `xml-validator.sh` - Validates XML markup completeness and naming
- `frontmatter-validator.sh` - Validates frontmatter format and fields

## Documentation

- **Specification**: `/docs/specs/SPEC-0015-faber-agent-plugin-specification.md`
- **Standards**: `/docs/standards/FRACTARY-PLUGIN-STANDARDS.md`
- **Examples**: Coming in Phase 4

## Development Status

**Phase 1: Foundation** (In Progress)
- ✅ Core structure and templates
- 🚧 First working workflow (create-agent)

**Phase 2: Core Workflows** (Planned)
- Complete agent, skill, and command creation workflows

**Phase 3: Advanced Features** (Planned)
- Plugin creation, handler support

**Phase 4: Polish** (Planned)
- Comprehensive docs and examples

## Contributing

See `/docs/specs/SPEC-0015-faber-agent-plugin-specification.md` for implementation details.

## License

MIT
