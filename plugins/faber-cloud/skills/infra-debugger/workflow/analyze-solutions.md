# Solution Analysis Workflow

## Overview
Analyze the selected solution for applicability, generate detailed proposal, and determine automation strategy.

## Analysis Steps

### Step 1: Validate Solution Applicability

Check if solution can be applied in current context:

```bash
# Extract current context
current_env="${environment}"
current_resource_type="${resource_type}"
current_operation="${operation}"

# Extract solution requirements
solution_env=$(echo "${best_solution}" | jq -r '.original_context.environment // "any"')
solution_resource=$(echo "${best_solution}" | jq -r '.original_context.resource_type // "any"')

# Check compatibility
applicable=true

# Environment check
if [[ "${solution_env}" != "any" ]] && [[ "${solution_env}" != "${current_env}" ]]; then
  echo "WARNING: Solution was used in ${solution_env}, applying to ${current_env}"
  if [[ "${current_env}" == "prod" ]] && [[ "${solution_env}" == "test" ]]; then
    applicable=false
    reason="Solution not tested in production environment"
  fi
fi

# Resource type check
if [[ "${solution_resource}" != "any" ]] && [[ "${solution_resource}" != "${current_resource_type}" ]]; then
  echo "WARNING: Solution was for ${solution_resource}, current resource is ${current_resource_type}"
  applicable=false
  reason="Resource type mismatch"
fi
```

### Step 2: Assess Automation Capability

Determine if solution can be automated in current situation:

```bash
can_automate="${automated}"
automation_blocker=""

# Check if automation is configured
if [[ "${automated}" == "true" ]]; then
  target_skill=$(echo "${best_solution}" | jq -r '.automation.skill')
  skill_operation=$(echo "${best_solution}" | jq -r '.automation.operation')

  # Verify target skill exists
  if [[ ! -f "${PLUGIN_DIR}/skills/${target_skill}/SKILL.md" ]]; then
    can_automate=false
    automation_blocker="Target skill ${target_skill} not found"
  fi

  # Check environment restrictions
  if [[ "${current_env}" == "prod" ]]; then
    # Production requires manual approval even for automated solutions
    requires_approval=true
  fi
fi
```

### Step 3: Estimate Impact

Analyze potential impact of applying solution:

```bash
impact_level="low"
impact_description=""

case "${solution_category}" in
  "permission_grant")
    impact_level="low"
    impact_description="Grants additional IAM permission - low risk"
    ;;

  "config_fix")
    impact_level="medium"
    impact_description="Modifies infrastructure configuration - review changes"
    ;;

  "resource_recreation")
    impact_level="high"
    impact_description="May destroy and recreate resources - potential downtime"
    ;;

  "state_fix")
    impact_level="medium"
    impact_description="Modifies Terraform state - backup recommended"
    ;;
esac

# Higher impact in production
if [[ "${current_env}" == "prod" ]]; then
  if [[ "${impact_level}" == "low" ]]; then
    impact_level="medium"
  elif [[ "${impact_level}" == "medium" ]]; then
    impact_level="high"
  fi
fi
```

### Step 4: Generate Proposal

Create detailed proposal with all information:

```json
{
  "proposal": {
    "problem": {
      "summary": "Access denied when attempting to write to S3 bucket",
      "category": "permission",
      "error_code": "AccessDenied",
      "affected_resource": "arn:aws:s3:::myproject-test-uploads",
      "operation": "deploy",
      "environment": "test"
    },

    "root_cause": {
      "description": "Deployment IAM role lacks s3:PutObject permission for target bucket",
      "details": [
        "Current role: arn:aws:iam::123456789012:role/DeploymentRole",
        "Missing permission: s3:PutObject",
        "Required for: Writing deployment artifacts to S3"
      ]
    },

    "solution": {
      "description": "Grant s3:PutObject permission to deployment role",
      "category": "permission_grant",
      "confidence": "high",
      "success_rate": 95.5,
      "attempts": 22,
      "avg_resolution_time": "45 seconds",

      "steps": [
        "1. Switch to admin/discover-deploy AWS profile with elevated permissions",
        "2. Grant s3:PutObject permission to arn:aws:iam::123456789012:role/DeploymentRole",
        "3. Scope permission to specific bucket: arn:aws:s3:::myproject-test-uploads/*",
        "4. Switch back to deployment profile",
        "5. Retry deployment operation"
      ],

      "automation": {
        "can_automate": true,
        "target_skill": "infra-permission-manager",
        "operation": "auto-grant",
        "requires_approval": false,
        "estimated_time": "30-60 seconds"
      },

      "impact": {
        "level": "low",
        "description": "Grants additional IAM permission - low risk",
        "reversible": true,
        "downtime": false,
        "data_loss_risk": false
      }
    },

    "alternatives": [
      {
        "description": "Manually update IAM policy in AWS Console",
        "pros": ["Direct control", "Visual confirmation"],
        "cons": ["Slower", "Manual steps", "Error-prone"],
        "success_rate": 85.0
      }
    ],

    "recommendations": {
      "primary": "Apply automated solution",
      "rationale": [
        "High success rate (95.5%)",
        "Fast resolution (45 seconds average)",
        "Fully automated via infra-permission-manager",
        "Low risk - permission grants are safe and reversible"
      ],
      "cautions": [
        "Ensure discover-deploy profile is configured",
        "Verify permission scope matches security requirements"
      ]
    }
  }
}
```

### Step 5: Prepare Delegation Instructions

If solution can be automated, prepare detailed delegation:

```json
{
  "delegation": {
    "target_skill": "infra-permission-manager",
    "operation": "auto-grant",

    "parameters": {
      "environment": "test",
      "permission": "s3:PutObject",
      "resource": "arn:aws:s3:::myproject-test-uploads/*",
      "principal": "arn:aws:iam::123456789012:role/DeploymentRole",
      "scope": "resource-specific"
    },

    "callbacks": {
      "on_success": {
        "action": "retry_deployment",
        "log_resolution": {
          "issue_id": "abc123...",
          "solution_id": "xyz789...",
          "success": true,
          "resolution_time": "${duration}"
        }
      },
      "on_failure": {
        "action": "try_alternative_solution",
        "log_resolution": {
          "issue_id": "abc123...",
          "solution_id": "xyz789...",
          "success": false,
          "resolution_time": "${duration}"
        }
      }
    },

    "timeout_seconds": 120,
    "retry_policy": {
      "max_attempts": 3,
      "backoff_seconds": 10
    }
  }
}
```

### Step 6: Generate Manual Instructions

For non-automated solutions or as fallback:

```markdown
# Manual Resolution Steps

## Problem
Access denied when attempting to write to S3 bucket during deployment.

## Root Cause
Deployment IAM role lacks `s3:PutObject` permission for target bucket.

## Solution Steps

### 1. Switch to Administrative Profile
```bash
export AWS_PROFILE=discover-deploy
# Or: aws configure --profile discover-deploy
```

### 2. Identify Current Role
```bash
# Current deployment role
current_role="arn:aws:iam::123456789012:role/DeploymentRole"
```

### 3. Create IAM Policy
```bash
# Create policy document
cat > /tmp/s3-putobject-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::myproject-test-uploads/*"
    }
  ]
}
EOF
```

### 4. Attach Policy to Role
```bash
# Attach inline policy
aws iam put-role-policy \
  --role-name DeploymentRole \
  --policy-name S3PutObjectAccess \
  --policy-document file:///tmp/s3-putobject-policy.json
```

### 5. Verify Permission
```bash
# Get role policies
aws iam get-role-policy \
  --role-name DeploymentRole \
  --policy-name S3PutObjectAccess
```

### 6. Switch Back to Deployment Profile
```bash
export AWS_PROFILE=deployment
```

### 7. Retry Deployment
```bash
# Return to infra-manager and retry deployment
/fractary-faber-cloud:infra-manage deploy --env test
```

## Verification
After successful deployment:
- Check that resources were created in S3
- Verify no further permission errors
- Confirm deployment completed successfully

## Rollback
If needed, remove the policy:
```bash
aws iam delete-role-policy \
  --role-name DeploymentRole \
  --policy-name S3PutObjectAccess
```
```

## Decision Matrix

| Condition | Action | Reason |
|-----------|--------|--------|
| High confidence + Automated + Test env | Auto-apply | Safe and proven |
| High confidence + Automated + Prod env | Request approval | Production safety |
| High confidence + Not automated | Provide manual steps | User must execute |
| Medium confidence + Automated | Request approval | Verify before applying |
| Low confidence | Provide as suggestion | User decides |
| No solution found | Request manual investigation | Novel error |

## Output Format

Return comprehensive analysis to manager:

```json
{
  "analysis": {
    "applicable": true,
    "confidence": "high",
    "can_automate": true,
    "requires_approval": false,
    "impact_level": "low",

    "proposal": { /* detailed proposal */ },
    "delegation": { /* delegation instructions */ },
    "manual_steps": [ /* fallback manual steps */ ],

    "recommendations": {
      "primary_action": "auto_apply",
      "reasoning": "High confidence, proven solution, low risk",
      "estimated_time": "30-60 seconds",
      "success_probability": "95%"
    }
  }
}
```

This comprehensive analysis enables the manager to make informed decisions about how to proceed with error resolution.
