# FABER Plugin Extension Guide

**Audience**: Plugin developers creating specialized `faber-{type}` plugins

**Goal**: Extend core FABER with domain-specific skills and workflows

## Overview

Specialized FABER plugins (like `faber-cloud`, `faber-app`) extend the core FABER workflow by:
1. Adding domain-specific **skills**
2. Providing specialized **workflows** that use those skills
3. Adding workflows to the **core FABER config** (not separate configs)

**Key principle**: All workflows centralize in `.fractary/plugins/faber/config.json` for unified management and easy GitHub app integration.

## ⚠️ Critical: Preserve the Default Workflow

**IMPORTANT**: When adding custom workflows, **ALWAYS keep the default workflow**. Custom workflows should be **added alongside** the default workflow, not replace it.

**Why keep the default workflow?**
- ✅ Provides a standard software development baseline that works for most issues
- ✅ Gives teams a fallback for general development tasks
- ✅ Serves as a reference implementation for custom workflows
- ✅ Ensures FABER works out-of-the-box even with custom plugins installed

**Example of correct workflows array in config.json:**
```json
{
  "workflows": [
    {
      "id": "default",
      "file": "./workflows/default.json",
      "description": "Standard FABER workflow (Frame → Architect → Build → Evaluate → Release)"
      // ... default workflow is RETAINED
    },
    {
      "id": "cloud",
      "file": "./workflows/cloud.json",
      "description": "Infrastructure workflow (Terraform → Deploy → Monitor)"
      // ... custom workflow is ADDED
    },
    {
      "id": "hotfix",
      "file": "./workflows/hotfix.json",
      "description": "Expedited workflow for critical patches"
      // ... another custom workflow is ADDED
    }
  ]
}
```

**Workflow files structure:**
```
.fractary/plugins/faber/
├── config.json              # Main config (references all workflows)
└── workflows/               # Workflow definition files
    ├── default.json         # Standard FABER workflow
    ├── cloud.json           # Infrastructure workflow (from faber-cloud plugin)
    └── hotfix.json          # Hotfix workflow
```

**How to use multiple workflows:**
```bash
# Use default workflow (general development)
/fractary-faber:run 123

# Use cloud workflow (infrastructure changes)
/fractary-faber:run 456 --workflow cloud

# Use hotfix workflow (critical patches)
/fractary-faber:run 789 --workflow hotfix
```

## Architecture

### Core FABER (baseline)
```
faber/
  ├── commands/
  │   └── init.md              # Creates default workflow
  └── skills/                   # Universal skills
      ├── frame/
      ├── architect/
      ├── build/
      ├── evaluate/
      └── release/
```

### Specialized Plugin (example: faber-cloud)
```
faber-cloud/
  ├── commands/
  │   └── init.md              # Copies workflow templates to project
  ├── skills/                   # Cloud-specific skills
  │   ├── terraform-manager/
  │   ├── aws-deployer/
  │   ├── cost-estimator/
  │   └── security-scanner/
  └── config/
      └── workflows/            # Workflow templates (copied during init)
          ├── cloud.json        # Infrastructure workflow
          └── README.md         # Workflow documentation
```

**Template-Copy Pattern**: During plugin initialization, workflow templates are copied from `plugins/faber-cloud/config/workflows/` to `.fractary/plugins/faber/workflows/` and referenced in the main config.

## Creating a Specialized Plugin

### Step 1: Plugin Structure

Create standard plugin structure:

```bash
plugins/faber-{type}/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── commands/
│   └── init.md              # Init command (copies workflow templates)
├── skills/
│   ├── {skill-name}/
│   │   ├── SKILL.md
│   │   └── scripts/
│   └── ...
├── config/
│   ├── workflows/            # Workflow templates (source)
│   │   ├── {type}.json       # Workflow definition
│   │   └── README.md         # Workflow documentation
│   └── issue-templates/      # GitHub issue templates (source)
│       ├── {type}.yml        # Issue template for this workflow
│       └── README.md         # Template documentation
└── README.md
```

**Note**: Workflow templates are stored in `config/workflows/` in the plugin and copied to `.fractary/plugins/faber/workflows/` during project initialization.

### Step 2: Define Specialized Skills

Each skill should:
- Perform a specific domain task
- Follow the 3-layer architecture (command → agent → skill → script)
- Document clearly what it does

**Example**: `skills/terraform-manager/SKILL.md`

```markdown
# Terraform Manager Skill

Manages Terraform operations (plan, apply, destroy) for infrastructure workflows.

## Operations

- **plan**: Generate Terraform execution plan
- **apply**: Apply Terraform changes
- **validate**: Validate Terraform configuration
- **cost-estimate**: Estimate infrastructure costs

## Usage

Invoked by faber-cloud workflows in the build and evaluate phases.
```

### Step 3: Create Workflow Template

Define a workflow that uses your specialized skills.

**Location**: `config/workflows/cloud.json` (in your plugin directory)

This file will be copied to `.fractary/plugins/faber/workflows/cloud.json` during project initialization.

**Example**: `plugins/faber-cloud/config/workflows/cloud.json`

```json
{
  "$schema": "../../../faber/config/workflow.schema.json",
  "id": "cloud",
  "description": "Infrastructure workflow (Terraform → Deploy → Monitor)",
  "phases": {
    "frame": {
      "enabled": true,
      "description": "Frame: Fetch issue, create branch",
      "steps": [
        {
          "name": "fetch-issue",
          "description": "Fetch infrastructure issue",
          "skill": "fractary-work:issue-fetcher"
        },
        {
          "name": "create-branch",
          "description": "Create infrastructure branch",
          "skill": "fractary-repo:branch-manager"
        }
      ]
    },
    "architect": {
      "enabled": true,
      "description": "Architect: Design infrastructure",
      "steps": [
        {
          "name": "design-infrastructure",
          "description": "Generate infrastructure design",
          "skill": "faber-cloud:infrastructure-designer"
        },
        {
          "name": "cost-estimate",
          "description": "Estimate infrastructure costs",
          "skill": "faber-cloud:cost-estimator"
        }
      ]
    },
    "build": {
      "enabled": true,
      "description": "Build: Generate Terraform code",
      "steps": [
        {
          "name": "terraform-plan",
          "description": "Generate Terraform execution plan",
          "skill": "faber-cloud:terraform-manager"
        },
        {
          "name": "security-scan",
          "description": "Scan for security issues (checkov, tfsec)",
          "skill": "faber-cloud:security-scanner"
        },
        {
          "name": "commit",
          "description": "Commit Terraform code",
          "skill": "fractary-repo:commit-creator"
        }
      ]
    },
    "evaluate": {
      "enabled": true,
      "description": "Evaluate: Validate and test infrastructure",
      "max_retries": 2,
      "steps": [
        {
          "name": "terraform-validate",
          "description": "Validate Terraform configuration",
          "skill": "faber-cloud:terraform-manager"
        },
        {
          "name": "compliance-check",
          "description": "Check compliance policies",
          "skill": "faber-cloud:compliance-checker"
        },
        {
          "name": "cost-review",
          "description": "Review estimated costs",
          "skill": "faber-cloud:cost-estimator"
        }
      ]
    },
    "release": {
      "enabled": true,
      "description": "Release: Apply infrastructure changes",
      "require_approval": true,
      "steps": [
        {
          "name": "terraform-apply",
          "description": "Apply Terraform changes to infrastructure",
          "skill": "faber-cloud:terraform-manager"
        },
        {
          "name": "deploy-infra",
          "description": "Deploy infrastructure components",
          "skill": "faber-cloud:aws-deployer"
        },
        {
          "name": "create-pr",
          "description": "Create PR documenting infrastructure changes",
          "skill": "fractary-repo:pr-manager"
        }
      ]
    }
  },
  "hooks": {
    "pre_frame": [],
    "post_frame": [],
    "pre_architect": [
      {
        "type": "document",
        "name": "infrastructure-standards",
        "path": "docs/infrastructure/STANDARDS.md",
        "description": "Load infrastructure design standards"
      }
    ],
    "post_architect": [],
    "pre_build": [],
    "post_build": [],
    "pre_evaluate": [],
    "post_evaluate": [],
    "pre_release": [
      {
        "type": "skill",
        "name": "final-cost-check",
        "skill": "faber-cloud:cost-estimator",
        "description": "Final cost verification before applying"
      }
    ],
    "post_release": [
      {
        "type": "script",
        "name": "notify-ops-team",
        "path": "./scripts/notify-ops.sh",
        "description": "Notify operations team of infrastructure changes"
      }
    ]
  },
  "autonomy": {
    "level": "guarded",
    "pause_before_release": true,
    "require_approval_for": ["release"],
    "overrides": {}
  }
}
```

### Step 4: Create Init Command

The init command **copies workflow templates** and **adds references** to the core FABER config using the **template-copy pattern**:

**Example**: `commands/init.md`

```markdown
# /fractary-faber-cloud:init

Initialize cloud infrastructure workflow for FABER.

## What This Does

1. Copies workflow template from plugin to project
2. Adds workflow reference to `.fractary/plugins/faber/config.json`

**Files created:**
- `.fractary/plugins/faber/workflows/cloud.json` (workflow definition)

**Files modified:**
- `.fractary/plugins/faber/config.json` (adds workflow reference)

## Prerequisites

- Core FABER must be initialized first: `/fractary-faber:init`

## Usage

```bash
# Add cloud workflow to existing FABER config
/fractary-faber-cloud:init

# Specify environment (optional)
/fractary-faber-cloud:init --env production
/fractary-faber-cloud:init --env staging
```

## Implementation (Template-Copy Pattern)

This command should:
1. Check if core FABER config exists (require `/fractary-faber:init` first)
2. Create `.fractary/plugins/faber/workflows/` directory if needed
3. Copy workflow template:
   - From: `plugins/faber-cloud/config/workflows/cloud.json`
   - To: `.fractary/plugins/faber/workflows/cloud.json`
4. Load existing config from `.fractary/plugins/faber/config.json`
5. Check if "cloud" workflow reference already exists (warn if duplicate)
6. Add workflow reference to config's `workflows` array:
   ```json
   {
     "id": "cloud",
     "file": "./workflows/cloud.json",
     "description": "Infrastructure workflow (Terraform → Deploy → Monitor)"
   }
   ```
7. Write updated config back to `.fractary/plugins/faber/config.json`
8. Validate configuration and workflow file
9. Report success with usage instructions

## After Initialization

The "cloud" workflow will be available:

```bash
# Use cloud workflow for infrastructure issues
/fractary-faber:run 123 --workflow cloud

# Status for cloud workflow
/fractary-faber:status 123
```

## See Also

- Core FABER: `/fractary-faber:init`
- Workflow selection: `/fractary-faber:run --help`
```

### Step 5: Create GitHub Issue Templates (Recommended)

Provide GitHub issue templates that mirror your workflow definitions. These templates will be copied to the project's `.github/ISSUE_TEMPLATE/` directory during initialization.

**Why include issue templates:**
- Provides workflow selection at issue creation time
- Pre-populates metadata and labels aligned with specific workflows
- Ensures issues have the right structure for the workflow they'll follow
- Makes custom workflows discoverable to users

#### Template Structure in Plugin

Store issue templates in your plugin's `config/issue-templates/` directory:

```
plugins/faber-cloud/
├── config/
│   ├── workflows/            # Workflow definitions
│   │   └── cloud.json
│   └── issue-templates/      # Issue templates
│       ├── cloud.yml         # Template for cloud workflow
│       └── README.md         # Documentation
```

#### Example: Cloud Infrastructure Template

**File**: `plugins/faber-cloud/config/issue-templates/cloud.yml`

```yaml
name: Cloud Infrastructure Change
description: Infrastructure workflow using Terraform and AWS
title: "[Infrastructure]: "
labels: ["type:infrastructure", "workflow:cloud"]
body:
  - type: markdown
    attributes:
      value: |
        This issue will follow the **cloud FABER workflow**:
        Frame → Architect (cost estimate) → Build (Terraform) → Evaluate (security scan) → Release (apply)

  - type: dropdown
    id: change-type
    attributes:
      label: Change Type
      description: What type of infrastructure change?
      options:
        - New resource
        - Update existing resource
        - Delete resource
        - Configuration change
    validations:
      required: true

  - type: dropdown
    id: environment
    attributes:
      label: Target Environment
      description: Which environment will this affect?
      options:
        - Development
        - Staging
        - Production
    validations:
      required: true

  - type: textarea
    id: description
    attributes:
      label: Infrastructure Description
      description: What infrastructure should be created/modified?
      placeholder: Describe the infrastructure components...
    validations:
      required: true

  - type: textarea
    id: resources
    attributes:
      label: AWS Resources
      description: What AWS resources will be affected?
      placeholder: |
        - EC2 instances
        - S3 buckets
        - RDS databases
        - etc.

  - type: textarea
    id: cost-estimate
    attributes:
      label: Expected Cost Impact
      description: Estimated monthly cost change
      placeholder: |
        Current: $X/month
        New: $Y/month
        Increase: $Z/month

  - type: checkboxes
    id: security
    attributes:
      label: Security Considerations
      description: Have you considered security implications?
      options:
        - label: Security groups configured properly
        - label: IAM roles follow least privilege
        - label: Encryption enabled where applicable
        - label: Compliance requirements reviewed

  - type: textarea
    id: rollback
    attributes:
      label: Rollback Plan
      description: How can this change be reverted if needed?
```

#### Copy Templates During Init

Modify your init command to copy both workflow definitions AND issue templates:

**Updated implementation** (extend Step 4's init logic):

```javascript
function initFaberCloudWorkflow() {
  // ... existing workflow copy logic ...

  // Copy issue template
  const issueTemplateDir = '.github/ISSUE_TEMPLATE'
  const templateSource = 'plugins/faber-cloud/config/issue-templates/cloud.yml'
  const templateTarget = '.github/ISSUE_TEMPLATE/cloud.yml'

  // Create .github/ISSUE_TEMPLATE directory if needed
  if (!exists(issueTemplateDir)) {
    mkdir(issueTemplateDir, { recursive: true })
    log("Created .github/ISSUE_TEMPLATE directory")
  }

  // Copy issue template
  if (exists(templateTarget)) {
    warn("Cloud issue template already exists, skipping copy")
  } else {
    copyFile(templateSource, templateTarget)
    log("Copied cloud issue template to .github/ISSUE_TEMPLATE/cloud.yml")
  }

  // Report success with issue template info
  success(`Cloud workflow added to FABER

  Files created:
    - .fractary/plugins/faber/workflows/cloud.json (workflow definition)
    - .github/ISSUE_TEMPLATE/cloud.yml (issue template)

  Files modified:
    - .fractary/plugins/faber/config.json (added workflow reference)

  Usage:
    1. Create issue using "Cloud Infrastructure Change" template
    2. Run: /fractary-faber:run <issue-number>
    3. FABER detects "workflow:cloud" label and uses cloud workflow

  Customize:
    - Workflow: .fractary/plugins/faber/workflows/cloud.json
    - Template: .github/ISSUE_TEMPLATE/cloud.yml
  `)
}
```

#### Multiple Templates Example

If your plugin provides multiple workflows, provide corresponding templates:

```
plugins/faber-cloud/config/issue-templates/
├── cloud-aws.yml       # AWS-specific infrastructure
├── cloud-gcp.yml       # GCP-specific infrastructure
├── cloud-azure.yml     # Azure-specific infrastructure
└── README.md           # Template documentation
```

Your init command should copy the appropriate template:

```bash
# Copy AWS template
/fractary-faber-cloud:init --provider aws
# Copies: cloud-aws.yml → .github/ISSUE_TEMPLATE/cloud-aws.yml

# Copy GCP template
/fractary-faber-cloud:init --provider gcp
# Copies: cloud-gcp.yml → .github/ISSUE_TEMPLATE/cloud-gcp.yml
```

#### Template Best Practices

1. **Label mapping**: Use `workflow:{id}` label to map to workflow ID
   ```yaml
   labels: ["type:infrastructure", "workflow:cloud"]
   ```

2. **Workflow documentation**: Include markdown explaining the workflow
   ```yaml
   - type: markdown
     attributes:
       value: |
         This issue follows the **cloud workflow**:
         Frame → Architect (cost) → Build (Terraform) → Evaluate → Release
   ```

3. **Domain-specific fields**: Include fields relevant to your workflow
   - Infrastructure: environment, resources, cost estimate
   - Application: feature type, UI/API, dependencies
   - Documentation: doc type, audience, scope

4. **Validation**: Use required fields for critical information
   ```yaml
   validations:
     required: true
   ```

5. **Checklists**: Include pre-flight checks
   ```yaml
   - type: checkboxes
     id: prerequisites
     attributes:
       label: Prerequisites
       options:
         - label: Design approved
         - label: Cost estimated
   ```

#### Documentation in README

Document the template in `config/issue-templates/README.md`:

```markdown
# Cloud Infrastructure Issue Templates

This directory contains GitHub issue templates for the faber-cloud plugin workflows.

## Templates

### cloud.yml
Maps to the `cloud` workflow for general infrastructure changes.

**Labels**: `type:infrastructure`, `workflow:cloud`
**Workflow**: Frame → Architect (cost) → Build (Terraform) → Evaluate → Release

**Fields**:
- Change Type: Type of infrastructure modification
- Target Environment: dev/staging/production
- Infrastructure Description: What to create/modify
- AWS Resources: Affected resource types
- Cost Estimate: Expected monthly cost impact
- Security Considerations: Security checklist
- Rollback Plan: How to revert changes

## Usage

After running `/fractary-faber-cloud:init`, users can:

1. Go to GitHub → Issues → New Issue
2. Select "Cloud Infrastructure Change" template
3. Fill out the form
4. Issue is created with `workflow:cloud` label
5. Run `/fractary-faber:run <issue-number>` to execute cloud workflow
```

### Step 6: Implement Init Logic (Template-Copy Pattern)

The init command should programmatically copy workflow templates and add references:

```javascript
// Pseudocode for init implementation using template-copy pattern

function initFaberCloudWorkflow() {
  // 1. Check prerequisites
  const coreConfigPath = '.fractary/plugins/faber/config.json'
  if (!exists(coreConfigPath)) {
    error("Core FABER not initialized. Run /fractary-faber:init first")
    return
  }

  // 2. Create workflows directory if needed
  const workflowsDir = '.fractary/plugins/faber/workflows'
  if (!exists(workflowsDir)) {
    mkdir(workflowsDir)
  }

  // 3. Copy workflow template
  const templatePath = 'plugins/faber-cloud/config/workflows/cloud.json'
  const targetPath = '.fractary/plugins/faber/workflows/cloud.json'

  if (exists(targetPath)) {
    warn("Cloud workflow file already exists, skipping copy")
  } else {
    copyFile(templatePath, targetPath)
    log("Copied cloud workflow template")
  }

  // 4. Load existing config
  const config = readJSON(coreConfigPath)

  // 5. CRITICAL: Verify default workflow reference exists
  const defaultWorkflow = config.workflows.find(w => w.id === 'default')
  if (!defaultWorkflow) {
    error("Default workflow not found. This should never happen. Re-run /fractary-faber:init")
    return
  }

  // 6. Check for duplicate reference
  const existingCloudRef = config.workflows.find(w => w.id === 'cloud')
  if (existingCloudRef) {
    warn("Cloud workflow reference already exists in config")
    return
  }

  // 7. Add workflow reference to config (NOT the full workflow)
  const workflowRef = {
    "id": "cloud",
    "file": "./workflows/cloud.json",
    "description": "Infrastructure workflow (Terraform → Deploy → Monitor)"
  }

  // 8. Add reference to workflows array (PRESERVE default workflow)
  config.workflows.push(workflowRef)

  // 9. Write updated config
  writeJSON(coreConfigPath, config)

  // 10. Validate configuration
  const configValidation = validateConfig(config)
  if (!configValidation.valid) {
    error("Configuration validation failed", configValidation.errors)
    return
  }

  // 11. Validate workflow file
  const workflowValidation = validateWorkflowFile(targetPath)
  if (!workflowValidation.valid) {
    error("Workflow file validation failed", workflowValidation.errors)
    return
  }

  // 12. Report success
  success(`Cloud workflow added to FABER

  Files created:
    - .fractary/plugins/faber/workflows/cloud.json

  Files modified:
    - .fractary/plugins/faber/config.json (added workflow reference)

  Usage:
    /fractary-faber:run <work-id> --workflow cloud

  Customize:
    Edit .fractary/plugins/faber/workflows/cloud.json
    Modify phases, steps, and hooks as needed
  `)
}
```

### Step 7: Update Testing Flow

When testing your plugin integration, verify both workflow and issue template installation:

```bash
# Test integration
1. /fractary-faber:init                    # Core FABER
2. /fractary-faber-cloud:init              # Your plugin

# Verify files created
3. ls .fractary/plugins/faber/workflows/   # Should show cloud.json
4. ls .github/ISSUE_TEMPLATE/              # Should show cloud.yml

# Verify config
5. cat .fractary/plugins/faber/config.json # Should reference cloud workflow

# Test issue template
6. Create test issue using "Cloud Infrastructure Change" template on GitHub
7. /fractary-faber:run <issue-number>      # Should auto-detect workflow from label
```

## Best Practices

### 1. Namespace Your Skills

Use consistent naming:
```
faber-cloud:terraform-manager
faber-cloud:aws-deployer
faber-app:ui-generator
faber-app:api-designer
```

### 2. Provide Multiple Workflow Options

A plugin can provide multiple workflows:

```json
{
  "workflows": [
    {
      "id": "cloud-aws",
      "description": "AWS infrastructure workflow"
    },
    {
      "id": "cloud-gcp",
      "description": "GCP infrastructure workflow"
    },
    {
      "id": "cloud-azure",
      "description": "Azure infrastructure workflow"
    }
  ]
}
```

Let users choose:
```bash
/fractary-faber-cloud:init --provider aws
/fractary-faber-cloud:init --provider gcp
```

### 3. Respect Core FABER Structure

- Don't modify core FABER phases (frame, architect, build, evaluate, release)
- Add steps within phases, don't create new phases
- Use hooks for pre/post phase operations
- Follow phase-level hook structure (10 hooks total)

### 4. Document Skill Dependencies

Clearly document what tools/platforms your skills require:

```markdown
## Prerequisites

- Terraform >= 1.0
- AWS CLI configured
- checkov for security scanning
- Environment variables:
  - AWS_ACCESS_KEY_ID
  - AWS_SECRET_ACCESS_KEY
  - AWS_REGION
```

### 5. Provide Configuration Examples

Show users how to customize your workflows:

```json
// Example customization for faber-cloud
{
  "workflows": [
    {
      "id": "cloud",
      "phases": {
        "build": {
          "steps": [
            {
              "name": "terraform-plan",
              "skill": "faber-cloud:terraform-manager",
              "config": {
                "backend": "s3",
                "state_key": "terraform.tfstate",
                "auto_approve": false
              }
            }
          ]
        }
      }
    }
  ]
}
```

## Testing Your Plugin

### Test Integration Flow

1. Initialize core FABER:
   ```bash
   /fractary-faber:init
   ```

2. Initialize your plugin:
   ```bash
   /fractary-faber-cloud:init
   ```

3. Verify config:
   ```bash
   cat .fractary/plugins/faber/config.json
   # Should show both "default" and "cloud" workflows
   ```

4. Run audit:
   ```bash
   /fractary-faber:audit
   # Should validate both workflows
   ```

5. Test workflow:
   ```bash
   /fractary-faber:run 123 --workflow cloud --autonomy dry-run
   ```

## Examples

### Example 1: faber-cloud Plugin

See `plugins/faber-cloud/` for complete implementation showing:
- Terraform management skills
- AWS deployment skills
- Infrastructure workflows
- Multi-environment support

### Example 2: faber-app Plugin (planned)

Would provide:
- UI generation skills
- API design skills
- Database migration skills
- Full-stack application workflows

## See Also

- [PROJECT-INTEGRATION-GUIDE.md](./PROJECT-INTEGRATION-GUIDE.md) - For end users adopting FABER
- [CONFIGURATION.md](./CONFIGURATION.md) - Configuration reference
- Core FABER: `plugins/faber/`
- Example plugin: `plugins/faber-cloud/`
