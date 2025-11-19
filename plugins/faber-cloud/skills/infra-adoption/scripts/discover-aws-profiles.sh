#!/bin/bash
# discover-aws-profiles.sh - Discover and analyze AWS CLI profiles
#
# Analyzes ~/.aws/config and ~/.aws/credentials to find profiles that may be
# related to the project, detects naming patterns, and maps to environments

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
Usage: discover-aws-profiles.sh [project_name] [output_file]

Discover and analyze AWS CLI profiles for infrastructure management.

Arguments:
  project_name  Optional: Project name to filter profiles (default: auto-detect from git)
  output_file   Output JSON file (default: discovery-report-aws.json)

Discovery Includes:
  - All AWS profiles from ~/.aws/config
  - Profile naming patterns
  - Default regions per profile
  - Credential sources (static, SSO, IAM role)
  - Project-related profile detection
  - Environment mapping (test, prod, etc.)

Exit Codes:
  0 - Discovery completed successfully
  1 - No AWS profiles found
  2 - Invalid arguments

Examples:
  discover-aws-profiles.sh
  discover-aws-profiles.sh my-project
  discover-aws-profiles.sh my-project aws-profiles.json
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

# Function: Auto-detect project name from git
detect_project_name() {
  local project_name=""

  # Try to get from git remote
  if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null 2>&1; then
    local remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    if [ -n "$remote_url" ]; then
      # Extract project name from URL
      project_name=$(echo "$remote_url" | sed -E 's/.*[/:]([-a-zA-Z0-9_]+)(\.git)?$/\1/')
    fi
  fi

  # Fallback to current directory name
  if [ -z "$project_name" ]; then
    project_name=$(basename "$(pwd)")
  fi

  echo "$project_name"
}

# Function: Parse AWS config file
parse_aws_config() {
  local config_file="$HOME/.aws/config"

  if [ ! -f "$config_file" ]; then
    log_warning "AWS config file not found: $config_file"
    echo "[]"
    return
  fi

  log_info "Parsing AWS config: $config_file"

  local profiles="[]"
  local current_profile=""
  local region=""
  local credential_source=""
  local sso_start_url=""

  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Profile header
    if [[ "$line" =~ ^\[profile[[:space:]]+([^]]+)\] ]]; then
      # Save previous profile if exists
      if [ -n "$current_profile" ]; then
        local profile_entry=$(jq -n \
          --arg name "$current_profile" \
          --arg region "${region:-us-east-1}" \
          --arg cred_source "${credential_source:-static}" \
          --arg sso_url "${sso_start_url:-}" \
          '{
            name: $name,
            region: $region,
            credential_source: $cred_source,
            sso_start_url: $sso_url
          }')
        profiles=$(echo "$profiles" | jq --argjson entry "$profile_entry" '. + [$entry]')
      fi

      current_profile="${BASH_REMATCH[1]}"
      region=""
      credential_source=""
      sso_start_url=""

    # Region
    elif [[ "$line" =~ ^region[[:space:]]*=[[:space:]]*(.+)$ ]]; then
      region="${BASH_REMATCH[1]}"

    # SSO start URL
    elif [[ "$line" =~ ^sso_start_url[[:space:]]*=[[:space:]]*(.+)$ ]]; then
      sso_start_url="${BASH_REMATCH[1]}"
      credential_source="sso"

    # Source profile (assume role)
    elif [[ "$line" =~ ^source_profile[[:space:]]*= ]]; then
      credential_source="assume-role"

    # Credential process
    elif [[ "$line" =~ ^credential_process[[:space:]]*= ]]; then
      credential_source="credential-process"
    fi
  done < "$config_file"

  # Save last profile
  if [ -n "$current_profile" ]; then
    local profile_entry=$(jq -n \
      --arg name "$current_profile" \
      --arg region "${region:-us-east-1}" \
      --arg cred_source "${credential_source:-static}" \
      --arg sso_url "${sso_start_url:-}" \
      '{
        name: $name,
        region: $region,
        credential_source: $cred_source,
        sso_start_url: $sso_url
      }')
    profiles=$(echo "$profiles" | jq --argjson entry "$profile_entry" '. + [$entry]')
  fi

  echo "$profiles"
}

# Function: Get profiles from credentials file
get_credential_profiles() {
  local cred_file="$HOME/.aws/credentials"

  if [ ! -f "$cred_file" ]; then
    log_info "AWS credentials file not found (may be using SSO or other auth method)"
    echo "[]"
    return
  fi

  log_info "Parsing AWS credentials: $cred_file"

  # Extract profile names from [profile_name] headers
  local profiles=$(grep -E '^\[.+\]' "$cred_file" | sed 's/^\[\(.*\)\]$/\1/' | jq -R . | jq -s . || echo "[]")

  echo "$profiles"
}

# Function: Detect environment from profile name
detect_environment() {
  local profile_name="$1"

  # Normalize to lowercase for matching
  local lower_name=$(echo "$profile_name" | tr '[:upper:]' '[:lower:]')

  # IMPORTANT: Only detect standard deployment environments
  # Do NOT detect IAM user/role names as environments
  # Standard environments: test, prod, staging, dev

  # Check for environment keywords - prioritize most specific matches first
  if [[ "$lower_name" =~ (prod|production|prd)-deploy$ ]] || [[ "$lower_name" =~ ^(prod|production|prd)- ]] || [[ "$lower_name" =~ -(prod|production|prd)$ ]]; then
    echo "prod"
  elif [[ "$lower_name" =~ (staging|stage|stg)-deploy$ ]] || [[ "$lower_name" =~ ^(staging|stage|stg)- ]] || [[ "$lower_name" =~ -(staging|stage|stg)$ ]]; then
    echo "staging"
  elif [[ "$lower_name" =~ (test|testing|tst)-deploy$ ]] || [[ "$lower_name" =~ ^(test|testing|tst)- ]] || [[ "$lower_name" =~ -(test|testing|tst)$ ]]; then
    echo "test"
  elif [[ "$lower_name" =~ (dev|development|devel)-deploy$ ]] || [[ "$lower_name" =~ ^(dev|development|devel)- ]] || [[ "$lower_name" =~ -(dev|development|devel)$ ]]; then
    echo "dev"
  else
    # Unknown - likely an IAM user/role, not an environment
    echo "unknown"
  fi
}

# Function: Check if profile is an IAM utility user (not a deployment environment)
is_iam_utility_profile() {
  local profile_name="$1"

  # Normalize to lowercase
  local lower_name=$(echo "$profile_name" | tr '[:upper:]' '[:lower:]')

  # IMPORTANT: These are IAM user/role patterns that are NOT deployment environments
  # Common IAM utility user patterns:
  # - discover: Used for permission discovery/granting
  # - admin: Administrative access
  # - ci: CI/CD pipeline user
  # - terraform: Terraform state management
  # - backup: Backup operations
  # - monitor: Monitoring/observability

  # Check for utility patterns that should NOT be treated as environments
  if [[ "$lower_name" =~ -discover$ ]] || [[ "$lower_name" =~ -discover- ]]; then
    echo "true"
  elif [[ "$lower_name" =~ -admin$ ]] || [[ "$lower_name" =~ ^admin- ]]; then
    echo "true"
  elif [[ "$lower_name" =~ -ci$ ]] || [[ "$lower_name" =~ ^ci- ]]; then
    echo "true"
  elif [[ "$lower_name" =~ -terraform$ ]] || [[ "$lower_name" =~ ^terraform- ]]; then
    echo "true"
  elif [[ "$lower_name" =~ -backup$ ]] || [[ "$lower_name" =~ ^backup- ]]; then
    echo "true"
  elif [[ "$lower_name" =~ -monitor$ ]] || [[ "$lower_name" =~ ^monitor- ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Function: Check if profile is project-related
is_project_related() {
  local profile_name="$1"
  local project_name="$2"

  # Normalize names
  local lower_profile=$(echo "$profile_name" | tr '[:upper:]' '[:lower:]' | tr '-' '_')
  local lower_project=$(echo "$project_name" | tr '[:upper:]' '[:lower:]' | tr '-' '_')

  # Check if profile contains project name
  if [[ "$lower_profile" == *"$lower_project"* ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Function: Detect naming pattern
detect_naming_pattern() {
  local profiles="$1"

  log_info "Analyzing profile naming patterns..."

  # Extract profile names
  local profile_names=$(echo "$profiles" | jq -r '.[].name')

  # Check for common patterns
  local has_env_suffix=false
  local has_env_prefix=false
  local has_project_prefix=false
  local separator=""

  while IFS= read -r name; do
    [ -z "$name" ] && continue

    # Check for environment suffix (name-test, name-prod)
    if [[ "$name" =~ -(test|prod|staging|dev)$ ]]; then
      has_env_suffix=true
      separator="-"
    fi

    # Check for environment prefix (test-name, prod-name)
    if [[ "$name" =~ ^(test|prod|staging|dev)- ]]; then
      has_env_prefix=true
      separator="-"
    fi

    # Check for underscore separator
    if [[ "$name" =~ _ ]]; then
      separator="_"
    fi

  done <<< "$profile_names"

  local pattern="custom"
  if [ "$has_env_suffix" = true ]; then
    pattern="project-environment"
  elif [ "$has_env_prefix" = true ]; then
    pattern="environment-project"
  fi

  echo "{\"pattern\": \"$pattern\", \"separator\": \"$separator\"}"
}

# Main execution
main() {
  local project_name="${1:-}"
  local output_file="${2:-discovery-report-aws.json}"

  # Auto-detect project name if not provided
  if [ -z "$project_name" ]; then
    project_name=$(detect_project_name)
    log_info "Auto-detected project name: $project_name"
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_info "AWS Profiles Discovery"
  log_info "Project Name: $project_name"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Parse AWS config
  local config_profiles=$(parse_aws_config)

  # Get credential profiles
  local cred_profiles=$(get_credential_profiles)

  # Merge profiles (config takes precedence)
  local all_profiles="$config_profiles"

  # Add credential-only profiles
  while IFS= read -r cred_profile; do
    [ -z "$cred_profile" ] && continue

    # Check if profile already in config
    local exists=$(echo "$all_profiles" | jq --arg name "$cred_profile" 'any(.[]; .name == $name)')

    if [ "$exists" = "false" ]; then
      # Add with defaults
      local entry=$(jq -n \
        --arg name "$cred_profile" \
        '{
          name: $name,
          region: "us-east-1",
          credential_source: "static",
          sso_start_url: ""
        }')
      all_profiles=$(echo "$all_profiles" | jq --argjson entry "$entry" '. + [$entry]')
    fi
  done <<< "$(echo "$cred_profiles" | jq -r '.[]')"

  local profile_count=$(echo "$all_profiles" | jq 'length')

  if [ "$profile_count" -eq 0 ]; then
    log_error "No AWS profiles found"
    echo '{"discovered": false, "reason": "no_profiles_found"}' > "$output_file"
    exit 1
  fi

  log_success "Found $profile_count AWS profile(s)"
  echo ""

  # Enrich profiles with environment detection and project relation
  local enriched_profiles="[]"

  while IFS= read -r profile; do
    [ -z "$profile" ] && continue

    local name=$(echo "$profile" | jq -r '.name')
    local is_utility=$(is_iam_utility_profile "$name")
    local environment=$(detect_environment "$name")
    local project_related=$(is_project_related "$name" "$project_name")

    # Override environment detection if this is a utility profile
    if [ "$is_utility" = "true" ]; then
      environment="iam-utility"
      log_info "Profile: $name → IAM utility user (not an environment)"
    elif [ "$project_related" = "true" ]; then
      log_info "Profile: $name → $environment (project-related)"
    fi

    local enriched=$(echo "$profile" | jq \
      --arg env "$environment" \
      --arg related "$project_related" \
      --arg is_util "$is_utility" \
      '. + {environment: $env, project_related: ($related == "true"), is_iam_utility: ($is_util == "true")}')

    enriched_profiles=$(echo "$enriched_profiles" | jq --argjson entry "$enriched" '. + [$entry]')

  done <<< "$(echo "$all_profiles" | jq -c '.[]')"

  # Detect naming pattern
  local naming_info=$(detect_naming_pattern "$enriched_profiles")

  # Count project-related profiles
  local project_related_count=$(echo "$enriched_profiles" | jq '[.[] | select(.project_related == true)] | length')

  log_info "Project-related profiles: $project_related_count"
  echo ""

  # Generate final report with environment filtering
  local report=$(jq -n \
    --arg project "$project_name" \
    --argjson profiles "$enriched_profiles" \
    --argjson naming "$naming_info" \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{
      discovered: true,
      timestamp: $timestamp,
      project_name: $project,
      profiles: $profiles,
      naming_pattern: $naming,
      summary: {
        total_profiles: ($profiles | length),
        project_related_profiles: ([$profiles[] | select(.project_related == true)] | length),
        iam_utility_profiles: ([$profiles[] | select(.is_iam_utility == true)] | length),
        environments_detected: ([$profiles[] | select(.project_related == true and .is_iam_utility != true and .environment != "unknown" and .environment != "iam-utility") | .environment] | unique),
        most_common_region: ([$profiles[].region] | group_by(.) | max_by(length) | .[0])
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
