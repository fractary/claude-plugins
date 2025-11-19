---
spec_id: WORK-00138-fix-issue-fetch-wrong-repository
issue_number: 138
issue_url: https://github.com/fractary/claude-plugins/issues/138
title: Fix fractary-work:issue-fetch fetching wrong repository issues
type: bug
status: draft
created: 2025-11-18
author: jmcwilliam
validated: false
severity: high
source: conversation+issue
---

# Bug Fix Specification: Fix fractary-work:issue-fetch fetching wrong repository issues

**Issue**: [#138](https://github.com/fractary/claude-plugins/issues/138)
**Type**: Bug Fix
**Severity**: High
**Status**: Draft
**Created**: 2025-11-18

## Summary

The `/fractary-work:issue-fetch` command incorrectly fetches issues from the fractary/claude-plugins repository instead of the user's actual project repository. This recurring bug has persisted through multiple prior fix attempts. The root cause is that the plugin code executes from `~/.claude/plugins/` and uses that directory context rather than the user's project directory when loading configuration and making API calls.

## Bug Description

### Observed Behavior
When running `/fractary-work:issue-fetch <number>` in a user's project (e.g., `corthosai/etl.corthion.ai`), the command fetches issue details from the fractary/claude-plugins repository instead of the correct repository configured in the project's `.fractary/plugins/work/config.json`.

**Example:**
- User working in: `corthosai/etl.corthion.ai`
- Command: `/fractary-work:issue-fetch 24`
- Expected: Fetch issue #24 from `corthosai/etl.corthion.ai`
- Actual: Fetches issue #24 from `fractary/claude-plugins`

### Expected Behavior
The command should:
1. Load the project-specific configuration from `.fractary/plugins/work/config.json` in the user's working directory
2. Use the `owner` and `repo` values from that configuration
3. Fetch the issue from the correct repository as configured

### Impact
- **Severity**: High
- **Affected Users**: All users of the fractary-work plugin across multiple projects
- **Affected Features**:
  - `/fractary-work:issue-fetch` command
  - Any workflow that depends on fetching issue details
  - FABER workflows using work tracking integration

## Reproduction Steps

1. Navigate to a project that is NOT fractary/claude-plugins (e.g., `corthosai/etl.corthion.ai`)
2. Ensure `.fractary/plugins/work/config.json` is correctly configured with the project's repository:
   ```json
   {
     "platform": "github",
     "github": {
       "owner": "corthosai",
       "repo": "etl.corthion.ai"
     }
   }
   ```
3. Run: `/fractary-work:issue-fetch <number>` (where `<number>` exists in both repos)
4. Observe: Issue details fetched from fractary/claude-plugins instead of the configured repository

**Frequency**: 100% reproducible
**Environment**: All environments, all platforms (GitHub, Jira, Linear)

## Root Cause Analysis

### Investigation Findings
From the bug report in issue #138:
- The project configuration file was verified to be correct (owner: "corthosai", repo: "etl.corthion.ai")
- Despite correct configuration, the plugin fetched from fractary/claude-plugins
- The plugin code is installed in `~/.claude/plugins/` (cloned from fractary/claude-plugins)
- When the plugin code executes, it appears to use its installation directory as the working directory

Hypothesis from prior debugging:
> "I would hypothesize that when executing that code, it somehow sees its project or working directory as that repository, that of the plugin source, rather than the current actual project being worked on by Claude Code."

### Root Cause
The `working_directory` parameter is not being properly utilized throughout the command → agent → skill execution chain. Specifically:

1. **Command Layer** (`commands/issue-fetch.md`): Passes `working_directory: "${PWD}"` to the agent
2. **Agent Layer** (`agents/work-manager.md`): Should set `CLAUDE_WORK_CWD` from `working_directory` parameter
3. **Skill Layer** (`skills/issue-fetcher/`): Should use `CLAUDE_WORK_CWD` to locate and load config
4. **Script Layer**: Shell scripts should use the environment variable to find the correct config path

**The bug likely occurs at one or more of these layers** where the parameter is either:
- Not being passed correctly
- Not being used to construct the config path
- Being overridden by a default/cached value

### Why It Wasn't Caught Earlier
- The bug is specific to multi-repository workflows (not apparent when only working on fractary/claude-plugins)
- Testing may have been primarily done within the plugin's own repository
- The `working_directory` parameter was added as a fix but not fully propagated through all layers
- No automated tests for multi-repository scenarios

## Technical Analysis

### Affected Components
- `plugins/work/commands/issue-fetch.md`: Command invocation layer
- `plugins/work/agents/work-manager.md`: Agent routing and environment setup
- `plugins/work/skills/issue-fetcher/SKILL.md`: Skill execution instructions
- `plugins/work/skills/issue-fetcher/scripts/fetch-issue.sh`: Shell script execution
- `plugins/work/skills/handler-work-tracker-github/scripts/github/fetch-issue.sh`: Platform-specific implementation

### Stack Trace
No stack trace available (logic error, not runtime exception)

### Related Code
- `plugins/work/commands/issue-fetch.md`: Lines defining `working_directory` parameter passing
- `plugins/work/agents/work-manager.md`: Lines handling `CLAUDE_WORK_CWD` environment variable setting
- `plugins/work/skills/issue-fetcher/workflow/fetch.md`: Workflow defining config loading
- `plugins/work/skills/handler-work-tracker-github/scripts/github/fetch-issue.sh`: Script that should read config from correct path

## Proposed Fix

### Solution Approach
**Audit and fix the parameter flow through all layers:**

1. **Command Layer**: Verify `working_directory` is captured and passed
2. **Agent Layer**: Ensure `CLAUDE_WORK_CWD` is set from `working_directory` parameter
3. **Skill Layer**: Verify workflow reads `CLAUDE_WORK_CWD` and uses it for config path
4. **Script Layer**: Ensure scripts construct config path from `CLAUDE_WORK_CWD` environment variable

**Key principle**: Every layer must explicitly use the working directory context, not rely on `pwd` or implicit directory context.

### Code Changes Required
- `plugins/work/commands/issue-fetch.md`: Verify `working_directory: "${PWD}"` is passed to agent
- `plugins/work/agents/work-manager.md`: Add/verify `CLAUDE_WORK_CWD="${working_directory}"` before skill invocation
- `plugins/work/skills/issue-fetcher/workflow/fetch.md`: Ensure workflow instructs LLM to use `CLAUDE_WORK_CWD`
- `plugins/work/skills/handler-work-tracker-github/scripts/github/fetch-issue.sh`: Use `${CLAUDE_WORK_CWD}/.fractary/plugins/work/config.json` for config path

### Why This Fix Works
By explicitly threading the working directory context through every layer as an environment variable, we ensure that:
1. Configuration is always loaded from the user's project directory, not the plugin installation directory
2. The parameter cannot be lost or overridden during execution
3. All platform handlers (GitHub/Jira/Linear) use the same pattern
4. The fix is defensive - even if one layer fails, others still preserve the context

### Alternative Solutions Considered
- **Alternative 1: Use git remote to detect repository**: Rejected because not all projects are git repositories, and this adds unnecessary complexity
- **Alternative 2: Cache repository context globally**: Rejected because it could cause race conditions in multi-project scenarios
- **Alternative 3: Store config in plugin directory**: Rejected because this defeats the purpose of per-project configuration

## Files to Modify

- `plugins/work/commands/issue-fetch.md`: Verify/document `working_directory` parameter
- `plugins/work/agents/work-manager.md`: Add/verify `CLAUDE_WORK_CWD` environment variable setup
- `plugins/work/skills/issue-fetcher/SKILL.md`: Document requirement to use `CLAUDE_WORK_CWD`
- `plugins/work/skills/issue-fetcher/workflow/fetch.md`: Update workflow to explicitly use environment variable
- `plugins/work/skills/handler-work-tracker-github/scripts/github/fetch-issue.sh`: Fix config path construction
- `plugins/work/skills/handler-work-tracker-jira/scripts/jira/fetch-issue.sh`: Fix config path construction
- `plugins/work/skills/handler-work-tracker-linear/scripts/linear/fetch-issue.sh`: Fix config path construction

**Pattern to apply across all handler scripts:**
```bash
# Use CLAUDE_WORK_CWD if set, otherwise fallback to PWD
WORK_DIR="${CLAUDE_WORK_CWD:-${PWD}}"
CONFIG_PATH="${WORK_DIR}/.fractary/plugins/work/config.json"
```

## Testing Strategy

### Regression Tests
- Test `/fractary-work:issue-fetch` in the fractary/claude-plugins repository itself
- Verify existing functionality still works when working directory matches plugin directory

### New Test Cases
- **Test 1: Multi-repository scenario**
  - Setup: Navigate to a different repository (not fractary/claude-plugins)
  - Configure: Set up `.fractary/plugins/work/config.json` with different owner/repo
  - Execute: `/fractary-work:issue-fetch <number>`
  - Verify: Issue fetched from configured repository, not fractary/claude-plugins

- **Test 2: Cross-org scenario**
  - Setup: Configure work plugin for a different GitHub organization
  - Execute: `/fractary-work:issue-fetch <number>`
  - Verify: Correct organization and repository used

- **Test 3: Platform consistency**
  - Repeat Test 1 for all platforms: GitHub, Jira, Linear
  - Verify: All platforms respect working directory context

### Manual Testing Checklist
- [ ] Test in fractary/claude-plugins repository (regression)
- [ ] Test in corthosai/etl.corthion.ai repository (original bug scenario)
- [ ] Test in a third repository unrelated to either
- [ ] Test with GitHub platform
- [ ] Test with Jira platform (if configured)
- [ ] Test with Linear platform (if configured)
- [ ] Verify other work commands still work (`issue-list`, `issue-create`, etc.)
- [ ] Test FABER workflow integration with work tracking

## Risk Assessment

### Risks of Fix
- **Risk**: Breaking existing working functionality if environment variable not set
  - **Mitigation**: Use fallback pattern `${CLAUDE_WORK_CWD:-${PWD}}` to maintain backwards compatibility

- **Risk**: Different behavior in different contexts (command-line vs agent vs hooks)
  - **Mitigation**: Standardize on environment variable pattern across all contexts

- **Risk**: Platform-specific handlers might implement pattern inconsistently
  - **Mitigation**: Create shared utility function/script for config loading that all handlers use

### Risks of Not Fixing
- Users cannot reliably use fractary-work plugin in any repository other than fractary/claude-plugins
- FABER workflows fail when integrated with work tracking in real projects
- Loss of trust in the plugin ecosystem
- Continued user frustration and bug reports

## Dependencies

- No external dependencies required
- Fix is internal to the fractary-work plugin
- Should be compatible with all platforms (GitHub, Jira, Linear)

## Acceptance Criteria

- [ ] `/fractary-work:issue-fetch` correctly fetches issues from configured repository in all scenarios
- [ ] Fix works consistently across all platforms (GitHub, Jira, Linear)
- [ ] No regression in existing fractary/claude-plugins repository usage
- [ ] `working_directory` parameter properly flows through command → agent → skill → script
- [ ] `CLAUDE_WORK_CWD` environment variable is set and used by all handlers
- [ ] Config path construction uses working directory context, not implicit `pwd`
- [ ] Manual tests pass for all scenarios
- [ ] Documentation updated to explain the fix and parameter flow

## Prevention Measures

### How to Prevent Similar Bugs
- Add automated tests for multi-repository scenarios to CI/CD
- Create integration test suite that runs commands in different project contexts
- Document the "working directory context" pattern in plugin standards
- Add linting/validation to ensure environment variables are used correctly in scripts
- Create shared utilities for common patterns (config loading, path resolution)

### Process Improvements
- **Testing Standard**: All plugin commands must be tested in at least two different repositories
- **Documentation Standard**: All commands must document how they determine working directory context
- **Code Review**: Require explicit review of parameter passing for any command/agent/skill changes
- **Plugin Standards Update**: Add section on "Context Preservation" to `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`

## Implementation Notes

**Implementation Order:**
1. Start with the shell scripts (most likely source of bug)
2. Verify skill workflows properly instruct the use of environment variable
3. Verify agent sets the environment variable
4. Verify command passes the parameter
5. Test in multi-repository scenario
6. Apply pattern to all work commands (not just issue-fetch)

**Key files to investigate first:**
- `plugins/work/skills/handler-work-tracker-github/scripts/github/fetch-issue.sh`
- `plugins/work/agents/work-manager.md` (check for `CLAUDE_WORK_CWD` setup)
- Any common utility scripts used for config loading

**Debugging approach:**
- Add logging at each layer to trace the working directory value
- Verify config path being used at script level
- Compare with command invocation directory

**Related Issues:**
This bug has been reported multiple times previously. Ensure we reference and close all related issues when this is fixed.
