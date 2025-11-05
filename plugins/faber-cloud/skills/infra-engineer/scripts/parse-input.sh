#!/usr/bin/env bash
set -euo pipefail

# parse-input.sh
# Parses free-text instructions to determine input source type and extract file paths
# Usage: ./parse-input.sh "<instructions>"
# Output: JSON with source_type, file_path, instructions, additional_context

INSTRUCTIONS="${1:-}"

# Allowed directories for security
DESIGN_DIR=".fractary/plugins/faber-cloud/designs"
SPEC_DIR=".faber/specs"

# Security: Sanitize and validate file path
sanitize_path() {
    local input_path="$1"
    local allowed_base="$2"

    # Resolve to absolute path (don't follow symlinks for security)
    local resolved
    resolved=$(realpath -m "$input_path" 2>/dev/null || echo "")

    if [ -z "$resolved" ]; then
        echo "ERROR: Invalid path: $input_path" >&2
        return 1
    fi

    # Get absolute allowed base
    local abs_base
    abs_base=$(realpath -m "$allowed_base" 2>/dev/null || echo "")

    if [ -z "$abs_base" ]; then
        echo "ERROR: Invalid base directory: $allowed_base" >&2
        return 1
    fi

    # Check if resolved path is within allowed directory
    if [[ "$resolved" != "$abs_base"* ]]; then
        echo "ERROR: Path outside allowed directory: $input_path" >&2
        echo "ERROR: Resolved to: $resolved" >&2
        echo "ERROR: Allowed base: $abs_base" >&2
        return 1
    fi

    echo "$resolved"
}

# Extract filename from natural language
# Example: "Implement design from api-backend.md" -> "api-backend.md"
extract_filename() {
    local text="$1"

    # Priority order for extraction:
    # 1. .faber/specs/ paths (most specific)
    # 2. .fractary/plugins/faber-cloud/designs/ paths
    # 3. Standalone .md files
    # 4. References with "from", "in", "using" keywords

    # Pattern 1: .faber/specs/ paths
    if echo "$text" | grep -qE '\.faber/specs/[^[:space:]]+\.md'; then
        echo "$text" | grep -oE '\.faber/specs/[^[:space:]]+\.md' | head -1
        return 0
    fi

    # Pattern 2: .fractary/plugins/faber-cloud/designs/ paths
    if echo "$text" | grep -qE '\.fractary/plugins/faber-cloud/designs/[^[:space:]]+\.md'; then
        echo "$text" | grep -oE '\.fractary/plugins/faber-cloud/designs/[^[:space:]]+\.md' | head -1
        return 0
    fi

    # Pattern 3: Standalone .md files (no path separators)
    if echo "$text" | grep -qE '[a-zA-Z0-9_-]+\.md'; then
        # Extract first .md filename that doesn't have path separators before it
        echo "$text" | grep -oE '[^/[:space:]]+\.md' | head -1
        return 0
    fi

    # Pattern 4: Natural language with keywords
    if echo "$text" | grep -qiE '(from|in|using|implement|design)[[:space:]]+[^[:space:]]+\.md'; then
        echo "$text" | grep -oiE '(from|in|using|implement|design)[[:space:]]+[^[:space:]]+\.md' | \
            sed -E 's/(from|in|using|implement|design)[[:space:]]+//i' | head -1
        return 0
    fi

    return 1
}

# Determine source type and extract relevant information
determine_source() {
    local text="$1"

    # Empty input -> latest design
    if [ -z "$text" ]; then
        echo "latest_design"
        return 0
    fi

    # Try to extract filename
    local filename
    filename=$(extract_filename "$text" || echo "")

    if [ -n "$filename" ]; then
        # Determine if it's a FABER spec or design doc
        if echo "$filename" | grep -qE '^\.faber/specs/'; then
            echo "faber_spec:$filename"
            return 0
        elif echo "$filename" | grep -qE '^\.fractary/plugins/faber-cloud/designs/'; then
            echo "design_file:$filename"
            return 0
        elif echo "$filename" | grep -qE '^[^/]+\.md$'; then
            # Relative filename -> design file
            echo "design_file:$filename"
            return 0
        else
            # Full path - determine by directory
            if echo "$filename" | grep -q '\.faber/specs/'; then
                echo "faber_spec:$filename"
                return 0
            else
                echo "design_file:$filename"
                return 0
            fi
        fi
    fi

    # No filename found -> direct instructions
    echo "direct_instructions:"
    return 0
}

# Main logic
main() {
    local source_info
    source_info=$(determine_source "$INSTRUCTIONS")

    local source_type="${source_info%%:*}"
    local extracted_file="${source_info#*:}"

    local file_path=""
    local additional_context=""

    case "$source_type" in
        latest_design)
            # Find most recent design
            if [ ! -d "$DESIGN_DIR" ]; then
                mkdir -p "$DESIGN_DIR" 2>/dev/null || true
            fi

            local latest
            latest=$(ls -t "$DESIGN_DIR"/*.md 2>/dev/null | head -1 || echo "")

            if [ -z "$latest" ]; then
                echo "{\"error\": \"No design documents found in $DESIGN_DIR\"}" >&2
                exit 1
            fi

            file_path="$latest"
            ;;

        faber_spec)
            # Resolve and validate FABER spec path
            if [ -z "$extracted_file" ]; then
                echo "{\"error\": \"Could not extract spec file path\"}" >&2
                exit 1
            fi

            # Validate path is within .faber/specs/
            if ! file_path=$(sanitize_path "$extracted_file" "$SPEC_DIR"); then
                echo "{\"error\": \"Invalid or unsafe spec path: $extracted_file\"}" >&2
                exit 1
            fi

            # Check file exists
            if [ ! -f "$file_path" ]; then
                echo "{\"error\": \"Spec file not found: $file_path\"}" >&2
                exit 1
            fi

            # Extract additional context (text after filename)
            if echo "$INSTRUCTIONS" | grep -qF "$extracted_file"; then
                additional_context=$(echo "$INSTRUCTIONS" | sed "s|.*$extracted_file||" | sed 's/^[[:space:]]*-*//' | xargs || echo "")
            fi
            ;;

        design_file)
            # Resolve design file path
            if [ -z "$extracted_file" ]; then
                echo "{\"error\": \"Could not extract design file path\"}" >&2
                exit 1
            fi

            # If relative filename, prepend design directory
            if [[ "$extracted_file" != /* ]] && [[ "$extracted_file" != .* ]]; then
                extracted_file="$DESIGN_DIR/$extracted_file"
            fi

            # Validate path is within designs directory
            if ! file_path=$(sanitize_path "$extracted_file" "$DESIGN_DIR"); then
                echo "{\"error\": \"Invalid or unsafe design path: $extracted_file\"}" >&2
                exit 1
            fi

            # Check file exists
            if [ ! -f "$file_path" ]; then
                echo "{\"error\": \"Design file not found: $file_path\"}" >&2
                exit 1
            fi

            # Extract additional context
            if echo "$INSTRUCTIONS" | grep -qF "$(basename "$extracted_file")"; then
                additional_context=$(echo "$INSTRUCTIONS" | sed "s|.*$(basename "$extracted_file")||" | sed 's/^[[:space:]]*-*//' | xargs || echo "")
            fi
            ;;

        direct_instructions)
            # No file reference - treat entire input as instructions
            file_path=""
            ;;

        *)
            echo "{\"error\": \"Unknown source type: $source_type\"}" >&2
            exit 1
            ;;
    esac

    # Output JSON result
    jq -n \
        --arg source_type "$source_type" \
        --arg file_path "$file_path" \
        --arg instructions "$INSTRUCTIONS" \
        --arg additional_context "$additional_context" \
        '{
            source_type: $source_type,
            file_path: $file_path,
            instructions: $instructions,
            additional_context: $additional_context
        }'
}

main
