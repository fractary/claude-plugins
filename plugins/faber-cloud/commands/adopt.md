---
name: fractary-faber-cloud:adopt
description: Adopt existing infrastructure into faber-cloud management
model: claude-haiku-4-5
examples:
  - /fractary-faber-cloud:adopt
  - /fractary-faber-cloud:adopt --project-root ./services/api
  - /fractary-faber-cloud:adopt --dry-run
argument-hint: "[--project-root <path>] [--dry-run]"
---

# Adopt Command

Discover and adopt existing infrastructure into faber-cloud lifecycle management.

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:adopt
/fractary-faber-cloud:adopt --project-root ./my-project
/fractary-faber-cloud:adopt --project-root ./services/api --dry-run

# Incorrect ❌
/fractary-faber-cloud:adopt --project-root=./my-project
/fractary-faber-cloud:adopt --dry-run=true
```
</ARGUMENT_SYNTAX>

## Usage

```bash
/fractary-faber-cloud:adopt [--project-root <path>] [--dry-run]
```

## When to Use This Command

**Use `/fractary-faber-cloud:adopt` if you have:**
- ✅ Existing Terraform infrastructure to migrate
- ✅ Custom deployment scripts to preserve
- ✅ Complex multi-environment setup

**Use `/fractary-faber-cloud:init` instead if you:**
- ⚠️ Don't have existing infrastructure yet (greenfield project)
- ⚠️ Want a simple, minimal configuration
- ⚠️ Just need to get started quickly

**IMPORTANT:** The adopt command does NOT require faber-cloud to be configured first. It will discover your infrastructure and create the configuration automatically.

## Parameters

- `--project-root`: Root directory of the project to analyze. **Defaults to current directory.** The command recursively searches for infrastructure from this location, so you typically don't need to specify this - just cd to your project and run `/fractary-faber-cloud:adopt`.
- `--dry-run`: Run discovery and generate reports without creating configuration. Defaults to false.

## What This Does

### Infrastructure Adoption Workflow

1. **Discovery Phase** - Analyze existing infrastructure
   - Scan for Terraform files and structure
   - Identify AWS profiles and environments
   - Discover custom infrastructure scripts
   - Assess complexity and risks

2. **Configuration Phase** - Generate faber-cloud setup
   - Auto-select appropriate template (flat, modular, multi-environment)
   - Map AWS profiles to environments
   - Generate hook suggestions from custom scripts
   - Validate generated configuration

3. **Report Phase** - Provide migration guidance
   - Generate comprehensive migration report
   - Assess risks and mitigation strategies
   - Estimate timeline by complexity
   - Provide step-by-step checklist

4. **User Confirmation** - Interactive decision point
   - Present findings to user
   - Review configuration together
   - Get approval to proceed or save for later

5. **Setup Phase** (if approved) - Install configuration
   - Copy configuration to project
   - Set up directory structure
   - Provide next steps

### Read-Only Discovery

- **Non-destructive**: Discovery phase never modifies infrastructure
- **Safe to run**: Analyze existing setup without risk
- **Comprehensive**: Discovers Terraform, AWS, and custom scripts
- **Fast**: Most discoveries complete in <1 minute

## Output

The adoption workflow produces:

### Discovery Reports (JSON)
- `discovery-terraform.json` - Terraform structure analysis
- `discovery-aws.json` - AWS profile mappings
- `discovery-custom-agents.json` - Custom script inventory

### Generated Configuration
- `config.json` - Complete faber-cloud configuration

### Migration Report (Markdown)
- `MIGRATION.md` - Comprehensive migration guide
  - Executive summary
  - Infrastructure overview
  - Capability mapping
  - Risk assessment
  - Timeline estimation
  - Migration checklist
  - Rollback procedures

## Examples

**Typical usage - adopt infrastructure in current directory:**
```bash
cd /path/to/my-project
/fractary-faber-cloud:adopt
```

**Monorepo - adopt infrastructure for a specific service:**
```bash
# You're at repo root, analyzing a specific service's infrastructure
/fractary-faber-cloud:adopt --project-root ./services/api
```

**Preview adoption without making changes:**
```bash
/fractary-faber-cloud:adopt --dry-run
```

**Batch analysis - evaluate multiple projects:**
```bash
# Analyze several projects without cd'ing between them
/fractary-faber-cloud:adopt --project-root ~/projects/app-a --dry-run
/fractary-faber-cloud:adopt --project-root ~/projects/app-b --dry-run
```

## Adoption Scenarios

### Scenario 1: Simple Flat Structure

**Infrastructure:**
- Single Terraform directory
- test.tfvars and prod.tfvars
- 2 AWS profiles
- No custom scripts

**Result:**
- Complexity: SIMPLE
- Timeline: 4 hours
- Configuration: Flat template
- Environments: test, prod
- Hooks: None

### Scenario 2: Modular Structure

**Infrastructure:**
- Terraform with modules/
- Multiple .tfvars files
- 3+ AWS profiles
- Some custom scripts

**Result:**
- Complexity: MODERATE
- Timeline: 12 hours
- Configuration: Modular template
- Environments: dev, test, staging, prod
- Hooks: 3-5 suggested

### Scenario 3: Complex Multi-Environment

**Infrastructure:**
- Terraform with environments/ and modules/
- Many .tfvars files
- 4+ AWS profiles
- Many custom scripts

**Result:**
- Complexity: COMPLEX
- Timeline: 24 hours
- Configuration: Multi-environment template
- Environments: Full environment hierarchy
- Hooks: 5+ suggested with custom logic

## Interactive Workflow

The adoption process is interactive and guides you through each step:

```
Step 1: Discovery
  🔍 Scanning for Terraform files...
  🔍 Analyzing AWS profiles...
  🔍 Discovering custom scripts...
  ✅ Discovery complete

Step 2: Assessment
  📊 Infrastructure Complexity: MODERATE
  📊 Total Resources: 45
  📊 Environments: 2
  📊 Custom Scripts: 3
  📊 Estimated Migration Time: 12 hours

Step 3: Configuration Generation
  🔧 Selected template: modular
  🔧 Mapped AWS profiles to environments
  🔧 Generated 3 hook suggestions
  ✅ Configuration generated

Step 4: Report Generation
  📝 Generating migration report...
  📝 Assessing risks...
  📝 Creating checklist...
  ✅ MIGRATION.md created

Step 5: User Review
  📋 Review findings:
     - Configuration: config.json
     - Report: MIGRATION.md
     - Discovery: .fractary/adoption/*.json

  ❓ Proceed with setup? (yes/no)

  [If yes → Install configuration]
  [If no → Save reports for review]
```

## Use Cases

### First-Time Adoption (Most Common)

Adopt existing manually-managed infrastructure:

```bash
# Navigate to your project
cd /path/to/my-project

# Run adoption - it will automatically discover infrastructure
# in common locations (./terraform, ./infrastructure, etc.)
/fractary-faber-cloud:adopt

# Review generated reports
# Approve setup
# Follow MIGRATION.md checklist
```

**Note:** The command searches recursively from your project root, so you don't need to point it to your terraform directory - just run it from your project root.

### Evaluate Before Adopting

Generate reports without committing to adoption:

```bash
cd /path/to/my-project

# Run discovery only
/fractary-faber-cloud:adopt --dry-run

# Review reports
cat .fractary/adoption/MIGRATION.md

# Decide whether to adopt
# Re-run without --dry-run to proceed
```

### Monorepo - Multiple Services

When working with a monorepo containing multiple services:

```bash
# You're at the monorepo root
# Each service has its own infrastructure

# Adopt infrastructure for each service
/fractary-faber-cloud:adopt --project-root ./services/api
/fractary-faber-cloud:adopt --project-root ./services/worker
/fractary-faber-cloud:adopt --project-root ./services/frontend

# Each gets its own faber-cloud configuration
```

### Migrate from Custom Scripts

Replace custom deployment scripts with faber-cloud:

```bash
cd /path/to/my-project

# Adopt infrastructure
/fractary-faber-cloud:adopt

# Review capability mapping
# See which scripts → hooks
# See which scripts → replace

# Follow migration plan
```

## What Gets Created

### Directory Structure

```
project/
├── .fractary/
│   └── adoption/
│       ├── discovery-terraform.json
│       ├── discovery-aws.json
│       ├── discovery-custom-agents.json
│       ├── config.json
│       └── MIGRATION.md
└── .fractary/
    └── plugins/
        └── faber-cloud/
            └── config.json  (if setup approved)
```

### Configuration File

Generated `config.json` includes:

- **Environments**: All detected environments configured
- **Terraform settings**: Paths, backend, version
- **AWS settings**: Profiles, regions
- **Handlers**: IaC and hosting configurations
- **Hooks**: Generated from custom scripts
- **Deployment settings**: Approval, validation, rollback
- **Monitoring**: CloudWatch, notifications (disabled by default)

## After Adoption

Once infrastructure is adopted, follow the migration checklist:

1. **Test in test environment first**
   ```bash
   /fractary-faber-cloud:audit --env=test
   /fractary-faber-cloud:deploy-plan --env=test
   /fractary-faber-cloud:deploy-execute --env=test
   ```

2. **Validate with staging** (if available)
   ```bash
   /fractary-faber-cloud:deploy-execute --env=staging
   ```

3. **Deploy to production**
   ```bash
   /fractary-faber-cloud:audit --env=prod
   /fractary-faber-cloud:deploy-plan --env=prod
   /fractary-faber-cloud:deploy-execute --env=prod
   ```

## Rollback Plan

If adoption doesn't work as expected:

1. Configuration is in `.fractary/` (not yet active)
2. Original infrastructure is unchanged
3. Original scripts still available
4. Can revert by removing `.fractary/plugins/faber-cloud/`
5. Continue using original workflow

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
- Starting with faber-cloud for first time
- Have existing Terraform infrastructure
- Want to standardize infrastructure management
- Migrating from custom deployment scripts
- Need better environment validation
- Want lifecycle hooks support
- Need deployment approval workflow

## Requirements

Before running adopt:

- Terraform files present in project
- AWS profiles configured (optional but recommended)
- Git repository (recommended for version control)
- No pending infrastructure changes

## Next Steps After Adoption

1. **Review generated reports**
   - Read `MIGRATION.md` thoroughly
   - Understand risks and timeline
   - Review capability mapping

2. **Test configuration**
   - Start with test environment
   - Validate all hooks work
   - Verify environment detection

3. **Train team**
   - Share migration report
   - Document new workflow
   - Update runbooks

4. **Gradual rollout**
   - Test → Staging → Production
   - Monitor each phase
   - Iterate as needed

## Invocation

This command invokes the `infra-manager` agent with the `adopt` operation.

USE AGENT: infra-manager with operation=adopt, project-root from --project-root parameter (defaults to current directory), and dry-run from --dry-run parameter (defaults to false)
