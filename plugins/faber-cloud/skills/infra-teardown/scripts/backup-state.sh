#!/bin/bash
# Backup Terraform state before destruction
set -e

ENV=$1

if [ -z "$ENV" ]; then
  echo "Error: Environment not specified"
  exit 1
fi

# Source config loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../cloud-common/scripts/config-loader.sh"

# Load configuration
load_config

# Get Terraform directory from config
TERRAFORM_DIR=$(get_terraform_dir)

if [ ! -d "$TERRAFORM_DIR" ]; then
  echo "Error: Terraform directory not found: $TERRAFORM_DIR"
  exit 1
fi

# Create backup directory
BACKUP_DIR="infrastructure/backups"
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Backup state file
BACKUP_FILE="${BACKUP_DIR}/terraform-state-${ENV}-${TIMESTAMP}.tfstate"

cd "$TERRAFORM_DIR"

# Pull latest state
terraform state pull > "$BACKUP_FILE"

if [ ! -s "$BACKUP_FILE" ]; then
  echo "Error: State backup is empty"
  exit 1
fi

# Verify backup
RESOURCE_COUNT=$(jq '.resources | length' "$BACKUP_FILE")

echo "✓ State backed up successfully"
echo "  Location: $BACKUP_FILE"
echo "  Resources: $RESOURCE_COUNT"
echo "  Size: $(du -h "$BACKUP_FILE" | cut -f1)"
