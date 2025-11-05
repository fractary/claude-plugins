#!/usr/bin/env bash
#
# parse-document.sh - Parse markdown document structure
#
# Usage: parse-document.sh --file <path>
#

set -euo pipefail

# Default values
FILE_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$FILE_PATH" ]]; then
  echo "Error: Missing required argument: --file" >&2
  exit 1
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
  echo "Error: File not found: $FILE_PATH" >&2
  exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed" >&2
  exit 1
fi

# Initialize result
SECTIONS_JSON="[]"
CODE_BLOCKS_JSON="[]"
TABLES_JSON="[]"
HAS_FRONTMATTER=false
FRONTMATTER_JSON="{}"

# Check for front matter
if head -n 1 "$FILE_PATH" | grep -q "^---$"; then
  HAS_FRONTMATTER=true

  # Extract front matter (between first two --- markers)
  FM_CONTENT=$(sed -n '/^---$/,/^---$/p' "$FILE_PATH" | sed '1d;$d')

  # Convert YAML to JSON if yq is available
  if command -v yq &> /dev/null; then
    FRONTMATTER_JSON=$(echo "$FM_CONTENT" | yq eval -o json 2>/dev/null || echo "{}")
  else
    # Simple YAML to JSON conversion (basic fields only)
    FRONTMATTER_JSON="{"
    first=true
    while IFS=: read -r key value; do
      if [[ -n "$key" && -n "$value" ]]; then
        [[ "$first" == "false" ]] && FRONTMATTER_JSON+=","
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        FRONTMATTER_JSON+="\"$key\":\"$value\""
        first=false
      fi
    done <<< "$FM_CONTENT"
    FRONTMATTER_JSON+="}"
  fi
fi

# Parse sections (markdown headings)
line_num=0
current_section=""
section_level=0
section_start=0
section_content=""
in_code_block=false
code_block_start=0

while IFS= read -r line; do
  ((line_num++))

  # Skip front matter
  if [[ $line_num -le 10 ]] && [[ "$line" == "---" ]]; then
    continue
  fi

  # Track code blocks (don't parse headings inside them)
  if [[ "$line" =~ ^```  ]]; then
    if [[ "$in_code_block" == "false" ]]; then
      in_code_block=true
      code_block_start=$line_num
      # Extract language
      lang="${line#\`\`\`}"
      lang=$(echo "$lang" | xargs)
    else
      in_code_block=false
      # Record code block
      CODE_BLOCKS_JSON=$(echo "$CODE_BLOCKS_JSON" | jq --arg start "$code_block_start" --arg end "$line_num" --arg lang "$lang" '. += [{"line_start": ($start|tonumber), "line_end": ($end|tonumber), "language": $lang}]')
    fi
    continue
  fi

  # Don't process headings inside code blocks
  if [[ "$in_code_block" == "true" ]]; then
    continue
  fi

  # Detect markdown headings
  if [[ "$line" =~ ^(#{1,6})\ +(.+)$ ]]; then
    heading_marks="${BASH_REMATCH[1]}"
    heading_text="${BASH_REMATCH[2]}"
    level=${#heading_marks}

    # If we were tracking a previous section, save it
    if [[ -n "$current_section" ]]; then
      # Calculate end line (previous line)
      section_end=$((line_num - 1))

      # Add section to JSON
      SECTIONS_JSON=$(echo "$SECTIONS_JSON" | jq \
        --arg heading "$current_section" \
        --arg level "$section_level" \
        --arg start "$section_start" \
        --arg end "$section_end" \
        '. += [{"heading": $heading, "level": ($level|tonumber), "line_start": ($start|tonumber), "line_end": ($end|tonumber)}]')
    fi

    # Start tracking new section
    current_section="$heading_text"
    section_level=$level
    section_start=$line_num
  fi

  # Detect tables (lines with pipes)
  if [[ "$line" =~ ^\|.*\|$ ]]; then
    # Simple table detection - could be enhanced
    TABLES_JSON=$(echo "$TABLES_JSON" | jq --arg line "$line_num" '. += [{"line": ($line|tonumber)}]')
  fi
done < "$FILE_PATH"

# Save last section if any
if [[ -n "$current_section" ]]; then
  total_lines=$(wc -l < "$FILE_PATH")
  SECTIONS_JSON=$(echo "$SECTIONS_JSON" | jq \
    --arg heading "$current_section" \
    --arg level "$section_level" \
    --arg start "$section_start" \
    --arg end "$total_lines" \
    '. += [{"heading": $heading, "level": ($level|tonumber), "line_start": ($start|tonumber), "line_end": ($end|tonumber)}]')
fi

# Build subsection relationships
# For each section, find subsections (higher level numbers within range)
SECTIONS_WITH_SUBSECTIONS="[]"
sections_count=$(echo "$SECTIONS_JSON" | jq 'length')

for ((i=0; i<sections_count; i++)); do
  section=$(echo "$SECTIONS_JSON" | jq ".[$i]")
  section_level=$(echo "$section" | jq '.level')
  section_start=$(echo "$section" | jq '.line_start')
  section_end=$(echo "$section" | jq '.line_end')
  section_heading=$(echo "$section" | jq -r '.heading')

  # Find subsections
  subsections="[]"
  for ((j=i+1; j<sections_count; j++)); do
    sub=$(echo "$SECTIONS_JSON" | jq ".[$j]")
    sub_level=$(echo "$sub" | jq '.level')
    sub_start=$(echo "$sub" | jq '.line_start')

    # If subsection level is higher (more #) and within range
    if [[ $sub_level -gt $section_level ]] && [[ $sub_start -ge $section_start ]] && [[ $sub_start -le $section_end ]]; then
      subsections=$(echo "$subsections" | jq ". += [$(echo "$sub")]")
    fi

    # Break if we hit a same-level or lower-level section
    if [[ $sub_level -le $section_level ]] && [[ $sub_start -gt $section_start ]]; then
      break
    fi
  done

  # Add section with subsections
  SECTIONS_WITH_SUBSECTIONS=$(echo "$SECTIONS_WITH_SUBSECTIONS" | jq \
    --argjson section "$section" \
    --argjson subsections "$subsections" \
    '. += [$section + {"subsections": $subsections}]')
done

# Get file size
FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null)

# Return parsed structure
cat <<EOF
{
  "success": true,
  "file": "$FILE_PATH",
  "size_bytes": $FILE_SIZE,
  "has_frontmatter": $HAS_FRONTMATTER,
  "frontmatter": $FRONTMATTER_JSON,
  "sections": $SECTIONS_WITH_SUBSECTIONS,
  "code_blocks": $CODE_BLOCKS_JSON,
  "tables": $TABLES_JSON
}
EOF
