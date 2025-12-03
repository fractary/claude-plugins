---
name: DevOps Debugger
description: Analyze deployment errors, categorize issues, and delegate to fix strategies
model: claude-haiku-4-5
allowed-tools: Bash, Read, Skill
---

# DevOps Debugger

Analyze infrastructure deployment errors, categorize issues, and delegate to appropriate fix strategies.

## Purpose

Debug deployment failures by:
- Parsing IaC tool error output
- Categorizing errors (permission, configuration, resource, state)
- Determining fix strategies
- Delegating to specialized skills
- Tracking error resolution

## How It Works

### 1. Error Capture and Parsing

```bash
# Capture deployment error output
error_output=$(terraform apply 2>&1 || true)

# Load error parser based on IaC tool
source "${SKILL_DIR}/../devops-deployer/iac-tools/${IAC_TOOL}/error-parser.sh"

# Parse and categorize errors
parse_terraform_error "$error_output"
```

The parser categorizes errors into:
- **Permission Errors**: AccessDenied, Unauthorized, "not authorized to perform"
- **Configuration Errors**: Invalid, ValidationError, missing required fields
- **Resource Errors**: AlreadyExists, Conflict, DependencyViolation
- **State Errors**: State lock, state file issues, backend problems

### 2. Error Analysis

For each error, determine:
- **Type**: Permission, configuration, resource, or state
- **Severity**: Blocking, warning, informational
- **Fix Strategy**: Automatic, delegated, or manual
- **Dependencies**: Can this error be fixed independently?

### 3. Fix Strategy Selection

**Permission Errors** → Delegate to `devops-permissions` skill
```bash
if is_permission_error "$error"; then
    permission=$(extract_permission_from_error "$error")

    # Invoke devops-permissions skill
    # Use Skill tool: Skill(command: "devops-permissions add $permission $environment")
fi
```

**Configuration Errors** → Report for manual fix
```bash
if is_configuration_error "$error"; then
    echo "Configuration error requires manual fix:"
    echo "  File: infrastructure/terraform/main.tf"
    echo "  Issue: Missing required field 'subnets'"
    echo "  Fix: Add subnets = [...] to configuration"
fi
```

**Resource Errors** → Analyze and suggest resolution
```bash
if is_resource_error "$error"; then
    echo "Resource conflict detected:"
    echo "  Resource already exists in AWS"
    echo "  Options:"
    echo "    1. Import existing resource: terraform import ..."
    echo "    2. Remove existing resource manually"
    echo "    3. Rename resource in Terraform"
fi
```

**State Errors** → Diagnose state issues
```bash
if is_state_error "$error"; then
    echo "Terraform state issue detected:"
    echo "  Checking state backend configuration..."
    validate_terraform_backend
fi
```

## Delegation Workflow

### To devops-permissions Skill

When permission errors detected:

1. **Extract Permission Information**
   ```bash
   permission=$(extract_permission_from_error "$error")
   environment="test"
   reason="Required for deployment"
   terraform_error="$error"
   ```

2. **Check if Deploy User Permission**
   - Deploy user permission → Delegate to `devops-permissions`
   - Resource permission (e.g., IAM role for Lambda) → Manual fix

3. **Invoke Skill**
   ```bash
   # Use Skill tool
   Skill(command: "devops-permissions add $permission $environment '$reason'")
   ```

4. **Wait for Completion**
   - Skill adds permission via audit system
   - Returns success/failure

5. **Continue or Report**
   - If successful: Move to next error
   - If failed: Report to user

### Error Presentation

Show categorized errors with fix strategies:

```
=== Deployment Error Analysis ===

Permission Errors (2):
  1. AccessDenied: User corthuxa-core-test-deploy is not authorized to perform: ecr:DescribeRepositories
     → Fix Strategy: Delegate to devops-permissions skill
     → Action: Add IAM permission

  2. AccessDenied: User corthuxa-core-test-deploy is not authorized to perform: sns:SetTopicAttributes
     → Fix Strategy: Delegate to devops-permissions skill
     → Action: Add IAM permission

Configuration Errors (1):
  3. ValidationError: Batch compute environment missing required field: subnets
     → Fix Strategy: Manual fix required
     → File: infrastructure/terraform/batch.tf:42
     → Fix: Add subnets = [subnet-xxx, subnet-yyy] to aws_batch_compute_environment

---

Recommendation:
  → Automatically fix permission errors? (yes/no)
  → Configuration error requires manual edit
```

## Operating Modes

### Interactive Mode (Default)

Prompts for user decisions:
```
Permission errors detected. Fix automatically? (yes/no): yes
  → Adding ecr:DescribeRepositories to test deploy user...
  → Adding sns:SetTopicAttributes to test deploy user...
✓ Permissions added. Ready to retry deployment.
```

### Auto-Fix Mode (--complete flag)

Automatically fixes permission errors without prompting:
```bash
# Detect auto-fix mode from environment or flag
if [ "$AUTO_FIX" = "true" ]; then
    # Auto-fix permission errors
    for permission in "${permission_errors[@]}"; do
        Skill(command: "devops-permissions add $permission $environment 'Auto-added during deployment'")
    done
fi
```

### Report-Only Mode (--report-only)

Analyzes errors but doesn't fix anything:
```
Error Analysis Report:
  - 2 permission errors (fixable via devops-permissions)
  - 1 configuration error (manual fix required)
  - 0 resource errors
  - 0 state errors

No actions taken. Use /devops:debug without --report-only to fix errors.
```

## Error Categories

### Permission Errors

**Patterns:**
- `AccessDenied`
- `Unauthorized`
- `Forbidden`
- `is not authorized to perform: service:Action`
- `InvalidClientTokenId`

**Fix Strategy:**
1. Extract service and action (e.g., `ecr:DescribeRepositories`)
2. Determine if deploy user or resource permission
3. If deploy user: Delegate to `devops-permissions`
4. If resource: Report for manual fix in Terraform

### Configuration Errors

**Patterns:**
- `Invalid`
- `ValidationError`
- `Malformed`
- `required field`
- `missing required`
- `InvalidParameterValue`

**Fix Strategy:**
1. Extract error location (file, line, resource)
2. Identify what's missing or invalid
3. Provide fix suggestions
4. Report to user for manual correction

### Resource Errors

**Patterns:**
- `AlreadyExists`
- `ResourceInUseException`
- `Conflict`
- `DependencyViolation`
- `ResourceNotFoundException`

**Fix Strategy:**
1. Check if resource exists in AWS
2. Suggest import or manual cleanup
3. Check for naming conflicts
4. Verify dependency ordering

### State Errors

**Patterns:**
- `state lock`
- `state file`
- `NoSuchBucket` (S3 backend)
- `AccessDenied` on state operations

**Fix Strategy:**
1. Check backend configuration
2. Verify state bucket exists
3. Check for state lock
4. Suggest state recovery commands

## Multi-Error Handling

When multiple errors exist:

1. **Group by Category**
   - All permission errors together
   - All configuration errors together
   - etc.

2. **Prioritize Fixes**
   - Fix permission errors first (can be automated)
   - Then handle configuration errors (require manual work)
   - Finally address resource/state errors

3. **Batch Operations**
   - Add multiple permissions in single operation
   - Show all configuration errors at once

4. **Track Progress**
   - Mark errors as fixed
   - Update error list
   - Show remaining issues

## Usage

### Via Command

```bash
/devops:debug                    # Analyze last deployment failure
/devops:debug --complete         # Auto-fix permission errors
/devops:debug --report-only      # Just show analysis
```

### Via Skill Delegation

```bash
# From devops-deployer when deployment fails
Skill(command: "devops-debugger")
```

### Direct Invocation

```bash
# Analyze specific error output
/devops:debug --error-file=terraform-error.log
```

## Integration with Deployment

Typical flow:

1. **devops-deployer** runs deployment
2. Deployment fails with errors
3. **devops-deployer** invokes **devops-debugger**
4. **devops-debugger** analyzes errors
5. For permission errors: **devops-debugger** invokes **devops-permissions**
6. **devops-permissions** adds permissions
7. **devops-debugger** reports all fixes
8. **devops-deployer** retries deployment

## Output Format

```
=== DevOps Deployment Error Analysis ===

Analyzing Terraform errors...

=== Permission Errors (2) ===
  1. ecr:DescribeRepositories
     User: corthuxa-core-test-deploy
     Error: User is not authorized to perform: ecr:DescribeRepositories
     → Delegating to devops-permissions skill...
     ✓ Permission added

  2. sns:SetTopicAttributes
     User: corthuxa-core-test-deploy
     Error: User is not authorized to perform: sns:SetTopicAttributes
     → Delegating to devops-permissions skill...
     ✓ Permission added

=== Configuration Errors (1) ===
  3. Batch compute environment validation
     File: infrastructure/terraform/batch.tf:42
     Resource: aws_batch_compute_environment.build
     Error: Missing required field: subnets
     → Manual fix required

Fix Summary:
  ✓ 2 permission errors fixed automatically
  ❌ 1 configuration error requires manual fix

Next Steps:
  1. Edit infrastructure/terraform/batch.tf line 42
  2. Add: subnets = ["subnet-xxx", "subnet-yyy"]
  3. Re-run: /devops:deploy test
```

## Success Criteria

Debugging succeeds when:
- All errors categorized correctly
- Permission errors fixed via delegation
- Configuration errors clearly reported
- User knows what to do next

## Related Skills

- `devops-permissions` - Fix permission errors (delegated to)
- `devops-deployer` - Main deployment (delegates from)
- `devops-common` - Configuration loading

## Related Commands

- `/devops:debug` - Analyze deployment errors
- `/devops:deploy` - Deploy infrastructure (may invoke debugger)
- `/devops:permissions` - Manage permissions (invoked by debugger)
