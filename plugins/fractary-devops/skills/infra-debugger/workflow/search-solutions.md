# Solution Search Workflow

## Overview
Search the issue log for known solutions to the current error, rank by relevance and success rate, and select the best solution.

## Search Process

### Step 1: Prepare Search Parameters

```bash
# From categorization step
error_message="${raw_error_message}"
error_code="${extracted_error_code}"
category="${error_category}"
resource_type="${extracted_resource_type}"
environment="${target_environment}"
operation="${attempted_operation}"

# Normalize error for searching
normalized_error=$(normalize_error "${error_message}")
```

### Step 2: Execute Search

```bash
# Use log-resolution.sh to search issue log
search_results=$(../devops-common/scripts/log-resolution.sh \
  --action=search-solutions \
  --error-message="${error_message}" \
  --error-code="${error_code}" \
  --resource-type="${resource_type}" \
  --environment="${environment}")

# Parse results
solution_count=$(echo "${search_results}" | jq 'length')

echo "Found ${solution_count} matching issues with solutions"
```

### Step 3: Rank Solutions

Solutions are ranked by the log-resolution.sh script using:

1. **Exact normalized message match** (Weight: 10.0)
2. **Error code match** (Weight: 5.0)
3. **Resource type match** (Weight: 3.0)
4. **Environment match** (Weight: 2.0)
5. **Success rate** (Weight: 0.0-1.0 based on percentage)

Higher scores = better matches

### Step 4: Filter Solutions

```bash
# Filter solutions by minimum criteria
filtered_solutions=$(echo "${search_results}" | jq '[
  .[] |
  select(.match_score >= 5.0) |  # Minimum score threshold
  select(.solutions | length > 0) |
  {
    issue_id: .issue_id,
    match_score: .match_score,
    error: .error,
    solutions: [
      .solutions[] |
      select(.success_rate.percentage >= 50) |  # Minimum 50% success rate
      select(.success_rate.attempts >= 2)  # Minimum 2 attempts for reliability
    ]
  } |
  select(.solutions | length > 0)  # Only keep issues with viable solutions
]')

viable_count=$(echo "${filtered_solutions}" | jq 'length')
echo "Filtered to ${viable_count} viable solutions"
```

## Solution Selection

### Selection Criteria

Choose the best solution based on:

1. **Highest match score** - Most relevant to current error
2. **Highest success rate** - Most likely to work
3. **Most recent usage** - More recent = more likely still valid
4. **Can be automated** - Prefer automated solutions when available

### Selection Algorithm

```bash
# Get top solution
best_solution=$(echo "${filtered_solutions}" | jq '
  # Sort by match score (primary) and success percentage (secondary)
  sort_by(-.match_score, -.solutions[0].success_rate.percentage) |
  first |
  .solutions[0]
')

# Extract solution details
solution_id=$(echo "${best_solution}" | jq -r '.solution_id')
solution_description=$(echo "${best_solution}" | jq -r '.description')
solution_steps=$(echo "${best_solution}" | jq -r '.steps[]')
solution_category=$(echo "${best_solution}" | jq -r '.category')
automated=$(echo "${best_solution}" | jq -r '.automation.automated')
target_skill=$(echo "${best_solution}" | jq -r '.automation.skill')
success_rate=$(echo "${best_solution}" | jq -r '.success_rate.percentage')
avg_time=$(echo "${best_solution}" | jq -r '.avg_resolution_time_seconds')
```

## Solution Output Format

```json
{
  "search_results": {
    "total_matches": 5,
    "viable_solutions": 3,
    "best_solution": {
      "issue_id": "abc123...",
      "solution_id": "xyz789...",
      "match_score": 18.5,

      "description": "Grant missing S3 permission",

      "steps": [
        "Switch to discover-deploy AWS profile",
        "Grant s3:PutObject permission to deployment role",
        "Switch back to deployment profile",
        "Retry deployment operation"
      ],

      "category": "permission_grant",

      "automation": {
        "automated": true,
        "skill": "infra-permission-manager",
        "operation": "auto-grant",
        "parameters": {
          "permission": "s3:PutObject",
          "resource": "arn:aws:s3:::bucket-name"
        }
      },

      "success_rate": {
        "percentage": 95.5,
        "attempts": 22,
        "successes": 21,
        "failures": 1
      },

      "avg_resolution_time_seconds": 45,
      "last_used": "2025-10-20T15:30:00Z"
    },

    "alternative_solutions": [
      {
        "solution_id": "def456...",
        "description": "Alternative solution",
        "match_score": 15.2,
        "success_rate": 85.0
      }
    ]
  }
}
```

## No Solution Found

If no solutions found or no viable solutions:

```json
{
  "search_results": {
    "total_matches": 0,
    "viable_solutions": 0,
    "best_solution": null,
    "novel_error": true,
    "recommendation": "This error has not been encountered before. Manual investigation required."
  }
}
```

## Solution Confidence

Assign confidence level to selected solution:

**High Confidence (>80%):**
- Match score >= 15.0
- Success rate >= 90%
- Exact error message match
- Recent usage (< 30 days)

**Medium Confidence (50-80%):**
- Match score >= 10.0
- Success rate >= 70%
- Error code match
- Used within 90 days

**Low Confidence (20-50%):**
- Match score >= 5.0
- Success rate >= 50%
- General pattern match
- May need adaptation

**Very Low (<20%):**
- Match score < 5.0
- Success rate < 50%
- Consider as hint only
- Manual review recommended

```bash
# Calculate confidence
if (( $(echo "${match_score} >= 15.0 && ${success_rate} >= 90" | bc -l) )); then
  confidence="high"
elif (( $(echo "${match_score} >= 10.0 && ${success_rate} >= 70" | bc -l) )); then
  confidence="medium"
elif (( $(echo "${match_score} >= 5.0 && ${success_rate} >= 50" | bc -l) )); then
  confidence="low"
else
  confidence="very_low"
fi
```

## Context-Aware Adjustments

### Environment-Specific Adjustments

**Production Environment:**
- Require higher confidence (>70%)
- Prefer well-tested solutions (>10 attempts)
- Avoid experimental solutions
- Require manual approval for automated fixes

**Test Environment:**
- Accept medium confidence (>50%)
- Can try newer solutions (>2 attempts)
- Allow experimental approaches
- Auto-apply high-confidence automated fixes

### Operation-Specific Adjustments

**Destroy Operations:**
- Be more cautious with state fixes
- Prefer manual verification
- Higher confidence threshold

**Deploy Operations:**
- Can be more aggressive with permission fixes
- Automated solutions preferred
- Standard confidence thresholds

## Alternative Solutions

Always include top 2-3 alternative solutions if available:

```bash
alternative_solutions=$(echo "${filtered_solutions}" | jq '
  sort_by(-.match_score, -.solutions[0].success_rate.percentage) |
  .[1:3] |
  map({
    solution_id: .solutions[0].solution_id,
    description: .solutions[0].description,
    match_score: .match_score,
    success_rate: .solutions[0].success_rate.percentage,
    automated: .solutions[0].automation.automated
  })
')
```

Useful when:
- Best solution fails
- User wants to see options
- Multiple solutions have similar scores

## Integration with Issue Log

The search leverages:

1. **Normalized error patterns** - Consistent matching
2. **Historical success rates** - Proven solutions ranked higher
3. **Context matching** - Similar situations get similar solutions
4. **Recency** - More recent solutions weighted higher

This creates a learning system that improves over time as more errors are logged and resolved.

## Example Search Flow

```
Input: "AccessDenied: not authorized for s3:PutObject"

↓

Normalize: "accessdenied: not authorized for s3:putobject"

↓

Search issue log for matches

↓

Found 3 matches:
1. Score: 18.5, Success: 95%, "Grant s3:PutObject" ✓
2. Score: 12.0, Success: 85%, "Update IAM policy"
3. Score: 8.5,  Success: 70%, "Check bucket policy"

↓

Select #1: Highest score + success rate

↓

Return solution with automation details
```
