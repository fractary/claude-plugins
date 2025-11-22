#!/usr/bin/env bash
# Slugify - Convert text to URL-friendly slug
# Usage: slugify.sh <text> [max_length]
# Example: slugify.sh "Use PostgreSQL for Data Store" 50
# Returns: use-postgresql-for-data-store

set -euo pipefail

slugify() {
    local text="$1"
    local max_length="${2:-50}"

    # Convert to lowercase
    # Replace spaces and underscores with hyphens
    # Remove non-alphanumeric except hyphens
    # Remove leading/trailing hyphens
    # Collapse multiple hyphens
    # Truncate to max length
    echo "$text" \
        | tr '[:upper:]' '[:lower:]' \
        | tr ' _' '--' \
        | tr -cd '[:alnum:]-' \
        | sed 's/^-*//' \
        | sed 's/-*$//' \
        | sed 's/-\+/-/g' \
        | cut -c1-"${max_length}"
}

# Main execution
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <text> [max_length]" >&2
        echo "Example: $0 'Use PostgreSQL for Data Store' 50" >&2
        return 1
    fi

    slugify "$@"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
