---
name: fractary-faber-cloud:architect
description: Design cloud infrastructure architecture from requirements
model: claude-haiku-4-5
examples:
  - /fractary-faber-cloud:architect "S3 bucket for user uploads"
  - /fractary-faber-cloud:architect "VPC with public and private subnets"
  - /fractary-faber-cloud:architect "Lambda function with API Gateway"
argument-hint: '"<description of infrastructure to build>"'
---

# Architect Command

Design cloud infrastructure architecture from natural language requirements.

## Usage

```bash
/fractary-faber-cloud:architect "<description>"
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
/fractary-faber-cloud:architect "S3 bucket for user uploads with versioning"
```

**Design VPC:**
```
/fractary-faber-cloud:architect "VPC with public and private subnets"
```

**Design serverless API:**
```
/fractary-faber-cloud:architect "Lambda function with API Gateway and DynamoDB"
```

## Next Steps

After designing, you can:
- Generate code: `/fractary-faber-cloud:engineer`
- Validate: `/fractary-faber-cloud:validate`
- Deploy: `/fractary-faber-cloud:deploy-apply --env test`

## Invocation

This command invokes the `infra-manager` agent with the `architect` operation.

USE AGENT: infra-manager with operation=architect and description from user input
