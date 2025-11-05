---
name: fractary-faber-cloud:design
description: Design cloud infrastructure from requirements
examples:
  - /fractary-faber-cloud:design "S3 bucket for user uploads"
  - /fractary-faber-cloud:design "VPC with public and private subnets"
  - /fractary-faber-cloud:design "Lambda function with API Gateway"
argument-hint: "<description>"
---

# Design Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Boolean flags**: No value needed, just include the flag

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:design --env test

# Incorrect ❌
/fractary-faber-cloud:design --env=test
```
</ARGUMENT_SYNTAX>

Design cloud infrastructure from natural language requirements.

## Usage

```bash
/fractary-faber-cloud:design "<description>"
```

## Parameters

- `description`: Natural language description of what infrastructure you need

## What This Does

1. Analyzes infrastructure requirements
2. Designs appropriate AWS resources
3. Considers best practices (security, cost, scalability)
4. Creates design document
5. Prepares for IaC code generation

## Examples

**Design S3 bucket:**
```
/fractary-faber-cloud:design "S3 bucket for user uploads with versioning"
```

**Design VPC:**
```
/fractary-faber-cloud:design "VPC with public and private subnets"
```

**Design serverless API:**
```
/fractary-faber-cloud:design "Lambda function with API Gateway and DynamoDB"
```

## Next Steps

After designing, you can:
- Generate code: `/fractary-faber-cloud:configure`
- Validate: `/fractary-faber-cloud:validate`
- Deploy: `/fractary-faber-cloud:deploy-apply --env test`

## Invocation

This command invokes the `infra-manager` agent with the `design` operation.

USE AGENT: infra-manager with operation=design and description from user input
