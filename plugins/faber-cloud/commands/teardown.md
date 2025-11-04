---
name: /fractary-faber-cloud:teardown
description: Destroy infrastructure (terraform destroy)
examples:
  - /fractary-faber-cloud:teardown --env test
  - /fractary-faber-cloud:teardown --env staging
argument-hint: "--env <environment> [--confirm]"
---

# Teardown Infrastructure


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Boolean flags**: No value needed, just include the flag

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:teardown --env test

# Incorrect ❌
/fractary-faber-cloud:teardown --env=test
```
</ARGUMENT_SYNTAX>

Destroy deployed infrastructure in the specified environment.

## Usage

```bash
/fractary-faber-cloud:teardown --env <environment> [options]
```

## Arguments

- `--env <environment>` (required): Environment to destroy (test, staging, prod)
- `--confirm` (optional): Skip confirmation prompts (dangerous! Not allowed for production)

## Examples

```bash
# Destroy test environment (with confirmation)
/fractary-faber-cloud:teardown --env test

# Destroy with auto-confirmation (be careful!)
/fractary-faber-cloud:teardown --env test --confirm
```

## Safety

**Production Safety**: Destroying production infrastructure requires multiple confirmations and cannot use `--confirm` flag.

**State Backup**: Terraform state is automatically backed up before destruction.

**Verification**: After destruction, verifies all resources are removed.

## Workflow

1. Validate environment exists
2. Backup Terraform state
3. Request confirmation (multiple for production)
4. Execute terraform destroy
5. Verify resource removal
6. Document destruction in deployment history

## Production Teardown

For production environments:
- ⚠️ Requires 3 separate confirmations
- ⚠️ User must type environment name to confirm
- ⚠️ `--confirm` flag is rejected
- ⚠️ Extended timeout (30 minutes)
- ⚠️ Additional approval checkpoint after plan review

## Non-Production Teardown

For test/staging environments:
- 1 confirmation required (unless `--confirm` flag used)
- Standard timeout (10 minutes)
- Automatic if `--confirm` flag present

## After Teardown

Teardown automatically:
- ✅ Backs up Terraform state to `infrastructure/backups/`
- ✅ Documents teardown in `docs/infrastructure/deployments.md`
- ✅ Verifies all resources removed from AWS
- ✅ Cleans up workspace (optional)

## Error Handling

If destruction fails:
- Shows error output
- Identifies stuck resources (dependencies, protection)
- Suggests resolution steps
- Does NOT continue if critical resources remain

## Agent Invocation

This command invokes the infra-manager agent with operation="teardown".

USE AGENT: infra-manager with operation=teardown and environment from --env parameter
