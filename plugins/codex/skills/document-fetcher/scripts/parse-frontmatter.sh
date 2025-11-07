#!/usr/bin/env bash
# Parse YAML frontmatter from markdown document
#
# Usage: ./parse-frontmatter.sh <file_path_or_stdin>
# Output: JSON object with frontmatter fields

set -euo pipefail

input_file="${1:--}"

# Read content
if [[ "$input_file" == "-" ]]; then
  content=$(cat)
else
  content=$(cat "$input_file")
fi

# Check if content starts with frontmatter delimiter (---)
if ! echo "$content" | head -1 | grep -q "^---$"; then
  echo '{}'
  exit 0
fi

# Extract frontmatter (between first two --- delimiters)
frontmatter=$(echo "$content" | awk '
  BEGIN { in_fm = 0; fm_count = 0 }
  /^---$/ {
    fm_count++
    if (fm_count == 1) {
      in_fm = 1
      next
    }
    if (fm_count == 2) {
      in_fm = 0
      exit
    }
  }
  in_fm { print }
')

# If no frontmatter found
if [[ -z "$frontmatter" ]]; then
  echo '{}'
  exit 0
fi

# Convert YAML to JSON using python (if available) or fallback to simple parsing
if command -v python3 >/dev/null 2>&1; then
  # Use Python's yaml library
  python3 <<EOF
import yaml, json, sys
try:
    frontmatter = '''$frontmatter'''
    data = yaml.safe_load(frontmatter)
    if data is None:
        data = {}
    print(json.dumps(data))
except Exception as e:
    print('{}')
    sys.exit(0)
EOF
elif command -v yq >/dev/null 2>&1; then
  # Use yq if available
  echo "$frontmatter" | yq eval -o=json - 2>/dev/null || echo '{}'
else
  # Fallback: Simple key-value parsing for common cases
  # This is a simplified parser for basic YAML structures
  echo "$frontmatter" | awk '
    BEGIN {
      print "{"
      first = 1
    }
    /^[a-zA-Z_][a-zA-Z0-9_]*:/ {
      if (!first) print ","
      first = 0

      match($0, /^([a-zA-Z_][a-zA-Z0-9_]*):(.*)/, arr)
      key = arr[1]
      value = arr[2]

      # Trim whitespace
      gsub(/^[ \t]+|[ \t]+$/, "", value)

      # Handle arrays (simple case: "- item" format)
      if (value == "") {
        # Next lines might be array items
        printf "  \"%s\": [", key
        getline
        array_first = 1
        while ($0 ~ /^[ \t]+-/) {
          if (!array_first) printf ","
          array_first = 0
          match($0, /-[ \t]+(.*)/, item_arr)
          item = item_arr[1]
          gsub(/^[ \t]+|[ \t]+$/, "", item)
          printf "\"%s\"", item
          getline
        }
        print "]"
      } else {
        # Simple value
        printf "  \"%s\": \"%s\"\n", key, value
      }
    }
    END {
      print "}"
    }
  '
fi
