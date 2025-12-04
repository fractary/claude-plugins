---
name: fractary-faber-cloud:list
description: List deployed infrastructure resources
model: claude-haiku-4-5
examples:
  - /fractary-faber-cloud:list --env test
  - /fractary-faber-cloud:list --env prod
argument-hint: "--env <environment>"
---

# List Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Boolean flags**: No value needed, just include the flag

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:list --env test

# Incorrect ❌
/fractary-faber-cloud:list --env=test
```
</ARGUMENT_SYNTAX>

List detailed information about deployed infrastructure resources.

## Usage

```bash
/fractary-faber-cloud:list --env <environment>
```

## Parameters

- `--env`: Environment to query (test, prod). Required.

## What This Does

1. Reads deployment registry
2. Queries Terraform state
3. Retrieves AWS resource details
4. Displays comprehensive resource information
5. Shows relationships between resources

## Examples

**List test resources:**
```
/fractary-faber-cloud:list --env test
```

**List production resources:**
```
/fractary-faber-cloud:list --env prod
```

## Output Includes

**By Resource Type:**
- Lambda functions (name, runtime, memory, timeout)
- S3 buckets (name, versioning, encryption)
- RDS databases (endpoint, engine, size)
- VPC components (CIDR, subnets, routing)
- IAM resources (roles, policies)
- CloudWatch alarms and logs

**Details Shown:**
- Resource name and ARN
- Resource type and configuration
- Creation timestamp
- Tags and metadata
- Dependencies
- Estimated cost contribution

## Output Formats

**Table view (default):**
```
╔════════════════╦══════════════════════╦═══════════════╗
║ Type           ║ Name                 ║ Status        ║
╠════════════════╬══════════════════════╬═══════════════╣
║ Lambda         ║ api-handler          ║ Active        ║
║ S3             ║ uploads-bucket       ║ Active        ║
║ RDS            ║ main-db              ║ Available     ║
╚════════════════╩══════════════════════╩═══════════════╝
```

**Detailed view:**
- Full resource configuration
- Dependencies graph
- Cost breakdown
- Access patterns

## When to Use

List resources:
- After deployment
- Before making changes
- For documentation
- When troubleshooting
- For cost analysis

## Next Steps

After viewing resources:
- Monitor health: `/fractary-helm-cloud:health --env test`
- Check costs: `/fractary-helm-cloud:audit --type=cost --env test`
- Make changes: `/fractary-faber-cloud:architect "modify..."`

## Invocation

This command invokes the `infra-manager` agent with the `list-resources` operation.

USE AGENT: infra-manager with operation=list-resources and environment from --env parameter
