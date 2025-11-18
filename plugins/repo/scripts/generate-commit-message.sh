#!/bin/bash

# Generate Commit Message
# This script generates a meaningful commit message based on staged changes
# Part of fractary-repo plugin - used by auto-commit-on-stop.sh
# Analyzes file types and change patterns to determine commit type and summary

set -euo pipefail

# Function to generate meaningful commit message based on changes
generate_commit_message() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Get change statistics
    local stats=$(git diff --cached --numstat)
    local name_status=$(git diff --cached --name-status)

    # Count changes by type (modern wc -l doesn't need tr -d)
    local added=$(echo "$name_status" | grep "^A" | wc -l)
    local modified=$(echo "$name_status" | grep "^M" | wc -l)
    local deleted=$(echo "$name_status" | grep "^D" | wc -l)
    local renamed=$(echo "$name_status" | grep "^R" | wc -l)

    # Get file extensions and paths
    local files=$(git diff --cached --name-only)
    local file_count=$(echo "$files" | wc -l)

    # Analyze file types and paths
    # Distinguish between different types of markdown files based on their location
    local has_docs=$(echo "$files" | grep -iE "^docs/.*\.(md|rst|txt|adoc)$" | grep -vE "^docs/(specs|logs)/" | wc -l)
    local has_specs=$(echo "$files" | grep -iE "(^specs/|^docs/specs/).*\.(md|rst|txt|adoc)$" | wc -l)
    local has_logs=$(echo "$files" | grep -iE "(^logs/|^docs/logs/).*\.(md|rst|txt|adoc)$" | wc -l)
    local has_plugin_structure=$(echo "$files" | grep -iE "(^plugins/.*/skills/|^plugins/.*/agents/|^plugins/.*/commands/|^skills/|^agents/|^commands/).*\.(md|rst|txt|adoc)$" | wc -l)
    local has_scripts=$(echo "$files" | grep -E "\.(sh|bash|zsh|fish)$" | wc -l)
    local has_config=$(echo "$files" | grep -E "\.(toml|yaml|yml|json|ini|conf)$" | wc -l)
    local has_source=$(echo "$files" | grep -E "\.(js|ts|py|rb|go|rs|java|c|cpp|h|hpp)$" | wc -l)

    # Determine commit type and generate summary
    local commit_type="chore"
    local summary=""

    if [ "$file_count" -eq 1 ]; then
        # Single file change
        local filename=$(basename "$files")
        local filepath="$files"

        if [ "$added" -eq 1 ]; then
            # Determine type based on path for added files
            if [[ "$filepath" =~ ^docs/specs/ ]] || [[ "$filepath" =~ ^specs/ ]]; then
                commit_type="docs"
                summary="Add spec: $filename"
            elif [[ "$filepath" =~ ^docs/logs/ ]] || [[ "$filepath" =~ ^logs/ ]]; then
                commit_type="chore"
                summary="Add log: $filename"
            elif [[ "$filepath" =~ (^plugins/.*/skills/|^plugins/.*/agents/|^plugins/.*/commands/|^skills/|^agents/|^commands/) ]]; then
                commit_type="feat"
                summary="Add plugin component: $filename"
            elif [[ "$filepath" =~ ^docs/ ]] && [[ "$filename" =~ \.(md|rst|txt|adoc)$ ]]; then
                commit_type="docs"
                summary="Add documentation: $filename"
            else
                commit_type="feat"
                summary="Add $filename"
            fi
        elif [ "$deleted" -eq 1 ]; then
            commit_type="chore"
            summary="Remove $filename"
        elif [ "$modified" -eq 1 ]; then
            # Determine type based on path for modified files
            if [[ "$filepath" =~ ^docs/specs/ ]] || [[ "$filepath" =~ ^specs/ ]]; then
                commit_type="docs"
                summary="Update spec: $filename"
            elif [[ "$filepath" =~ ^docs/logs/ ]] || [[ "$filepath" =~ ^logs/ ]]; then
                commit_type="chore"
                summary="Update log: $filename"
            elif [[ "$filepath" =~ (^plugins/.*/skills/|^plugins/.*/agents/|^plugins/.*/commands/|^skills/|^agents/|^commands/) ]] && [[ "$filename" =~ \.(md|rst|txt|adoc)$ ]]; then
                commit_type="chore"
                summary="Update plugin component: $filename"
            elif [[ "$filepath" =~ ^docs/ ]] && [[ "$filename" =~ \.(md|rst|txt|adoc)$ ]]; then
                commit_type="docs"
                summary="Update documentation: $filename"
            elif [[ "$filename" =~ \.(sh|bash)$ ]]; then
                commit_type="fix"
                summary="Update $filename"
            else
                commit_type="chore"
                summary="Update $filename"
            fi
        fi
    else
        # Multiple files changed
        # Prioritize based on file type and location
        if [ "$has_specs" -gt 0 ] && [ "$has_specs" -eq "$file_count" ]; then
            commit_type="docs"
            summary="Update specs ($file_count files)"
        elif [ "$has_logs" -gt 0 ] && [ "$has_logs" -eq "$file_count" ]; then
            commit_type="chore"
            summary="Update logs ($file_count files)"
        elif [ "$has_plugin_structure" -gt 0 ] && [ "$has_plugin_structure" -eq "$file_count" ]; then
            commit_type="chore"
            summary="Update plugin components ($file_count files)"
        elif [ "$has_docs" -gt 0 ] && [ "$has_source" -eq 0 ] && [ "$has_scripts" -eq 0 ] && [ "$has_plugin_structure" -eq 0 ]; then
            commit_type="docs"
            summary="Update documentation ($file_count files)"
        elif [ "$has_scripts" -gt "$has_source" ]; then
            commit_type="chore"
            summary="Update scripts ($file_count files)"
        elif [ "$has_config" -eq "$file_count" ]; then
            commit_type="chore"
            summary="Update configuration ($file_count files)"
        elif [ "$added" -gt 0 ] && [ "$modified" -eq 0 ] && [ "$deleted" -eq 0 ]; then
            commit_type="feat"
            summary="Add $file_count files"
        elif [ "$deleted" -gt 0 ] && [ "$added" -eq 0 ] && [ "$modified" -eq 0 ]; then
            commit_type="chore"
            summary="Remove $file_count files"
        else
            # Mixed changes - try to identify the main pattern
            local dir_pattern=$(echo "$files" | head -1 | cut -d'/' -f1-2)
            local common_prefix=$(echo "$files" | sed -e 'N;s/^\(.*\).*\n\1.*$/\1\n\1/;D')

            if [ -n "$common_prefix" ] && [ "$common_prefix" != "/" ]; then
                summary="Update $common_prefix ($file_count files)"
            else
                summary="Update $file_count files"
            fi

            # Set type based on what changed most
            if [ "$has_specs" -gt 0 ]; then
                commit_type="docs"
            elif [ "$has_docs" -gt 0 ] && [ "$has_plugin_structure" -eq 0 ]; then
                commit_type="docs"
            elif [ "$has_plugin_structure" -gt 0 ]; then
                commit_type="chore"
            elif [ "$modified" -gt "$added" ]; then
                commit_type="chore"
            else
                commit_type="feat"
            fi
        fi
    fi

    # Build commit message with conventional commit format
    cat <<EOF
$commit_type: $summary

Auto-committed on Claude Code session end at $timestamp
EOF
}

# Execute the function and output the result
generate_commit_message
