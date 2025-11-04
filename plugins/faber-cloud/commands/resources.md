---
name: /fractary-faber-cloud:resources
description: Show deployed infrastructure resources
examples:
  - /fractary-faber-cloud:resources --env test
  - /fractary-faber-cloud:resources --env prod
argument-hint: "--env <environment>"
---

# Resources Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Boolean flags**: No value needed, just include the flag

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:resources --env test

# Incorrect ❌
/fractary-faber-cloud:resources --env=test
```
</ARGUMENT_SYNTAX>

Show detailed information about deployed infrastructure resources.

## Usage

```bash
/fractary-faber-cloud:resources --env <environment>
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
/fractary-faber-cloud:resources --env test
```

**List production resources:**
```
/fractary-faber-cloud:resources --env prod
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

This command invokes the `infra-manager` agent with the `show-resources` operation.

USE AGENT: infra-manager with operation=show-resources and environment from --env parameter
