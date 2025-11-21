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

**Example of correct workflows array:**
```json
{
  "workflows": [
    {
      "id": "default",
      "description": "Standard FABER workflow (Frame → Architect → Build → Evaluate → Release)"
      // ... default workflow is RETAINED
    },
    {
      "id": "cloud",
      "description": "Infrastructure workflow (Terraform → Deploy → Monitor)"
      // ... custom workflow is ADDED
    },
    {
      "id": "hotfix",
      "description": "Expedited workflow for critical patches"
      // ... another custom workflow is ADDED
    }
  ]
}
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
  │   └── init.md              # ADDS "cloud" workflow to core config
  ├── skills/                   # Cloud-specific skills
  │   ├── terraform-manager/
  │   ├── aws-deployer/
  │   ├── cost-estimator/
  │   └── security-scanner/
  └── docs/
      └── workflows/            # Workflow templates for cloud
          └── infrastructure.json
```

## Creating a Specialized Plugin

### Step 1: Plugin Structure

Create standard plugin structure:

```bash
plugins/faber-{type}/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── commands/
│   └── init.md              # Init command (adds workflow)
├── skills/
│   ├── {skill-name}/
│   │   ├── SKILL.md
│   │   └── scripts/
│   └── ...
├── docs/
│   └── workflows/            # Workflow templates
│       └── {type}.json
└── README.md
```

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

Define a workflow that uses your specialized skills:

**Example**: `docs/workflows/cloud.json`

```json
{
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

The init command **adds** your workflow to the core FABER config:

**Example**: `commands/init.md`

```markdown
# /fractary-faber-cloud:init

Initialize cloud infrastructure workflow for FABER.

## What This Does

Adds a "cloud" workflow to `.fractary/plugins/faber/config.json` that uses cloud-specific skills for infrastructure management.

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

## Implementation

This command should:
1. Check if core FABER config exists (require `/fractary-faber:init` first)
2. Load existing config from `.fractary/plugins/faber/config.json`
3. Check if "cloud" workflow already exists (warn if duplicate)
4. Load workflow template from `plugins/faber-cloud/docs/workflows/cloud.json`
5. Add workflow to config's `workflows` array
6. Write updated config back to `.fractary/plugins/faber/config.json`
7. Validate complete configuration
8. Report success with usage instructions

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

### Step 5: Implement Init Logic

The init command should programmatically:

```javascript
// Pseudocode for init implementation

function initFaberCloudWorkflow() {
  // 1. Check prerequisites
  const coreConfigPath = '.fractary/plugins/faber/config.json'
  if (!exists(coreConfigPath)) {
    error("Core FABER not initialized. Run /fractary-faber:init first")
    return
  }

  // 2. Load existing config
  const config = readJSON(coreConfigPath)

  // 2a. CRITICAL: Verify default workflow exists
  const defaultWorkflow = config.workflows.find(w => w.id === 'default')
  if (!defaultWorkflow) {
    error("Default workflow not found. This should never happen. Re-run /fractary-faber:init")
    return
  }

  // 3. Check for duplicates
  const existingCloud = config.workflows.find(w => w.id === 'cloud')
  if (existingCloud) {
    warn("Cloud workflow already exists. Overwrite? (y/n)")
    if (!confirm()) return
  }

  // 4. Load cloud workflow template
  const cloudWorkflow = readJSON('plugins/faber-cloud/docs/workflows/cloud.json')

  // 5. Add to workflows array (PRESERVE default workflow)
  if (existingCloud) {
    // Replace existing cloud workflow ONLY (keep default!)
    const index = config.workflows.findIndex(w => w.id === 'cloud')
    config.workflows[index] = cloudWorkflow
  } else {
    // Add new cloud workflow alongside default
    config.workflows.push(cloudWorkflow)
  }

  // 6. Write updated config
  writeJSON(coreConfigPath, config)

  // 7. Validate
  const validation = validateConfig(config)
  if (!validation.valid) {
    error("Configuration validation failed", validation.errors)
    return
  }

  // 8. Report success
  success(`Cloud workflow added to FABER config

  Usage:
    /fractary-faber:run <work-id> --workflow cloud

  Customize:
    Edit .fractary/plugins/faber/config.json
    Modify the "cloud" workflow as needed
  `)
}
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
