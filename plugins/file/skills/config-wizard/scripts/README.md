# AWS Profile Discovery for File Storage

## Overview

The `discover-aws-profiles.sh` script automatically discovers and analyzes AWS CLI profiles to simplify S3 configuration for the fractary-file plugin.

## Profile Naming Pattern

This script follows the **Fractary standard naming convention** for AWS deployment profiles:

```
{system}-{subsystem}-{environment}-deploy
```

### Examples

- `corthion-etl-test-deploy` - Test environment for Corthion ETL system
- `corthion-etl-prod-deploy` - Production environment for Corthion ETL system
- `myapp-api-test-deploy` - Test environment for MyApp API
- `myapp-api-prod-deploy` - Production environment for MyApp API

### Supported Environments

- `test` - Testing/QA environment
- `prod` - Production environment
- `staging` - Staging environment
- `dev` - Development environment

## How It Works

### 1. Project Detection

Auto-detects the project name from:
1. Git remote URL (if available)
2. Current directory name (fallback)

### 2. Profile Discovery

Scans for profiles in:
- `~/.aws/config` - AWS CLI configuration
- `~/.aws/credentials` - AWS credentials file

### 3. Profile Filtering

Identifies:
- **Deploy profiles**: Profiles ending in `-deploy`
- **Project-related profiles**: Profiles containing the project name
- **Environment**: Extracted from profile name (test, prod, staging, dev)
- **Region**: Read from AWS config

### 4. Output Format

Returns JSON with:
```json
{
  "project_name": "my-project",
  "all_profiles": [...],
  "deploy_profiles": [...],
  "project_deploy_profiles": [...],
  "summary": {
    "total_profiles": 10,
    "deploy_profiles": 4,
    "project_deploy_profiles": 2
  }
}
```

## Usage

### Standalone

```bash
bash plugins/file/skills/config-wizard/scripts/discover-aws-profiles.sh
```

### In Config Wizard

The script is automatically called during S3 configuration setup to:
1. Show discovered deployment profiles grouped by environment
2. Auto-suggest the test-deploy profile for the current project
3. Auto-fill the region from the selected profile
4. Streamline the configuration process

## Integration with Config Wizard

When configuring S3 in interactive mode, the wizard:

1. **Discovers profiles** matching `{project}-*-{env}-deploy`
2. **Groups by environment** (Test, Production, Staging, Dev)
3. **Shows project-related profiles first** for easy selection
4. **Auto-suggests** the test-deploy profile as default
5. **Auto-fills region** from the selected profile's AWS config

This eliminates manual typing and reduces configuration errors.

## Example Discovery Output

For a project named "corthion-etl" with these profiles:
- `corthion-etl-test-deploy` (us-east-1)
- `corthion-etl-prod-deploy` (us-east-1)
- `other-project-test-deploy` (us-west-2)
- `default` (us-east-1)

The wizard would display:

```
📋 Discovered deployment profiles for 'corthion-etl':
───────────────────────────────────────
  Test:
    • corthion-etl-test-deploy (us-east-1)
  Production:
    • corthion-etl-prod-deploy (us-east-1)

Other deployment profiles available:
  • other-project-test-deploy (us-west-2)

AWS Profile Selection
───────────────────────────────────────
Pattern: {system}-{subsystem}-{env}-deploy

Enter profile name [corthion-etl-test-deploy]: _
```

## Benefits

1. **Zero manual configuration** for standard projects
2. **Automatic environment detection** (test vs prod)
3. **Region auto-fill** from AWS config
4. **Consistent naming** across all Fractary plugins
5. **Project isolation** - only shows relevant profiles
6. **Error prevention** - validates profiles exist

## Compatibility

This script uses the same profile discovery pattern as:
- `faber-cloud` plugin (infrastructure deployment)
- `fractary-repo` plugin (repository operations)
- `fractary-work` plugin (work item management)

All Fractary plugins follow the `{system}-{subsystem}-{env}-deploy` convention.
