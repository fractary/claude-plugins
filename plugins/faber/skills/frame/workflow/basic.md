# Frame Phase: Basic Workflow

This workflow implements the basic Frame phase operations for FABER workflows. It fetches work items, classifies work types, and prepares environments for implementation.

## Overview

The Frame phase is responsible for:
1. Fetching work item details from tracking systems
2. Classifying work type (/bug, /feature, /chore, /patch)
3. Preparing domain-specific environments
4. Creating initial workflow context

## Implementation Steps

### Step 1: Fetch Work Item

Use the work-manager agent to retrieve work item details:

```markdown
Use the @agent-fractary-work:work-manager agent with the following request:
{
  "operation": "fetch-issue",
  "parameters": {
    "issue_number": "{source_id}"
  }
}
```

Extract work item information:
- **Title**: Work item title
- **Description**: Full description or body
- **Labels**: Associated labels
- **State**: Current state (open, closed, etc.)
- **Assignees**: Assigned users

**Error Handling**: If work item fetch fails, update state with error and exit:
```bash
if [ $? -ne 0 ]; then
    echo "❌ Failed to fetch work item from ${source_type}"
    # Update state with error
    "$CORE_SKILL/state-update-phase.sh" "frame" "failed" '{"error": "Failed to fetch work item"}'
    # Post error notification
    "$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "frame" "Frame failed: Could not fetch work item" '["retry"]'
    exit 1
fi
```

### Step 2: Classify Work Type

Use the work-manager agent to classify the work item:

```markdown
Use the @agent-fractary-work:work-manager agent with the following request:
{
  "operation": "classify-issue",
  "parameters": {
    "issue_number": "{source_id}",
    "title": "{work_item_title}",
    "labels": "{work_item_labels}",
    "description": "{work_item_description}"
  }
}
```

The classifier returns one of:
- `/bug` - Bug fixes, defects, errors
- `/feature` - New features, enhancements
- `/chore` - Maintenance, refactoring, documentation
- `/patch` - Hotfixes, urgent patches, security fixes

**Default Behavior**: If classification is unclear, default to `/feature` and post a warning.

**Store Classification**:
```bash
WORK_TYPE=$(echo "$CLASSIFY_RESULT" | jq -r '.work_type // "/feature"')
echo "✅ Work classified as: $WORK_TYPE"
```

### Step 3: Post Frame Start Notification

Post a status card to the work tracking system:

```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "frame" "🚀 **Frame Phase Started**

**Work ID**: \`${WORK_ID}\`
**Type**: ${WORK_TYPE}
**Domain**: ${WORK_DOMAIN}

Fetching work item details and setting up environment..." '[]'
```

This notifies stakeholders that the workflow has begun.

### Step 4: Start Session Capture (Optional)

**If configured**, start session capture to log all subsequent conversation:

```markdown
Use the @agent-fractary-logs:log-manager agent with the following request:
{
  "operation": "capture",
  "parameters": {
    "issue_number": "{source_id}",
    "work_id": "{work_id}"
  }
}
```

This captures all LLM interactions for:
- Future debugging
- Process improvement
- Compliance and audit
- Knowledge extraction

**Configuration Check**:
```bash
SESSION_CAPTURE=$(echo "$CONFIG_JSON" | jq -r '.logs.session_capture // "auto"')

if [ "$SESSION_CAPTURE" = "auto" ] || [ "$SESSION_CAPTURE" = "manual" ]; then
    echo "📝 Starting session capture..."
    # Invoke log-manager agent as shown above
    echo "✅ Session capture started"
fi
```

**Skip if**: `logs.session_capture = "off"` in configuration.

### Step 5: Setup Domain Environment

Domain-specific environment preparation:

#### Engineering Domain

For engineering work, prepare the development environment:

**Create Branch with Worktree**:
```markdown
Use the @agent-fractary-repo:repo-manager agent with the following request:
{
  "operation": "create-branch",
  "parameters": {
    "mode": "description",
    "work_id": "{work_id}",
    "prefix": "{branch_prefix}",
    "description": "{work_item_title}",
    "base_branch": "main",
    "worktree": true
  }
}
```

**CRITICAL**: The `worktree: true` parameter ensures the workflow executes in an isolated worktree.

**Branch Prefix Mapping**: Map work_type to branch prefix:
- `/bug` → `fix`
- `/feature` → `feat`
- `/chore` → `chore`
- `/patch` → `hotfix`
- Default → `feat`

The repo-manager will:
- Generate branch name (e.g., `feat/123-add-export`)
- Check registry (`~/.fractary/repo/worktrees.json`) for existing worktree
- If worktree exists for this work_id:
  - Reuse existing worktree (enables resume)
  - Switch to worktree directory: `.worktrees/feat-123-add-export`
  - Update registry timestamp
- If worktree does NOT exist:
  - Create branch from default branch (usually `main`)
  - Create worktree in `.worktrees/feat-123-add-export` subfolder
  - Register worktree in registry
  - Switch to worktree directory
- Return branch name and worktree path

**Benefits of Worktree Execution**:
- Prevents workflow interference (can run #123, pause, run #124 without conflicts)
- Enables resume (restarting #123 reuses same worktree)
- Isolates state files (each worktree has own `.fractary/plugins/faber/state.json`)
- Stays within Claude's working directory scope (`.worktrees/` is subfolder, not parallel dir)

**Store Branch Information**:
```bash
BRANCH_NAME=$(echo "$BRANCH_RESULT" | jq -r '.branch_name')
echo "✅ Branch created: $BRANCH_NAME"
```

**Optional: Setup Development Environment**
- Check for `package.json` → Run `npm install`
- Check for `pyproject.toml` → Run `uv sync`
- Check for database migrations → Initialize database
- Allocate ports if needed (for services)

These are optional optimizations. The basic workflow focuses on branch creation.

#### Design Domain (Future)

For design work:
- Create design workspace directory
- Load design templates
- Prepare asset directories

#### Writing Domain (Future)

For writing work:
- Create document workspace
- Load style guides
- Prepare reference materials

#### Data Domain (Future)

For data work:
- Create data workspace
- Load data sources
- Prepare analysis environment

### Step 6: Update Workflow State

Update the workflow state with Frame results:

```bash
# Build Frame data JSON
FRAME_DATA=$(cat <<EOF
{
  "work_type": "$WORK_TYPE",
  "title": $(echo "$WORK_ITEM_TITLE" | jq -R .),
  "description": $(echo "$WORK_ITEM_DESCRIPTION" | jq -Rs .),
  "labels": $(echo "$WORK_ITEM_LABELS" | jq -R . | jq -s .),
  "branch_name": "$BRANCH_NAME",
  "state": "open",
  "source_url": "$WORK_ITEM_URL"
}
EOF
)

# Update state
"$CORE_SKILL/state-update-phase.sh" "frame" "completed" "$FRAME_DATA"
```

This stores all Frame results in `.fractary/plugins/faber/state.json` for use by subsequent phases.

### Step 7: Post Frame Complete Notification

Post completion status to work tracking system:

```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "frame" "✅ **Frame Phase Complete**

**Work Type**: ${WORK_TYPE}
**Domain**: ${WORK_DOMAIN}
**Branch**: \`${BRANCH_NAME}\`

Environment prepared and ready for Architect phase.

**Next**: Generating implementation specification..." '[]'
```

### Step 8: Return Results

Return Frame results to workflow-manager:

```bash
cat <<EOF
{
  "status": "success",
  "phase": "frame",
  "work_type": "$WORK_TYPE",
  "work_item": {
    "title": "$WORK_ITEM_TITLE",
    "description": "$WORK_ITEM_DESCRIPTION",
    "labels": $WORK_ITEM_LABELS,
    "url": "$WORK_ITEM_URL"
  },
  "environment": {
    "branch_name": "$BRANCH_NAME",
    "ready": true
  }
}
EOF
```

## Success Criteria

Frame phase succeeds when:
- ✅ Work item fetched successfully
- ✅ Work type classified
- ✅ Frame start notification posted
- ✅ Domain environment prepared (branch created for engineering)
- ✅ Workflow state updated with Frame data
- ✅ Frame complete notification posted

## Error Recovery

### Work Item Fetch Failure
- **Action**: Update state, post error notification, exit with code 1
- **Recovery**: User can retry Frame phase

### Classification Failure
- **Action**: Default to `/feature`, post warning, continue
- **Recovery**: Automatic (use default)

### Branch Creation Failure
- **Action**: Update state, post error notification, exit with code 1
- **Recovery**: User can retry Frame phase

### State Update Failure
- **Action**: Log error, retry once, exit with code 1 if persistent
- **Recovery**: Check state file permissions and ensure `.fractary/plugins/faber/` directory exists

## Configuration

Frame phase respects these configuration settings:

```toml
[project]
repo_system = "github"  # Where to create branches

[systems.repo_config]
default_branch = "main"  # Base branch for new work

[defaults]
work_domain = "engineering"  # Default domain
```

## Testing

To test Frame phase independently:

```bash
# Via workflow-manager (partial execution)
claude --agent workflow-manager "abc12345 github 123 engineering" "" "frame" "frame" ""

# Or invoke skill directly (for testing)
# (Skill invocation syntax depends on skill framework)
```

## Future Enhancements

1. **Parallel Dependency Installation** - Run `npm install` concurrently with other setup
2. **Environment Validation** - Check all prerequisites before starting
3. **Resource Allocation** - Allocate ports, databases, etc. dynamically
4. **Domain Detection** - Auto-detect domain from repository structure

**Note**: Workspace isolation via git worktrees is already implemented (see Step 5).

## Notes

- This is the **batteries-included** implementation
- Domain plugins can override with domain-specific workflows
- Keep this implementation simple and generic
- Avoid domain-specific logic here (delegate to domain bundles)

This basic Frame workflow provides a solid foundation for all FABER workflows while remaining simple and maintainable.
