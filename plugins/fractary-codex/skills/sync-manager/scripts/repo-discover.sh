#!/bin/bash
# Discovers the Codex repository for the current organization
# Priority: 1) .env configuration, 2) Auto-discovery
#
# Usage:
#   CODEX_REPO=$(./codex-discover-repo.sh)
#   if [ $? -ne 0 ]; then
#     echo "Failed to discover Codex repository"
#     exit 1
#   fi

set -e

# Load .env if present
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

# Check for explicit configuration
if [ -n "$CODEX_GITHUB_ORG" ] && [ -n "$CODEX_GITHUB_REPO" ]; then
  echo "$CODEX_GITHUB_ORG/$CODEX_GITHUB_REPO"
  exit 0
fi

# Auto-discovery: find codex repo by pattern (codex.*)
GITHUB_ORG=$(gh repo view --json owner -q .owner.login 2>/dev/null || echo "")

if [ -n "$GITHUB_ORG" ]; then
  CODEX_REPO=$(gh repo list "$GITHUB_ORG" --json name,nameWithOwner --limit 100 2>/dev/null | \
    jq -r '.[] | select(.name | test("^codex\\.")) | .nameWithOwner' | head -1)

  if [ -n "$CODEX_REPO" ]; then
    echo "$CODEX_REPO"
    exit 0
  fi
fi

# Failed to discover
echo "ERROR: Could not determine Codex repository" >&2
echo "Set CODEX_GITHUB_ORG and CODEX_GITHUB_REPO in .env or ensure repo follows codex.* naming" >&2
exit 1