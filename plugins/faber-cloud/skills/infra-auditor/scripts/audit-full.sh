#!/bin/bash
# audit-full.sh - Comprehensive audit (runs all audit checks)
# Usage: audit-full.sh --env <environment>

set -euo pipefail

# Source report generator
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/report-generator.sh"

# Check dependencies before proceeding
if ! check_dependencies; then
    exit 1
fi

# Parse arguments
ENVIRONMENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --env requires a value" >&2
                exit 2
            fi
            ENVIRONMENT="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 --env <environment>" >&2
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -z "$ENVIRONMENT" ]]; then
    log_error "Environment not specified"
    exit 1
fi

# Initialize audit report
init_audit_report "$ENVIRONMENT" "full"
generate_report_header "full" "$ENVIRONMENT"
init_json_report "full" "$ENVIRONMENT"

log_info "═══════════════════════════════════════════════════════════"
log_info "  COMPREHENSIVE INFRASTRUCTURE AUDIT"
log_info "  Environment: ${ENVIRONMENT}"
log_info "═══════════════════════════════════════════════════════════"
echo ""

# Array to track individual audit results
declare -A AUDIT_RESULTS
declare -A AUDIT_DURATIONS

# Function to run individual audit and capture results
run_audit() {
    local audit_name="$1"
    local audit_script="$2"
    local start_time=$(date +%s)

    log_info "Running ${audit_name} audit..."

    # Run audit and capture exit code
    local exit_code=0
    "${SCRIPT_DIR}/${audit_script}" --env "$ENVIRONMENT" || exit_code=$?

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    AUDIT_RESULTS["$audit_name"]=$exit_code
    AUDIT_DURATIONS["$audit_name"]=$duration

    case $exit_code in
        0)
            log_success "${audit_name}: PASSED (${duration}s)"
            ;;
        1)
            log_warning "${audit_name}: WARNINGS (${duration}s)"
            ;;
        2)
            log_error "${audit_name}: FAILED (${duration}s)"
            ;;
    esac

    echo ""
}

# Run all audits in sequence
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AUDIT EXECUTION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

run_audit "Configuration Validation" "audit-config.sh"
run_audit "IAM Health" "audit-iam.sh"
run_audit "Drift Detection" "audit-drift.sh"
run_audit "Security Posture" "audit-security.sh"
run_audit "Cost Analysis" "audit-cost.sh"

# Calculate overall results
TOTAL_PASSED=0
TOTAL_WARNINGS=0
TOTAL_FAILURES=0
TOTAL_DURATION=0

for audit in "${!AUDIT_RESULTS[@]}"; do
    exit_code=${AUDIT_RESULTS[$audit]}
    duration=${AUDIT_DURATIONS[$audit]}
    TOTAL_DURATION=$((TOTAL_DURATION + duration))

    case $exit_code in
        0)
            TOTAL_PASSED=$((TOTAL_PASSED + 1))
            ;;
        1)
            TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
            ;;
        2)
            TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
            ;;
    esac
done

# Aggregate all individual audit reports
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AGGREGATING RESULTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Collect all JSON reports from individual audits
INDIVIDUAL_REPORTS=(
    "${AUDIT_ENV_DIR}/${AUDIT_TIMESTAMP}-config-valid.json"
    "${AUDIT_ENV_DIR}/${AUDIT_TIMESTAMP}-iam-health.json"
    "${AUDIT_ENV_DIR}/${AUDIT_TIMESTAMP}-drift.json"
    "${AUDIT_ENV_DIR}/${AUDIT_TIMESTAMP}-security.json"
    "${AUDIT_ENV_DIR}/${AUDIT_TIMESTAMP}-cost.json"
)

# Aggregate summary counts
TOTAL_PASSING=0
TOTAL_WARN=0
TOTAL_FAIL=0

for report in "${INDIVIDUAL_REPORTS[@]}"; do
    if [[ -f "$report" ]]; then
        PASSING=$(jq -r '.summary.passing' "$report" 2>/dev/null || echo "0")
        WARNINGS=$(jq -r '.summary.warnings' "$report" 2>/dev/null || echo "0")
        FAILURES=$(jq -r '.summary.failures' "$report" 2>/dev/null || echo "0")

        TOTAL_PASSING=$((TOTAL_PASSING + PASSING))
        TOTAL_WARN=$((TOTAL_WARN + WARNINGS))
        TOTAL_FAIL=$((TOTAL_FAIL + FAILURES))
    fi
done

# Update summary in full report
jq ".summary.passing = ${TOTAL_PASSING} | .summary.warnings = ${TOTAL_WARN} | .summary.failures = ${TOTAL_FAIL}" \
    "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
mv "${AUDIT_REPORT_JSON}.tmp" "$AUDIT_REPORT_JSON"

# Add audit execution summary
cat >> "$AUDIT_REPORT_MD" <<EOF

## Audit Execution Summary

**Total Duration:** ${TOTAL_DURATION}s

### Audit Categories
EOF

for audit in "${!AUDIT_RESULTS[@]}"; do
    exit_code=${AUDIT_RESULTS[$audit]}
    duration=${AUDIT_DURATIONS[$audit]}

    case $exit_code in
        0)
            status_icon="✅"
            status_text="PASSED"
            ;;
        1)
            status_icon="⚠️"
            status_text="WARNINGS"
            ;;
        2)
            status_icon="❌"
            status_text="FAILED"
            ;;
    esac

    echo "- ${status_icon} **${audit}**: ${status_text} (${duration}s)" >> "$AUDIT_REPORT_MD"
done

cat >> "$AUDIT_REPORT_MD" <<EOF

---

## Aggregated Results

### Summary Statistics
- **Total Checks Passed:** ${TOTAL_PASSING}
- **Total Warnings:** ${TOTAL_WARN}
- **Total Failures:** ${TOTAL_FAIL}

EOF

# Aggregate all checks from individual reports
echo "### All Checks" >> "$AUDIT_REPORT_MD"
echo "" >> "$AUDIT_REPORT_MD"

for report in "${INDIVIDUAL_REPORTS[@]}"; do
    if [[ -f "$report" ]]; then
        CHECK_TYPE=$(jq -r '.audit.check_type' "$report")
        echo "#### ${CHECK_TYPE^}" >> "$AUDIT_REPORT_MD"
        echo "" >> "$AUDIT_REPORT_MD"

        jq -r '.checks[] | "- \(.status | if . == "pass" then "✅" elif . == "warn" then "⚠️" else "❌" end) \(.name): \(.details)"' \
            "$report" >> "$AUDIT_REPORT_MD"
        echo "" >> "$AUDIT_REPORT_MD"
    fi
done

# Aggregate all recommendations by priority
echo "---" >> "$AUDIT_REPORT_MD"
echo "" >> "$AUDIT_REPORT_MD"
echo "## Prioritized Recommendations" >> "$AUDIT_REPORT_MD"
echo "" >> "$AUDIT_REPORT_MD"

# Critical recommendations
CRITICAL_RECS=""
for report in "${INDIVIDUAL_REPORTS[@]}"; do
    if [[ -f "$report" ]]; then
        RECS=$(jq -r '.recommendations[] | select(.priority == "critical") | .recommendation' "$report" 2>/dev/null || echo "")
        if [[ -n "$RECS" ]]; then
            CRITICAL_RECS="${CRITICAL_RECS}${RECS}"$'\n'
        fi
    fi
done

if [[ -n "$CRITICAL_RECS" ]]; then
    echo "### 🔴 Critical (Fix Immediately)" >> "$AUDIT_REPORT_MD"
    echo "" >> "$AUDIT_REPORT_MD"
    echo "$CRITICAL_RECS" | grep -v '^$' | sort -u | sed 's/^/- /' >> "$AUDIT_REPORT_MD"
    echo "" >> "$AUDIT_REPORT_MD"
fi

# Important recommendations
IMPORTANT_RECS=""
for report in "${INDIVIDUAL_REPORTS[@]}"; do
    if [[ -f "$report" ]]; then
        RECS=$(jq -r '.recommendations[] | select(.priority == "important") | .recommendation' "$report" 2>/dev/null || echo "")
        if [[ -n "$RECS" ]]; then
            IMPORTANT_RECS="${IMPORTANT_RECS}${RECS}"$'\n'
        fi
    fi
done

if [[ -n "$IMPORTANT_RECS" ]]; then
    echo "### 🟡 Important (Fix Soon)" >> "$AUDIT_REPORT_MD"
    echo "" >> "$AUDIT_REPORT_MD"
    echo "$IMPORTANT_RECS" | grep -v '^$' | sort -u | sed 's/^/- /' >> "$AUDIT_REPORT_MD"
    echo "" >> "$AUDIT_REPORT_MD"
fi

# Optimization recommendations
OPTIMIZATION_RECS=""
for report in "${INDIVIDUAL_REPORTS[@]}"; do
    if [[ -f "$report" ]]; then
        RECS=$(jq -r '.recommendations[] | select(.priority == "optimization") | .recommendation' "$report" 2>/dev/null || echo "")
        if [[ -n "$RECS" ]]; then
            OPTIMIZATION_RECS="${OPTIMIZATION_RECS}${RECS}"$'\n'
        fi
    fi
done

if [[ -n "$OPTIMIZATION_RECS" ]]; then
    echo "### 🟢 Optimization (Consider)" >> "$AUDIT_REPORT_MD"
    echo "" >> "$AUDIT_REPORT_MD"
    echo "$OPTIMIZATION_RECS" | grep -v '^$' | sort -u | sed 's/^/- /' >> "$AUDIT_REPORT_MD"
    echo "" >> "$AUDIT_REPORT_MD"
fi

# Add aggregated metrics
echo "---" >> "$AUDIT_REPORT_MD"
echo "" >> "$AUDIT_REPORT_MD"
echo "## Aggregated Metrics" >> "$AUDIT_REPORT_MD"
echo "" >> "$AUDIT_REPORT_MD"

for report in "${INDIVIDUAL_REPORTS[@]}"; do
    if [[ -f "$report" ]]; then
        CHECK_TYPE=$(jq -r '.audit.check_type' "$report")
        METRICS=$(jq -r '.metrics | to_entries[] | "- **\(.key)**: \(.value)"' "$report" 2>/dev/null || echo "")

        if [[ -n "$METRICS" ]]; then
            echo "### ${CHECK_TYPE^}" >> "$AUDIT_REPORT_MD"
            echo "" >> "$AUDIT_REPORT_MD"
            echo "$METRICS" >> "$AUDIT_REPORT_MD"
            echo "" >> "$AUDIT_REPORT_MD"
        fi
    fi
done

# Finalize report
jq ".audit.duration_seconds = ${TOTAL_DURATION} | .audit.status = \"completed\"" \
    "$AUDIT_REPORT_JSON" > "${AUDIT_REPORT_JSON}.tmp"
mv "${AUDIT_REPORT_JSON}.tmp" "$AUDIT_REPORT_JSON"

# Print summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "COMPREHENSIVE AUDIT COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "Duration: ${TOTAL_DURATION}s"
log_info "Audits: ${TOTAL_PASSED} passed, ${TOTAL_WARNINGS} warnings, ${TOTAL_FAILURES} failures"
log_info "Checks: ${TOTAL_PASSING} passed, ${TOTAL_WARN} warnings, ${TOTAL_FAIL} failures"
echo ""
log_success "Full audit report: ${AUDIT_REPORT_MD}"
log_success "JSON report: ${AUDIT_REPORT_JSON}"
echo ""

# Determine overall exit code
OVERALL_EXIT=0
if [[ $TOTAL_FAILURES -gt 0 || $TOTAL_FAIL -gt 0 ]]; then
    OVERALL_EXIT=2
    log_error "❌ AUDIT FAILED - Critical issues found"
elif [[ $TOTAL_WARNINGS -gt 0 || $TOTAL_WARN -gt 0 ]]; then
    OVERALL_EXIT=1
    log_warning "⚠️  AUDIT WARNING - Non-critical issues found"
else
    log_success "✅ AUDIT PASSED - All checks successful"
fi

exit $OVERALL_EXIT
