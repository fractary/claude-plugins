#!/usr/bin/env bash
# Validate JSON data against JSON Schema
# Usage: validate-data.sh {schema_path} {data_json}
# Returns: Validation errors (empty if valid)

set -euo pipefail

SCHEMA_PATH="${1:-}"
DATA_JSON="${2:-}"

# Validate inputs
if [[ -z "$SCHEMA_PATH" ]] || [[ -z "$DATA_JSON" ]]; then
  echo "ERROR: Missing required arguments" >&2
  echo "Usage: validate-data.sh {schema_path} {data_json}" >&2
  exit 1
fi

if [[ ! -f "$SCHEMA_PATH" ]]; then
  echo "ERROR: Schema file not found: $SCHEMA_PATH" >&2
  exit 1
fi

# Check if ajv-cli is available for JSON Schema validation
if command -v ajv >/dev/null 2>&1; then
  # Use ajv-cli for full JSON Schema Draft 7 validation
  echo "$DATA_JSON" | ajv validate -s "$SCHEMA_PATH" -d /dev/stdin 2>&1 || {
    echo "VALIDATION_FAILED" >&2
    exit 1
  }
  exit 0
fi

# Fallback: Basic validation using jq
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: Neither ajv nor jq available for validation" >&2
  echo "Install ajv-cli: npm install -g ajv-cli" >&2
  exit 1
fi

# Extract schema requirements
REQUIRED_FIELDS=$(jq -r '.required[]? // empty' "$SCHEMA_PATH")
ERRORS=()

# Parse data JSON
if ! echo "$DATA_JSON" | jq empty 2>/dev/null; then
  echo "ERROR: Invalid JSON data" >&2
  exit 1
fi

# Check required fields
for field in $REQUIRED_FIELDS; do
  if ! echo "$DATA_JSON" | jq -e ".$field" >/dev/null 2>&1; then
    ERRORS+=("Missing required field: $field")
  fi
done

# Check log_type const (if present in schema)
LOG_TYPE_CONST=$(jq -r '.properties.log_type.const // empty' "$SCHEMA_PATH")
if [[ -n "$LOG_TYPE_CONST" ]]; then
  ACTUAL_LOG_TYPE=$(echo "$DATA_JSON" | jq -r '.log_type // empty')
  if [[ "$ACTUAL_LOG_TYPE" != "$LOG_TYPE_CONST" ]]; then
    ERRORS+=("Invalid log_type: expected '$LOG_TYPE_CONST', got '$ACTUAL_LOG_TYPE'")
  fi
fi

# Report errors
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  printf "%s\n" "${ERRORS[@]}" >&2
  exit 1
fi

# Validation passed
exit 0
