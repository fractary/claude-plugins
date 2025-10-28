---
name: devops-init
description: Initialize DevOps plugin configuration for cloud infrastructure management - routes to init-manager agent
tags: [devops, initialization, configuration, setup]
examples:
  - trigger: "/fractary-devops:init"
    action: "Invoke init-manager agent to initialize DevOps configuration"
  - trigger: "/fractary-devops:init --provider=aws --iac=terraform"
    action: "Invoke init-manager with specified provider and IaC tool"
---

# fractary-devops:init

Initializes the DevOps plugin configuration for your project. Creates the configuration file at `.fractary/plugins/devops/config/devops.json` with project-specific settings for cloud infrastructure management.

<CRITICAL_RULES>
**YOU MUST:**
- Create initialization script directly (this is a setup command)
- Do NOT invoke any agents (this is an exception to the normal pattern)
- Prompt user for required configuration values
- Create `.fractary/plugins/devops/config/` directory
- Generate `devops.json` from template at `skills/devops-common/templates/devops.json.template`
- Validate all inputs before saving
- Do NOT commit the config file (contains secrets/profiles)
- Add config directory to `.gitignore` if not already present

**THIS COMMAND PERFORMS SETUP WORK DIRECTLY.**
This is an exception to the normal pattern because it's a one-time setup command.
</CRITICAL_RULES>

<IMPLEMENTATION>
1. Parse command line arguments
2. Detect project information from Git (or prompt)
3. Prompt for provider (AWS, GCP) and IaC tool (Terraform, Pulumi)
4. For AWS: Get account ID via `aws sts get-caller-identity`, prompt for region
5. Read template from `skills/devops-common/templates/devops.json.template`
6. Substitute all placeholders with user values
7. Create config directory: `.fractary/plugins/devops/config/`
8. Save to `.fractary/plugins/devops/config/devops.json`
9. Display configuration summary and next steps
</IMPLEMENTATION>

Create `.fractary/plugins/devops/config/devops.json` configuration file for this project.

## Your Task

Set up DevOps automation configuration by:

1. **Detect Project Information**
   - Extract project name from Git repository
   - Determine namespace from repository structure
   - Detect organization from Git remote

2. **Auto-Discover Infrastructure**
   - Scan for Terraform directory
   - Check for AWS CLI and profiles
   - Detect cloud provider and IaC tool

3. **Generate Configuration**
   - Use template from `skills/devops-common/templates/devops-config.json.template`
   - Substitute detected values
   - Create `.fractary/.config/devops.json`

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

Source: `skills/devops-common/templates/devops-config.json.template`

Placeholders to substitute:
- `{{PROJECT_NAME}}` - Project name from Git
- `{{NAMESPACE}}` - Namespace (org-project pattern)
- `{{ORGANIZATION}}` - Organization from Git remote
- `{{AWS_ACCOUNT_ID}}` - From `aws sts get-caller-identity`
- `{{AWS_REGION}}` - From AWS config or default to us-east-1
- `{{TERRAFORM_DIR}}` - Detected Terraform directory path

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
   # Verify .fractary/.config/devops.json exists
   # Validate JSON syntax
   jq empty .fractary/.config/devops.json
   ```

2. **AWS Profile Validation**
   ```bash
   # Source config loader
   source skills/devops-common/scripts/config-loader.sh
   load_devops_config

   # Validate profiles
   source skills/devops-deployer/providers/aws/auth.sh
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
✓ DevOps configuration initialized

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

Configuration saved to: .fractary/.config/devops.json

Next steps:
  - Review configuration: cat .fractary/.config/devops.json
  - Validate setup: /devops:validate
  - Deploy infrastructure: /devops:deploy test
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

- MUST create `.fractary/.config/` directory if it doesn't exist
- MUST validate JSON syntax after generation
- SHOULD run profile validation if AWS detected
- SHOULD offer to create `.gitignore` entry for sensitive configs
- MUST handle case where config already exists (ask to overwrite)

## Related Commands

- `/devops:validate` - Validate existing configuration
- `/devops:status` - Show current configuration status
- `/devops:deploy` - Deploy infrastructure using configuration
