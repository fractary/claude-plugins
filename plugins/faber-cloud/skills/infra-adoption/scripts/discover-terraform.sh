#!/bin/bash
# discover-terraform.sh - Discover and analyze existing Terraform infrastructure
#
# Detects Terraform directory structure, identifies patterns (flat, modular, multi-environment),
# analyzes configuration, and generates discovery report

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function: Display usage
usage() {
  cat <<EOF
Usage: discover-terraform.sh <project_root> [output_file]

Discover and analyze Terraform infrastructure in a project.

Arguments:
  project_root  Root directory of the project to analyze
  output_file   Output JSON file (default: discovery-report-terraform.json)

Discovery Includes:
  - Terraform directory location(s)
  - Structure type (flat, modular, multi-environment)
  - Terraform version requirements
  - Backend configuration (local, S3, remote)
  - Variable file patterns
  - Module usage and dependencies
  - Environment separation strategy
  - Resource count estimation

Exit Codes:
  0 - Discovery completed successfully
  1 - No Terraform found
  2 - Invalid arguments

Examples:
  discover-terraform.sh /path/to/project
  discover-terraform.sh /path/to/project terraform-discovery.json
EOF
  exit 2
}

# Function: Log with color
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
  echo -e "${RED}[✗]${NC} $*" >&2
}

# Function: Detect Terraform directories
find_terraform_dirs() {
  local project_root="$1"

  log_info "Searching for Terraform files..."

  # Find all directories containing .tf files
  find "$project_root" -type f -name "*.tf" -not -path "*/.*" -not -path "*/node_modules/*" -not -path "*/vendor/*" 2>/dev/null | \
    xargs -I {} dirname {} | sort -u || echo ""
}

# Function: Analyze Terraform directory structure
analyze_structure() {
  local tf_dir="$1"

  log_info "Analyzing structure of: $tf_dir"

  local structure="flat"

  # Check for modular structure
  if [ -d "$tf_dir/modules" ]; then
    structure="modular"
    log_info "  └─ Detected modules directory"
  fi

  # Check for multi-environment structure
  if [ -d "$tf_dir/environments" ]; then
    structure="multi-environment"
    log_info "  └─ Detected environments directory"
  elif [ -d "$tf_dir/env" ]; then
    structure="multi-environment"
    log_info "  └─ Detected env directory"
  fi

  echo "$structure"
}

# Function: Detect Terraform version
detect_tf_version() {
  local tf_dir="$1"

  # Look for required_version in .tf files
  local version=$(grep -r "required_version" "$tf_dir"/*.tf 2>/dev/null | \
    grep -oE '["><=~]+[[:space:]]*[0-9]+\.[0-9]+(\.[0-9]+)?' | \
    head -1 | sed 's/^["><=~]*[[:space:]]*//' || echo "")

  if [ -n "$version" ]; then
    echo "$version"
  else
    # Try to detect from .terraform-version file
    if [ -f "$tf_dir/.terraform-version" ]; then
      cat "$tf_dir/.terraform-version"
    else
      echo "unknown"
    fi
  fi
}

# Function: Detect backend configuration
detect_backend() {
  local tf_dir="$1"

  log_info "Detecting backend configuration..."

  # Look for backend blocks in .tf files
  local backend_type=$(grep -r "backend[[:space:]]*\"" "$tf_dir"/*.tf 2>/dev/null | \
    grep -oE 'backend[[:space:]]+"[^"]+"' | \
    grep -oE '"[^"]+"' | tr -d '"' | head -1 || echo "")

  if [ -z "$backend_type" ]; then
    backend_type="local"
    log_info "  └─ No explicit backend found, assuming local"
  else
    log_info "  └─ Detected backend: $backend_type"
  fi

  # Extract backend configuration details
  local backend_config="{}"

  case "$backend_type" in
    s3)
      local bucket=$(grep -A 10 "backend[[:space:]]*\"s3\"" "$tf_dir"/*.tf 2>/dev/null | \
        grep -oE 'bucket[[:space:]]*=[[:space:]]*"[^"]+"' | \
        grep -oE '"[^"]+"' | tr -d '"' | head -1 || echo "")

      local key=$(grep -A 10 "backend[[:space:]]*\"s3\"" "$tf_dir"/*.tf 2>/dev/null | \
        grep -oE 'key[[:space:]]*=[[:space:]]*"[^"]+"' | \
        grep -oE '"[^"]+"' | tr -d '"' | head -1 || echo "")

      local region=$(grep -A 10 "backend[[:space:]]*\"s3\"" "$tf_dir"/*.tf 2>/dev/null | \
        grep -oE 'region[[:space:]]*=[[:space:]]*"[^"]+"' | \
        grep -oE '"[^"]+"' | tr -d '"' | head -1 || echo "")

      backend_config=$(jq -n \
        --arg bucket "$bucket" \
        --arg key "$key" \
        --arg region "$region" \
        '{bucket: $bucket, key: $key, region: $region}')
      ;;
    local)
      backend_config='{"path": "terraform.tfstate"}'
      ;;
  esac

  echo "$backend_type|$backend_config"
}

# Function: Detect variable files
detect_var_files() {
  local tf_dir="$1"

  log_info "Detecting variable files..."

  # Find all .tfvars files
  local tfvars_files=$(find "$tf_dir" -maxdepth 2 -name "*.tfvars" -o -name "*.tfvars.json" 2>/dev/null | \
    xargs -I {} basename {} | sort || echo "")

  if [ -z "$tfvars_files" ]; then
    log_warning "  └─ No .tfvars files found"
    echo "[]"
    return
  fi

  # Convert to JSON array
  echo "$tfvars_files" | jq -R . | jq -s .
}

# Function: Detect modules
detect_modules() {
  local tf_dir="$1"

  log_info "Detecting modules..."

  if [ ! -d "$tf_dir/modules" ]; then
    log_info "  └─ No modules directory found"
    echo "[]"
    return
  fi

  # Find all module directories
  local modules=$(find "$tf_dir/modules" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | \
    xargs -I {} basename {} | sort || echo "")

  if [ -z "$modules" ]; then
    echo "[]"
    return
  fi

  log_info "  └─ Found $(echo "$modules" | wc -l) module(s)"

  # Convert to JSON array
  echo "$modules" | jq -R . | jq -s .
}

# Function: Count resources
count_resources() {
  local tf_dir="$1"

  log_info "Counting resources..."

  # Count resource blocks in .tf files
  local count=$(grep -r "^resource[[:space:]]*\"" "$tf_dir"/*.tf 2>/dev/null | wc -l || echo "0")

  log_info "  └─ Found $count resource definition(s)"

  echo "$count"
}

# Function: Detect environment separation strategy
detect_env_strategy() {
  local tf_dir="$1"
  local structure="$2"

  log_info "Detecting environment separation strategy..."

  case "$structure" in
    multi-environment)
      # Check if using directories
      if [ -d "$tf_dir/environments" ] || [ -d "$tf_dir/env" ]; then
        echo "directories"
      else
        echo "unknown"
      fi
      ;;
    *)
      # Check for workspace usage
      if [ -d "$tf_dir/.terraform" ] && [ -d "$tf_dir/.terraform/environment" ]; then
        echo "workspaces"
      # Check for tfvars pattern
      elif ls "$tf_dir"/*.tfvars 2>/dev/null | grep -qE "(test|prod|staging)\.tfvars"; then
        echo "tfvars-files"
      else
        echo "single-environment"
      fi
      ;;
  esac
}

# Main execution
main() {
  # Validate arguments
  if [ $# -lt 1 ]; then
    usage
  fi

  local project_root="$1"
  local output_file="${2:-discovery-report-terraform.json}"

  # Validate project root exists
  if [ ! -d "$project_root" ]; then
    log_error "Project root not found: $project_root"
    exit 2
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_info "Terraform Infrastructure Discovery"
  log_info "Project Root: $project_root"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Find Terraform directories
  local tf_dirs=$(find_terraform_dirs "$project_root")

  if [ -z "$tf_dirs" ]; then
    log_error "No Terraform files found in project"
    echo '{"discovered": false, "reason": "no_terraform_files"}' > "$output_file"
    exit 1
  fi

  local tf_dir_count=$(echo "$tf_dirs" | wc -l)
  log_success "Found Terraform in $tf_dir_count location(s)"
  echo ""

  # Analyze each Terraform directory
  local discoveries="[]"

  while IFS= read -r tf_dir; do
    [ -z "$tf_dir" ] && continue

    log_info "Analyzing: $tf_dir"
    echo "───────────────────────────────────────────────────────────"

    # Analyze structure
    local structure=$(analyze_structure "$tf_dir")

    # Detect version
    local tf_version=$(detect_tf_version "$tf_dir")
    log_info "Terraform version: $tf_version"

    # Detect backend
    local backend_info=$(detect_backend "$tf_dir")
    local backend_type=$(echo "$backend_info" | cut -d'|' -f1)
    local backend_config=$(echo "$backend_info" | cut -d'|' -f2-)

    # Detect variable files
    local var_files=$(detect_var_files "$tf_dir")

    # Detect modules
    local modules=$(detect_modules "$tf_dir")

    # Count resources
    local resource_count=$(count_resources "$tf_dir")

    # Detect environment strategy
    local env_strategy=$(detect_env_strategy "$tf_dir" "$structure")
    log_info "Environment strategy: $env_strategy"

    echo ""

    # Build discovery entry
    local discovery=$(jq -n \
      --arg dir "$tf_dir" \
      --arg structure "$structure" \
      --arg version "$tf_version" \
      --arg backend "$backend_type" \
      --argjson backend_config "$backend_config" \
      --argjson var_files "$var_files" \
      --argjson modules "$modules" \
      --arg resource_count "$resource_count" \
      --arg env_strategy "$env_strategy" \
      '{
        directory: $dir,
        structure: $structure,
        terraform_version: $version,
        backend: {
          type: $backend,
          config: $backend_config
        },
        var_files: $var_files,
        modules: $modules,
        resource_count: ($resource_count | tonumber),
        environment_strategy: $env_strategy
      }')

    discoveries=$(echo "$discoveries" | jq --argjson discovery "$discovery" '. + [$discovery]')

  done <<< "$tf_dirs"

  # Generate final report
  local report=$(jq -n \
    --argjson discoveries "$discoveries" \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{
      discovered: true,
      timestamp: $timestamp,
      terraform_directories: $discoveries,
      summary: {
        total_directories: ($discoveries | length),
        primary_directory: ($discoveries[0].directory // ""),
        primary_structure: ($discoveries[0].structure // ""),
        total_resources: ($discoveries | map(.resource_count) | add // 0)
      }
    }')

  # Write report
  echo "$report" | jq . > "$output_file"

  echo "═══════════════════════════════════════════════════════════"
  log_success "Discovery complete"
  log_info "Report saved to: $output_file"
  echo "═══════════════════════════════════════════════════════════"

  exit 0
}

# Run main function
main "$@"
