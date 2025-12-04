#!/usr/bin/env bash
# Validate codex references in markdown files
#
# Usage: ./validate-refs.sh [options]
# Output: JSON with validation results
#
# Options:
#   --path <dir>        Directory to scan (default: .)
#   --pattern <glob>    File pattern (default: **/*.md)
#   --fix               Auto-fix @codex/ references
#   --json              Output in JSON format
#
# Checks for:
#   - Deprecated @codex/ references (should be codex://)
#   - Relative path references (../)
#   - Absolute path references (/)

set -euo pipefail

# Defaults
scan_path="."
file_pattern="**/*.md"
fix_mode="false"
json_output="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      scan_path="$2"
      shift 2
      ;;
    --pattern)
      file_pattern="$2"
      shift 2
      ;;
    --fix)
      fix_mode="true"
      shift
      ;;
    --json)
      json_output="true"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Arrays to track issues
declare -a deprecated_refs=()
declare -a relative_refs=()
declare -a fixed_files=()
files_scanned=0
refs_checked=0

# Find files to scan
while IFS= read -r file; do
  ((files_scanned++)) || true

  # Skip if not a regular file
  [[ ! -f "$file" ]] && continue

  line_num=0
  file_modified=false

  # Create temp file for fixes
  temp_file=""
  if [[ "$fix_mode" == "true" ]]; then
    temp_file=$(mktemp)
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_num++)) || true

    # Check for deprecated @codex/ references
    if [[ "$line" =~ @codex/([^)\"\'[:space:]]+) ]]; then
      ref="${BASH_REMATCH[1]}"
      ((refs_checked++)) || true

      if [[ "$fix_mode" == "true" ]]; then
        # Convert @codex/project/path to codex://org/project/path
        # Read organization from config
        org=""
        if [[ -f ".fractary/plugins/codex/config.json" ]]; then
          org=$(jq -r '.organization // empty' .fractary/plugins/codex/config.json 2>/dev/null || true)
        fi

        if [[ -n "$org" ]]; then
          # Extract project and path from ref
          project=$(echo "$ref" | cut -d'/' -f1)
          path=$(echo "$ref" | cut -d'/' -f2-)
          new_ref="codex://$org/$project/$path"
          line="${line/@codex\/$ref/$new_ref}"
          file_modified=true
        else
          deprecated_refs+=("$file:$line_num: @codex/$ref (cannot fix: organization not configured)")
        fi
      else
        deprecated_refs+=("$file:$line_num: @codex/$ref")
      fi
    fi

    # Check for relative path references in links
    if [[ "$line" =~ \]\((\.\./[^)]+)\) ]]; then
      ref="${BASH_REMATCH[1]}"
      ((refs_checked++)) || true
      relative_refs+=("$file:$line_num: $ref")
    fi

    # Write line to temp file if fixing
    if [[ "$fix_mode" == "true" ]] && [[ -n "$temp_file" ]]; then
      echo "$line" >> "$temp_file"
    fi
  done < "$file"

  # Apply fixes if file was modified
  if [[ "$fix_mode" == "true" ]] && [[ "$file_modified" == "true" ]] && [[ -n "$temp_file" ]]; then
    mv "$temp_file" "$file"
    fixed_files+=("$file")
  elif [[ -n "$temp_file" ]] && [[ -f "$temp_file" ]]; then
    rm -f "$temp_file"
  fi

done < <(find "$scan_path" -type f -name "*.md" 2>/dev/null || true)

# Calculate totals
deprecated_count=${#deprecated_refs[@]}
relative_count=${#relative_refs[@]}
fixed_count=${#fixed_files[@]}
total_issues=$((deprecated_count + relative_count))

# Output results
if [[ "$json_output" == "true" ]]; then
  jq -n \
    --argjson files_scanned "$files_scanned" \
    --argjson refs_checked "$refs_checked" \
    --argjson deprecated_count "$deprecated_count" \
    --argjson relative_count "$relative_count" \
    --argjson fixed_count "$fixed_count" \
    --argjson total_issues "$total_issues" \
    --argjson deprecated "$(printf '%s\n' "${deprecated_refs[@]:-}" | jq -R . | jq -s .)" \
    --argjson relative "$(printf '%s\n' "${relative_refs[@]:-}" | jq -R . | jq -s .)" \
    --argjson fixed "$(printf '%s\n' "${fixed_files[@]:-}" | jq -R . | jq -s .)" \
    --argjson fix_mode "$fix_mode" \
    '{
      success: true,
      files_scanned: $files_scanned,
      refs_checked: $refs_checked,
      issues: {
        total: $total_issues,
        deprecated: $deprecated_count,
        relative: $relative_count
      },
      deprecated_refs: $deprecated,
      relative_refs: $relative,
      fix_mode: $fix_mode,
      fixed_files: $fixed,
      fixed_count: $fixed_count
    }'
else
  if [[ $total_issues -eq 0 ]]; then
    echo "✅ Reference Validation Passed"
    echo ""
    echo "Scanned: $files_scanned files"
    echo "References checked: $refs_checked"
    echo "All references are portable"
  else
    echo "⚠️ Reference Validation Issues Found"
    echo ""
    echo "Scanned: $files_scanned files"
    echo "References checked: $refs_checked"
    echo "Issues found: $total_issues"
    echo ""

    if [[ $deprecated_count -gt 0 ]]; then
      echo "Deprecated @codex/ references:"
      for ref in "${deprecated_refs[@]}"; do
        echo "  $ref"
      done
      if [[ "$fix_mode" != "true" ]]; then
        echo "  → Run with --fix to convert to codex:// format"
      fi
      echo ""
    fi

    if [[ $relative_count -gt 0 ]]; then
      echo "Non-portable relative paths:"
      for ref in "${relative_refs[@]}"; do
        echo "  $ref"
      done
      echo "  → Review and convert to codex:// URIs if referencing codex content"
      echo ""
    fi

    if [[ "$fix_mode" == "true" ]] && [[ $fixed_count -gt 0 ]]; then
      echo "Fixed files:"
      for file in "${fixed_files[@]}"; do
        echo "  $file"
      done
      echo ""
    fi
  fi
fi
