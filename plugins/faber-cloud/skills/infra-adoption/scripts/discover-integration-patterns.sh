#!/bin/bash
# discover-integration-patterns.sh - Analyze how to best integrate faber-cloud
#
# This script analyzes existing infrastructure code and deployment processes to recommend:
# 1. Which custom logic should become skill-based hooks
# 2. Which commands should delegate to faber-cloud agents
# 3. Project-specific documentation/standards to pass to agents
#
# Usage: discover-integration-patterns.sh <project_root> <output_json>

set -euo pipefail

PROJECT_ROOT="${1:-.}"
OUTPUT_FILE="${2:-./integration-patterns.json}"

echo "Analyzing integration patterns for: $PROJECT_ROOT"

# Initialize results
HOOK_OPPORTUNITIES=()
COMMAND_DELEGATIONS=()
PROJECT_DOCS=()
CUSTOM_VALIDATION=()

# Function: Find custom validation scripts
find_validation_scripts() {
  local validation_patterns=(
    "scripts/*validate*"
    "scripts/*check*"
    "scripts/*verify*"
    ".github/workflows/*validate*"
    "hooks/*"
  )

  for pattern in "${validation_patterns[@]}"; do
    while IFS= read -r -d '' file; do
      if [ -f "$file" ]; then
        local purpose=$(head -5 "$file" | grep -E '#.*validate|#.*check|#.*verify' | head -1 | sed 's/^#\s*//' || echo "Unknown")
        HOOK_OPPORTUNITIES+=("{\"file\": \"$file\", \"purpose\": \"$purpose\", \"type\": \"validation\"}")
      fi
    done < <(find "$PROJECT_ROOT" -path "$PROJECT_ROOT/$pattern" -print0 2>/dev/null || true)
  done
}

# Function: Find build/compilation scripts
find_build_scripts() {
  local build_patterns=(
    "scripts/*build*"
    "scripts/*compile*"
    "scripts/*package*"
    "Makefile"
    "package.json"
  )

  for pattern in "${build_patterns[@]}"; do
    while IFS= read -r -d '' file; do
      if [ -f "$file" ]; then
        local purpose="Build/compilation step"
        if [[ "$file" == *"lambda"* ]]; then
          purpose="Lambda function build"
        elif [[ "$file" == *"docker"* ]]; then
          purpose="Docker image build"
        fi
        HOOK_OPPORTUNITIES+=("{\"file\": \"$file\", \"purpose\": \"$purpose\", \"type\": \"build\"}")
      fi
    done < <(find "$PROJECT_ROOT" -path "$PROJECT_ROOT/$pattern" -print0 2>/dev/null || true)
  done
}

# Function: Find deployment commands
find_deployment_commands() {
  local command_patterns=(
    ".claude/commands/*deploy*"
    ".claude/commands/*infra*"
    "scripts/deploy*"
    "bin/deploy*"
  )

  for pattern in "${command_patterns[@]}"; do
    while IFS= read -r -d '' file; do
      if [ -f "$file" ]; then
        # Check if it's a custom agent or just a wrapper
        local uses_agent=$(grep -c "agent" "$file" 2>/dev/null || echo "0")
        local uses_terraform=$(grep -c "terraform" "$file" 2>/dev/null || echo "0")

        local recommendation="lightweight-command"
        if [ "$uses_agent" -gt 0 ]; then
          recommendation="already-delegating"
        fi

        COMMAND_DELEGATIONS+=("{\"file\": \"$file\", \"terraform_calls\": $uses_terraform, \"recommendation\": \"$recommendation\"}")
      fi
    done < <(find "$PROJECT_ROOT" -path "$PROJECT_ROOT/$pattern" -print0 2>/dev/null || true)
  done
}

# Function: Find project-specific documentation
find_project_docs() {
  local doc_patterns=(
    "docs/*architecture*"
    "docs/*standards*"
    "docs/*requirements*"
    "ARCHITECTURE.md"
    "STANDARDS.md"
    "README.md"
    ".claude/CLAUDE.md"
  )

  for pattern in "${doc_patterns[@]}"; do
    while IFS= read -r -d '' file; do
      if [ -f "$file" ]; then
        local size=$(wc -l < "$file")
        local has_infra=$(grep -ic "infrastructure\|terraform\|aws" "$file" 2>/dev/null || echo "0")

        if [ "$has_infra" -gt 5 ]; then
          PROJECT_DOCS+=("{\"file\": \"$file\", \"lines\": $size, \"relevance\": \"high\"}")
        elif [ "$has_infra" -gt 0 ]; then
          PROJECT_DOCS+=("{\"file\": \"$file\", \"lines\": $size, \"relevance\": \"medium\"}")
        fi
      fi
    done < <(find "$PROJECT_ROOT" -path "$PROJECT_ROOT/$pattern" -print0 2>/dev/null || true)
  done
}

# Function: Analyze custom validation needs
analyze_validation_needs() {
  # Look for data validation patterns
  if [ -d "$PROJECT_ROOT/data" ] || [ -d "$PROJECT_ROOT/datasets" ]; then
    CUSTOM_VALIDATION+=("{\"type\": \"dataset\", \"pattern\": \"data directory found\", \"skill_name\": \"dataset-validator\"}")
  fi

  # Look for API validation
  if grep -rq "swagger\|openapi" "$PROJECT_ROOT" 2>/dev/null; then
    CUSTOM_VALIDATION+=("{\"type\": \"api-schema\", \"pattern\": \"API specs found\", \"skill_name\": \"api-validator\"}")
  fi

  # Look for database migrations
  if [ -d "$PROJECT_ROOT/migrations" ] || grep -rq "alembic\|flyway\|liquibase" "$PROJECT_ROOT" 2>/dev/null; then
    CUSTOM_VALIDATION+=("{\"type\": \"database\", \"pattern\": \"migration files found\", \"skill_name\": \"db-migration-validator\"}")
  fi

  # Look for security scanning
  if grep -rq "checkov\|tfsec\|terrascan" "$PROJECT_ROOT" 2>/dev/null; then
    CUSTOM_VALIDATION+=("{\"type\": \"security\", \"pattern\": \"security tools found\", \"skill_name\": \"security-scanner\"}")
  fi
}

# Execute discovery
echo "  → Finding validation scripts..."
find_validation_scripts

echo "  → Finding build scripts..."
find_build_scripts

echo "  → Finding deployment commands..."
find_deployment_commands

echo "  → Finding project documentation..."
find_project_docs

echo "  → Analyzing validation needs..."
analyze_validation_needs

# Build JSON output
cat > "$OUTPUT_FILE" <<EOF
{
  "analysis_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "project_root": "$PROJECT_ROOT",

  "hook_opportunities": {
    "count": ${#HOOK_OPPORTUNITIES[@]},
    "recommendations": [
      $(IFS=,; echo "${HOOK_OPPORTUNITIES[*]}")
    ]
  },

  "command_delegations": {
    "count": ${#COMMAND_DELEGATIONS[@]},
    "recommendations": [
      $(IFS=,; echo "${COMMAND_DELEGATIONS[*]}")
    ]
  },

  "project_documentation": {
    "count": ${#PROJECT_DOCS[@]},
    "files": [
      $(IFS=,; echo "${PROJECT_DOCS[*]}")
    ]
  },

  "custom_validation_needs": {
    "count": ${#CUSTOM_VALIDATION[@]},
    "patterns": [
      $(IFS=,; echo "${CUSTOM_VALIDATION[*]}")
    ]
  },

  "integration_strategy": {
    "skill_hooks": {
      "recommended": $([ ${#HOOK_OPPORTUNITIES[@]} -gt 0 ] && echo "true" || echo "false"),
      "count": ${#HOOK_OPPORTUNITIES[@]},
      "priority": "high"
    },
    "lightweight_commands": {
      "recommended": $([ ${#COMMAND_DELEGATIONS[@]} -gt 0 ] && echo "true" || echo "false"),
      "count": ${#COMMAND_DELEGATIONS[@]},
      "priority": "high"
    },
    "project_context": {
      "available": $([ ${#PROJECT_DOCS[@]} -gt 0 ] && echo "true" || echo "false"),
      "files_count": ${#PROJECT_DOCS[@]},
      "priority": "medium"
    }
  }
}
EOF

# Summary
echo ""
echo "Integration Pattern Analysis Complete"
echo "  Hook opportunities found: ${#HOOK_OPPORTUNITIES[@]}"
echo "  Commands to delegate: ${#COMMAND_DELEGATIONS[@]}"
echo "  Project docs found: ${#PROJECT_DOCS[@]}"
echo "  Custom validation needs: ${#CUSTOM_VALIDATION[@]}"
echo ""
echo "Results: $OUTPUT_FILE"

exit 0
