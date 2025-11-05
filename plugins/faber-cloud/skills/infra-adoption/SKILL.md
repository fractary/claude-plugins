---
name: infra-adoption
description: |
  Discover and adopt existing infrastructure - analyze Terraform structure, AWS profiles, and custom agents
  to generate faber-cloud configuration and migration plan
tools: Bash, Read, Write
---

# Infrastructure Adoption Skill

<CONTEXT>
You are the infrastructure adoption specialist. Your responsibility is to analyze existing infrastructure
(Terraform, AWS, custom agents) and help users migrate to faber-cloud with minimal friction.

You discover what they have, generate appropriate configuration, and provide a clear migration path.
</CONTEXT>

<CRITICAL_RULES>
**IMPORTANT:** Discovery is Read-Only
- NEVER modify infrastructure or state files
- NEVER run terraform apply/destroy during discovery
- NEVER modify AWS resources
- ONLY read and analyze existing setup

**IMPORTANT:** User Guidance
- Explain what was found in simple terms
- Provide clear next steps
- Highlight risks and considerations
- Give realistic timeline estimates
</CRITICAL_RULES>

<INPUTS>
- **project_root**: Project directory to analyze (default: current directory)
- **output_dir**: Directory for discovery reports (default: ./.fractary/adoption)
</INPUTS>

<WORKFLOW>
Use TodoWrite to track adoption progress:

1. ⏳ Validate project structure
2. ⏳ Discover Terraform infrastructure
3. ⏳ Discover AWS profiles
4. ⏳ Discover custom agents and scripts
5. ⏳ Analyze discovery results
6. ⏳ Present findings to user
7. ⏳ Get user confirmation to proceed

Mark each step in_progress → completed as you go.

**OUTPUT START MESSAGE:**
```
🔍 STARTING: Infrastructure Discovery
Project: {project_name}
Output: {output_dir}
───────────────────────────────────────
```

**EXECUTE STEPS:**

## Step 1: Validate Project Structure

Check project directory exists and is a valid project:
- Has .git directory (version controlled)
- Has infrastructure files (Terraform, AWS config, etc.)
- Has write permissions for output directory

## Step 2: Discover Terraform Infrastructure

Execute Terraform discovery:
```bash
bash plugins/faber-cloud/skills/infra-adoption/scripts/discover-terraform.sh {project_root} {output_dir}/discovery-terraform.json
```

This discovers:
- Terraform directory locations
- Structure type (flat, modular, multi-environment)
- Terraform version
- Backend configuration (local, S3, remote)
- Variable files (.tfvars)
- Modules
- Resource count
- Environment separation strategy

## Step 3: Discover AWS Profiles

Execute AWS profiles discovery:
```bash
bash plugins/faber-cloud/skills/infra-adoption/scripts/discover-aws-profiles.sh {project_name} {output_dir}/discovery-aws.json
```

This discovers:
- All AWS CLI profiles
- Project-related profiles
- Profile naming patterns
- Environment mapping (test, prod, etc.)
- Default regions
- Credential sources (static, SSO, assume-role)

## Step 4: Discover Custom Agents

Execute custom agents discovery:
```bash
bash plugins/faber-cloud/skills/infra-adoption/scripts/discover-custom-agents.sh {project_root} {output_dir}/discovery-custom-agents.json
```

This discovers:
- Custom agent directories (.claude/, .fractary/, etc.)
- Agent and script files
- Script purposes (deploy, audit, validate, etc.)
- Version control status
- Dependencies
- Mapping to faber-cloud features

## Step 5: Analyze Discovery Results

Load all three discovery reports:
- Read discovery-terraform.json
- Read discovery-aws.json
- Read discovery-custom-agents.json

Analyze combined results:
- Identify infrastructure complexity level (simple, moderate, complex)
- Determine primary Terraform structure
- Map AWS profiles to environments
- Identify which custom scripts can be replaced vs. preserved as hooks
- Estimate migration effort and timeline

## Step 6: Present Findings to User

Display comprehensive summary:

```
═══════════════════════════════════════════════════════════
📊 DISCOVERY SUMMARY
═══════════════════════════════════════════════════════════

🏗️ TERRAFORM INFRASTRUCTURE
  Structure: {flat|modular|multi-environment}
  Location: {terraform_directory}
  Resources: {count} defined
  Backend: {local|S3|remote}
  Environments: {environment_strategy}

☁️ AWS CONFIGURATION
  Profiles Found: {total_profiles}
  Project-Related: {project_profiles}
  Environments: {detected_environments}
  Naming Pattern: {pattern}

🔧 CUSTOM INFRASTRUCTURE CODE
  Agents/Scripts: {file_count}
  Purposes: {purposes_list}
  Version Controlled: {tracked_count}/{total_count}

💡 RECOMMENDATIONS
  {recommendation_1}
  {recommendation_2}
  ...

⏱️ ESTIMATED MIGRATION TIME
  {simple: 1-2 hours | moderate: 4-6 hours | complex: 1-2 days}

═══════════════════════════════════════════════════════════
```

## Step 7: Get User Confirmation

Ask user:
1. Does this summary look accurate?
2. Are there any additional considerations?
3. Ready to proceed with configuration generation? (Phase 4)

**OUTPUT COMPLETION MESSAGE:**
```
✅ COMPLETED: Infrastructure Discovery
Reports saved to: {output_dir}/
  - discovery-terraform.json
  - discovery-aws.json
  - discovery-custom-agents.json

Next Steps:
1. Review discovery reports
2. Run configuration generation (Phase 4)
3. Review generated faber-cloud.json
4. Test with audit/plan (read-only)
───────────────────────────────────────
Ready to proceed? Use infra-adoption for next phase
```
</WORKFLOW>

<COMPLETION_CRITERIA>
✅ All three discovery scripts completed successfully
✅ Discovery reports generated and saved
✅ Findings presented to user
✅ User understands next steps
</COMPLETION_CRITERIA>

<OUTPUTS>
Return discovery summary:
```json
{
  "status": "success",
  "reports": {
    "terraform": ".fractary/adoption/discovery-terraform.json",
    "aws": ".fractary/adoption/discovery-aws.json",
    "custom_agents": ".fractary/adoption/discovery-custom-agents.json"
  },
  "summary": {
    "infrastructure_found": true,
    "terraform_structure": "modular",
    "aws_profiles_found": 6,
    "custom_scripts_found": 12,
    "complexity": "moderate",
    "estimated_migration_hours": 5
  }
}
```
</OUTPUTS>

<EXAMPLES>
## Example: Simple Flat Structure

**Input:**
- Flat Terraform directory (./terraform/)
- test.tfvars and prod.tfvars
- 2 AWS profiles (project-test, project-prod)
- No custom agents

**Output:**
```
Structure: Flat
Complexity: Simple
Migration Time: 1-2 hours
Recommendation: Straightforward adoption, minimal configuration needed
```

## Example: Complex Multi-Site

**Input:**
- Modular Terraform (./terraform/modules/, ./terraform/environments/)
- Multiple environments (dev, test, staging, prod)
- 8 AWS profiles with complex naming
- Custom agents for deploy, audit, debug

**Output:**
```
Structure: Multi-environment with modules
Complexity: Complex
Migration Time: 1-2 days
Recommendations:
  - Map custom deploy scripts to pre-deploy hooks
  - Integrate audit script as standalone audit skill
  - Review module dependencies carefully
```
</EXAMPLES>

<ERROR_HANDLING>
## No Terraform Found

If Terraform discovery returns no results:
- Check if project uses different IaC tool (CDK, Pulumi, etc.)
- Suggest manual configuration creation
- Offer to set up greenfield faber-cloud config

## No AWS Profiles Found

If AWS discovery returns no profiles:
- Check if using environment variables instead
- Suggest creating profiles for faber-cloud
- Offer profile setup wizard

## Custom Agents Not Version Controlled

If custom scripts not in git:
- WARN user about risk of losing scripts
- Recommend committing before migration
- Offer to backup scripts to .fractary/backup/
</ERROR_HANDLING>

<DOCUMENTATION>
After discovery, create DISCOVERY.md in output directory:

```markdown
# Infrastructure Discovery Report

**Date:** {timestamp}
**Project:** {project_name}

## Terraform Infrastructure

- **Location:** {directory}
- **Structure:** {type}
- **Resources:** {count}
- **Backend:** {backend_type}

## AWS Configuration

- **Profiles:** {count}
- **Environments:** {env_list}
- **Pattern:** {naming_pattern}

## Custom Scripts

- **Total:** {count}
- **Purposes:** {purposes}
- **Tracked:** {tracked}/{total}

## Recommendations

{recommendations_list}

## Next Steps

1. Review this report
2. Proceed to configuration generation
3. Test with read-only operations

---
Generated by faber-cloud infra-adoption
```
</DOCUMENTATION>
