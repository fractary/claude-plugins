# Fractary DevOps Plugin

Generic DevOps automation plugin for Claude Code, supporting multiple cloud providers and Infrastructure as Code (IaC) tools.

## Overview

This plugin provides configuration-driven DevOps automation that works across projects. Instead of hardcoding AWS profiles, Terraform paths, and resource names for each project, you configure once in `.fractary/.config/devops.json` and the plugin handles the rest.

**Key Features:**
- Multi-cloud provider support (AWS, GCP, Azure)
- Multi-IaC tool support (Terraform, Pulumi, CDK, CloudFormation)
- Configuration-driven with pattern substitution
- Auto-discovery fallbacks when config missing
- IAM permission audit system
- Error categorization and auto-fix
- Deployment orchestration with safety checks

## Quick Start

### 1. Install Plugin

```bash
# Clone to your Claude Code plugins directory
cd ~/.claude-code/plugins/
git clone https://github.com/fractary/claude-devops-plugin.git fractary-devops
```

### 2. Initialize Configuration

```bash
# In your project directory
/devops:init
```

This creates `.fractary/.config/devops.json` with auto-discovered settings.

### 3. Deploy Infrastructure

```bash
# Deploy to test environment
/devops:deploy test

# Deploy to production (with safety checks)
/devops:deploy prod
```

## Configuration

Configuration file: `.fractary/.config/devops.json`

### Example Configuration

```json
{
  "provider": "aws",
  "iac_tool": "terraform",
  "project": {
    "name": "corthography",
    "namespace": "corthuxa-core",
    "organization": "corthos"
  },
  "aws": {
    "account_id": "123456789012",
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
    "directory": "./infrastructure/terraform",
    "var_file_pattern": "{environment}.tfvars",
    "backend": {
      "type": "s3",
      "bucket": "{namespace}-terraform-state",
      "key": "{project}/terraform.tfstate"
    }
  }
}
```

### Pattern Substitution

Patterns use placeholders that get substituted with actual values:

- `{project}` - Project name (e.g., "corthography")
- `{namespace}` - Project namespace (e.g., "corthuxa-core")
- `{organization}` - Organization (e.g., "corthos")
- `{environment}` - Current environment (e.g., "test", "prod")
- `{prefix}` - Resource prefix (e.g., "corthuxa")

Example:
```json
"user_name_pattern": "{namespace}-{environment}-deploy"
```
Resolves to: `corthuxa-core-test-deploy`

## Commands

### /devops:init

Initialize DevOps configuration for your project.

```bash
/devops:init
```

Auto-discovers:
- Project name from Git repository
- AWS profiles and credentials
- Terraform directory location
- Cloud provider and IaC tool

### /devops:deploy

Deploy infrastructure to specified environment.

```bash
/devops:deploy [environment] [options]

# Examples:
/devops:deploy test                # Deploy to test
/devops:deploy prod                # Deploy to production
/devops:deploy test --auto-approve # Skip approval prompt
/devops:deploy test --plan-only    # Generate plan without applying
```

**Options:**
- `--auto-approve` - Skip interactive approval
- `--plan-only` - Generate plan without applying
- `--var-file=PATH` - Custom variable file
- `--complete` - Auto-fix permission errors

### /devops:debug

Debug deployment errors and suggest fixes.

```bash
/devops:debug                  # Analyze last deployment failure
/devops:debug --complete       # Auto-fix permission errors
/devops:debug --report-only    # Just show analysis
```

Categorizes errors into:
- Permission errors (auto-fixable)
- Configuration errors (manual fix)
- Resource errors (needs resolution)
- State errors (backend issues)

### /devops:permissions

Manage IAM permissions for deploy users.

```bash
/devops:permissions <action> [args]

# Examples:
/devops:permissions add ecr:DescribeRepositories test "Required for ECR state"
/devops:permissions verify s3:PutBucketPolicy test
/devops:permissions list test
/devops:permissions audit test
```

**Actions:**
- `add <permission> <environment> [reason]` - Add permission
- `verify <permission> <environment>` - Check if exists
- `list <environment>` - List all permissions
- `audit <environment>` - Show change history

### /devops:validate

Validate DevOps configuration and setup.

```bash
/devops:validate [component]

# Examples:
/devops:validate           # Validate everything
/devops:validate config    # Config file only
/devops:validate provider  # Provider credentials only
/devops:validate iac       # IaC tool only
```

### /devops:status

Show current DevOps configuration and deployment status.

```bash
/devops:status [environment] [options]

# Examples:
/devops:status                    # Show all environments
/devops:status test               # Test environment only
/devops:status --verbose          # Detailed information
/devops:status --resources        # Include resource list
/devops:status --config           # Show full configuration
```

## Agents

### devops-deployer

Orchestrates infrastructure deployments.

**Features:**
- Configuration-driven provider/tool selection
- Authenticate with cloud provider
- Execute IaC workflow (init → validate → plan → apply)
- Error handling and delegation
- Production safety checks

**Invoked by:**
- `/devops:deploy` command
- Direct skill invocation

### devops-debugger

Analyzes deployment errors and determines fix strategies.

**Features:**
- Parse IaC tool error output
- Categorize errors (permission, configuration, resource, state)
- Determine fix strategies
- Delegate to specialized skills
- Multi-error handling

**Invoked by:**
- `/devops:debug` command
- `devops-deployer` on deployment failure
- Direct skill invocation

### devops-permissions

Manages IAM permissions for deployment users.

**Features:**
- Add permissions to deploy user IAM policies
- Track changes in audit system
- Verify permissions exist
- List current permissions
- Show permission change history

**Invoked by:**
- `/devops:permissions` command
- `devops-debugger` when permission errors detected
- `devops-deployer` for proactive permission checks

## Architecture

```
fractary-devops-plugin/
├── plugin.json                      # Plugin metadata
├── README.md                        # This file
├── commands/                        # Slash commands
│   ├── devops-init.md
│   ├── devops-deploy.md
│   ├── devops-debug.md
│   ├── devops-permissions.md
│   ├── devops-validate.md
│   └── devops-status.md
├── agents/                          # Agent definitions
│   ├── devops-deployer.md
│   ├── devops-debugger.md
│   └── devops-permissions.md
├── skills/                          # Skills and plugins
│   ├── devops-common/              # Shared utilities
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   └── config-loader.sh   # Config loading & patterns
│   │   └── templates/
│   │       └── devops-config.json.template
│   └── devops-deployer/            # Deployment orchestration
│       ├── providers/              # Cloud provider plugins
│       │   ├── aws/
│       │   │   ├── auth.sh
│       │   │   ├── permissions.sh
│       │   │   ├── resource-naming.sh
│       │   │   └── README.md
│       │   ├── gcp/                # Future
│       │   └── azure/              # Future
│       └── iac-tools/              # IaC tool plugins
│           ├── terraform/
│           │   ├── init.sh
│           │   ├── validate.sh
│           │   ├── plan.sh
│           │   ├── apply.sh
│           │   ├── error-parser.sh
│           │   └── README.md
│           ├── pulumi/             # Future
│           └── cdk/                # Future
└── docs/                           # Documentation
    └── specs/
        └── fractary-devops-plugin-spec.md
```

## Provider Plugins

### AWS (Implemented)

**Features:**
- AWS profile-based authentication
- IAM permission management via audit system
- AWS resource naming conventions
- Multi-environment support (discover, test, prod)

**Configuration:**
```json
{
  "provider": "aws",
  "aws": {
    "account_id": "123456789012",
    "region": "us-east-1",
    "profiles": {
      "discover": "myproject-discover-deploy",
      "test": "myproject-test-deploy",
      "prod": "myproject-prod-deploy"
    }
  }
}
```

### GCP (Planned)

Service account or user authentication, IAM binding management, GCP naming conventions.

### Azure (Planned)

Azure CLI authentication, RBAC management, Azure naming conventions.

## IaC Tool Plugins

### Terraform (Implemented)

**Workflow:** init → validate → plan → apply

**Features:**
- Terraform initialization and validation
- Plan generation and display
- Apply with approval gates
- Error parsing and categorization
- State management

**Configuration:**
```json
{
  "iac_tool": "terraform",
  "terraform": {
    "directory": "./infrastructure/terraform",
    "var_file_pattern": "{environment}.tfvars",
    "backend": {
      "type": "s3",
      "bucket": "{namespace}-terraform-state"
    }
  }
}
```

### Pulumi (Planned)

Stack-based deployment with preview and up commands.

### CDK (Planned)

AWS CDK synth, diff, and deploy workflow.

### CloudFormation (Planned)

Change set creation and execution.

## IAM Permission Audit System

All IAM permission changes are tracked in audit files.

**Location:** `/infrastructure/iam-policies/{environment}-deploy-permissions.json`

**Audit Entry:**
```json
{
  "timestamp": "2025-10-17T14:07:22Z",
  "action": "added",
  "permissions": ["ecr:DescribeRepositories"],
  "reason": "Required for Terraform to read ECR repository state",
  "terraform_error": "User is not authorized to perform: ecr:DescribeRepositories",
  "added_by": "devops-permissions-skill"
}
```

**Benefits:**
- Complete history of permission changes
- Drift detection
- Reproduction from audit files
- Context for each permission (why, when, who)

## Safety Features

### Environment Protection

**Test Environment:**
- Lower risk, faster iteration
- Auto-approve allowed
- Permissive error handling

**Production Environment:**
- High risk, requires caution
- Always prompts for approval (ignores `--auto-approve`)
- Requires explicit "yes" confirmation
- Shows detailed plan review

### IAM Security

**AWS Profile Strategy:**
- `{namespace}-discover-deploy` - IAM management only (temporary use)
- `{namespace}-test-deploy` - Test deployments (NO IAM permissions)
- `{namespace}-prod-deploy` - Production deployments (NO IAM permissions)

**Principle of Least Privilege:**
- Add only specific permissions needed
- Document reason for each permission
- Track all changes in audit system
- Regular permission reviews

### Delegation Pattern

Errors are delegated to appropriate specialists:
- Permission errors → `devops-permissions` skill (auto-fixable)
- Complex errors → `devops-debugger` skill (analysis and categorization)
- Configuration errors → User (manual fix required)

## Auto-Discovery

When configuration file doesn't exist, the plugin auto-discovers:

**Project Information:**
- Project name from Git repository
- Organization from Git remote
- Namespace from repository structure

**Infrastructure:**
- Cloud provider from installed tools and credentials
- IaC tool from directory structure
- Terraform directory location
- Environment variable files

**AWS:**
- Account ID from credentials
- Configured profiles
- Default region

## Workflow Example

Typical deployment workflow:

```bash
# 1. Initialize configuration (first time only)
/devops:init
# Auto-discovers project, AWS profiles, Terraform directory
# Creates .fractary/.config/devops.json

# 2. Validate setup
/devops:validate
# Checks config, AWS credentials, Terraform setup

# 3. Deploy to test
/devops:deploy test
# Authenticates with AWS
# Runs: terraform init → validate → plan
# Shows plan, prompts for approval
# Applies changes

# If deployment fails with permission error:
# → devops-debugger analyzes errors
# → Detects permission error (e.g., ecr:DescribeRepositories)
# → Delegates to devops-permissions
# → Permission added via audit system
# → Deployment retries

# 4. Check status
/devops:status test
# Shows resources deployed, last deployment time

# 5. Deploy to production
/devops:deploy prod
# Extra safety checks
# Requires explicit "yes" confirmation
```

## Error Handling

### Permission Errors

**Automatic Fix:**
1. Error detected during deployment
2. `devops-debugger` extracts permission (e.g., `s3:PutBucketPolicy`)
3. Delegates to `devops-permissions`
4. Permission added via audit system
5. Deployment retries

### Configuration Errors

**Manual Fix Required:**
1. Error detected and categorized
2. File location and issue identified
3. Fix suggestions provided
4. User manually corrects Terraform files
5. Re-run deployment

### Resource Errors

**Resolution Required:**
1. Conflict detected (e.g., resource already exists)
2. Options presented:
   - Import existing resource
   - Remove existing resource
   - Rename in Terraform
3. User resolves manually
4. Re-run deployment

## Supported Versions

**Current (v0.1.0):**
- AWS provider
- Terraform IaC tool
- Configuration system
- Audit system
- All commands and agents

**Planned:**
- v0.2.0: GCP provider, Pulumi IaC tool
- v0.3.0: Azure provider
- v0.4.0: CDK, CloudFormation support

## Requirements

- Claude Code >= 1.0.0
- One of:
  - AWS CLI (for AWS provider)
  - gcloud (for GCP provider)
  - az (for Azure provider)
- One of:
  - Terraform (for Terraform IaC tool)
  - Pulumi (for Pulumi IaC tool)
  - AWS CDK (for CDK IaC tool)
- jq (for JSON processing)

## Installation

### Option 1: Clone Repository

```bash
cd ~/.claude-code/plugins/
git clone https://github.com/fractary/claude-devops-plugin.git fractary-devops
```

### Option 2: Manual Installation

1. Download latest release
2. Extract to `~/.claude-code/plugins/fractary-devops/`
3. Restart Claude Code or reload plugins

## Usage

See [Commands](#commands) section for detailed usage of each command.

Quick reference:
```bash
/devops:init              # Setup configuration
/devops:validate          # Validate setup
/devops:deploy test       # Deploy to test
/devops:status test       # Check status
/devops:permissions list  # List permissions
```

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License - see [LICENSE](LICENSE)

## Support

- Documentation: [docs/](docs/)
- Issues: https://github.com/fractary/claude-devops-plugin/issues
- Spec: [docs/specs/fractary-devops-plugin-spec.md](docs/specs/fractary-devops-plugin-spec.md)

## Credits

Created by Fractary for Claude Code.
