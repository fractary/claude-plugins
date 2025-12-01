#!/usr/bin/env bash
# Schema Loader - Load and parse doc type schemas
# Usage: schema-loader.sh <type>
# Example: schema-loader.sh adr
# Returns: JSON schema for the specified doc type

set -euo pipefail

# Get plugin root (assuming we're in plugins/docs/skills/_shared/lib/)
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SCHEMAS_DIR="${PLUGIN_ROOT}/schemas"

# Function to load schema
load_schema() {
    local doc_type="$1"
    local schema_file="${SCHEMAS_DIR}/${doc_type}.schema.json"

    if [[ ! -f "$schema_file" ]]; then
        echo "{\"error\": \"Schema not found for type: ${doc_type}\", \"schema_file\": \"${schema_file}\"}" >&2
        return 1
    fi

    # Validate JSON
    if ! jq empty "$schema_file" 2>/dev/null; then
        echo "{\"error\": \"Invalid JSON in schema: ${schema_file}\"}" >&2
        return 1
    fi

    # Return schema
    cat "$schema_file"
}

# Main execution
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <doc_type>" >&2
        echo "Example: $0 adr" >&2
        return 1
    fi

    local doc_type="$1"
    load_schema "$doc_type"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
