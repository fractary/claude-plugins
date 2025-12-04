---
name: fractary-faber-cloud:engineer
description: Generate Infrastructure as Code from architecture design, specification, or direct instructions
model: claude-haiku-4-5
examples:
  - /fractary-faber-cloud:engineer "user-uploads.md"
  - /fractary-faber-cloud:engineer "Implement design from .fractary/plugins/faber-cloud/designs/api-backend.md"
  - /fractary-faber-cloud:engineer ".faber/specs/123-add-uploads.md"
  - /fractary-faber-cloud:engineer "Fix IAM permissions - Lambda needs s3:PutObject on uploads bucket"
argument-hint: "[instructions]"
---

# Engineer Command

Generate Infrastructure as Code (Terraform) from architecture designs, specifications, or direct instructions.

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command accepts free-text instructions that can include:
- **Design file reference**: "user-uploads.md" or path to design document
- **Spec file reference**: ".faber/specs/123-feature.md" or path to FABER spec
- **Direct instructions**: "Fix IAM permissions issue from debugger"
- **Mixed context**: "Implement design from api-backend.md and fix the timeout issue"

The engineer skill will intelligently parse the input and determine what to do.

### Examples

```bash
# Reference a design document
/fractary-faber-cloud:engineer "user-uploads.md"

# Reference a FABER spec
/fractary-faber-cloud:engineer ".faber/specs/123-add-uploads.md"

# Direct instructions (e.g., from debugger)
/fractary-faber-cloud:engineer "Fix the Lambda IAM permissions - needs s3:PutObject"

# Mixed context
/fractary-faber-cloud:engineer "Implement api-backend.md and add CloudWatch alarms"
```
</ARGUMENT_SYNTAX>

## Usage

```bash
/fractary-faber-cloud:engineer [instructions]
```

## Parameters

- `instructions`: Free-text instructions, file references, or context (optional - will look for latest design if omitted)

## What This Does

1. Parses instructions to determine input source
2. Reads design documents or specs if referenced
3. Generates Terraform configuration
4. Creates resource definitions
5. Configures providers and backends
6. Applies naming conventions and best practices
7. **Always validates** generated code (terraform fmt + validate)
8. Saves IaC code to terraform directory

## Examples

**Generate from latest design:**
```
/fractary-faber-cloud:engineer
```

**Generate from specific design:**
```
/fractary-faber-cloud:engineer "user-uploads.md"
```

**Generate from FABER spec:**
```
/fractary-faber-cloud:engineer ".faber/specs/123-add-uploads.md"
```

**Fix specific issue:**
```
/fractary-faber-cloud:engineer "Fix IAM permissions from debugger - Lambda needs DynamoDB access"
```

## Next Steps

After generating code, you should:
- Test: `/fractary-faber-cloud:test`
- Preview: `/fractary-faber-cloud:deploy-plan`
- Deploy: `/fractary-faber-cloud:deploy-apply --env test`

## Invocation

This command invokes the `infra-manager` agent with the `engineer` operation.

USE AGENT: infra-manager with operation=engineer and instructions
