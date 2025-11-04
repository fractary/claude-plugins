---
name: fractary-faber-cloud:deploy-destroy
description: Destroy deployed infrastructure (terraform destroy)
examples:
<<<<<<< HEAD:plugins/faber-cloud/commands/deploy-destroy.md
  - /fractary-faber-cloud:deploy-destroy --env=test
  - /fractary-faber-cloud:deploy-destroy --env=staging
argument-hint: "--env=<environment> [--confirm]"
=======
  - /fractary-faber-cloud:teardown --env test
  - /fractary-faber-cloud:teardown --env staging
argument-hint: "--env <environment> [--confirm]"
>>>>>>> origin/main:plugins/faber-cloud/commands/teardown.md
---

# Deploy-Destroy Command


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
<<<<<<< HEAD:plugins/faber-cloud/commands/deploy-destroy.md
/fractary-faber-cloud:deploy-destroy --env=<environment> [options]
=======
/fractary-faber-cloud:teardown --env <environment> [options]
>>>>>>> origin/main:plugins/faber-cloud/commands/teardown.md
```

## Arguments

- `--env <environment>` (required): Environment to destroy (test, staging, prod)
- `--confirm` (optional): Skip confirmation prompts (dangerous! Not allowed for production)

## Examples

```bash
# Destroy test environment (with confirmation)
<<<<<<< HEAD:plugins/faber-cloud/commands/deploy-destroy.md
/fractary-faber-cloud:deploy-destroy --env=test

# Destroy with auto-confirmation (be careful!)
/fractary-faber-cloud:deploy-destroy --env=test --confirm
=======
/fractary-faber-cloud:teardown --env test

# Destroy with auto-confirmation (be careful!)
/fractary-faber-cloud:teardown --env test --confirm
>>>>>>> origin/main:plugins/faber-cloud/commands/teardown.md
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

Destruction automatically:
- ✅ Backs up Terraform state to `infrastructure/backups/`
- ✅ Documents destruction in `docs/infrastructure/deployments.md`
- ✅ Verifies all resources removed from AWS
- ✅ Cleans up workspace (optional)

## Error Handling

If destruction fails:
- Shows error output
- Identifies stuck resources (dependencies, protection)
- Suggests resolution steps
- Does NOT continue if critical resources remain

## Agent Invocation

This command invokes the infra-manager agent with operation="deploy-destroy".

USE AGENT: infra-manager with operation=deploy-destroy and environment from --env parameter
