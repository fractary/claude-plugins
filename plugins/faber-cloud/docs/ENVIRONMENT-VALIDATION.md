# Environment Validation & IAM Profile Prevention

**Date**: 2025-11-19
**Issue**: [Migration Issue #153] - Preventing IAM users from being misidentified as deployment environments

## Problem Statement

IAM utility users (with names like `discover`, `admin`, `ci`, etc.) were being incorrectly identified as deployment environments, leading to:

1. Configuration generation for non-existent environments
2. Audit recommendations to create infrastructure for IAM users
3. Implementation attempts to deploy to "discover" environment
4. Confusion between IAM users and deployment environments

### Root Cause

The AWS profile discovery script (`discover-aws-profiles.sh`) was using an overly permissive environment detection function that treated any profile name containing certain keywords (including "discover") as an environment.

**Example problematic profile**:
- Profile name: `corthuxa-core-discover-deploy`
- Incorrectly detected as: "discover" environment
- Actual purpose: IAM user for permission discovery/granting

## Solution: Multi-Layer Defense

We implemented a comprehensive, defense-in-depth approach with multiple safeguards:

### Layer 1: Strict Environment Detection

**File**: `plugins/faber-cloud/skills/infra-adoption/scripts/discover-aws-profiles.sh`

**Changes**:
1. **Removed "discover" from environment keywords** - It's not a deployment environment
2. **Added position-aware matching** - Only match environment keywords in expected positions:
   - Suffix: `{name}-{env}-deploy`
   - Prefix: `{env}-{name}`
   - Middle: `{name}-{env}`
3. **Prioritized specific matches** - Match prod, staging, test, dev in order

**Before**:
```bash
elif [[ "$lower_name" =~ discover ]]; then
    echo "discover"  # This was the bug!
```

**After**:
```bash
# IMPORTANT: Only detect standard deployment environments
# Do NOT detect IAM user/role names as environments
# Standard environments: test, prod, staging, dev

if [[ "$lower_name" =~ (prod|production|prd)-deploy$ ]] || [[ "$lower_name" =~ ^(prod|production|prd)- ]] || [[ "$lower_name" =~ -(prod|production|prd)$ ]]; then
  echo "prod"
elif [[ "$lower_name" =~ (staging|stage|stg)-deploy$ ]] || [[ "$lower_name" =~ ^(staging|stage|stg)- ]] || [[ "$lower_name" =~ -(staging|stage|stg)$ ]]; then
  echo "staging"
# ... similar for test, dev
else
  echo "unknown"
fi
```

### Layer 2: IAM Utility Profile Detection

**File**: `plugins/faber-cloud/skills/infra-adoption/scripts/discover-aws-profiles.sh`

**New Function**: `is_iam_utility_profile()`

Explicitly identifies profiles that are IAM utility users, not environments:

```bash
is_iam_utility_profile() {
  # Patterns that are NOT deployment environments:
  # - discover: Permission discovery/granting
  # - admin: Administrative access
  # - ci: CI/CD pipeline user
  # - terraform: Terraform state management
  # - backup: Backup operations
  # - monitor: Monitoring/observability

  if [[ "$lower_name" =~ -discover$ ]] || [[ "$lower_name" =~ -discover- ]]; then
    echo "true"
  # ... similar for admin, ci, terraform, backup, monitor
}
```

Profiles identified as IAM utilities are:
- Marked with `is_iam_utility: true` in discovery report
- Assigned environment: `"iam-utility"` instead of deployment environment
- Excluded from environment configuration generation

### Layer 3: Environment Validation Utility

**File**: `plugins/faber-cloud/skills/infra-adoption/scripts/shared/validate-environments.sh`

**Purpose**: Centralized environment validation logic

**Standard Allowed Environments**:
- `test` / `testing` / `tst`
- `prod` / `production` / `prd`
- `staging` / `stage` / `stg`
- `dev` / `development` / `devel`

**IAM Utility Patterns (Always Rejected)**:
- `discover`
- `admin`
- `ci`
- `terraform`
- `backup`
- `monitor`
- `audit`
- `readonly`
- `poweruser`

**Functions**:
- `is_standard_environment(env)` - Check if environment is standard
- `is_iam_utility_pattern(env)` - Check if matches IAM utility pattern
- `validate_environment(env, source)` - Validate single environment
- `validate_environment_list(list, source)` - Validate list of environments
- `filter_environments(list)` - Remove invalid environments from list

**Exit Codes**:
- `0` = Valid (standard environment)
- `1` = Invalid (IAM utility pattern)
- `2` = Warning (non-standard but not IAM utility)

### Layer 4: Configuration Generation Validation

**File**: `plugins/faber-cloud/skills/infra-adoption/scripts/generate-config.sh`

**Changes**:
1. **Source validation utility** - Import environment validation functions
2. **Filter IAM utilities** - Skip profiles marked as `is_iam_utility: true`
3. **Skip unknown environments** - Don't create config for `environment: "unknown"`
4. **Validate before adding** - Run validation on each environment before adding to config

**Logic**:
```bash
# Skip IAM utility profiles
if [ "$is_iam_utility" = "true" ] || [ "$environment" = "iam-utility" ]; then
  log_warning "Skipped IAM utility profile: $profile_name (not an environment)"
  continue
fi

# Skip unknown environments
if [ "$environment" = "unknown" ]; then
  log_warning "Skipped profile with unknown environment: $profile_name"
  continue
fi

# Validate environment
local validation_result=$(validate_environment "$environment" "AWS profile $profile_name")
if [[ "$validation_result" == *"invalid"* ]]; then
  log_error "Skipped profile with invalid environment: $profile_name → $environment"
  continue
fi
```

### Layer 5: Discovery Report Enhancement

**File**: `plugins/faber-cloud/skills/infra-adoption/scripts/discover-aws-profiles.sh`

**Enhanced Discovery Report**:
```json
{
  "profiles": [
    {
      "name": "corthuxa-core-discover-deploy",
      "environment": "iam-utility",
      "is_iam_utility": true,
      "project_related": true
    },
    {
      "name": "corthuxa-core-test-deploy",
      "environment": "test",
      "is_iam_utility": false,
      "project_related": true
    }
  ],
  "summary": {
    "iam_utility_profiles": 1,
    "environments_detected": ["test", "prod"]  // discover excluded!
  }
}
```

## Testing & Validation

### Test Scenario 1: Discover Profile

**Input**: AWS profile `corthuxa-core-discover-deploy`

**Expected Behavior**:
1. Discovery detects as IAM utility user
2. Marked with `is_iam_utility: true`
3. Environment set to `"iam-utility"`
4. Excluded from `environments_detected` summary
5. **NOT** included in generated config.json
6. **NO** recommendation to create "discover" infrastructure

**Test**:
```bash
# Run AWS discovery
bash plugins/faber-cloud/skills/infra-adoption/scripts/discover-aws-profiles.sh \
  project-name \
  /tmp/aws-discovery.json

# Verify discover is marked as IAM utility
jq '.profiles[] | select(.name | contains("discover"))' /tmp/aws-discovery.json

# Expected output:
{
  "name": "corthuxa-core-discover-deploy",
  "environment": "iam-utility",
  "is_iam_utility": true
}

# Verify environments_detected excludes discover
jq '.summary.environments_detected' /tmp/aws-discovery.json
# Expected: ["test", "prod"] (no "discover")
```

### Test Scenario 2: Config Generation

**Input**: Discovery report with discover profile

**Expected Behavior**:
1. Config generation skips IAM utility profiles
2. Logs warning: "Skipped IAM utility profile: corthuxa-core-discover-deploy"
3. Generated config has only test/prod environments

**Test**:
```bash
# Generate config
bash plugins/faber-cloud/skills/infra-adoption/scripts/generate-config.sh \
  terraform-report.json \
  aws-discovery.json \
  agents-report.json \
  /tmp/config.json

# Verify only test/prod in config
jq '.environments[].name' /tmp/config.json
# Expected: "test" and "prod" only (no "discover")
```

### Test Scenario 3: Environment Validation

**Test**:
```bash
# Test validation utility
bash plugins/faber-cloud/skills/infra-adoption/scripts/shared/validate-environments.sh \
  'discover' 'test-profile'

# Expected: Exit code 1 (invalid - IAM utility pattern)
# Expected output: Error message about IAM utility user

bash plugins/faber-cloud/skills/infra-adoption/scripts/shared/validate-environments.sh \
  'test' 'test-profile'

# Expected: Exit code 0 (valid - standard environment)
```

## Prevention Guidelines

### For Plugin Developers

1. **Never add non-deployment keywords to environment detection**
   - Only add: test, prod, staging, dev, qa
   - Never add: discover, admin, ci, backup, etc.

2. **Always use position-aware matching**
   - Don't use simple substring matching
   - Match environment keywords in expected positions only

3. **Add new IAM patterns to the utility list**
   - Update `is_iam_utility_profile()` when discovering new patterns
   - Document the purpose of each pattern

4. **Use validation utility for all environment operations**
   - Source `shared/validate-environments.sh`
   - Validate before creating configs, running audits, etc.

### For Users

1. **Use clear naming conventions**
   - Deployment profiles: `{project}-{env}-deploy`
   - IAM utility profiles: `{project}-{purpose}` (e.g., `project-discover`)

2. **Review discovery reports carefully**
   - Check `environments_detected` in summary
   - Verify `is_iam_utility` flags are correct
   - Report misclassifications

3. **Question unusual environments**
   - If audit recommends "discover" environment, it's wrong
   - Standard environments: test, prod, staging, dev only
   - Report as bug if others appear

## Future Improvements

1. **Configuration schema validation**
   - Add JSON schema for faber-cloud.json
   - Validate environment names match allowlist

2. **Audit enhancement**
   - Add warnings when non-standard environments detected
   - Separate IAM health checks from environment audits

3. **User-configurable environment list**
   - Allow projects to define custom environments
   - Require explicit configuration (not auto-detection)

4. **Better error messages**
   - When IAM profile detected, suggest correct naming
   - Provide examples of correct profile names

## Related Files

- `plugins/faber-cloud/skills/infra-adoption/scripts/discover-aws-profiles.sh`
- `plugins/faber-cloud/skills/infra-adoption/scripts/generate-config.sh`
- `plugins/faber-cloud/skills/infra-adoption/scripts/shared/validate-environments.sh`
- `plugins/faber-cloud/skills/infra-auditor/scripts/audit-iam.sh`

## References

- Issue: [Migrate to faber-cloud - Discover Environment Issue]
- PR: [Fix: Prevent IAM users from being detected as environments]
- Related: FRACTARY-PLUGIN-STANDARDS.md (Environment naming conventions)
