#!/bin/bash
# report-generator.sh - Generate and store audit reports
# Usage: source report-generator.sh

set -euo pipefail

# Source configuration loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_COMMON_DIR="${SCRIPT_DIR}/../../cloud-common/scripts"
source "${CLOUD_COMMON_DIR}/config-loader.sh"

# Report configuration
export AUDIT_BASE_DIR=""
export AUDIT_ENV_DIR=""
export AUDIT_REPORT_FILE=""
export AUDIT_REPORT_JSON=""
export AUDIT_REPORT_MD=""
export AUDIT_TIMESTAMP=""
export AUDIT_START_TIME=""

# Initialize audit report directories and filenames
# Usage: init_audit_report <environment> <check_type>
init_audit_report() {
    local env="${1:-test}"
    local check_type="${2:-config-valid}"

    # Load configuration
    load_config "$env"

    # Create timestamp
    export AUDIT_TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    export AUDIT_START_TIME=$(date +%s)

    # Define paths
    export AUDIT_BASE_DIR="${DEVOPS_PROJECT_ROOT}/.fractary/plugins/faber-cloud/audits"
    export AUDIT_ENV_DIR="${AUDIT_BASE_DIR}/${env}"
    export AUDIT_REPORT_FILE="${AUDIT_ENV_DIR}/${AUDIT_TIMESTAMP}-${check_type}"
    export AUDIT_REPORT_JSON="${AUDIT_REPORT_FILE}.json"
    export AUDIT_REPORT_MD="${AUDIT_REPORT_FILE}.md"

    # Create directories
    mkdir -p "$AUDIT_ENV_DIR"

    log_info "Initializing audit report: ${check_type} for ${env}"
    log_info "Report location: ${AUDIT_REPORT_FILE}"

    return 0
}

# Generate audit report header (Markdown)
# Usage: generate_report_header <check_type> <env>
generate_report_header() {
    local check_type="$1"
    local env="$2"
    local timestamp_iso=$(date -Iseconds)

    cat > "$AUDIT_REPORT_MD" <<EOF
# Audit Report: ${env^^} Environment

**Check Type:** ${check_type}
**Timestamp:** ${timestamp_iso}
**Project:** ${DEVOPS_PROJECT_NAME}-${DEVOPS_PROJECT_SUBSYSTEM}

---

EOF
}

# Initialize JSON report structure
# Usage: init_json_report <check_type> <env>
init_json_report() {
    local check_type="$1"
    local env="$2"
    local timestamp_iso=$(date -Iseconds)

    cat > "$AUDIT_REPORT_JSON" <<EOF
{
  "audit": {
    "check_type": "${check_type}",
    "environment": "${env}",
    "timestamp": "${timestamp_iso}",
    "project": "${DEVOPS_PROJECT_NAME}-${DEVOPS_PROJECT_SUBSYSTEM}",
    "status": "running"
  },
  "summary": {
    "passing": 0,
    "warnings": 0,
    "failures": 0
  },
  "checks": [],
  "metrics": {},
  "recommendations": []
}
EOF
}

# Add check result to JSON report
# Usage: add_check_result <name> <status> <details...>
add_check_result() {
    local check_name="$1"
    local status="$2"  # pass, warn, fail
    shift 2
    local details="$@"

    # Create temporary check object
    local check_json=$(cat <<CHECKEOF
{
  "name": "${check_name}",
  "status": "${status}",
  "details": "${details}"
}
CHECKEOF
)

    # Add to checks array
    jq ".checks += [${check_json}]" "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
    mv "${AUDIT_REPORT_JSON}.tmp" "$AUDIT_REPORT_JSON"

    # Update summary counts
    case "$status" in
        pass)
            jq '.summary.passing += 1' "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
            ;;
        warn)
            jq '.summary.warnings += 1' "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
            ;;
        fail)
            jq '.summary.failures += 1' "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
            ;;
    esac
    mv "${AUDIT_REPORT_JSON}.tmp" "$AUDIT_REPORT_JSON"
}

# Add metric to JSON report
# Usage: add_metric <key> <value>
add_metric() {
    local key="$1"
    local value="$2"

    jq ".metrics.${key} = \"${value}\"" "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
    mv "${AUDIT_REPORT_JSON}.tmp" "$AUDIT_REPORT_JSON"
}

# Add recommendation to JSON report
# Usage: add_recommendation <priority> <recommendation>
add_recommendation() {
    local priority="$1"  # critical, important, optimization
    local recommendation="$2"

    local rec_json=$(cat <<RECEOF
{
  "priority": "${priority}",
  "recommendation": "${recommendation}"
}
RECEOF
)

    jq ".recommendations += [${rec_json}]" "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
    mv "${AUDIT_REPORT_JSON}.tmp" "$AUDIT_REPORT_JSON"
}

# Finalize audit report
# Usage: finalize_report
finalize_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - AUDIT_START_TIME))

    # Update JSON with final status and duration
    jq ".audit.status = \"completed\" | .audit.duration_seconds = ${duration}" "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
    mv "${AUDIT_REPORT_JSON}.tmp" "$AUDIT_REPORT_JSON"

    # Generate markdown summary from JSON
    generate_markdown_from_json

    log_success "Audit report generated successfully"
    log_info "JSON Report: ${AUDIT_REPORT_JSON}"
    log_info "Markdown Report: ${AUDIT_REPORT_MD}"
    log_info "Duration: ${duration}s"

    return 0
}

# Generate markdown report from JSON data
generate_markdown_from_json() {
    local passing=$(jq -r '.summary.passing' "$AUDIT_REPORT_JSON")
    local warnings=$(jq -r '.summary.warnings' "$AUDIT_REPORT_JSON")
    local failures=$(jq -r '.summary.failures' "$AUDIT_REPORT_JSON")
    local duration=$(jq -r '.audit.duration_seconds' "$AUDIT_REPORT_JSON")

    # Append summary to markdown
    cat >> "$AUDIT_REPORT_MD" <<EOF

## Summary

**Duration:** ${duration}s

### Status
- ✅ **Passing:** ${passing}
- ⚠️  **Warnings:** ${warnings}
- ❌ **Failures:** ${failures}

---

## Checks Performed

EOF

    # Add each check
    jq -r '.checks[] | "### \(.status | if . == "pass" then "✅" elif . == "warn" then "⚠️" else "❌" end) \(.name)\n\n\(.details)\n"' "$AUDIT_REPORT_JSON" >> "$AUDIT_REPORT_MD"

    # Add metrics if any
    local metric_count=$(jq '.metrics | length' "$AUDIT_REPORT_JSON")
    if [[ $metric_count -gt 0 ]]; then
        cat >> "$AUDIT_REPORT_MD" <<EOF

---

## Metrics

EOF
        jq -r '.metrics | to_entries[] | "- **\(.key):** \(.value)"' "$AUDIT_REPORT_JSON" >> "$AUDIT_REPORT_MD"
    fi

    # Add recommendations if any
    local rec_count=$(jq '.recommendations | length' "$AUDIT_REPORT_JSON")
    if [[ $rec_count -gt 0 ]]; then
        cat >> "$AUDIT_REPORT_MD" <<EOF

---

## Recommendations

EOF
        # Group by priority
        local has_critical=$(jq '[.recommendations[] | select(.priority == "critical")] | length' "$AUDIT_REPORT_JSON")
        local has_important=$(jq '[.recommendations[] | select(.priority == "important")] | length' "$AUDIT_REPORT_JSON")
        local has_optimization=$(jq '[.recommendations[] | select(.priority == "optimization")] | length' "$AUDIT_REPORT_JSON")

        if [[ $has_critical -gt 0 ]]; then
            echo "### 🔴 Critical (Fix Immediately)" >> "$AUDIT_REPORT_MD"
            echo "" >> "$AUDIT_REPORT_MD"
            jq -r '.recommendations[] | select(.priority == "critical") | "- \(.recommendation)"' "$AUDIT_REPORT_JSON" >> "$AUDIT_REPORT_MD"
            echo "" >> "$AUDIT_REPORT_MD"
        fi

        if [[ $has_important -gt 0 ]]; then
            echo "### 🟡 Important (Fix Soon)" >> "$AUDIT_REPORT_MD"
            echo "" >> "$AUDIT_REPORT_MD"
            jq -r '.recommendations[] | select(.priority == "important") | "- \(.recommendation)"' "$AUDIT_REPORT_JSON" >> "$AUDIT_REPORT_MD"
            echo "" >> "$AUDIT_REPORT_MD"
        fi

        if [[ $has_optimization -gt 0 ]]; then
            echo "### 🟢 Optimization (Consider)" >> "$AUDIT_REPORT_MD"
            echo "" >> "$AUDIT_REPORT_MD"
            jq -r '.recommendations[] | select(.priority == "optimization") | "- \(.recommendation)"' "$AUDIT_REPORT_JSON" >> "$AUDIT_REPORT_MD"
            echo "" >> "$AUDIT_REPORT_MD"
        fi
    fi

    # Add footer
    cat >> "$AUDIT_REPORT_MD" <<EOF

---

**Report Files:**
- JSON: \`.fractary/plugins/faber-cloud/audits/$(basename "$(dirname "$AUDIT_REPORT_JSON")")/$(basename "$AUDIT_REPORT_JSON")\`
- Markdown: \`.fractary/plugins/faber-cloud/audits/$(basename "$(dirname "$AUDIT_REPORT_MD")")/$(basename "$AUDIT_REPORT_MD")\`

EOF
}

# Determine exit code based on report status
# Usage: get_exit_code
get_exit_code() {
    local failures=$(jq -r '.summary.failures' "$AUDIT_REPORT_JSON")
    local warnings=$(jq -r '.summary.warnings' "$AUDIT_REPORT_JSON")

    if [[ $failures -gt 0 ]]; then
        return 2
    elif [[ $warnings -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}
