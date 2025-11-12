#!/bin/bash

# Generate Session Summary
# This script generates a summary of work done since the last stop event
# Part of fractary-work plugin - used by auto-comment-on-stop.sh
# Analyzes commits and changes to determine what was accomplished

set -euo pipefail

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 1
fi

# Configuration
CACHE_DIR="${HOME}/.fractary/work"
LAST_STOP_FILE="${CACHE_DIR}/last_stop_ref"
mkdir -p "${CACHE_DIR}"

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Get current HEAD
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null)

# Try to get the last stop reference
LAST_STOP_REF=""
if [ -f "$LAST_STOP_FILE" ]; then
    LAST_STOP_REF=$(cat "$LAST_STOP_FILE" 2>/dev/null | grep "^${CURRENT_BRANCH}:" | cut -d: -f2 || echo "")
fi

# Get commits since last stop
COMMITS=""
COMMIT_COUNT=0

if [ -n "$LAST_STOP_REF" ] && git rev-parse "$LAST_STOP_REF" &>/dev/null; then
    # We have a valid last stop ref - show commits since then
    COMMITS=$(git log --pretty=format:"%h|%s|%an|%ar" "$LAST_STOP_REF..HEAD" --reverse 2>/dev/null || echo "")
else
    # No last stop ref - show recent commits (last 15 minutes as fallback)
    COMMITS=$(git log --since="15 minutes ago" --pretty=format:"%h|%s|%an|%ar" --reverse 2>/dev/null || echo "")
fi

# Count commits
if [ -n "$COMMITS" ]; then
    COMMIT_COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')
fi

# Get current status
UNCOMMITTED_CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# Analyze file changes in this session
if [ "$COMMIT_COUNT" -gt 0 ]; then
    FILES_CHANGED=$(git diff --name-status HEAD~${COMMIT_COUNT}..HEAD 2>/dev/null | wc -l | tr -d ' ')
else
    FILES_CHANGED=0
fi

# Analyze commit types to understand what was done
FEAT_COUNT=0
FIX_COUNT=0
DOCS_COUNT=0
REFACTOR_COUNT=0
TEST_COUNT=0
CHORE_COUNT=0

if [ -n "$COMMITS" ]; then
    FEAT_COUNT=$(echo "$COMMITS" | grep -c "^[^|]*|feat" 2>/dev/null | tr -d ' \n' || echo "0")
    FIX_COUNT=$(echo "$COMMITS" | grep -c "^[^|]*|fix" 2>/dev/null | tr -d ' \n' || echo "0")
    DOCS_COUNT=$(echo "$COMMITS" | grep -c "^[^|]*|docs" 2>/dev/null | tr -d ' \n' || echo "0")
    REFACTOR_COUNT=$(echo "$COMMITS" | grep -c "^[^|]*|refactor" 2>/dev/null | tr -d ' \n' || echo "0")
    TEST_COUNT=$(echo "$COMMITS" | grep -c "^[^|]*|test" 2>/dev/null | tr -d ' \n' || echo "0")
    CHORE_COUNT=$(echo "$COMMITS" | grep -c "^[^|]*|chore" 2>/dev/null | tr -d ' \n' || echo "0")
fi

# Generate summary header
if [ -n "$LAST_STOP_REF" ] && git rev-parse "$LAST_STOP_REF" &>/dev/null; then
    LAST_REF_SHORT=$(git rev-parse --short "$LAST_STOP_REF")
    cat <<EOF
## 🔄 Work Update

_Changes since last update (from \`$LAST_REF_SHORT\`)_

### What Was Done

EOF
else
    cat <<EOF
## 🔄 Work Update

_Recent work on this issue_

### What Was Done

EOF
fi

# Output commit summary
if [ "$COMMIT_COUNT" -gt 0 ]; then
    echo "**$COMMIT_COUNT commit(s) made:**"
    echo ""

    # List commits with details
    echo "$COMMITS" | while IFS='|' read -r hash subject author time; do
        echo "- \`$hash\` $subject"
    done
    echo ""

    # Summarize by type
    if [ "$FEAT_COUNT" -gt 0 ]; then
        echo "- ✨ **$FEAT_COUNT** feature(s) added"
    fi
    if [ "$FIX_COUNT" -gt 0 ]; then
        echo "- 🐛 **$FIX_COUNT** bug fix(es)"
    fi
    if [ "$DOCS_COUNT" -gt 0 ]; then
        echo "- 📝 **$DOCS_COUNT** documentation update(s)"
    fi
    if [ "$REFACTOR_COUNT" -gt 0 ]; then
        echo "- ♻️  **$REFACTOR_COUNT** refactoring(s)"
    fi
    if [ "$TEST_COUNT" -gt 0 ]; then
        echo "- ✅ **$TEST_COUNT** test(s) added/updated"
    fi
    if [ "$CHORE_COUNT" -gt 0 ]; then
        echo "- 🔧 **$CHORE_COUNT** maintenance task(s)"
    fi

    if [ "$FILES_CHANGED" -gt 0 ]; then
        echo "- 📁 **$FILES_CHANGED** file(s) modified"
    fi
else
    echo "No commits made since last update."

    if [ "$UNCOMMITTED_CHANGES" -gt 0 ]; then
        echo ""
        echo "⚠️ **$UNCOMMITTED_CHANGES** uncommitted change(s) in progress."
    else
        echo ""
        echo "_No changes detected._"
    fi
fi

# Outstanding work section
cat <<EOF

### Outstanding Work

EOF

if [ "$UNCOMMITTED_CHANGES" -gt 0 ]; then
    echo "- ⚠️ **$UNCOMMITTED_CHANGES uncommitted change(s)** - work in progress"
fi

# Check if tests exist and suggest running them
if git ls-files | grep -qE "test|spec" 2>/dev/null; then
    echo "- 🧪 **Test validation** - ensure tests pass before merging"
fi

# If no specific outstanding work found
if [ "$UNCOMMITTED_CHANGES" -eq 0 ]; then
    echo "No obvious outstanding work detected."
fi

# Next steps section
cat <<EOF

### Recommended Next Steps

EOF

if [ "$UNCOMMITTED_CHANGES" -gt 0 ]; then
    echo "1. **Review and commit** uncommitted changes"
    echo "2. **Run tests** to ensure everything works"
    echo "3. **Create pull request** when ready"
elif [ "$COMMIT_COUNT" -gt 0 ]; then
    echo "1. **Run final tests** to validate changes"
    echo "2. **Create pull request** for review"
    echo "3. **Address any review feedback**"
else
    echo "1. **Continue implementation** on current branch"
    echo "2. **Commit changes** as you make progress"
fi

cat <<EOF

---
_🤖 Auto-generated work update • Branch: \`$CURRENT_BRANCH\` • $(date -u +"%Y-%m-%d %H:%M UTC")_
EOF
