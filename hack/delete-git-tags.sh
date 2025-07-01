#!/bin/bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for git
if ! command -v git >/dev/null 2>&1; then
    echo -e "${RED}Error: git is not installed or not in PATH${NC}"
    exit 1
fi

# Check if inside a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}Error: Not inside a git repository${NC}"
    exit 1
fi

# Confirmation prompt
read -p $'\033[0;31mWARNING: This will delete ALL Git tags locally and remotely!\033[0m\nType DELETE ALL TAGS to continue: ' confirm
if [[ "$confirm" != "DELETE ALL TAGS" ]]; then
    echo -e "${YELLOW}Aborted by user.${NC}"
    exit 0
fi

git fetch --tags

# Get tag list
TAGS=$(git tag -l)
if [ -z "$TAGS" ]; then
    echo -e "${YELLOW}No tags found to delete.${NC}"
    exit 0
fi

# Delete all remote tags
echo -e "${YELLOW}Deleting all remote tags...${NC}"
for tag in $TAGS; do
  git push origin --delete refs/tags/$tag || true
done

# Delete all local tags
echo -e "${YELLOW}Deleting all local tags...${NC}"
echo "$TAGS" | xargs -r git tag -d

echo -e "${GREEN}All tags have been deleted locally and remotely.${NC}"
