---
name: fractary-faber-cloud:init
description: Initialize faber-cloud plugin configuration for cloud infrastructure management
model: claude-haiku-4-5
argument-hint: [--provider aws] [--iac terraform]
tags: [faber-cloud, initialization, configuration, setup]
examples:
  - trigger: "/fractary-faber-cloud:init"
    action: "Initialize faber-cloud configuration"
  - trigger: "/fractary-faber-cloud:init --provider aws --iac terraform"
    action: "Initialize with specified provider and IaC tool"
---

# fractary-faber-cloud:init

Initializes the faber-cloud plugin configuration for your project. Creates the configuration file at `.fractary/plugins/faber-cloud/config.json` with project-specific settings for cloud infrastructure management.

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:init
/fractary-faber-cloud:init --provider aws --iac terraform

# Incorrect ❌
/fractary-faber-cloud:init --provider=aws --iac=terraform
```
</ARGUMENT_SYNTAX>

<CRITICAL_RULES>
**YOU MUST:**
- Create initialization script directly (this is a setup command)
- Do NOT invoke any agents (this is an exception to the normal pattern)
- Prompt user for required configuration values
- Create `.fractary/plugins/faber-cloud/` directory if needed
- Generate `config.json` from template at `skills/cloud-common/templates/faber-cloud.json.template`
  - If template not found, generate configuration from scratch using auto-discovery
  - This is NORMAL - templates are part of the plugin source, not required in user projects
- Handle migration: If `faber-cloud.json` exists, rename it to `config.json` (preserving all settings)
- Validate all inputs before saving
- Do NOT commit the config file (contains secrets/profiles)
- Add config directory to `.gitignore` if not already present

**THIS COMMAND PERFORMS SETUP WORK DIRECTLY.**
This is an exception to the normal pattern because it's a one-time setup command.

**IMPORTANT ERROR HANDLING:**
- If you get "template not found" or similar errors, DO NOT report "plugin not installed"
- Instead, use auto-discovery to generate configuration
- The template is a convenience - configuration can be generated without it
</CRITICAL_RULES>

<IMPLEMENTATION>
1. Parse command line arguments
2. Check for existing configs and handle migration:
   - If `faber-cloud.json` exists: rename to `config.json`
   - If `devops.json` exists: warn user to migrate manually
   - If `config.json` exists: ask to overwrite or update
3. Detect project information from Git (or prompt)
4. Prompt for provider (AWS, GCP) and IaC tool (Terraform, Pulumi)
5. For AWS: Get account ID via `aws sts get-caller-identity`, prompt for region
6. Read template from `plugins/faber-cloud/config/config.example.json`
7. Substitute all placeholders with user values
8. Create config directory: `.fractary/plugins/faber-cloud/`
9. Create workflows directory: `.fractary/plugins/faber-cloud/workflows/`
10. Copy workflow templates:
    - `plugins/faber-cloud/config/workflows/infrastructure-deploy.json` → `.fractary/plugins/faber-cloud/workflows/infrastructure-deploy.json`
    - `plugins/faber-cloud/config/workflows/infrastructure-audit.json` → `.fractary/plugins/faber-cloud/workflows/infrastructure-audit.json`
    - `plugins/faber-cloud/config/workflows/infrastructure-teardown.json` → `.fractary/plugins/faber-cloud/workflows/infrastructure-teardown.json`
11. Save config to `.fractary/plugins/faber-cloud/config.json`
12. Validate configuration (including workflow file references)
13. Display configuration summary and next steps
</IMPLEMENTATION>

Create `.fractary/plugins/faber-cloud/config.json` configuration file for this project.

## Your Task

Set up cloud infrastructure automation configuration by:

1. **Detect Project Information**
   - Extract project name from Git repository
   - Determine namespace from repository structure
   - Detect organization from Git remote

2. **Auto-Discover Infrastructure**
   - Scan for Terraform directory
   - Check for AWS CLI and profiles
   - Detect cloud provider and IaC tool

3. **Generate Configuration**
   - Check for existing `faber-cloud.json` and migrate to `config.json` if found
   - Use template from `plugins/faber-cloud/config/config.example.json`
   - Substitute detected values
   - Create `.fractary/plugins/faber-cloud/` directory
   - Create `.fractary/plugins/faber-cloud/workflows/` directory
   - Copy workflow templates to project
   - Save config to `.fractary/plugins/faber-cloud/config.json`

4. **Validate Setup**
   - Verify AWS profiles exist
   - Check Terraform directory structure
   - Validate configuration schema

## Auto-Discovery Process

### Project Information

Extract from Git:
```bash
# Project name from repo
git remote get-url origin | sed 's/.*\///' | sed 's/\.git$//'

# Organization from GitHub URL
git remote get-url origin | sed 's/.*github.com[:/]\([^/]*\)\/.*/\1/'

# Namespace: typically organization-project or subdomain
# Examples:
#   corthos/core.corthuxa.ai → corthuxa-core
#   myorg/api.service.com → myorg-api
```

### Infrastructure Detection

Scan directories:
```bash
# Find Terraform directory
find . -type d -name "terraform" -o -name "infrastructure"

# Find tfvars files (indicates environments)
find . -name "*.tfvars"

# Check for AWS profiles in config
aws configure list-profiles
```

### Provider Detection

Check installed tools:
```bash
# AWS
command -v aws && aws sts get-caller-identity

# GCP
command -v gcloud && gcloud config get-value project

# Azure
command -v az && az account show

# Terraform
command -v terraform && terraform version

# Pulumi
command -v pulumi && pulumi version
```

## Configuration Template

Source: `plugins/faber-cloud/config/config.example.json`

This template includes workflow file references:
```json
{
  "workflows": [
    {
      "id": "infrastructure-deploy",
      "file": "./workflows/infrastructure-deploy.json"
    },
    {
      "id": "infrastructure-audit",
      "file": "./workflows/infrastructure-audit.json"
    },
    {
      "id": "infrastructure-teardown",
      "file": "./workflows/infrastructure-teardown.json"
    }
  ]
}
```

Placeholders to substitute:
- `{{PROJECT_NAME}}` - Project name from Git
- `{{SUBSYSTEM}}` - Subsystem name (if applicable)
- `{{ORGANIZATION}}` - Organization from Git remote
- `{{HOSTING_PROVIDER}}` - Cloud provider (aws, gcp, azure)
- `{{AWS_ACCOUNT_ID}}` - From `aws sts get-caller-identity`
- `{{AWS_REGION}}` - From AWS config or default to us-east-1
- `{{IAC_TOOL}}` - IaC tool (terraform, pulumi)

## What Gets Created

**Directory structure**:
```
.fractary/plugins/faber-cloud/
├── config.json                           # Main configuration (references workflows)
└── workflows/                            # Workflow definition files
    ├── infrastructure-deploy.json        # Standard deployment workflow
    ├── infrastructure-audit.json         # Non-destructive audit workflow
    └── infrastructure-teardown.json      # Safe destruction workflow
```

**Workflow files** are copied from `plugins/faber-cloud/config/workflows/` and contain:
- Complete FABER phase definitions (Frame → Architect → Build → Evaluate → Release)
- Infrastructure-specific hooks
- Autonomy settings for each workflow type

## Interactive Prompts

If auto-discovery fails or needs confirmation, ask user:

1. **Provider Selection** (if multiple detected or none):
   - Question: "Which cloud provider do you use?"
   - Options: AWS, GCP, Azure, Other

2. **IaC Tool Selection** (if multiple detected or none):
   - Question: "Which Infrastructure as Code tool do you use?"
   - Options: Terraform, Pulumi, CloudFormation, CDK, Other

3. **Environment Confirmation** (if profiles detected):
   - Question: "Configure these AWS profiles?"
   - Show detected profiles
   - Options: Yes (use detected), No (manual entry)

4. **Terraform Directory** (if multiple candidates):
   - Question: "Which directory contains your Terraform code?"
   - Options: List of detected directories

## Validation

After generating configuration:

1. **File Structure Check**
   ```bash
   # Verify .fractary/plugins/faber-cloud/config.json exists
   # Validate JSON syntax
   jq empty .fractary/plugins/faber-cloud/config.json
   ```

2. **AWS Profile Validation**
   ```bash
   # Source config loader
   source skills/cloud-common/scripts/config-loader.sh
   load_config

   # Validate profiles
   source skills/handler-hosting-aws/scripts/auth.sh
   validate_all_profiles
   ```

3. **Terraform Validation**
   ```bash
   # Check Terraform directory
   [ -d "$TERRAFORM_DIR" ] && echo "✓ Terraform directory found"

   # Check for .tfvars files
   ls "$TERRAFORM_DIR"/*.tfvars
   ```

## Success Output

Display configuration summary:
```
✓ faber-cloud configuration initialized

Project: corthography
Namespace: corthuxa-core
Organization: corthos

Provider: AWS
  Account: 123456789012
  Region: us-east-1

IaC Tool: Terraform
  Directory: ./infrastructure/terraform

AWS Profiles:
  ✓ Discover: corthuxa-core-discover-deploy
  ✓ Test: corthuxa-core-test-deploy
  ✓ Prod: corthuxa-core-prod-deploy

Workflows:
  ✓ infrastructure-deploy (Standard deployment)
  ✓ infrastructure-audit (Non-destructive audit)
  ✓ infrastructure-teardown (Safe destruction)

Files created:
  ✓ .fractary/plugins/faber-cloud/config.json
  ✓ .fractary/plugins/faber-cloud/workflows/infrastructure-deploy.json
  ✓ .fractary/plugins/faber-cloud/workflows/infrastructure-audit.json
  ✓ .fractary/plugins/faber-cloud/workflows/infrastructure-teardown.json

Next steps:
  - Review configuration: cat .fractary/plugins/faber-cloud/config.json
  - Review workflows: ls .fractary/plugins/faber-cloud/workflows/
  - Customize workflows: Edit workflow files in .fractary/plugins/faber-cloud/workflows/
  - Validate setup: /fractary-faber-cloud:validate
  - Deploy infrastructure: /fractary-faber-cloud:manage <work-id> --workflow infrastructure-deploy
```

## Error Handling

**No Git Repository:**
- Prompt for manual project name entry
- Warn that auto-discovery limited

**No Cloud Provider Detected:**
- Ask user to select provider
- Offer to configure AWS CLI or other provider

**No IaC Tool Detected:**
- Ask user to select tool
- Offer installation instructions

**AWS Profiles Missing:**
- Show how to create profiles
- Link to AWS configuration guide

**Invalid Terraform Directory:**
- Ask user to specify directory
- Offer to create basic structure

## Implementation Notes

- MUST create `.fractary/plugins/faber-cloud/` directory if it doesn't exist
- MUST create `.fractary/plugins/faber-cloud/workflows/` directory
- MUST copy workflow templates from `plugins/faber-cloud/config/workflows/` to project:
  - infrastructure-deploy.json
  - infrastructure-audit.json
  - infrastructure-teardown.json
- MUST check for existing `faber-cloud.json` and migrate to `config.json` if found
- MUST use config template from `plugins/faber-cloud/config/config.example.json`
- MUST validate JSON syntax after generation (config + all workflow files)
- MUST validate workflow file references in config.json
- SHOULD run profile validation if AWS detected
- SHOULD offer to create `.gitignore` entry for sensitive configs
- MUST handle case where config already exists (ask to overwrite)
- MUST log migration action when renaming faber-cloud.json → config.json

## Related Commands

- `/fractary-faber-cloud:validate` - Validate existing configuration
- `/fractary-faber-cloud:status` - Show current configuration status
- `/fractary-faber-cloud:deploy-apply` - Deploy infrastructure using configuration
