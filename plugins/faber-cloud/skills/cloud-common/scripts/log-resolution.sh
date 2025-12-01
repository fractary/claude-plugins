#!/bin/bash
#
# Issue Log Management Script
#
# Manages the infrastructure issue log including:
# - Logging new issues
# - Recording solutions and their success/failure
# - Searching for solutions to known issues
# - Updating statistics
#
# Usage:
#   log-resolution.sh --action log-issue --error-message "..." --category permission ...
#   log-resolution.sh --action log-solution --issue-id "..." --success true ...
#   log-resolution.sh --action search-solutions --error-message "..." ...

set -euo pipefail

# Default paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
ISSUE_LOG_FILE="${PLUGIN_DIR}/.fractary/plugins/faber-cloud/deployments/issue-log.json"
ISSUE_LOG_TEMPLATE="${SCRIPT_DIR}/../templates/issue-log.json.template"

# Initialize variables
ACTION=""
ERROR_MESSAGE=""
ERROR_CODE=""
CATEGORY=""
RESOURCE_TYPE=""
RESOURCE_NAME=""
ENVIRONMENT=""
OPERATION=""
ISSUE_ID=""
SOLUTION_DESCRIPTION=""
SOLUTION_STEPS=""
SOLUTION_CATEGORY=""
AUTOMATED="false"
SKILL=""
SKILL_OPERATION=""
SUCCESS="false"
RESOLUTION_TIME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --action)
      ACTION="$2"
      shift 2
      ;;
    --error-message)
      ERROR_MESSAGE="$2"
      shift 2
      ;;
    --error-code)
      ERROR_CODE="$2"
      shift 2
      ;;
    --category)
      CATEGORY="$2"
      shift 2
      ;;
    --resource-type)
      RESOURCE_TYPE="$2"
      shift 2
      ;;
    --resource-name)
      RESOURCE_NAME="$2"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --operation)
      OPERATION="$2"
      shift 2
      ;;
    --issue-id)
      ISSUE_ID="$2"
      shift 2
      ;;
    --description)
      SOLUTION_DESCRIPTION="$2"
      shift 2
      ;;
    --steps)
      SOLUTION_STEPS="$2"
      shift 2
      ;;
    --solution-category)
      SOLUTION_CATEGORY="$2"
      shift 2
      ;;
    --automated)
      AUTOMATED="$2"
      shift 2
      ;;
    --skill)
      SKILL="$2"
      shift 2
      ;;
    --skill-operation)
      SKILL_OPERATION="$2"
      shift 2
      ;;
    --success)
      SUCCESS="$2"
      shift 2
      ;;
    --resolution-time)
      RESOLUTION_TIME="$2"
      shift 2
      ;;
    --*=*)
      # Reject equals syntax with helpful error
      FLAG_NAME="${1%%=*}"
      echo "Error: Use space-separated syntax, not equals syntax" >&2
      echo "Use: $FLAG_NAME <value>" >&2
      echo "Not: $1" >&2
      exit 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Ensure issue log exists
ensure_issue_log() {
  if [[ ! -f "${ISSUE_LOG_FILE}" ]]; then
    mkdir -p "$(dirname "${ISSUE_LOG_FILE}")"
    if [[ -f "${ISSUE_LOG_TEMPLATE}" ]]; then
      cp "${ISSUE_LOG_TEMPLATE}" "${ISSUE_LOG_FILE}"
    else
      # Create minimal template
      echo '{"version":"1.0","created":"'$(date -Iseconds)'","last_updated":"'$(date -Iseconds)'","issues":[]}' > "${ISSUE_LOG_FILE}"
    fi
    echo "Created issue log: ${ISSUE_LOG_FILE}"
  fi
}

# Normalize error message for consistent matching
normalize_error() {
  local error="$1"

  # Convert to lowercase
  error=$(echo "$error" | tr '[:upper:]' '[:lower:]')

  # Remove specific identifiers
  error=$(echo "$error" | sed -E 's/arn:aws:[^:]+::[^:]*:[^[:space:]]*/arn:aws:{SERVICE}::{RESOURCE}/g')
  error=$(echo "$error" | sed -E 's/[a-z0-9-]+-[a-z0-9-]+-[a-z0-9-]+-[a-z0-9]+/{PROJECT}-{ENV}-{RESOURCE}/g')
  error=$(echo "$error" | sed -E 's/[0-9]{12}/{ACCOUNT_ID}/g')
  error=$(echo "$error" | sed -E 's/requestid: [a-z0-9-]+/requestid: {REQUEST_ID}/g')
  error=$(echo "$error" | sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}/{TIMESTAMP}/g')

  # Remove extra whitespace
  error=$(echo "$error" | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  echo "$error"
}

# Generate issue ID from normalized message and resource type
generate_issue_id() {
  local normalized="$1"
  local resource_type="$2"

  # Create SHA-256 hash
  echo -n "${normalized}|${resource_type}" | sha256sum | awk '{print $1}'
}

# Log a new issue
log_issue() {
  ensure_issue_log

  # Normalize error message
  local normalized=$(normalize_error "${ERROR_MESSAGE}")

  # Generate issue ID
  local issue_id=$(generate_issue_id "${normalized}" "${RESOURCE_TYPE}")

  echo "Logging issue: ${issue_id}"
  echo "Normalized: ${normalized}"

  # Check if issue already exists
  local existing=$(jq --arg id "${issue_id}" '.issues[] | select(.issue_id == $id)' "${ISSUE_LOG_FILE}")

  if [[ -n "${existing}" ]]; then
    # Update existing issue
    echo "Issue already exists, updating occurrence count"
    jq --arg id "${issue_id}" \
       --arg timestamp "$(date -Iseconds)" \
       '.issues = [.issues[] | if .issue_id == $id then .last_seen = $timestamp | .occurrence_count += 1 else . end] |
        .last_updated = $timestamp' \
       "${ISSUE_LOG_FILE}" > "${ISSUE_LOG_FILE}.tmp"
    mv "${ISSUE_LOG_FILE}.tmp" "${ISSUE_LOG_FILE}"
  else
    # Add new issue
    echo "Adding new issue to log"
    jq --arg id "${issue_id}" \
       --arg timestamp "$(date -Iseconds)" \
       --arg category "${CATEGORY}" \
       --arg message "${ERROR_MESSAGE}" \
       --arg normalized "${normalized}" \
       --arg code "${ERROR_CODE}" \
       --arg env "${ENVIRONMENT}" \
       --arg op "${OPERATION}" \
       --arg res_type "${RESOURCE_TYPE}" \
       --arg res_name "${RESOURCE_NAME}" \
       '.issues += [{
         issue_id: $id,
         first_seen: $timestamp,
         last_seen: $timestamp,
         occurrence_count: 1,
         error: {
           category: $category,
           message: $message,
           normalized_message: $normalized,
           code: $code,
           context: {
             environment: $env,
             operation: $op,
             resource_type: $res_type,
             resource_name: $res_name
           }
         },
         solutions: [],
         tags: [],
         related_issues: [],
         notes: []
       }] |
       .last_updated = $timestamp' \
       "${ISSUE_LOG_FILE}" > "${ISSUE_LOG_FILE}.tmp"
    mv "${ISSUE_LOG_FILE}.tmp" "${ISSUE_LOG_FILE}"
  fi

  # Update statistics
  update_statistics

  echo "Issue logged successfully: ${issue_id}"
  echo "${issue_id}"
}

# Log a solution for an issue
log_solution() {
  ensure_issue_log

  echo "Logging solution for issue: ${ISSUE_ID}"

  # Generate solution ID
  local solution_id=$(echo -n "${ISSUE_ID}|${SOLUTION_DESCRIPTION}" | sha256sum | awk '{print $1}')
  local timestamp=$(date -Iseconds)

  # Check if solution already exists
  local existing=$(jq --arg issue_id "${ISSUE_ID}" \
                      --arg sol_id "${solution_id}" \
                      '.issues[] | select(.issue_id == $issue_id) | .solutions[] | select(.solution_id == $sol_id)' \
                      "${ISSUE_LOG_FILE}")

  if [[ -n "${existing}" ]]; then
    # Update existing solution with new attempt
    echo "Solution exists, updating success rate"

    # Calculate new success rate
    local attempts=$(echo "${existing}" | jq -r '.success_rate.attempts')
    local successes=$(echo "${existing}" | jq -r '.success_rate.successes')
    local failures=$(echo "${existing}" | jq -r '.success_rate.failures')
    local total_time=$(echo "${existing}" | jq -r '.avg_resolution_time_seconds * .success_rate.attempts')

    attempts=$((attempts + 1))
    if [[ "${SUCCESS}" == "true" ]]; then
      successes=$((successes + 1))
      total_time=$((total_time + RESOLUTION_TIME))
    else
      failures=$((failures + 1))
    fi

    local percentage=$(echo "scale=2; ${successes} * 100 / ${attempts}" | bc)
    local avg_time=$(echo "scale=0; ${total_time} / ${successes}" | bc)

    jq --arg issue_id "${ISSUE_ID}" \
       --arg sol_id "${solution_id}" \
       --arg timestamp "${timestamp}" \
       --argjson attempts "${attempts}" \
       --argjson successes "${successes}" \
       --argjson failures "${failures}" \
       --argjson percentage "${percentage}" \
       --argjson avg_time "${avg_time}" \
       '.issues = [.issues[] | if .issue_id == $issue_id then
         .solutions = [.solutions[] | if .solution_id == $sol_id then
           .success_rate.attempts = $attempts |
           .success_rate.successes = $successes |
           .success_rate.failures = $failures |
           .success_rate.percentage = $percentage |
           .avg_resolution_time_seconds = $avg_time |
           .last_used = $timestamp
         else . end]
       else . end] |
       .last_updated = $timestamp' \
       "${ISSUE_LOG_FILE}" > "${ISSUE_LOG_FILE}.tmp"
    mv "${ISSUE_LOG_FILE}.tmp" "${ISSUE_LOG_FILE}"

  else
    # Add new solution
    echo "Adding new solution"

    local percentage=0
    local successes=0
    local failures=0

    if [[ "${SUCCESS}" == "true" ]]; then
      percentage=100
      successes=1
    else
      failures=1
    fi

    jq --arg issue_id "${ISSUE_ID}" \
       --arg sol_id "${solution_id}" \
       --arg timestamp "${timestamp}" \
       --arg description "${SOLUTION_DESCRIPTION}" \
       --arg category "${SOLUTION_CATEGORY}" \
       --argjson steps "${SOLUTION_STEPS}" \
       --argjson automated "${AUTOMATED}" \
       --arg skill "${SKILL}" \
       --arg skill_op "${SKILL_OPERATION}" \
       --argjson successes "${successes}" \
       --argjson failures "${failures}" \
       --argjson percentage "${percentage}" \
       --argjson res_time "${RESOLUTION_TIME:-0}" \
       '.issues = [.issues[] | if .issue_id == $issue_id then
         .solutions += [{
           solution_id: $sol_id,
           description: $description,
           category: $category,
           steps: $steps,
           automation: {
             automated: $automated,
             skill: $skill,
             operation: $skill_op,
             parameters: {}
           },
           success_rate: {
             attempts: 1,
             successes: $successes,
             failures: $failures,
             percentage: $percentage
           },
           first_used: $timestamp,
           last_used: $timestamp,
           avg_resolution_time_seconds: $res_time
         }]
       else . end] |
       .last_updated = $timestamp' \
       "${ISSUE_LOG_FILE}" > "${ISSUE_LOG_FILE}.tmp"
    mv "${ISSUE_LOG_FILE}.tmp" "${ISSUE_LOG_FILE}"
  fi

  # Update statistics
  update_statistics

  echo "Solution logged successfully"
}

# Search for solutions matching an error
search_solutions() {
  ensure_issue_log

  echo "Searching for solutions..." >&2

  # Normalize error message
  local normalized=$(normalize_error "${ERROR_MESSAGE}")

  echo "Normalized query: ${normalized}" >&2

  # Search for matching issues and rank solutions
  jq --arg normalized "${normalized}" \
     --arg resource_type "${RESOURCE_TYPE}" \
     --arg environment "${ENVIRONMENT}" \
     --arg error_code "${ERROR_CODE}" \
     '[.issues[] |
       # Calculate match score
       (if .error.normalized_message == $normalized then 10.0 else 0 end) as $exact_match |
       (if .error.code == $error_code and $error_code != "" then 5.0 else 0 end) as $code_match |
       (if .error.context.resource_type == $resource_type then 3.0 else 0 end) as $resource_match |
       (if .error.context.environment == $environment then 2.0 else 0 end) as $env_match |
       (1.0) as $base_score |

       # Calculate total score
       ($exact_match + $code_match + $resource_match + $env_match + $base_score) as $score |

       # Select if score > 0 and has solutions
       select($score > 0 and (.solutions | length) > 0) |

       # Add score to each solution
       {
         issue_id: .issue_id,
         error: .error,
         match_score: $score,
         solutions: [.solutions[] |
           . + {
             total_score: ($score + (.success_rate.percentage / 100))
           }
         ] | sort_by(.total_score) | reverse
       }
     ] | sort_by(.match_score) | reverse' \
     "${ISSUE_LOG_FILE}"
}

# Update statistics in issue log
update_statistics() {
  local timestamp=$(date -Iseconds)

  jq --arg timestamp "${timestamp}" \
     '{
       version: .version,
       created: .created,
       last_updated: $timestamp,
       issues: .issues,
       statistics: {
         total_issues: (.issues | length),
         total_resolutions: ([.issues[].solutions[].success_rate.successes] | add // 0),
         avg_resolution_time_seconds: (
           [.issues[].solutions[] | select(.success_rate.successes > 0) | .avg_resolution_time_seconds] |
           if length > 0 then (add / length) else 0 end
         ),
         most_common_categories: (
           [.issues[] | .error.category] | group_by(.) |
           map({key: .[0], value: length}) | from_entries
         ),
         automation_rate: (
           ([.issues[].solutions[] | select(.automation.automated == true) | .success_rate.successes] | add // 0) /
           ([.issues[].solutions[].success_rate.successes] | add // 1) * 100
         )
       }
     }' \
     "${ISSUE_LOG_FILE}" > "${ISSUE_LOG_FILE}.tmp"
  mv "${ISSUE_LOG_FILE}.tmp" "${ISSUE_LOG_FILE}"
}

# Get statistics
get_statistics() {
  ensure_issue_log
  jq '.statistics' "${ISSUE_LOG_FILE}"
}

# Main execution
case "${ACTION}" in
  log-issue)
    log_issue
    ;;
  log-solution)
    log_solution
    ;;
  search-solutions)
    search_solutions
    ;;
  get-statistics)
    get_statistics
    ;;
  *)
    echo "Error: Unknown action '${ACTION}'"
    echo "Valid actions: log-issue, log-solution, search-solutions, get-statistics"
    exit 1
    ;;
esac
