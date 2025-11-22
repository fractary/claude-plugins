#!/usr/bin/env bash
# Config Resolver - Load and merge configuration
# Merges: schema defaults → global config → project config
# Usage: config-resolver.sh <doc_type> [project_root]
# Example: config-resolver.sh adr /path/to/project
# Returns: Merged JSON configuration

set -euo pipefail

# Get plugin root
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SCHEMA_LOADER="${PLUGIN_ROOT}/skills/_shared/lib/schema-loader.sh"

# Config locations
GLOBAL_CONFIG="${HOME}/.config/fractary/docs/config.json"
DEFAULT_CONFIG="${PLUGIN_ROOT}/config/config.example.json"

# Function to load project config
load_project_config() {
    local project_root="${1:-.}"
    local project_config="${project_root}/.fractary/plugins/docs/config.json"

    if [[ -f "$project_config" ]]; then
        cat "$project_config"
    else
        echo "{}"
    fi
}

# Function to load global config
load_global_config() {
    if [[ -f "$GLOBAL_CONFIG" ]]; then
        cat "$GLOBAL_CONFIG"
    else
        echo "{}"
    fi
}

# Function to load default config
load_default_config() {
    if [[ -f "$DEFAULT_CONFIG" ]]; then
        cat "$DEFAULT_CONFIG"
    else
        echo "{}"
    fi
}

# Function to merge configs with doc type schema
merge_configs() {
    local doc_type="$1"
    local schema="$2"
    local default_config="$3"
    local global_config="$4"
    local project_config="$5"

    # Use jq to merge configs (later configs override earlier ones)
    jq -n \
        --argjson schema "$schema" \
        --argjson defaults "$default_config" \
        --argjson global "$global_config" \
        --argjson project "$project_config" \
        --arg type "$doc_type" '
        # Extract schema defaults
        $schema as $s |

        # Extract doc_type specific config from each level
        ($defaults.doc_types[$type] // {}) as $default_doc_config |
        ($global.doc_types[$type] // {}) as $global_doc_config |
        ($project.doc_types[$type] // {}) as $project_doc_config |

        # Merge schema with configs (project overrides global overrides defaults)
        $s * {
            "config_source": "merged",
            "enabled": ($project_doc_config.enabled // $global_doc_config.enabled // $default_doc_config.enabled // true),
            "storage": (
                $s.storage *
                ($default_doc_config.storage // {}) *
                ($global_doc_config.storage // {}) *
                ($project_doc_config.storage // {})
            ),
            "path": (
                $project_doc_config.path //
                $global_doc_config.path //
                $default_doc_config.path //
                $s.storage.default_path
            ),
            "frontmatter": (
                $defaults.frontmatter *
                $global.frontmatter *
                $project.frontmatter
            ),
            "validation": (
                $defaults.validation *
                $global.validation *
                $project.validation
            )
        }
    '
}

# Main execution
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <doc_type> [project_root]" >&2
        echo "Example: $0 adr /path/to/project" >&2
        return 1
    fi

    local doc_type="$1"
    local project_root="${2:-.}"

    # Load schema
    local schema
    if ! schema=$("$SCHEMA_LOADER" "$doc_type"); then
        echo "{\"error\": \"Failed to load schema for type: ${doc_type}\"}" >&2
        return 1
    fi

    # Load configs
    local default_config
    default_config=$(load_default_config)

    local global_config
    global_config=$(load_global_config)

    local project_config
    project_config=$(load_project_config "$project_root")

    # Merge and return
    merge_configs "$doc_type" "$schema" "$default_config" "$global_config" "$project_config"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
