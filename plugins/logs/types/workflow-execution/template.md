---
log_type: workflow-execution
execution_id: "{uuid}"
run_id: "{run_id}"
work_id: "{work_id}"
final_status: "{completed|completed_with_warnings|failed|cancelled|paused}"
started_at: "{ISO8601}"
completed_at: "{ISO8601}"
---

# Workflow Execution Report

**Run ID**: `{run_id}`
**Work Item**: #{work_id}
**Target**: {target}
**Duration**: {duration_formatted}
**Status**: {final_status_emoji} {final_status}

## Autonomy Configuration

| Setting | Value |
|---------|-------|
| Check-in Frequency | {check_in_frequency} |
| Warning Tolerance | {warning_tolerance} |
| Error Tolerance | {error_tolerance} |

## Phase Summary

| Phase | Status | Steps | Warnings | Errors | Duration |
|-------|--------|-------|----------|--------|----------|
| Frame | {frame_status_emoji} | {frame_steps_succeeded}/{frame_steps_total} | {frame_warnings} | {frame_errors} | {frame_duration} |
| Architect | {architect_status_emoji} | {architect_steps_succeeded}/{architect_steps_total} | {architect_warnings} | {architect_errors} | {architect_duration} |
| Build | {build_status_emoji} | {build_steps_succeeded}/{build_steps_total} | {build_warnings} | {build_errors} | {build_duration} |
| Evaluate | {evaluate_status_emoji} | {evaluate_steps_succeeded}/{evaluate_steps_total} | {evaluate_warnings} | {evaluate_errors} | {evaluate_duration} |
| Release | {release_status_emoji} | {release_steps_succeeded}/{release_steps_total} | {release_warnings} | {release_errors} | {release_duration} |

## Totals

- **Steps**: {steps_succeeded}/{steps_total} succeeded
- **Warnings**: {warnings_total} ({warnings_low} low, {warnings_medium} medium, {warnings_high} high)
- **Errors**: {errors_total} ({errors_low} low, {errors_medium} medium, {errors_high} high)
- **Retries Used**: {retries_used}

## Warnings by Phase/Step ({warnings_total})

{#if aggregated_warnings}
{#each aggregated_warnings}
### {step_id} [{severity}] [{category}]

{text}

{#if analysis}
> **Analysis**: {analysis}
{/if}

{#if suggested_fix}
**Suggested Fix**: {suggested_fix}
{/if}

{/each}
{else}
No warnings collected.
{/if}

## Warnings by Category

{#each warnings_by_category}
- **{category}** ({count}): {step_ids}
{/each}

## Errors ({errors_total})

{#if aggregated_errors}
{#each aggregated_errors}
### {step_id} [{severity}] [{category}]

{text}

{#if analysis}
> **Analysis**: {analysis}
{/if}

{#if suggested_fix}
**Suggested Fix**: {suggested_fix}
{/if}

{/each}
{else}
No errors collected.
{/if}

## Recommended Actions

{#if recommended_actions}
{#each recommended_actions}
### [{priority}] {description}

**Source**: `{source_step}`

{#if command}
```bash
{command}
```
{/if}

{#if file}
**File**: `{file}`
{/if}

{/each}
{else}
No recommended actions.
{/if}

## Artifacts Created

{#if artifacts}
| Type | Value |
|------|-------|
{#if artifacts.branch_name}| Branch | `{artifacts.branch_name}` |{/if}
{#if artifacts.spec_path}| Spec | `{artifacts.spec_path}` |{/if}
{#if artifacts.pr_number}| PR | [#{artifacts.pr_number}]({artifacts.pr_url}) |{/if}
{#if artifacts.commits}| Commits | {artifacts.commits.length} commits |{/if}
{else}
No artifacts created.
{/if}

## Step Response References

{#each step_response_refs}
- `{ref}`
{/each}

---

**Generated**: {completed_at}
