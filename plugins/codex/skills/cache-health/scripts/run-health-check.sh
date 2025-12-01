#!/usr/bin/env bash
# run-health-check.sh - Comprehensive health check for codex cache system
#
# Usage: run-health-check.sh <cache_path> <check_category> <verbose> <fix> <format>
#
# Arguments:
#   cache_path      - Path to cache directory
#   check_category  - Category: all|cache|config|performance|storage|system
#   verbose         - true|false for detailed output
#   fix             - true|false to attempt automatic repairs
#   format          - text|json output format
#
# Returns: Health check results with exit code

set -euo pipefail

cache_path="${1:-codex}"
check_category="${2:-all}"
verbose="${3:-false}"
fix="${4:-false}"
format="${5:-text}"

# Counters
checks_passed=0
checks_total=0
warnings=0
errors=0

# Results arrays
declare -a cache_checks=()
declare -a config_checks=()
declare -a performance_checks=()
declare -a storage_checks=()
declare -a system_checks=()
declare -a recommendations=()
declare -a fixes_applied=()

# Helper: Check and record result
# Usage: check_item "category" "name" "description" "command"
check_item() {
  local category="$1"
  local name="$2"
  local description="$3"
  local command="$4"

  ((checks_total++)) || true

  if eval "$command" >/dev/null 2>&1; then
    ((checks_passed++)) || true
    eval "${category}_checks+=(\"✓ $description:pass\")"
    return 0
  else
    eval "${category}_checks+=(\"✗ $description:fail\")"
    return 1
  fi
}

# CACHE HEALTH CHECKS
cache_status="pass"

if [[ "$check_category" == "all" ]] || [[ "$check_category" == "cache" ]]; then
  # Check 1: Cache directory exists
  if [[ -d "$cache_path" ]]; then
    ((checks_passed++)); ((checks_total++))
    cache_checks+=("✓ Cache directory exists ($cache_path):pass")
  else
    ((checks_total++))
    cache_checks+=("! Cache not initialized ($cache_path):warning")
    cache_status="warning"
    recommendations+=("Initialize cache by fetching a document: /fractary-codex:fetch @codex/project/path")
  fi

  # Check 2: Cache index exists and valid
  index_file="$cache_path/.cache-index.json"
  if [[ -f "$index_file" ]]; then
    if cat "$index_file" | jq empty 2>/dev/null; then
      ((checks_passed++)); ((checks_total++))
      cache_checks+=("✓ Cache index valid (.cache-index.json):pass")
    else
      ((errors++)); ((checks_total++))
      cache_checks+=("✗ Cache index corrupted (invalid JSON):error")
      cache_status="error"
      recommendations+=("Rebuild index: /fractary-codex:health --fix")
    fi
  else
    if [[ -d "$cache_path" ]]; then
      ((warnings++)); ((checks_total++))
      cache_checks+=("! Cache index missing:warning")
      cache_status="warning"
    fi
  fi

  # Check 3: File permissions
  if [[ -d "$cache_path" ]] && [[ -r "$cache_path" ]] && [[ -w "$cache_path" ]]; then
    ((checks_passed++)); ((checks_total++))
    cache_checks+=("✓ File permissions correct:pass")
  elif [[ -d "$cache_path" ]]; then
    ((errors++)); ((checks_total++))
    cache_checks+=("✗ Permission denied on cache directory:error")
    cache_status="error"
    recommendations+=("Fix permissions: chmod -R u+rw $cache_path")
  fi

  # Check 4: Orphaned files
  if [[ -f "$index_file" ]] && [[ -d "$cache_path" ]]; then
    indexed_files=$(cat "$index_file" | jq -r '.entries[].path' | sort)
    actual_files=$(find "$cache_path" -type f ! -name '.cache-index.json' -printf '%P\n' | sort)

    orphaned_count=$(comm -13 <(echo "$indexed_files") <(echo "$actual_files") | wc -l)

    if [[ $orphaned_count -eq 0 ]]; then
      ((checks_passed++)); ((checks_total++))
      cache_checks+=("✓ No orphaned files:pass")
    else
      ((warnings++)); ((checks_total++))
      cache_checks+=("! $orphaned_count orphaned files (in cache but not indexed):warning")
      cache_status="warning"
      recommendations+=("Clean orphaned files: /fractary-codex:health --fix")

      if [[ "$fix" == "true" ]]; then
        # Remove orphaned files
        comm -13 <(echo "$indexed_files") <(echo "$actual_files") | while read -r file; do
          rm -f "$cache_path/$file" 2>/dev/null || true
          fixes_applied+=("Removed orphaned file: $file")
        done
      fi
    fi
  fi
fi

# CONFIGURATION HEALTH CHECKS
config_status="pass"
config_file=".fractary/plugins/codex/config.json"

if [[ "$check_category" == "all" ]] || [[ "$check_category" == "config" ]]; then
  # Check 1: Config exists
  if [[ -f "$config_file" ]]; then
    ((checks_passed++)); ((checks_total++))
    config_checks+=("✓ Config file exists ($config_file):pass")
  else
    ((warnings++)); ((checks_total++))
    config_checks+=("! Config file not found:warning")
    config_status="warning"
    recommendations+=("Initialize configuration: /fractary-codex:init")
  fi

  # Check 2: Valid JSON
  if [[ -f "$config_file" ]]; then
    if cat "$config_file" | jq empty 2>/dev/null; then
      ((checks_passed++)); ((checks_total++))
      config_checks+=("✓ Valid JSON format:pass")
    else
      ((errors++)); ((checks_total++))
      config_checks+=("✗ Invalid JSON in config:error")
      config_status="error"
    fi
  fi

  # Check 3: Required fields present
  if [[ -f "$config_file" ]] && cat "$config_file" | jq empty 2>/dev/null; then
    org=$(cat "$config_file" | jq -r '.organization // empty')
    repo=$(cat "$config_file" | jq -r '.codex_repo // empty')

    if [[ -n "$org" ]] && [[ -n "$repo" ]]; then
      ((checks_passed++)); ((checks_total++))
      config_checks+=("✓ Required fields present (organization, codex_repo):pass")
    else
      ((errors++)); ((checks_total++))
      config_checks+=("✗ Missing required fields:error")
      config_status="error"
    fi
  fi

  # Check 4: V3.0 sources array
  if [[ -f "$config_file" ]] && cat "$config_file" | jq empty 2>/dev/null; then
    has_sources=$(cat "$config_file" | jq 'has("sources")')

    if [[ "$has_sources" == "true" ]]; then
      ((checks_passed++)); ((checks_total++))
      source_count=$(cat "$config_file" | jq '.sources | length')
      config_checks+=("✓ V3.0 configuration ($source_count sources):pass")
    else
      ((warnings++)); ((checks_total++))
      config_checks+=("! V2.0 configuration (needs migration):warning")
      config_status="warning"
      recommendations+=("Migrate to V3.0: /fractary-codex:migrate")
    fi
  fi
fi

# PERFORMANCE HEALTH CHECKS
perf_status="pass"

if [[ "$check_category" == "all" ]] || [[ "$check_category" == "performance" ]]; then
  if [[ -f "$cache_path/.cache-index.json" ]]; then
    index=$(cat "$cache_path/.cache-index.json")

    # Check hit rate
    cache_hits=$(echo "$index" | jq '.stats.cache_hits // 0')
    cache_misses=$(echo "$index" | jq '.stats.cache_misses // 0')
    total_fetches=$((cache_hits + cache_misses))

    if [[ $total_fetches -gt 0 ]]; then
      hit_rate=$(echo "$cache_hits $total_fetches" | awk '{printf "%.1f", ($1/$2)*100}')
      hit_rate_int=${hit_rate%.*}

      if [[ $hit_rate_int -ge 70 ]]; then
        ((checks_passed++)); ((checks_total++))
        performance_checks+=("✓ Cache hit rate good ($hit_rate% >= 70%):pass")
      else
        ((warnings++)); ((checks_total++))
        performance_checks+=("! Cache hit rate low ($hit_rate% < 70%):warning")
        perf_status="warning"
        recommendations+=("Improve hit rate: prefetch common docs or increase TTL")
      fi
    fi

    # Check expired documents
    total_docs=$(echo "$index" | jq '.entries | length')
    if [[ $total_docs -gt 0 ]]; then
      now_epoch=$(date +%s)
      expired_count=0

      while IFS= read -r entry; do
        cached_at=$(echo "$entry" | jq -r '.cached_at // empty')
        ttl_days=$(echo "$entry" | jq -r '.ttl_days // 7')

        if [[ -n "$cached_at" ]]; then
          cached_epoch=$(date -d "$cached_at" +%s 2>/dev/null || echo "0")
          ttl_seconds=$((ttl_days * 86400))
          expires_at=$((cached_epoch + ttl_seconds))

          if [[ $now_epoch -ge $expires_at ]]; then
            ((expired_count++)) || true
          fi
        fi
      done < <(echo "$index" | jq -c '.entries[]')

      expired_pct=$(echo "$expired_count $total_docs" | awk '{printf "%.0f", ($1/$2)*100}')

      if [[ $expired_pct -lt 20 ]]; then
        ((checks_passed++)); ((checks_total++))
        performance_checks+=("✓ Expired documents manageable ($expired_count, $expired_pct%):pass")
      else
        ((warnings++)); ((checks_total++))
        performance_checks+=("! Many expired documents ($expired_count, $expired_pct%):warning")
        perf_status="warning"
        recommendations+=("Clear expired documents: /fractary-codex:cache-clear --expired")
      fi
    fi
  fi
fi

# STORAGE HEALTH CHECKS
storage_status="pass"

if [[ "$check_category" == "all" ]] || [[ "$check_category" == "storage" ]]; then
  # Check disk space
  if df_output=$(df -h "$cache_path" 2>/dev/null | tail -n 1); then
    avail_gb=$(echo "$df_output" | awk '{print $4}' | sed 's/G//')

    if (( $(echo "$avail_gb >= 1" | bc -l 2>/dev/null || echo 0) )); then
      ((checks_passed++)); ((checks_total++))
      storage_checks+=("✓ Disk space sufficient (${avail_gb}G available):pass")
    else
      ((errors++)); ((checks_total++))
      storage_checks+=("✗ Low disk space (${avail_gb}G available):error")
      storage_status="error"
      recommendations+=("Free up disk space or clear cache")
    fi
  fi
fi

# SYSTEM HEALTH CHECKS
system_status="pass"

if [[ "$check_category" == "all" ]] || [[ "$check_category" == "system" ]]; then
  # Check git
  if command -v git >/dev/null 2>&1; then
    ((checks_passed++)); ((checks_total++))
    system_checks+=("✓ Git installed and accessible:pass")
  else
    ((errors++)); ((checks_total++))
    system_checks+=("✗ Git not found:error")
    system_status="error"
  fi

  # Check jq
  if command -v jq >/dev/null 2>&1; then
    ((checks_passed++)); ((checks_total++))
    system_checks+=("✓ jq installed for JSON processing:pass")
  else
    ((errors++)); ((checks_total++))
    system_checks+=("✗ jq not found:error")
    system_status="error"
  fi
fi

# Determine overall status
overall_status="healthy"
if [[ $errors -gt 0 ]]; then
  overall_status="error"
  exit_code=2
elif [[ $warnings -gt 0 ]]; then
  overall_status="warning"
  exit_code=1
else
  overall_status="healthy"
  exit_code=0
fi

# Output results
if [[ "$format" == "json" ]]; then
  # JSON output
  recs_json=$(printf '%s\n' "${recommendations[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
  fixes_json=$(printf '%s\n' "${fixes_applied[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")

  cat <<EOF
{
  "cache": {"status": "$cache_status"},
  "config": {"status": "$config_status"},
  "performance": {"status": "$perf_status"},
  "storage": {"status": "$storage_status"},
  "system": {"status": "$system_status"},
  "overall": {
    "status": "$overall_status",
    "checks_passed": $checks_passed,
    "checks_total": $checks_total,
    "warnings": $warnings,
    "errors": $errors,
    "exit_code": $exit_code
  },
  "recommendations": $recs_json,
  "fixes_applied": $fixes_json
}
EOF
else
  # Text output
  echo "🏥 Codex Health Check"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  if [[ "$check_category" == "all" ]] || [[ "$check_category" == "cache" ]]; then
    status_icon=$([ "$cache_status" == "pass" ] && echo "✅ PASS" || [ "$cache_status" == "warning" ] && echo "⚠️  WARNING" || echo "❌ ERROR")
    printf "%-56s %s\n" "CACHE HEALTH" "$status_icon"
    echo "────────────────────────────────────────────────────────────"
    for check in "${cache_checks[@]}"; do
      echo "${check%%:*}"
    done
    echo ""
  fi

  if [[ "$check_category" == "all" ]] || [[ "$check_category" == "config" ]]; then
    status_icon=$([ "$config_status" == "pass" ] && echo "✅ PASS" || [ "$config_status" == "warning" ] && echo "⚠️  WARNING" || echo "❌ ERROR")
    printf "%-56s %s\n" "CONFIGURATION HEALTH" "$status_icon"
    echo "────────────────────────────────────────────────────────────"
    for check in "${config_checks[@]}"; do
      echo "${check%%:*}"
    done
    echo ""
  fi

  if [[ "$check_category" == "all" ]] || [[ "$check_category" == "performance" ]]; then
    status_icon=$([ "$perf_status" == "pass" ] && echo "✅ PASS" || [ "$perf_status" == "warning" ] && echo "⚠️  WARNING" || echo "❌ ERROR")
    printf "%-56s %s\n" "PERFORMANCE HEALTH" "$status_icon"
    echo "────────────────────────────────────────────────────────────"
    for check in "${performance_checks[@]}"; do
      echo "${check%%:*}"
    done
    echo ""
  fi

  if [[ "$check_category" == "all" ]] || [[ "$check_category" == "storage" ]]; then
    status_icon=$([ "$storage_status" == "pass" ] && echo "✅ PASS" || [ "$storage_status" == "warning" ] && echo "⚠️  WARNING" || echo "❌ ERROR")
    printf "%-56s %s\n" "STORAGE HEALTH" "$status_icon"
    echo "────────────────────────────────────────────────────────────"
    for check in "${storage_checks[@]}"; do
      echo "${check%%:*}"
    done
    echo ""
  fi

  if [[ "$check_category" == "all" ]] || [[ "$check_category" == "system" ]]; then
    status_icon=$([ "$system_status" == "pass" ] && echo "✅ PASS" || [ "$system_status" == "warning" ] && echo "⚠️  WARNING" || echo "❌ ERROR")
    printf "%-56s %s\n" "SYSTEM HEALTH" "$status_icon"
    echo "────────────────────────────────────────────────────────────"
    for check in "${system_checks[@]}"; do
      echo "${check%%:*}"
    done
    echo ""
  fi

  echo "═══════════════════════════════════════════════════════════"
  echo ""
  overall_icon=$([ "$overall_status" == "healthy" ] && echo "✅ Healthy" || [ "$overall_status" == "warning" ] && echo "⚠️  Warning" || echo "❌ Error")
  echo "OVERALL STATUS: $overall_icon"
  echo ""
  echo "Summary:"
  printf "  Checks passed:  %d/%d (%d%%)\n" "$checks_passed" "$checks_total" $(( checks_passed * 100 / checks_total ))
  printf "  Warnings:       %d\n" "$warnings"
  printf "  Errors:         %d\n" "$errors"
  echo ""

  if [[ ${#recommendations[@]} -gt 0 ]]; then
    echo "Recommendations:"
    for rec in "${recommendations[@]}"; do
      echo "  • $rec"
    done
    echo ""
  fi

  if [[ ${#fixes_applied[@]} -gt 0 ]]; then
    echo "Fixes Applied:"
    for fix in "${fixes_applied[@]}"; do
      echo "  • $fix"
    done
    echo ""
  fi
fi

exit $exit_code
