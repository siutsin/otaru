#!/bin/bash

set -euo pipefail

# Default to current directory, but allow override
TARGET_DIR="${1:-.}"

echo "Searching for .terragrunt-cache directories in: ${TARGET_DIR}"

# Count cache directories before removal
cache_count=$(find "${TARGET_DIR}" -type d -name '.terragrunt-cache' 2>/dev/null | wc -l)

if [ "$cache_count" -eq 0 ]; then
    echo "No .terragrunt-cache directories found."
    exit 0
fi

echo "Found ${cache_count} .terragrunt-cache directory(ies) to remove..."

# Remove cache directories
find "${TARGET_DIR}" -type d -name '.terragrunt-cache' -exec rm -rf {} + 2>/dev/null

echo "Successfully removed ${cache_count} .terragrunt-cache directory(ies)."
