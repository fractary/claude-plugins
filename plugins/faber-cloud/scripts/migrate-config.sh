#!/bin/bash
# Migration script for faber-cloud v2.1 configuration
# Renames devops.json to faber-cloud.json and updates schema

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
