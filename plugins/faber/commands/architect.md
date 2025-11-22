# /fractary-faber:architect

Execute the **Architect phase** of the FABER workflow.

## What This Does

Executes Frame + Architect phases which include:
- **Frame**: Fetch work item, classify, setup branch (if not done)
- **Architect**: Generate technical specification

**Stops after Architect phase** - does not proceed to Build, Evaluate, or Release.

## Usage

```bash
/fractary-faber:architect <work-id> [--workflow <id>]
```

## Arguments

- `<work-id>` (required): Work item ID (e.g., 158)
- `--workflow <id>` (optional): Workflow to use (e.g., default, hotfix). If not specified, inferred from issue metadata or defaults to first workflow.

## Examples

```bash
# Execute architect phase for issue #158
/fractary-faber:architect 158

# Execute architect phase with specific workflow
/fractary-faber:architect 158 --workflow hotfix

# This will:
# 1. Check if frame is complete, if not: run frame
# 2. Execute architect phase (generate spec)
# 3. Stop (do not build)
```

## What Gets Created

After successful architect phase:
- ✅ Technical specification generated (e.g., `/specs/WORK-00158-description.md`)
- ✅ Specification linked to issue
- ✅ State updated
- ✅ Logged to fractary-logs

## Next Steps

After architect phase completes, you can:
- Review the specification before implementation
- Continue to Build: `/fractary-faber:build 158`
- Continue full workflow: `/fractary-faber:run 158 --from build`
- Check status: `/fractary-faber:status 158`

## Use Cases

**When to use Architect only:**
- Want to review specification before implementation
- "Just do the architect phase" from issue #158 requirements
- Need approval on design before committing to build
- Testing architect configuration/hooks
- Generating specs for multiple issues without implementing

## Implementation

This command invokes the universal faber-manager agent with:
- `phase_only=architect`
- `stop_at_phase=architect`

The manager executes:
1. Frame phase (if not complete)
2. Pre-architect hooks
3. Architect phase steps (generate spec)
4. Post-architect hooks
5. Stops (does not continue to build)

## Hooks

Common architect hooks (from config):
- **pre_architect**: Load architecture standards, design patterns
- **post_architect**: Validate spec completeness, check against standards

## See Also

- `/fractary-faber:frame` - Execute frame phase only
- `/fractary-faber:build` - Execute build phase
- `/fractary-faber:evaluate` - Execute evaluate phase
- `/fractary-faber:release` - Execute release phase
- `/fractary-faber:run` - Execute complete workflow
