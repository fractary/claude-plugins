---
name: fractary-faber-cloud:debug
description: Debug deployment errors and permission issues
model: claude-haiku-4-5
examples:
  - /fractary-faber-cloud:debug "AccessDenied error during deployment"
  - /fractary-faber-cloud:debug "terraform apply failed"
  - /fractary-faber-cloud:debug
argument-hint: '"<description of issue to debug>"'
---

# Debug Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Boolean flags**: No value needed, just include the flag

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:debug "AccessDenied error"
/fractary-faber-cloud:debug "deployment failed with state lock error"

# No arguments for interactive mode ✅
/fractary-faber-cloud:debug
```
</ARGUMENT_SYNTAX>

Debug deployment errors and permission issues.

## Usage

```bash
/fractary-faber-cloud:debug ["<description of issue>"]
```

## Parameters

- `description`: Natural language description of the issue (optional - if omitted, enters interactive mode)

## What This Does

1. Analyzes error messages
2. Categorizes error type
3. Identifies root cause
4. Provides specific remediation steps
5. Can automatically fix some issues

## Examples

**Debug permission error:**
```
/fractary-faber-cloud:debug "AccessDenied: User is not authorized"
```

**Debug deployment failure:**
```
/fractary-faber-cloud:debug "terraform apply failed during deployment"
```

**Interactive debugging:**
```
/fractary-faber-cloud:debug
# Will ask questions to diagnose issue
```

## Common Error Categories

### Permission Errors
**Symptoms:**
- AccessDenied
- UnauthorizedOperation
- InvalidPermissions

**Remediation:**
- Analyzes required permissions
- Generates IAM policy
- Can create permission requests
- Suggests AWS profile fixes

### Configuration Errors
**Symptoms:**
- InvalidConfiguration
- ValidationError
- Missing required parameter

**Remediation:**
- Identifies invalid values
- Suggests corrections
- Can auto-fix some issues
- Updates configuration

### Resource Errors
**Symptoms:**
- ResourceNotFound
- ResourceAlreadyExists
- DependencyViolation

**Remediation:**
- Checks resource state
- Identifies conflicts
- Suggests cleanup steps
- Can resolve dependencies

### State Errors
**Symptoms:**
- StateLockedError
- StateMismatch
- BackendError

**Remediation:**
- Checks state file
- Can unlock state
- Reconciles differences
- Repairs backend connection

## Auto-Fix Capabilities

Some issues can be automatically fixed:
- ✅ IAM permission policies (can generate)
- ✅ State lock issues (can unlock)
- ✅ Configuration typos (can correct)
- ⚠️ Resource conflicts (suggests manual steps)
- ⚠️ Account limits (requires AWS support)

## Debug Workflow

```
1. Error occurs during operation
   ↓
2. Run debug command with error details
   ↓
3. Debugger categorizes and analyzes
   ↓
4. Provides remediation steps
   ↓
5. Apply fix (automatic or manual)
   ↓
6. Retry original operation
```

## Examples

**After deployment failure:**
```
/fractary-faber-cloud:deploy-apply --env test
# Error: AccessDenied for CreateFunction

/fractary-faber-cloud:debug "AccessDenied for CreateFunction"
# Analyzes and suggests adding lambda:CreateFunction permission
```

**Permission issues:**
```
/fractary-faber-cloud:debug "User is not authorized to perform: s3:CreateBucket"
# Generates IAM policy with required permissions
# Can create permission request
```

## When to Use

Run debug:
- After any deployment error
- For permission issues
- When validation fails
- For mysterious errors
- Before requesting support

## Next Steps

After debugging:
- Apply suggested fixes
- Retry operation: `/fractary-faber-cloud:deploy-apply --env test`
- If still failing: Review AWS console
- Document issue for team

## Invocation

This command invokes the `infra-manager` agent with the `debug` operation.

USE AGENT: infra-manager with operation=debug and description from user input (optional)
