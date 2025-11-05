# Phase 5: Configuration Updates - faber-cloud v2.1

**Parent Spec**: `faber-cloud-v2.1-simplification.md`
**Estimated Effort**: 30 minutes

## Overview

Rename configuration files and update schema to support new operation names and IAM audit system.

## Configuration File Rename

### Primary Config File

**Current**: `.fractary/plugins/faber-cloud/config/devops.json`
**New**: `.fractary/plugins/faber-cloud/config/faber-cloud.json`

**Migration Path**:
```bash
# User command
mv .fractary/plugins/faber-cloud/config/devops.json \
   .fractary/plugins/faber-cloud/config/faber-cloud.json
```

**Backward Compatibility**:
- Keep support for `devops.json` temporarily (v2.1.x)
- Show deprecation warning if `devops.json` found
- Auto-migrate to `faber-cloud.json` with user consent
- Remove backward compatibility in v3.0

---

## Configuration Schema Updates

### Updated Schema

**File**: `.fractary/plugins/faber-cloud/config/faber-cloud.json`

```json
{
  "$schema": "https://fractary.io/schemas/faber-cloud-v2.1.json",
  "version": "2.1.0",
  "plugin": "faber-cloud",

  "handlers": {
    "iac": {
      "active": "terraform",
      "config": {
        "version": "1.5.0",
        "backend": "s3",
        "state_bucket": "terraform-state-bucket",
        "state_key_prefix": "faber-cloud",
        "lock_table": "terraform-locks"
      }
    },
    "hosting": {
      "active": "aws",
      "config": {
        "region": "us-east-1",
        "default_tags": {
          "ManagedBy": "faber-cloud",
          "Environment": "${environment}"
        }
      }
    }
  },

  "environments": {
    "test": {
      "aws_profile": "test-deploy",
      "aws_audit_profile": "test-deploy-discover",
      "iam_audit_file": "infrastructure/iam-policies/test-deploy-permissions.json",
      "terraform_workspace": "test",
      "auto_approve": false,
      "safety_validation": true
    },
    "staging": {
      "aws_profile": "staging-deploy",
      "aws_audit_profile": "staging-deploy-discover",
      "iam_audit_file": "infrastructure/iam-policies/staging-deploy-permissions.json",
      "terraform_workspace": "staging",
      "auto_approve": false,
      "safety_validation": true
    },
    "prod": {
      "aws_profile": "prod-deploy",
      "aws_audit_profile": "prod-deploy-discover",
      "iam_audit_file": "infrastructure/iam-policies/prod-deploy-permissions.json",
      "terraform_workspace": "prod",
      "auto_approve": false,
      "safety_validation": true,
      "production_mode": true,
      "require_confirmations": 3
    }
  },

  "workflows": {
    "design": {
      "skill": "infra-designer",
      "output_dir": "infrastructure/specs"
    },
    "configure": {
      "skill": "infra-configurator",
      "output_dir": "infrastructure/terraform"
    },
    "validate": {
      "skill": "infra-validator",
      "checks": ["syntax", "security", "best-practices"]
    },
    "test": {
      "skill": "infra-tester",
      "security_scanners": ["tfsec", "checkov"],
      "cost_estimation": true
    },
    "deploy-plan": {
      "skill": "infra-planner",
      "output_file": "infrastructure/plans/terraform.tfplan"
    },
    "deploy-apply": {
      "skill": "infra-deployer",
      "pre_validation": true,
      "error_delegation": {
        "auto_debug": false,
        "allow_complete_flag": true
      },
      "post_deployment": {
        "verify_resources": true,
        "update_documentation": true,
        "update_history": true
      }
    },
    "debug": {
      "skill": "infra-debugger",
      "allow_complete_flag": true,
      "return_to_parent": true,
      "error_categories": ["permission", "configuration", "state", "conflict"]
    },
    "teardown": {
      "skill": "infra-teardown",
      "backup_state": true,
      "verify_removal": true,
      "document_teardown": true
    }
  },

  "iam_audit": {
    "enabled": true,
    "audit_dir": "infrastructure/iam-policies",
    "audit_file_pattern": "{environment}-deploy-permissions.json",
    "scripts_dir": "plugins/faber-cloud/skills/infra-permission-manager/scripts/audit",
    "enforce_distinction": true,
    "reject_resource_permissions": true
  },

  "safety": {
    "environment_validation": true,
    "workspace_mismatch_check": true,
    "profile_validation": true,
    "production_safeguards": {
      "multiple_confirmations": true,
      "require_typed_environment": true,
      "disallow_auto_approve": true,
      "extended_timeout": true
    }
  },

  "documentation": {
    "deployment_history": "docs/infrastructure/deployments.md",
    "deployed_resources": "infrastructure/DEPLOYED.md",
    "terraform_docs": "infrastructure/README.md"
  },

  "paths": {
    "infrastructure": "infrastructure",
    "terraform": "infrastructure/terraform",
    "specs": "infrastructure/specs",
    "plans": "infrastructure/plans",
    "backups": "infrastructure/backups",
    "iam_policies": "infrastructure/iam-policies"
  }
}
```

### Schema Changes from v2.0

#### New Sections

1. **iam_audit**: Complete IAM audit system configuration
2. **safety**: Environment safety validation settings
3. **workflows.debug**: Debug-specific configuration with --complete flag support
4. **workflows.teardown**: Teardown-specific configuration

#### Updated Sections

1. **environments**: Added `iam_audit_file`, `aws_audit_profile`, `safety_validation`
2. **workflows**: Renamed operations (design, configure, deploy-plan, deploy-apply)
3. **documentation**: Added deployment_history path

#### Removed Sections

1. **operations**: Removed (operations monitoring moved to helm-cloud)
2. **monitoring**: Removed (moved to helm-cloud)

---

## cloud-common Skill Updates

**File**: `plugins/faber-cloud/skills/cloud-common/SKILL.md`

### Changes Required

#### 1. Update Config Loading

```markdown
<CONTEXT>
You are the cloud-common skill providing shared utilities for faber-cloud plugin.

Your responsibilities:
- Load and parse configuration from faber-cloud.json
- Resolve patterns and variables
- Provide configuration to other skills
</CONTEXT>

<CONFIGURATION_LOADING>
Primary config file: .fractary/plugins/faber-cloud/config/faber-cloud.json

Backward compatibility (v2.1.x only):
- If faber-cloud.json not found, check for devops.json
- If devops.json found:
  1. Show deprecation warning
  2. Prompt user to migrate: "Would you like to rename devops.json to faber-cloud.json?"
  3. If yes: Rename file automatically
  4. If no: Use devops.json but warn on every load

This backward compatibility will be removed in v3.0.
</CONFIGURATION_LOADING>

<CONFIG_SCHEMA>
Expected schema version: 2.1.0

Required sections:
- handlers (iac, hosting)
- environments (test, staging, prod)
- workflows (design, configure, validate, test, deploy-plan, deploy-apply, debug, teardown)
- iam_audit (enabled, audit_dir, scripts_dir)
- safety (environment_validation, production_safeguards)
- documentation (deployment_history, deployed_resources)
- paths (infrastructure, terraform, iam_policies, backups)

Validate schema on load. Error if required sections missing.
</CONFIG_SCHEMA>

<PATTERN_RESOLUTION>
Resolve patterns in config values:

${environment} → Current environment (test, staging, prod)
${aws_profile} → Profile from environments[env].aws_profile
${iam_audit_file} → Audit file from environments[env].iam_audit_file
${region} → Region from handlers.hosting.config.region

Example:
  "state_key_prefix": "faber-cloud/${environment}"
  → Resolves to: "faber-cloud/test" when environment=test
</PATTERN_RESOLUTION>
```

#### 2. Add Helper Functions

```markdown
<HELPER_FUNCTIONS>
get_config()
  - Returns full configuration object
  - Handles backward compatibility (devops.json)
  - Validates schema

get_environment_config(env)
  - Returns environment-specific configuration
  - Includes: aws_profile, aws_audit_profile, iam_audit_file, terraform_workspace, safety_validation

get_workflow_config(operation)
  - Returns workflow-specific configuration
  - Maps operation to skill and config
  - Example: get_workflow_config("design") → {"skill": "infra-designer", "output_dir": "..."}

get_iam_audit_config()
  - Returns IAM audit system configuration
  - Includes: audit_dir, scripts_dir, enforce_distinction

get_safety_config()
  - Returns safety validation configuration
  - Includes: environment_validation, production_safeguards

resolve_path(path_key)
  - Resolves path from paths section
  - Example: resolve_path("iam_policies") → "infrastructure/iam-policies"

validate_environment(env)
  - Validates environment exists in config
  - Checks required fields present
  - Returns validation status
</HELPER_FUNCTIONS>
```

#### 3. Update All References

Search and replace in cloud-common skill:
- `devops.json` → `faber-cloud.json`
- `devops-common` → `cloud-common`
- Operation names: `architect` → `design`, `engineer` → `configure`, etc.

---

## Migration Script

**File**: `plugins/faber-cloud/scripts/migrate-config.sh`

Create migration script for user convenience:

```bash
#!/bin/bash
# Migration script for faber-cloud v2.1 configuration

set -e

CONFIG_DIR=".fractary/plugins/faber-cloud/config"
OLD_FILE="${CONFIG_DIR}/devops.json"
NEW_FILE="${CONFIG_DIR}/faber-cloud.json"

echo "====================================="
echo "faber-cloud v2.1 Config Migration"
echo "====================================="
echo

# Check if new file already exists
if [ -f "$NEW_FILE" ]; then
  echo "✅ faber-cloud.json already exists. No migration needed."
  exit 0
fi

# Check if old file exists
if [ ! -f "$OLD_FILE" ]; then
  echo "ℹ️  No devops.json found. Nothing to migrate."
  echo "   Run /fractary-faber-cloud:init to create configuration."
  exit 0
fi

# Confirm migration
echo "Found devops.json configuration file."
echo
echo "This script will:"
echo "  1. Rename: devops.json → faber-cloud.json"
echo "  2. Update schema version to 2.1.0"
echo "  3. Add new configuration sections (iam_audit, safety)"
echo
read -p "Proceed with migration? (y/n) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Migration cancelled."
  exit 0
fi

# Backup old file
echo "Creating backup: devops.json.backup"
cp "$OLD_FILE" "${OLD_FILE}.backup"

# Rename file
echo "Renaming: devops.json → faber-cloud.json"
mv "$OLD_FILE" "$NEW_FILE"

# Update schema version and add new sections
echo "Updating configuration schema..."
# Use jq to update JSON (assumes jq installed)
if command -v jq &> /dev/null; then
  jq '.version = "2.1.0" |
      .plugin = "faber-cloud" |
      .iam_audit = {
        "enabled": true,
        "audit_dir": "infrastructure/iam-policies",
        "audit_file_pattern": "{environment}-deploy-permissions.json",
        "scripts_dir": "plugins/faber-cloud/skills/infra-permission-manager/scripts/audit",
        "enforce_distinction": true,
        "reject_resource_permissions": true
      } |
      .safety = {
        "environment_validation": true,
        "workspace_mismatch_check": true,
        "profile_validation": true,
        "production_safeguards": {
          "multiple_confirmations": true,
          "require_typed_environment": true,
          "disallow_auto_approve": true,
          "extended_timeout": true
        }
      }' "$NEW_FILE" > "${NEW_FILE}.tmp" && mv "${NEW_FILE}.tmp" "$NEW_FILE"

  echo "✅ Configuration updated successfully"
else
  echo "⚠️  jq not found. Please manually update:"
  echo "   - version: \"2.1.0\""
  echo "   - plugin: \"faber-cloud\""
  echo "   - Add iam_audit section"
  echo "   - Add safety section"
fi

echo
echo "====================================="
echo "Migration Complete"
echo "====================================="
echo
echo "Your configuration has been migrated to faber-cloud.json"
echo "Backup available at: devops.json.backup"
echo
echo "Next steps:"
echo "  1. Review: cat $NEW_FILE"
echo "  2. Update environment configs if needed"
echo "  3. Initialize IAM audit system: /fractary-faber-cloud:init"
```

---

## Implementation Checklist

### Configuration Files

- [ ] Update example config: `config/faber-cloud.example.json`
- [ ] Add schema validation to cloud-common
- [ ] Create migration script: `scripts/migrate-config.sh`
- [ ] Test backward compatibility (devops.json → faber-cloud.json)

### cloud-common Skill Updates

- [ ] Update SKILL.md with new config loading logic
- [ ] Add backward compatibility handling
- [ ] Add deprecation warning for devops.json
- [ ] Update pattern resolution for new operation names
- [ ] Add helper functions (get_iam_audit_config, get_safety_config)
- [ ] Update all internal references (devops → faber-cloud)

### Schema Updates

- [ ] Add iam_audit section
- [ ] Add safety section
- [ ] Update workflows section (rename operations)
- [ ] Add environment configs (iam_audit_file, aws_audit_profile)
- [ ] Add documentation paths
- [ ] Remove operations/monitoring sections (moved to helm-cloud)

### References Updates

Search all files for references to `devops.json` and update:
- [ ] Command files
- [ ] Agent files
- [ ] Skill files
- [ ] Documentation files
- [ ] Test files

---

## Testing

### Configuration Loading

```bash
# Test with new config file
ls .fractary/plugins/faber-cloud/config/faber-cloud.json
/fractary-faber-cloud:init

# Test backward compatibility
mv .fractary/plugins/faber-cloud/config/faber-cloud.json \
   .fractary/plugins/faber-cloud/config/devops.json
/fractary-faber-cloud:init
# Should show deprecation warning and offer migration
```

### Migration Script

```bash
# Test migration
./plugins/faber-cloud/scripts/migrate-config.sh

# Verify:
# 1. devops.json renamed to faber-cloud.json
# 2. Backup created: devops.json.backup
# 3. Schema updated to 2.1.0
# 4. New sections added (iam_audit, safety)
```

### Schema Validation

```bash
# Test with valid config
/fractary-faber-cloud:design "Test feature"

# Test with invalid config (missing required section)
# Remove "handlers" section, verify error message
```

### Pattern Resolution

```bash
# Test environment variable resolution
# Config: "state_key_prefix": "faber-cloud/${environment}"
# Verify resolves to: "faber-cloud/test" for test environment
```

**Validation Points**:
- [ ] New config file loads correctly
- [ ] Backward compatibility works (devops.json)
- [ ] Deprecation warning shown
- [ ] Migration script works
- [ ] Schema validation catches missing sections
- [ ] Pattern resolution works
- [ ] All operations access correct config sections
- [ ] IAM audit config accessible
- [ ] Safety config accessible

---

## Rollback Plan

If issues arise:

1. Revert config file rename:
   ```bash
   mv .fractary/plugins/faber-cloud/config/faber-cloud.json \
      .fractary/plugins/faber-cloud/config/devops.json
   ```

2. Git checkout cloud-common skill

3. Document issues encountered

4. Revise specification before retry

---

## Next Phase

After Phase 5 completion, proceed to **Phase 6: Testing & Validation** (`faber-cloud-v2.1-phase6-testing.md`)
