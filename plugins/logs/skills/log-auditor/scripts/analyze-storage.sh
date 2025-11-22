#!/usr/bin/env bash
# analyze-storage.sh - Calculate storage impact and savings
#
# Usage: analyze-storage.sh <discovery_logs_json> <output_json>
#
# Analyzes:
# - Total storage used by logs
# - Breakdown by category and managed status
# - Potential savings from cloud archival
# - Compression estimates (60-70% reduction)
# - Cloud storage cost estimates
#
# Outputs JSON with storage analysis

set -euo pipefail

DISCOVERY_LOGS="${1:-discovery-logs.json}"
OUTPUT_JSON="${2:-discovery-storage.json}"

echo "🔍 Analyzing storage impact..." >&2

# Check if input exists
if [[ ! -f "$DISCOVERY_LOGS" ]]; then
  echo "❌ Error: $DISCOVERY_LOGS not found" >&2
  exit 1
fi

# Read total size from discovery JSON
if command -v jq &>/dev/null; then
  total_bytes=$(jq -r '.total_size_bytes' "$DISCOVERY_LOGS")
  total_logs=$(jq -r '.total_logs' "$DISCOVERY_LOGS")
  managed_count=$(jq -r '.by_status.managed' "$DISCOVERY_LOGS")
  unmanaged_count=$(jq -r '.by_status.unmanaged' "$DISCOVERY_LOGS")

  # Calculate size by status
  managed_bytes=0
  unmanaged_bytes=0

  while IFS= read -r log_entry; do
    size=$(echo "$log_entry" | jq -r '.size')
    managed=$(echo "$log_entry" | jq -r '.managed')

    if [[ "$managed" == "true" ]]; then
      managed_bytes=$((managed_bytes + size))
    else
      unmanaged_bytes=$((unmanaged_bytes + size))
    fi
  done < <(jq -c '.logs[]' "$DISCOVERY_LOGS")

  # Calculate size by type
  declare -A type_sizes
  while IFS= read -r log_entry; do
    size=$(echo "$log_entry" | jq -r '.size')
    type=$(echo "$log_entry" | jq -r '.type')
    type_sizes[$type]=$((${type_sizes[$type]:-0} + size))
  done < <(jq -c '.logs[]' "$DISCOVERY_LOGS")

else
  # Fallback without jq
  echo "  (jq not found, using estimates)" >&2
  total_bytes=0
  total_logs=0
  managed_count=0
  unmanaged_count=0
  managed_bytes=0
  unmanaged_bytes=0
  declare -A type_sizes
fi

# Storage calculations
total_gb=$(awk "BEGIN {printf \"%.3f\", $total_bytes / 1073741824}")
managed_gb=$(awk "BEGIN {printf \"%.3f\", $managed_bytes / 1073741824}")
unmanaged_gb=$(awk "BEGIN {printf \"%.3f\", $unmanaged_bytes / 1073741824}")

# Compression estimates (typical 60-70% reduction for text logs)
compression_ratio=0.35  # 35% of original size after compression
compressed_bytes=$(awk "BEGIN {printf \"%.0f\", $total_bytes * $compression_ratio}")
compressed_gb=$(awk "BEGIN {printf \"%.3f\", $compressed_bytes / 1073741824}")
compression_savings_bytes=$(awk "BEGIN {printf \"%.0f\", $total_bytes * (1 - $compression_ratio)}")
compression_savings_gb=$(awk "BEGIN {printf \"%.3f\", $compression_savings_bytes / 1073741824}")

# Hybrid retention savings
# Assume 30 days local retention, rest archived
# Estimate 20% of logs are within 30 days
local_ratio=0.20
local_bytes=$(awk "BEGIN {printf \"%.0f\", $total_bytes * $local_ratio}")
local_gb=$(awk "BEGIN {printf \"%.3f\", $local_bytes / 1073741824}")
archived_bytes=$(awk "BEGIN {printf \"%.0f\", $total_bytes * (1 - $local_ratio)}")
archived_gb=$(awk "BEGIN {printf \"%.3f\", $archived_bytes / 1073741824}")

# Cloud storage cost estimates
# S3 Standard: ~$0.023/GB/month
# R2: ~$0.015/GB/month (Cloudflare R2)
# Use R2 pricing as it's more cost-effective for logs
price_per_gb_month=0.015
monthly_cost_uncompressed=$(awk "BEGIN {printf \"%.2f\", $archived_bytes / 1073741824 * $price_per_gb_month}")
monthly_cost_compressed=$(awk "BEGIN {printf \"%.2f\", $compressed_bytes / 1073741824 * $price_per_gb_month}")

# Repository size impact (unmanaged logs that would be removed from VCS)
repo_impact_bytes=$unmanaged_bytes
repo_impact_gb=$unmanaged_gb

# Build size_by_type JSON
size_by_type_json="{"
first=true
for type in "${!type_sizes[@]}"; do
  if [[ "$first" == "false" ]]; then
    size_by_type_json+=","
  fi
  type_gb=$(awk "BEGIN {printf \"%.3f\", ${type_sizes[$type]} / 1073741824}")
  size_by_type_json+="\"$type\":{\"bytes\":${type_sizes[$type]},\"gb\":$type_gb}"
  first=false
done
size_by_type_json+="}"

# Write final JSON
cat > "$OUTPUT_JSON" <<EOF
{
  "discovery_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_storage": {
    "bytes": $total_bytes,
    "gb": $total_gb,
    "log_count": $total_logs
  },
  "by_status": {
    "managed": {
      "bytes": $managed_bytes,
      "gb": $managed_gb,
      "count": $managed_count
    },
    "unmanaged": {
      "bytes": $unmanaged_bytes,
      "gb": $unmanaged_gb,
      "count": $unmanaged_count
    }
  },
  "size_by_type": $size_by_type_json,
  "compression_analysis": {
    "original_bytes": $total_bytes,
    "original_gb": $total_gb,
    "compressed_bytes": $compressed_bytes,
    "compressed_gb": $compressed_gb,
    "savings_bytes": $compression_savings_bytes,
    "savings_gb": $compression_savings_gb,
    "compression_ratio": $compression_ratio
  },
  "hybrid_retention": {
    "local_30_days": {
      "bytes": $local_bytes,
      "gb": $local_gb,
      "description": "Recent logs kept locally (fast access)"
    },
    "archived_cloud": {
      "bytes": $archived_bytes,
      "gb": $archived_gb,
      "description": "Historical logs archived to cloud (compressed)"
    }
  },
  "cost_estimates": {
    "cloud_storage": {
      "uncompressed_monthly_usd": $monthly_cost_uncompressed,
      "compressed_monthly_usd": $monthly_cost_compressed,
      "currency": "USD",
      "provider": "R2",
      "price_per_gb_month": $price_per_gb_month
    }
  },
  "repository_impact": {
    "current_logs_in_repo_bytes": $repo_impact_bytes,
    "current_logs_in_repo_gb": $repo_impact_gb,
    "savings_after_adoption": {
      "bytes": $repo_impact_bytes,
      "gb": $repo_impact_gb,
      "description": "Repository size reduction from removing logs"
    }
  },
  "recommendations": {
    "enable_compression": {
      "enabled": true,
      "threshold_mb": 1,
      "savings_gb": $compression_savings_gb
    },
    "hybrid_retention": {
      "local_days": 30,
      "cloud_retention": "forever",
      "benefits": [
        "Fast access to recent logs",
        "Permanent historical record",
        "Reduced local storage by ${archived_gb}GB"
      ]
    },
    "estimated_monthly_cost": {
      "usd": $monthly_cost_compressed,
      "description": "Cloud storage for archived logs (compressed)"
    }
  }
}
EOF

echo "✅ Storage analysis complete" >&2
echo "  Total: ${total_gb}GB ($total_logs files)" >&2
echo "  Unmanaged: ${unmanaged_gb}GB ($unmanaged_count files)" >&2
echo "  Compression savings: ${compression_savings_gb}GB" >&2
echo "  Estimated cloud cost: \$${monthly_cost_compressed}/month" >&2
echo "  Output: $OUTPUT_JSON" >&2
