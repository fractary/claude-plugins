# Terraform IaC Plugin

Terraform-specific implementation for DevOps automation.

## Purpose

Handles Terraform-specific operations:
- Terraform initialization and validation
- Plan generation and execution
- Error parsing and categorization
- State management
- Configuration validation

## Components

### init.sh

Terraform initialization:
- `terraform_init(environment)` - Initialize Terraform for environment
- `validate_terraform_cli()` - Check Terraform is installed
- `validate_terraform_config(environment)` - Validate Terraform configuration

### plan.sh

Plan generation:
- `terraform_plan(environment, var_file)` - Generate Terraform plan
- `show_terraform_plan(environment)` - Display plan summary
- `terraform_plan_destroy(environment, var_file)` - Generate destroy plan

### apply.sh

Apply Terraform changes:
- `terraform_apply(environment, auto_approve, var_file)` - Apply Terraform plan
- `terraform_destroy(environment, auto_approve, var_file)` - Destroy infrastructure
- `terraform_output(output_name)` - Get output values
- `terraform_refresh(environment, var_file)` - Refresh state

### error-parser.sh

Error parsing and categorization:
- `parse_terraform_error(error_output)` - Parse and categorize errors
- `categorize_error(error)` - Categorize individual error
- `extract_permission_from_error(error)` - Extract IAM permission from error
- `is_permission_error(error)` - Check if error is permission-related
- `is_configuration_error(error)` - Check if error is configuration-related

### validate.sh

Configuration and state validation:
- `validate_terraform_syntax()` - Validate syntax
- `check_terraform_formatting()` - Check file formatting
- `format_terraform_files()` - Format files
- `validate_terraform_state(environment)` - Validate state
- `validate_terraform_variables(environment, var_file)` - Validate variables
- `validate_terraform_backend()` - Validate backend configuration
- `validate_terraform_all(environment)` - Run all validations

## Configuration

Required config values (from `.fractary/.config/devops.json`):

```json
{
  "iac_tool": "terraform",
  "terraform": {
    "directory": "./infrastructure/terraform",
    "var_file_pattern": "{environment}.tfvars",
    "backend": {
      "type": "s3",
      "bucket": "{namespace}-terraform-state",
      "key": "{project}/terraform.tfstate"
    }
  }
}
```

## Usage

```bash
# Source Terraform plugin
source "${SKILL_DIR}/iac-tools/terraform/init.sh"
source "${SKILL_DIR}/iac-tools/terraform/plan.sh"
source "${SKILL_DIR}/iac-tools/terraform/apply.sh"
source "${SKILL_DIR}/iac-tools/terraform/error-parser.sh"
source "${SKILL_DIR}/iac-tools/terraform/validate.sh"

# Validate installation
validate_terraform_cli

# Initialize
terraform_init "test"

# Validate
validate_terraform_all "test"

# Plan
terraform_plan "test" "test.tfvars"
show_terraform_plan "test"

# Apply
terraform_apply "test" "true" "test.tfvars"

# Get outputs
terraform_output "bucket_name"
```

## Terraform Workflow

Standard deployment workflow:

1. **Initialize**: `terraform_init(environment)`
   - Downloads providers
   - Configures backend
   - Prepares working directory

2. **Validate**: `validate_terraform_all(environment)`
   - Checks syntax
   - Validates configuration
   - Verifies variables
   - Checks state accessibility

3. **Plan**: `terraform_plan(environment, var_file)`
   - Generates execution plan
   - Shows proposed changes
   - Saves plan file

4. **Review**: `show_terraform_plan(environment)`
   - Displays summary of changes
   - Lists resources to create/update/delete

5. **Apply**: `terraform_apply(environment, auto_approve, var_file)`
   - Executes plan
   - Creates/updates infrastructure
   - Updates state

## Error Categories

The error parser categorizes errors into:

**Permission Errors:**
- `AccessDenied`, `Unauthorized`, `Forbidden`
- `is not authorized to perform: service:Action`
- → Delegate to devops-permissions skill

**Configuration Errors:**
- `Invalid`, `ValidationError`, `Malformed`
- `required field`, `missing required`
- → Fix in Terraform configuration

**Resource Errors:**
- `AlreadyExists`, `ResourceInUseException`
- `Conflict`, `DependencyViolation`
- → Manual resource resolution

**State Errors:**
- `state lock`, `state file`
- `NoSuchBucket` (for S3 backend)
- → Fix state backend configuration

## Variable Files

Variable files follow pattern: `{environment}.tfvars`

Example `test.tfvars`:
```hcl
environment = "test"
region      = "us-east-1"
namespace   = "corthuxa-core"
project     = "corthography"
```

## Backend Configuration

S3 backend example:
```hcl
terraform {
  backend "s3" {
    bucket = "corthuxa-terraform-state"
    key    = "corthography/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Common Operations

**Check plan without applying:**
```bash
terraform_plan "test"
show_terraform_plan "test"
# Review changes, then:
terraform_apply "test" "false"  # Interactive approval
```

**Auto-approve (CI/CD):**
```bash
terraform_plan "test"
terraform_apply "test" "true"  # Auto-approve
```

**Destroy infrastructure:**
```bash
terraform_plan_destroy "test"  # Preview
terraform_destroy "test" "false"  # Interactive
```

**Get specific output:**
```bash
bucket_name=$(terraform_output "s3_bucket_name")
echo "Bucket: $bucket_name"
```

## Error Handling

When Terraform errors occur:

1. Capture error output
2. Parse with `parse_terraform_error()`
3. Review categorized errors
4. For permission errors:
   - Extract permission with `extract_permission_from_error()`
   - Delegate to devops-permissions skill
5. For configuration errors:
   - Fix in Terraform files
   - Re-run validation
6. For resource errors:
   - Manually resolve conflicts
   - Import existing resources if needed

## See Also

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Provider](../providers/aws/README.md)
- [DevOps Common](/skills/devops-common/SKILL.md)
- [Fractary DevOps Plugin Spec](/docs/specs/fractary-devops-plugin-spec.md)
