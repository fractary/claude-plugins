---
name: validate
description: Validate Terraform configuration syntax and structure
examples:
  - /fractary-faber-cloud:validate
  - /fractary-faber-cloud:validate --env=test
argument-hint: "[--env=<environment>]"
---

# Validate Command

Validate Terraform configuration syntax and structure.

## Usage

```bash
/fractary-faber-cloud:validate [--env=<environment>]
```

## Parameters

- `--env`: Environment to validate (test, prod). Defaults to test.

## What This Does

1. Runs `terraform validate` on configuration
2. Checks syntax errors
3. Validates resource references
4. Checks provider configuration
5. Reports any issues found

## Examples

**Validate test configuration:**
```
/fractary-faber-cloud:validate --env=test
```

**Validate production configuration:**
```
/fractary-faber-cloud:validate --env=prod
```

**Validate with default environment:**
```
/fractary-faber-cloud:validate
```

## When to Use

Run validation:
- After generating IaC code (engineer phase)
- Before running tests
- Before deploying
- After making manual changes to Terraform files

## Next Steps

After validation passes:
- Test security: `/fractary-faber-cloud:test --env=test`
- Preview changes: `/fractary-faber-cloud:preview --env=test`
- Deploy: `/fractary-faber-cloud:deploy --env=test`

## Invocation

This command invokes the `infra-manager` agent with the `validate-config` operation.

USE AGENT: infra-manager with operation=validate-config and environment from --env parameter (defaults to test)
