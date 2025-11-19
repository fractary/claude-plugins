# /fractary-faber:build

Execute the **Build phase** of the FABER workflow.

## What This Does

Executes Frame + Architect + Build phases which include:
- **Frame**: Fetch work item, classify, setup branch (if not done)
- **Architect**: Generate specification (if not done)
- **Build**: Implement solution and commit changes

**Stops after Build phase** - does not proceed to Evaluate or Release.

## Usage

```bash
/fractary-faber:build <work-id>
```

## Arguments

- `<work-id>` (required): Work item ID (e.g., 158)

## Examples

```bash
# Execute build phase for issue #158
/fractary-faber:build 158

# This will:
# 1. Check if frame is complete, if not: run frame
# 2. Check if architect is complete, if not: run architect
# 3. Execute build phase (implement + commit)
# 4. Stop (do not evaluate)
```

## What Gets Created

After successful build phase:
- ✅ Implementation complete
- ✅ Changes committed with semantic commit message
- ✅ Commit linked to issue
- ✅ State updated
- ✅ Logged to fractary-logs

## Next Steps

After build phase completes, you can:
- Continue to Evaluate: `/fractary-faber:evaluate 158`
- Continue full workflow: `/fractary-faber:run 158 --from evaluate`
- Check status: `/fractary-faber:status 158`

## Use Cases

**When to use Build only:**
- Want to implement without immediately testing
- Need to review implementation before evaluation
- Testing build configuration/hooks
- Batch implementation for multiple issues

## Implementation

This command invokes the universal faber-manager agent with:
- `phase_only=build`
- `stop_at_phase=build`

The manager executes:
1. Frame phase (if not complete)
2. Architect phase (if not complete)
3. Pre-build hooks
4. Build phase steps (implement, commit)
5. Post-build hooks
6. Stops (does not continue to evaluate)

## Hooks

Common build hooks (from config):
- **pre_build**: Load coding standards, linting rules
- **post_build**: Run quick smoke tests, code formatting

## See Also

- `/fractary-faber:frame` - Execute frame phase only
- `/fractary-faber:architect` - Execute architect phase
- `/fractary-faber:evaluate` - Execute evaluate phase
- `/fractary-faber:release` - Execute release phase
- `/fractary-faber:run` - Execute complete workflow
