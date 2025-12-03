#!/bin/bash
# generate-migration-report.sh - Generate comprehensive migration report
#
# Analyzes discovery reports and generates a detailed markdown migration report
# with capability mappings, risk assessment, timeline estimation, and checklists

set -euo pipefail

# Get script directory for sourcing shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared complexity assessment
# shellcheck source=./shared/assess-complexity.sh
source "$SCRIPT_DIR/shared/assess-complexity.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function: Display usage
usage() {
  cat <<EOF
Usage: generate-migration-report.sh <terraform_report> <aws_report> <custom_agents_report> <output_file>

Generate comprehensive migration report from discovery data.

Arguments:
  terraform_report        Path to Terraform discovery report JSON
  aws_report              Path to AWS profiles discovery report JSON
  custom_agents_report    Path to custom agents discovery report JSON
  output_file             Output path for migration report (markdown)

The report includes:
  - Executive summary with key metrics
  - Infrastructure complexity assessment
  - Custom script capability mapping
  - Risk assessment and mitigation strategies
  - Estimated timeline with phases
  - Step-by-step migration checklist
  - Rollback plan
  - Post-migration validation steps

Exit Codes:
  0 - Report generated successfully
  1 - Error during generation
  2 - Invalid arguments or missing reports

Examples:
  generate-migration-report.sh terraform.json aws.json agents.json MIGRATION.md
EOF
  exit 2
}

# Function: Log with color
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
  echo -e "${RED}[✗]${NC} $*" >&2
}

# Function: Validate discovery reports exist
validate_reports() {
  local tf_report="$1"
  local aws_report="$2"
  local agents_report="$3"

  log_info "Validating discovery reports..."

  if [ ! -f "$tf_report" ]; then
    log_error "Terraform discovery report not found: $tf_report"
    return 1
  fi

  if [ ! -f "$aws_report" ]; then
    log_error "AWS discovery report not found: $aws_report"
    return 1
  fi

  if [ ! -f "$agents_report" ]; then
    log_error "Custom agents discovery report not found: $agents_report"
    return 1
  fi

  log_success "All discovery reports valid"
  return 0
}

# Note: assess_complexity() is now sourced from shared/assess-complexity.sh

# Function: Estimate timeline
estimate_timeline() {
  local complexity="$1"

  log_info "Estimating migration timeline..."

  local hours=0
  local phases=""

  case "$complexity" in
    simple)
      hours=4
      phases="1. Discovery & Planning (1 hour)
2. Configuration Setup (1 hour)
3. Testing in Test Environment (1 hour)
4. Production Migration (1 hour)"
      ;;
    moderate)
      hours=12
      phases="1. Discovery & Planning (2 hours)
2. Configuration Setup (2 hours)
3. Hook Integration (2 hours)
4. Testing in Test Environment (3 hours)
5. Staging Validation (1 hour)
6. Production Migration (2 hours)"
      ;;
    complex)
      hours=24
      phases="1. Discovery & Planning (4 hours)
2. Configuration Setup (4 hours)
3. Module Analysis & Mapping (3 hours)
4. Hook Integration (3 hours)
5. Testing in Test Environment (4 hours)
6. Staging Validation (2 hours)
7. Production Migration (3 hours)
8. Post-Migration Monitoring (1 hour)"
      ;;
  esac

  echo "$hours|$phases"
}

# Function: Assess risks
assess_risks() {
  local tf_report="$1"
  local aws_report="$2"
  local agents_report="$3"

  log_info "Assessing migration risks..."

  local risks="[]"

  # Check for production environments
  local has_prod=$(jq -r '.profiles[] | select(.environment == "prod") | .name' "$aws_report" | head -1)
  if [ -n "$has_prod" ]; then
    local risk=$(jq -n \
      --arg level "HIGH" \
      --arg desc "Production environment detected" \
      --arg mitigation "Test thoroughly in test/staging before production migration. Use dry-run mode. Ensure rollback plan is ready." \
      '{level: $level, description: $desc, mitigation: $mitigation}')
    risks=$(echo "$risks" | jq --argjson risk "$risk" '. + [$risk]')
  fi

  # Check for remote backend
  local backend_type=$(jq -r '.terraform_directories[0].backend.type // "local"' "$tf_report")
  if [ "$backend_type" = "s3" ] || [ "$backend_type" = "remote" ]; then
    local risk=$(jq -n \
      --arg level "MEDIUM" \
      --arg desc "Remote state backend in use" \
      --arg mitigation "Backup state file before migration. Verify state locking works. Test state operations." \
      '{level: $level, description: $desc, mitigation: $mitigation}')
    risks=$(echo "$risks" | jq --argjson risk "$risk" '. + [$risk]')
  fi

  # Check for many resources
  local resource_count=$(jq -r '.summary.total_resources // 0' "$tf_report")
  if [ "$resource_count" -gt 50 ]; then
    local risk=$(jq -n \
      --arg level "MEDIUM" \
      --arg desc "Large number of resources ($resource_count)" \
      --arg mitigation "Plan changes may take longer. Consider increasing timeout settings. Monitor apply progress." \
      '{level: $level, description: $desc, mitigation: $mitigation}')
    risks=$(echo "$risks" | jq --argjson risk "$risk" '. + [$risk]')
  fi

  # Check for untracked custom scripts
  local untracked=$(jq -r '.summary.not_version_controlled // 0' "$agents_report")
  if [ "$untracked" -gt 0 ]; then
    local risk=$(jq -n \
      --arg level "HIGH" \
      --arg desc "$untracked custom scripts not in version control" \
      --arg mitigation "Commit all scripts to git before migration. Risk of losing custom tooling." \
      '{level: $level, description: $desc, mitigation: $mitigation}')
    risks=$(echo "$risks" | jq --argjson risk "$risk" '. + [$risk]')
  fi

  # Check for modules
  local module_count=$(jq -r '.terraform_directories[0].modules | length' "$tf_report")
  if [ "$module_count" -gt 5 ]; then
    local risk=$(jq -n \
      --arg level "MEDIUM" \
      --arg desc "Multiple Terraform modules ($module_count)" \
      --arg mitigation "Verify module sources are accessible. Test module initialization. Check for module version constraints." \
      '{level: $level, description: $desc, mitigation: $mitigation}')
    risks=$(echo "$risks" | jq --argjson risk "$risk" '. + [$risk]')
  fi

  echo "$risks"
}

# Function: Generate capability mapping
generate_capability_mapping() {
  local agents_report="$1"

  log_info "Generating capability mapping..."

  local discovered=$(jq -r '.discovered // false' "$agents_report")
  if [ "$discovered" = "false" ]; then
    echo "[]"
    return
  fi

  local mappings="[]"

  # Process each file
  local files=$(jq -c '.files[]?' "$agents_report")

  while IFS= read -r file; do
    [ -z "$file" ] && continue

    local file_path=$(echo "$file" | jq -r '.path')
    local purposes=$(echo "$file" | jq -r '.purposes | join(", ")')
    local faber_features=$(echo "$file" | jq -r '.faber_cloud_mappings[0].faber_cloud_feature // "Unknown"')
    local hook_alternatives=$(echo "$file" | jq -r '.faber_cloud_mappings[0].hook_alternative // "N/A"')

    # Determine recommendation
    local recommendation=""
    case "$(echo "$file" | jq -r '.purposes[0]')" in
      deploy)
        recommendation="Replace with faber-cloud infra-deployer skill. Can preserve as pre-deploy hook if custom logic needed."
        ;;
      audit)
        recommendation="Replace with faber-cloud infra-auditor skill. Can preserve as post-deploy hook for additional checks."
        ;;
      validate)
        recommendation="Integrate as post-plan hook for custom validation logic."
        ;;
      debug)
        recommendation="Preserve and use faber-cloud infra-debugger when needed. Keep script for edge cases."
        ;;
      teardown)
        recommendation="Use faber-cloud infra-teardown skill. Keep script as pre-destroy hook for backups."
        ;;
      configure)
        recommendation="Configuration now managed by config.json. Archive script after migration."
        ;;
      monitor)
        recommendation="Keep as standalone tool. faber-cloud doesn't replace monitoring functionality."
        ;;
      *)
        recommendation="Evaluate on case-by-case basis. May preserve as hook or standalone tool."
        ;;
    esac

    local mapping=$(jq -n \
      --arg path "$file_path" \
      --arg purposes "$purposes" \
      --arg features "$faber_features" \
      --arg hooks "$hook_alternatives" \
      --arg rec "$recommendation" \
      '{
        script: $path,
        current_purpose: $purposes,
        faber_cloud_equivalent: $features,
        integration_as: $hooks,
        recommendation: $rec
      }')

    mappings=$(echo "$mappings" | jq --argjson mapping "$mapping" '. + [$mapping]')

  done <<< "$files"

  echo "$mappings"
}

# Function: Generate markdown report
generate_report() {
  local tf_report="$1"
  local aws_report="$2"
  local agents_report="$3"

  log_info "Generating migration report..."

  # Get script directory for template
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local template_file="$script_dir/../templates/migration-report.template.md"

  # Extract data from reports
  local structure=$(jq -r '.summary.primary_structure // "flat"' "$tf_report")
  local tf_dir=$(jq -r '.summary.primary_directory // "./terraform"' "$tf_report")
  local resource_count=$(jq -r '.summary.total_resources // 0' "$tf_report")
  local backend_type=$(jq -r '.terraform_directories[0].backend.type // "local"' "$tf_report")
  local tf_version=$(jq -r '.terraform_directories[0].terraform_version // "unknown"' "$tf_report")

  local profile_count=$(jq -r '.summary.total_profiles // 0' "$aws_report")
  local project_profiles=$(jq -r '.summary.project_related_profiles // 0' "$aws_report")
  local environments=$(jq -r '.summary.environments_detected | join(", ")' "$aws_report")
  local region=$(jq -r '.summary.most_common_region // "us-east-1"' "$aws_report")

  local agent_count=$(jq -r '.summary.total_files // 0' "$agents_report")
  local agent_purposes=$(jq -r '.summary.purposes_detected | join(", ")' "$agents_report")
  local untracked=$(jq -r '.summary.not_version_controlled // 0' "$agents_report")

  # Assess complexity (uses shared function from shared/assess-complexity.sh)
  local complexity_info=$(assess_complexity "$tf_report" "$aws_report" "$agents_report")
  local complexity=$(echo "$complexity_info" | cut -d'|' -f1)
  local complexity_score=$(echo "$complexity_info" | cut -d'|' -f2)
  # Note: Third field is estimated_hours, but we get more detailed phases from estimate_timeline()

  # Estimate timeline
  local timeline_info=$(estimate_timeline "$complexity")
  local estimated_hours=$(echo "$timeline_info" | cut -d'|' -f1)
  local migration_phases=$(echo "$timeline_info" | cut -d'|' -f2-)

  # Assess risks
  local risks=$(assess_risks "$tf_report" "$aws_report" "$agents_report")

  # Generate capability mapping
  local capability_mapping=$(generate_capability_mapping "$agents_report")

  # Generate report content
  cat <<EOF
# Infrastructure Migration Report

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Tool:** faber-cloud Infrastructure Adoption

---

## Executive Summary

This report provides a comprehensive analysis of your existing infrastructure and outlines a migration plan to adopt faber-cloud for infrastructure lifecycle management.

### Key Metrics

| Metric | Value |
|--------|-------|
| **Infrastructure Complexity** | ${complexity^^} |
| **Terraform Structure** | $structure |
| **Total Resources** | $resource_count |
| **Environments Detected** | $project_profiles |
| **Custom Scripts** | $agent_count |
| **Estimated Migration Time** | $estimated_hours hours |

### Recommendation

EOF

  # Add recommendation based on complexity
  case "$complexity" in
    simple)
      cat <<EOF
Your infrastructure is straightforward and well-suited for faber-cloud adoption. Migration should be smooth with minimal custom configuration needed. Proceed with confidence after testing in a test environment.

EOF
      ;;
    moderate)
      cat <<EOF
Your infrastructure has moderate complexity. Migration is recommended but will require careful planning, especially around hook integration and multi-environment coordination. Allocate adequate time for testing.

EOF
      ;;
    complex)
      cat <<EOF
Your infrastructure is complex with multiple moving parts. Migration is feasible but requires significant planning and testing. Consider migrating in phases (test → staging → prod) and allocate extra time for module validation and hook integration.

EOF
      ;;
  esac

  cat <<EOF
---

## Infrastructure Overview

### Terraform Configuration

- **Location:** \`$tf_dir\`
- **Structure Type:** $structure
- **Terraform Version:** $tf_version
- **Backend:** $backend_type
- **Total Resources:** $resource_count
EOF

  if [ "$structure" = "modular" ] || [ "$structure" = "multi-environment" ]; then
    local module_count=$(jq -r '.terraform_directories[0].modules | length' "$tf_report")
    cat <<EOF
- **Modules:** $module_count
EOF
  fi

  cat <<EOF

### AWS Configuration

- **Total Profiles:** $profile_count
- **Project-Related Profiles:** $project_profiles
- **Environments:** $environments
- **Primary Region:** $region

### Custom Infrastructure Scripts

EOF

  if [ "$agent_count" -gt 0 ]; then
    cat <<EOF
- **Total Scripts:** $agent_count
- **Purposes:** $agent_purposes
- **Version Controlled:** $(( agent_count - untracked )) / $agent_count
EOF
    if [ "$untracked" -gt 0 ]; then
      cat <<EOF
- ⚠️ **WARNING:** $untracked script(s) not in version control
EOF
    fi
  else
    cat <<EOF
- **No custom scripts detected**
EOF
  fi

  cat <<EOF

---

## Capability Mapping

This section maps your existing custom scripts to faber-cloud features.

EOF

  if [ "$(echo "$capability_mapping" | jq 'length')" -gt 0 ]; then
    cat <<EOF
### Script Analysis

| Script | Current Purpose | faber-cloud Feature | Integration Method | Recommendation |
|--------|----------------|---------------------|-------------------|----------------|
EOF

    echo "$capability_mapping" | jq -r '.[] | "| `\(.script)` | \(.current_purpose) | \(.faber_cloud_equivalent) | \(.integration_as) | \(.recommendation) |"'

    cat <<EOF

### Migration Strategy by Purpose

EOF

    # Group recommendations by purpose
    local purposes=$(echo "$capability_mapping" | jq -r '.[].current_purpose' | sort -u)

    while IFS= read -r purpose; do
      [ -z "$purpose" ] && continue

      case "$purpose" in
        *deploy*)
          cat <<EOF
**Deployment Scripts:**
- Replace with \`faber-cloud infra-deployer\` skill
- Preserve custom logic as pre-deploy or post-deploy hooks
- Test deployment workflow in test environment first

EOF
          ;;
        *audit*)
          cat <<EOF
**Audit Scripts:**
- Use \`faber-cloud infra-auditor\` for standard checks
- Integrate custom checks as post-deploy hooks
- Schedule regular audits via cron or CI/CD

EOF
          ;;
        *validate*)
          cat <<EOF
**Validation Scripts:**
- Integrate as post-plan hooks
- Run automatically after every terraform plan
- Keep critical validations marked as critical: true

EOF
          ;;
        *teardown* | *backup*)
          cat <<EOF
**Backup/Teardown Scripts:**
- Integrate as pre-destroy hooks (critical: true)
- Ensure backups complete before any destroy operation
- Test backup restoration process

EOF
          ;;
      esac

    done <<< "$purposes"

  else
    cat <<EOF
No custom scripts detected. Your infrastructure will adopt faber-cloud's built-in lifecycle management without custom hook integration.

EOF
  fi

  cat <<EOF
---

## Risk Assessment

EOF

  local risk_count=$(echo "$risks" | jq 'length')
  if [ "$risk_count" -gt 0 ]; then
    cat <<EOF
### Identified Risks

The following risks have been identified for this migration:

EOF

    echo "$risks" | jq -r '.[] | "#### \(.level): \(.description)\n\n**Mitigation:** \(.mitigation)\n"'

  else
    cat <<EOF
### Low Risk Migration

No significant risks identified. This appears to be a low-risk migration.

EOF
  fi

  cat <<EOF
### General Risk Mitigation

1. **Backup Everything**
   - Create full backup of Terraform state files
   - Export current AWS resource inventory
   - Commit all changes to version control

2. **Test Thoroughly**
   - Run \`faber-cloud audit\` (read-only) first
   - Test deployment in test environment
   - Validate with \`terraform plan\` before any applies

3. **Gradual Rollout**
   - Start with test environment
   - Move to staging for validation
   - Deploy to production only after full validation

4. **Rollback Plan**
   - Keep existing scripts available during transition
   - Maintain manual deployment ability
   - Document rollback procedures

---

## Estimated Timeline

**Total Estimated Time:** $estimated_hours hours

### Migration Phases

$migration_phases

### Timeline by Complexity

EOF

  case "$complexity" in
    simple)
      cat <<EOF
**Simple Infrastructure (Your Case)**

- **Day 1 Morning:** Discovery, configuration setup, initial testing (4 hours)
- **Day 1 Afternoon:** Production migration and validation

This timeline assumes no major issues. Add buffer time for unexpected challenges.

EOF
      ;;
    moderate)
      cat <<EOF
**Moderate Infrastructure (Your Case)**

- **Day 1:** Discovery, planning, configuration setup (4 hours)
- **Day 2 Morning:** Hook integration and test environment testing (5 hours)
- **Day 2 Afternoon:** Staging validation (1 hour)
- **Day 3 Morning:** Production migration (2 hours)

This timeline assumes availability of test and staging environments. Add 20% buffer time.

EOF
      ;;
    complex)
      cat <<EOF
**Complex Infrastructure (Your Case)**

- **Week 1 Day 1-2:** Discovery, planning, configuration setup (8 hours)
- **Week 1 Day 3:** Module analysis and mapping (3 hours)
- **Week 1 Day 4:** Hook integration (3 hours)
- **Week 2 Day 1-2:** Comprehensive testing in test environment (4 hours)
- **Week 2 Day 3:** Staging validation (2 hours)
- **Week 2 Day 4:** Production migration (3 hours)
- **Week 2 Day 5:** Post-migration monitoring (1 hour)

This timeline requires dedicated time blocks. Consider splitting across 2 weeks for safety.

EOF
      ;;
  esac

  cat <<EOF
---

## Migration Checklist

Use this checklist to track your migration progress.

### Phase 1: Pre-Migration (Discovery & Planning)

- [ ] Run infrastructure discovery scripts
  \`\`\`bash
  bash plugins/faber-cloud/skills/infra-adoption/scripts/discover-terraform.sh . discovery-terraform.json
  bash plugins/faber-cloud/skills/infra-adoption/scripts/discover-aws-profiles.sh discovery-aws.json
  bash plugins/faber-cloud/skills/infra-adoption/scripts/discover-custom-agents.sh . discovery-custom-agents.json
  \`\`\`

- [ ] Review discovery reports
- [ ] Identify all custom scripts and their purposes
- [ ] Document current deployment workflow
- [ ] Backup all Terraform state files
- [ ] Commit all untracked scripts to version control

### Phase 2: Configuration Setup

- [ ] Generate faber-cloud configuration
  \`\`\`bash
  bash plugins/faber-cloud/skills/infra-adoption/scripts/generate-config.sh \\
    discovery-terraform.json \\
    discovery-aws.json \\
    discovery-custom-agents.json \\
    config.json
  \`\`\`

- [ ] Validate generated configuration
  \`\`\`bash
  bash plugins/faber-cloud/skills/infra-adoption/scripts/validate-generated-config.sh config.json
  \`\`\`

- [ ] Review and customize configuration
  - [ ] Update project name and description
  - [ ] Verify environment configurations
  - [ ] Adjust hook timeouts if needed
  - [ ] Configure notifications (Slack, etc.)

- [ ] Copy configuration to project
  \`\`\`bash
  mkdir -p .fractary/plugins/faber-cloud
  cp config.json .fractary/plugins/faber-cloud/
  \`\`\`

### Phase 3: Hook Integration

EOF

  if [ "$agent_count" -gt 0 ]; then
    cat <<EOF
- [ ] Review generated hook suggestions
- [ ] Test each custom script individually
- [ ] Adjust hook configurations:
  - [ ] Set appropriate timeouts
  - [ ] Mark critical hooks correctly
  - [ ] Limit hooks to specific environments if needed

- [ ] Create hook wrapper scripts if needed
- [ ] Document hook dependencies

EOF
  else
    cat <<EOF
- [ ] No custom hooks to integrate (skipping this phase)

EOF
  fi

  cat <<EOF
### Phase 4: Testing in Test Environment

- [ ] Run read-only audit
  \`\`\`bash
  faber-cloud audit test
  \`\`\`

- [ ] Review audit output
- [ ] Run terraform plan via faber-cloud
  \`\`\`bash
  faber-cloud plan test
  \`\`\`

- [ ] Verify enhanced environment validation
- [ ] Test all hooks execute correctly
- [ ] Deploy to test environment
  \`\`\`bash
  faber-cloud deploy test
  \`\`\`

- [ ] Validate deployed resources
- [ ] Test rollback if applicable

EOF

  if [ "$project_profiles" -gt 2 ]; then
    cat <<EOF
### Phase 5: Staging Validation

- [ ] Deploy to staging environment
  \`\`\`bash
  faber-cloud deploy staging
  \`\`\`

- [ ] Run integration tests
- [ ] Validate with production-like data
- [ ] Monitor for issues
- [ ] Get stakeholder sign-off

EOF
  fi

  cat <<EOF
### Phase 6: Production Migration

- [ ] Schedule maintenance window (if needed)
- [ ] Notify team members
- [ ] Create production state backup
  \`\`\`bash
  cp terraform.tfstate terraform.tfstate.pre-faber-cloud
  \`\`\`

- [ ] Run production audit
  \`\`\`bash
  faber-cloud audit prod
  \`\`\`

- [ ] Review plan carefully
  \`\`\`bash
  faber-cloud plan prod
  \`\`\`

- [ ] Deploy to production
  \`\`\`bash
  faber-cloud deploy prod
  \`\`\`

- [ ] Validate all resources
- [ ] Run smoke tests
- [ ] Monitor for 24 hours

### Phase 7: Post-Migration

- [ ] Update team documentation
- [ ] Train team on faber-cloud usage
- [ ] Archive old deployment scripts
- [ ] Set up monitoring/alerting
- [ ] Schedule first regular audit
- [ ] Conduct retrospective
- [ ] Document lessons learned

---

## Rollback Plan

If issues occur during migration, follow this rollback procedure:

### Immediate Rollback (During Deployment)

1. **Stop the deployment:**
   \`\`\`bash
   Ctrl+C (if safe to interrupt)
   \`\`\`

2. **Assess state:**
   \`\`\`bash
   terraform show
   git status
   \`\`\`

3. **Restore previous state (if needed):**
   \`\`\`bash
   cp terraform.tfstate.pre-faber-cloud terraform.tfstate
   \`\`\`

4. **Use old deployment process:**
   - Revert to manual terraform commands
   - Use original custom scripts

### Full Rollback (After Deployment)

1. **Document what went wrong**

2. **Restore from backup:**
   \`\`\`bash
   cp terraform.tfstate.backup terraform.tfstate
   \`\`\`

3. **Revert configuration changes:**
   \`\`\`bash
   git checkout HEAD~1 .fractary/
   \`\`\`

4. **Return to old workflow** until issues are resolved

---

## Post-Migration Validation

After successful migration, validate the following:

### Infrastructure Health

- [ ] All resources in expected state
- [ ] No drift detected (\`faber-cloud audit\`)
- [ ] State file intact and accessible
- [ ] Backends functioning correctly

### Workflow Validation

- [ ] Team can successfully deploy
- [ ] Hooks execute as expected
- [ ] Environment validation prevents errors
- [ ] Approval workflow works for production

### Documentation

- [ ] README updated with faber-cloud usage
- [ ] Team trained on new workflow
- [ ] Runbooks updated
- [ ] Emergency procedures documented

---

## Next Steps

1. **Review this report** with your team
2. **Schedule migration time** based on estimated timeline
3. **Run discovery scripts** if not already done
4. **Generate configuration** using provided commands
5. **Start with test environment** for safe experimentation

## Support

For questions or issues during migration:

- Review: \`specs/SPEC-0030-01-faber-cloud-migration-features.md\`
- Check: \`plugins/faber-cloud/skills/infra-adoption/SKILL.md\`
- Use: \`faber-cloud --help\`

---

**End of Report**

*Generated by faber-cloud infrastructure adoption tool*
EOF
}

# Main execution
main() {
  # Validate arguments
  if [ $# -lt 4 ]; then
    usage
  fi

  local tf_report="$1"
  local aws_report="$2"
  local agents_report="$3"
  local output_file="$4"

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_info "Migration Report Generation"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Validate all reports
  if ! validate_reports "$tf_report" "$aws_report" "$agents_report"; then
    exit 1
  fi

  echo ""

  # Generate report
  generate_report "$tf_report" "$aws_report" "$agents_report" > "$output_file"

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_success "Migration report generated successfully"
  log_info "Output: $output_file"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "Next steps:"
  echo "  1. Review the migration report"
  echo "  2. Share with your team"
  echo "  3. Follow the migration checklist"
  echo "  4. Start with test environment"
  echo ""

  exit 0
}

# Run main function
main "$@"
