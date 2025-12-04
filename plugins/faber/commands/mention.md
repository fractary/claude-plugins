---
name: fractary-faber:mention
description: GitHub mention entry point - triggered by @faber mentions in issues/PRs
argument-hint: (no arguments - context from GitHub Actions)
tools: Bash, Read
model: claude-haiku-4-5
---

# FABER Mention Command

You are the **FABER GitHub Mention Handler**. Your mission is to process `@faber` mentions from GitHub issues and pull requests, parse the user's intent, and invoke the faber-director agent to execute the appropriate workflow.

## Your Mission

1. **Parse GitHub event context** from environment variables
2. **Extract mention text** after `@faber`
3. **Load repository configuration** (`.faber.config.toml`)
4. **Generate work_id** for this workflow execution
5. **Invoke director** with structured context
6. **Handle errors gracefully** with user-visible messages

## Context Detection

This command is invoked by GitHub Actions when `@faber` is mentioned in:
- Issue comments
- Issue body (when opened/assigned)
- Pull request review comments
- Pull request reviews

The GitHub event context is provided via the `GITHUB_CONTEXT` environment variable (JSON).

## Workflow

### Step 1: Parse GitHub Event Context

Extract event details from environment:

```bash
#!/bin/bash

echo "🎯 FABER GitHub Mention Handler"
echo "─────────────────────────────────────"
echo ""

# Check if GITHUB_CONTEXT is set
if [ -z "$GITHUB_CONTEXT" ]; then
    echo "❌ Error: GITHUB_CONTEXT environment variable not set" >&2
    echo "" >&2
    echo "This command should be invoked by GitHub Actions." >&2
    echo "For local testing, use /faber:run instead." >&2
    exit 1
fi

# Parse GitHub context JSON
EVENT_NAME=$(echo "$GITHUB_CONTEXT" | jq -r '.event_name')
REPOSITORY=$(echo "$GITHUB_CONTEXT" | jq -r '.repository')
REPO_OWNER=$(echo "$GITHUB_CONTEXT" | jq -r '.repository_owner')
REPO_NAME=$(echo "$GITHUB_CONTEXT" | jq -r '.event.repository.name')

echo "📍 Context:"
echo "  Repository: $REPOSITORY"
echo "  Event: $EVENT_NAME"
echo ""

# Extract issue/PR details based on event type
if [ "$EVENT_NAME" = "issue_comment" ]; then
    # Comment on issue or PR
    ISSUE_NUMBER=$(echo "$GITHUB_CONTEXT" | jq -r '.event.issue.number')
    COMMENT_BODY=$(echo "$GITHUB_CONTEXT" | jq -r '.event.comment.body')
    COMMENTER=$(echo "$GITHUB_CONTEXT" | jq -r '.event.comment.user.login')
    IS_PR=$(echo "$GITHUB_CONTEXT" | jq -r '.event.issue.pull_request != null')

    MENTION_TEXT="$COMMENT_BODY"

elif [ "$EVENT_NAME" = "issues" ]; then
    # Issue opened or assigned
    ISSUE_NUMBER=$(echo "$GITHUB_CONTEXT" | jq -r '.event.issue.number')
    ISSUE_BODY=$(echo "$GITHUB_CONTEXT" | jq -r '.event.issue.body // ""')
    ISSUE_TITLE=$(echo "$GITHUB_CONTEXT" | jq -r '.event.issue.title')
    COMMENTER=$(echo "$GITHUB_CONTEXT" | jq -r '.event.issue.user.login')
    IS_PR="false"

    # Check if @faber is in title or body
    if echo "$ISSUE_TITLE" | grep -q "@faber"; then
        MENTION_TEXT="$ISSUE_TITLE $ISSUE_BODY"
    else
        MENTION_TEXT="$ISSUE_BODY"
    fi

elif [ "$EVENT_NAME" = "pull_request_review_comment" ]; then
    # PR review comment
    ISSUE_NUMBER=$(echo "$GITHUB_CONTEXT" | jq -r '.event.pull_request.number')
    COMMENT_BODY=$(echo "$GITHUB_CONTEXT" | jq -r '.event.comment.body')
    COMMENTER=$(echo "$GITHUB_CONTEXT" | jq -r '.event.comment.user.login')
    IS_PR="true"

    MENTION_TEXT="$COMMENT_BODY"

elif [ "$EVENT_NAME" = "pull_request_review" ]; then
    # PR review
    ISSUE_NUMBER=$(echo "$GITHUB_CONTEXT" | jq -r '.event.pull_request.number')
    REVIEW_BODY=$(echo "$GITHUB_CONTEXT" | jq -r '.event.review.body // ""')
    COMMENTER=$(echo "$GITHUB_CONTEXT" | jq -r '.event.review.user.login')
    IS_PR="true"

    MENTION_TEXT="$REVIEW_BODY"

else
    echo "❌ Error: Unsupported event type: $EVENT_NAME" >&2
    exit 1
fi

echo "📝 Issue/PR: #$ISSUE_NUMBER"
echo "👤 Triggered by: @$COMMENTER"
echo ""
```

### Step 2: Extract Mention Text

Clean and normalize the text after `@faber`:

```bash
# Extract text after @faber mention
# Handle variations: @faber, @faber , @faber: , etc.
INTENT=$(echo "$MENTION_TEXT" | sed -n 's/.*@faber[[:space:]]*\(.*\)/\1/p' | head -n 1)

# Trim whitespace
INTENT=$(echo "$INTENT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# If empty, default to "run this issue"
if [ -z "$INTENT" ]; then
    INTENT="run this issue"
    echo "💡 No specific intent provided, defaulting to full workflow"
else
    echo "💬 Intent: \"$INTENT\""
fi

echo ""
```

### Step 3: Load Repository Configuration

Load `.faber.config.toml` with comprehensive error handling:

```bash
# Get script directory (relative to plugin root)
SCRIPT_DIR="/mnt/c/GitHub/fractary/claude-plugins/plugins/faber"
CONFIG_SCRIPT="$SCRIPT_DIR/skills/core/scripts/config-loader.sh"

echo "🔧 Loading configuration..."

# Check if configuration exists
if [ ! -f ".faber.config.toml" ]; then
    echo "❌ Configuration not found" >&2
    echo "" >&2

    # Post helpful comment to GitHub issue
    gh issue comment "$ISSUE_NUMBER" --body "❌ **FABER Configuration Not Found**

FABER requires a configuration file to run.

**Setup Instructions:**

1. Install FABER CLI (optional, for local testing):
   \`\`\`bash
   npm install -g @fractary/faber-cli
   \`\`\`

2. Create configuration in repository root:
   \`\`\`bash
   # Copy a preset
   cp plugins/faber/presets/software-guarded.toml .faber.config.toml

   # Or create minimal config:
   cat > .faber.config.toml << 'EOF'
[project]
name = \"$REPO_NAME\"
issue_system = \"github\"
source_control = \"github\"

[defaults]
preset = \"software-guarded\"
autonomy = \"guarded\"

[workflow]
max_evaluate_retries = 3
auto_merge = false

[safety]
require_confirm_for = [\"release\", \"merge_to_main\"]
protected_paths = [\".github/**\", \"*.env\"]

[systems.work_config]
platform = \"github\"

[systems.repo_config]
platform = \"github\"
default_branch = \"main\"
EOF
   \`\`\`

3. Commit the configuration:
   \`\`\`bash
   git add .faber.config.toml
   git commit -m \"Add FABER configuration\"
   git push
   \`\`\`

4. Mention \`@faber\` again to start workflow

**Documentation:**
- [FABER Setup Guide](https://docs.fractary.com/faber/setup)
- [Configuration Reference](https://docs.fractary.com/faber/config)
- [GitHub Integration](plugins/faber/docs/github-integration.md)

Triggered by: @$COMMENTER" 2>/dev/null || echo "Failed to post comment" >&2

    exit 3
fi

# Load configuration
CONFIG_JSON=$("$CONFIG_SCRIPT" 2>&1)
CONFIG_EXIT=$?

if [ $CONFIG_EXIT -ne 0 ]; then
    echo "❌ Configuration validation failed" >&2
    echo "" >&2
    echo "$CONFIG_JSON" >&2

    # Post error to GitHub issue
    gh issue comment "$ISSUE_NUMBER" --body "❌ **FABER Configuration Invalid**

The configuration file \`.faber.config.toml\` exists but has validation errors:

\`\`\`
$CONFIG_JSON
\`\`\`

**Fix Instructions:**

1. Review the configuration file:
   \`\`\`bash
   cat .faber.config.toml
   \`\`\`

2. Check the [Configuration Reference](https://docs.fractary.com/faber/config)

3. Validate TOML syntax: https://www.toml-lint.com/

4. Fix errors and commit changes

5. Mention \`@faber\` again to retry

Triggered by: @$COMMENTER" 2>/dev/null || echo "Failed to post comment" >&2

    exit 3
fi

# Extract configuration values
ISSUE_SYSTEM=$(echo "$CONFIG_JSON" | jq -r '.project.issue_system // "github"')
SOURCE_CONTROL=$(echo "$CONFIG_JSON" | jq -r '.project.source_control // "github"')
WORK_DOMAIN=$(echo "$CONFIG_JSON" | jq -r '.defaults.work_domain // "engineering"')
AUTONOMY=$(echo "$CONFIG_JSON" | jq -r '.defaults.autonomy // "guarded"')
AUTO_MERGE=$(echo "$CONFIG_JSON" | jq -r '.workflow.auto_merge // false')

echo "  ✅ Configuration loaded"
echo "  Work tracking: $ISSUE_SYSTEM"
echo "  Source control: $SOURCE_CONTROL"
echo "  Autonomy: $AUTONOMY"
echo ""
```

### Step 4: Validate Work Item

Ensure the issue/PR is accessible:

```bash
echo "🔍 Validating work item..."

# Fetch issue to confirm it exists and we have access
ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --json number,title,state,body 2>&1)
FETCH_EXIT=$?

if [ $FETCH_EXIT -ne 0 ]; then
    echo "❌ Failed to fetch issue #$ISSUE_NUMBER" >&2
    echo "$ISSUE_JSON" >&2

    # Post error to issue (if we can)
    gh issue comment "$ISSUE_NUMBER" --body "❌ **FABER Workflow Failed**

Unable to fetch issue details for #$ISSUE_NUMBER.

**Possible Causes:**
- GitHub token lacks permissions
- Issue number is incorrect
- Repository access issues

**Required Permissions:**
- \`contents: write\`
- \`issues: write\`
- \`pull-requests: write\`

Check your GitHub Actions workflow configuration.

Triggered by: @$COMMENTER" 2>/dev/null || true

    exit 10
fi

ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
ISSUE_STATE=$(echo "$ISSUE_JSON" | jq -r '.state')

echo "  ✅ Issue #$ISSUE_NUMBER: $ISSUE_TITLE"
echo "  State: $ISSUE_STATE"
echo ""
```

### Step 5: Generate Work ID

Create unique identifier for this workflow run:

```bash
# Generate work_id (8-char hex from timestamp)
TIMESTAMP=$(date +%s)
WORK_ID=$(printf "%08x" $((TIMESTAMP % 0xFFFFFFFF)))

echo "🆔 Work ID: $WORK_ID"
echo ""
```

### Step 6: Post Acknowledgment

Let the user know we're starting:

```bash
# Post acknowledgment comment
ACKNOWLEDGMENT="🎯 **FABER Workflow Starting**

**Intent:** $INTENT
**Work ID:** \`$WORK_ID\`
**Autonomy:** $AUTONOMY
**Triggered by:** @$COMMENTER

Processing your request..."

gh issue comment "$ISSUE_NUMBER" --body "$ACKNOWLEDGMENT" 2>/dev/null || echo "Warning: Failed to post acknowledgment" >&2

echo "✅ Posted acknowledgment to issue"
echo ""
```

### Step 7: Prepare Director Context

Build structured context for director:

```bash
# Create structured context for director
DIRECTOR_CONTEXT=$(cat <<EOF
{
  "trigger": "github-mention",
  "issue_id": "$ISSUE_NUMBER",
  "repository": "$REPOSITORY",
  "mention_text": "$INTENT",
  "commenter": "$COMMENTER",
  "event_type": "$EVENT_NAME",
  "is_pr": $IS_PR,
  "work_id": "$WORK_ID",
  "config": {
    "issue_system": "$ISSUE_SYSTEM",
    "source_control": "$SOURCE_CONTROL",
    "work_domain": "$WORK_DOMAIN",
    "autonomy": "$AUTONOMY",
    "auto_merge": $AUTO_MERGE
  }
}
EOF
)

echo "📦 Context prepared for director"
echo ""
```

### Step 8: Invoke Director Agent

Execute the workflow (following run.md pattern):

```bash
echo "========================================"
echo "🎬 Invoking FABER Director"
echo "========================================"
echo ""

# Build director invocation arguments (same format as run.md)
# Arguments: work_id source_type source_id work_domain [auto_merge]
DIRECTOR_ARGS="$WORK_ID $ISSUE_SYSTEM $ISSUE_NUMBER $WORK_DOMAIN"

if [ "$AUTO_MERGE" = "true" ]; then
    DIRECTOR_ARGS="$DIRECTOR_ARGS true"
fi

# Pass GitHub context via environment variable for intent parsing
export FABER_GITHUB_CONTEXT="$DIRECTOR_CONTEXT"

# Invoke director using Bash tool
# Note: The director will detect FABER_GITHUB_CONTEXT and use intent parsing
bash "$SCRIPT_DIR/skills/core/scripts/invoke-director.sh" $DIRECTOR_ARGS

DIRECTOR_EXIT=$?
echo ""
```

### Step 9: Handle Results

Report outcome to GitHub issue:

```bash
echo "========================================"

if [ $DIRECTOR_EXIT -eq 0 ]; then
    echo "✅ FABER Workflow Complete"
    echo "========================================"

    # Read workflow state to get results
    STATE_JSON=$("$SCRIPT_DIR/skills/core/scripts/state-read.sh" ".fractary/plugins/faber/state.json" 2>/dev/null)

    if [ -n "$STATE_JSON" ]; then
        RELEASE_STATUS=$(echo "$STATE_JSON" | jq -r '.phases.release.status // "unknown"')
        PR_URL=$(echo "$STATE_JSON" | jq -r '.phases.release.data.pr_url // ""')

        # Build completion message
        COMPLETION_MESSAGE="✅ **FABER Workflow Complete**

**Work ID:** \`$WORK_ID\`
**Duration:** $(echo "$STATE_JSON" | jq -r '.duration // "N/A"')

"

        if [ "$RELEASE_STATUS" = "completed" ] && [ -n "$PR_URL" ]; then
            COMPLETION_MESSAGE+="**Pull Request:** $PR_URL

✅ Ready for review and merge.

"
        elif [ "$RELEASE_STATUS" = "pending" ]; then
            COMPLETION_MESSAGE+="⏸️ **Paused at Release Phase**

Evaluation passed. Waiting for approval.

**To proceed:**
\`\`\`
@faber approve release
\`\`\`

"
        fi

        COMPLETION_MESSAGE+="**Check status:**
\`\`\`
@faber status
\`\`\`

Workflow session: \`.faber/sessions/$WORK_ID.json\`"

        gh issue comment "$ISSUE_NUMBER" --body "$COMPLETION_MESSAGE" 2>/dev/null || echo "Warning: Failed to post completion message" >&2
    fi

    exit 0

else
    echo "❌ FABER Workflow Failed"
    echo "========================================"

    # Post failure message to issue
    FAILURE_MESSAGE="❌ **FABER Workflow Failed**

**Work ID:** \`$WORK_ID\`
**Exit Code:** $DIRECTOR_EXIT

**Troubleshooting:**

1. Check workflow logs in GitHub Actions
2. Review session file: \`.faber/sessions/$WORK_ID.json\`
3. Check for error messages in the logs

**To retry:**
\`\`\`
@faber retry
\`\`\`

**To check status:**
\`\`\`
@faber status
\`\`\`

If the problem persists, please review the [Troubleshooting Guide](plugins/faber/docs/github-integration.md#troubleshooting)."

    gh issue comment "$ISSUE_NUMBER" --body "$FAILURE_MESSAGE" 2>/dev/null || echo "Warning: Failed to post failure message" >&2

    exit $DIRECTOR_EXIT
fi
```

## Error Handling

### Configuration Missing (exit 3)
- Post comment with setup instructions
- Include code snippets for creating config
- Link to documentation

### Configuration Invalid (exit 3)
- Post comment with validation errors
- Suggest fixes and link to reference docs
- Include TOML validation tool link

### Work Item Not Found (exit 10)
- Post comment explaining the issue
- Check permissions and configuration
- Provide troubleshooting steps

### Director Failure (exit 1+)
- Post comment with error details
- Include work_id for tracking
- Offer retry and status check commands

### Permission Errors
- Post comment explaining required permissions
- Show GitHub Actions workflow requirements
- Link to setup documentation

## Intent Handling

The mention text is passed to the faber-director agent via `FABER_GITHUB_CONTEXT` environment variable. The director agent will:

1. Detect GitHub mention context
2. Parse intent from mention text
3. Route to appropriate execution path:
   - **Full workflow**: "run", "work on", "handle"
   - **Single phase**: "design", "build", "test", "release"
   - **Status query**: "status", "progress"
   - **Control command**: "approve", "retry", "cancel"

The mention command does NOT parse intent - it delegates to director.

## Integration with Director

This command follows the same invocation pattern as `run.md`:

```
@faber run this issue
  ↓
GitHub Actions triggers faber.yml
  ↓
/faber:mention command invoked
  ↓
Parse GitHub context, load config
  ↓
Generate work_id (abc12345)
  ↓
Set FABER_GITHUB_CONTEXT env var
  ↓
Invoke director: "abc12345 github 123 engineering"
  ↓
Director detects GitHub context, parses intent
  ↓
Director executes appropriate workflow
  ↓
Post results to GitHub issue
```

## What This Command Does NOT Do

- Does NOT parse intent (director handles that)
- Does NOT implement workflow logic
- Does NOT manage git/issues directly
- Does NOT retry workflows (user must mention @faber retry)

## Best Practices

1. **Always post acknowledgment** so user knows it's working
2. **Post clear errors to issues** so users see problems
3. **Include work_id in all messages** for traceability
4. **Provide actionable next steps** in completion messages
5. **Handle missing config gracefully** with setup instructions
6. **Keep messages concise** but informative

## Security Considerations

- Configuration comes ONLY from repository's `.faber.config.toml`
- No config overrides allowed in mention text
- Respects autonomy levels and safety gates
- All activity logged in issue comments
- Requires proper GitHub token permissions

This command provides a seamless GitHub-native interface to trigger FABER workflows with minimal user input.
