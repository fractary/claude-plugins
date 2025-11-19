#!/bin/bash
# report-generator.sh - Generate and store audit reports
# Usage: source report-generator.sh

set -euo pipefail

# Source configuration loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_COMMON_DIR="${SCRIPT_DIR}/../../cloud-common/scripts"
source "${CLOUD_COMMON_DIR}/config-loader.sh"

# Check required dependencies
# Usage: check_dependencies
check_dependencies() {
    local missing_deps=()

    # Check for jq (JSON processor)
    if ! command -v jq &>/dev/null; then
        missing_deps+=("jq")
    fi

    # Check for bc (calculator for cost analysis)
    if ! command -v bc &>/dev/null; then
        missing_deps+=("bc")
    fi

    # Check for aws CLI
    if ! command -v aws &>/dev/null; then
        missing_deps+=("aws")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                jq)
                    log_info "  - jq: brew install jq (macOS) or apt-get install jq (Ubuntu)"
                    ;;
                bc)
                    log_info "  - bc: brew install bc (macOS) or apt-get install bc (Ubuntu)"
                    ;;
                aws)
                    log_info "  - aws: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
                    ;;
            esac
        done
        return 1
    fi

    return 0
}

# Validate AWS credentials
# Usage: validate_aws_credentials
validate_aws_credentials() {
    if [[ -z "${AWS_PROFILE:-}" ]]; then
        log_error "AWS_PROFILE not set. Cannot proceed without AWS credentials."
        log_info "Ensure configuration is loaded and AWS profile is configured."
        return 1
    fi

    # Test AWS credentials by making a simple API call
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &>/dev/null; then
        log_error "AWS credentials are invalid or not configured for profile: ${AWS_PROFILE}"
        log_info "Please configure AWS credentials:"
        log_info "  1. Run: aws configure --profile ${AWS_PROFILE}"
        log_info "  2. Or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
        log_info "  3. Or configure ~/.aws/credentials file"
        return 1
    fi

    return 0
}

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
    export AUDIT_BASE_DIR="${DEVOPS_PROJECT_ROOT}/logs/infrastructure/audits"
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

    # Use jq with --arg to safely handle special characters and prevent JSON injection
    jq --arg name "$check_name" \
       --arg status "$status" \
       --arg details "$details" \
       '.checks += [{
           "name": $name,
           "status": $status,
           "details": $details
       }]' "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
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

    # Validate key contains only alphanumeric characters and underscores
    if [[ ! "$key" =~ ^[a-zA-Z0-9_]+$ ]]; then
        log_error "Invalid metric key: ${key}. Must contain only alphanumeric characters and underscores."
        return 1
    fi

    # Use jq with --arg to safely handle special characters
    jq --arg key "$key" \
       --arg value "$value" \
       '.metrics[$key] = $value' "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
    mv "${AUDIT_REPORT_JSON}.tmp" "$AUDIT_REPORT_JSON"
}

# Add recommendation to JSON report
# Usage: add_recommendation <priority> <recommendation>
add_recommendation() {
    local priority="$1"  # critical, important, optimization
    local recommendation="$2"

    # Use jq with --arg to safely handle special characters and prevent JSON injection
    jq --arg priority "$priority" \
       --arg recommendation "$recommendation" \
       '.recommendations += [{
           "priority": $priority,
           "recommendation": $recommendation
       }]' "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
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
- JSON: \`logs/infrastructure/audits/$(basename "$(dirname "$AUDIT_REPORT_JSON")")/$(basename "$AUDIT_REPORT_JSON")\`
- Markdown: \`logs/infrastructure/audits/$(basename "$(dirname "$AUDIT_REPORT_MD")")/$(basename "$AUDIT_REPORT_MD")\`

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
