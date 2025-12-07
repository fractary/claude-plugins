# FABER Agent Plugin

**Meta-plugin for creating, auditing, and migrating Claude Code agents, skills, and workflows**

Version: 0.5.0 (Best Practices Update)

---

## Best Practices (Start Here)

Before creating agents, skills, or workflows, read the **[Best Practices Guide](docs/BEST-PRACTICES.md)**.

**Key Principles (v2.0):**
- **Projects create Skills, FABER handles orchestration** - Use core `faber-director` and `faber-manager`
- **No project-specific directors or managers** - These are anti-patterns
- **FABER workflow configs** - Define custom workflows via `.fractary/plugins/faber/workflows/`
- **Skills for domain operations** - Validator, processor, reporter, etc.
- **Documentation is mandatory** - Skills that make changes MUST update docs
- **Debugger knowledge base** - Maintain troubleshooting log
- **Plugin integrations** - Use fractary-docs, fractary-spec, fractary-logs, etc.

---

## Overview

The `faber-agent` plugin codifies all Fractary plugin development standards into executable workflows. It enables consistent, high-quality creation of agents, skills, and workflows, while detecting and fixing architectural anti-patterns.

### What It Does

**Create:**
- **Agents** (workflow orchestrators with full tool access)
- **Skills** (focused execution units with scripts)
- **Workflows** (complete multi-phase workflows with Manager-as-Agent pattern)
- **Plugins** (complete plugin bundles)

**Audit & Fix:**
- **Detect anti-patterns** (Manager-as-Skill, agent chains, hybrid agents, inline scripts)
- **Generate conversion specs** (step-by-step fix plans)
- **Apply conversions** (automated refactoring)
- **Validate compliance** (Manager-as-Agent pattern verification)

---

## Key Features

✅ **Standards as Code** - All plugin development standards become executable workflows
✅ **Workflow Creation** - Generate complete 7-phase workflows or iterative Builder/Debugger patterns
✅ **Anti-Pattern Detection** - Automatic audit finds architectural issues
✅ **Conversion System** - Automated refactoring with conversion specifications
✅ **Migration Guides** - Comprehensive guides for all anti-pattern fixes
✅ **Template-Based Generation** - Consistent artifact creation from proven templates
✅ **Automated Validation** - XML markup, frontmatter, naming, and structure checks
✅ **6-12x Faster** - Create workflows in 5-10 minutes vs manual 60+ minutes
✅ **100% Compliance** - Every artifact follows Manager-as-Agent pattern automatically

---

## Installation

```bash
# Install faber-agent plugin
claude plugin install fractary/claude-plugins/faber-agent

# Requires faber core
claude plugin install fractary/claude-plugins/faber
```

---

## Quick Start

### Create a Workflow

```bash
# Create a 7-phase data processing workflow
/fractary-faber-agent:create-workflow csv-processor \
  --pattern multi-phase \
  --domain data \
  --batch

# Create an iterative build-fix workflow
/fractary-faber-agent:create-workflow ts-builder \
  --pattern builder-debugger \
  --domain code \
  --max-iterations 5
```

### Audit Your Plugin

```bash
# Audit for anti-patterns
/fractary-faber-agent:audit /plugins/my-plugin

# Generate conversion specifications
/fractary-faber-agent:audit /plugins/my-plugin --generate-specs

# Apply a conversion
/fractary-faber-agent:apply-conversion /tmp/conversion-specs/fix-20250111.json
```

### Create Components

```bash
# Create a Manager agent
/fractary-faber-agent:create-agent my-manager --type manager

# Create a specialist skill with scripts
/fractary-faber-agent:create-skill my-skill

# Create a command router
/fractary-faber-agent:create-command my-command --invokes my-manager

# Create a complete plugin
/fractary-faber-agent:create-plugin my-plugin --type workflow
```

---

## Implementation Status

**Phase 1: Foundation** ✅ Complete
- ✅ Plugin directory structure
- ✅ Basic templates (agent, skill, command)
- ✅ Template substitution engine
- ✅ XML markup validator
- ✅ Frontmatter validator
- ✅ create-agent workflow

**Phase 2: Core Workflows** ✅ Complete
- ✅ create-skill workflow
- ✅ create-command workflow
- ✅ gather-requirements skill
- ✅ generate-from-template skill
- ✅ validate-artifact skill

**Phase 3: Advanced Features** ✅ Complete
- ✅ create-plugin workflow
- ✅ Plugin structure generation
- ✅ Handler skill template and creation
- ✅ Advanced validation (naming, cross-references)

**Phase 4: SPEC-025 Implementation** ✅ Complete
- ✅ Audit system (anti-pattern detection)
- ✅ Conversion specification system
- ✅ Workflow creation system (multi-phase, builder-debugger)
- ✅ Project auditing (architectural analysis)
- ✅ Workflow validation (Manager-as-Agent compliance)
- ✅ Migration guides (4 guides: agent chains, hybrid agents, script extraction, manager inversion)
- ✅ Usage guides (workflow creation, audit, conversion specs)
- ✅ Complete examples (CSV processor, TypeScript builder, conversions)

---

## Architecture

### Component Creation

```
Commands → Agents → Skills → Scripts

/fractary-faber-agent:create-workflow
    └─ workflow-creator (Manager Agent)
        ├─ workflow-designer (generates all components)
        ├─ workflow-validator (validates compliance)
        └─ document-workflow (generates docs)
```

### Audit & Conversion

```
/fractary-faber-agent:audit
    └─ project-auditor (Manager Agent)
        ├─ pattern-detector (finds anti-patterns)
        ├─ spec-generator (creates conversion specs)
        └─ impact-analyzer (estimates savings)

/fractary-faber-agent:apply-conversion
    └─ conversion-executor (Manager Agent)
        ├─ spec-validator (validates conversion spec)
        ├─ file-modifier (applies changes)
        └─ rollback-manager (creates backups)
```

---

## Workflow Patterns

### Multi-Phase (7-Phase Standard)

Best for: Data processing, deployments, migrations

**Structure:**
1. **GATHER/INSPECT** - Collect input data
2. **ANALYZE/VALIDATE** - Process and validate
3. **PRESENT** - Show results to user
4. **APPROVE** - Get user decision
5. **EXECUTE** - Perform main work
6. **VERIFY** - Validate results
7. **REPORT** - Provide summary

**Example:**
```bash
/fractary-faber-agent:create-workflow data-processor \
  --pattern multi-phase \
  --description "Process CSV files with validation" \
  --batch
```

**Generated:**
- Manager Agent (orchestrates 7 phases)
- Director Skill (batch coordination)
- 4 Specialist Skills (fetch, validate, process, verify)
- Command Router
- All scripts

### Builder/Debugger (Iterative Fixing)

Best for: Build processes, test fixing, error resolution

**Structure:**
```
Iteration Loop (max N):
  1. INSPECT (Observer - WHAT IS)
  2. ANALYZE (Analyzer - WHY + HOW)
  → If issues:
    3. PRESENT
    4. APPROVE
    5. BUILD (Executor - DO)
    6. VERIFY
    → Repeat until resolved
  → If no issues: REPORT success
```

**Example:**
```bash
/fractary-faber-agent:create-workflow code-fixer \
  --pattern builder-debugger \
  --max-iterations 5
```

**Generated:**
- Manager Agent (iterative loop)
- Inspector Skill (observe state)
- Debugger Skill (analyze + recommend)
- Builder Skill (execute fixes)
- Knowledge Base templates

---

## Anti-Pattern Detection

### Patterns Detected

**1. Project-Specific Directors** (NEW in v2.0)
- `{project}-director` skills
- Custom `/{project}-direct` commands
- Pattern expansion in project code

**2. Project-Specific Managers** (NEW in v2.0)
- `{project}-manager` agents
- Orchestration logic in project files
- Custom workflow coordination

**3. Agent Chains**
- Sequential agent invocations (A → B → C)
- Context accumulation (60K+ tokens)
- Complex state passing

**4. Hybrid Agents**
- Agents doing execution work directly
- Bash commands in agent files
- Mixed orchestration + execution

**5. Inline Scripts**
- Bash logic in markdown instead of scripts/
- Deterministic operations in LLM context
- Not independently testable

### Running Audits

```bash
# Audit single plugin
/fractary-faber-agent:audit /plugins/my-plugin

# Audit all plugins
/fractary-faber-agent:audit-all

# Filter by severity
/fractary-faber-agent:audit /plugins/my-plugin --severity critical

# Filter by pattern
/fractary-faber-agent:audit /plugins/my-plugin --pattern manager-as-skill
```

---

## Conversion System

### Conversion Specifications

Structured JSON files describing:
- What anti-pattern was detected
- Which files are affected
- Step-by-step fix plan
- Expected impact (context savings)
- Rollback procedures

### Applying Conversions

```bash
# Review a conversion spec
/fractary-faber-agent:review-conversion /tmp/specs/fix-20250111.json

# Apply conversion (interactive)
/fractary-faber-agent:apply-conversion /tmp/specs/fix-20250111.json

# Rollback if needed
/fractary-faber-agent:rollback-conversion /tmp/specs/fix-20250111.json
```

### Typical Results

**Manager-as-Skill Inversion:**
- Context reduction: 40-60% (~5K tokens)
- New capabilities: User approval gates, state management
- Fix time: 5-10 minutes

**Agent Chain Refactor:**
- Context reduction: 55-75% (~45K tokens)
- Centralized orchestration
- Fix time: 15-30 minutes

**Hybrid Agent Split:**
- Context reduction: 20-40% (~6K tokens)
- Reusable execution skills
- Fix time: 10-20 minutes

**Script Extraction:**
- Context reduction: 50-70% (~2K tokens)
- Independently testable
- Fix time: 5-10 minutes

---

## Commands Reference

### Workflow Creation

- `/fractary-faber-agent:create-workflow <name> --pattern <pattern>` - Create complete workflow
  - `--pattern multi-phase` - 7-phase standard workflow
  - `--pattern builder-debugger` - Iterative fixing workflow
  - `--domain <data|code|api|infrastructure>` - Domain categorization
  - `--batch` - Enable batch operations with Director
  - `--max-iterations <n>` - Max iterations (builder-debugger only)

### Audit & Conversion

- `/fractary-faber-agent:audit <path>` - Audit plugin for anti-patterns
  - `--severity <critical|warning|all>` - Filter by severity
  - `--pattern <pattern>` - Filter by specific anti-pattern
  - `--output <text|json|markdown>` - Output format
  - `--generate-specs` - Auto-generate conversion specs

- `/fractary-faber-agent:audit-all` - Audit all plugins

- `/fractary-faber-agent:review-conversion <spec-file>` - Review conversion spec

- `/fractary-faber-agent:apply-conversion <spec-file>` - Apply conversion interactively

- `/fractary-faber-agent:rollback-conversion <spec-file>` - Rollback conversion

### Validation

- `/fractary-faber-agent:validate <workflow-name>` - Validate workflow compliance
  - Checks Manager is Agent
  - Checks Director is Skill
  - Validates tool access
  - Checks scripts exist

### Component Creation

- `/fractary-faber-agent:create-agent <name> --type <manager|handler>` - Create an agent

- `/fractary-faber-agent:create-skill <name>` - Create a skill
  - `--handler-type <type>` - Create handler skill

- `/fractary-faber-agent:create-command <name> --invokes <agent>` - Create command

- `/fractary-faber-agent:create-plugin <name>` - Create plugin
  - `--type <workflow|primitive|utility>` - Plugin type

---

## Templates

### Workflow Templates

Located in `templates/workflow/`:
- `specialist-skill-with-scripts.md.template` - General specialist skill
- `inspector-skill.md.template` - Inspector (Observer role)
- `debugger-skill.md.template` - Debugger (Analyzer role)
- `builder-skill.md.template` - Builder (Executor role)
- `troubleshooting-kb.md.template` - Knowledge base article
- `faber-workflow-config.json.template` - FABER workflow configuration

### Component Templates

Located in `templates/`:
- `skill/basic-skill.md.template` - Basic skill
- `skill/handler-skill.md.template` - Handler skill (multi-provider)
- `command/command.md.template` - Command router (routes to FABER)
- `plugin/plugin.json.template` - Plugin manifest
- `plugin/README.md.template` - Plugin README

**Note:** Manager and Director templates are deprecated. Projects should use core FABER orchestration with workflow configs.

---

## Validators

Located in `skills/workflow-validator/scripts/`:
- `skill-script-validator.sh` - Validates skill has scripts/ directory
- `anti-pattern-detector.sh` - Detects project-specific directors/managers (ERROR)

Located in `validators/`:
- `xml-validator.sh` - Validates XML markup completeness
- `frontmatter-validator.sh` - Validates frontmatter format
- `naming-validator.sh` - Validates naming conventions
- `cross-reference-validator.sh` - Validates cross-references exist

**Note:** The `manager-agent-validator.sh` and `director-skill-validator.sh` are deprecated. Projects should not create these components.

---

## Documentation

### Best Practices
- **[/docs/BEST-PRACTICES.md](docs/BEST-PRACTICES.md)** - **START HERE** - Current best practices guide (v2.0)

### Specifications
- `/specs/SPEC-00015-faber-agent-plugin-specification.md` - Original spec
- `/specs/SPEC-00025-FABER-AGENT-COMPREHENSIVE-ENHANCEMENT.md` - SPEC-00025 implementation

### Standards
- `/docs/standards/FRACTARY-PLUGIN-STANDARDS.md` - Plugin development standards

### Patterns
- `/docs/patterns/builder-debugger.md` - Builder/Debugger iterative pattern

### Migration Guides
- `/docs/migration/agent-chain-to-skills.md` - Converting agent chains to Skills
- `/docs/migration/hybrid-agent-splitting.md` - Splitting hybrid agents
- `/docs/migration/script-extraction.md` - Moving bash to scripts

### Usage Guides
- `/docs/guides/workflow-creation-guide.md` - Complete workflow creation guide
- `/docs/guides/audit-usage-guide.md` - Audit system usage
- `/docs/guides/conversion-spec-guide.md` - Conversion specification format

### Examples
- `/docs/examples/csv-processor-example.md` - Complete CSV processing workflow
- `/docs/examples/typescript-builder-example.md` - Iterative TypeScript build with error fixing
- `/docs/examples/conversion-example.md` - Conversion walkthrough

---

## Development Roadmap

**Phase 4: SPEC-025 Implementation** ✅ Complete
- ✅ Audit system with anti-pattern detection
- ✅ Conversion specification system
- ✅ Workflow creation (multi-phase, builder-debugger)
- ✅ Comprehensive migration guides
- ✅ Usage guides and examples

**Phase 5: Integration & Distribution** (Next)
- CI/CD integration (GitHub Actions)
- Pre-commit hooks for validation
- Plugin registry publication
- VS Code extension

**Phase 6: Future Enhancements** (Planned)
- Multi-framework support (OpenAI, LangChain)
- Framework conversion tools
- AI-assisted requirement gathering
- Visual workflow designer
- Knowledge base integration
- Pattern library expansion

---

## Context Efficiency

### Typical Savings

**Before SPEC-025 Fixes:**
- Agent chains: ~60K tokens
- Hybrid agents: ~15K tokens
- Inline scripts: ~10K tokens
- **Total: ~85K tokens**

**After SPEC-025 Fixes:**
- Manager + Skills: ~15K tokens
- Clean agents: ~8K tokens
- Script extraction: ~3K tokens
- **Total: ~26K tokens**

**Savings: ~59K tokens (69% reduction)**

---

## Contributing

See `/specs/SPEC-00015-faber-agent-plugin-specification.md` and `/specs/SPEC-00025-FABER-AGENT-COMPREHENSIVE-ENHANCEMENT.md` for implementation details.

---

## License

MIT

---

## Version History

**0.4.0 (2025-01-11)** - SPEC-025 Implementation
- Added workflow creation system (multi-phase, builder-debugger)
- Added audit system with anti-pattern detection
- Added conversion specification system
- Added 4 migration guides
- Added 3 usage guides
- Added 3 complete examples
- Added workflow validators

**0.3.0** - Advanced Features
- Plugin creation workflow
- Handler skill templates
- Advanced validation

**0.2.0** - Core Workflows
- Skill and command creation
- Template substitution
- Basic validation

**0.1.0** - Foundation
- Initial plugin structure
- Basic agent creation
- Template system
