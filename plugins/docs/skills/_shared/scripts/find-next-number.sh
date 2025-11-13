#!/usr/bin/env bash
# Find Next Number - Find the next available number for numbered documents (e.g., ADRs)
# Usage: find-next-number.sh <directory> <prefix> <format>
# Example: find-next-number.sh docs/architecture/adrs "ADR-" "%03d"
# Returns: Next number (e.g., 005)

set -euo pipefail

find_next_number() {
    local directory="$1"
    local prefix="$2"
    local format="${3:-%03d}"

    # Create directory if it doesn't exist
    mkdir -p "$directory"

    # Find all files matching the prefix pattern
    # Extract numbers, find max, increment
    local max_number=0

    if [[ -d "$directory" ]]; then
        while IFS= read -r file; do
            # Extract filename without path
            local filename=$(basename "$file")

            # Extract number after prefix
            # Pattern: PREFIX-NUMBER-rest.md
            if [[ "$filename" =~ ^${prefix}([0-9]+)- ]]; then
                local num="${BASH_REMATCH[1]}"
                # Remove leading zeros for arithmetic
                num=$((10#$num))
                if [[ $num -gt $max_number ]]; then
                    max_number=$num
                fi
            fi
        done < <(find "$directory" -maxdepth 1 -type f -name "${prefix}*.md" 2>/dev/null)
    fi

    # Increment and format
    local next_number=$((max_number + 1))
    printf "$format" "$next_number"
}

# Main execution
main() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <directory> <prefix> [format]" >&2
        echo "Example: $0 docs/architecture/adrs 'ADR-' '%03d'" >&2
        return 1
    fi

    find_next_number "$@"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
