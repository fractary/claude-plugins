---
spec_id: WORK-00241-pr-review-poll-workflow-ci
work_id: 241
issue_url: https://github.com/fractary/claude-plugins/issues/241
title: Add CI workflow polling to pr-review command
type: feature
status: draft
created: 2025-12-05
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: Add CI Workflow Polling to pr-review Command

**Issue**: [#241](https://github.com/fractary/claude-plugins/issues/241)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-05

## Summary

Enhance the `fractary-repo:pr-review` command to automatically poll and wait for all GitHub CI workflows to complete before proceeding with PR review. This enables automatic sequential execution of `pr-create` followed by `pr-review` in FABER workflows without manual intervention or timing issues.

## Problem Statement

Currently, when `pr-review` runs immediately after `pr-create`, it fails because GitHub CI workflows are often still in progress. Users must wait an unknown amount of time before manually running the review. This breaks automation in FABER workflows and requires manual intervention.

## User Stories

### Enable Automated PR Review Workflow
**As a** FABER workflow automation user
**I want** `pr-review` to wait for CI checks to complete
**So that** I can automatically chain `pr-create` → `pr-review` without manual timing intervention

**Acceptance Criteria**:
- [ ] pr-review polls for CI workflow completion before starting review
- [ ] Default polling interval is 60-120 seconds
- [ ] Review only proceeds when all CI checks complete successfully
- [ ] Failed CI checks are detected and reported as failure status
- [ ] Timeout protection prevents infinite polling (15 minute default)
- [ ] Polling is done via script to minimize Claude context usage

## Functional Requirements

- **FR1**: Poll GitHub API for workflow run status on the PR's ref/branch
- **FR2**: Check all CI workflow checks for completion (success, failure, or other terminal state)
- **FR3**: Wait between polls using configurable interval (default 60-120 seconds)
- **FR4**: Continue with PR review only after all checks complete successfully
- **FR5**: Detect and report failed CI checks with failure status
- **FR6**: Implement timeout mechanism (15 minute default) to prevent infinite polling
- **FR7**: Support configuration of polling interval and timeout via plugin config
- **FR8**: Integrate polling check before review process in pr-review skill

## Non-Functional Requirements

- **NFR1**: Polling should be deterministic and executed outside Claude context (shell script)
- **NFR2**: Script should be idempotent and handle network failures gracefully
- **NFR3**: Polling should not consume Claude context tokens for each check
- **NFR4**: Performance impact on initial pr-review call should be minimal

## Technical Design

### Architecture Changes

The pr-review skill will be modified to:
1. Call a new `check-ci-workflows.sh` script before proceeding with review
2. Script polls GitHub API until CI completes or timeout occurs
3. Return exit code indicating success/failure/timeout
4. pr-review skill handles the exit code and either proceeds or reports failure

### Implementation Flow

```
pr-review command triggered
  ↓
[NEW] poll-ci-workflows.sh script starts
  ↓ (polling loop - runs in background, deterministic)
Check workflow status via GitHub API
  ↓
Is complete? (success/failure/timeout)
  ├→ Yes: exit script, return status
  └→ No: wait 60-120s, check again
  ↓
pr-review skill receives status
  ├→ Success: proceed with review
  ├→ Failed: report failure with error details
  └→ Timeout: report timeout error
```

### GitHub API Usage

Use GitHub API endpoints to check workflow status:
- `GET /repos/{owner}/{repo}/pulls/{pull_number}` - Get PR details (statuses/check_runs)
- `GET /repos/{owner}/{repo}/commits/{ref}/check-runs` - Get check run status
- `GET /repos/{owner}/{repo}/commits/{ref}/status` - Get combined status

### Configuration

Add to `.fractary/plugins/repo/config.json`:
```json
{
  "pr_review": {
    "polling": {
      "enabled": true,
      "interval_seconds": 60,
      "timeout_seconds": 900,
      "wait_for_ci": true
    }
  }
}
```

### New Files to Create

- `plugins/repo/skills/pr-reviewer/scripts/poll-ci-workflows.sh` - Main polling script
- `plugins/repo/skills/pr-reviewer/scripts/lib/workflow-utils.sh` - Helper functions
- `plugins/repo/skills/pr-reviewer/workflow/wait-for-ci.md` - Workflow documentation

### Modified Files

- `plugins/repo/skills/pr-reviewer/SKILL.md` - Add polling section, update workflow
- `plugins/repo/skills/pr-reviewer/workflow/*.md` - Add CI polling steps
- `.fractary/plugins/repo/config.json` (example) - Add polling configuration

## Implementation Plan

### Phase 1: Create Polling Script
- Create `poll-ci-workflows.sh` script
- Implement GitHub API calls to check workflow status
- Implement polling loop with configurable interval
- Implement timeout protection
- Add error handling for API failures
- Add logging/output for debugging

### Phase 2: Integrate with pr-review Skill
- Add polling check to beginning of pr-review workflow
- Load polling config from plugin config
- Handle polling script exit codes
- Report status and errors appropriately
- Update skill documentation

### Phase 3: Configuration and Testing
- Add polling configuration section to example config
- Test with different polling intervals and timeout values
- Test failure scenarios (CI failures, timeouts, API errors)
- Document configuration options

## Testing Strategy

### Unit Tests

Test polling script components:
- Workflow status parsing from GitHub API responses
- Polling logic with various status values
- Timeout calculation and enforcement
- Interval timing
- Error handling for API failures

### Integration Tests

Test with actual GitHub workflows:
- Poll actual PR with running workflows
- Verify correct success detection when workflows pass
- Verify failure detection when workflows fail
- Verify timeout protection
- Test sequential pr-create → pr-review flow

### E2E Tests

Full FABER workflow tests:
- Create branch and PR
- Run pr-review immediately (triggers polling)
- Verify review completes after CI
- Test with different CI configuration

## Dependencies

- `curl` or `gh` CLI for GitHub API calls
- GitHub authentication token (already available in repo config)
- Bash 4.0+ for associative arrays and advanced features

## Risks and Mitigations

- **Risk**: GitHub API rate limiting during intensive polling
  - **Likelihood**: Low
  - **Impact**: High (polling stops, user must retry)
  - **Mitigation**: Implement exponential backoff, use GraphQL for efficient queries, cache workflow status

- **Risk**: CI workflows stuck/hanging indefinitely
  - **Likelihood**: Medium
  - **Impact**: Medium (timeout protects, but 15min is long)
  - **Mitigation**: Timeout is configurable, document recommended values, add health check alerts

- **Risk**: GitHub API authentication token expiration
  - **Likelihood**: Low
  - **Impact**: High (polling fails completely)
  - **Mitigation**: Use repo plugin's existing auth, refresh token handling already in place

- **Risk**: Network failures during polling loop
  - **Likelihood**: Medium
  - **Impact**: Low (script retries, eventually times out)
  - **Mitigation**: Implement retry logic with exponential backoff, log network errors

## Documentation Updates

- `plugins/repo/docs/PR-REVIEW-WORKFLOW.md` - Document CI polling feature
- `plugins/repo/skills/pr-reviewer/SKILL.md` - Add section on polling behavior
- `plugins/repo/config/repo.example.json` - Add polling configuration example
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md` - Reference this as deterministic polling pattern

## Rollout Plan

1. **Phase 1 (Complete)**: Implement polling script with full test coverage
2. **Phase 2 (Complete)**: Integrate with pr-review skill and update documentation
3. **Phase 3 (Testing)**: Internal testing with various workflows
4. **Phase 4 (Release)**: Release with default polling enabled (can be disabled in config)
5. **Phase 5 (Monitor)**: Monitor for issues, collect user feedback

## Success Metrics

- Polling correctly waits for CI completion in 100% of test scenarios
- User can chain pr-create → pr-review without manual timing
- Timeout protection prevents hanging after configured duration
- Failed CI workflows are detected and reported with 100% accuracy
- No regression in pr-review performance when polling is disabled

## Implementation Notes

### Key Design Decisions

1. **Polling in Shell Script**: Determined outside Claude context to preserve tokens and ensure deterministic operation
2. **Configurable Intervals**: Different projects have different CI speeds; allow customization
3. **Timeout Protection**: 15 minutes is reasonable default but configurable for complex workflows
4. **Graceful Failure Handling**: Script failures don't break pr-review, just report status

### Script Architecture

The `poll-ci-workflows.sh` script should:
- Be completely self-contained and deterministic
- Not depend on Claude or LLM context
- Log all polling attempts with timestamps
- Support dry-run mode for testing
- Exit with meaningful exit codes (0=success, 1=CI failed, 2=timeout, 3=API error)

### Integration Points

- pr-review skill calls polling script at start of review process
- Polling script uses repo config for interval/timeout settings
- GitHub auth token comes from repo plugin's existing configuration
- Results integrated into pr-review workflow logging

### Future Enhancements

- Support for other CI systems (GitLab, Bitbucket)
- Webhook-based notification instead of polling (reduces API calls)
- Parallel workflow checking for multi-workflow scenarios
- Integration with FABER workflow metrics/monitoring
