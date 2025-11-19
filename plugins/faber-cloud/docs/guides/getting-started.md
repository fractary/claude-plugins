# Getting Started with Fractary DevOps Plugin

This guide will help you get started with the fractary-faber-cloud plugin in 15 minutes.

## Prerequisites

Before you begin, ensure you have:

- Claude Code installed and configured
- AWS CLI installed (`aws --version`)
- Terraform installed (`terraform --version`)
- jq installed (`jq --version`)
- AWS credentials configured (`~/.aws/credentials`)
- AWS profiles for test and production

## Step 1: Initialize Configuration

In your project directory, initialize the plugin:

```bash
/fractary-faber-cloud:init --provider aws --iac terraform
```

This creates `.fractary/plugins/faber-cloud/devops.json` with your project configuration.

**What it does:**
- Auto-discovers your project name
- Detects AWS profiles
- Finds Terraform directory
- Creates configuration file
- Sets up directory structure

## Step 2: Verify Setup

Check that everything is configured correctly:

```bash
# View configuration
cat .fractary/plugins/faber-cloud/devops.json

# Verify AWS credentials
aws sts get-caller-identity --profile your-test-profile
```

Your config should look like:
```json
{
  "version": "1.0",
  "project": {
    "name": "my-project",
    "subsystem": "core",
    "organization": "my-org"
  },
  "handlers": {
    "hosting": {
      "active": "aws",
      "aws": {
        "region": "us-east-1",
        "profiles": {
          "discover": "my-project-discover-deploy",
          "test": "my-project-test-deploy",
          "prod": "my-project-prod-deploy"
        }
      }
    },
    "iac": {
      "active": "terraform",
      "terraform": {
        "directory": "./infrastructure/terraform"
      }
    }
  }
}
```

## Step 3: Your First Deployment

### Option A: Natural Language (Recommended)

```bash
/fractary-faber-cloud:director "deploy my infrastructure to test"
```

### Option B: Direct Command

```bash
/fractary-faber-cloud:infra-manage deploy --env test
```

**What happens:**
1. Pre-deployment security scans
2. Cost estimation
3. Terraform plan preview
4. Request for your approval
5. Deployment execution
6. Post-deployment verification
7. Health checks
8. Documentation generated

## Step 4: View Deployed Resources

```bash
/fractary-faber-cloud:director "show me deployed resources"
```

Or:
```bash
/fractary-faber-cloud:infra-manage show-resources --env test
```

You'll see:
- List of all deployed resources
- AWS Console links
- Resource ARNs and IDs
- Deployment timestamp

## Step 5: Monitor Health

```bash
/fractary-faber-cloud:director "check health of my services"
```

Or:
```bash
/fractary-faber-cloud:ops-manage check-health --env test
```

**What it checks:**
- Resource status (running/stopped)
- CloudWatch metrics
- Error rates
- Performance indicators
- Overall health status

## Common First Tasks

### Design New Infrastructure

```bash
/fractary-faber-cloud:director "design an S3 bucket for user uploads"
```

This creates a design document you can review and modify.

### Generate Terraform Code

```bash
/fractary-faber-cloud:director "implement the S3 bucket design"
```

This generates `main.tf`, `variables.tf`, and `outputs.tf`.

### Validate Configuration

```bash
/fractary-faber-cloud:director "validate my terraform configuration"
```

This checks syntax and configuration correctness.

### Preview Changes Before Deploying

```bash
/fractary-faber-cloud:director "preview changes for test environment"
```

This shows you exactly what will change.

### Investigate Issues

```bash
/fractary-faber-cloud:director "investigate errors in my API service"
```

This analyzes logs and identifies root causes.

## Understanding the Workflow

### Infrastructure Lifecycle

```
Design → Engineer → Validate → Test → Preview → Deploy → Monitor
   ↓         ↓          ↓        ↓       ↓        ↓        ↓
architect  engineer  validator tester previewer deployer monitor
```

### Natural Language Routing

```
Your request → director → infra-manager or ops-manager → skills
```

The director determines your intent and routes to the appropriate manager.

## Configuration Patterns

### Pattern Substitution

Your config uses patterns like:
```json
{
  "resource_naming": {
    "pattern": "{project}-{subsystem}-{environment}-{resource}"
  }
}
```

This automatically creates names like: `my-project-core-test-database`

### Environment-Specific Settings

```json
{
  "environments": {
    "test": {
      "auto_approve": false,
      "cost_threshold": 100
    },
    "prod": {
      "auto_approve": false,
      "cost_threshold": 500,
      "require_confirmation": true
    }
  }
}
```

## Next Steps

Now that you're set up:

1. **Read the [User Guide](user-guide.md)** for advanced features
2. **Explore natural language commands** - try different phrasings
3. **Set up your Terraform code** in `infrastructure/terraform/`
4. **Deploy to test** and verify everything works
5. **Check the [Troubleshooting Guide](troubleshooting.md)** if you hit issues

## Quick Reference

**Natural Language Commands:**
```bash
# Infrastructure
/fractary-faber-cloud:director "design [feature]"
/fractary-faber-cloud:director "deploy to [environment]"
/fractary-faber-cloud:director "validate configuration"

# Operations
/fractary-faber-cloud:director "check health"
/fractary-faber-cloud:director "investigate errors"
/fractary-faber-cloud:director "analyze costs"
```

**Direct Commands:**
```bash
# Infrastructure
/fractary-faber-cloud:infra-manage architect --feature="..."
/fractary-faber-cloud:infra-manage deploy --env test

# Operations
/fractary-faber-cloud:ops-manage check-health --env test
/fractary-faber-cloud:ops-manage investigate --service=...
```

## Getting Help

- **Documentation:** [User Guide](user-guide.md), [Architecture](../architecture/ARCHITECTURE.md)
- **Troubleshooting:** [Troubleshooting Guide](troubleshooting.md)
- **Examples:** [README.md](../../README.md#complete-workflow-example)
- **Issues:** GitHub Issues

## Tips for Success

1. **Start with test environment** - Always deploy to test first
2. **Use natural language** - It's easier and more intuitive
3. **Review previews** - Always check the preview before deploying
4. **Let errors auto-fix** - Permission errors can be fixed automatically
5. **Monitor regularly** - Use health checks to catch issues early
6. **Read error messages** - They contain specific guidance
7. **Check documentation** - Generated docs are always up-to-date

Congratulations! You're ready to use fractary-faber-cloud for your infrastructure automation.
