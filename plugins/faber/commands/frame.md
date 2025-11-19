# /fractary-faber:frame

Execute only the **Frame phase** of the FABER workflow.

## What This Does

Executes the Frame phase which includes:
- Fetch work item details from issue tracker
- Classify work type (feature, bug, chore, etc.)
- Create branch and setup development environment

**Stops after Frame phase** - does not proceed to Architect, Build, Evaluate, or Release.

## Usage

```bash
/fractary-faber:frame <work-id>
```

## Arguments

- `<work-id>` (required): Work item ID (e.g., 158, PROJ-456)

## Examples

```bash
# Execute frame phase for issue #158
/fractary-faber:frame 158

# Execute frame phase for Jira ticket
/fractary-faber:frame PROJ-456
```

## What Gets Created

After successful frame phase:
- ✅ Branch created (e.g., `feat/158-description`)
- ✅ Work item details cached
- ✅ Development environment ready
- ✅ State saved to `.fractary/plugins/faber/state.json`
- ✅ Logged to fractary-logs

## Next Steps

After frame phase completes, you can:
- Continue to Architect: `/fractary-faber:architect 158`
- Continue full workflow: `/fractary-faber:run 158 --from architect`
- Check status: `/fractary-faber:status 158`

## Use Cases

**When to use Frame only:**
- Want to setup branch before starting work
- Need to review work item before committing to full workflow
- Testing frame phase configuration/hooks
- Batch branch creation for multiple issues

## Implementation

This command invokes the universal faber-manager agent with:
- `phase_only=frame`
- `stop_at_phase=frame`

The manager executes:
1. Pre-frame hooks
2. Frame phase steps
3. Post-frame hooks
4. Stops (does not continue to architect)

## See Also

- `/fractary-faber:architect` - Execute architect phase
- `/fractary-faber:build` - Execute build phase
- `/fractary-faber:evaluate` - Execute evaluate phase
- `/fractary-faber:release` - Execute release phase
- `/fractary-faber:run` - Execute complete workflow
