# Generate Terraform Code

This workflow step generates Terraform infrastructure as code based on the loaded context and requirements.

## Input

- Loaded context (from load-context step)
- Configuration values
- Requirements and resource specifications

## Process

### 1. Initialize File Structure

```bash
TF_DIR="./infrastructure/terraform"
mkdir -p "$TF_DIR"

echo "📁 Terraform directory: $TF_DIR"
```

### 2. Generate main.tf

Create the main Terraform configuration with:

**Provider Configuration:**
```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Backend config provided via init or config file
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
```

**Local Values:**
```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Subsystem   = var.subsystem
    Environment = var.environment
    ManagedBy   = "terraform"
    CreatedBy   = "fractary-faber-cloud"
  }
}
```

**Resources:**

Generate resource blocks based on requirements. Use templates from SKILL.md:

**Example: S3 Bucket**
```hcl
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project_name}-${var.subsystem}-${var.environment}-uploads"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**Example: Lambda Function**
```hcl
resource "aws_lambda_function" "processor" {
  function_name = "${var.project_name}-${var.subsystem}-${var.environment}-processor"
  role          = aws_iam_role.lambda_processor.arn

  runtime = "python3.11"
  handler = "index.handler"

  # Placeholder - user will need to provide actual code
  filename         = "lambda/processor.zip"
  source_code_hash = fileexists("lambda/processor.zip") ? filebase64sha256("lambda/processor.zip") : null

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.uploads.id
    }
  }

  tags = local.common_tags
}

resource "aws_iam_role" "lambda_processor" {
  name = "${var.project_name}-${var.subsystem}-${var.environment}-lambda-processor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_processor_basic" {
  role       = aws_iam_role.lambda_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for S3 access
resource "aws_iam_role_policy" "lambda_processor_s3" {
  name = "s3-access"
  role = aws_iam_role.lambda_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })
}
```

### 3. Generate variables.tf

Define all configurable variables:

```hcl
# Core variables (always included)
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "subsystem" {
  description = "Subsystem name"
  type        = string
}

variable "environment" {
  description = "Environment (test/prod)"
  type        = string

  validation {
    condition     = contains(["test", "prod"], var.environment)
    error_message = "Environment must be test or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Resource-specific variables (generated based on requirements)
# Example:
variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.11"
}
```

### 4. Generate outputs.tf

Define outputs for important resource attributes:

```hcl
output "bucket_name" {
  description = "Name of the uploads S3 bucket"
  value       = aws_s3_bucket.uploads.id
}

output "bucket_arn" {
  description = "ARN of the uploads S3 bucket"
  value       = aws_s3_bucket.uploads.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda processor function"
  value       = aws_lambda_function.processor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda processor function"
  value       = aws_lambda_function.processor.arn
}
```

### 5. Generate tfvars Files (Optional)

Create environment-specific variable files:

**test.tfvars:**
```hcl
project_name = "myproject"
subsystem    = "core"
environment  = "test"
aws_region   = "us-east-1"

# Resource-specific values
lambda_runtime = "python3.11"
```

**prod.tfvars:**
```hcl
project_name = "myproject"
subsystem    = "core"
environment  = "prod"
aws_region   = "us-east-1"

# Resource-specific values
lambda_runtime = "python3.11"
```

### 6. Apply Best Practices

**Naming Conventions:**
- Format: `${project}-${subsystem}-${environment}-${resource}`
- Use variables for all name components
- Consistent across all resources

**Security:**
- Enable encryption by default (S3, DynamoDB, RDS)
- Follow least privilege for IAM policies
- Use security groups properly
- Enable logging where applicable

**Tags:**
- Apply common_tags to all resources
- Include: Project, Subsystem, Environment, ManagedBy, CreatedBy

**Code Organization:**
- Related resources grouped together
- Comments explaining purpose
- Logical ordering (IAM roles before resources that use them)

### 7. Write Files

```bash
# Write all generated files
echo "$MAIN_TF" > "$TF_DIR/main.tf"
echo "$VARIABLES_TF" > "$TF_DIR/variables.tf"
echo "$OUTPUTS_TF" > "$TF_DIR/outputs.tf"

if [ -n "$TEST_TFVARS" ]; then
    echo "$TEST_TFVARS" > "$TF_DIR/test.tfvars"
fi

if [ -n "$PROD_TFVARS" ]; then
    echo "$PROD_TFVARS" > "$TF_DIR/prod.tfvars"
fi

echo "✅ Terraform files generated"
```

## Output

Generated files:
- `main.tf` - Provider config, locals, resources
- `variables.tf` - Variable declarations
- `outputs.tf` - Output definitions
- `test.tfvars` - Test environment values (optional)
- `prod.tfvars` - Prod environment values (optional)

Return summary:
```json
{
  "files_created": [
    "main.tf",
    "variables.tf",
    "outputs.tf"
  ],
  "resource_count": 5,
  "resources": [
    {"type": "aws_s3_bucket", "name": "uploads"},
    {"type": "aws_lambda_function", "name": "processor"},
    {"type": "aws_iam_role", "name": "lambda_processor"}
  ]
}
```

## Success Criteria

✅ All files created
✅ Valid HCL syntax
✅ Resources match requirements
✅ Variables defined for configurable values
✅ Outputs defined for important attributes
✅ Best practices applied (naming, tags, security)
