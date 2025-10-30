# Post-Deployment Testing Workflow

## Overview
Verify infrastructure after deployment to ensure resources are correctly created and operational.

## Test Suite

### 1. Resource Existence Verification

**Test: Verify Resources Created**
```bash
# Read deployed resources from registry
registry_path=".fractary/plugins/faber-cloud/deployments/${environment}/registry.json"
expected_resources=$(jq -r '.resources | keys[]' ${registry_path})

# For each expected resource, verify it exists
verification_results=()
for resource_id in ${expected_resources}; do
  resource_type=$(jq -r ".resources[\"${resource_id}\"].type" ${registry_path})
  resource_arn=$(jq -r ".resources[\"${resource_id}\"].arn" ${registry_path})

  # Use handler to verify resource
  # This delegates to handler-hosting-{provider}
  **USE SKILL: handler-hosting-${hosting_handler}**
  Operation: verify
  Arguments: ${resource_arn}

  verification_results+=("${resource_id}:${result}")
done
```

**Existence Criteria:**
- ✅ PASS: All expected resources exist
- ❌ FAIL: Any expected resource missing

### 2. Resource Configuration Verification

**Test: Verify Resource Settings**
```bash
# For each deployed resource, verify key configuration settings
for resource_id in ${expected_resources}; do
  resource_type=$(jq -r ".resources[\"${resource_id}\"].type" ${registry_path})

  case ${resource_type} in
    "S3")
      # Verify bucket encryption, versioning, public access block
      **USE SKILL: handler-hosting-${hosting_handler}**
      Operation: query
      Arguments: get-bucket-encryption ${resource_id}

      # Check encryption enabled
      encryption_status=$(echo ${result} | jq -r '.ServerSideEncryptionConfiguration != null')
      ;;

    "Lambda")
      # Verify Lambda configuration, environment variables, memory
      **USE SKILL: handler-hosting-${hosting_handler}**
      Operation: query
      Arguments: get-function ${resource_id}

      # Check configuration matches expected
      memory=$(echo ${result} | jq -r '.Configuration.MemorySize')
      ;;

    "RDS")
      # Verify RDS instance settings, backups, encryption
      **USE SKILL: handler-hosting-${hosting_handler}**
      Operation: query
      Arguments: describe-db-instances ${resource_id}

      # Check encryption enabled
      encryption=$(echo ${result} | jq -r '.DBInstances[0].StorageEncrypted')
      ;;
  esac
done
```

**Configuration Criteria:**
- ✅ PASS: All resources configured as expected
- ⚠️ WARN: Non-critical configuration differences
- ❌ FAIL: Critical configuration mismatch

### 3. Security Posture Verification

**Test: Runtime Security Checks**
```bash
# Check security groups, IAM policies, encryption settings
for resource_id in ${expected_resources}; do
  resource_type=$(jq -r ".resources[\"${resource_id}\"].type" ${registry_path})

  # Security checks based on resource type
  case ${resource_type} in
    "SecurityGroup")
      # Check for overly permissive rules (0.0.0.0/0)
      **USE SKILL: handler-hosting-${hosting_handler}**
      Operation: query
      Arguments: describe-security-groups ${resource_id}

      # Analyze rules for public access
      public_rules=$(echo ${result} | jq '[.SecurityGroups[0].IpPermissions[] | select(.IpRanges[].CidrIp == "0.0.0.0/0")]')
      ;;

    "S3")
      # Check public access block settings
      **USE SKILL: handler-hosting-${hosting_handler}**
      Operation: query
      Arguments: get-public-access-block ${resource_id}

      # Verify all blocks enabled
      blocks=$(echo ${result} | jq '.PublicAccessBlockConfiguration')
      ;;
  esac
done
```

**Security Criteria:**
- ✅ PASS: All security best practices followed
- ⚠️ WARN: Minor security recommendations
- ❌ FAIL: Security vulnerabilities detected

### 4. Integration Testing

**Test: Resource Connectivity**
```bash
# Test that resources can communicate as expected
# Example: Lambda can access S3, RDS can be reached from Lambda

# Get Lambda function ARN
lambda_arn=$(jq -r '.resources[] | select(.type == "Lambda") | .arn' ${registry_path} | head -1)

# Get S3 bucket name
s3_bucket=$(jq -r '.resources[] | select(.type == "S3") | .id' ${registry_path} | head -1)

# Test Lambda can access S3 (if both exist)
if [[ -n "${lambda_arn}" ]] && [[ -n "${s3_bucket}" ]]; then
  # Invoke Lambda with test event that writes to S3
  **USE SKILL: handler-hosting-${hosting_handler}**
  Operation: invoke-lambda
  Arguments: ${lambda_arn} test-event.json

  # Check for successful execution
  execution_status=$(echo ${result} | jq -r '.StatusCode')
fi
```

**Integration Criteria:**
- ✅ PASS: All integration points working
- ⚠️ WARN: Optional integrations not tested
- ❌ FAIL: Required integration failing

### 5. Health Checks

**Test: Resource Health Status**
```bash
# Check health/status of each deployed resource
for resource_id in ${expected_resources}; do
  resource_type=$(jq -r ".resources[\"${resource_id}\"].type" ${registry_path})

  case ${resource_type} in
    "Lambda")
      # Check Lambda recent invocations, errors
      **USE SKILL: handler-hosting-${hosting_handler}**
      Operation: get-function
      Arguments: ${resource_id}

      state=$(echo ${result} | jq -r '.Configuration.State')
      ;;

    "RDS")
      # Check RDS instance status
      **USE SKILL: handler-hosting-${hosting_handler}**
      Operation: describe-db-instances
      Arguments: ${resource_id}

      status=$(echo ${result} | jq -r '.DBInstances[0].DBInstanceStatus')
      ;;

    "ECS")
      # Check ECS service running task count
      **USE SKILL: handler-hosting-${hosting_handler}**
      Operation: describe-services
      Arguments: ${resource_id}

      running_count=$(echo ${result} | jq -r '.services[0].runningCount')
      desired_count=$(echo ${result} | jq -r '.services[0].desiredCount')
      ;;
  esac
done
```

**Health Criteria:**
- ✅ PASS: All resources healthy
- ⚠️ WARN: Resources initializing
- ❌ FAIL: Resources in failed state

### 6. Monitoring Setup Verification

**Test: CloudWatch Alarms and Logs**
```bash
# Verify CloudWatch alarms created for critical resources
for resource_id in ${expected_resources}; do
  resource_type=$(jq -r ".resources[\"${resource_id}\"].type" ${registry_path})

  # Check if alarms exist for this resource
  **USE SKILL: handler-hosting-${hosting_handler}**
  Operation: describe-alarms-for-resource
  Arguments: ${resource_arn}

  alarm_count=$(echo ${result} | jq '.MetricAlarms | length')

  # Check if log group exists (for Lambda, ECS, etc.)
  if [[ "${resource_type}" == "Lambda" ]] || [[ "${resource_type}" == "ECS" ]]; then
    **USE SKILL: handler-hosting-${hosting_handler}**
    Operation: describe-log-groups
    Arguments: /aws/${resource_type}/${resource_id}

    log_group_exists=$(echo ${result} | jq '.logGroups | length > 0')
  fi
done
```

**Monitoring Criteria:**
- ✅ PASS: Monitoring configured for all resources
- ⚠️ WARN: Optional monitoring missing
- ❌ FAIL: Required monitoring not configured

## Test Execution Order

1. Resource Existence Verification (must pass to continue)
2. Resource Configuration Verification
3. Security Posture Verification
4. Health Checks
5. Integration Testing (if applicable)
6. Monitoring Setup Verification

## Result Aggregation

```json
{
  "phase": "post-deployment",
  "environment": "${environment}",
  "timestamp": "${timestamp}",
  "overall_status": "PASS|WARN|FAIL",
  "tests": [
    {
      "name": "resource_existence",
      "status": "PASS|FAIL",
      "resources_expected": 5,
      "resources_found": 5,
      "missing_resources": [],
      "duration_ms": 2345
    },
    {
      "name": "resource_configuration",
      "status": "PASS|WARN|FAIL",
      "resources_checked": 5,
      "misconfigurations": [],
      "duration_ms": 3456
    },
    {
      "name": "security_posture",
      "status": "PASS|WARN|FAIL",
      "security_issues": [],
      "duration_ms": 2789
    },
    {
      "name": "health_checks",
      "status": "PASS|WARN|FAIL",
      "healthy_resources": 5,
      "unhealthy_resources": 0,
      "duration_ms": 1890
    },
    {
      "name": "integration_tests",
      "status": "PASS|WARN|FAIL",
      "tests_run": 3,
      "tests_passed": 3,
      "duration_ms": 5678
    },
    {
      "name": "monitoring_verification",
      "status": "PASS|WARN|FAIL",
      "alarms_configured": 8,
      "log_groups_created": 3,
      "duration_ms": 1234
    }
  ],
  "summary": {
    "total_tests": 6,
    "passed": 6,
    "warnings": 0,
    "failed": 0,
    "resources_verified": 5,
    "total_duration_ms": 17392
  },
  "recommendations": [
    "Consider adding CloudWatch alarm for S3 bucket size",
    "Enable enhanced monitoring for RDS instance"
  ]
}
```

## Critical Issues List

**Block reporting success if:**
- Any expected resource missing
- Resources in failed state
- Critical security vulnerabilities
- Required integration tests failing

**Warn but report success if:**
- Optional monitoring missing
- Non-critical configuration differences
- Health checks still initializing

## Retry Logic

For resources still initializing:
- Retry health checks up to 3 times with 30-second delays
- Mark as WARNING if still initializing after retries
- Provide guidance to user for manual verification
