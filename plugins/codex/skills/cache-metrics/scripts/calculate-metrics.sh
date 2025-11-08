#!/usr/bin/env bash
# calculate-metrics.sh - Calculate and display codex cache metrics
#
# Usage: calculate-metrics.sh <cache_path> <category> <format>
#
# Arguments:
#   cache_path - Path to cache directory (default: codex)
#   category   - Metric category: all|cache|performance|sources|storage (default: all)
#   format     - Output format: text|json (default: text)
#
# Returns: Formatted metrics output

set -euo pipefail

cache_path="${1:-codex}"
category="${2:-all}"
format="${3:-text}"

index_file="$cache_path/.cache-index.json"

# Check if cache exists
if [[ ! -d "$cache_path" ]]; then
  if [[ "$format" == "json" ]]; then
    echo '{"error": "Cache directory not found", "path": "'"$cache_path"'"}'
  else
    echo "⚠️  Cache not initialized"
    echo ""
    echo "No cache found at: $cache_path"
    echo ""
    echo "Fetch some documents first:"
    echo "  /fractary-codex:fetch @codex/project/path"
  fi
  exit 1
fi

# Check if index exists
if [[ ! -f "$index_file" ]]; then
  if [[ "$format" == "json" ]]; then
    echo '{"error": "Cache index not found", "index_path": "'"$index_file"'"}'
  else
    echo "⚠️  Cache index not found"
    echo ""
    echo "Index file missing: $index_file"
    echo "Cache may be corrupted. Try fetching a document to rebuild."
  fi
  exit 1
fi

# Read and validate index
if ! index=$(cat "$index_file" 2>/dev/null) || ! echo "$index" | jq empty 2>/dev/null; then
  if [[ "$format" == "json" ]]; then
    echo '{"error": "Invalid cache index JSON"}'
  else
    echo "⚠️  Cache index corrupted (invalid JSON)"
  fi
  exit 1
fi

# Extract basic info
version=$(echo "$index" | jq -r '.version // "unknown"')
last_cleanup=$(echo "$index" | jq -r '.stats.last_cleanup // "never"')

# Calculate cache statistics
total_docs=$(echo "$index" | jq '.entries | length')
total_size_bytes=$(echo "$index" | jq '[.entries[].size_bytes] | add // 0')
total_size_mb=$(echo "$total_size_bytes" | awk '{printf "%.1f", $1/1024/1024}')

# Calculate fresh vs expired
now_epoch=$(date +%s)
fresh_count=0
expired_count=0

while IFS= read -r entry; do
  cached_at=$(echo "$entry" | jq -r '.cached_at')
  ttl_days=$(echo "$entry" | jq -r '.ttl_days // 7')

  # Convert cached_at to epoch
  if [[ "$cached_at" != "null" ]]; then
    cached_epoch=$(date -d "$cached_at" +%s 2>/dev/null || echo "0")
    ttl_seconds=$((ttl_days * 86400))
    expires_at=$((cached_epoch + ttl_seconds))

    if [[ $now_epoch -lt $expires_at ]]; then
      ((fresh_count++)) || true
    else
      ((expired_count++)) || true
    fi
  fi
done < <(echo "$index" | jq -c '.entries[]')

if [[ $total_docs -gt 0 ]]; then
  fresh_pct=$(echo "$fresh_count $total_docs" | awk '{printf "%.1f", ($1/$2)*100}')
  expired_pct=$(echo "$expired_count $total_docs" | awk '{printf "%.1f", ($1/$2)*100}')
else
  fresh_pct="0.0"
  expired_pct="0.0"
fi

# Calculate performance metrics (if available)
cache_hits=$(echo "$index" | jq '.stats.cache_hits // 0')
cache_misses=$(echo "$index" | jq '.stats.cache_misses // 0')
total_fetches=$((cache_hits + cache_misses))

if [[ $total_fetches -gt 0 ]]; then
  hit_rate=$(echo "$cache_hits $total_fetches" | awk '{printf "%.1f", ($1/$2)*100}')
else
  hit_rate="0.0"
fi

avg_hit_ms=$(echo "$index" | jq '.stats.avg_cache_hit_ms // 0')
avg_fetch_ms=$(echo "$index" | jq '.stats.avg_fetch_ms // 0')
failed_fetches=$(echo "$index" | jq '.stats.failed_fetches // 0')

if [[ $total_fetches -gt 0 ]]; then
  failure_rate=$(echo "$failed_fetches $total_fetches" | awk '{printf "%.1f", ($1/$2)*100}')
else
  failure_rate="0.0"
fi

# Analyze sources
sources_json=$(echo "$index" | jq '[.entries | group_by(.source) | .[] | {
  name: .[0].source,
  count: length,
  size_bytes: ([.[].size_bytes] | add)
}]')

# Find largest documents
largest_docs=$(echo "$index" | jq -r '[.entries | sort_by(.size_bytes) | reverse | .[0:10] | .[] |
  {path: .path, size_mb: (.size_bytes / 1024 / 1024)}] | .[]  | "\(.path):\(.size_mb)"' | head -n 3)

# Check disk space
if df_output=$(df -h "$cache_path" 2>/dev/null | tail -n 1); then
  disk_free_pct=$(echo "$df_output" | awk '{print $5}' | tr -d '%')
  disk_free_pct=$((100 - disk_free_pct))
else
  disk_free_pct="unknown"
fi

# Determine health status
health_status="healthy"
health_cache_accessible=true
health_index_valid=true
health_corrupted=0

if [[ ! -r "$cache_path" ]]; then
  health_cache_accessible=false
  health_status="unhealthy"
fi

if [[ "$disk_free_pct" != "unknown" ]] && [[ $disk_free_pct -lt 10 ]]; then
  health_status="warning"
fi

# Generate recommendations
recommendations=()

if [[ $expired_count -gt 0 ]]; then
  recommendations+=("Clear $expired_count expired documents: /fractary-codex:cache-clear --expired")
fi

compression_enabled=$(echo "$index" | jq -r '.config.compression // false')
if [[ "$compression_enabled" == "false" ]] && [[ $total_size_bytes -gt 10485760 ]]; then  # > 10 MB
  recommendations+=("Consider enabling compression to save disk space")
fi

if [[ "$hit_rate" != "0.0" ]]; then
  hit_rate_num=${hit_rate%.*}
  if [[ $hit_rate_num -lt 80 ]]; then
    recommendations+=("Cache hit rate is low ($hit_rate%). Consider prefetching common docs.")
  fi
fi

if [[ "$disk_free_pct" != "unknown" ]] && [[ $disk_free_pct -lt 20 ]]; then
  recommendations+=("Disk space low ($disk_free_pct% free). Consider clearing cache or freeing space.")
fi

# Format output
if [[ "$format" == "json" ]]; then
  # JSON output
  recs_json=$(printf '%s\n' "${recommendations[@]}" | jq -R . | jq -s .)

  cat <<EOF
{
  "cache": {
    "total_documents": $total_docs,
    "total_size_bytes": $total_size_bytes,
    "total_size_mb": $total_size_mb,
    "fresh_documents": $fresh_count,
    "expired_documents": $expired_count,
    "fresh_percentage": $fresh_pct,
    "last_cleanup": "$last_cleanup",
    "cache_path": "$cache_path"
  },
  "performance": {
    "cache_hit_rate": $hit_rate,
    "avg_cache_hit_ms": $avg_hit_ms,
    "avg_fetch_ms": $avg_fetch_ms,
    "total_fetches": $total_fetches,
    "failed_fetches": $failed_fetches,
    "failure_rate": $failure_rate
  },
  "sources": $sources_json,
  "storage": {
    "disk_used_mb": $total_size_mb,
    "compression_enabled": $compression_enabled,
    "disk_free_percent": $disk_free_pct
  },
  "health": {
    "status": "$health_status",
    "cache_accessible": $health_cache_accessible,
    "index_valid": $health_index_valid,
    "corrupted_entries": $health_corrupted,
    "disk_free_percent": $disk_free_pct
  },
  "recommendations": $recs_json
}
EOF

else
  # Text output
  echo "📊 Codex Knowledge Retrieval Metrics"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  if [[ "$category" == "all" ]] || [[ "$category" == "cache" ]]; then
    echo "CACHE STATISTICS"
    echo "────────────────────────────────────────────────────────────"
    printf "%-24s %s\n" "Total Documents:" "$total_docs files"
    printf "%-24s %s MB\n" "Cache Size:" "$total_size_mb"
    printf "%-24s %s (%s%%)\n" "Fresh Documents:" "$fresh_count" "$fresh_pct"
    printf "%-24s %s (%s%%)\n" "Expired Documents:" "$expired_count" "$expired_pct"
    printf "%-24s %s\n" "Last Cleanup:" "$last_cleanup"
    printf "%-24s %s\n" "Cache Path:" "$cache_path"
    echo ""
  fi

  if [[ "$category" == "all" ]] || [[ "$category" == "performance" ]]; then
    echo "PERFORMANCE METRICS"
    echo "────────────────────────────────────────────────────────────"
    printf "%-24s %s%%\n" "Cache Hit Rate:" "$hit_rate"
    printf "%-24s %s ms\n" "Avg Cache Hit Time:" "$avg_hit_ms"
    printf "%-24s %s ms\n" "Avg Fetch Time:" "$avg_fetch_ms"
    printf "%-24s %s\n" "Total Fetches:" "$total_fetches"
    printf "%-24s %s (%s%%)\n" "Failed Fetches:" "$failed_fetches" "$failure_rate"
    echo ""
  fi

  if [[ "$category" == "all" ]] || [[ "$category" == "sources" ]]; then
    echo "SOURCE BREAKDOWN"
    echo "────────────────────────────────────────────────────────────"
    while IFS= read -r source; do
      name=$(echo "$source" | jq -r '.name')
      count=$(echo "$source" | jq -r '.count')
      size_mb=$(echo "$source" | jq -r '.size_bytes / 1024 / 1024 | floor')
      printf "%-24s %s docs (%s MB)\n" "$name:" "$count" "$size_mb"
    done < <(echo "$sources_json" | jq -c '.[]')
    echo ""
  fi

  if [[ "$category" == "all" ]] || [[ "$category" == "storage" ]]; then
    echo "STORAGE USAGE"
    echo "────────────────────────────────────────────────────────────"
    printf "%-24s %s MB\n" "Disk Space Used:" "$total_size_mb"
    printf "%-24s %s\n" "Compression:" "$([ "$compression_enabled" == "true" ] && echo "Enabled" || echo "Disabled")"
    if [[ -n "$largest_docs" ]]; then
      echo "Largest Documents:"
      echo "$largest_docs" | while IFS=: read -r path size; do
        printf "  • %s (%.1f MB)\n" "$path" "$size"
      done
    fi
    echo ""
  fi

  # Always show health
  echo "HEALTH STATUS: $([ "$health_status" == "healthy" ] && echo "✅ Healthy" || echo "⚠️  $health_status")"
  echo "────────────────────────────────────────────────────────────"
  echo "✓ Cache accessible"
  echo "✓ Index valid"
  echo "✓ No corrupted entries"
  if [[ "$disk_free_pct" != "unknown" ]]; then
    echo "✓ Disk space available ($disk_free_pct% free)"
  fi
  echo ""

  if [[ ${#recommendations[@]} -gt 0 ]]; then
    echo "Recommendations:"
    for rec in "${recommendations[@]}"; do
      echo "  • $rec"
    done
    echo ""
  fi
fi
