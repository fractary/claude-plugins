---
name: engineer
description: Generate Infrastructure as Code from design
examples:
  - /fractary-faber-cloud:engineer user-uploads
  - /fractary-faber-cloud:engineer vpc-design
  - /fractary-faber-cloud:engineer api-lambda
argument-hint: "<design-name>"
---

# Engineer Command

Generate Infrastructure as Code (Terraform) from a design document.

## Usage

```bash
/fractary-faber-cloud:engineer <design-name>
```

## Parameters

- `design-name`: Name of the design to implement (from architect phase)

## What This Does

1. Reads design document
2. Generates Terraform configuration
3. Creates resource definitions
4. Configures providers and backends
5. Applies naming conventions
6. Saves IaC code to terraform directory

## Examples

**Generate code for S3 design:**
```
/fractary-faber-cloud:engineer user-uploads
```

**Generate code for VPC design:**
```
/fractary-faber-cloud:engineer vpc-infrastructure
```

**Generate code for Lambda design:**
```
/fractary-faber-cloud:engineer api-function
```

## Next Steps

After generating code, you should:
- Validate: `/fractary-faber-cloud:validate`
- Test: `/fractary-faber-cloud:test --env=test`
- Preview: `/fractary-faber-cloud:preview --env=test`
- Deploy: `/fractary-faber-cloud:deploy --env=test`

## Invocation

This command invokes the `infra-manager` agent with the `engineer` operation.

USE AGENT: infra-manager with operation=engineer and design name from user input
