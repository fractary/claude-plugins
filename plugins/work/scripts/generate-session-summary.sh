#!/bin/bash

# Generate Session Summary
# This script generates a summary of work done since the last stop event
# Part of fractary-work plugin - used by auto-comment-on-stop.sh
# Analyzes commits and changes to determine what was accomplished
# Enhanced to provide context-aware summaries based on actual work done

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

# ============================================================================
# Helper Functions for Context Analysis
# ============================================================================

# Extract issue ID from branch name
get_issue_id_from_branch() {
    local branch="$1"
    if [[ "$branch" =~ ^(feat|fix|chore|hotfix|patch|refactor)/([0-9]+)- ]]; then
        echo "${BASH_REMATCH[2]}"
    elif [[ "$branch" =~ ^[a-z]+/([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Fetch issue content from GitHub
fetch_issue_content() {
    local issue_id="$1"
    if ! command -v gh &> /dev/null; then
        echo ""
        return
    fi
    gh issue view "$issue_id" --json title,body 2>/dev/null || echo ""
}

# Find spec file for this issue
find_spec_file() {
    local issue_id="$1"
    # Common spec file patterns
    local patterns=(
        "docs/specs/*${issue_id}*.md"
        "specs/*${issue_id}*.md"
        ".fractary/specs/*${issue_id}*.md"
        "SPEC-*${issue_id}*.md"
    )

    for pattern in "${patterns[@]}"; do
        local files=$(find . -path "*/${pattern}" 2>/dev/null | head -1)
        if [ -n "$files" ]; then
            echo "$files"
            return
        fi
    done
    echo ""
}

# Analyze code changes to understand what was actually done
analyze_code_changes() {
    local last_ref="$1"
    local current_ref="$2"

    if [ -z "$last_ref" ] || ! git rev-parse "$last_ref" &>/dev/null; then
        # Fallback to recent changes
        git diff HEAD~1..HEAD 2>/dev/null || echo ""
    else
        git diff "$last_ref..$current_ref" 2>/dev/null || echo ""
    fi
}

# Determine workflow state based on changes and files
determine_workflow_state() {
    local commits="$1"
    local spec_file="$2"
    local uncommitted="$3"

    # Check if spec was just created
    if [ -n "$spec_file" ] && echo "$commits" | grep -q "spec:.*${spec_file##*/}"; then
        echo "spec-created"
        return
    fi

    # Check if spec exists
    if [ -n "$spec_file" ] && [ -f "$spec_file" ]; then
        echo "implementing"
        return
    fi

    # Check if implementation looks complete (has tests, no TODOs in recent changes)
    if echo "$commits" | grep -qE "(test|spec)"; then
        if [ "$uncommitted" -eq 0 ]; then
            echo "testing"
            return
        fi
    fi

    # Default state
    if [ "$uncommitted" -gt 0 ]; then
        echo "in-progress"
    else
        echo "ready-for-review"
    fi
}

# Generate specific next steps based on context
generate_context_aware_next_steps() {
    local state="$1"
    local issue_id="$2"
    local spec_file="$3"
    local uncommitted="$4"
    local has_tests="$5"

    case "$state" in
        spec-created)
            cat <<EOF
1. **Review the spec** - Ensure it captures all requirements
2. **Begin implementation** - Start coding according to the spec
3. **Add tests** - Write tests as you implement features
EOF
            ;;
        implementing)
            if [ "$uncommitted" -gt 0 ]; then
                cat <<EOF
1. **Complete current changes** - Finish and commit work in progress
2. **Follow the spec** - Ensure implementation matches specification in: \`${spec_file##*/}\`
3. **Add tests** - Verify each feature as you implement
EOF
            else
                cat <<EOF
1. **Continue implementation** - Follow the specification in: \`${spec_file##*/}\`
2. **Add tests** - Ensure features are properly tested
3. **Review progress** - Check if all spec requirements are met
EOF
            fi
            ;;
        testing)
            cat <<EOF
1. **Run test suite** - Verify all tests pass
2. **Manual testing** - Test edge cases and user flows
3. **Create pull request** - Ready for code review
EOF
            ;;
        ready-for-review)
            if [ "$has_tests" = "yes" ]; then
                cat <<EOF
1. **Final validation** - Run full test suite
2. **Create pull request** - Submit for team review
3. **Address feedback** - Respond to review comments
EOF
            else
                cat <<EOF
1. **Add tests** - Implementation needs test coverage
2. **Run validation** - Ensure everything works
3. **Create pull request** - Submit for review after tests
EOF
            fi
            ;;
        in-progress)
            cat <<EOF
1. **Commit current work** - Save progress with clear commit message
2. **Continue implementation** - Keep working toward issue goals
3. **Add tests** - Ensure code quality as you go
EOF
            ;;
        *)
            cat <<EOF
1. **Review issue requirements** - Understand what needs to be done
2. **Plan implementation** - Consider creating a spec if complex
3. **Begin coding** - Start with tests for TDD approach
EOF
            ;;
    esac
}

# Analyze what was actually accomplished (beyond commit messages)
analyze_accomplishments() {
    local diff_content="$1"
    local commits="$2"

    local accomplishments=()

    # Check for new files created
    local new_files=$(echo "$diff_content" | grep "^diff --git" | grep "/dev/null b/" | wc -l)
    if [ "$new_files" -gt 0 ]; then
        accomplishments+=("Created $new_files new file(s)")
    fi

    # Check for spec creation
    if echo "$commits" | grep -qE "spec:|Add spec"; then
        accomplishments+=("Created technical specification")
    fi

    # Check for test additions
    local test_additions=$(echo "$diff_content" | grep -E "^\+.*test|^\+.*describe|^\+.*it\(" | wc -l)
    if [ "$test_additions" -gt 5 ]; then
        accomplishments+=("Added test coverage ($test_additions new test assertions)")
    fi

    # Check for function/class additions
    local new_functions=$(echo "$diff_content" | grep -E "^\+.*(function |def |class |const .* = |export )" | wc -l)
    if [ "$new_functions" -gt 0 ]; then
        accomplishments+=("Implemented $new_functions new function(s)/class(es)")
    fi

    # Check for documentation
    if echo "$diff_content" | grep -qE "^\+.*\/\/|^\+.*\/\*|^\+.*#"; then
        local doc_lines=$(echo "$diff_content" | grep -E "^\+.*\/\/|^\+.*\/\*|^\+.*#" | wc -l)
        if [ "$doc_lines" -gt 10 ]; then
            accomplishments+=("Added inline documentation")
        fi
    fi

    # Check for bug fixes (removed TODO, FIXME, etc.)
    local fixed_todos=$(echo "$diff_content" | grep -E "^-.*TODO|^-.*FIXME|^-.*XXX" | wc -l)
    if [ "$fixed_todos" -gt 0 ]; then
        accomplishments+=("Resolved $fixed_todos TODO/FIXME item(s)")
    fi

    # Output accomplishments
    if [ ${#accomplishments[@]} -gt 0 ]; then
        printf '%s\n' "${accomplishments[@]}"
    fi
}

# ============================================================================
# End Helper Functions
# ============================================================================

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

# ============================================================================
# Enhanced Context Analysis
# ============================================================================

# Get issue ID
ISSUE_ID=$(get_issue_id_from_branch "$CURRENT_BRANCH")

# Find spec file
SPEC_FILE=""
if [ -n "$ISSUE_ID" ]; then
    SPEC_FILE=$(find_spec_file "$ISSUE_ID")
fi

# Analyze code changes
CODE_DIFF=""
if [ "$COMMIT_COUNT" -gt 0 ]; then
    CODE_DIFF=$(analyze_code_changes "$LAST_STOP_REF" "$CURRENT_HEAD")
fi

# Determine workflow state
WORKFLOW_STATE=$(determine_workflow_state "$COMMITS" "$SPEC_FILE" "$UNCOMMITTED_CHANGES")

# Check if tests exist
HAS_TESTS="no"
if git ls-files | grep -qE "test|spec" 2>/dev/null; then
    HAS_TESTS="yes"
fi

# Analyze accomplishments
ACCOMPLISHMENTS=""
if [ -n "$CODE_DIFF" ]; then
    ACCOMPLISHMENTS=$(analyze_accomplishments "$CODE_DIFF" "$COMMITS")
fi

# ============================================================================
# End Enhanced Context Analysis
# ============================================================================

# Generate summary header
if [ -n "$LAST_STOP_REF" ] && git rev-parse "$LAST_STOP_REF" &>/dev/null; then
    LAST_REF_SHORT=$(git rev-parse --short "$LAST_STOP_REF")
    cat <<EOF
## 🔄 Work Update

_Changes since last update (from \`$LAST_REF_SHORT\`)_

EOF
    # Add workflow state indicator
    case "$WORKFLOW_STATE" in
        spec-created)
            echo "**Current State:** 📋 Specification Created"
            ;;
        implementing)
            echo "**Current State:** 🔨 Implementation In Progress"
            if [ -n "$SPEC_FILE" ]; then
                echo "_Following spec:_ \`${SPEC_FILE##*/}\`"
            fi
            ;;
        testing)
            echo "**Current State:** 🧪 Testing Phase"
            ;;
        ready-for-review)
            echo "**Current State:** ✅ Ready for Review"
            ;;
        in-progress)
            echo "**Current State:** 🚧 Work In Progress"
            ;;
    esac
    echo ""
    echo "### What Was Done"
    echo ""
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

    # Show accomplishments from code analysis
    if [ -n "$ACCOMPLISHMENTS" ]; then
        echo "**Key Accomplishments:**"
        echo ""
        echo "$ACCOMPLISHMENTS" | while IFS= read -r line; do
            echo "- $line"
        done
        echo ""
    fi

    # Show key files changed
    if [ -n "$CODE_DIFF" ]; then
        KEY_FILES=$(echo "$CODE_DIFF" | grep "^diff --git" | sed 's/^diff --git a\///' | sed 's/ b\/.*//' | head -10)
        if [ -n "$KEY_FILES" ]; then
            FILE_COUNT_DISPLAY=$(echo "$KEY_FILES" | wc -l | tr -d ' ')
            if [ "$FILE_COUNT_DISPLAY" -le 5 ]; then
                echo "**Files Changed:**"
                echo ""
                echo "$KEY_FILES" | while IFS= read -r file; do
                    echo "- \`$file\`"
                done
                echo ""
            elif [ "$FILE_COUNT_DISPLAY" -le 10 ]; then
                echo "**Files Changed:** \`$FILE_COUNT_DISPLAY\` files (showing first 5)"
                echo ""
                echo "$KEY_FILES" | head -5 | while IFS= read -r file; do
                    echo "- \`$file\`"
                done
                echo ""
            fi
        fi
    fi

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

# Next steps section - use context-aware next steps
cat <<EOF

### Recommended Next Steps

EOF

# Use the enhanced context-aware next steps
generate_context_aware_next_steps "$WORKFLOW_STATE" "$ISSUE_ID" "$SPEC_FILE" "$UNCOMMITTED_CHANGES" "$HAS_TESTS"

cat <<EOF

---
_🤖 Auto-generated work update • Branch: \`$CURRENT_BRANCH\` • $(date -u +"%Y-%m-%d %H:%M UTC")_
EOF
