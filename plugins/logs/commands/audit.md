---
name: fractary-logs:audit
description: Audit logs in project and generate plan to manage them with Universal Log Manager
examples:
  - /fractary-logs:audit
  - /fractary-logs:audit --project-root ./my-project
  - /fractary-logs:audit --execute
argument-hint: "[--project-root <path>] [--execute]"
---

# Audit Command

Audit existing logs and log-like files in project, identify what should be managed by the Universal Log Manager, and generate actionable remediation specification.

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-logs:audit
/fractary-logs:audit --project-root ./my-project
/fractary-logs:audit --execute

# Incorrect ❌
/fractary-logs:audit --project-root=./my-project
/fractary-logs:audit --execute=true
```
</ARGUMENT_SYNTAX>

## Usage

```bash
/fractary-logs:audit [--project-root <path>] [--execute]
```

## When to Use This Command

**Use `/fractary-logs:audit` to:**
- ✅ Identify logs that should be managed by fractary-logs
- ✅ Find logs in version control that should be in cloud storage
- ✅ Generate plan to adopt Universal Log Manager
- ✅ Calculate storage savings from hybrid retention
- ✅ Regular log management health checks

**Use `/fractary-logs:init` instead if:**
- ⚠️ First-time setup (no config yet)
- ⚠️ Just want to create configuration

## Parameters

- `--project-root`: Root directory to audit. **Defaults to current directory.**
- `--execute`: Execute high-priority remediations immediately after audit. Defaults to false (generate spec only).

## What This Does

### Log Audit Workflow

1. **Load Configuration**
   - Load fractary-logs configuration (if exists)
   - Determine log management strategy
   - Load .gitignore patterns

2. **Discover Current State**
   - Scan all log files and log-like files
   - Identify logs in version control
   - Find build outputs, deployment logs, debug files
   - Analyze log sizes and storage usage
   - Check existing log management

3. **Analyze Against Best Practices**
   - **Managed logs**: Logs under fractary-logs management
   - **Unmanaged logs**: Logs that should be managed but aren't
   - **VCS logs**: Logs in version control that should be archived
   - **Storage waste**: Calculate potential savings

4. **Generate Remediation Specification**
   - Prioritize actions (high, medium, low)
   - Create actionable plan to adopt Universal Log Manager
   - Include commands to move logs to managed locations
   - Add .gitignore entries
   - Configure archival to cloud storage
   - Initial archive of historical logs

5. **Optional Execution** (if --execute flag)
   - Execute high-priority remediations automatically
   - Report results

## Output

The audit produces **two separate documents** plus discovery data:

### 1. Audit Report (Assessment)
**File**: `AUDIT-REPORT.md`
- Executive summary with quick stats
- Current state assessment
- Standard definition
- Gap analysis (current vs standard)
- Recommendations by priority
- Benefits of remediation

**Purpose**: Understand what's wrong and why.

### 2. Remediation Specification (Action Plan)
**File**: `REMEDIATION-SPEC.md` (via Spec Manager)
- Overview with current/target state
- Detailed requirements
- 4-phase implementation plan
- Executable commands
- Verification steps
- Acceptance criteria

**Purpose**: Know exactly how to fix it.

### 3. Discovery Data (JSON)
- `discovery-logs.json` - Log file inventory
- `discovery-vcs-logs.json` - Logs in version control
- `discovery-patterns.json` - Log patterns identified
- `discovery-storage.json` - Storage analysis

**Key Distinction:**
- **Audit Report** = Assessment (what's wrong)
- **Remediation Spec** = Action plan (how to fix)

## Examples

**Basic audit in current directory:**
```bash
cd /path/to/my-project
/fractary-logs:audit
```

**Audit specific project:**
```bash
/fractary-logs:audit --project-root ./services/api
```

**Audit and execute high-priority fixes:**
```bash
/fractary-logs:audit --execute
```

**Regular compliance check:**
```bash
# Run monthly or when logs accumulate
/fractary-logs:audit

# Review spec
cat .fractary/audit/REMEDIATION-SPEC.md

# Execute in separate session if needed
```

## Audit Scenarios

### Scenario 1: First-Time Adoption

**Situation:**
- Project has many unmanaged logs
- Some logs committed to version control
- Want to adopt Universal Log Manager

**Workflow:**
```bash
# Audit to identify all logs
/fractary-logs:audit

# Review what needs to be done
cat .fractary/audit/REMEDIATION-SPEC.md

# Follow spec to adopt fractary-logs management
```

### Scenario 2: Logs in Version Control

**Situation:**
- Build logs, deployment logs in Git
- Repository size growing
- Need to move to cloud storage

**Workflow:**
```bash
# Audit to find VCS logs
/fractary-logs:audit

# Spec will show which logs to archive
# and how to configure cloud storage

# Execute to archive and remove from VCS
/fractary-logs:audit --execute
```

### Scenario 3: Regular Health Check

**Situation:**
- Monthly check for log management
- Ensure logs properly archived
- Check for storage waste

**Workflow:**
```bash
# Audit current state
/fractary-logs:audit

# Review findings
# Address any new unmanaged logs
```

## Interactive Workflow

```
Step 1: Loading Configuration
  📖 Configuration: .fractary/plugins/logs/config.json
  📖 .gitignore patterns loaded
  ✅ Configuration loaded

Step 2: Discovery
  🔍 Scanning for log files...
  🔍 Checking version control...
  🔍 Analyzing storage...
  🔍 Identifying patterns...
  ✅ Discovery complete

Step 3: Define Standard
  📋 Defining fractary-logs best practices...
  📋 Standard configuration and structure...
  ✅ Standard defined

Step 4: Gap Analysis
  📊 Comparing current vs standard...
  📊 Identifying gaps by priority...
  📊 Calculating storage savings...
  ✅ Gap analysis complete

Step 5: Generate Audit Report
  📝 Documenting current state...
  📝 Writing gap analysis...
  📝 Adding recommendations...
  ✅ AUDIT-REPORT.md generated

Step 6: Generate Remediation Spec
  📝 Invoking Spec Manager agent...
  📝 Creating 4-phase implementation plan...
  📝 Adding executable commands...
  ✅ REMEDIATION-SPEC.md generated

Step 7: Summary
  📋 Audit Results:
     - Total Logs: 45 files (2.3 GB)
     - Managed: 3 files (150 MB)
     - Unmanaged: 42 files (2.15 GB)
     - In VCS: 12 files (450 MB)
     - Gaps: 14 (8 high, 4 medium, 2 low)
     - Potential Savings: 1.9 GB from repo

  📁 Outputs:
     - Audit Report: .fractary/audit/AUDIT-REPORT.md
     - Remediation Spec: .fractary/audit/REMEDIATION-SPEC.md
     - Discovery Data: .fractary/audit/discovery-*.json

  💡 Next Steps:
     1. Review audit report (assessment)
     2. Review remediation spec (action plan)
     3. Follow 4-phase implementation
     4. Verify with search command
```

## Use Cases

### Adopt Universal Log Manager

After project has accumulated many logs:

```bash
# Audit to create adoption plan
/fractary-logs:audit

# Follow spec to:
# - Configure cloud storage
# - Move logs to managed locations
# - Archive historical logs
# - Update .gitignore
```

### Clean Up Repository

Remove logs from version control:

```bash
# Audit to find VCS logs
/fractary-logs:audit

# Spec shows how to:
# - Archive logs to cloud
# - Remove from Git history
# - Save repository space
```

### Regular Maintenance

Ensure logs properly managed:

```bash
# Monthly audit
/fractary-logs:audit

# Address any unmanaged logs
# Verify archival working correctly
```

## What Gets Created

### Directory Structure

```
project/
├── .fractary/
│   └── audit/
│       ├── AUDIT-REPORT.md          # Current state + gap analysis
│       ├── REMEDIATION-SPEC.md      # Actionable implementation plan
│       ├── discovery-logs.json
│       ├── discovery-vcs-logs.json
│       ├── discovery-patterns.json
│       └── discovery-storage.json
```

### Audit Report (AUDIT-REPORT.md)

The assessment document contains:

- **Executive Summary**: Quick stats and compliance level
- **Current State**: What logs exist, where they are, how they're managed
- **Standard Definition**: What proper fractary-logs management looks like
- **Gap Analysis**: Detailed comparison of current vs standard
  - Configuration gaps
  - Directory structure gaps
  - Version control gaps
  - Archival gaps
  - Integration gaps
  - Storage gaps
- **Recommendations**: Prioritized actions (high/medium/low)
- **Benefits**: Storage savings, cost estimates, improvements

**Purpose**: Understand the current situation and what needs to change.

### Remediation Specification (REMEDIATION-SPEC.md)

The action plan document contains:

- **Overview**: Current vs target state summary
- **Requirements**: Detailed actions needed with rationale
- **Implementation Plan**: 4-phase approach
  - Phase 1: Configure cloud storage (fractary-file)
  - Phase 2: Set up log management (fractary-logs)
  - Phase 3: Archive historical logs
  - Phase 4: Configure auto-capture
- **Each Task Includes**:
  - Task ID and title
  - Executable commands (copy/paste ready)
  - Verification steps
- **Acceptance Criteria**: Checklist for completion
- **Verification Steps**: Final validation commands

**Purpose**: Step-by-step guide to bring logs into compliance.

**Key Features:**
- ✅ Generated by Spec Manager agent (standardized format)
- ✅ Human-readable and editable
- ✅ Contains copy/paste commands
- ✅ Organized by priority and phase
- ✅ Includes cloud storage setup
- ✅ Shows storage savings
- ✅ Can be committed to version control

## After Audit

Follow this process to adopt log management:

1. **Review the audit report** (understand what needs to change)
   ```bash
   cat .fractary/audit/AUDIT-REPORT.md
   ```

2. **Review the remediation spec** (understand how to change it)
   ```bash
   cat .fractary/audit/REMEDIATION-SPEC.md
   ```

3. **Execute Phase 1** (Configure cloud storage)
   - Set up fractary-file plugin
   - Configure S3/R2 bucket
   - Test connection

4. **Execute Phase 2** (Set up log management)
   - Initialize fractary-logs
   - Move logs to managed locations
   - Update .gitignore

5. **Execute Phase 3** (Archive historical logs)
   - Archive existing logs to cloud
   - Remove logs from VCS (if applicable)
   - Verify archival

6. **Execute Phase 4** (Configure auto-capture)
   - Set up build log capture
   - Set up deployment log capture
   - Test auto-capture

7. **Verify setup**
   ```bash
   /fractary-logs:search "test"
   git status  # Should show no log files
   ```

8. **Commit configuration**
   ```bash
   git add .fractary/plugins/logs/config.json .gitignore
   git commit -m "feat: adopt fractary-logs for log management"
   ```

## Benefits of Universal Log Manager

**Hybrid Retention Strategy:**
- 📁 Local: Recent logs (30 days) for fast access
- ☁️ Cloud: Historical logs archived permanently
- 🔍 Searchable: Index makes cloud logs searchable
- 💰 Cost-effective: Repository stays small

**Version Control Benefits:**
- Keep repo size down
- Logs never lost (archived to cloud)
- No accidental commits of sensitive logs
- Historical logs still accessible

**Operational Benefits:**
- Centralized log management
- Automatic archival on issue close
- Compression reduces storage costs
- Search across all logs (local + cloud)

## Requirements

Before running audit:

- Project with logs or log-like files
- Optional: fractary-logs configuration (will suggest if missing)
- Optional: fractary-file configured for cloud storage

## Next Steps After Audit

1. **Review remediation spec thoroughly**
2. **Set up cloud storage (if not configured)**
3. **Follow phase-based implementation plan**
4. **Archive historical logs to cloud**
5. **Verify with search and read commands**
6. **Re-audit to confirm compliance**

## Invocation

This command invokes the `log-manager` agent with the `audit` operation.

USE AGENT: log-manager with operation=audit, project-root from --project-root parameter (defaults to current directory), and execute from --execute parameter (defaults to false)
