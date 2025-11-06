#!/usr/bin/env bash
#
# generate-graph.sh - Generate document relationship graph
#
# Usage: generate-graph.sh --directory <path> --output <file> [--format <fmt>] [--include-tags]
#

set -euo pipefail

# Default values
DIRECTORY=""
OUTPUT_FILE=""
FORMAT="mermaid"  # mermaid, dot, json
INCLUDE_TAGS=false

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
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --include-tags)
      INCLUDE_TAGS="$2"
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
  cat <<EOF
{
  "success": false,
  "error": "Missing required argument: --directory",
  "error_code": "MISSING_ARGUMENT"
}
EOF
  exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
  cat <<EOF
{
  "success": false,
  "error": "Missing required argument: --output",
  "error_code": "MISSING_ARGUMENT"
}
EOF
  exit 1
fi

# Validate format
if [[ ! "$FORMAT" =~ ^(mermaid|dot|json)$ ]]; then
  cat <<EOF
{
  "success": false,
  "error": "Invalid format: $FORMAT. Must be: mermaid, dot, or json",
  "error_code": "INVALID_ARGUMENT"
}
EOF
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

# Build graph data structure
NODES="[]"
EDGES="[]"
NODE_ID=0

declare -A FILE_TO_ID
declare -A ID_TO_FILE

# First pass: collect all documents and assign IDs
while IFS= read -r file; do
  # Generate unique ID
  ID="doc$NODE_ID"
  FILE_TO_ID["$file"]=$ID
  ID_TO_FILE["$ID"]=$file
  ((NODE_ID++))

  # Parse front matter
  if head -n 1 "$file" | grep -q "^---$"; then
    FM_CONTENT=$(sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d')

    # Parse YAML to JSON
    if command -v yq &> /dev/null; then
      FM_JSON=$(echo "$FM_CONTENT" | yq eval -o json 2>/dev/null || echo "{}")
    else
      # Basic parsing
      FM_JSON="{"
      first=true
      while IFS=: read -r key value; do
        if [[ -n "$key" && -n "$value" ]]; then
          [[ "$first" == "false" ]] && FM_JSON+=","
          key=$(echo "$key" | xargs)
          value=$(echo "$value" | xargs | sed 's/^"//;s/"$//')
          FM_JSON+="\"$key\":\"$value\""
          first=false
        fi
      done <<< "$FM_CONTENT"
      FM_JSON+="}"
    fi

    # Extract node data
    TITLE=$(echo "$FM_JSON" | jq -r '.title // ""')
    TYPE=$(echo "$FM_JSON" | jq -r '.type // "other"')
    TAGS=$(echo "$FM_JSON" | jq -r '.tags // [] | if type == "array" then join(",") else . end')

    # Use filename if no title
    if [[ -z "$TITLE" ]]; then
      TITLE=$(basename "$file" .md)
    fi

    # Add node
    NODES=$(echo "$NODES" | jq \
      --arg id "$ID" \
      --arg title "$TITLE" \
      --arg type "$TYPE" \
      --arg tags "$TAGS" \
      --arg file "$file" \
      '. += [{
        "id": $id,
        "title": $title,
        "type": $type,
        "tags": $tags,
        "file": $file
      }]')
  fi
done < <(find "$DIRECTORY" -type f -name "*.md" | sort)

# Second pass: collect edges from related[] arrays
while IFS= read -r file; do
  SOURCE_ID="${FILE_TO_ID[$file]}"

  if head -n 1 "$file" | grep -q "^---$"; then
    FM_CONTENT=$(sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d')

    # Parse related array
    RELATED_ARRAY="[]"
    if command -v yq &> /dev/null; then
      RELATED_ARRAY=$(echo "$FM_CONTENT" | yq eval '.related // []' -o json 2>/dev/null || echo "[]")
    fi

    # Get file directory for resolving relative paths
    FILE_DIR="$(dirname "$file")"

    # Process each related link
    if [[ "$RELATED_ARRAY" != "[]" ]]; then
      while IFS= read -r rel_path; do
        [[ -z "$rel_path" ]] && continue

        # Resolve relative path
        if [[ "$rel_path" == /* ]]; then
          TARGET_FILE="$rel_path"
        else
          TARGET_FILE="$(cd "$FILE_DIR" && realpath -m "$rel_path" 2>/dev/null || echo "$rel_path")"
        fi

        # Check if target file exists in our node list
        if [[ -n "${FILE_TO_ID[$TARGET_FILE]:-}" ]]; then
          TARGET_ID="${FILE_TO_ID[$TARGET_FILE]}"

          # Add edge
          EDGES=$(echo "$EDGES" | jq \
            --arg from "$SOURCE_ID" \
            --arg to "$TARGET_ID" \
            '. += [{
              "from": $from,
              "to": $to
            }]')
        fi
      done < <(echo "$RELATED_ARRAY" | jq -r '.[]' 2>/dev/null || true)
    fi
  fi
done < <(find "$DIRECTORY" -type f -name "*.md" | sort)

# Add tag-based edges if requested
if [[ "$INCLUDE_TAGS" == "true" ]]; then
  # Group documents by tags
  declare -A TAG_DOCS

  while IFS= read -r node; do
    ID=$(echo "$node" | jq -r '.id')
    TAGS=$(echo "$node" | jq -r '.tags')

    if [[ -n "$TAGS" ]]; then
      IFS=',' read -ra TAG_ARRAY <<< "$TAGS"
      for tag in "${TAG_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs)  # trim whitespace
        TAG_DOCS["$tag"]+="$ID "
      done
    fi
  done < <(echo "$NODES" | jq -c '.[]')

  # Create edges between documents with same tags
  for tag in "${!TAG_DOCS[@]}"; do
    IFS=' ' read -ra DOC_IDS <<< "${TAG_DOCS[$tag]}"
    for ((i=0; i<${#DOC_IDS[@]}; i++)); do
      for ((j=i+1; j<${#DOC_IDS[@]}; j++)); do
        # Add bidirectional tag relationship
        EDGES=$(echo "$EDGES" | jq \
          --arg from "${DOC_IDS[$i]}" \
          --arg to "${DOC_IDS[$j]}" \
          --arg tag "$tag" \
          '. += [{
            "from": $from,
            "to": $to,
            "tag": $tag
          }]')
      done
    done
  done
fi

# Count graph metrics
NODE_COUNT=$(echo "$NODES" | jq 'length')
EDGE_COUNT=$(echo "$EDGES" | jq 'length')

# Generate output based on format
case "$FORMAT" in
  mermaid)
    # Generate Mermaid diagram
    OUTPUT="graph TB\n"

    # Type colors
    declare -A TYPE_COLORS=(
      ["adr"]="#e1f5ff"
      ["design"]="#fff4e1"
      ["runbook"]="#e8f5e9"
      ["api-spec"]="#f3e5f5"
      ["test-report"]="#fce4ec"
      ["deployment"]="#e0f2f1"
      ["changelog"]="#fff9c4"
      ["architecture"]="#e3f2fd"
      ["troubleshooting"]="#ffe0b2"
      ["postmortem"]="#ffebee"
      ["other"]="#f5f5f5"
    )

    # Add nodes
    while IFS= read -r node; do
      ID=$(echo "$node" | jq -r '.id')
      TITLE=$(echo "$node" | jq -r '.title')
      TYPE=$(echo "$node" | jq -r '.type')

      # Escape special characters in title
      TITLE=$(echo "$TITLE" | sed 's/"/\\"/g')

      OUTPUT+="  $ID[\"$TITLE\"]\n"
    done < <(echo "$NODES" | jq -c '.[]')

    # Add edges
    while IFS= read -r edge; do
      FROM=$(echo "$edge" | jq -r '.from')
      TO=$(echo "$edge" | jq -r '.to')
      TAG=$(echo "$edge" | jq -r '.tag // empty')

      if [[ -n "$TAG" ]]; then
        OUTPUT+="  $FROM -.\"$TAG\".-> $TO\n"
      else
        OUTPUT+="  $FROM --> $TO\n"
      fi
    done < <(echo "$EDGES" | jq -c '.[]')

    # Add styling
    while IFS= read -r node; do
      ID=$(echo "$node" | jq -r '.id')
      TYPE=$(echo "$node" | jq -r '.type')
      COLOR="${TYPE_COLORS[$TYPE]:-#f5f5f5}"

      OUTPUT+="  style $ID fill:$COLOR\n"
    done < <(echo "$NODES" | jq -c '.[]')

    # Write to file
    echo -e "$OUTPUT" > "$OUTPUT_FILE"
    ;;

  dot)
    # Generate GraphViz DOT format
    OUTPUT="digraph docs {\n"
    OUTPUT+="  rankdir=TB;\n"
    OUTPUT+="  node [shape=box];\n\n"

    # Add nodes
    while IFS= read -r node; do
      ID=$(echo "$node" | jq -r '.id')
      TITLE=$(echo "$node" | jq -r '.title')

      # Escape special characters
      TITLE=$(echo "$TITLE" | sed 's/"/\\"/g')

      OUTPUT+="  $ID [label=\"$TITLE\"];\n"
    done < <(echo "$NODES" | jq -c '.[]')

    OUTPUT+="\n"

    # Add edges
    while IFS= read -r edge; do
      FROM=$(echo "$edge" | jq -r '.from')
      TO=$(echo "$edge" | jq -r '.to')
      TAG=$(echo "$edge" | jq -r '.tag // empty')

      if [[ -n "$TAG" ]]; then
        OUTPUT+="  $FROM -> $TO [label=\"$TAG\", style=dashed];\n"
      else
        OUTPUT+="  $FROM -> $TO;\n"
      fi
    done < <(echo "$EDGES" | jq -c '.[]')

    OUTPUT+="}\n"

    # Write to file
    echo -e "$OUTPUT" > "$OUTPUT_FILE"
    ;;

  json)
    # Generate JSON graph
    GRAPH_JSON=$(jq -n \
      --argjson nodes "$NODES" \
      --argjson edges "$EDGES" \
      '{
        "nodes": $nodes,
        "edges": $edges,
        "metadata": {
          "node_count": ($nodes | length),
          "edge_count": ($edges | length),
          "generated": now | strftime("%Y-%m-%dT%H:%M:%SZ")
        }
      }')

    echo "$GRAPH_JSON" > "$OUTPUT_FILE"
    ;;
esac

# Return results
cat <<EOF
{
  "success": true,
  "operation": "generate-graph",
  "directory": "$DIRECTORY",
  "output_file": "$OUTPUT_FILE",
  "format": "$FORMAT",
  "include_tags": $INCLUDE_TAGS,
  "nodes": $NODE_COUNT,
  "edges": $EDGE_COUNT,
  "timestamp": "$(date -Iseconds)"
}
EOF
