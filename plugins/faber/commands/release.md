---
model: claude-haiku-4-5
---

# /fractary-faber:release

Execute the **Release phase** of the FABER workflow.

## What This Does

Executes the Release phase which includes:
- Create pull request with comprehensive description
- Update project documentation
- Optional: Deploy (based on project configuration)

**Note**: Requires completed evaluation. If prerequisites missing, will execute full workflow first.

**Respects autonomy gates** - may require approval before proceeding.

## Usage

```bash
/fractary-faber:release <work-id> [--workflow <id>]
```

## Arguments

- `<work-id>` (required): Work item ID (e.g., 158)
- `--workflow <id>` (optional): Workflow to use (e.g., default, hotfix). If not specified, inferred from issue metadata or defaults to first workflow.

## Examples

```bash
# Execute release phase for issue #158
/fractary-faber:release 158

# Execute release phase with specific workflow
/fractary-faber:release 158 --workflow hotfix

# This will:
# 1. Check prerequisites (all phases complete)
# 2. Check autonomy level (may prompt for approval)
# 3. Execute release phase (create PR, update docs)
# 4. Complete workflow
```

## What Gets Created

After successful release phase:
- ✅ Pull request created and linked to issue
- ✅ PR description includes summary, changes, testing
- ✅ Documentation updated
- ✅ CI/CD triggered
- ✅ State updated to "completed"
- ✅ Logged to fractary-logs

## Autonomy Gates

Release phase respects configured autonomy level:

**dry-run**: Simulate only, no PR created
**assist**: Create draft PR, no merge
**guarded**: **Pause for approval** before creating PR
**autonomous**: Create PR automatically, may auto-merge

**Configuration** (from config):
```json
{
  "autonomy": {
    "level": "guarded",
    "pause_before_release": true,
    "require_approval_for": ["release"]
  }
}
```

## Approval Process

If autonomy level requires approval:

1. **Pause**: Workflow pauses before release
2. **Notification**: GitHub comment requests approval
3. **Wait**: Workflow state saved, exits
4. **Resume**: User approves, then re-run this command

**Approval Methods**:
- GitHub comment: "@faber approve"
- Re-run command: `/fractary-faber:release 158`
- CLI: `claude --agent faber-manager "158 github 158" # with approval flag`

## Next Steps

After release phase completes:
- Review PR: Check the created pull request
- Merge PR: After approval and CI pass
- Check status: `/fractary-faber:status 158`

## Use Cases

**When to use Release only:**
- Create PR after manual implementation/testing
- Re-create PR if first attempt had issues
- Test release configuration/hooks
- Release after holding work for review

## Implementation

This command invokes the universal faber-manager agent with:
- `phase_only=release`
- `stop_at_phase=release`

The manager executes:
1. Prerequisites (all phases if needed)
2. **Approval gate check** (may pause here)
3. Pre-release hooks
4. Release phase steps (create PR, update docs)
5. Post-release hooks
6. Workflow complete

## Hooks

Common release hooks (from config):
- **pre_release**: Final code review, security scan, dependency check
- **post_release**: Notify team, update project board, trigger deployment

## Safety Features

Release phase has multiple safety checks:
- ✅ All previous phases must be complete
- ✅ All tests must pass
- ✅ Code review must be approved
- ✅ Autonomy gates enforced
- ✅ Protected branch rules respected

## See Also

- `/fractary-faber:frame` - Execute frame phase only
- `/fractary-faber:architect` - Execute architect phase
- `/fractary-faber:build` - Execute build phase
- `/fractary-faber:evaluate` - Execute evaluate phase
- `/fractary-faber:run` - Execute complete workflow
