# Issue Log Schema

## Overview
The issue log tracks infrastructure deployment errors, their solutions, and success rates for intelligent debugging.

## File Location
`.fractary/plugins/faber-cloud/deployments/issue-log.json`

## Schema Definition

```json
{
  "version": "1.0",
  "created": "ISO-8601 timestamp",
  "last_updated": "ISO-8601 timestamp",
  "issues": [
    {
      "issue_id": "unique-identifier",
      "first_seen": "ISO-8601 timestamp",
      "last_seen": "ISO-8601 timestamp",
      "occurrence_count": "integer",

      "error": {
        "category": "permission|config|resource|state|network|quota",
        "message": "original error message",
        "normalized_message": "normalized error pattern",
        "code": "error code if available",
        "context": {
          "environment": "test|prod",
          "operation": "deploy|destroy|validate|preview",
          "resource_type": "S3|Lambda|RDS|etc",
          "resource_name": "name of resource",
          "terraform_module": "module name if applicable"
        }
      },

      "solutions": [
        {
          "solution_id": "unique-identifier",
          "description": "human-readable description",
          "category": "permission_grant|config_fix|resource_recreation|state_fix",
          "steps": [
            "Step 1: Action to take",
            "Step 2: Follow-up action",
            "Step 3: Verification step"
          ],
          "automation": {
            "automated": true,
            "skill": "infra-permission-manager",
            "operation": "auto-grant",
            "parameters": {}
          },
          "success_rate": {
            "attempts": "integer",
            "successes": "integer",
            "failures": "integer",
            "percentage": "float 0-100"
          },
          "first_used": "ISO-8601 timestamp",
          "last_used": "ISO-8601 timestamp",
          "avg_resolution_time_seconds": "integer"
        }
      ],

      "tags": [
        "aws",
        "iam",
        "permission",
        "s3"
      ],

      "related_issues": [
        "issue-id-1",
        "issue-id-2"
      ],

      "notes": [
        {
          "timestamp": "ISO-8601 timestamp",
          "author": "infra-debugger",
          "note": "Additional context or observations"
        }
      ]
    }
  ],

  "statistics": {
    "total_issues": "integer",
    "total_resolutions": "integer",
    "avg_resolution_time_seconds": "integer",
    "most_common_categories": {
      "permission": "count",
      "config": "count",
      "resource": "count"
    },
    "automation_rate": "percentage of issues auto-resolved"
  }
}
```

## Field Descriptions

### Issue Fields

**issue_id**: SHA-256 hash of normalized error message + resource type
- Ensures consistent identification of same error across occurrences
- Format: `sha256(normalized_message + resource_type)`

**first_seen**: Timestamp when this error was first encountered

**last_seen**: Timestamp of most recent occurrence

**occurrence_count**: Number of times this specific error has occurred

### Error Fields

**category**: Classification of error type
- `permission`: IAM/authorization issues
- `config`: Configuration or validation errors
- `resource`: Resource creation/modification failures
- `state`: Terraform state issues
- `network`: Connectivity or network issues
- `quota`: Service quota or limit issues

**normalized_message**: Error message with variable parts removed
- Example: `"Access Denied for action s3:PutObject"`
- Variables like bucket names, ARNs replaced with placeholders
- Used for matching similar errors

**context**: Environmental context when error occurred
- Helps match solutions to similar situations
- Used for filtering and searching

### Solution Fields

**solution_id**: Unique identifier for this solution approach

**description**: Clear, actionable description of solution

**category**: Type of solution
- `permission_grant`: Grant missing permissions
- `config_fix`: Fix configuration issue
- `resource_recreation`: Recreate or modify resource
- `state_fix`: Fix terraform state issues

**steps**: Ordered list of actions to resolve issue

**automation**: Details if solution can be automated
- `automated`: boolean - can this be auto-applied
- `skill`: which skill can auto-apply this
- `operation`: operation to call
- `parameters`: parameters to pass

**success_rate**: Track effectiveness of this solution
- `attempts`: Total times this solution was tried
- `successes`: Times it successfully resolved the issue
- `failures`: Times it failed to resolve
- `percentage`: Success rate (successes/attempts * 100)

**avg_resolution_time_seconds**: Average time to resolve using this solution

### Statistics

**automation_rate**: Percentage of logged issues that were auto-resolved
- Indicates effectiveness of automated error handling
- Goal: Increase over time as more solutions are automated

## Error Normalization

### Purpose
Normalize error messages to identify same root cause across different contexts.

### Normalization Rules

1. **Remove specific identifiers**
   - ARNs: `arn:aws:s3:::bucket-name` → `arn:aws:s3:::{BUCKET}`
   - Resource names: `myproject-test-database` → `{PROJECT}-{ENV}-{RESOURCE}`
   - Account IDs: `123456789012` → `{ACCOUNT_ID}`

2. **Remove timestamps and request IDs**
   - `RequestId: abc123` → `RequestId: {REQUEST_ID}`
   - `at 2025-10-28 10:30:00` → `at {TIMESTAMP}`

3. **Standardize formatting**
   - Convert to lowercase for comparison
   - Remove extra whitespace
   - Standardize quotes

4. **Extract error code**
   - AWS error codes: `AccessDenied`, `ValidationException`
   - HTTP status codes: `403`, `404`

### Example Normalization

**Original:**
```
Error: error creating S3 bucket (myproject-test-uploads): AccessDenied:
Access Denied for action s3:CreateBucket on resource arn:aws:s3:::myproject-test-uploads
RequestId: abc123-def456
```

**Normalized:**
```
error creating s3 bucket: accessdenied: access denied for action s3:createbucket
```

**Error Code:** `AccessDenied`

**Resource Type:** `S3`

**Action:** `s3:CreateBucket`

## Solution Matching Algorithm

### Ranking Factors

When searching for solutions, rank by:

1. **Exact normalized message match** (highest priority)
   - Weight: 10.0

2. **Error code match**
   - Weight: 5.0

3. **Resource type match**
   - Weight: 3.0

4. **Environment match** (test vs prod)
   - Weight: 2.0

5. **Operation match** (deploy vs destroy)
   - Weight: 1.5

6. **Solution success rate**
   - Weight: 1.0 * (success_percentage / 100)

7. **Recency** (more recent solutions ranked higher)
   - Weight: 0.5 * (1 / days_since_last_used)

### Scoring Formula

```
score = (exact_match * 10.0) +
        (error_code_match * 5.0) +
        (resource_type_match * 3.0) +
        (environment_match * 2.0) +
        (operation_match * 1.5) +
        (success_rate / 100) +
        (0.5 / max(1, days_since_last_used))
```

### Example Scoring

Error: S3 AccessDenied during deploy in test environment

Solution A:
- Exact normalized match: Yes (10.0)
- Error code match: Yes (5.0)
- Resource type match: Yes (3.0)
- Environment match: Yes (2.0)
- Operation match: Yes (1.5)
- Success rate: 95% (0.95)
- Last used: 2 days ago (0.25)
- **Total: 22.70**

Solution B:
- Exact normalized match: No (0)
- Error code match: Yes (5.0)
- Resource type match: Yes (3.0)
- Environment match: No (0)
- Operation match: Yes (1.5)
- Success rate: 80% (0.80)
- Last used: 30 days ago (0.017)
- **Total: 10.32**

→ Solution A ranked higher

## Maintenance

### Log Rotation
When issue-log.json exceeds 10MB:
1. Archive to S3: `s3://{bucket}/issue-logs/issue-log-{timestamp}.json`
2. Keep only last 90 days of issues in local file
3. Maintain statistics across all archived logs

### Cleanup
Periodically remove:
- Issues with no successful solutions after 180 days
- Solutions with <10% success rate after 50 attempts
- Duplicate solutions (same steps, merged into one)

### Statistics Updates
Update statistics block on every log update:
- Total counts
- Category distribution
- Automation rate
- Average resolution time

## Usage Examples

### Log New Issue
```bash
../devops-common/scripts/log-resolution.sh \
  --action=log-issue \
  --error-message="AccessDenied: User not authorized for s3:PutObject" \
  --error-code="AccessDenied" \
  --category="permission" \
  --resource-type="S3" \
  --environment="test" \
  --operation="deploy"
```

### Log Solution
```bash
../devops-common/scripts/log-resolution.sh \
  --action=log-solution \
  --issue-id="abc123..." \
  --description="Grant s3:PutObject permission" \
  --steps='["Switch to discover-deploy profile", "Grant permission", "Retry operation"]' \
  --automated=true \
  --skill="infra-permission-manager" \
  --success=true \
  --resolution-time=45
```

### Search Solutions
```bash
../devops-common/scripts/log-resolution.sh \
  --action=search-solutions \
  --error-message="AccessDenied: User not authorized for s3:PutObject" \
  --resource-type="S3" \
  --environment="test"
```

Returns ranked list of matching solutions.

## Integration with infra-debugger

The infra-debugger skill uses this log to:

1. **Search for known solutions** when errors occur
2. **Rank solutions** by relevance and success rate
3. **Log new issues** when novel errors encountered
4. **Update solution success rates** after resolution attempts
5. **Learn from patterns** to improve future debugging

## Best Practices

1. **Always normalize errors** before creating issue_id
2. **Update success rates** after every resolution attempt
3. **Add context** to help future matching
4. **Link related issues** for pattern recognition
5. **Archive old logs** to keep file size manageable
6. **Review statistics** to identify automation opportunities
