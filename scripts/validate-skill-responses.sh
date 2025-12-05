#!/usr/bin/env bash
#
# validate-skill-responses.sh - Audit skills for response format compliance
#
# Usage:
#   ./scripts/validate-skill-responses.sh [options] [plugin_path...]
#
# Options:
#   --fix       Auto-add OUTPUTS section boilerplate to non-compliant skills
#   --verbose   Show detailed analysis for each skill
#   --summary   Show only summary statistics
#   --json      Output results as JSON
#   --help      Show this help message
#
# Examples:
#   ./scripts/validate-skill-responses.sh                    # Check all plugins
#   ./scripts/validate-skill-responses.sh plugins/repo       # Check specific plugin
#   ./scripts/validate-skill-responses.sh --verbose          # Detailed output
#   ./scripts/validate-skill-responses.sh --json             # Machine-readable output

set -euo pipefail

# Configuration
PLUGINS_DIR="${PLUGINS_DIR:-plugins}"
VERBOSE=false
FIX_MODE=false
SUMMARY_ONLY=false
JSON_OUTPUT=false

# Colors (disabled if not terminal or JSON mode)
if [[ -t 1 ]] && [[ "${JSON_OUTPUT}" != "true" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Counters
TOTAL_SKILLS=0
COMPLIANT_SKILLS=0
PARTIAL_SKILLS=0
NON_COMPLIANT_SKILLS=0

# Results array for JSON output
declare -a RESULTS=()

show_help() {
    head -30 "$0" | tail -28 | sed 's/^#//' | sed 's/^ //'
    exit 0
}

log_info() {
    [[ "${JSON_OUTPUT}" == "true" ]] && return
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    [[ "${JSON_OUTPUT}" == "true" ]] && return
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    [[ "${JSON_OUTPUT}" == "true" ]] && return
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    [[ "${JSON_OUTPUT}" == "true" ]] && return
    echo -e "${RED}✗${NC} $1"
}

# Check if SKILL.md has proper OUTPUTS section with response format
check_skill_outputs() {
    local skill_path="$1"
    local skill_md="${skill_path}/SKILL.md"

    if [[ ! -f "${skill_md}" ]]; then
        echo "no_skill_md"
        return
    fi

    local content
    content=$(cat "${skill_md}")

    # Check for <OUTPUTS> section
    if ! grep -q '<OUTPUTS>' <<< "${content}"; then
        echo "no_outputs_section"
        return
    fi

    # Check for standard response format reference
    local has_format_ref=false
    if grep -q 'RESPONSE-FORMAT.md' <<< "${content}" || \
       grep -q 'standard FABER response format' <<< "${content}"; then
        has_format_ref=true
    fi

    # Check for status field in examples
    local has_status=false
    if grep -q '"status":\s*"success"\|"status":\s*"warning"\|"status":\s*"failure"' <<< "${content}"; then
        has_status=true
    fi

    # Check for message field in examples
    local has_message=false
    if grep -q '"message":' <<< "${content}"; then
        has_message=true
    fi

    # Check for details field in examples
    local has_details=false
    if grep -q '"details":' <<< "${content}"; then
        has_details=true
    fi

    # Check for errors/warnings arrays
    local has_error_handling=false
    if grep -q '"errors":' <<< "${content}" || grep -q '"warnings":' <<< "${content}"; then
        has_error_handling=true
    fi

    # Determine compliance level
    if [[ "${has_format_ref}" == "true" ]] && \
       [[ "${has_status}" == "true" ]] && \
       [[ "${has_message}" == "true" ]] && \
       [[ "${has_details}" == "true" ]] && \
       [[ "${has_error_handling}" == "true" ]]; then
        echo "compliant"
    elif [[ "${has_status}" == "true" ]] && [[ "${has_message}" == "true" ]]; then
        echo "partial:missing_some_fields"
    elif [[ "${has_status}" == "true" ]]; then
        echo "partial:missing_message_and_more"
    else
        echo "non_compliant"
    fi
}

# Get compliance details for verbose output
get_compliance_details() {
    local skill_path="$1"
    local skill_md="${skill_path}/SKILL.md"

    [[ ! -f "${skill_md}" ]] && return

    local content
    content=$(cat "${skill_md}")

    local details=""

    if ! grep -q 'RESPONSE-FORMAT.md' <<< "${content}" && \
       ! grep -q 'standard FABER response format' <<< "${content}"; then
        details+="  - Missing reference to RESPONSE-FORMAT.md\n"
    fi

    if ! grep -q '"status":\s*"success"\|"status":\s*"warning"\|"status":\s*"failure"' <<< "${content}"; then
        details+="  - Missing status field examples (success/warning/failure)\n"
    fi

    if ! grep -q '"message":' <<< "${content}"; then
        details+="  - Missing message field in response examples\n"
    fi

    if ! grep -q '"details":' <<< "${content}"; then
        details+="  - Missing details object wrapper\n"
    fi

    if ! grep -q '"errors":' <<< "${content}"; then
        details+="  - Missing errors array for failure cases\n"
    fi

    if ! grep -q '"warnings":' <<< "${content}"; then
        details+="  - Missing warnings array for warning cases\n"
    fi

    if ! grep -q '"error_analysis":' <<< "${content}"; then
        details+="  - Missing error_analysis field\n"
    fi

    if ! grep -q '"suggested_fixes":' <<< "${content}"; then
        details+="  - Missing suggested_fixes field\n"
    fi

    echo -e "${details}"
}

# Analyze a single skill
analyze_skill() {
    local skill_path="$1"
    local skill_name
    skill_name=$(basename "${skill_path}")
    local plugin_name
    plugin_name=$(basename "$(dirname "$(dirname "${skill_path}")")")

    ((TOTAL_SKILLS++))

    local result
    result=$(check_skill_outputs "${skill_path}")

    local status_icon=""
    local status_text=""
    local compliance="unknown"

    case "${result}" in
        "no_skill_md")
            status_icon="${YELLOW}?${NC}"
            status_text="No SKILL.md found"
            compliance="skip"
            ((TOTAL_SKILLS--))  # Don't count skills without SKILL.md
            ;;
        "no_outputs_section")
            status_icon="${RED}✗${NC}"
            status_text="Missing <OUTPUTS> section"
            compliance="non_compliant"
            ((NON_COMPLIANT_SKILLS++))
            ;;
        "compliant")
            status_icon="${GREEN}✓${NC}"
            status_text="Fully compliant"
            compliance="compliant"
            ((COMPLIANT_SKILLS++))
            ;;
        partial:*)
            status_icon="${YELLOW}⚠${NC}"
            status_text="Partially compliant (${result#partial:})"
            compliance="partial"
            ((PARTIAL_SKILLS++))
            ;;
        "non_compliant")
            status_icon="${RED}✗${NC}"
            status_text="Non-compliant (missing standard format)"
            compliance="non_compliant"
            ((NON_COMPLIANT_SKILLS++))
            ;;
    esac

    if [[ "${JSON_OUTPUT}" == "true" ]]; then
        RESULTS+=("{\"plugin\":\"${plugin_name}\",\"skill\":\"${skill_name}\",\"compliance\":\"${compliance}\",\"message\":\"${status_text}\"}")
    elif [[ "${SUMMARY_ONLY}" != "true" ]] && [[ "${compliance}" != "skip" ]]; then
        echo -e "${status_icon} ${plugin_name}/${skill_name}: ${status_text}"

        if [[ "${VERBOSE}" == "true" ]] && [[ "${compliance}" != "compliant" ]]; then
            local details
            details=$(get_compliance_details "${skill_path}")
            if [[ -n "${details}" ]]; then
                echo -e "${details}"
            fi
        fi
    fi
}

# Analyze all skills in a plugin
analyze_plugin() {
    local plugin_path="$1"
    local skills_dir="${plugin_path}/skills"

    if [[ ! -d "${skills_dir}" ]]; then
        return
    fi

    for skill_dir in "${skills_dir}"/*/; do
        [[ -d "${skill_dir}" ]] || continue
        analyze_skill "${skill_dir%/}"
    done
}

# Main analysis function
run_analysis() {
    local targets=("$@")

    if [[ ${#targets[@]} -eq 0 ]]; then
        # Analyze all plugins
        for plugin_dir in "${PLUGINS_DIR}"/*/; do
            [[ -d "${plugin_dir}" ]] || continue
            analyze_plugin "${plugin_dir%/}"
        done
    else
        # Analyze specified paths
        for target in "${targets[@]}"; do
            if [[ -d "${target}/skills" ]]; then
                analyze_plugin "${target}"
            elif [[ -d "${target}" ]] && [[ -f "${target}/SKILL.md" ]]; then
                analyze_skill "${target}"
            else
                log_warning "Invalid target: ${target}"
            fi
        done
    fi
}

# Print summary
print_summary() {
    if [[ "${JSON_OUTPUT}" == "true" ]]; then
        local results_json
        results_json=$(printf '%s\n' "${RESULTS[@]}" | jq -s '.')
        jq -n \
            --argjson results "${results_json}" \
            --arg total "${TOTAL_SKILLS}" \
            --arg compliant "${COMPLIANT_SKILLS}" \
            --arg partial "${PARTIAL_SKILLS}" \
            --arg non_compliant "${NON_COMPLIANT_SKILLS}" \
            '{
                summary: {
                    total: ($total | tonumber),
                    compliant: ($compliant | tonumber),
                    partial: ($partial | tonumber),
                    non_compliant: ($non_compliant | tonumber)
                },
                results: $results
            }'
        return
    fi

    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  SKILL RESPONSE FORMAT COMPLIANCE SUMMARY"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "  Total skills analyzed:  ${TOTAL_SKILLS}"
    echo -e "  ${GREEN}✓${NC} Fully compliant:       ${COMPLIANT_SKILLS}"
    echo -e "  ${YELLOW}⚠${NC} Partially compliant:   ${PARTIAL_SKILLS}"
    echo -e "  ${RED}✗${NC} Non-compliant:         ${NON_COMPLIANT_SKILLS}"
    echo ""

    if [[ ${TOTAL_SKILLS} -gt 0 ]]; then
        local percent
        percent=$(( (COMPLIANT_SKILLS * 100) / TOTAL_SKILLS ))
        echo "  Compliance rate: ${percent}%"

        if [[ ${percent} -eq 100 ]]; then
            echo -e "  ${GREEN}All skills are compliant!${NC}"
        elif [[ ${percent} -ge 80 ]]; then
            echo -e "  ${YELLOW}Good progress! A few skills need updates.${NC}"
        else
            echo -e "  ${RED}Many skills need migration to standard format.${NC}"
            echo "  See: docs/MIGRATE-SKILL-RESPONSES.md"
        fi
    fi
    echo ""
    echo "════════════════════════════════════════════════════════"
}

# Parse arguments
TARGETS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --fix)
            FIX_MODE=true
            shift
            ;;
        --summary)
            SUMMARY_ONLY=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            # Disable colors for JSON mode
            RED=''
            GREEN=''
            YELLOW=''
            BLUE=''
            NC=''
            shift
            ;;
        *)
            TARGETS+=("$1")
            shift
            ;;
    esac
done

# Run analysis
if [[ "${JSON_OUTPUT}" != "true" ]] && [[ "${SUMMARY_ONLY}" != "true" ]]; then
    echo ""
    echo "Analyzing skill response format compliance..."
    echo ""
fi

run_analysis "${TARGETS[@]}"
print_summary

# Exit with error code if non-compliant skills exist
if [[ ${NON_COMPLIANT_SKILLS} -gt 0 ]]; then
    exit 1
fi
