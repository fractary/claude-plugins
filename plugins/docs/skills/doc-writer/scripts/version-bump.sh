#!/bin/bash
# version-bump.sh - Increment semantic version
# Usage: version-bump.sh <current_version> [major|minor|patch]

set -euo pipefail

CURRENT_VERSION="$1"
BUMP_TYPE="${2:-patch}"  # Default to patch

# Validate version format (MAJOR.MINOR.PATCH)
if ! [[ "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid version format: $CURRENT_VERSION" >&2
    echo "Expected: MAJOR.MINOR.PATCH (e.g., 1.0.0)" >&2
    exit 1
fi

# Split version into components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Bump according to type
case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "Error: Invalid bump type: $BUMP_TYPE" >&2
        echo "Valid types: major, minor, patch" >&2
        exit 1
        ;;
esac

# Output new version
echo "${MAJOR}.${MINOR}.${PATCH}"
