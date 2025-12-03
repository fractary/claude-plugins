#!/bin/bash
# Migration script for faber-cloud configuration
# Migrates legacy devops.json/faber-cloud.json to config.json

set -e

CONFIG_DIR=".fractary/plugins/faber-cloud"
LEGACY_FILE="${CONFIG_DIR}/devops.json"
OLD_FILE="${CONFIG_DIR}/faber-cloud.json"
NEW_FILE="${CONFIG_DIR}/config.json"

echo "====================================="
echo "faber-cloud Config Migration"
echo "====================================="
echo

# Check if new file already exists
if [ -f "$NEW_FILE" ]; then
  echo "✅ config.json already exists. No migration needed."
  exit 0
fi

# Determine which old file to migrate
SOURCE_FILE=""
if [ -f "$OLD_FILE" ]; then
  SOURCE_FILE="$OLD_FILE"
  SOURCE_NAME="faber-cloud.json"
elif [ -f "$LEGACY_FILE" ]; then
  SOURCE_FILE="$LEGACY_FILE"
  SOURCE_NAME="devops.json"
else
  echo "ℹ️  No legacy config found (devops.json or faber-cloud.json)."
  echo "   Run /fractary-faber-cloud:init to create configuration."
  exit 0
fi

# Confirm migration
echo "Found ${SOURCE_NAME} configuration file."
echo
echo "This script will:"
echo "  1. Rename: ${SOURCE_NAME} → config.json"
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
echo "Creating backup: ${SOURCE_NAME}.backup"
cp "$SOURCE_FILE" "${SOURCE_FILE}.backup"

# Rename file
echo "Renaming: ${SOURCE_NAME} → config.json"
mv "$SOURCE_FILE" "$NEW_FILE"

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
echo "Your configuration has been migrated to config.json"
echo "Backup available at: ${SOURCE_FILE}.backup"
echo
echo "Next steps:"
echo "  1. Review: cat $NEW_FILE"
echo "  2. Update environment configs if needed"
echo "  3. Validate setup: /fractary-faber-cloud:validate"
