#!/bin/bash
# Version Validation Script for FinixTapToPaySDK
# Ensures that the version in code matches the git tag

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the version from SDKMetadata.swift
SDK_FILE="FinixTapToPaySDK/Internal/SDKMetadata.swift"
CODE_VERSION=$(grep -E '^\s*static let version = "' "$SDK_FILE" | sed -E 's/.*"(.*)".*/\1/')

if [ -z "$CODE_VERSION" ]; then
    echo -e "${RED}❌ Error: Could not find version in $SDK_FILE${NC}"
    echo "Expected format: static let version = \"x.y.z\""
    exit 1
fi

echo "Code version: $CODE_VERSION"

# Check if we're validating against a git tag
if [ -n "$1" ]; then
    # Tag provided as argument (for CI)
    GIT_TAG="$1"
    # Remove 'v' prefix if present (e.g., v1.0.0 -> 1.0.0)
    GIT_VERSION="${GIT_TAG#v}"

    echo "Git tag: $GIT_TAG"
    echo "Git version: $GIT_VERSION"

    if [ "$CODE_VERSION" != "$GIT_VERSION" ]; then
        echo -e "${RED}❌ Version mismatch!${NC}"
        echo -e "  Code version: ${YELLOW}$CODE_VERSION${NC}"
        echo -e "  Git tag:      ${YELLOW}$GIT_VERSION${NC}"
        echo ""
        echo "Please update the version in $SDK_FILE to match the git tag."
        exit 1
    fi

    echo -e "${GREEN}✅ Version matches git tag ($CODE_VERSION)${NC}"
else
    # No tag provided - just show current version
    echo -e "${GREEN}✅ Current SDK version: $CODE_VERSION${NC}"
    echo ""
    echo "To create a release:"
    echo "  1. Update version in FinixTapToPaySDK/Internal/SDKMetadata.swift"
    echo "  2. Commit: git commit -m \"Bump version to $CODE_VERSION\""
    echo "  3. Tag: git tag v$CODE_VERSION"
    echo "  4. Push: git push origin main --tags"
fi
