# Operational Log Validation Rules

## Frontmatter
✅ **MUST have** `log_type: operational`
✅ **MUST have** `operation_id`
✅ **MUST have** `operation_type` (maintenance, backup, restore, migration, sync, cleanup, monitoring)
✅ **MUST have** valid status
⚠️  **SHOULD have** `component` (system/service affected)
⚠️  **SHOULD have** `duration_seconds`
⚠️  **SHOULD have** `exit_code`

## Structure
✅ **MUST have** Operation Details section
✅ **MUST have** Execution Log section
⚠️  **SHOULD have** Resource Impact section
⚠️  **SHOULD have** Metrics section
⚠️  **SHOULD have** Errors and Warnings section (if applicable)

## Content
✅ **Failed operations must include**: Error messages, stack traces, root cause analysis
✅ **Resource changes must be documented**: What changed, previous state, new state
⚠️  **Metrics should be quantitative**: Use numbers (MB, seconds, count) not adjectives
⚠️  **Exit code 0 for success**: Non-zero exit codes indicate failure/warning

## Type-Specific Rules

### backup/restore
✅ **MUST include**: Data volume, backup location, verification status

### migration
✅ **MUST include**: Records processed, migration strategy, rollback plan

### sync
✅ **MUST include**: Source/destination, sync method, conflict resolution
