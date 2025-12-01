#!/bin/bash
# discover-custom-agents.sh - Discover and analyze custom infrastructure agents and scripts
#
# Identifies custom agents, skills, and scripts used for infrastructure management,
# analyzes their capabilities, and maps them to faber-cloud features

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
Usage: discover-custom-agents.sh <project_root> [output_file]

Discover and analyze custom infrastructure management agents and scripts.

Arguments:
  project_root  Root directory of the project to analyze
  output_file   Output JSON file (default: discovery-report-custom-agents.json)

Discovery Includes:
  - Custom agent files (.claude/, .fractary/, etc.)
  - Custom skill directories and scripts
  - Script purposes (deploy, audit, validate, etc.)
  - Version control status (committed vs local)
  - Dependencies and requirements
  - Capability mapping to faber-cloud features

Exit Codes:
  0 - Discovery completed successfully
  1 - Error during discovery
  2 - Invalid arguments

Examples:
  discover-custom-agents.sh /path/to/project
  discover-custom-agents.sh /path/to/project custom-agents.json
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

# Function: Find custom agent directories
find_agent_directories() {
  local project_root="$1"

  log_info "Searching for custom agent directories..."

  local dirs=()

  # Check common locations
  [ -d "$project_root/.claude" ] && dirs+=("$project_root/.claude")
  [ -d "$project_root/.fractary" ] && dirs+=("$project_root/.fractary")
  [ -d "$project_root/.agents" ] && dirs+=("$project_root/.agents")
  [ -d "$project_root/agents" ] && dirs+=("$project_root/agents")
  [ -d "$project_root/skills" ] && dirs+=("$project_root/skills")
  [ -d "$project_root/.claude/agents" ] && dirs+=("$project_root/.claude/agents")
  [ -d "$project_root/.claude/skills" ] && dirs+=("$project_root/.claude/skills")

  # Convert to JSON array
  printf '%s\n' "${dirs[@]}" | jq -R . | jq -s . || echo "[]"
}

# Function: Analyze file for purpose
analyze_file_purpose() {
  local file="$1"

  # Read first 50 lines for analysis
  local content=$(head -50 "$file" 2>/dev/null || echo "")

  local purposes=()

  # Check for infrastructure keywords
  if echo "$content" | grep -qi "terraform\|tf\|infrastructure\|iac"; then
    purposes+=("infrastructure")
  fi

  # Check for deployment keywords
  if echo "$content" | grep -qi "deploy\|apply\|provision"; then
    purposes+=("deploy")
  fi

  # Check for audit keywords
  if echo "$content" | grep -qi "audit\|check\|verify\|inspect"; then
    purposes+=("audit")
  fi

  # Check for validation keywords
  if echo "$content" | grep -qi "validate\|test\|lint"; then
    purposes+=("validate")
  fi

  # Check for debugging keywords
  if echo "$content" | grep -qi "debug\|troubleshoot\|diagnose\|fix"; then
    purposes+=("debug")
  fi

  # Check for destroy/teardown keywords
  if echo "$content" | grep -qi "destroy\|teardown\|delete\|remove"; then
    purposes+=("teardown")
  fi

  # Check for configuration keywords
  if echo "$content" | grep -qi "configure\|config\|setup\|init"; then
    purposes+=("configure")
  fi

  # Check for monitoring keywords
  if echo "$content" | grep -qi "monitor\|watch\|observe\|alert"; then
    purposes+=("monitor")
  fi

  # Convert to JSON array
  if [ ${#purposes[@]} -eq 0 ]; then
    echo '["unknown"]'
  else
    printf '%s\n' "${purposes[@]}" | jq -R . | jq -s . || echo '["unknown"]'
  fi
}

# Function: Map purposes to faber-cloud features
map_to_faber_cloud() {
  local purposes="$1"

  local mappings="[]"

  # Map each purpose to faber-cloud feature
  while IFS= read -r purpose; do
    [ -z "$purpose" ] && continue

    local feature=""
    local hook_type=""

    case "$purpose" in
      infrastructure)
        feature="infra-architect, infra-engineer"
        hook_type=""
        ;;
      deploy)
        feature="infra-deployer"
        hook_type="pre-deploy, post-deploy"
        ;;
      audit)
        feature="infra-auditor"
        hook_type=""
        ;;
      validate)
        feature="infra-validator"
        hook_type="pre-plan, post-plan"
        ;;
      debug)
        feature="infra-debugger"
        hook_type=""
        ;;
      teardown)
        feature="infra-teardown"
        hook_type="pre-destroy, post-destroy"
        ;;
      configure)
        feature="init command"
        hook_type=""
        ;;
      monitor)
        feature="Custom (not in faber-cloud)"
        hook_type=""
        ;;
      *)
        feature="Unknown"
        hook_type=""
        ;;
    esac

    local mapping=$(jq -n \
      --arg purpose "$purpose" \
      --arg feature "$feature" \
      --arg hook "$hook_type" \
      '{
        purpose: $purpose,
        faber_cloud_feature: $feature,
        hook_alternative: $hook
      }')

    mappings=$(echo "$mappings" | jq --argjson entry "$mapping" '. + [$entry]')

  done <<< "$(echo "$purposes" | jq -r '.[]')"

  echo "$mappings"
}

# Function: Check if file is in version control
is_version_controlled() {
  local file="$1"
  local project_root="$2"

  cd "$project_root" 2>/dev/null || return 1

  if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null 2>&1; then
    # Check if file is tracked by git
    if git ls-files --error-unmatch "$file" &> /dev/null; then
      echo "true"
      return 0
    fi
  fi

  echo "false"
}

# Function: Extract dependencies from script
extract_dependencies() {
  local file="$1"

  local deps=()

  # Check for common dependencies
  if grep -q "terraform " "$file" 2>/dev/null; then
    deps+=("terraform")
  fi

  if grep -q "aws " "$file" 2>/dev/null; then
    deps+=("aws-cli")
  fi

  if grep -q "jq " "$file" 2>/dev/null; then
    deps+=("jq")
  fi

  if grep -q "docker " "$file" 2>/dev/null; then
    deps+=("docker")
  fi

  if grep -q "npm " "$file" 2>/dev/null; then
    deps+=("npm")
  fi

  if grep -q "python" "$file" 2>/dev/null; then
    deps+=("python")
  fi

  # Convert to JSON array
  if [ ${#deps[@]} -eq 0 ]; then
    echo '[]'
  else
    printf '%s\n' "${deps[@]}" | sort -u | jq -R . | jq -s . || echo '[]'
  fi
}

# Function: Analyze single file
analyze_file() {
  local file="$1"
  local project_root="$2"

  local basename=$(basename "$file")
  local relative_path=$(realpath --relative-to="$project_root" "$file" 2>/dev/null || echo "$file")

  # Analyze purpose
  local purposes=$(analyze_file_purpose "$file")

  # Map to faber-cloud
  local mappings=$(map_to_faber_cloud "$purposes")

  # Check version control
  local is_tracked=$(is_version_controlled "$file" "$project_root")

  # Extract dependencies
  local dependencies=$(extract_dependencies "$file")

  # Get file size
  local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")

  # Build entry
  jq -n \
    --arg path "$relative_path" \
    --arg name "$basename" \
    --argjson purposes "$purposes" \
    --argjson mappings "$mappings" \
    --arg tracked "$is_tracked" \
    --argjson deps "$dependencies" \
    --arg size "$size" \
    '{
      path: $path,
      name: $name,
      purposes: $purposes,
      faber_cloud_mappings: $mappings,
      version_controlled: ($tracked == "true"),
      dependencies: $deps,
      size_bytes: ($size | tonumber)
    }'
}

# Main execution
main() {
  # Validate arguments
  if [ $# -lt 1 ]; then
    usage
  fi

  local project_root="$1"
  local output_file="${2:-discovery-report-custom-agents.json}"

  # Validate project root exists
  if [ ! -d "$project_root" ]; then
    log_error "Project root not found: $project_root"
    exit 2
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_info "Custom Agents & Scripts Discovery"
  log_info "Project Root: $project_root"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Find agent directories
  local agent_dirs=$(find_agent_directories "$project_root")
  local dir_count=$(echo "$agent_dirs" | jq 'length')

  if [ "$dir_count" -eq 0 ]; then
    log_info "No custom agent directories found"
    echo '{"discovered": false, "reason": "no_custom_agents"}' > "$output_file"
    exit 0
  fi

  log_success "Found $dir_count custom agent director(y/ies)"
  echo ""

  # Find all agent/skill files
  local all_files=()

  while IFS= read -r dir; do
    [ -z "$dir" ] && continue

    log_info "Scanning: $dir"

    # Find markdown files (agent/skill definitions)
    while IFS= read -r file; do
      [ -z "$file" ] && continue
      all_files+=("$file")
    done < <(find "$dir" -type f \( -name "*.md" -o -name "*.sh" \) 2>/dev/null || true)

  done <<< "$(echo "$agent_dirs" | jq -r '.[]')"

  local file_count=${#all_files[@]}

  if [ $file_count -eq 0 ]; then
    log_info "No agent or script files found"
    echo '{"discovered": false, "reason": "no_files_found"}' > "$output_file"
    exit 0
  fi

  log_success "Found $file_count file(s) to analyze"
  echo ""

  # Analyze each file
  local analyzed_files="[]"

  for file in "${all_files[@]}"; do
    log_info "Analyzing: $(basename "$file")"

    local analysis=$(analyze_file "$file" "$project_root")
    analyzed_files=$(echo "$analyzed_files" | jq --argjson entry "$analysis" '. + [$entry]')
  done

  echo ""

  # Generate summary
  local total_tracked=$(echo "$analyzed_files" | jq '[.[] | select(.version_controlled == true)] | length')
  local total_untracked=$(echo "$analyzed_files" | jq '[.[] | select(.version_controlled == false)] | length')

  # Extract unique purposes
  local all_purposes=$(echo "$analyzed_files" | jq -r '[.[].purposes[]] | unique')

  # Count files by purpose
  local purpose_counts="{}"
  while IFS= read -r purpose; do
    [ -z "$purpose" ] && continue
    local count=$(echo "$analyzed_files" | jq --arg p "$purpose" '[.[] | select(.purposes[] == $p)] | length')
    purpose_counts=$(echo "$purpose_counts" | jq --arg p "$purpose" --arg c "$count" '. + {($p): ($c | tonumber)}')
  done <<< "$(echo "$all_purposes" | jq -r '.[]')"

  # Generate recommendations
  local recommendations="[]"

  # Recommend using faber-cloud deployer
  if echo "$all_purposes" | jq -e 'index("deploy")' > /dev/null; then
    recommendations=$(echo "$recommendations" | jq '. + ["Consider using infra-deployer skill instead of custom deploy scripts"]')
  fi

  # Recommend using hooks
  if echo "$all_purposes" | jq -e 'index("validate")' > /dev/null; then
    recommendations=$(echo "$recommendations" | jq '. + ["Custom validation scripts can be integrated as pre-plan hooks"]')
  fi

  # Recommend migration
  if [ $total_untracked -gt 0 ]; then
    recommendations=$(echo "$recommendations" | jq '. + ["Some scripts are not version controlled - consider committing before migration"]')
  fi

  # Generate final report
  local report=$(jq -n \
    --argjson dirs "$agent_dirs" \
    --argjson files "$analyzed_files" \
    --argjson purposes "$all_purposes" \
    --argjson purpose_counts "$purpose_counts" \
    --argjson recommendations "$recommendations" \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{
      discovered: true,
      timestamp: $timestamp,
      agent_directories: $dirs,
      files: $files,
      summary: {
        total_directories: ($dirs | length),
        total_files: ($files | length),
        version_controlled: ([$files[] | select(.version_controlled == true)] | length),
        not_version_controlled: ([$files[] | select(.version_controlled == false)] | length),
        purposes_detected: $purposes,
        files_by_purpose: $purpose_counts
      },
      recommendations: $recommendations
    }')

  # Write report
  echo "$report" | jq . > "$output_file"

  echo "═══════════════════════════════════════════════════════════"
  log_success "Discovery complete"
  log_info "Analyzed $file_count file(s)"
  log_info "Version controlled: $total_tracked, Local only: $total_untracked"
  log_info "Report saved to: $output_file"
  echo "═══════════════════════════════════════════════════════════"

  exit 0
}

# Run main function
main "$@"
