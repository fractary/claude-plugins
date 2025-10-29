#!/bin/bash
# Work Common: JQL Query Builder
# Builds Jira Query Language (JQL) queries from filter parameters

set -euo pipefail

# Usage: ./jql-builder.sh <state> <labels> <assignee> [project_key]
# Outputs JQL query string to stdout

# Parameters
STATE="${1:-all}"
LABELS="${2:-}"
ASSIGNEE="${3:-}"
PROJECT_KEY="${4:-${JIRA_PROJECT_KEY:-}}"

# Validate project key
if [ -z "$PROJECT_KEY" ]; then
    echo "Error: Project key required (set JIRA_PROJECT_KEY or pass as argument)" >&2
    exit 2
fi

# Build JQL query parts
QUERY_PARTS=()

# Project filter (always present)
QUERY_PARTS+=("project = $PROJECT_KEY")

# State filter
case "$STATE" in
    all)
        # No state filter
        ;;
    open)
        # Map to common open states
        QUERY_PARTS+=("status in (\"To Do\", \"Open\", \"Backlog\")")
        ;;
    in_progress)
        QUERY_PARTS+=("status in (\"In Progress\", \"In Development\")")
        ;;
    in_review)
        QUERY_PARTS+=("status in (\"In Review\", \"Code Review\")")
        ;;
    done)
        QUERY_PARTS+=("status in (\"Done\", \"Resolved\")")
        ;;
    closed)
        QUERY_PARTS+=("status in (\"Closed\", \"Cancelled\")")
        ;;
    *)
        # Treat as literal status name
        QUERY_PARTS+=("status = \"$STATE\"")
        ;;
esac

# Labels filter
if [ -n "$LABELS" ]; then
    # Split comma-separated labels
    IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"

    # Build labels IN clause
    LABEL_LIST=""
    for label in "${LABEL_ARRAY[@]}"; do
        # Trim whitespace
        label=$(echo "$label" | xargs)
        if [ -n "$LABEL_LIST" ]; then
            LABEL_LIST="$LABEL_LIST, "
        fi
        LABEL_LIST="$LABEL_LIST$label"
    done

    QUERY_PARTS+=("labels in ($LABEL_LIST)")
fi

# Assignee filter
if [ -n "$ASSIGNEE" ]; then
    if [ "$ASSIGNEE" = "none" ] || [ "$ASSIGNEE" = "unassigned" ]; then
        QUERY_PARTS+=("assignee is EMPTY")
    elif [ "$ASSIGNEE" = "currentUser()" ] || [ "$ASSIGNEE" = "me" ]; then
        QUERY_PARTS+=("assignee = currentUser()")
    else
        # Assume it's an email or username
        QUERY_PARTS+=("assignee = \"$ASSIGNEE\"")
    fi
fi

# Join query parts with AND
FINAL_QUERY=""
for ((i=0; i<${#QUERY_PARTS[@]}; i++)); do
    if [ $i -gt 0 ]; then
        FINAL_QUERY="$FINAL_QUERY AND "
    fi
    FINAL_QUERY="$FINAL_QUERY${QUERY_PARTS[$i]}"
done

# Add default ORDER BY
FINAL_QUERY="$FINAL_QUERY ORDER BY created DESC"

# Output query
echo "$FINAL_QUERY"

exit 0
