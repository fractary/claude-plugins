# /fractary-faber:evaluate

Execute the **Evaluate phase** of the FABER workflow.

## What This Does

Executes the Evaluate phase which includes:
- Run automated tests (unit, integration, e2e)
- Code review and quality checks
- Validation against requirements
- Fix issues if found (with retry loop)

**Note**: Requires existing implementation. If no build exists, will run Frame + Architect + Build first.

**Stops after Evaluate phase** - does not proceed to Release.

## Usage

```bash
/fractary-faber:evaluate <work-id>
```

## Arguments

- `<work-id>` (required): Work item ID (e.g., 158)

## Examples

```bash
# Execute evaluate phase for issue #158
/fractary-faber:evaluate 158

# This will:
# 1. Check prerequisites (frame, architect, build)
# 2. Execute evaluate phase (test, review)
# 3. Retry build if tests fail (up to max_retries)
# 4. Stop (do not release)
```

## What Happens

After successful evaluate phase:
- ✅ All tests pass
- ✅ Code review complete
- ✅ Quality checks pass
- ✅ State updated
- ✅ Logged to fractary-logs

## Retry Loop

The evaluate phase implements a **Build-Evaluate retry loop**:

1. **Tests Pass**: Proceed (evaluation complete)
2. **Tests Fail + Retries Available**:
   - Return to Build phase with failure context
   - Fix issues
   - Re-evaluate
3. **Tests Fail + Max Retries Reached**: Fail workflow

**Configuration** (from config):
```json
{
  "phases": {
    "evaluate": {
      "max_retries": 3
    }
  }
}
```

## Next Steps

After evaluate phase completes:
- Continue to Release: `/fractary-faber:release 158`
- Continue full workflow: `/fractary-faber:run 158 --from release`
- Check status: `/fractary-faber:status 158`

## Use Cases

**When to use Evaluate only:**
- Re-run tests after manual fixes
- Validate implementation before release
- Test evaluate configuration/hooks
- Run evaluation suite on existing work

## Implementation

This command invokes the universal faber-manager agent with:
- `phase_only=evaluate`
- `stop_at_phase=evaluate`

The manager executes:
1. Prerequisites (frame, architect, build if needed)
2. Pre-evaluate hooks
3. Evaluate phase steps (test, review, fix)
4. Retry loop if failures occur
5. Post-evaluate hooks
6. Stops (does not continue to release)

## Hooks

Common evaluate hooks (from config):
- **pre_evaluate**: Setup test environment, load test data
- **post_evaluate**: Generate test reports, update code coverage

## See Also

- `/fractary-faber:frame` - Execute frame phase only
- `/fractary-faber:architect` - Execute architect phase
- `/fractary-faber:build` - Execute build phase
- `/fractary-faber:release` - Execute release phase
- `/fractary-faber:run` - Execute complete workflow
