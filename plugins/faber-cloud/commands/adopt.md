---
name: fractary-faber-cloud:adopt
description: Adopt existing infrastructure into faber-cloud management
examples:
  - /fractary-faber-cloud:adopt
  - /fractary-faber-cloud:adopt --project-root=./my-project
  - /fractary-faber-cloud:adopt --dry-run
argument-hint: "[--project-root=<path>] [--dry-run]"
---

# Adopt Command

Discover and adopt existing infrastructure into faber-cloud lifecycle management.

## Usage

```bash
/fractary-faber-cloud:adopt [--project-root=<path>] [--dry-run]
```

## Parameters

- `--project-root`: Root directory of the project to analyze. Defaults to current directory.
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
- `faber-cloud.json` - Complete faber-cloud configuration

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

**Adopt infrastructure in current directory:**
```
/fractary-faber-cloud:adopt
```

**Adopt infrastructure in specific directory:**
```
/fractary-faber-cloud:adopt --project-root=/path/to/project
```

**Run discovery without generating configuration:**
```
/fractary-faber-cloud:adopt --dry-run
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
     - Configuration: faber-cloud.json
     - Report: MIGRATION.md
     - Discovery: .fractary/adoption/*.json

  ❓ Proceed with setup? (yes/no)

  [If yes → Install configuration]
  [If no → Save reports for review]
```

## Use Cases

### First-Time Adoption

Adopt existing manually-managed infrastructure:

```bash
# Navigate to infrastructure project
cd /path/to/infrastructure

# Run adoption
/fractary-faber-cloud:adopt

# Review generated reports
# Approve setup
# Follow MIGRATION.md checklist
```

### Evaluate Before Adopting

Generate reports without committing to adoption:

```bash
# Run discovery only
/fractary-faber-cloud:adopt --dry-run

# Review reports
cat .fractary/adoption/MIGRATION.md

# Decide whether to adopt
# Re-run without --dry-run to proceed
```

### Migrate from Custom Scripts

Replace custom deployment scripts with faber-cloud:

```bash
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
│       ├── faber-cloud.json
│       └── MIGRATION.md
└── .fractary/
    └── plugins/
        └── faber-cloud/
            └── config/
                └── faber-cloud.json  (if setup approved)
```

### Configuration File

Generated `faber-cloud.json` includes:

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
4. Can revert by removing `.fractary/plugins/faber-cloud/config/`
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
