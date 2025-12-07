# Report Generation Workflow

This document defines how end-of-workflow reports are generated from aggregated responses.

## Overview

At workflow completion, a report is generated showing:
1. Phase summary with status icons
2. Warnings organized by phase/step and by category
3. Errors with analysis and suggested fixes
4. Recommended actions prioritized by severity
5. Interactive options to apply fixes

---

## Report Formats

### Summary Format (Default)

Standard report for most workflows. Shows:
- Phase summary table
- Warnings by phase/step
- Warnings by category
- Errors with details
- Recommended actions

### Detailed Format

Extended report including:
- All of summary format
- Success messages from each step
- Full `details` objects
- Timing breakdown per step
- Complete artifact list

### Minimal Format

Concise report for quick review:
- Phase summary only
- Total warning/error counts
- No individual issue listing
- Final status and artifacts

---

## Report Generation

### Trigger

```pseudocode
FUNCTION generateEndOfWorkflowReport(context):
  # Read workflow execution log
  workflow_log = readWorkflowExecutionLog(context.run_id)

  # Determine report format
  format = context.report_format ?? "summary"

  SWITCH format:
    CASE "detailed":
      RETURN generateDetailedReport(workflow_log, context)
    CASE "minimal":
      RETURN generateMinimalReport(workflow_log, context)
    DEFAULT:
      RETURN generateSummaryReport(workflow_log, context)
```

### Summary Report Template

```pseudocode
FUNCTION generateSummaryReport(log, context):
  report = """
┌─────────────────────────────────────────────────────────────────────────────┐
│                         WORKFLOW EXECUTION REPORT                           │
├─────────────────────────────────────────────────────────────────────────────┤
│  Target: {log.target}                                                       │
│  Work Item: #{log.work_id}                                                  │
│  Duration: {formatDuration(log.duration_ms)}                                │
│  Status: {getStatusEmoji(log.final_status)} {log.final_status}              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE SUMMARY                                                              │
│  ─────────────                                                              │
"""

  # Add phase rows
  FOR each phase in ["frame", "architect", "build", "evaluate", "release"]:
    summary = log.phases_summary[phase]
    report += formatPhaseRow(phase, summary)

  report += """
├─────────────────────────────────────────────────────────────────────────────┤
"""

  # Add warnings section if any
  IF log.totals.warnings > 0 THEN
    report += formatWarningsSection(log.aggregated_warnings)

  # Add by-category section
  IF log.totals.warnings > 0 THEN
    report += formatWarningsByCategory(log)

  # Add errors section if any
  IF log.totals.errors > 0 THEN
    report += formatErrorsSection(log.aggregated_errors)

  # Add recommended actions
  IF log.recommended_actions.length > 0 THEN
    report += formatRecommendedActions(log.recommended_actions)

  # Add artifacts
  report += formatArtifacts(log.artifacts)

  report += """
└─────────────────────────────────────────────────────────────────────────────┘
"""

  RETURN report
```

---

## Phase Summary Formatting

```pseudocode
FUNCTION formatPhaseRow(phase, summary):
  emoji = getPhaseStatusEmoji(summary.status)
  steps_display = "{summary.steps_succeeded}/{summary.steps_total} steps"

  extras = []
  IF summary.warnings > 0 THEN
    extras.push("{summary.warnings} warning(s)")
  IF summary.errors > 0 THEN
    extras.push("{summary.errors} error(s)")

  extra_text = extras.length > 0 ? ", " + extras.join(", ") : ""

  RETURN "│  {emoji} {capitalize(phase)}  {steps_display}{extra_text}"


FUNCTION getPhaseStatusEmoji(status):
  SWITCH status:
    CASE "success": RETURN "✅"
    CASE "warning": RETURN "⚠️"
    CASE "failure": RETURN "❌"
    CASE "skipped": RETURN "⏭️"
    CASE "not_run": RETURN "⬜"
    DEFAULT: RETURN "❓"
```

---

## Warnings Section

### By Phase/Step

```pseudocode
FUNCTION formatWarningsSection(warnings):
  section = """
│  WARNINGS BY PHASE/STEP ({warnings.length})                                 │
│  ──────────────────────────                                                 │
"""

  # Group by phase:step
  grouped = groupBy(warnings, w => w.step_id)

  FOR each [step_id, step_warnings] in grouped:
    FOR each warning in step_warnings:
      section += """
│                                                                             │
│  📍 {warning.step_id} [{warning.severity}] [{warning.category}]             │
│     {warning.text}                                                          │
"""
      IF warning.analysis THEN
        section += "│     └─ Analysis: {warning.analysis}\n"

      IF warning.suggested_fix THEN
        section += "│     └─ Fix: {warning.suggested_fix}\n"

  RETURN section
```

### By Category

```pseudocode
FUNCTION formatWarningsByCategory(log):
  section = """
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  WARNINGS BY CATEGORY                                                       │
│  ────────────────────                                                       │
"""

  # Group warnings by category
  by_category = groupBy(log.aggregated_warnings, w => w.category)

  FOR each [category, warnings] in by_category:
    step_ids = unique(warnings.map(w => w.step_id)).join(", ")
    section += "│  {category} ({warnings.length}): {step_ids}\n"

  RETURN section
```

---

## Errors Section

```pseudocode
FUNCTION formatErrorsSection(errors):
  section = """
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ERRORS ({errors.length})                                                   │
│  ─────────────────                                                          │
"""

  FOR each error in errors:
    section += """
│                                                                             │
│  ❌ {error.step_id} [{error.severity}] [{error.category}]                   │
│     {error.text}                                                            │
"""
    IF error.analysis THEN
      section += "│     └─ Analysis: {error.analysis}\n"

    IF error.suggested_fix THEN
      section += "│     └─ Fix: {error.suggested_fix}\n"

  RETURN section
```

---

## Recommended Actions

### Prioritization

Actions are prioritized by:
1. Severity (high > medium > low)
2. Category priority (security > compatibility > deprecation > others)
3. Phase order (earlier phases first)

```pseudocode
FUNCTION buildRecommendedActions(warnings, errors):
  actions = []

  # Process errors first (higher priority)
  FOR each error in errors:
    IF error.suggested_fix THEN
      actions.push({
        priority: calculatePriority(error, "error"),
        description: error.suggested_fix,
        source_step: error.step_id,
        type: "error_fix"
      })

  # Process warnings
  FOR each warning in warnings:
    IF warning.suggested_fix THEN
      actions.push({
        priority: calculatePriority(warning, "warning"),
        description: warning.suggested_fix,
        source_step: warning.step_id,
        type: "warning_fix"
      })

  # Sort by priority
  actions.sort((a, b) => a.priority - b.priority)

  # Add numeric priority
  FOR each action in actions with index:
    action.priority = index + 1

  RETURN actions


FUNCTION calculatePriority(item, type):
  base_priority = type == "error" ? 0 : 1000  # Errors before warnings

  severity_weight = SWITCH item.severity:
    CASE "high": 0
    CASE "medium": 100
    CASE "low": 200
    DEFAULT: 150

  category_weight = SWITCH item.category:
    CASE "security": 0
    CASE "compatibility": 10
    CASE "deprecation": 20
    CASE "validation": 30
    CASE "performance": 40
    CASE "configuration": 50
    CASE "style": 60
    CASE "other": 70
    DEFAULT: 50

  phase_weight = SWITCH item.phase:
    CASE "frame": 0
    CASE "architect": 1
    CASE "build": 2
    CASE "evaluate": 3
    CASE "release": 4
    DEFAULT: 5

  RETURN base_priority + severity_weight + category_weight + phase_weight
```

### Formatting

```pseudocode
FUNCTION formatRecommendedActions(actions):
  section = """
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  RECOMMENDED ACTIONS                                                        │
│  ───────────────────                                                        │
"""

  FOR each action in actions:
    section += """
│                                                                             │
│  [{action.priority}] {action.description}                                   │
"""
    IF action.command THEN
      section += "│      Command: {action.command}\n"

    IF action.file THEN
      section += "│      File: {action.file}\n"

  # Add skip option for low-priority items
  low_priority_count = actions.filter(a => a.priority > actions.length / 2).length
  IF low_priority_count > 0 THEN
    section += """
│                                                                             │
│  [{actions.length + 1}] Skip remaining ({low_priority_count} low-priority)  │
"""

  section += """
│                                                                             │
│  Enter choice (1-{actions.length + 1}) or 'done' to finish:                 │
"""

  RETURN section
```

---

## Interactive Actions

### Offering Fixes

```pseudocode
FUNCTION offerInteractiveFixes(actions, context):
  WHILE true:
    response = AskUserQuestion:
      question: "Select an action to apply, or 'done' to finish"
      header: "Actions"
      options: buildActionOptions(actions)
      multiSelect: false

    IF response == "done" OR response == "Skip all" THEN
      BREAK

    IF response matches action number THEN
      action_index = parseInt(response) - 1
      action = actions[action_index]

      # Execute the action
      result = executeAction(action, context)

      IF result.status == "success" THEN
        # Mark action as completed
        action.completed = true
        displayMessage("✅ Action completed: {action.description}")
      ELSE
        displayMessage("❌ Action failed: {result.message}")

      # Ask if they want to continue
      continue_response = AskUserQuestion:
        question: "Continue with more actions?"
        options: ["Yes", "No"]

      IF continue_response == "No" THEN
        BREAK


FUNCTION executeAction(action, context):
  IF action.command THEN
    # Execute command
    RETURN Bash(action.command)

  ELSE IF action.file THEN
    # Open file for review
    displayMessage("Review file: {action.file}")
    RETURN { status: "success", message: "File noted for review" }

  ELSE
    # Generic description - just acknowledge
    displayMessage("Action noted: {action.description}")
    RETURN { status: "success", message: "Action acknowledged" }
```

---

## Artifacts Section

```pseudocode
FUNCTION formatArtifacts(artifacts):
  IF artifacts is null OR isEmpty(artifacts) THEN
    RETURN """
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ARTIFACTS                                                                  │
│  ─────────                                                                  │
│  No artifacts created.                                                      │
"""

  section = """
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ARTIFACTS                                                                  │
│  ─────────                                                                  │
"""

  IF artifacts.branch_name THEN
    section += "│  Branch: {artifacts.branch_name}\n"

  IF artifacts.spec_path THEN
    section += "│  Spec: {artifacts.spec_path}\n"

  IF artifacts.pr_number THEN
    section += "│  PR: #{artifacts.pr_number} ({artifacts.pr_url})\n"

  IF artifacts.commits AND artifacts.commits.length > 0 THEN
    section += "│  Commits: {artifacts.commits.length} commits\n"

  RETURN section
```

---

## Detailed Report Extras

### Step Details

```pseudocode
FUNCTION formatStepDetails(log):
  section = """
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  STEP DETAILS                                                               │
│  ────────────                                                               │
"""

  FOR each phase in ["frame", "architect", "build", "evaluate", "release"]:
    section += "\n│  {capitalize(phase)} Phase\n"

    step_logs = getStepLogs(log.step_response_refs, phase)

    FOR each step_log in step_logs:
      emoji = getPhaseStatusEmoji(step_log.status)
      section += "│    {emoji} {step_log.step_name}"

      IF step_log.duration_ms THEN
        section += " ({formatDuration(step_log.duration_ms)})"

      section += "\n"

      # Success messages (detailed format only)
      IF step_log.messages AND step_log.messages.length > 0 THEN
        FOR each message in step_log.messages:
          section += "│       ✓ {message.text}\n"

      # Details (detailed format only)
      IF step_log.details AND !isEmpty(step_log.details) THEN
        section += "│       Details: {JSON.stringify(step_log.details)}\n"

  RETURN section
```

### Timing Breakdown

```pseudocode
FUNCTION formatTimingBreakdown(log):
  section = """
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TIMING BREAKDOWN                                                           │
│  ────────────────                                                           │
"""

  total_ms = log.duration_ms

  FOR each phase in ["frame", "architect", "build", "evaluate", "release"]:
    phase_summary = log.phases_summary[phase]
    percentage = (phase_summary.duration_ms / total_ms * 100).toFixed(1)

    bar = generateProgressBar(percentage, 20)

    section += "│  {capitalize(phase)}: {bar} {formatDuration(phase_summary.duration_ms)} ({percentage}%)\n"

  section += "│\n│  Total: {formatDuration(total_ms)}\n"

  RETURN section


FUNCTION generateProgressBar(percentage, width):
  filled = Math.round(percentage / 100 * width)
  empty = width - filled
  RETURN "█".repeat(filled) + "░".repeat(empty)
```

---

## Minimal Report

```pseudocode
FUNCTION generateMinimalReport(log, context):
  RETURN """
FABER Workflow Complete
───────────────────────
Target: {log.target}
Work Item: #{log.work_id}
Status: {getStatusEmoji(log.final_status)} {log.final_status}
Duration: {formatDuration(log.duration_ms)}

Phases: {formatPhasesSummary(log.phases_summary)}
Warnings: {log.totals.warnings}
Errors: {log.totals.errors}

{formatArtifactsMinimal(log.artifacts)}
"""


FUNCTION formatPhasesSummary(phases_summary):
  parts = []
  FOR each phase in ["frame", "architect", "build", "evaluate", "release"]:
    emoji = getPhaseStatusEmoji(phases_summary[phase].status)
    parts.push("{emoji}{capitalize(phase.charAt(0))}")

  RETURN parts.join(" ")


FUNCTION formatArtifactsMinimal(artifacts):
  IF artifacts.pr_url THEN
    RETURN "PR: {artifacts.pr_url}"
  ELSE IF artifacts.branch_name THEN
    RETURN "Branch: {artifacts.branch_name}"
  ELSE
    RETURN ""
```

---

## Report Display

### Console Output

```pseudocode
FUNCTION displayReport(report, format):
  # Clear any previous output
  clearScreen()

  # Display the report
  print(report)

  # Wait for acknowledgment if detailed
  IF format == "detailed" THEN
    waitForKey("Press Enter to continue...")
```

### Saving Report

```pseudocode
FUNCTION saveReport(report, context):
  # Save to run directory
  report_path = ".fractary/plugins/faber/runs/{context.run_id}/report.md"
  writeFile(report_path, report)

  # Also save to workflow execution log
  updateWorkflowLog(context.run_id, { report_generated: true })

  RETURN report_path
```

---

## Integration

### Event Emission

```pseudocode
FUNCTION emitReportGenerated(context, report_path):
  Bash: plugins/faber/skills/run-manager/scripts/emit-event.sh \
    --run-id "{context.run_id}" \
    --type "report_generated" \
    --status "completed" \
    --message "Workflow report generated" \
    --data '{"report_path": "{report_path}"}'
```

### Complete Flow

```pseudocode
FUNCTION completeWorkflowWithReport(context):
  # 1. Generate workflow execution log
  workflow_log = generateWorkflowExecutionLog(context)

  # 2. Generate report
  report = generateEndOfWorkflowReport(context)

  # 3. Display report
  displayReport(report, context.report_format)

  # 4. Save report
  report_path = saveReport(report, context)

  # 5. Offer interactive fixes if any
  IF workflow_log.recommended_actions.length > 0 THEN
    offerInteractiveFixes(workflow_log.recommended_actions, context)

  # 6. Emit completion event
  emitReportGenerated(context, report_path)

  RETURN { status: "success", report_path: report_path }
```
