#!/usr/bin/env bash
set -euo pipefail

# parse-input.sh
# Parses free-text instructions to determine input source type and extract file paths
# Usage: ./parse-input.sh "<instructions>"
# Output: JSON with source_type, file_path, instructions, additional_context

INSTRUCTIONS="${1:-}"

# Input validation: max length to prevent abuse
MAX_INPUT_LENGTH=10000
if [ ${#INSTRUCTIONS} -gt $MAX_INPUT_LENGTH ]; then
    jq -n --arg error "Input too long (max $MAX_INPUT_LENGTH characters)" '{error: $error}' >&2
    exit 1
fi

# Allowed directories for security (parameterized for testability)
DESIGN_DIR="${FABER_CLOUD_DESIGN_DIR:-.fractary/plugins/faber-cloud/designs}"
SPEC_DIR="${FABER_SPEC_DIR:-.faber/specs}"

# Detect stat platform once for performance (LOW PRIORITY optimization)
STAT_FORMAT=""
if command -v stat &> /dev/null; then
    # Test GNU stat format (Linux)
    if stat --format='%Y' /dev/null 2>/dev/null | grep -q '^[0-9]'; then
        STAT_FORMAT="gnu"
    # Test BSD stat format (macOS)
    elif stat -f '%m' /dev/null 2>/dev/null | grep -q '^[0-9]'; then
        STAT_FORMAT="bsd"
    fi
fi

# Check if realpath is available (required for security)
if ! command -v realpath &> /dev/null; then
    jq -n --arg error "realpath command not found - required for path validation" '{error: $error}' >&2
    exit 1
fi

# Security: Sanitize and validate file path
# Shared function to eliminate DRY violation
sanitize_path() {
    local input_path="$1"
    local allowed_base="$2"

    # Resolve to absolute path (don't follow symlinks for security)
    local resolved
    resolved=$(realpath -m "$input_path" 2>/dev/null || echo "")

    if [ -z "$resolved" ]; then
        jq -n --arg error "Invalid path: $input_path" '{error: $error}' >&2
        return 1
    fi

    # Get absolute allowed base
    local abs_base
    abs_base=$(realpath -m "$allowed_base" 2>/dev/null || echo "")

    if [ -z "$abs_base" ]; then
        jq -n --arg error "Invalid base directory: $allowed_base" '{error: $error}' >&2
        return 1
    fi

    # Ensure abs_base ends with / to prevent edge case:
    # /home/user/designs-backup/ should NOT match base /home/user/designs
    if [[ "$abs_base" != */ ]]; then
        abs_base="$abs_base/"
    fi

    # Check if resolved path is within allowed directory
    # Allow exact match (resolved == abs_base without trailing /) or subdirectories
    if [[ "$resolved/" != "$abs_base"* ]]; then
        jq -n \
            --arg error "Path outside allowed directory" \
            --arg input_path "$input_path" \
            --arg resolved "$resolved" \
            --arg allowed_base "$abs_base" \
            '{error: $error, input_path: $input_path, resolved: $resolved, allowed_base: $allowed_base}' >&2
        return 1
    fi

    echo "$resolved"
}

# Shared path resolution function (reduces DRY violation)
resolve_and_validate_file() {
    local extracted_file="$1"
    local file_type="$2"  # "design" or "spec"
    local allowed_dir="$3"

    if [ -z "$extracted_file" ]; then
        jq -n --arg error "Could not extract $file_type file path" '{error: $error}' >&2
        return 1
    fi

    local processed_file="$extracted_file"

    # If simple filename (no directory separators), prepend allowed directory
    # Paths like ".faber/specs/file.md" or "./designs/file.md" are complete paths
    # Only prepend directory for simple filenames like "user-uploads.md"
    if [[ "$processed_file" != /* ]] && [[ "$processed_file" != ./* ]] && [[ "$processed_file" != */* ]]; then
        processed_file="$allowed_dir/$processed_file"
    fi

    # Validate path is within allowed directory
    local validated_path
    if ! validated_path=$(sanitize_path "$processed_file" "$allowed_dir"); then
        jq -n --arg error "Invalid or unsafe $file_type path: $extracted_file" '{error: $error}' >&2
        return 1
    fi

    # Check file exists
    if [ ! -f "$validated_path" ]; then
        jq -n --arg error "$file_type file not found: $validated_path" '{error: $error}' >&2
        return 1
    fi

    echo "$validated_path"
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

    # Pattern 3: Standalone .md files without spaces (no path separators)
    # Matches simple filenames: "user-uploads.md", "api-backend.md"
    # Does NOT match filenames with spaces to avoid false positives
    if echo "$text" | grep -qE '\b[a-zA-Z0-9_-]+\.md\b'; then
        echo "$text" | grep -oE '\b[a-zA-Z0-9_-]+\.md\b' | head -1
        return 0
    fi

    # Pattern 4: Natural language with keywords (allows spaces in filenames)
    # Matches: "Use design from api-backend.md", "Implement my-design (v2).md"
    if echo "$text" | grep -qiE '(from|in|using|implement)[[:space:]]+[a-zA-Z0-9_-]'; then
        # Extract filename after keyword, allowing spaces and special characters
        # Note: Removed "design" from extraction pattern to avoid matching "design from file.md"
        echo "$text" | grep -oiE '(from|in|using|implement)[[:space:]]+[a-zA-Z0-9_-][a-zA-Z0-9_ ().-]*\.md' | \
            sed -E 's/^(from|in|using|implement)[[:space:]]+//i' | head -1
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
                if ! mkdir -p "$DESIGN_DIR" 2>/dev/null; then
                    jq -n \
                        --arg error "Failed to create design directory: $DESIGN_DIR" \
                        --arg reason "Permission denied or invalid path" \
                        --arg suggestion "Check directory permissions or use an explicit design file path" \
                        '{error: $error, reason: $reason, suggestion: $suggestion}' >&2
                    exit 1
                fi
            fi

            # Cross-platform file sorting by modification time (using cached platform detection)
            local latest=""

            case "$STAT_FORMAT" in
                gnu)
                    # GNU stat format (Linux)
                    latest=$(stat --format='%Y %n' "$DESIGN_DIR"/*.md 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- || echo "")
                    ;;
                bsd)
                    # BSD stat format (macOS)
                    latest=$(stat -f '%m %N' "$DESIGN_DIR"/*.md 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- || echo "")
                    ;;
                *)
                    # Fallback: use ls (less reliable but portable)
                    latest=$(ls -t "$DESIGN_DIR"/*.md 2>/dev/null | head -1 || echo "")
                    ;;
            esac

            if [ -z "$latest" ]; then
                jq -n \
                    --arg error "No design documents found in $DESIGN_DIR" \
                    --arg suggestion "Create a design with: /fractary-faber-cloud:architect <feature description>" \
                    '{error: $error, suggestion: $suggestion}' >&2
                exit 1
            fi

            file_path="$latest"
            ;;

        faber_spec)
            # Use shared function to resolve and validate
            if ! file_path=$(resolve_and_validate_file "$extracted_file" "spec" "$SPEC_DIR"); then
                exit 1
            fi

            # Extract additional context (text after filename)
            if echo "$INSTRUCTIONS" | grep -qF "$extracted_file"; then
                additional_context=$(echo "$INSTRUCTIONS" | sed "s|.*$extracted_file||" | sed 's/^[[:space:]]*-*//' | xargs || echo "")
            fi
            ;;

        design_file)
            # Use shared function to resolve and validate
            if ! file_path=$(resolve_and_validate_file "$extracted_file" "design" "$DESIGN_DIR"); then
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
            jq -n --arg error "Unknown source type: $source_type" '{error: $error}' >&2
            exit 1
            ;;
    esac

    # Output JSON result using jq for consistency and safety
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
