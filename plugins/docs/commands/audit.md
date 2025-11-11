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

## What This Does

### Documentation Audit Workflow

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

4. **Generate Remediation Specification**
   - Prioritize issues (high, medium, low)
   - Create actionable remediation plan
   - **Uses fractary-spec plugin** if available for standardized spec
   - Include executable commands and verification steps

5. **Optional Execution** (if --execute flag)
   - Execute high-priority remediations automatically
   - Report results

## Output

The audit produces:

### Remediation Specification (Markdown)
- `REMEDIATION-SPEC.md` - Actionable plan to fix issues
  - Issue summary by priority
  - Detailed requirements with rationale
  - Phase-based implementation plan
  - Executable commands
  - Verification steps

### Discovery Reports (JSON)
- `discovery-docs.json` - Documentation inventory
- `discovery-structure.json` - Organization analysis
- `discovery-frontmatter.json` - Front matter coverage
- `discovery-quality.json` - Quality assessment

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

Step 4: Spec Generation
  📝 Generating remediation spec...
  📝 Using fractary-spec plugin ✓
  📝 Creating actionable plan...
  ✅ REMEDIATION-SPEC.md generated

Step 5: Summary
  📋 Audit Results:
     - Total Documents: 23
     - Issues Found: 12 (5 high, 5 medium, 2 low)
     - Quality Score: 7.2/10
     - Compliance: 68%

  📁 Outputs:
     - Spec: .fractary/audit/REMEDIATION-SPEC.md
     - Reports: .fractary/audit/discovery-*.json

  💡 Next Steps:
     1. Review remediation spec
     2. Follow implementation plan
     3. Verify with /fractary-docs:validate
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

## Invocation

This command invokes the `docs-manager` agent with the `audit` operation.

USE AGENT: docs-manager with operation=audit, project-root from --project-root parameter (defaults to current directory), and execute from --execute parameter (defaults to false)
