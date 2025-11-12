#!/bin/bash
# discover-aws-profiles.sh - Discover AWS CLI profiles for file storage
#
# Simplified version focusing on deployment profiles matching:
# - {system}-{subsystem}-test-deploy
# - {system}-{subsystem}-prod-deploy

set -euo pipefail

# Function: Auto-detect project/system name from git
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
parse_aws_profiles() {
  local config_file="$HOME/.aws/config"

  if [ ! -f "$config_file" ]; then
    echo "[]"
    return
  fi

  local profiles="[]"
  local current_profile=""
  local region=""

  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Profile header: [profile name] or [name]
    if [[ "$line" =~ ^\[profile[[:space:]]+([^]]+)\] ]]; then
      # Save previous profile if exists
      if [ -n "$current_profile" ]; then
        local profile_entry=$(jq -n \
          --arg name "$current_profile" \
          --arg region "${region:-us-east-1}" \
          '{name: $name, region: $region}')
        profiles=$(echo "$profiles" | jq --argjson entry "$profile_entry" '. + [$entry]')
      fi

      current_profile="${BASH_REMATCH[1]}"
      region=""

    # Region
    elif [[ "$line" =~ ^region[[:space:]]*=[[:space:]]*(.+)$ ]]; then
      region="${BASH_REMATCH[1]}"
    fi
  done < "$config_file"

  # Save last profile
  if [ -n "$current_profile" ]; then
    local profile_entry=$(jq -n \
      --arg name "$current_profile" \
      --arg region "${region:-us-east-1}" \
      '{name: $name, region: $region}')
    profiles=$(echo "$profiles" | jq --argjson entry "$profile_entry" '. + [$entry]')
  fi

  echo "$profiles"
}

# Function: Get profiles from credentials file
get_credential_profiles() {
  local cred_file="$HOME/.aws/credentials"

  if [ ! -f "$cred_file" ]; then
    echo "[]"
    return
  fi

  # Extract profile names from [profile_name] headers
  local profiles=$(grep -E '^\[.+\]' "$cred_file" | sed 's/^\[\(.*\)\]$/\1/' | jq -R . | jq -s . || echo "[]")
  echo "$profiles"
}

# Function: Detect environment from profile name
detect_environment() {
  local profile_name="$1"

  # Check for -test-deploy or -prod-deploy suffix
  if [[ "$profile_name" =~ -test-deploy$ ]]; then
    echo "test"
  elif [[ "$profile_name" =~ -prod-deploy$ ]]; then
    echo "prod"
  elif [[ "$profile_name" =~ -staging-deploy$ ]]; then
    echo "staging"
  elif [[ "$profile_name" =~ -dev-deploy$ ]]; then
    echo "dev"
  # Fallback to general environment detection
  elif [[ "$profile_name" =~ (test|testing|tst) ]]; then
    echo "test"
  elif [[ "$profile_name" =~ (prod|production|prd) ]]; then
    echo "prod"
  elif [[ "$profile_name" =~ (staging|stage|stg) ]]; then
    echo "staging"
  elif [[ "$profile_name" =~ (dev|development|devel) ]]; then
    echo "dev"
  else
    echo "unknown"
  fi
}

# Function: Check if profile matches deployment pattern
is_deploy_profile() {
  local profile_name="$1"

  # Check for -deploy suffix (the standard pattern)
  if [[ "$profile_name" =~ -deploy$ ]]; then
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

# Main execution
main() {
  local project_name=$(detect_project_name)

  # Parse AWS config
  local config_profiles=$(parse_aws_profiles)

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
        '{name: $name, region: "us-east-1"}')
      all_profiles=$(echo "$all_profiles" | jq --argjson entry "$entry" '. + [$entry]')
    fi
  done <<< "$(echo "$cred_profiles" | jq -r '.[]')"

  # Enrich profiles with environment detection and filtering
  local enriched_profiles="[]"

  while IFS= read -r profile; do
    [ -z "$profile" ] && continue

    local name=$(echo "$profile" | jq -r '.name')
    local region=$(echo "$profile" | jq -r '.region')
    local environment=$(detect_environment "$name")
    local is_deploy=$(is_deploy_profile "$name")
    local project_related=$(is_project_related "$name" "$project_name")

    local enriched=$(jq -n \
      --arg name "$name" \
      --arg region "$region" \
      --arg env "$environment" \
      --arg deploy "$is_deploy" \
      --arg related "$project_related" \
      '{
        name: $name,
        region: $region,
        environment: $env,
        is_deploy_profile: ($deploy == "true"),
        project_related: ($related == "true")
      }')

    enriched_profiles=$(echo "$enriched_profiles" | jq --argjson entry "$enriched" '. + [$entry]')

  done <<< "$(echo "$all_profiles" | jq -c '.[]')"

  # Filter to deployment profiles
  local deploy_profiles=$(echo "$enriched_profiles" | jq '[.[] | select(.is_deploy_profile == true)]')

  # Further filter to project-related deployment profiles
  local project_deploy_profiles=$(echo "$enriched_profiles" | jq '[.[] | select(.is_deploy_profile == true and .project_related == true)]')

  # Generate output
  local output=$(jq -n \
    --arg project "$project_name" \
    --argjson all "$enriched_profiles" \
    --argjson deploy "$deploy_profiles" \
    --argjson project_deploy "$project_deploy_profiles" \
    '{
      project_name: $project,
      all_profiles: $all,
      deploy_profiles: $deploy,
      project_deploy_profiles: $project_deploy,
      summary: {
        total_profiles: ($all | length),
        deploy_profiles: ($deploy | length),
        project_deploy_profiles: ($project_deploy | length)
      }
    }')

  echo "$output"
}

# Run main function
main "$@"
