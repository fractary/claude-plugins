---
name: DevOps Common
description: Shared utilities for DevOps automation - configuration loading, pattern resolution, auto-discovery
allowed-tools: Bash, Read
---

# DevOps Common

Shared utilities used across all DevOps skills.

## Purpose

This skill provides:
- Configuration loading from `.fractary/plugins/faber-cloud/config/faber-cloud.json`
- Pattern substitution (`{project}`, `{environment}`, etc.)
- Auto-discovery fallbacks when config is missing
- Validation and error handling

## Components

### scripts/config-loader.sh

Core configuration management:

**Main Functions:**
- `load_devops_config()` - Load configuration from file or auto-discover
- `resolve_pattern(pattern, environment)` - Substitute placeholders in patterns
- `get_aws_profile(environment)` - Get AWS profile for environment
- `get_config_value(key)` - Get specific config value
- `show_config()` - Display current configuration

**Usage:**
```bash
# Source the loader
source "${SKILL_DIR}/../devops-common/scripts/config-loader.sh"

# Load configuration
load_devops_config

# Use configuration variables
echo "Project: $PROJECT_NAME"
echo "Provider: $PROVIDER"
echo "IaC Tool: $IAC_TOOL"

# Resolve patterns
USER_NAME=$(resolve_pattern "$USER_NAME_PATTERN" "test")
# Result: corthuxa-core-test-deploy

# Get AWS profile
AWS_PROFILE=$(get_aws_profile "test")
# Result: corthuxa-core-test-deploy
```

**Exported Variables:**
- `PROJECT_NAME` - Project name
- `NAMESPACE` - Project namespace
- `ORGANIZATION` - Organization name
- `PROVIDER` - Cloud provider (aws, gcp, azure)
- `IAC_TOOL` - IaC tool (terraform, pulumi, cdk)
- `AWS_REGION` - AWS region
- `TERRAFORM_DIR` - Terraform directory path
- `IAM_POLICIES_DIR` - IAM policies directory path
- `PROFILE_DISCOVER`, `PROFILE_TEST`, `PROFILE_PROD` - AWS profiles
- `USER_NAME_PATTERN`, `POLICY_NAME_PATTERN` - IAM naming patterns
- `RESOURCE_PREFIX` - Resource naming prefix

### templates/devops-config.json.template

Template for generating `.fractary/plugins/faber-cloud/config/faber-cloud.json`:
- Placeholders: `{{PROJECT_NAME}}`, `{{NAMESPACE}}`, etc.
- Used by `/faber-cloud:init` command
- Includes sensible defaults

## Auto-Discovery

When configuration file doesn't exist, auto-discovers:
- Project name from Git repository
- Organization from Git remote
- AWS account ID from credentials
- Provider and IaC tool from installed tools

## Pattern Substitution

Supported placeholders:
- `{project}` - Project name
- `{namespace}` - Project namespace
- `{organization}` - Organization name
- `{environment}` - Current environment (test, prod, etc.)
- `{prefix}` - Resource prefix

Example:
```
Pattern: "{prefix}-{environment}-bucket"
Result: "corthuxa-test-bucket"
```

## Configuration Schema

See `/docs/specs/fractary-faber-cloud-plugin-spec.md` for complete schema.

## Used By

**Infrastructure Skills:**
- infra-architect
- infra-engineer
- infra-validator
- infra-previewer
- infra-deployer
- infra-permission-manager
- infra-tester
- infra-debugger

**Operations Skills:**
- ops-monitor
- ops-investigator
- ops-responder
- ops-auditor

**Handler Skills:**
- handler-hosting-aws
- handler-iac-terraform

**Note:** Previously used by deprecated agents (devops-deployer, devops-debugger, devops-permissions) - now superseded by Phase 1-4 architecture. See `.archive/pre-phase-architecture/` for historical reference.
