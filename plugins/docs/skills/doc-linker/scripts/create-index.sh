#!/usr/bin/env bash
#
# create-index.sh - Generate documentation index
#
# Usage: create-index.sh --directory <path> --output <file> [--title <title>] [--group-by <strategy>]
#

set -euo pipefail

# Default values
DIRECTORY=""
OUTPUT_FILE=""
TITLE="Documentation Index"
GROUP_BY="type"  # type, tag, date, flat

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --directory)
      DIRECTORY="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --title)
      TITLE="$2"
      shift 2
      ;;
    --group-by)
      GROUP_BY="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$DIRECTORY" ]]; then
  echo "Error: Missing required argument: --directory" >&2
  exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
  echo "Error: Missing required argument: --output" >&2
  exit 1
fi

# Check if directory exists
if [[ ! -d "$DIRECTORY" ]]; then
  cat <<EOF
{
  "success": false,
  "error": "Directory not found: $DIRECTORY",
  "error_code": "DIR_NOT_FOUND"
}
EOF
  exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
  cat <<EOF
{
  "success": false,
  "error": "jq is required but not installed",
  "error_code": "MISSING_DEPENDENCY"
}
EOF
  exit 1
fi

# Find all markdown files
DOCS_JSON="[]"
TOTAL_DOCS=0

# Get absolute path of directory for relative path calculation
ABS_DIR="$(cd "$DIRECTORY" && pwd)"
OUTPUT_DIR="$(cd "$(dirname "$OUTPUT_FILE")" 2>/dev/null && pwd || echo "$(dirname "$OUTPUT_FILE")")"

while IFS= read -r file; do
  # Skip the output file itself
  [[ "$file" == "$OUTPUT_FILE" ]] && continue

  # Parse front matter
  if head -n 1 "$file" | grep -q "^---$"; then
    # Extract front matter
    FM_CONTENT=$(sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d')

    # Parse YAML to JSON
    if command -v yq &> /dev/null; then
      FM_JSON=$(echo "$FM_CONTENT" | yq eval -o json 2>/dev/null || echo "{}")
    else
      # Basic YAML parsing
      FM_JSON="{"
      first=true
      while IFS=: read -r key value; do
        if [[ -n "$key" && -n "$value" ]]; then
          [[ "$first" == "false" ]] && FM_JSON+=","
          key=$(echo "$key" | xargs)
          value=$(echo "$value" | xargs)
          # Remove quotes if present
          value="${value#\"}"
          value="${value%\"}"
          FM_JSON+="\"$key\":\"$value\""
          first=false
        fi
      done <<< "$FM_CONTENT"
      FM_JSON+="}"
    fi

    # Extract fields
    TITLE_VAL=$(echo "$FM_JSON" | jq -r '.title // ""')
    TYPE_VAL=$(echo "$FM_JSON" | jq -r '.type // "other"')
    DATE_VAL=$(echo "$FM_JSON" | jq -r '.date // ""')
    STATUS_VAL=$(echo "$FM_JSON" | jq -r '.status // ""')
    TAGS_VAL=$(echo "$FM_JSON" | jq -r '.tags // [] | if type == "array" then . else [.] end | join(", ")')

    # Use filename if no title
    if [[ -z "$TITLE_VAL" ]]; then
      TITLE_VAL=$(basename "$file" .md)
    fi

    # Calculate relative path from output file to this file
    REL_PATH=$(realpath --relative-to="$OUTPUT_DIR" "$file" 2>/dev/null || echo "$file")

    # Add to docs array
    DOCS_JSON=$(echo "$DOCS_JSON" | jq \
      --arg path "$REL_PATH" \
      --arg title "$TITLE_VAL" \
      --arg type "$TYPE_VAL" \
      --arg date "$DATE_VAL" \
      --arg status "$STATUS_VAL" \
      --arg tags "$TAGS_VAL" \
      '. += [{
        "path": $path,
        "title": $title,
        "type": $type,
        "date": $date,
        "status": $status,
        "tags": $tags
      }]')

    ((TOTAL_DOCS++))
  fi
done < <(find "$DIRECTORY" -type f -name "*.md" | sort)

# Generate index content based on grouping strategy
INDEX_CONTENT="# $TITLE\n\n"
INDEX_CONTENT+="Generated: $(date +%Y-%m-%d)\n\n"
INDEX_CONTENT+="Total Documents: $TOTAL_DOCS\n\n"

case "$GROUP_BY" in
  type)
    # Group by document type
    INDEX_CONTENT+="## Documents by Type\n\n"

    # Get unique types, sorted
    TYPES=$(echo "$DOCS_JSON" | jq -r '.[].type' | sort -u)

    # Type display names
    declare -A TYPE_NAMES=(
      ["adr"]="Architecture Decision Records (ADRs)"
      ["design"]="Design Documents"
      ["runbook"]="Runbooks"
      ["api-spec"]="API Specifications"
      ["test-report"]="Test Reports"
      ["deployment"]="Deployment Records"
      ["changelog"]="Changelogs"
      ["architecture"]="Architecture Documents"
      ["troubleshooting"]="Troubleshooting Guides"
      ["postmortem"]="Postmortems"
      ["other"]="Other Documents"
    )

    for type in $TYPES; do
      type_name="${TYPE_NAMES[$type]:-$type}"
      INDEX_CONTENT+="### $type_name\n\n"

      # Get docs of this type
      while IFS= read -r doc; do
        title=$(echo "$doc" | jq -r '.title')
        path=$(echo "$doc" | jq -r '.path')
        status=$(echo "$doc" | jq -r '.status')

        if [[ -n "$status" ]]; then
          INDEX_CONTENT+="- [$title]($path) - *$status*\n"
        else
          INDEX_CONTENT+="- [$title]($path)\n"
        fi
      done < <(echo "$DOCS_JSON" | jq -c ".[] | select(.type == \"$type\")")

      INDEX_CONTENT+="\n"
    done
    ;;

  tag)
    # Group by tags
    INDEX_CONTENT+="## Documents by Tag\n\n"

    # Get all unique tags
    ALL_TAGS=$(echo "$DOCS_JSON" | jq -r '.[].tags' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sort -u | grep -v '^$')

    if [[ -n "$ALL_TAGS" ]]; then
      while IFS= read -r tag; do
        [[ -z "$tag" ]] && continue

        INDEX_CONTENT+="### $tag\n\n"

        # Get docs with this tag
        while IFS= read -r doc; do
          title=$(echo "$doc" | jq -r '.title')
          path=$(echo "$doc" | jq -r '.path')
          type=$(echo "$doc" | jq -r '.type')

          INDEX_CONTENT+="- [$title]($path) - *$type*\n"
        done < <(echo "$DOCS_JSON" | jq -c ".[] | select(.tags | contains(\"$tag\"))")

        INDEX_CONTENT+="\n"
      done <<< "$ALL_TAGS"
    else
      INDEX_CONTENT+="*(No tagged documents)*\n\n"
    fi

    # Untagged documents
    UNTAGGED=$(echo "$DOCS_JSON" | jq '[.[] | select(.tags == "")] | length')
    if [[ $UNTAGGED -gt 0 ]]; then
      INDEX_CONTENT+="### Untagged\n\n"

      while IFS= read -r doc; do
        title=$(echo "$doc" | jq -r '.title')
        path=$(echo "$doc" | jq -r '.path')
        type=$(echo "$doc" | jq -r '.type')

        INDEX_CONTENT+="- [$title]($path) - *$type*\n"
      done < <(echo "$DOCS_JSON" | jq -c '.[] | select(.tags == "")')

      INDEX_CONTENT+="\n"
    fi
    ;;

  date)
    # Group by year and month
    INDEX_CONTENT+="## Documents by Date\n\n"

    # Get unique year-months
    YEAR_MONTHS=$(echo "$DOCS_JSON" | jq -r '.[] | select(.date != "") | .date[0:7]' | sort -r -u)

    if [[ -n "$YEAR_MONTHS" ]]; then
      while IFS= read -r ym; do
        [[ -z "$ym" ]] && continue

        # Format as "2025-01" -> "January 2025"
        year="${ym%-*}"
        month="${ym#*-}"
        month_name=$(date -d "${year}-${month}-01" +%B 2>/dev/null || echo "$month")

        INDEX_CONTENT+="### $month_name $year\n\n"

        # Get docs from this month
        while IFS= read -r doc; do
          title=$(echo "$doc" | jq -r '.title')
          path=$(echo "$doc" | jq -r '.path')
          date=$(echo "$doc" | jq -r '.date')
          type=$(echo "$doc" | jq -r '.type')

          INDEX_CONTENT+="- [$title]($path) - *$type* - $date\n"
        done < <(echo "$DOCS_JSON" | jq -c ".[] | select(.date[0:7] == \"$ym\")" | sort -k4 -r)

        INDEX_CONTENT+="\n"
      done <<< "$YEAR_MONTHS"
    fi

    # Undated documents
    UNDATED=$(echo "$DOCS_JSON" | jq '[.[] | select(.date == "")] | length')
    if [[ $UNDATED -gt 0 ]]; then
      INDEX_CONTENT+="### Undated\n\n"

      while IFS= read -r doc; do
        title=$(echo "$doc" | jq -r '.title')
        path=$(echo "$doc" | jq -r '.path')
        type=$(echo "$doc" | jq -r '.type')

        INDEX_CONTENT+="- [$title]($path) - *$type*\n"
      done < <(echo "$DOCS_JSON" | jq -c '.[] | select(.date == "")')

      INDEX_CONTENT+="\n"
    fi
    ;;

  flat)
    # Flat alphabetical list
    INDEX_CONTENT+="## All Documents\n\n"

    while IFS= read -r doc; do
      title=$(echo "$doc" | jq -r '.title')
      path=$(echo "$doc" | jq -r '.path')
      type=$(echo "$doc" | jq -r '.type')
      status=$(echo "$doc" | jq -r '.status')

      if [[ -n "$status" ]]; then
        INDEX_CONTENT+="- [$title]($path) - *$type* - *$status*\n"
      else
        INDEX_CONTENT+="- [$title]($path) - *$type*\n"
      fi
    done < <(echo "$DOCS_JSON" | jq -c '.[] | sort_by(.title)')

    INDEX_CONTENT+="\n"
    ;;

  *)
    cat <<EOF
{
  "success": false,
  "error": "Invalid group-by strategy: $GROUP_BY. Must be: type, tag, date, or flat",
  "error_code": "INVALID_ARGUMENT"
}
EOF
    exit 1
    ;;
esac

# Create front matter
CURRENT_DATE=$(date +%Y-%m-%d)
FRONT_MATTER="---\n"
FRONT_MATTER+="title: \"$TITLE\"\n"
FRONT_MATTER+="type: architecture\n"
FRONT_MATTER+="date: \"$CURRENT_DATE\"\n"
FRONT_MATTER+="generated: true\n"
FRONT_MATTER+="---\n\n"

# Write index file
echo -e "${FRONT_MATTER}${INDEX_CONTENT}" > "$OUTPUT_FILE"

# Count groups
GROUP_COUNT=0
case "$GROUP_BY" in
  type)
    GROUP_COUNT=$(echo "$TYPES" | wc -l)
    ;;
  tag)
    GROUP_COUNT=$(echo "$ALL_TAGS" | grep -v '^$' | wc -l)
    ;;
  date)
    GROUP_COUNT=$(echo "$YEAR_MONTHS" | wc -l)
    ;;
  flat)
    GROUP_COUNT=1
    ;;
esac

# Return results
cat <<EOF
{
  "success": true,
  "operation": "create-index",
  "index_file": "$OUTPUT_FILE",
  "documents_indexed": $TOTAL_DOCS,
  "group_by": "$GROUP_BY",
  "groups": $GROUP_COUNT,
  "timestamp": "$(date -Iseconds)"
}
EOF
