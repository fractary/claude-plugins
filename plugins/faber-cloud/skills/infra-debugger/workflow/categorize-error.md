# Error Categorization Workflow

## Overview
Analyze error messages to determine error category, extract key information, and prepare for solution searching.

## Error Categories

### 1. Permission Errors

**Indicators:**
- Keywords: `AccessDenied`, `Unauthorized`, `Forbidden`, `403`, `not authorized`, `permission denied`
- AWS specific: `User: arn:aws:iam::...`, `is not authorized to perform`
- Action patterns: `s3:PutObject`, `lambda:InvokeFunction`, `iam:PassRole`

**Examples:**
```
AccessDenied: User arn:aws:iam::123456789012:user/deploy is not authorized to perform s3:PutObject on resource arn:aws:s3:::bucket-name
```

**Category:** `permission`

**Extracted Info:**
- Action: `s3:PutObject`
- Resource: `arn:aws:s3:::bucket-name`
- User/Role: `arn:aws:iam::123456789012:user/deploy`

### 2. Configuration Errors

**Indicators:**
- Keywords: `Invalid`, `ValidationException`, `ValidationError`, `must be`, `required`, `missing`, `malformed`
- Terraform: `Error: Invalid`, `configuration error`
- AWS: `InvalidParameterValue`, `InvalidParameter`, `MissingParameter`

**Examples:**
```
Error: Invalid value for variable "instance_type": must be a valid EC2 instance type
ValidationException: The security group 'sg-123' does not belong to VPC 'vpc-456'
```

**Category:** `config`

**Extracted Info:**
- Parameter: Variable or setting name
- Expected: What was expected
- Received: What was provided
- Resource: Resource being configured

### 3. Resource Errors

**Indicators:**
- Keywords: `does not exist`, `not found`, `404`, `AlreadyExists`, `ConflictException`, `ResourceInUseException`
- Creation failures: `error creating`, `failed to create`
- State issues: `resource already exists`, `duplicate`

**Examples:**
```
Error: InvalidParameterValue: The security group 'sg-nonexistent' does not exist
Error creating S3 bucket: BucketAlreadyExists: The requested bucket name is not available
```

**Category:** `resource`

**Extracted Info:**
- Resource type: `SecurityGroup`, `S3`, `Lambda`, etc.
- Resource ID: Identifier that doesn't exist or conflicts
- Operation: `create`, `update`, `delete`

### 4. State Errors

**Indicators:**
- Keywords: `state`, `StateFile`, `LockID`, `backend`, `state lock`
- Terraform specific: `Error acquiring state lock`, `state file is locked`
- Drift: `resource was modified`, `drift detected`

**Examples:**
```
Error: Error acquiring the state lock
Error: Terraform state file is locked
Error: Resource has been modified outside of Terraform
```

**Category:** `state`

**Extracted Info:**
- State file: Path or backend
- Lock ID: If locked
- Drift details: What changed

### 5. Network Errors

**Indicators:**
- Keywords: `connection`, `timeout`, `unreachable`, `network`, `DNS`, `TLS`, `SSL`
- HTTP errors: `connection refused`, `timeout exceeded`
- DNS: `could not resolve`, `no such host`

**Examples:**
```
Error: connection timeout while accessing https://api.aws.amazon.com
Error: TLS handshake timeout
Error: dial tcp: lookup s3.amazonaws.com: no such host
```

**Category:** `network`

**Extracted Info:**
- Host/endpoint: What couldn't be reached
- Error type: timeout, refused, unreachable
- Port: If specified

### 6. Quota/Limit Errors

**Indicators:**
- Keywords: `limit`, `quota`, `exceeded`, `LimitExceededException`, `throttle`, `rate`
- AWS: `RequestLimitExceeded`, `Throttling`

**Examples:**
```
Error: LimitExceededException: Account has reached maximum number of VPCs
Error: RequestLimitExceeded: Rate exceeded for API call
```

**Category:** `quota`

**Extracted Info:**
- Limit type: What quota was exceeded
- Current value: How many exist
- Maximum: Quota limit
- Service: AWS service

## Categorization Algorithm

### Step 1: Extract Error Code

```bash
# Look for AWS error codes
error_code=$(echo "${error_message}" | grep -oE '(AccessDenied|ValidationException|InvalidParameter|LimitExceeded|ResourceInUse|NotFound|Conflict|Throttling)[A-Za-z]*' | head -1)

# Look for HTTP status codes
http_code=$(echo "${error_message}" | grep -oE '\b(4[0-9]{2}|5[0-9]{2})\b' | head -1)
```

### Step 2: Apply Pattern Matching

```bash
category="unknown"

# Permission patterns
if echo "${error_message}" | grep -qiE '(accessdenied|unauthorized|forbidden|not authorized|permission denied)'; then
  category="permission"

# Configuration patterns
elif echo "${error_message}" | grep -qiE '(invalid|validation|malformed|required|missing parameter)'; then
  category="config"

# Resource patterns
elif echo "${error_message}" | grep -qiE '(does not exist|not found|already exists|conflict|in use)'; then
  category="resource"

# State patterns
elif echo "${error_message}" | grep -qiE '(state|lock|drift|modified outside)'; then
  category="state"

# Network patterns
elif echo "${error_message}" | grep -qiE '(connection|timeout|unreachable|network|dns|tls|ssl)'; then
  category="network"

# Quota patterns
elif echo "${error_message}" | grep -qiE '(limit|quota|exceeded|throttl)'; then
  category="quota"
fi
```

### Step 3: Extract Resource Type

```bash
# Look for AWS resource types
resource_type=""

if echo "${error_message}" | grep -qiE 's3'; then
  resource_type="S3"
elif echo "${error_message}" | grep -qiE 'lambda'; then
  resource_type="Lambda"
elif echo "${error_message}" | grep -qiE 'security[- ]group'; then
  resource_type="SecurityGroup"
elif echo "${error_message}" | grep -qiE '\brds\b|database'; then
  resource_type="RDS"
elif echo "${error_message}" | grep -qiE '\bec2\b|instance'; then
  resource_type="EC2"
elif echo "${error_message}" | grep -qiE '\bvpc\b'; then
  resource_type="VPC"
elif echo "${error_message}" | grep -qiE 'iam|role|policy'; then
  resource_type="IAM"
fi
```

### Step 4: Extract Action (for permission errors)

```bash
# For permission errors, extract the denied action
if [[ "${category}" == "permission" ]]; then
  # Look for AWS action format (service:Action)
  action=$(echo "${error_message}" | grep -oE '[a-z0-9]+:[A-Za-z0-9]+' | head -1)
fi
```

### Step 5: Extract Resource ARN/ID

```bash
# Extract ARN if present
arn=$(echo "${error_message}" | grep -oE 'arn:aws:[a-z0-9-]+:[a-z0-9-]*:[0-9]*:[a-zA-Z0-9/_-]+' | head -1)

# Extract resource ID patterns
resource_id=""
if echo "${error_message}" | grep -qE 'sg-[a-z0-9]+'; then
  resource_id=$(echo "${error_message}" | grep -oE 'sg-[a-z0-9]+' | head -1)
elif echo "${error_message}" | grep -qE 'vpc-[a-z0-9]+'; then
  resource_id=$(echo "${error_message}" | grep -oE 'vpc-[a-z0-9]+' | head -1)
elif echo "${error_message}" | grep -qE 'subnet-[a-z0-9]+'; then
  resource_id=$(echo "${error_message}" | grep -oE 'subnet-[a-z0-9]+' | head -1)
fi
```

## Output Format

```json
{
  "categorization": {
    "category": "permission|config|resource|state|network|quota",
    "confidence": "high|medium|low",

    "error_code": "AccessDenied|InvalidParameter|etc",
    "http_code": "403|404|500|etc",

    "resource_type": "S3|Lambda|RDS|etc",
    "resource_id": "sg-123|vpc-456|bucket-name",
    "resource_arn": "arn:aws:...",

    "action": "s3:PutObject|lambda:InvokeFunction|etc",

    "context": {
      "operation": "${operation}",
      "environment": "${environment}",
      "terraform_module": "extracted if available"
    }
  }
}
```

## Confidence Levels

**High Confidence:**
- Clear error code match (AccessDenied, InvalidParameter)
- Unambiguous keyword matches
- Multiple indicators for same category

**Medium Confidence:**
- Single keyword match
- Less specific error message
- Could fit multiple categories

**Low Confidence:**
- Generic error message
- No clear patterns
- Minimal information available

## Special Cases

### Multi-Factor Errors

Some errors have multiple contributing factors:
```
Error: AccessDenied when creating S3 bucket: bucket name already taken
```

Primary category: `permission` (AccessDenied)
Secondary category: `resource` (already exists)

Choose primary category for routing, note secondary in context.

### Cascading Errors

Errors that are consequences of earlier errors:
```
Error: Cannot attach policy to role: role does not exist
```

Primary error: Role doesn't exist (resource)
This categorization helps find solutions that address root cause.

## Validation

Before proceeding, verify:
- ✅ Category assigned (even if "unknown")
- ✅ Resource type extracted (if applicable)
- ✅ Error code extracted (if available)
- ✅ Context preserved for searching
