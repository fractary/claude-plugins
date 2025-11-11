---
name: fractary-docs:audit
description: Audit documentation against standards and generate remediation plan
examples:
  - /fractary-docs:audit
  - /fractary-docs:audit --project-root ./services/api
  - /fractary-docs:audit --execute
argument-hint: "[--project-root <path>] [--execute]"
---

# Audit Command

Audit documentation against fractary-docs standards and generate actionable remediation specification.

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-docs:audit
/fractary-docs:audit --project-root ./my-project
/fractary-docs:audit --execute

# Incorrect ❌
/fractary-docs:audit --project-root=./my-project
/fractary-docs:audit --execute=true
```
</ARGUMENT_SYNTAX>

## Usage

```bash
/fractary-docs:audit [--project-root <path>] [--execute]
```

## When to Use This Command

**Use `/fractary-docs:audit` to:**
- ✅ Check documentation compliance with current standards
- ✅ Identify quality issues and gaps
- ✅ Generate actionable remediation plan
- ✅ Audit after standards evolve
- ✅ Regular documentation health checks

**Use `/fractary-docs:adopt` instead if:**
- ⚠️ First-time adoption (no fractary-docs config yet)
- ⚠️ Need to migrate custom document agent
- ⚠️ Need to generate initial configuration

## Parameters

- `--project-root`: Root directory to audit. **Defaults to current directory.**
- `--execute`: Execute high-priority remediations immediately after audit. Defaults to false (generate spec only).

## Requirements

**For Spec Generation (Phase 2)**:
- **fractary-spec plugin** must be installed
- Spec generation uses `fractary-spec:spec-manager`
- Without it, audit still runs and presents findings, but cannot save as formal spec
- Install fractary-spec to enable "Save as Spec" option

## What This Does

### Two-Phase Interactive Audit Workflow

**IMPORTANT**: This command uses a two-phase workflow with mandatory user approval:

#### Phase 1: Analysis & Presentation (Automatic)

1. **Load Configuration & Standards**
   - Load fractary-docs configuration
   - Load project-specific standards (if configured)
   - Determine applicable validation rules

2. **Discover Current State**
   - Scan all documentation files
   - Analyze organization and structure
   - Check front matter coverage
   - Assess quality scores

3. **Compare Against Standards**
   - **Plugin standards**: Front matter, organization, required sections
   - **Project standards**: Custom rules from project standards doc
   - Identify compliance gaps and issues

4. **Present Findings for Review**
   - Show detailed findings and proposed actions
   - Display priority breakdown (high, medium, low)
   - Estimate effort required
   - **PAUSE for user approval**

#### Phase 2: Specification Generation (After Approval)

5. **Generate Remediation Specification** (Only if approved)
   - Create actionable remediation plan
   - **Uses fractary-spec plugin** if available for standardized spec
   - Include executable commands and verification steps
   - Save to `.fractary/audit/REMEDIATION-SPEC.md`

6. **Optional Execution** (if --execute flag)
   - Execute high-priority remediations automatically
   - Report results

**User Options After Phase 1:**
- **Save as Spec**: Generate a formal remediation specification using fractary-spec:spec-manager
- **Refine Plan**: Provide feedback to adjust priorities, actions, or scope
- **Hold Off**: Save findings for later without generating spec (discovery reports available)

## Output

The audit produces:

### Phase 1 Outputs (Always Generated)

**Discovery Reports (JSON)**:
- `discovery-docs.json` - Documentation inventory
- `discovery-structure.json` - Organization analysis
- `discovery-frontmatter.json` - Front matter coverage
- `discovery-quality.json` - Quality assessment

**Findings Presentation (Interactive)**:
- Detailed issue breakdown by priority
- Proposed remediation actions
- Estimated effort
- User decision prompt

### Phase 2 Outputs (Generated After "Save as Spec")

**Remediation Specification (Markdown)**:
- `REMEDIATION-SPEC.md` - Generated via fractary-spec:spec-manager
  - Issue summary by priority
  - Detailed requirements with rationale
  - Phase-based implementation plan
  - Executable commands
  - Verification steps

## Examples

**Basic audit in current directory:**
```bash
cd /path/to/my-project
/fractary-docs:audit
```

**Audit specific project:**
```bash
/fractary-docs:audit --project-root ./services/api
```

**Audit and execute high-priority fixes:**
```bash
/fractary-docs:audit --execute
```

**Regular compliance check:**
```bash
# Run weekly or after standards updates
/fractary-docs:audit

# Review spec
cat .fractary/audit/REMEDIATION-SPEC.md

# Execute in separate session if needed
```

## Audit Scenarios

### Scenario 1: After Standards Update

**Situation:**
- Plugin standards evolved
- Need to update docs to new requirements

**Workflow:**
```bash
# Audit against new standards
/fractary-docs:audit

# Review what changed
cat .fractary/audit/REMEDIATION-SPEC.md

# Follow spec to update docs
```

### Scenario 2: Regular Compliance Check

**Situation:**
- Quarterly documentation review
- Check for quality drift

**Workflow:**
```bash
# Audit current state
/fractary-docs:audit

# Review issues found
# Address high-priority items
# Schedule medium/low priority for later
```

### Scenario 3: After Major Documentation Changes

**Situation:**
- Added many new docs
- Merged documentation from another project
- Need to ensure compliance

**Workflow:**
```bash
# Audit to identify issues
/fractary-docs:audit

# Auto-fix high-priority
/fractary-docs:audit --execute

# Manually review remaining issues
```

## Interactive Workflow

### Phase 1: Analysis & Presentation

```
Step 1: Loading Configuration
  📖 Configuration: .fractary/plugins/docs/config/config.json
  📖 Project Standards: docs/DOCUMENTATION-STANDARDS.md
  ✅ Configuration loaded

Step 2: Discovery
  🔍 Scanning documentation...
  🔍 Analyzing structure...
  🔍 Checking front matter...
  🔍 Assessing quality...
  ✅ Discovery complete

Step 3: Analysis
  📊 Comparing against standards...
  📊 Identifying issues...
  📊 Prioritizing actions...
  ✅ Analysis complete

Step 4: Findings Presentation
  📋 Audit Findings:
     - Total Documents: 23
     - Issues Found: 12 (5 high, 5 medium, 2 low)
     - Quality Score: 7.2/10
     - Compliance: 68%

  📋 Proposed Remediation Actions:
     [Detailed list of actions by priority]

  ⏱️ Estimated Effort: 8 hours

  💡 What would you like to do next?
     1. Save as Spec → Generate formal spec via spec-manager agent
     2. Refine Plan → Adjust priorities/actions/scope
     3. Hold Off → Save findings for later

  ⏸️  PAUSED - Awaiting your decision
```

### Phase 2: Specification Generation (After "Save as Spec")

```
Step 5: Create Tracking Issue
  🎫 Creating GitHub issue for remediation tracking...
  🎫 Issue #456 created: "Documentation Remediation - myproject"
  ✅ Tracking issue ready

Step 6: Generate Spec
  📝 Generating remediation spec via spec-manager agent...
  📝 Using fractary-spec:spec-manager with issue #456 ✓
  📝 Creating formal specification...
  ✅ specs/spec-456-documentation-remediation.md generated

Step 7: Final Summary
  📁 Outputs:
     - Spec: specs/spec-456-documentation-remediation.md
     - Issue: #456 (tracking)
     - Reports: .fractary/audit/discovery-*.json

  💡 Next Steps:
     1. Review remediation spec
     2. Follow implementation plan
     3. Verify with /fractary-docs:validate
```

### Workflow Without Spec Plugin

If `fractary-spec` plugin is not installed:

```
Step 1: Loading Configuration
  📖 Configuration: .fractary/plugins/docs/config/config.json
  ⚠️  WARNING: fractary-spec plugin not found
  ⚠️  Audit will present findings, but cannot generate formal spec
  ✅ Configuration loaded

Step 2-3: Discovery and Analysis
  [Same as above]

Step 4: Findings Presentation
  📋 Audit Findings:
     - Total Documents: 23
     - Issues Found: 12 (5 high, 5 medium, 2 low)
     - Quality Score: 7.2/10
     - Compliance: 68%

  📋 Proposed Remediation Actions:
     [Detailed list of actions by priority]

  ⏱️ Estimated Effort: 8 hours

  ⚠️  Note: fractary-spec plugin not installed - cannot generate formal spec

  💡 What would you like to do next?
     1. Refine Plan → Adjust priorities/actions/scope
     2. Hold Off → Save findings for later

     To enable spec generation, install fractary-spec plugin first.

  ⏸️  Workflow complete - Discovery reports available
```

## Revision Workflow

If you want to adjust the proposed remediation actions after seeing Phase 1 findings:

1. **Review the findings**: Examine the proposed actions, priorities, and estimated effort
2. **Provide feedback**: Tell Claude what you'd like to adjust:
   - Change priority of specific actions
   - Remove actions that aren't needed
   - Add additional remediation actions
   - Adjust scope or approach
3. **Approve revised plan**: Once you're satisfied with the adjustments
4. **Generate spec**: Claude will then generate the spec with your revisions

**Example revision conversation:**
```
You: I'd like to refine the plan. Can we:
     1. Move "Add missing ADR sections" from high to medium priority
     2. Remove the action to reorganize all files (too disruptive right now)
     3. Add an action to set up automated validation

Claude: [Presents revised findings with your changes]
        [Shows updated priority breakdown and effort estimate]

You: That looks great, please save as spec

Claude: [Generates formal spec via fractary-spec:spec-manager]
        [Spec saved to .fractary/audit/REMEDIATION-SPEC.md]
```

## Use Cases

### Initial Post-Adoption Audit

After adopting fractary-docs, verify everything is compliant:

```bash
# After following adoption spec
/fractary-docs:audit

# Should show minimal issues
# Address any remaining compliance gaps
```

### Continuous Compliance

Regular audits to maintain documentation quality:

```bash
# Weekly or monthly
/fractary-docs:audit

# Track compliance trends over time
# Address quality drift proactively
```

### Before Major Releases

Ensure documentation is release-ready:

```bash
# Pre-release audit
/fractary-docs:audit --execute

# Fix critical issues automatically
# Manually review remaining items
```

## What Gets Created

### Directory Structure

```
project/
├── .fractary/
│   └── audit/
│       ├── discovery-docs.json
│       ├── discovery-structure.json
│       ├── discovery-frontmatter.json
│       ├── discovery-quality.json
│       └── REMEDIATION-SPEC.md
```

### Remediation Specification

The spec contains:

- **Overview**: Current vs target state
- **Requirements**: Prioritized issues with rationale
- **Implementation Plan**: Phase-based with executable commands
- **Acceptance Criteria**: Checklist for completion
- **Verification Steps**: Commands to verify fixes

**Key Features:**
- ✅ Human-readable and editable
- ✅ Contains copy/paste commands
- ✅ Organized by priority and phase
- ✅ Includes verification steps
- ✅ Can be committed to version control

## After Audit

Follow the remediation spec to address issues:

1. **Review the spec**
   ```bash
   cat .fractary/audit/REMEDIATION-SPEC.md
   ```

2. **Execute high-priority fixes**
   - Follow Phase 1 in spec
   - Copy/paste commands or execute manually
   - Verify each fix

3. **Schedule remaining work**
   - Medium priority: Plan for next sprint
   - Low priority: Backlog for future improvement

4. **Verify compliance**
   ```bash
   /fractary-docs:validate
   /fractary-docs:link check
   ```

5. **Commit improvements**
   ```bash
   git add .
   git commit -m "docs: address audit findings"
   ```

## Comparison: Audit vs Adopt

| Feature | Audit | Adopt |
|---------|-------|-------|
| **Purpose** | Check compliance | Initial migration |
| **Config Required** | Yes | No (generates config) |
| **Custom Agent Migration** | No | Yes |
| **When to Use** | Ongoing compliance | First time setup |
| **Output** | Remediation spec | Config + remediation spec |

## Requirements

Before running audit:

- fractary-docs must be configured
- Configuration at `.fractary/plugins/docs/config/config.json`
- Documentation files present in project

## Next Steps After Audit

1. **Review remediation spec thoroughly**
2. **Address high-priority issues first**
3. **Follow phase-based implementation plan**
4. **Verify fixes with validation**
5. **Re-audit to confirm compliance**

## Testing the Audit Workflow

### Test Case 1: Happy Path (Full Workflow)

**Prerequisites:**
- fractary-spec plugin installed
- fractary-docs configured
- Documentation files present
- GitHub credentials configured

**Steps:**
1. Run: `/fractary-docs:audit`
2. Verify: Findings presentation shows issues and options
3. Action: Choose "Save as Spec"
4. Verify: GitHub issue created
5. Verify: Spec file generated in `specs/` directory
6. Verify: Spec linked to GitHub issue

**Expected Result:** Complete audit with formal spec generated

### Test Case 2: Refinement Workflow

**Prerequisites:** Same as Test Case 1

**Steps:**
1. Run: `/fractary-docs:audit`
2. Verify: Findings presentation appears
3. Action: Choose "Refine Plan"
4. Action: Request priority changes (e.g., "Move action X from high to medium")
5. Verify: Updated findings presentation with changes
6. Action: Choose "Save as Spec"
7. Verify: Spec reflects refined priorities

**Expected Result:** Spec reflects user refinements

### Test Case 3: Hold Off (Cancel)

**Prerequisites:** Same as Test Case 1

**Steps:**
1. Run: `/fractary-docs:audit`
2. Verify: Findings presentation appears
3. Action: Choose "Hold Off"
4. Verify: Discovery reports saved to `.fractary/audit/`
5. Verify: No spec generated
6. Verify: No GitHub issue created

**Expected Result:** Findings saved, workflow stops gracefully

### Test Case 4: Missing Spec Plugin

**Prerequisites:**
- fractary-spec plugin NOT installed
- fractary-docs configured
- Documentation files present

**Steps:**
1. Run: `/fractary-docs:audit`
2. Verify: Warning about missing spec plugin
3. Verify: Findings presentation appears
4. Verify: Only "Refine Plan" and "Hold Off" options (no "Save as Spec")
5. Action: Try to refine plan
6. Verify: Refinement works without spec plugin

**Expected Result:** Audit completes, findings available, spec generation unavailable

### Test Case 5: No Documentation Found

**Prerequisites:**
- Empty or no docs directory

**Steps:**
1. Run: `/fractary-docs:audit`
2. Verify: Error message about no documentation found
3. Verify: Suggestion to create documentation first

**Expected Result:** Clear error with guidance

## Invocation

This command invokes the `docs-manager` agent with the `audit` operation.

USE AGENT: docs-manager with operation=audit, project-root from --project-root parameter (defaults to current directory), and execute from --execute parameter (defaults to false)
