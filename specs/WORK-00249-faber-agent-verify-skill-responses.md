# WORK-00249: FABER Agent Project Audit Should Verify Standard Skill Responses

## Metadata

| Field | Value |
|-------|-------|
| Work ID | 249 |
| Issue URL | https://github.com/fractary/claude-plugins/issues/249 |
| Type | Enhancement |
| Created | 2025-12-07 |
| Branch | feat/249-faber-agent-project-audit-should-verify-standard-s |

## Summary

Enhance the `fractary-faber-agent:project-auditor` to detect skills that do not return responses conforming to the standardized FABER response format. This extends the existing audit capabilities with response format compliance checking (RESP-001 violation code).

## Background

PR #242 introduced the **Workflow Step Response Standardization** (Issue #235), which defines a standard JSON response format for all FABER workflow skills:

```json
{
  "status": "success" | "warning" | "failure",
  "message": "Human-readable summary",
  "details": { /* operation-specific data */ },
  "errors": ["..."],           // required if status=failure
  "warnings": ["..."],         // required if status=warning
  "error_analysis": "...",     // recommended for failures
  "suggested_fixes": ["..."]   // recommended for recoverable issues
}
```

### Reference Documentation

- **Schema**: `plugins/faber/config/schemas/skill-response.schema.json`
- **Specification**: `plugins/faber/docs/RESPONSE-FORMAT.md`
- **Best Practices**: `plugins/faber/docs/FABER-AGENT-BEST-PRACTICES.md`
- **Migration Guide**: `docs/MIGRATE-SKILL-RESPONSES.md`
- **Validation Script**: `scripts/validate-skill-responses.sh`

### Current Gap

The project auditor (`/fractary-faber-agent:audit-project`) currently detects these patterns:

| Code | Detection |
|------|-----------|
| ARC-001 | Manager-as-Skill anti-pattern |
| ARC-002 | Director-as-Agent anti-pattern |
| ARC-004 | Director patterns |
| ARC-005 | Project-specific directors |
| ARC-006 | Project-specific managers |
| AGT-005 | Missing workflow logging |
| CMD-004 | Direct skill commands |

**Missing**: Response format compliance checking (RESP-001).

## Requirements

### REQ-1: Create Detection Script

Create `detect-response-format-compliance.sh` in:
```
plugins/faber-agent/skills/project-analyzer/scripts/
```

**Script behavior**:
1. Accept project path as argument (defaults to current directory)
2. **Wrap the existing `scripts/validate-skill-responses.sh` with `--json` flag**
3. Transform output to match project-analyzer detection format
4. Return structured JSON with compliance results

**Integration approach** (Decision from Q2):
- Detection script wraps the existing validation script with `--json` flag
- This maintains single source of truth for validation logic
- Avoids code duplication and ensures consistency
- Existing script is already tested and stable

### REQ-2: Define Violation Code

Add violation code `RESP-001`:

| Code | Severity | Description |
|------|----------|-------------|
| RESP-001 | Warning | Skill does not document standard FABER response format |

**Severity rationale** (Decision from Q1):
- Keep as 'warning' severity initially (non-blocking)
- This is a new standard and non-blocking allows gradual adoption
- Can escalate to 'error' severity in a future iteration once adoption is widespread

### REQ-3: Compliance Levels (Strict Criteria)

**Decision from Q3**: Match the existing validation script's stricter criteria.

Define three compliance levels with strict ALL-required criteria:

| Level | Criteria |
|-------|----------|
| `compliant` | Has `<OUTPUTS>` section with ALL required indicators: status field, message field, details object, format reference (RESPONSE-FORMAT.md or "standard FABER response"), AND error handling (errors/warnings arrays) |
| `partial` | Has `<OUTPUTS>` section with SOME but not all required indicators |
| `non_compliant` | Missing `<OUTPUTS>` section or no response format indicators present |

**Why strict**: Consistency with existing `validate-skill-responses.sh` is more important than looser thresholds. This ensures audit results match standalone validation results.

### REQ-4: Integrate into Full Audit

Update `run-all-detections.sh` to include the new detection script in the full audit workflow.

**TOTAL_CHECKS adjustment** (Decision from Q5):
- Increment TOTAL_CHECKS from 30 to 31
- One check per detection type is the pattern used by other detectors

### REQ-5: Output Format

Script must output JSON matching the project-analyzer detection format.

**Root-level field addition** (Decision from Q4):
- Include `non_compliant_count` at root level for consistent aggregation
- This ensures `run-all-detections.sh` can extract counts using existing pattern

```json
{
  "detection": "response-format-compliance",
  "code": "RESP-001",
  "severity": "warning",
  "non_compliant_count": 2,
  "summary": {
    "skills_checked": 15,
    "compliant": 10,
    "partial": 3,
    "non_compliant": 2
  },
  "violations": [
    {
      "skill": "plugins/my-plugin/skills/my-skill",
      "compliance": "non_compliant",
      "missing": ["status field", "message field", "details object", "RESPONSE-FORMAT.md reference", "errors/warnings arrays"]
    },
    {
      "skill": "plugins/my-plugin/skills/another-skill",
      "compliance": "partial",
      "missing": ["errors array example", "warnings array example"]
    }
  ],
  "recommendation": "See docs/MIGRATE-SKILL-RESPONSES.md for migration guide"
}
```

**Partial vs Non-compliant `missing` array examples** (Suggestion S1 accepted):

For **non_compliant** skills (no or minimal indicators):
```json
{
  "skill": "plugins/my-plugin/skills/broken-skill",
  "compliance": "non_compliant",
  "missing": ["status field", "message field", "details object", "RESPONSE-FORMAT.md reference", "errors/warnings arrays"]
}
```

For **partial** skills (some indicators present):
```json
{
  "skill": "plugins/my-plugin/skills/partial-skill",
  "compliance": "partial",
  "missing": ["errors array example", "warnings array example"]
}
```

### REQ-6: Fix Integration

**Suggestion S2 accepted**: Add `--fix` pass-through capability.

The detection script should support an optional `--fix` flag that passes through to the underlying validation script:

```bash
# Detection only (default for audit)
./detect-response-format-compliance.sh /path/to/project

# Detection with auto-fix suggestion
./detect-response-format-compliance.sh /path/to/project --fix
```

When `--fix` is passed, the script will:
1. Run detection as normal
2. For non-compliant skills, invoke the validation script's `--fix` mode
3. Report which skills were fixed in the output

Note: The `--fix` mode is NOT invoked during normal audit runs. It's an optional capability for remediation workflows.

### REQ-7: Handler Skill Treatment

**Suggestion S3 rejected**: Handler skills follow the same compliance criteria.

Handler skills return platform-specific data but MUST still wrap their responses in the standard format. The `details` object is where platform-specific data belongs:

```json
{
  "status": "success",
  "message": "GitHub PR created successfully",
  "details": {
    "pr_number": 123,
    "pr_url": "https://github.com/...",
    "platform": "github"
  }
}
```

No special handling or different criteria for handler skills.

### REQ-8: Documentation Updates

Update the audit usage guide with:
- Description of new RESP-001 detection
- How to interpret compliance levels (strict criteria)
- Reference to migration guide for remediation
- Explanation of `--fix` capability

## Implementation Plan

### Phase 1: Detection Script

1. Create `detect-response-format-compliance.sh`:
   - Parse command-line arguments (project path, optional --fix)
   - Call `scripts/validate-skill-responses.sh --json` on target project
   - Transform output to project-analyzer format
   - Add `non_compliant_count` at root level
   - Output structured JSON

2. Reference existing patterns from:
   - `detect-workflow-logging.sh` for output structure
   - `scripts/validate-skill-responses.sh` for compliance logic (wrapper approach)

### Phase 2: Integration

1. Update `run-all-detections.sh`:
   - Add call to new detection script
   - Increment TOTAL_CHECKS from 30 to 31
   - Aggregate results into full audit report

2. Test integration:
   - Run on this repository (claude-plugins)
   - Verify output format matches expectations
   - Verify compliance detection accuracy
   - Verify `non_compliant_count` aggregation works

### Phase 3: Documentation

1. Update audit documentation with:
   - New RESP-001 violation code
   - Compliance level definitions (strict criteria)
   - Remediation guidance
   - `--fix` capability documentation

## Acceptance Criteria

- [ ] `detect-response-format-compliance.sh` script created and executable
- [ ] Script wraps `validate-skill-responses.sh --json` (not duplicate logic)
- [ ] Script outputs valid JSON matching project-analyzer format
- [ ] Output includes `non_compliant_count` at root level
- [ ] Script correctly identifies compliant, partial, and non-compliant skills using strict criteria
- [ ] RESP-001 violation code documented in audit output (warning severity)
- [ ] Script integrated into `run-all-detections.sh`
- [ ] TOTAL_CHECKS incremented to 31
- [ ] Script supports optional `--fix` flag pass-through
- [ ] Audit usage guide updated with new detection
- [ ] Test execution on sample project with mixed compliance levels
- [ ] Audit report shows:
  - Count of skills checked
  - Count by compliance level (compliant/partial/non_compliant)
  - List of non-compliant skills with specific missing elements
  - Suggested action referencing migration guide

## Technical Notes

### Script Template Structure

Based on wrapper approach decision:

```bash
#!/bin/bash
set -euo pipefail

# detect-response-format-compliance.sh
# Detect skills that don't follow FABER response format standards (RESP-001)
# Wraps scripts/validate-skill-responses.sh for consistent compliance logic

PROJECT_PATH="${1:-.}"
FIX_MODE=false

# Parse optional --fix flag
for arg in "$@"; do
  case $arg in
    --fix)
      FIX_MODE=true
      shift
      ;;
  esac
done

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  echo '{"status": "error", "error": "missing_dependency", "message": "jq is required"}'
  exit 1
fi

# Find the validation script (relative to this script's location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR_SCRIPT="$SCRIPT_DIR/../../../../../scripts/validate-skill-responses.sh"

if [[ ! -x "$VALIDATOR_SCRIPT" ]]; then
  echo '{"status": "error", "error": "missing_validator", "message": "validate-skill-responses.sh not found"}'
  exit 1
fi

# Run the validation script with --json flag
VALIDATION_OUTPUT=$("$VALIDATOR_SCRIPT" --json "$PROJECT_PATH" 2>/dev/null || true)

# Transform output to project-analyzer format
# Extract counts and violations from validation output
# Add non_compliant_count at root level for consistent aggregation

NON_COMPLIANT_COUNT=$(echo "$VALIDATION_OUTPUT" | jq -r '.summary.non_compliant // 0')

jq -n \
  --arg detection "response-format-compliance" \
  --arg code "RESP-001" \
  --arg severity "warning" \
  --argjson non_compliant_count "$NON_COMPLIANT_COUNT" \
  --argjson summary "$(echo "$VALIDATION_OUTPUT" | jq '.summary')" \
  --argjson violations "$(echo "$VALIDATION_OUTPUT" | jq '.violations // []')" \
  '{
    detection: $detection,
    code: $code,
    severity: $severity,
    non_compliant_count: $non_compliant_count,
    summary: $summary,
    violations: $violations,
    recommendation: "See docs/MIGRATE-SKILL-RESPONSES.md for migration guide"
  }'

# Optional fix mode
if [[ "$FIX_MODE" == "true" ]]; then
  "$VALIDATOR_SCRIPT" --fix "$PROJECT_PATH"
fi
```

### Compliance Detection Logic (Strict)

The existing `validate-skill-responses.sh` uses strict criteria:

| Requirement | Status for Compliant |
|-------------|---------------------|
| status field | Required |
| message field | Required |
| details object | Required |
| Format reference | Required |
| Error handling | Required |

ALL five requirements must be met for `compliant` status. This spec adopts the same strict criteria for consistency.

### Edge Cases

1. **Skills without OUTPUTS section**: Mark as `non_compliant`
2. **Handler skills**: Same compliance criteria as other skills (no special treatment)
3. **Utility skills**: Same compliance criteria (format is universal)
4. **Legacy skills**: Expected to show as partial/non_compliant (migration needed)

## Related

- Issue #235: Ensure workflow steps return status code responses
- PR #242: feat(235): Complete workflow step response standardization
- Script: `scripts/validate-skill-responses.sh` (existing validation logic)

## Changelog

| Date | Author | Change |
|------|--------|--------|
| 2025-12-07 | Claude | Initial specification created |
| 2025-12-07 | Claude | **Refinement Round 1**: Applied decisions from Q1-Q5, accepted S1-S2, rejected S3. Key changes: (1) Confirmed warning severity for gradual adoption, (2) Wrapper approach using existing validate-skill-responses.sh, (3) Strict ALL-required compliance criteria, (4) Added non_compliant_count at root level, (5) TOTAL_CHECKS to 31, (6) Added partial vs non-compliant missing array examples, (7) Added --fix pass-through capability, (8) Confirmed handler skills use same criteria |
