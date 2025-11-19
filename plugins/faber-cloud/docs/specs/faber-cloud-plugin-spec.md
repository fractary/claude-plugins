# Fractary DevOps Plugin Specification

**Version:** 1.0
**Status:** Draft
**Last Updated:** 2025-10-18
**Author:** Fractary Engineering

---

## Table of Contents

1. [Overview](#overview)
2. [Goals and Principles](#goals-and-principles)
3. [Architecture](#architecture)
4. [Configuration System](#configuration-system)
5. [Directory Structure](#directory-structure)
6. [Provider and IaC Plugin System](#provider-and-iac-plugin-system)
7. [Commands and Agents](#commands-and-agents)
8. [Initialization System](#initialization-system)
9. [Distribution Model](#distribution-model)
10. [Implementation Phases](#implementation-phases)
11. [Migration Path](#migration-path)
12. [Testing Strategy](#testing-strategy)
13. [Future Extensions](#future-extensions)

---

## Overview

### Problem Statement

Currently, infrastructure deployment skills are tightly coupled to:
- Specific cloud providers (AWS)
- Specific IaC tools (Terraform)
- Specific projects (corthuxa)
- Specific naming conventions

This creates duplication across projects and makes it difficult to:
- Reuse deployment logic across projects
- Support multiple cloud providers
- Support multiple IaC tools
- Maintain consistency across projects

### Solution

Create a **generic, extensible DevOps plugin** for Claude Code that:
- Works across multiple cloud providers (AWS, GCP, Azure, etc.)
- Works across multiple IaC tools (Terraform, Pulumi, CloudFormation, CDK, etc.)
- Works across multiple project types (JS, Python, Go, etc.)
- Configures via a simple JSON file
- Extends through provider and IaC plugins
- Distributes as a single Claude Code plugin

---

## Goals and Principles

### Primary Goals

1. **Generic by Default**: Commands and workflows work for any provider/IaC tool
2. **Config-Driven**: Project configuration determines behavior, not separate commands
3. **Extensible**: Easy to add new providers and IaC tools without changing core
4. **Consistent UX**: Same commands work across all projects
5. **Language-Agnostic**: Works for JS, Python, Go, Ruby, etc.
6. **Fractary-Branded**: All configuration lives in `.fractary/` namespace

### Design Principles

- **Convention over Configuration**: Sensible defaults, override only when needed
- **Plugin Architecture**: Providers and IaC tools are plugins, not forks
- **Fail-Safe**: Errors are caught and categorized before delegation
- **Discoverable**: Auto-detect project settings when possible
- **Auditable**: All changes tracked and documented
- **Idempotent**: Safe to re-run operations

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────┐
│         User Commands                           │
│   /faber-cloud:deploy /faber-cloud:debug /faber-cloud:init     │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│         Generic Orchestrator                    │
│   (devops-deployer, devops-debugger, etc.)      │
└────────────────┬────────────────────────────────┘
                 │
                 ├─── Reads Config (.fractary/plugins/faber-cloud/faber-cloud.json)
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│         Plugin Selector                         │
│   provider: aws → providers/aws/*               │
│   iac_tool: terraform → iac-tools/terraform/*   │
└────────────────┬────────────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌──────────────┐  ┌──────────────┐
│   Provider   │  │   IaC Tool   │
│   Plugins    │  │   Plugins    │
│              │  │              │
│ aws/         │  │ terraform/   │
│ gcp/         │  │ pulumi/      │
│ azure/       │  │ cdk/         │
└──────────────┘  └──────────────┘
```

### Component Responsibilities

**Generic Orchestrator:**
- Validates prerequisites
- Loads configuration
- Selects appropriate plugins
- Executes deployment workflow
- Handles errors and retries
- Generates documentation

**Provider Plugins:**
- Authentication (profiles, service accounts, etc.)
- Permission management (IAM, RBAC, etc.)
- Resource naming conventions
- Provider-specific error handling

**IaC Tool Plugins:**
- Tool initialization (init, setup)
- Planning (plan, preview)
- Application (apply, up)
- Error parsing and fixing
- State management

---

## Configuration System

### Configuration File Location

**Path:** `.fractary/plugins/faber-cloud/faber-cloud.json`

**Rationale:**
- Fractary-branded namespace (consistent with other Fractary tools)
- `.config/` subdirectory for organization
- Language-agnostic (works for any project type)
- Version-controllable
- Won't conflict with language-specific tooling

### Configuration Schema

```json
{
  "$schema": "https://raw.githubusercontent.com/fractary/claude-devops-plugin/main/schemas/devops-config.schema.json",
  "version": "1.0",

  "provider": "aws",
  "iac_tool": "terraform",

  "project": {
    "name": "corthuxa",
    "namespace": "corthuxa-core",
    "organization": "corthos",
    "repository_name": "core.corthuxa.ai"
  },

  "aws": {
    "account_id": "092446241284",
    "region": "us-east-1",
    "profiles": {
      "discover": "corthuxa-core-discover-deploy",
      "test": "corthuxa-core-test-deploy",
      "prod": "corthuxa-core-prod-deploy"
    },
    "iam": {
      "user_name_pattern": "{namespace}-{environment}-deploy",
      "policy_name_pattern": "{project}-{environment}-deploy-terraform"
    },
    "resource_naming": {
      "prefix": "corthuxa",
      "separator": "-"
    }
  },

  "terraform": {
    "directory": "infrastructure/terraform",
    "required_version": ">=1.5.0",
    "backend": "s3",
    "backend_config": {
      "bucket": "corthuxa-terraform-state",
      "key": "infrastructure/terraform.tfstate",
      "region": "us-east-1"
    }
  },

  "environments": ["test", "prod"],

  "directories": {
    "terraform": "infrastructure/terraform",
    "iam_policies": "infrastructure/iam-policies"
  },

  "features": {
    "build_lambda": true,
    "lambda_packages": ["packages/build-trigger"],
    "validate_plan_environment": true,
    "minimum_versions": {
      "terraform": "1.5.0",
      "node": "18.0.0",
      "pnpm": "8.0.0"
    }
  },

  "deployment": {
    "s3_bucket_patterns": [
      "{prefix}-core-{environment}-input",
      "{prefix}-core-{environment}-output"
    ],
    "lambda_functions": [
      "{prefix}-build-trigger-{environment}"
    ],
    "state_machines": [
      "{prefix}-build-orchestrator-{environment}"
    ]
  }
}
```

### Pattern Substitution

Configuration values support pattern substitution:

**Available Placeholders:**
- `{project}` - Project name
- `{namespace}` - Project namespace
- `{environment}` - Current environment (test, prod, etc.)
- `{prefix}` - Resource prefix
- `{organization}` - Organization name

**Examples:**
```
"{prefix}-{environment}-bucket" → "corthuxa-test-bucket"
"{namespace}-{environment}-deploy" → "corthuxa-core-test-deploy"
```

### Auto-Discovery Fallbacks

When configuration values are missing, the system attempts auto-discovery:

```bash
# Project name from Git repository
PROJECT_NAME=$(basename $(git rev-parse --show-toplevel))

# AWS account from credentials
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

# Terraform directory from file search
TERRAFORM_DIR=$(find . -maxdepth 3 -name "terraform" -type d | head -1)

# AWS profiles from AWS CLI config
PROFILES=$(aws configure list-profiles | grep -E "(test|prod)-deploy")
```

### Configuration Validation

The plugin includes a JSON schema for IDE validation and a validation command:

```bash
/faber-cloud:validate
```

Validates:
- Required fields present
- Valid provider/iac_tool values
- Pattern syntax correctness
- Directory paths exist
- AWS profiles accessible
- Version requirements met

---

## Directory Structure

### Complete Plugin Structure

```
fractary-faber-cloud-plugin/
├── plugin.json                       # Claude Code plugin manifest
│
├── agents/                           # Auto-triggered agents
│   ├── devops-deployer.md
│   ├── devops-debugger.md
│   └── devops-permissions.md
│
├── commands/                         # User-invoked commands
│   ├── init.md                      # /faber-cloud:init
│   ├── architect.md                 # /faber-cloud:architect
│   ├── engineer.md                  # /faber-cloud:engineer
│   ├── validate.md                  # /faber-cloud:validate
│   ├── test.md                      # /faber-cloud:test
│   ├── audit.md                     # /faber-cloud:audit
│   ├── deploy-plan.md               # /faber-cloud:deploy-plan
│   ├── deploy-apply.md              # /faber-cloud:deploy-apply
│   ├── teardown.md                  # /faber-cloud:teardown
│   ├── list.md                      # /faber-cloud:list
│   ├── status.md                    # /faber-cloud:status
│   ├── debug.md                     # /faber-cloud:debug
│   ├── manage.md                    # /faber-cloud:manage
│   └── director.md                  # /faber-cloud:director
│
├── skills/                          # Core implementation
│   ├── devops-common/               # Shared utilities
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   ├── config-loader.sh
│   │   │   ├── pattern-resolver.sh
│   │   │   ├── workflow-orchestrator.sh
│   │   │   ├── error-classifier.sh
│   │   │   └── auto-discovery.sh
│   │   └── templates/
│   │       ├── devops-config.json.template
│   │       └── devops-config.schema.json
│   │
│   ├── devops-deployer/             # Deployment orchestrator
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   ├── deploy.sh                # Main orchestrator
│   │   │   ├── validate-prerequisites.sh
│   │   │   ├── build-artifacts.sh
│   │   │   ├── verify-deployment.sh
│   │   │   └── generate-documentation.sh
│   │   │
│   │   ├── providers/               # Provider-specific implementations
│   │   │   ├── aws/
│   │   │   │   ├── README.md
│   │   │   │   ├── auth.sh
│   │   │   │   ├── permissions.sh
│   │   │   │   ├── resource-naming.sh
│   │   │   │   ├── validation.sh
│   │   │   │   └── verification.sh
│   │   │   │
│   │   │   ├── gcp/
│   │   │   │   ├── README.md
│   │   │   │   ├── auth.sh
│   │   │   │   ├── permissions.sh
│   │   │   │   ├── resource-naming.sh
│   │   │   │   └── ...
│   │   │   │
│   │   │   └── azure/
│   │   │       ├── README.md
│   │   │       └── ...
│   │   │
│   │   ├── iac-tools/               # IaC tool implementations
│   │   │   ├── terraform/
│   │   │   │   ├── README.md
│   │   │   │   ├── init.sh
│   │   │   │   ├── validate.sh
│   │   │   │   ├── plan.sh
│   │   │   │   ├── apply.sh
│   │   │   │   ├── destroy.sh
│   │   │   │   ├── error-parser.sh
│   │   │   │   └── state-manager.sh
│   │   │   │
│   │   │   ├── pulumi/
│   │   │   │   ├── README.md
│   │   │   │   ├── install.sh
│   │   │   │   ├── preview.sh
│   │   │   │   ├── up.sh
│   │   │   │   ├── destroy.sh
│   │   │   │   └── error-parser.sh
│   │   │   │
│   │   │   ├── cloudformation/
│   │   │   │   └── ...
│   │   │   │
│   │   │   └── cdk/
│   │   │       └── ...
│   │   │
│   │   ├── templates/               # Documentation templates
│   │   │   ├── deployment-report.md.template
│   │   │   ├── infrastructure-docs.md.template
│   │   │   └── deployment-summary.md.template
│   │   │
│   │   └── guides/
│   │       ├── adding-providers.md
│   │       ├── adding-iac-tools.md
│   │       └── customization.md
│   │
│   ├── devops-debugger/             # Error debugging
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   ├── debug.sh
│   │   │   ├── categorize-errors.sh
│   │   │   └── fix-errors.sh
│   │   │
│   │   ├── providers/               # Provider-specific debugging
│   │   │   ├── aws/
│   │   │   │   ├── debug-permissions.sh
│   │   │   │   ├── debug-resources.sh
│   │   │   │   └── fix-iam.sh
│   │   │   │
│   │   │   ├── gcp/
│   │   │   │   └── ...
│   │   │   │
│   │   │   └── azure/
│   │   │       └── ...
│   │   │
│   │   └── iac-tools/               # IaC-specific debugging
│   │       ├── terraform/
│   │       │   ├── fix-config.sh
│   │       │   ├── fix-state.sh
│   │       │   └── fix-syntax.sh
│   │       │
│   │       ├── pulumi/
│   │       │   └── ...
│   │       │
│   │       └── cloudformation/
│   │           └── ...
│   │
│   └── devops-permissions/          # Permission management
│       ├── SKILL.md
│       ├── scripts/
│       │   ├── manage-permissions.sh
│       │   └── audit-permissions.sh
│       │
│       └── providers/               # Provider-specific IAM
│           ├── aws/
│           │   ├── update-iam-user.sh
│           │   ├── update-iam-role.sh
│           │   ├── audit-system.sh
│           │   └── README.md
│           │
│           ├── gcp/
│           │   ├── update-service-account.sh
│           │   ├── update-iam-policy.sh
│           │   └── README.md
│           │
│           └── azure/
│               └── ...
│
└── hooks/                           # Optional deployment hooks
    ├── pre-deploy.sh
    ├── post-deploy.sh
    └── on-error.sh
```

### Project Structure (After Init)

```
my-project/
├── .fractary/
│   └── .config/
│       └── devops.json              # Generated by /faber-cloud:init
│
├── .claude/
│   └── [other Claude config]
│
└── [project files]
```

---

## Provider and IaC Plugin System

### Plugin Architecture

Plugins are **not separate installations** - they ship with the main plugin and are **activated by configuration**.

### Provider Plugin Interface

Each provider plugin must implement:

**Authentication:**
```bash
# providers/aws/auth.sh
authenticate_provider() {
    local environment=$1
    # Set AWS_PROFILE based on config
    # Validate credentials
    # Return success/failure
}
```

**Permission Management:**
```bash
# providers/aws/permissions.sh
add_deployment_permission() {
    local permission=$1
    local environment=$2
    # Add IAM permission to deploy user
    # Update audit trail
    # Verify permission added
}
```

**Resource Naming:**
```bash
# providers/aws/resource-naming.sh
resolve_resource_name() {
    local pattern=$1
    local environment=$2
    # Substitute {placeholders}
    # Apply provider conventions
    # Return resolved name
}
```

**Validation:**
```bash
# providers/aws/validation.sh
validate_provider_config() {
    # Check required config fields
    # Validate credentials exist
    # Verify permissions
    # Return validation results
}
```

### IaC Tool Plugin Interface

Each IaC tool plugin must implement:

**Initialization:**
```bash
# iac-tools/terraform/init.sh
iac_init() {
    local environment=$1
    # Run terraform init
    # Configure backend
    # Return success/failure
}
```

**Planning:**
```bash
# iac-tools/terraform/plan.sh
iac_plan() {
    local environment=$1
    local output_file=$2
    # Run terraform plan
    # Parse output
    # Return plan summary
}
```

**Application:**
```bash
# iac-tools/terraform/apply.sh
iac_apply() {
    local environment=$1
    local plan_file=$2
    # Run terraform apply
    # Monitor progress
    # Return results
}
```

**Error Parsing:**
```bash
# iac-tools/terraform/error-parser.sh
parse_iac_error() {
    local error_output=$1
    # Extract error type
    # Identify resource/line
    # Categorize error
    # Return structured error
}
```

### Plugin Selection Logic

```bash
# skills/devops-common/scripts/config-loader.sh

load_plugins() {
    # Read config
    PROVIDER=$(jq -r '.provider' .fractary/plugins/faber-cloud/faber-cloud.json)
    IAC_TOOL=$(jq -r '.iac_tool' .fractary/plugins/faber-cloud/faber-cloud.json)

    # Validate plugins exist
    PROVIDER_DIR="${SKILL_DIR}/providers/${PROVIDER}"
    IAC_DIR="${SKILL_DIR}/iac-tools/${IAC_TOOL}"

    if [ ! -d "$PROVIDER_DIR" ]; then
        echo "❌ Provider plugin not found: ${PROVIDER}"
        echo "Available: $(ls ${SKILL_DIR}/providers/)"
        exit 1
    fi

    if [ ! -d "$IAC_DIR" ]; then
        echo "❌ IaC tool plugin not found: ${IAC_TOOL}"
        echo "Available: $(ls ${SKILL_DIR}/iac-tools/)"
        exit 1
    fi

    # Source plugin functions
    for script in ${PROVIDER_DIR}/*.sh; do
        source "$script"
    done

    for script in ${IAC_DIR}/*.sh; do
        source "$script"
    done
}
```

### Adding New Providers

To add a new provider (e.g., DigitalOcean):

1. Create `providers/digitalocean/` directory
2. Implement required interface functions
3. Add provider documentation
4. Update schema to include "digitalocean" as valid provider
5. Test with sample project

**No changes required to core orchestrator.**

### Adding New IaC Tools

To add a new IaC tool (e.g., Ansible):

1. Create `iac-tools/ansible/` directory
2. Implement required interface functions
3. Add tool documentation
4. Update schema to include "ansible" as valid tool
5. Test with sample project

**No changes required to core orchestrator.**

---

## Commands and Agents

### Commands

Commands are user-invoked via `/faber-cloud:*` pattern.

#### `/faber-cloud:init`

**Purpose:** Initialize DevOps configuration for a project

**Workflow:**
1. Check if `.fractary/plugins/faber-cloud/faber-cloud.json` already exists
2. If exists, prompt to overwrite or update
3. If not exists, run setup wizard:
   - Detect project name from Git
   - Prompt for provider (aws/gcp/azure/etc.)
   - Prompt for IaC tool (terraform/pulumi/etc.)
   - Auto-discover AWS profiles (if AWS)
   - Auto-discover Terraform directory (if Terraform)
   - Generate configuration file
   - Validate configuration
4. Display configuration summary
5. Optionally run `/faber-cloud:validate`

**Example Usage:**
```bash
/faber-cloud:init
```

#### `/faber-cloud:deploy [environment]`

**Purpose:** Deploy infrastructure to specified environment

**Arguments:**
- `environment` - Target environment (test, prod, etc.)
- Defaults to `test` if not specified

**Workflow:**
1. Load configuration
2. Validate prerequisites
3. Authenticate with provider
4. Build artifacts (if configured)
5. Initialize IaC tool
6. Generate plan
7. Validate plan safety
8. Prompt for confirmation
9. Apply infrastructure
10. Verify deployment
11. Generate documentation

**Example Usage:**
```bash
/faber-cloud:deploy test
/faber-cloud:deploy prod
```

#### `/faber-cloud:debug`

**Purpose:** Debug most recent deployment errors

**Workflow:**
1. Parse errors from recent conversation context
2. Categorize errors (permission, config, state, resource)
3. For each error:
   - Show diagnosis
   - Prompt for fix approval (interactive) or auto-fix (--complete)
   - Delegate to appropriate provider/IaC plugin
   - Verify fix
4. Provide retry instructions

**Example Usage:**
```bash
/faber-cloud:debug
/faber-cloud:debug --complete  # Auto-fix all errors
```

#### `/faber-cloud:permissions`

**Purpose:** Manage deployment permissions

**Workflow:**
1. Parse permission error from context or prompt
2. Validate this is a deployment permission (not resource)
3. Show current permissions from audit
4. Prompt for confirmation
5. Add permission via provider plugin
6. Update audit trail
7. Verify permission added

**Example Usage:**
```bash
/faber-cloud:permissions
```

#### `/faber-cloud:validate`

**Purpose:** Validate DevOps configuration

**Workflow:**
1. Load configuration file
2. Validate against JSON schema
3. Check provider plugin exists
4. Check IaC tool plugin exists
5. Verify all directory paths exist
6. Validate credentials/authentication
7. Check required tool versions
8. Report validation results

**Example Usage:**
```bash
/faber-cloud:validate
```

#### `/faber-cloud:status`

**Purpose:** Show deployment status for environment

**Workflow:**
1. Load configuration
2. Authenticate with provider
3. Query infrastructure state via IaC tool
4. Show deployed resources
5. Show recent deployments
6. Show any drift detected

**Example Usage:**
```bash
/faber-cloud:status test
/faber-cloud:status prod
```

### Agents

Agents are auto-triggered based on context patterns.

#### devops-deployer

**Trigger Patterns:**
- "deploy.*infrastructure"
- "deploy to (test|prod|staging)"
- "run deployment"

**Behavior:**
Auto-invokes `/faber-cloud:deploy` workflow with detected environment.

#### devops-debugger

**Trigger Patterns:**
- "fix.*deployment.*error"
- "debug.*terraform.*error"
- "permission.*denied"

**Behavior:**
Auto-invokes `/faber-cloud:debug` workflow in interactive mode.

#### devops-permissions

**Trigger Patterns:**
- "add.*permission.*deploy"
- "iam.*permission.*error"
- "access.*denied.*deploy"

**Behavior:**
Auto-invokes `/faber-cloud:permissions` workflow.

---

## Initialization System

### The `/faber-cloud:init` Command

This is a **critical component** for creating the configuration file outside the Claude/plugin directories.

### Interactive Setup Wizard

```bash
/faber-cloud:init
```

**Wizard Flow:**

```
Welcome to Fractary DevOps Configuration Setup!

This wizard will help you configure DevOps automation for your project.

Detecting project settings...
✓ Project name: corthuxa (from Git repository)
✓ Organization: corthos (from Git remote)
✓ Repository: core.corthuxa.ai

1. Cloud Provider
   Which cloud provider are you using?
   [1] AWS (Amazon Web Services)
   [2] GCP (Google Cloud Platform)
   [3] Azure (Microsoft Azure)
   [4] DigitalOcean
   [5] Other

   > 1

   ✓ Selected: AWS

2. Infrastructure-as-Code Tool
   Which IaC tool are you using?
   [1] Terraform
   [2] Pulumi
   [3] AWS CloudFormation
   [4] AWS CDK
   [5] Other

   > 1

   ✓ Selected: Terraform

3. AWS Configuration
   Detecting AWS profiles...
   Found profiles:
   - corthuxa-core-discover-deploy
   - corthuxa-core-test-deploy
   - corthuxa-core-prod-deploy

   Discovery profile (for IAM management): corthuxa-core-discover-deploy
   Test deploy profile: corthuxa-core-test-deploy
   Prod deploy profile: corthuxa-core-prod-deploy

   Confirm? [Y/n] y

   ✓ AWS profiles configured

4. Terraform Configuration
   Detecting Terraform directory...
   Found: infrastructure/terraform

   Use this directory? [Y/n] y

   Required Terraform version: >=1.5.0

   ✓ Terraform directory configured

5. Environments
   Which environments do you deploy to?
   [test, prod] (comma-separated)

   > test, prod

   ✓ Environments configured

6. Review Configuration

   Project: corthuxa
   Provider: AWS
   IaC Tool: Terraform
   Environments: test, prod

   AWS Profiles:
   - discover: corthuxa-core-discover-deploy
   - test: corthuxa-core-test-deploy
   - prod: corthuxa-core-prod-deploy

   Terraform Directory: infrastructure/terraform

   Create configuration? [Y/n] y

   ✓ Creating .fractary/plugins/faber-cloud/faber-cloud.json...
   ✓ Validating configuration...
   ✓ Configuration created successfully!

Next steps:
1. Review configuration: cat .fractary/plugins/faber-cloud/faber-cloud.json
2. Validate setup: /faber-cloud:validate
3. Deploy infrastructure: /faber-cloud:deploy test

For more information, see: /faber-cloud:help
```

### Configuration File Generation

The wizard creates `.fractary/plugins/faber-cloud/faber-cloud.json` with:
- User-provided values
- Auto-discovered values
- Sensible defaults
- Comments for customization

### Post-Init Validation

After creation, automatically runs:
```bash
/faber-cloud:validate
```

To ensure configuration is complete and correct.

---

## Distribution Model

### Claude Code Plugin

The Fractary DevOps plugin is distributed as a **Claude Code plugin**.

### Installation

**Method 1: Claude Plugin Marketplace** (Future)
```bash
# In Claude Code
/plugins:install fractary-faber-cloud
```

**Method 2: Git Clone** (Current)
```bash
# Clone plugin repository
git clone https://github.com/fractary/claude-devops-plugin.git \
    ~/.claude/plugins/fractary-faber-cloud

# Reload Claude Code plugins
/plugins:reload
```

### Plugin Manifest

```json
{
  "name": "fractary-faber-cloud",
  "version": "1.0.0",
  "description": "Generic DevOps automation for AWS, GCP, Azure + Terraform, Pulumi, CDK",
  "author": "Fractary",
  "homepage": "https://github.com/fractary/claude-devops-plugin",
  "license": "MIT",
  "keywords": ["devops", "terraform", "aws", "gcp", "azure", "deployment"],
  "requires": {
    "claude-code": ">=1.0.0"
  },
  "commands": [
    "/faber-cloud:init",
    "/faber-cloud:deploy",
    "/faber-cloud:debug",
    "/faber-cloud:permissions",
    "/faber-cloud:validate",
    "/faber-cloud:status"
  ],
  "agents": [
    "devops-deployer",
    "devops-debugger",
    "devops-permissions"
  ]
}
```

### Plugin Updates

Users update via:
```bash
cd ~/.claude/plugins/fractary-faber-cloud
git pull
/plugins:reload
```

Or via Claude plugin manager (future):
```bash
/plugins:update fractary-faber-cloud
```

### Configuration File Management

**Important:** The configuration file (`.fractary/plugins/faber-cloud/faber-cloud.json`) is:
- **NOT** included in the plugin
- **Generated per-project** by `/faber-cloud:init`
- **Version-controlled with the project**
- **User-editable**

The plugin only provides the **template** for the config file.

---

## Implementation Phases

### Phase 1: Extract and Generify Core (Week 1-2)

**Goals:**
- Extract current corthuxa infrastructure skills
- Create plugin directory structure
- Implement configuration system
- Create AWS + Terraform plugins (baseline)

**Deliverables:**
- `fractary-faber-cloud-plugin/` repository
- `devops-common/` with config-loader
- `devops-deployer/` with AWS+Terraform support
- `devops-debugger/` with AWS+Terraform support
- `devops-permissions/` with AWS IAM support
- `/faber-cloud:init` command
- Configuration template and schema

**Testing:**
- Test with corthuxa project
- Validate deployment workflow
- Verify all existing features work

### Phase 2: Documentation and Examples (Week 2-3)

**Goals:**
- Comprehensive documentation
- Multiple example projects
- Migration guides

**Deliverables:**
- README.md with quick start
- ARCHITECTURE.md with design details
- PROVIDERS.md with provider plugin guide
- IAC-TOOLS.md with IaC tool plugin guide
- Example configurations for common setups
- Migration guide from corthuxa skills

**Testing:**
- Test with new test project
- Validate documentation accuracy
- Test migration process

### Phase 3: Additional Providers (Week 3-4)

**Goals:**
- Add GCP provider support
- Validate multi-provider architecture

**Deliverables:**
- `providers/gcp/` plugin
- GCP authentication
- GCP IAM management
- GCP-specific validation
- GCP example configuration

**Testing:**
- Deploy to GCP test project
- Verify plugin isolation
- Test provider switching

### Phase 4: Additional IaC Tools (Week 4-5)

**Goals:**
- Add Pulumi support
- Validate multi-IaC architecture

**Deliverables:**
- `iac-tools/pulumi/` plugin
- Pulumi installation
- Pulumi preview/up workflows
- Pulumi error parsing
- Pulumi example configuration

**Testing:**
- Deploy with Pulumi
- Test IaC tool switching
- Verify backward compatibility

### Phase 5: Polish and Release (Week 5-6)

**Goals:**
- Production-ready release
- Plugin marketplace submission

**Deliverables:**
- Complete test coverage
- Performance optimization
- Error handling improvements
- Release documentation
- Plugin marketplace listing

**Testing:**
- End-to-end testing
- Performance benchmarks
- Security audit
- User acceptance testing

---

## Migration Path

### Migrating from Corthuxa-Specific Skills

**Current State:**
- Skills: `infrastructure-deployer`, `infrastructure-debugger`, `managing-deploy-permissions`
- Location: `.claude/skills/`
- Hardcoded: AWS profiles, resource names, Terraform paths

**Migration Steps:**

1. **Install Plugin**
   ```bash
   git clone https://github.com/fractary/claude-devops-plugin.git \
       ~/.claude/plugins/fractary-faber-cloud
   ```

2. **Initialize Configuration**
   ```bash
   /faber-cloud:init
   ```

   Wizard auto-detects:
   - AWS profiles from existing setup
   - Terraform directory
   - Project name
   - Generates `.fractary/plugins/faber-cloud/faber-cloud.json`

3. **Validate Configuration**
   ```bash
   /faber-cloud:validate
   ```

4. **Test Deployment**
   ```bash
   /faber-cloud:deploy test
   ```

5. **Remove Old Skills** (after validation)
   ```bash
   rm -rf .claude/skills/infrastructure-*
   rm -rf .claude/skills/managing-deploy-permissions
   ```

6. **Update Commands**
   - Old: `/infrastructure:deploy`
   - New: `/faber-cloud:deploy`

7. **Commit Configuration**
   ```bash
   git add .fractary/plugins/faber-cloud/faber-cloud.json
   git commit -m "Add Fractary DevOps configuration"
   ```

### Migration Checklist

- [ ] Install fractary-faber-cloud plugin
- [ ] Run `/faber-cloud:init` and generate config
- [ ] Validate config with `/faber-cloud:validate`
- [ ] Test deployment to test environment
- [ ] Compare deployment outputs with old skills
- [ ] Verify all features work (build, deploy, permissions)
- [ ] Remove old skills after validation
- [ ] Update any custom scripts/docs
- [ ] Commit configuration to version control
- [ ] Deploy to production with new plugin

---

## Testing Strategy

### Unit Testing

**Config Loader:**
- Test pattern substitution
- Test auto-discovery
- Test validation
- Test error handling

**Provider Plugins:**
- Test authentication
- Test permission management
- Test resource naming
- Test each provider independently

**IaC Tool Plugins:**
- Test init/plan/apply workflows
- Test error parsing
- Test state management
- Test each tool independently

### Integration Testing

**Full Deployment Workflow:**
- Test init → validate → deploy-apply → verify
- Test with multiple providers
- Test with multiple IaC tools
- Test error recovery

**Multi-Project Testing:**
- Test with JS project
- Test with Python project
- Test with Go project
- Test with mixed language project

### End-to-End Testing

**Real Deployments:**
- Deploy to AWS test account
- Deploy to GCP test project
- Deploy with Terraform
- Deploy with Pulumi
- Verify resources created correctly

**Error Scenarios:**
- Trigger permission errors (verify fixing)
- Trigger config errors (verify fixing)
- Trigger state errors (verify handling)
- Trigger resource conflicts (verify resolution)

### Performance Testing

- Measure init time
- Measure plan time
- Measure apply time
- Measure plugin load time
- Optimize slow operations

### Security Testing

- Audit credential handling
- Verify secrets not logged
- Test permission boundaries
- Validate IAM changes are minimal

---

## Future Extensions

### Phase 6+: Advanced Features

**Multi-Region Support:**
- Deploy to multiple regions simultaneously
- Cross-region replication
- Region-specific configurations

**Blue-Green Deployments:**
- Traffic shifting strategies
- Rollback capabilities
- Health checks

**Monitoring Integration:**
- CloudWatch/Stackdriver integration
- Alert configuration
- Dashboard generation

**Secrets Management:**
- AWS Secrets Manager integration
- Vault integration
- Environment variable management

**Cost Optimization:**
- Cost estimation before deploy
- Budget alerts
- Resource tagging for cost allocation

### Additional Providers

**Planned:**
- Alibaba Cloud
- Oracle Cloud
- IBM Cloud
- Kubernetes (multi-cloud)

### Additional IaC Tools

**Planned:**
- Ansible
- Chef
- Puppet
- Crossplane

### CI/CD Integration

**Planned:**
- GitHub Actions workflows
- GitLab CI integration
- CircleCI integration
- Jenkins integration

---

## Appendices

### A. Configuration Schema Reference

Full JSON schema available at:
`skills/devops-common/templates/devops-config.schema.json`

### B. Provider Plugin API

Full API reference for implementing providers:
`docs/PROVIDER-PLUGIN-API.md`

### C. IaC Tool Plugin API

Full API reference for implementing IaC tools:
`docs/IAC-TOOL-PLUGIN-API.md`

### D. Error Categories

Complete list of error categories and handling:
`docs/ERROR-HANDLING.md`

### E. Glossary

- **Provider**: Cloud infrastructure provider (AWS, GCP, Azure, etc.)
- **IaC Tool**: Infrastructure-as-Code tool (Terraform, Pulumi, etc.)
- **Plugin**: Modular implementation for a specific provider or IaC tool
- **Orchestrator**: Generic workflow engine that delegates to plugins
- **Pattern**: Configuration value with placeholders (e.g., `{prefix}-{environment}`)
- **Namespace**: Project identifier prefix (e.g., `corthuxa-core`)

---

## Document History

| Version | Date       | Author   | Changes                        |
|---------|------------|----------|--------------------------------|
| 1.0     | 2025-10-18 | Fractary | Initial specification          |

---

## Approval and Sign-off

**Specification Status:** ✅ Approved for Implementation

**Next Steps:**
1. Create `fractary-faber-cloud-plugin` repository
2. Begin Phase 1 implementation
3. Weekly progress reviews
4. Update specification as needed based on implementation learnings

---

*End of Specification*
