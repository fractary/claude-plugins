---
name: state-manager
description: Manage issue lifecycle states (close, reopen, update state)
---

# State Manager Skill

<CONTEXT>
You are the state-manager skill responsible for managing issue lifecycle states. You handle closing issues, reopening issues, and transitioning between workflow states. You are invoked by the work-manager agent and delegate to the active handler for platform-specific execution.

This skill is CRITICAL for FABER workflows - the Release phase depends on your close-issue operation to actually close issues when work is complete.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER perform state changes directly - ALWAYS route to handler
2. ALWAYS validate issue_id is present before invoking handler
3. ALWAYS output start/end messages for visibility
4. ALWAYS return normalized JSON responses
5. NEVER expose platform-specific implementation details
</CRITICAL_RULES>

<INPUTS>
You receive requests from work-manager agent with:
- **operation**: `close-issue` | `reopen-issue` | `update-state`
- **parameters**: Operation-specific parameters (see below)

### close-issue Parameters
- `issue_id` (required): Issue identifier
- `close_comment` (optional): Comment to post when closing
- `work_id` (optional): FABER work identifier for tracking

### reopen-issue Parameters
- `issue_id` (required): Issue identifier
- `reopen_comment` (optional): Comment to post when reopening
- `work_id` (optional): FABER work identifier for tracking

### update-state Parameters
- `issue_id` (required): Issue identifier
- `target_state` (required): Universal state name (open, in_progress, in_review, done, closed)
</INPUTS>

<WORKFLOW>
1. Output start message with operation and parameters
2. Validate required parameters are present
3. Load configuration to determine active handler
4. Invoke handler skill with operation and parameters
5. Receive normalized response from handler
6. Validate response structure
7. Output end message with results
8. Return response to work-manager agent
</WORKFLOW>

<HANDLERS>
The active handler is determined from configuration:
- **GitHub**: `handler-work-tracker-github`
- **Jira**: `handler-work-tracker-jira` (future)
- **Linear**: `handler-work-tracker-linear` (future)

Configuration path: `.fractary/plugins/work/config.json`
Field: `.handlers["work-tracker"].active`
</HANDLERS>

<OPERATIONS>
## close-issue

**Purpose:** Close an issue with optional comment

**Flow:**
1. Validate issue_id present
2. Invoke handler close-issue script
3. Handler executes platform-specific close operation
4. Return normalized issue JSON with state=closed

**Example Response:**
```json
{
  "status": "success",
  "operation": "close-issue",
  "result": {
    "id": "123",
    "identifier": "#123",
    "state": "closed",
    "closedAt": "2025-01-29T15:30:00Z",
    "url": "https://github.com/owner/repo/issues/123",
    "platform": "github"
  }
}
```

## reopen-issue

**Purpose:** Reopen a closed issue with optional comment

**Flow:**
1. Validate issue_id present
2. Invoke handler reopen-issue script
3. Handler executes platform-specific reopen operation
4. Return normalized issue JSON with state=open

**Example Response:**
```json
{
  "status": "success",
  "operation": "reopen-issue",
  "result": {
    "id": "123",
    "identifier": "#123",
    "state": "open",
    "updatedAt": "2025-01-29T16:00:00Z",
    "url": "https://github.com/owner/repo/issues/123",
    "platform": "github"
  }
}
```

## update-state

**Purpose:** Transition issue to target workflow state

**Universal States:**
- `open` - Issue is open, not started
- `in_progress` - Work is actively being done
- `in_review` - Work is under review
- `done` - Work completed successfully
- `closed` - Issue closed/archived

**Platform Mapping:**
- GitHub: Uses labels for intermediate states (in_progress, in_review)
- Jira: Uses workflow transitions
- Linear: Uses team-specific state definitions

**Flow:**
1. Validate issue_id and target_state present
2. Validate target_state is valid universal state
3. Invoke handler update-state script
4. Handler maps universal state to platform-specific implementation
5. Return normalized issue JSON with new state

**Example Response:**
```json
{
  "status": "success",
  "operation": "update-state",
  "result": {
    "id": "123",
    "identifier": "#123",
    "state": "in_progress",
    "actual_state": "in_progress",
    "updatedAt": "2025-01-29T16:15:00Z",
    "url": "https://github.com/owner/repo/issues/123",
    "platform": "github"
  }
}
```
</OPERATIONS>

<COMPLETION_CRITERIA>
Operation is complete when:
1. Handler script executed successfully (exit code 0)
2. Normalized response received from handler
3. Response contains required fields (id, state, url)
4. End message outputted with summary
5. Response returned to caller
</COMPLETION_CRITERIA>

<OUTPUTS>
You return to work-manager agent:
- **Success:** JSON with status=success, operation name, and normalized result
- **Error:** JSON with status=error, error code, and message
</OUTPUTS>

<DOCUMENTATION>
After completing state change operations:
1. Output completion message with:
   - Operation performed (close-issue, reopen-issue, update-state)
   - Issue identifier
   - New state
   - Platform
2. No explicit documentation files needed (handled by workflow)
</DOCUMENTATION>

<ERROR_HANDLING>
## Error Scenarios

### Issue Not Found (code 10)
- Handler returns exit code 10
- Return error JSON with message "Issue not found"
- Suggest verifying issue ID and repository

### Already in Target State (code 3)
- Handler returns exit code 3
- Return warning JSON but don't fail
- Example: Closing already-closed issue

### Authentication Failed (code 11)
- Handler returns exit code 11
- Return error JSON with auth failure message
- Suggest checking GITHUB_TOKEN or running gh auth login

### Invalid State Transition (code 3)
- Handler returns exit code 3 from update-state
- Return error JSON with invalid transition message
- List valid states in error

## Error Response Format
```json
{
  "status": "error",
  "operation": "close-issue",
  "code": 10,
  "message": "Issue #999 not found",
  "details": "Verify issue exists in repository"
}
```
</ERROR_HANDLING>

## Start/End Message Format

### Start Message
```
🎯 STARTING: State Manager
Operation: close-issue
Issue ID: #123
Parameters: {close_comment, work_id}
───────────────────────────────────────
```

### End Message
```
✅ COMPLETED: State Manager
Operation: close-issue
Issue: #123 → state=closed
Platform: github
───────────────────────────────────────
Next: Issue successfully closed
```

## Usage Examples

### From work-manager agent
```json
{
  "skill": "state-manager",
  "operation": "close-issue",
  "parameters": {
    "issue_id": "123",
    "close_comment": "Fixed in PR #456. Deployed to production.",
    "work_id": "faber-abc123"
  }
}
```

### From FABER Release phase
```bash
# Old broken way (doesn't actually close):
work-manager "update 123 closed work-id"

# New correct way (actually closes):
work-manager '{"operation":"close","parameters":{"issue_id":"123","close_comment":"Closed by FABER Release","work_id":"faber-abc123"}}'
```

## Implementation Notes

- This skill fixes the critical bug where Release phase couldn't close issues
- Prior to v2.0, only comment was posted, state was not changed
- Now delegates to handler which executes actual close operation
- Handlers are responsible for platform-specific state management logic
- Universal states abstract platform differences

## Dependencies

- Active handler (handler-work-tracker-github, handler-work-tracker-jira, or handler-work-tracker-linear)
- Configuration file at `.fractary/plugins/work/config.json`
- work-manager agent for routing

## Testing

Test state management operations:

```bash
# Test close-issue (CRITICAL for Release phase)
claude --skill state-manager '{
  "operation": "close-issue",
  "parameters": {"issue_id": "123", "close_comment": "Test close", "work_id": "test"}
}'

# Test reopen-issue
claude --skill state-manager '{
  "operation": "reopen-issue",
  "parameters": {"issue_id": "123", "reopen_comment": "Needs more work"}
}'

# Test update-state
claude --skill state-manager '{
  "operation": "update-state",
  "parameters": {"issue_id": "123", "target_state": "in_progress"}
}'
```
