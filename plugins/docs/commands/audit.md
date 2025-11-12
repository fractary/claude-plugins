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
- ✅ Initial setup: Analyze existing documentation and generate setup plan
- ✅ Check documentation compliance with current standards
- ✅ Identify quality issues and gaps
- ✅ Generate actionable remediation plan
- ✅ Audit after standards evolve
- ✅ Regular documentation health checks

**Note**: This command works for both initial setup (analyzing existing docs before fractary-docs config) and ongoing compliance checking.

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

5. **Create GitHub Tracking Issue**
   - Create issue for remediation tracking
   - Capture issue number for spec generation

6. **Generate Remediation Specification** (Only if approved)
   - Create actionable remediation plan via fractary-spec:spec-manager
   - Include executable commands and verification steps
   - Save to `specs/spec-{issue_number}-documentation-remediation.md` (default path, configurable via spec plugin)

7. **Optional Execution** (if --execute flag)
   - Execute high-priority remediations automatically
   - Report results

**User Options After Phase 1:**
- **Save as Spec**: Generate a formal remediation specification using fractary-spec:spec-manager
- **Refine Plan**: Provide feedback to adjust priorities, actions, or scope
- **Hold Off**: Save findings for later without generating spec (discovery reports available)

## Output

The audit produces:

### Phase 1 Outputs (Always Generated)

**Temporary Discovery Reports (JSON)** - Stored in `logs/audits/tmp/`:
- `discovery-docs.json` - Documentation inventory
- `discovery-structure.json` - Organization analysis
- `discovery-frontmatter.json` - Front matter coverage
- `discovery-quality.json` - Quality assessment
- **Note**: These files are temporary and cleaned up after final report generation

**Findings Presentation (Interactive)**:
- Detailed issue breakdown by priority
- Proposed remediation actions
- Estimated effort
- Temporary discovery directory path
- User decision prompt

### Phase 2 Outputs (Generated After "Save as Spec")

**GitHub Tracking Issue**:
- Created automatically for remediation tracking
- Contains audit summary and findings
- Labels: `documentation`, `remediation`, `automated-audit`

**Final Audit Report (Markdown)** - Permanent, tracked by logs-manager:
- `logs/audits/{timestamp}-audit-report.md`
  - Summary with quality score and compliance percentage
  - Key findings by priority
  - References to tracking issue and remediation spec
  - Next steps
  - Managed by `fractary-logs:logs-manager` for trend analysis

**Remediation Specification (Markdown)**:
- `specs/spec-{issue_number}-documentation-remediation.md` - Generated via fractary-spec:spec-manager
  - Path is configurable via spec plugin (default: `specs/` directory)
  - Issue summary by priority
  - Detailed requirements with rationale
  - Phase-based implementation plan
  - Executable commands
  - Verification steps
  - Linked to GitHub tracking issue

**Cleanup**:
- Temporary discovery files in `logs/audits/tmp/` are removed after report generation

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

# Review spec (path returned after generation)
cat specs/spec-123-documentation-remediation.md

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

# Review what changed (path returned after generation)
cat specs/spec-456-documentation-remediation.md

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
  📁 Temporary files: logs/audits/tmp/
  📄 Final report: logs/audits/2025-01-15-143022-audit-report.md
  ✅ Configuration loaded

Step 2: Discovery
  🔍 Scanning documentation...
  🔍 Analyzing structure...
  🔍 Checking front matter...
  🔍 Assessing quality...
  📝 Writing temporary files to: logs/audits/tmp/
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

Step 7: Register Audit Logs
  📋 Registering audit logs via logs-manager agent...
  📋 Using fractary-logs:logs-manager ✓
  ✅ Audit run registered in log tracking system

Step 8: Generate Final Report
  📝 Creating permanent audit report...
  📝 Writing to: logs/audits/2025-01-15-143022-audit-report.md
  🧹 Cleaning up temporary files from logs/audits/tmp/
  ✅ Final report generated

Step 9: Final Summary
  📁 Outputs:
     - Audit Report: logs/audits/2025-01-15-143022-audit-report.md
     - Remediation Spec: specs/spec-456-documentation-remediation.md
     - Tracking Issue: #456

  💡 Next Steps:
     1. Review audit report: logs/audits/2025-01-15-143022-audit-report.md
     2. Review remediation spec: specs/spec-456-documentation-remediation.md
     3. Follow implementation plan
     4. Verify with /fractary-docs:validate
     5. View audit history: logs/audits/
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

Claude: [Creates GitHub tracking issue #789]
        [Generates formal spec via fractary-spec:spec-manager]
        [Spec saved to specs/spec-789-documentation-remediation.md]
```

## Use Cases

### Initial Setup Audit

When setting up fractary-docs for the first time:

```bash
# Analyze existing documentation
/fractary-docs:audit

# Review generated remediation spec
# Follow spec to bring docs into compliance
# Re-run audit to verify completion
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
│   └── state/
│       ├── audit-spec-plugin-status.txt  # Workflow state
│       ├── audit-temp-dir.txt
│       ├── audit-report-path.txt
│       └── audit-timestamp.txt
├── logs/
│   └── audits/
│       ├── 2025-01-15-143022-audit-report.md  # First audit report
│       ├── 2025-01-22-091530-audit-report.md  # Second audit report
│       └── tmp/                                # Temporary discovery files
│           └── (cleaned up after each audit)
└── specs/
    ├── spec-123-documentation-remediation.md  # From first audit
    └── spec-456-documentation-remediation.md  # From second audit
```

**Note**:
- **Permanent audit reports**: `logs/audits/{timestamp}-audit-report.md` (managed by logs-manager)
- **Temporary discovery files**: `logs/audits/tmp/` (cleaned up after each audit)
- **Spec files**: `specs/` directory (configurable via spec plugin)
- **Workflow state**: `.fractary/state/` (ephemeral, not logged)
- Each audit produces one permanent report with unique timestamp

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

1. **Review the spec** (path displayed after generation)
   ```bash
   # Example: cat specs/spec-456-documentation-remediation.md
   cat specs/spec-{issue_number}-documentation-remediation.md
   ```

2. **Review audit reports** (useful for understanding findings)
   ```bash
   # View latest audit report
   cat logs/audits/$(ls -t logs/audits/*.md | head -1)

   # List all audit reports
   ls -ltr logs/audits/*.md
   ```

3. **Execute high-priority fixes**
   - Follow Phase 1 in spec
   - Copy/paste commands or execute manually
   - Verify each fix

4. **Schedule remaining work**
   - Medium priority: Plan for next sprint
   - Low priority: Backlog for future improvement

5. **Verify compliance**
   ```bash
   /fractary-docs:validate
   /fractary-docs:link check
   ```

6. **Commit improvements**
   ```bash
   git add .
   git commit -m "docs: address audit findings"
   ```

## Viewing Audit History

Since audits are logged over time with timestamps, you can track compliance trends:

```bash
# List all audit runs (sorted by date)
ls -ltr logs/audits/*.md

# View a specific audit report
cat logs/audits/2025-01-15-143022-audit-report.md

# View the latest audit report
cat logs/audits/$(ls -t logs/audits/*.md | head -1)

# Compare audit reports over time to track improvements
diff logs/audits/2025-01-15-143022-audit-report.md logs/audits/2025-01-22-091530-audit-report.md
```

**Note**: Temporary discovery JSON files in `logs/audits/tmp/` are cleaned up after each audit. Only the permanent markdown audit reports with timestamps are retained for historical tracking.

**Trend Analysis**: The logs-manager agent tracks audit metadata, enabling you to:
- See how documentation quality improves over time
- Identify recurring compliance issues
- Track remediation progress
- Generate compliance reports

## Requirements

Before running audit:

- Documentation files present in project
- Git repository (recommended for version control)
- No pending documentation changes (commit first)

**Note**: fractary-docs configuration is optional. Audit works for:
- **Initial setup**: Analyzing docs before configuration (generates setup plan)
- **Ongoing compliance**: Checking configured docs against standards

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
4. Verify: Temporary discovery reports saved to `logs/audits/tmp/`
5. Verify: No final audit report generated (no permanent `.md` file)
6. Verify: No spec generated
7. Verify: No GitHub issue created
8. Verify: Workflow stops gracefully

**Expected Result:** Temporary findings saved, no formal spec or report generated, workflow stops gracefully

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

USE AGENT: @agent-fractary-docs:docs-manager
Operation: audit
Parameters: {
  project_root: <from --project-root parameter, defaults to current directory>,
  execute: <from --execute parameter, defaults to false>
}
