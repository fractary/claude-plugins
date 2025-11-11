#!/usr/bin/env bash
#
# generate-config.sh - Generate fractary-docs configuration from discovery
#
# Usage: generate-config.sh <discovery_docs> <discovery_structure> <discovery_frontmatter> <discovery_quality> <output_json>
#
# Output: Complete fractary-docs configuration

set -euo pipefail

DISCOVERY_DOCS="${1:-discovery-docs.json}"
DISCOVERY_STRUCTURE="${2:-discovery-structure.json}"
DISCOVERY_FRONTMATTER="${3:-discovery-frontmatter.json}"
DISCOVERY_QUALITY="${4:-discovery-quality.json}"
OUTPUT_JSON="${5:-docs-config.json}"

# Load discovery data
docs_dir=$(jq -r '.primary_docs_dir' "$DISCOVERY_STRUCTURE" 2>/dev/null || echo "docs")
[ "$docs_dir" = "null" ] && docs_dir="docs"
[ "$docs_dir" = "." ] && docs_dir="docs"

adr_path=$(jq -r '.common_paths.adrs' "$DISCOVERY_STRUCTURE" 2>/dev/null || echo "$docs_dir/architecture/adrs")
[ "$adr_path" = "null" ] || [ "$adr_path" = "not found" ] && adr_path="$docs_dir/architecture/adrs"

design_path=$(jq -r '.common_paths.designs' "$DISCOVERY_STRUCTURE" 2>/dev/null || echo "$docs_dir/architecture/designs")
[ "$design_path" = "null" ] || [ "$design_path" = "not found" ] && design_path="$docs_dir/architecture/designs"

runbook_path=$(jq -r '.common_paths.runbooks' "$DISCOVERY_STRUCTURE" 2>/dev/null || echo "$docs_dir/operations/runbooks")
[ "$runbook_path" = "null" ] || [ "$runbook_path" = "not found" ] && runbook_path="$docs_dir/operations/runbooks"

api_path=$(jq -r '.common_paths.api_docs' "$DISCOVERY_STRUCTURE" 2>/dev/null || echo "$docs_dir/api")
[ "$api_path" = "null" ] || [ "$api_path" = "not found" ] && api_path="$docs_dir/api"

frontmatter_format=$(jq -r '.format.primary' "$DISCOVERY_FRONTMATTER" 2>/dev/null || echo "yaml")
[ "$frontmatter_format" = "null" ] || [ "$frontmatter_format" = "none" ] && frontmatter_format="yaml"

codex_ready=$(jq -r '.codex_integration.ready' "$DISCOVERY_FRONTMATTER" 2>/dev/null || echo "false")

# Generate configuration using jq for safe JSON construction
jq -n \
  --arg schema_version "1.0" \
  --arg docs_dir "$docs_dir" \
  --arg adr_path "$adr_path" \
  --arg design_path "$design_path" \
  --arg runbook_path "$runbook_path" \
  --arg api_path "$api_path" \
  --arg guides_path "$docs_dir/guides" \
  --arg testing_path "$docs_dir/testing" \
  --arg deployments_path "$docs_dir/deployments" \
  '{
    schema_version: $schema_version,
    hooks: {
      pre_generate: null,
      post_generate: null,
      pre_validate: null,
      post_validate: null,
      pre_update: null,
      post_update: null
    },
    output_paths: {
      documentation: $docs_dir,
      adrs: $adr_path,
      designs: $design_path,
      runbooks: $runbook_path,
      api_docs: $api_path,
      guides: $guides_path,
      testing: $testing_path,
      deployments: $deployments_path
    },
    templates: {
      custom_template_dir: null,
      use_project_templates: true
    },
    frontmatter: {
      always_include: true,
      codex_sync: true,
      default_fields: {
        author: "Claude Code",
        generated: true
      }
    },
    validation: {
      lint_on_generate: true,
      check_links_on_generate: false,
      custom_rules_script: null,
      project_standards_doc: null,
      required_sections: {
        adr: ["Status", "Context", "Decision", "Consequences"],
        design: ["Overview", "Architecture", "Implementation"],
        runbook: ["Purpose", "Prerequisites", "Steps", "Troubleshooting"],
        "api-spec": ["Overview", "Endpoints", "Authentication"],
        "test-report": ["Summary", "Test Cases", "Results"],
        deployment: ["Overview", "Infrastructure", "Deployment Steps"]
      },
      status_values: {
        adr: ["proposed", "accepted", "deprecated", "superseded"]
      }
    },
    linking: {
      auto_update_index: true,
      check_broken_links: true,
      generate_graph: true
    }
  }' > "$OUTPUT_JSON"

# Validate JSON is well-formed
if ! jq empty "$OUTPUT_JSON" 2>/dev/null; then
    echo "Error: Generated invalid JSON" >&2
    exit 1
fi

echo "Configuration generated: $OUTPUT_JSON"
