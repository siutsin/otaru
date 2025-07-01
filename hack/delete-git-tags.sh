#!/bin/bash

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

# Check for git
if ! command_exists git; then
    exit_with_error "git is not installed or not in PATH"
fi

# Check if inside a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    exit_with_error "Not inside a git repository"
fi

# Confirmation prompt
confirm_action "WARNING: This will delete ALL Git tags locally and remotely! Type DELETE ALL TAGS to continue: " "DELETE ALL TAGS"

git fetch --tags

# Get tag list
TAGS=$(git tag -l)
if [ -z "$TAGS" ]; then
    log_warning "No tags found to delete."
    exit 0
fi

# Delete all remote tags
log_info "Deleting all remote tags..."
FAILED_TAGS=""
for tag in $TAGS; do
  if ! git push origin --delete refs/tags/$tag; then
    FAILED_TAGS="$FAILED_TAGS $tag"
  fi
done

if [ -n "$FAILED_TAGS" ]; then
  log_error "Failed to delete the following remote tags:$FAILED_TAGS"
else
  log_success "All remote tags deleted successfully."
fi

# Delete all local tags
log_info "Deleting all local tags..."
echo "$TAGS" | xargs -r git tag -d

log_success "All tags have been deleted locally and remotely."
