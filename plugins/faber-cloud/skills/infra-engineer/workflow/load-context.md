# Load Context

This workflow step loads the relevant context based on the parsed input source.

**IMPORTANT:** This step uses the `load-context.sh` script for deterministic context loading operations, keeping them outside LLM context to reduce token usage.

## Input

- Parsed source result (from parse-input step)
- Configuration from config-loader

## Process

### 1. Invoke Load Context Script

Execute the load-context.sh script with parse results:

```bash
# Pass parse result JSON to load-context script
CONTEXT_RESULT=$(./scripts/load-context.sh "$PARSE_RESULT")

if [ $? -ne 0 ]; then
    echo "❌ Context loading failed"
    exit 1
fi

echo "✅ Context loaded successfully"
```

The script handles file loading, validation, and requirement extraction.

### 2. Load Source Document (Script Handles This)

**For design_file:**
```bash
# Read design document
DESIGN_FILE="$FILE_PATH"
if [ ! -f "$DESIGN_FILE" ]; then
    echo "❌ Design file not found: $DESIGN_FILE"
    exit 1
fi

DESIGN_CONTENT=$(cat "$DESIGN_FILE")
echo "✓ Loaded design document: $DESIGN_FILE"
```

Design documents contain:
- Infrastructure requirements
- AWS resource specifications
- Security considerations
- Cost estimates
- Implementation plan

**For faber_spec:**
```bash
# Read FABER specification
SPEC_FILE="$FILE_PATH"
if [ ! -f "$SPEC_FILE" ]; then
    echo "❌ Spec file not found: $SPEC_FILE"
    exit 1
fi

SPEC_CONTENT=$(cat "$SPEC_FILE")
echo "✓ Loaded FABER spec: $SPEC_FILE"
```

FABER specs contain:
- Software requirements
- Technical approach
- Files to modify
- Infrastructure implications (may need extraction)

**For direct_instructions:**
```bash
# Use instructions directly
INSTRUCTIONS="$INPUT_INSTRUCTIONS"
echo "✓ Using direct instructions"

# Load existing Terraform code for context
if [ -d "./infrastructure/terraform" ]; then
    EXISTING_TF=$(find ./infrastructure/terraform -name "*.tf" -type f)
    echo "✓ Loaded existing Terraform files for modification"
fi
```

**For latest_design:**
```bash
# Already determined in parse-input
DESIGN_FILE="$LATEST_DESIGN_PATH"
DESIGN_CONTENT=$(cat "$DESIGN_FILE")
echo "✓ Loaded latest design: $DESIGN_FILE"
```

### 2. Extract Requirements

**From design document:**
- Resource specifications (S3, Lambda, DynamoDB, etc.)
- Configuration requirements
- Security settings
- Naming patterns

**From FABER spec:**
- Parse the "Requirements" section
- Extract infrastructure-related requirements
- Identify needed AWS services
- Example: "API endpoint" → API Gateway + Lambda
- Example: "File storage" → S3 bucket
- Example: "Database" → DynamoDB or RDS

**From direct instructions:**
- Identify target resources
- Determine modification type (add, update, fix)
- Locate relevant existing code

### 3. Load Configuration

```bash
# Load faber-cloud configuration
CONFIG_FILE=".fractary/plugins/faber-cloud/devops.json"
if [ -f "$CONFIG_FILE" ]; then
    CONFIG_JSON=$(cat "$CONFIG_FILE")

    # Extract key config values
    PROJECT_NAME=$(echo "$CONFIG_JSON" | jq -r '.project.name')
    SUBSYSTEM=$(echo "$CONFIG_JSON" | jq -r '.project.subsystem')
    AWS_REGION=$(echo "$CONFIG_JSON" | jq -r '.cloud.aws.region // "us-east-1"')

    echo "✓ Configuration loaded"
else
    echo "⚠️  Configuration file not found, using defaults"
fi
```

### 4. Determine Infrastructure Needs

Based on loaded context, determine:

**AWS Resources Needed:**
- Storage: S3, EFS
- Compute: Lambda, EC2, ECS
- Database: DynamoDB, RDS
- API: API Gateway, ALB
- CDN: CloudFront
- Security: IAM roles, policies, security groups
- Monitoring: CloudWatch logs, alarms

**Resource Relationships:**
- Lambda needs IAM role
- Lambda → S3 needs permissions
- API Gateway → Lambda needs integration
- S3 → CloudFront needs origin config

### 5. Check for Existing Infrastructure

```bash
# Check if Terraform code already exists
TF_DIR="./infrastructure/terraform"

if [ -d "$TF_DIR" ] && [ -f "$TF_DIR/main.tf" ]; then
    echo "⚠️  Existing Terraform detected"
    MODE="update"
else
    echo "✓ Fresh Terraform implementation"
    MODE="create"
fi
```

## Handling Mixed Context and Additional Instructions

When the input includes **mixed context** (e.g., `"Implement api-backend.md and add CloudWatch alarms"`), the system handles it as follows:

### 1. Primary Source (File Content)
The main design or spec file provides the **base requirements**:
- Resource specifications from the document
- Architecture from the design
- Security requirements from the spec

### 2. Additional Context (Merged Instructions)
The `additional_context` field contains extra instructions extracted after the filename:
- These are **additive modifications** to the base requirements
- They refine, extend, or constrain the base design
- They do NOT replace the base requirements

### 3. Merging Strategy

**Example Input:** `"Implement api-backend.md and add CloudWatch alarms"`

**Processing:**
1. **Load base requirements** from `api-backend.md`:
   ```
   - API Gateway REST API
   - Lambda functions for endpoints
   - DynamoDB table
   ```

2. **Parse additional context:** `"and add CloudWatch alarms"`

3. **Merge requirements** (LLM handles merging):
   ```
   - API Gateway REST API
   - Lambda functions for endpoints
   - DynamoDB table
   - CloudWatch alarms for Lambda functions  ← Added
   - CloudWatch alarms for API Gateway  ← Added
   ```

4. **Generate Terraform** with merged requirements

### Retry Context Handling

**Example Input:** `".faber/specs/123-add-api.md - Fix issues: Lambda needs s3:PutObject permission"`

This is a **special case** of mixed context used during FABER retry loops:

1. **Primary source:** `.faber/specs/123-add-api.md` (original spec)
2. **Additional context:** `"Fix issues: Lambda needs s3:PutObject permission"` (from debugger)

**Processing:**
1. Load original spec requirements
2. **Focus on the fix** mentioned in additional context
3. Update existing Terraform code (mode=update)
4. Apply the specific fix while preserving other resources

The `additional_context` acts as a **constraint filter** - it tells the engineer to focus on specific aspects mentioned rather than regenerating everything.

## Output

Return loaded context:
```json
{
  "source_type": "design_file|faber_spec|direct_instructions",
  "source_path": "/path/to/source.md",
  "mode": "create|update",
  "source_content": "full file content",
  "requirements": {
    "resources": ["s3_bucket", "lambda_function", "iam_role"],
    "relationships": ["lambda_to_s3_permissions"],
    "security": ["encryption", "least_privilege"],
    "monitoring": ["cloudwatch_logs"]
  },
  "config": {
    "project_name": "myproject",
    "subsystem": "core",
    "aws_region": "us-east-1"
  },
  "additional_context": "and add CloudWatch alarms"
}
```

**Note:** When `additional_context` is present, the LLM-based Terraform generation step merges it with base requirements intelligently.

## Success Criteria

✅ Source document loaded
✅ Requirements extracted
✅ Configuration loaded
✅ Infrastructure needs identified
✅ Mode determined (create vs update)
✅ Additional context preserved for merging
