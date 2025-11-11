---
name: fractary-docs:adopt
description: Adopt existing documentation into fractary-docs management
examples:
  - /fractary-docs:adopt
  - /fractary-docs:adopt --project-root ./services/api
  - /fractary-docs:adopt --dry-run
argument-hint: "[--project-root <path>] [--dry-run]"
---

# Adopt Command

Discover and adopt existing documentation into fractary-docs lifecycle management.

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-docs:adopt
/fractary-docs:adopt --project-root ./my-project
/fractary-docs:adopt --project-root ./services/api --dry-run

# Incorrect ❌
/fractary-docs:adopt --project-root=./my-project
/fractary-docs:adopt --dry-run=true
```
</ARGUMENT_SYNTAX>

## Usage

```bash
/fractary-docs:adopt [--project-root <path>] [--dry-run]
```

## When to Use This Command

**Use `/fractary-docs:adopt` if you have:**
- ✅ Existing documentation to migrate
- ✅ Custom documentation structure to preserve
- ✅ Multiple documentation types (ADRs, designs, runbooks, etc.)
- ✅ Inconsistent documentation formats to standardize

**Use `/fractary-docs:init` instead if you:**
- ⚠️ Don't have existing documentation yet (greenfield project)
- ⚠️ Want a simple, minimal configuration
- ⚠️ Just need to get started quickly

**IMPORTANT:** The adopt command does NOT require fractary-docs to be configured first. It will discover your documentation and create the configuration automatically.

## Parameters

- `--project-root`: Root directory of the project to analyze. **Defaults to current directory.** The command recursively searches for documentation from this location, so you typically don't need to specify this - just cd to your project and run `/fractary-docs:adopt`.
- `--dry-run`: Run discovery and generate reports without creating configuration. Defaults to false.

## What This Does

### Documentation Adoption Workflow

1. **Discovery Phase** - Analyze existing documentation
   - Scan for documentation files (README.md, docs/, etc.)
   - Identify documentation structure and organization
   - Discover documentation types (ADRs, designs, runbooks, API docs, etc.)
   - Analyze existing front matter patterns
   - Assess documentation quality and completeness

2. **Configuration Phase** - Generate fractary-docs setup
   - Auto-select appropriate output paths based on current structure
   - Map existing doc types to plugin templates
   - Generate validation rules from existing patterns
   - Configure front matter standardization
   - Validate generated configuration

3. **Report Phase** - Provide migration guidance
   - Generate comprehensive migration report
   - Assess documentation coverage and gaps
   - Identify quality issues and inconsistencies
   - Estimate standardization timeline
   - Provide step-by-step migration checklist

4. **User Confirmation** - Interactive decision point
   - Present findings to user
   - Review configuration together
   - Get approval to proceed or save for later

5. **Setup Phase** (if approved) - Install configuration
   - Copy configuration to project
   - Set up directory structure
   - Provide next steps for standardization

### Read-Only Discovery

- **Non-destructive**: Discovery phase never modifies documentation
- **Safe to run**: Analyze existing documentation without risk
- **Comprehensive**: Discovers all common documentation types
- **Fast**: Most discoveries complete in <1 minute

## Output

The adoption workflow produces:

### Discovery Reports (JSON)
- `discovery-docs.json` - Documentation file inventory and analysis
- `discovery-structure.json` - Directory structure and organization
- `discovery-frontmatter.json` - Front matter pattern analysis
- `discovery-quality.json` - Documentation quality assessment

### Generated Configuration
- `docs-config.json` - Complete fractary-docs configuration

### Migration Report (Markdown)
- `MIGRATION.md` - Comprehensive migration guide
  - Executive summary
  - Documentation inventory
  - Quality assessment
  - Gap analysis
  - Standardization recommendations
  - Timeline estimation
  - Migration checklist

## Examples

**Typical usage - adopt documentation in current directory:**
```bash
cd /path/to/my-project
/fractary-docs:adopt
```

**Monorepo - adopt documentation for a specific service:**
```bash
# You're at repo root, analyzing a specific service's docs
/fractary-docs:adopt --project-root ./services/api
```

**Preview adoption without making changes:**
```bash
/fractary-docs:adopt --dry-run
```

**Batch analysis - evaluate multiple projects:**
```bash
# Analyze several projects without cd'ing between them
/fractary-docs:adopt --project-root ~/projects/app-a --dry-run
/fractary-docs:adopt --project-root ~/projects/app-b --dry-run
```

## Adoption Scenarios

### Scenario 1: Minimal Documentation

**Documentation:**
- README.md only
- No structured docs/
- No front matter
- No documentation standards

**Result:**
- Complexity: SIMPLE
- Timeline: 2 hours
- Configuration: Basic template
- Recommendations: Start with ADRs and runbooks
- Migration: Create structure, move existing content

### Scenario 2: Moderate Documentation

**Documentation:**
- README.md and docs/
- Some ADRs or design docs
- Inconsistent structure
- Minimal or no front matter
- Mix of documentation types

**Result:**
- Complexity: MODERATE
- Timeline: 8 hours
- Configuration: Structured template matching current layout
- Recommendations: Standardize front matter, organize by type
- Migration: Reorganize, add front matter, fill gaps

### Scenario 3: Extensive Documentation

**Documentation:**
- Comprehensive docs/ structure
- Multiple doc types (ADRs, designs, runbooks, API specs)
- Some front matter exists
- Custom documentation conventions
- Documentation spread across multiple locations

**Result:**
- Complexity: COMPLEX
- Timeline: 16 hours
- Configuration: Full featured template preserving structure
- Recommendations: Standardize front matter, link related docs, validate
- Migration: Systematic standardization, quality improvements

## Interactive Workflow

The adoption process is interactive and guides you through each step:

```
Step 1: Discovery
  🔍 Scanning for documentation files...
  🔍 Analyzing documentation structure...
  🔍 Discovering documentation types...
  🔍 Assessing quality and completeness...
  ✅ Discovery complete

Step 2: Assessment
  📊 Documentation Complexity: MODERATE
  📊 Total Documents: 23
  📊 Document Types: 4 (README, ADRs, designs, runbooks)
  📊 With Front Matter: 5/23 (22%)
  📊 Estimated Migration Time: 8 hours

Step 3: Configuration Generation
  🔧 Selected output paths based on current structure
  🔧 Mapped doc types to templates
  🔧 Generated validation rules
  🔧 Configured front matter standards
  ✅ Configuration generated

Step 4: Report Generation
  📝 Generating migration report...
  📝 Assessing quality gaps...
  📝 Creating standardization checklist...
  ✅ MIGRATION.md created

Step 5: User Review
  📋 Review findings:
     - Configuration: docs-config.json
     - Report: MIGRATION.md
     - Discovery: .fractary/adoption/*.json

  ❓ Proceed with setup? (yes/no)

  [If yes → Install configuration]
  [If no → Save reports for review]
```

## Use Cases

### First-Time Adoption (Most Common)

Adopt existing manually-managed documentation:

```bash
# Navigate to your project
cd /path/to/my-project

# Run adoption - it will automatically discover documentation
# in common locations (./docs, ./documentation, README.md, etc.)
/fractary-docs:adopt

# Review generated reports
# Approve setup
# Follow MIGRATION.md checklist
```

**Note:** The command searches recursively from your project root, so you don't need to point it to your docs directory - just run it from your project root.

### Evaluate Before Adopting

Generate reports without committing to adoption:

```bash
cd /path/to/my-project

# Run discovery only
/fractary-docs:adopt --dry-run

# Review reports
cat .fractary/adoption/MIGRATION.md

# Decide whether to adopt
# Re-run without --dry-run to proceed
```

### Monorepo - Multiple Services

When working with a monorepo containing multiple services:

```bash
# You're at the monorepo root
# Each service has its own documentation

# Adopt documentation for each service
/fractary-docs:adopt --project-root ./services/api
/fractary-docs:adopt --project-root ./services/worker
/fractary-docs:adopt --project-root ./services/frontend

# Each gets its own docs configuration
```

### Standardize Existing Documentation

Replace inconsistent documentation practices with fractary-docs:

```bash
cd /path/to/my-project

# Adopt documentation
/fractary-docs:adopt

# Review recommendations
# See which docs need front matter
# See which docs need reorganization

# Follow migration plan
```

## What Gets Created

### Directory Structure

```
project/
├── .fractary/
│   └── adoption/
│       ├── discovery-docs.json
│       ├── discovery-structure.json
│       ├── discovery-frontmatter.json
│       ├── discovery-quality.json
│       ├── docs-config.json
│       └── MIGRATION.md
└── .fractary/
    └── plugins/
        └── docs/
            └── config/
                └── config.json  (if setup approved)
```

### Configuration File

Generated `config.json` includes:

- **output_paths**: Configured based on existing structure
- **templates**: Custom template directory if detected
- **frontmatter**: Standard fields and codex sync settings
- **validation**: Rules based on existing documentation patterns
- **linking**: Cross-reference and index settings

## After Adoption

Once documentation is adopted, follow the migration checklist:

1. **Review generated configuration**
   ```bash
   cat .fractary/plugins/docs/config/config.json
   ```

2. **Start with high-value documentation**
   - Add front matter to existing docs
   - Validate documentation quality
   - Fix broken links

3. **Organize by document type**
   - Move ADRs to configured location
   - Organize design docs
   - Consolidate runbooks

4. **Generate missing documentation**
   - Create ADRs for key decisions
   - Document critical operational procedures
   - Add API documentation

5. **Validate and iterate**
   ```bash
   /fractary-docs:validate
   /fractary-docs:link check
   ```

## Rollback Plan

If adoption doesn't work as expected:

1. Configuration is in `.fractary/` (not yet fully active)
2. Original documentation is unchanged
3. Can revert by removing `.fractary/plugins/docs/config/`
4. Continue using original documentation workflow

## Dry-Run Mode

Use `--dry-run` to:
- Generate discovery reports
- Generate migration report
- Generate configuration
- Review everything
- **Not** install configuration
- **Not** make any changes

This lets you evaluate adoption without commitment.

## When to Use

Run adopt when:
- Starting with fractary-docs for first time
- Have existing documentation to standardize
- Want to improve documentation quality
- Need consistent documentation structure
- Migrating from custom documentation practices
- Want better documentation discovery and linking
- Need front matter for codex integration

## Requirements

Before running adopt:

- Documentation files present in project (README.md, docs/, etc.)
- Git repository (recommended for version control)
- No pending documentation changes (commit first)

## Next Steps After Adoption

1. **Review generated reports**
   - Read `MIGRATION.md` thoroughly
   - Understand quality gaps
   - Review standardization recommendations

2. **Test configuration**
   - Generate a test document
   - Validate existing documentation
   - Check links and cross-references

3. **Systematic migration**
   - Start with high-value documents
   - Add front matter systematically
   - Reorganize gradually
   - Validate frequently

4. **Team alignment**
   - Share migration report
   - Document new standards
   - Update contribution guidelines

## Invocation

This command invokes the `docs-manager` agent with the `adopt` operation.

USE AGENT: docs-manager with operation=adopt, project-root from --project-root parameter (defaults to current directory), and dry-run from --dry-run parameter (defaults to false)
