---
name: /fractary-faber-cloud:configure
description: Generate Infrastructure as Code from design
examples:
  - /fractary-faber-cloud:configure
  - /fractary-faber-cloud:configure --validate
argument-hint: "[--validate]"
---

# Configure Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Boolean flags**: No value needed, just include the flag

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:configure --env test

# Incorrect ❌
/fractary-faber-cloud:configure --env=test
```
</ARGUMENT_SYNTAX>

Generate Infrastructure as Code (Terraform) from a design document.

## Usage

```bash
/fractary-faber-cloud:configure [--validate]
```

## Parameters

- `--validate`: Automatically validate after generating code (optional)

## What This Does

1. Reads design document
2. Generates Terraform configuration
3. Creates resource definitions
4. Configures providers and backends
5. Applies naming conventions
6. Saves IaC code to terraform directory

## Examples

**Generate code from latest design:**
```
/fractary-faber-cloud:configure
```

**Generate and validate:**
```
/fractary-faber-cloud:configure --validate
```

## Next Steps

After generating code, you should:
- Validate: `/fractary-faber-cloud:validate`
- Test: `/fractary-faber-cloud:test`
- Preview: `/fractary-faber-cloud:deploy-plan`
- Deploy: `/fractary-faber-cloud:deploy-apply --env test`

## Invocation

This command invokes the `infra-manager` agent with the `configure` operation.

USE AGENT: infra-manager with operation=configure
