#!/bin/bash

# Format only modified Swift files
cd "$(dirname "${BASH_SOURCE[0]}")/.."

MODIFIED_FILES=$(git diff --name-only --diff-filter=ACMR | grep -E "\.swift$")

if [ -z "$MODIFIED_FILES" ]; then
  echo "No modified Swift files found."
  exit 0
fi

echo "$MODIFIED_FILES" | xargs ./bin/swiftformat
