#!/usr/bin/env bash
# Classify log type based on content and metadata
# Usage: classify-log.sh {content_file} {metadata_json}
# Returns: JSON with type scores

set -euo pipefail

CONTENT_FILE="${1:-}"
METADATA_JSON="${2:-{}}"

# Validate inputs
if [[ -z "$CONTENT_FILE" ]]; then
  echo "ERROR: content_file required" >&2
  exit 1
fi

if [[ ! -f "$CONTENT_FILE" ]]; then
  echo "ERROR: Content file not found: $CONTENT_FILE" >&2
  exit 1
fi

# Read content
CONTENT=$(cat "$CONTENT_FILE")

# Initialize scores
declare -A SCORES=(
  [session]=0
  [build]=0
  [deployment]=0
  [debug]=0
  [test]=0
  [audit]=0
  [operational]=0
  [changelog]=0
  [workflow]=0
  [_untyped]=20
)

# Helper: Check keywords (case-insensitive)
check_keywords() {
  local type=$1
  shift
  local keywords=("$@")
  local found=0

  for keyword in "${keywords[@]}"; do
    if echo "$CONTENT" | grep -qi "$keyword"; then
      ((found++))
    fi
  done

  echo $found
}

# Helper: Check command presence
check_command() {
  local cmd=$1
  if echo "$METADATA_JSON" | jq -e ".command | contains(\"$cmd\")" >/dev/null 2>&1; then
    echo 1
  else
    echo 0
  fi
}

# SESSION classification
SESSION_KEYWORDS=("session" "conversation" "claude" "user_prompt" "issue_number")
SESSION_SCORE=$(check_keywords session "${SESSION_KEYWORDS[@]}")
SCORES[session]=$((SESSION_SCORE * 10))

# Add bonus for UUID pattern (session_id)
if echo "$CONTENT" | grep -qE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'; then
  SCORES[session]=$((SCORES[session] + 15))
fi

# BUILD classification
BUILD_KEYWORDS=("build" "compile" "webpack" "maven" "gradle" "cargo" "npm.*build")
BUILD_SCORE=$(check_keywords build "${BUILD_KEYWORDS[@]}")
SCORES[build]=$((BUILD_SCORE * 10))

# Check for build commands
BUILD_COMMANDS=("npm" "cargo" "mvn" "gradle" "webpack" "make")
for cmd in "${BUILD_COMMANDS[@]}"; do
  if [[ $(check_command "$cmd") -eq 1 ]]; then
    SCORES[build]=$((SCORES[build] + 15))
    break
  fi
done

# Check for exit code (common in builds)
if echo "$METADATA_JSON" | jq -e '.exit_code' >/dev/null 2>&1; then
  SCORES[build]=$((SCORES[build] + 10))
fi

# DEPLOYMENT classification
DEPLOY_KEYWORDS=("deploy" "release" "production" "staging" "rollout" "environment")
DEPLOY_SCORE=$(check_keywords deployment "${DEPLOY_KEYWORDS[@]}")
SCORES[deployment]=$((DEPLOY_SCORE * 10))

# Check for environment field (strong indicator)
if echo "$METADATA_JSON" | jq -e '.environment' >/dev/null 2>&1; then
  SCORES[deployment]=$((SCORES[deployment] + 25))
fi

# Check for semantic version pattern
if echo "$CONTENT" | grep -qE 'v?[0-9]+\.[0-9]+\.[0-9]+'; then
  SCORES[deployment]=$((SCORES[deployment] + 10))
fi

# DEBUG classification
DEBUG_KEYWORDS=("debug" "trace" "error" "exception" "stack.*trace" "breakpoint")
DEBUG_SCORE=$(check_keywords debug "${DEBUG_KEYWORDS[@]}")
SCORES[debug]=$((DEBUG_SCORE * 10))

# Check for stack trace pattern
if echo "$CONTENT" | grep -qE 'at .+:[0-9]+:[0-9]+'; then
  SCORES[debug]=$((SCORES[debug] + 20))
fi

# TEST classification
TEST_KEYWORDS=("test" "spec" "suite" "assertion" "passed" "failed" "coverage")
TEST_SCORE=$(check_keywords test "${TEST_KEYWORDS[@]}")
SCORES[test]=$((TEST_SCORE * 10))

# Check for test frameworks
TEST_FRAMEWORKS=("pytest" "jest" "mocha" "rspec" "junit")
for framework in "${TEST_FRAMEWORKS[@]}"; do
  if echo "$CONTENT" | grep -qi "$framework"; then
    SCORES[test]=$((SCORES[test] + 20))
    break
  fi
done

# Check for test count pattern (e.g., "45 passed, 3 failed")
if echo "$CONTENT" | grep -qE '[0-9]+ (passed|failed)'; then
  SCORES[test]=$((SCORES[test] + 15))
fi

# AUDIT classification
AUDIT_KEYWORDS=("audit" "security" "compliance" "access" "permission" "unauthorized")
AUDIT_SCORE=$(check_keywords audit "${AUDIT_KEYWORDS[@]}")
SCORES[audit]=$((AUDIT_SCORE * 10))

# Check for user + action + resource pattern
HAS_USER=$(echo "$METADATA_JSON" | jq -e '.user' >/dev/null 2>&1 && echo 1 || echo 0)
HAS_ACTION=$(echo "$METADATA_JSON" | jq -e '.action' >/dev/null 2>&1 && echo 1 || echo 0)
HAS_RESOURCE=$(echo "$METADATA_JSON" | jq -e '.resource' >/dev/null 2>&1 && echo 1 || echo 0)
if [[ $HAS_USER -eq 1 ]] && [[ $HAS_ACTION -eq 1 ]] && [[ $HAS_RESOURCE -eq 1 ]]; then
  SCORES[audit]=$((SCORES[audit] + 30))
fi

# OPERATIONAL classification
OP_KEYWORDS=("maintenance" "backup" "restore" "migration" "sync" "cleanup" "cron")
OP_SCORE=$(check_keywords operational "${OP_KEYWORDS[@]}")
SCORES[operational]=$((OP_SCORE * 10))

# Check for operational commands
OP_COMMANDS=("rsync" "tar" "pg_dump" "mysqldump")
for cmd in "${OP_COMMANDS[@]}"; do
  if [[ $(check_command "$cmd") -eq 1 ]]; then
    SCORES[operational]=$((SCORES[operational] + 15))
    break
  fi
done

# CHANGELOG classification
CHANGELOG_KEYWORDS=("changelog" "release.*notes?" "version" "breaking.*change" "semver")
CHANGELOG_SCORE=$(check_keywords changelog "${CHANGELOG_KEYWORDS[@]}")
SCORES[changelog]=$((CHANGELOG_SCORE * 10))

# Check for semantic version pattern in metadata or content
if echo "$METADATA_JSON" | jq -e '.version' >/dev/null 2>&1; then
  SCORES[changelog]=$((SCORES[changelog] + 25))
elif echo "$CONTENT" | grep -qE 'v?[0-9]+\.[0-9]+\.[0-9]+'; then
  SCORES[changelog]=$((SCORES[changelog] + 15))
fi

# Check for Keep a Changelog format sections
CHANGELOG_SECTIONS=("Added" "Changed" "Deprecated" "Removed" "Fixed" "Security")
CHANGELOG_SECTION_COUNT=0
for section in "${CHANGELOG_SECTIONS[@]}"; do
  if echo "$CONTENT" | grep -qE "^##.*$section"; then
    ((CHANGELOG_SECTION_COUNT++))
  fi
done
if [[ $CHANGELOG_SECTION_COUNT -ge 2 ]]; then
  SCORES[changelog]=$((SCORES[changelog] + 30))
elif [[ $CHANGELOG_SECTION_COUNT -eq 1 ]]; then
  SCORES[changelog]=$((SCORES[changelog] + 15))
fi

# Check for work items/PR references
if echo "$CONTENT" | grep -qE '#[0-9]+|PR.*#[0-9]+|issue.*#[0-9]+'; then
  SCORES[changelog]=$((SCORES[changelog] + 10))
fi

# WORKFLOW classification
WORKFLOW_KEYWORDS=("workflow" "pipeline" "faber" "operation" "phase" "lineage")
WORKFLOW_SCORE=$(check_keywords workflow "${WORKFLOW_KEYWORDS[@]}")
SCORES[workflow]=$((WORKFLOW_SCORE * 10))

# Check for FABER phases
FABER_PHASES=("Frame" "Architect" "Build" "Evaluate" "Release")
FABER_PHASE_COUNT=0
for phase in "${FABER_PHASES[@]}"; do
  if echo "$CONTENT" | grep -qi "$phase"; then
    ((FABER_PHASE_COUNT++))
  fi
done
if [[ $FABER_PHASE_COUNT -ge 3 ]]; then
  SCORES[workflow]=$((SCORES[workflow] + 30))
elif [[ $FABER_PHASE_COUNT -ge 1 ]]; then
  SCORES[workflow]=$((SCORES[workflow] + 15))
fi

# Check for ETL phases
ETL_PHASES=("Extract" "Transform" "Load")
ETL_PHASE_COUNT=0
for phase in "${ETL_PHASES[@]}"; do
  if echo "$CONTENT" | grep -qi "$phase"; then
    ((ETL_PHASE_COUNT++))
  fi
done
if [[ $ETL_PHASE_COUNT -ge 2 ]]; then
  SCORES[workflow]=$((SCORES[workflow] + 25))
fi

# Check for workflow metadata
if echo "$METADATA_JSON" | jq -e '.workflow_id' >/dev/null 2>&1; then
  SCORES[workflow]=$((SCORES[workflow] + 30))
fi

if echo "$METADATA_JSON" | jq -e '.phase' >/dev/null 2>&1; then
  SCORES[workflow]=$((SCORES[workflow] + 20))
fi

# Check for operations array or timeline
if echo "$CONTENT" | grep -qE 'operation|Operations Timeline'; then
  SCORES[workflow]=$((SCORES[workflow] + 15))
fi

# Check for workflow action verbs
WORKFLOW_ACTIONS=("processed" "transformed" "validated" "executed" "completed")
WORKFLOW_ACTION_COUNT=0
for action in "${WORKFLOW_ACTIONS[@]}"; do
  if echo "$CONTENT" | grep -qi "$action"; then
    ((WORKFLOW_ACTION_COUNT++))
  fi
done
if [[ $WORKFLOW_ACTION_COUNT -ge 2 ]]; then
  SCORES[workflow]=$((SCORES[workflow] + 10))
fi

# Check for lineage tracking keywords
if echo "$CONTENT" | grep -qE 'upstream|downstream|dependency|artifact'; then
  SCORES[workflow]=$((SCORES[workflow] + 10))
fi

# Cap scores at 100
for type in "${!SCORES[@]}"; do
  if [[ ${SCORES[$type]} -gt 100 ]]; then
    SCORES[$type]=100
  fi
done

# Output JSON
cat <<EOF
{
  "session": ${SCORES[session]},
  "build": ${SCORES[build]},
  "deployment": ${SCORES[deployment]},
  "debug": ${SCORES[debug]},
  "test": ${SCORES[test]},
  "audit": ${SCORES[audit]},
  "operational": ${SCORES[operational]},
  "changelog": ${SCORES[changelog]},
  "workflow": ${SCORES[workflow]},
  "_untyped": ${SCORES[_untyped]}
}
EOF
