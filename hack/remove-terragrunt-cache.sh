#!/bin/bash

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

# Default to current directory, but allow override
TARGET_DIR="${1:-.}"

log_info "Searching for .terragrunt-cache directories in: ${TARGET_DIR}"

# Count cache directories before removal
cache_count=$(find "${TARGET_DIR}" -type d -name '.terragrunt-cache' 2>/dev/null | wc -l)

if [ "$cache_count" -eq 0 ]; then
    log_warning "No .terragrunt-cache directories found."
    exit 0
fi

log_info "Found ${cache_count} .terragrunt-cache directory(ies) to remove..."

# Remove cache directories and capture any errors
removal_errors=$(find "${TARGET_DIR}" -type d -name '.terragrunt-cache' -exec rm -rf {} + 2>&1)

if [ -n "$removal_errors" ]; then
    log_warning "Some errors occurred during removal:"
    echo "$removal_errors"
else
    log_success "Successfully removed ${cache_count} .terragrunt-cache directory(ies)."
fi
