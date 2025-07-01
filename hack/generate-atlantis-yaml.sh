#!/bin/bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BASE_DIR="${1:-infrastructure}"
OUTPUT_FILE="${2:-atlantis.yaml}"

# Dependency checks
for dep in yq find; do
  if ! command -v $dep >/dev/null 2>&1; then
    echo -e "${RED}Error: $dep is not installed or not in PATH${NC}"
    exit 1
  fi
done

# Check if base directory exists
if [ ! -d "$BASE_DIR" ]; then
  echo -e "${RED}Error: Base directory '$BASE_DIR' does not exist${NC}"
  exit 1
fi

echo -e "${GREEN}Generating Atlantis configuration...${NC}"

cat <<EOF > "${OUTPUT_FILE}"
# This file is generated automatically by running 'make generate-atlantis-yaml'. Do not modify manually.

version: 3
automerge: true
parallel_plan: true
parallel_apply: false
projects: []
workflows:
  terragrunt:
    plan:
      steps:
        - env:
            name: TF_IN_AUTOMATION
            value: 'true'
        - run: find . -name '.terragrunt-cache' | xargs rm -rf
        - run: terragrunt init -reconfigure
        - run:
            command: terragrunt plan -input=false -out=\$PLANFILE
            output: strip_refreshing
    apply:
      steps:
        - run: terragrunt apply \$PLANFILE
EOF

# Find all occurrences of terragrunt.hcl in the infrastructure folder, excluding .terragrunt-cache and base directory file
find "$BASE_DIR" -type d -name ".terragrunt-cache" -prune -o -type f -name "terragrunt.hcl" ! -path "$BASE_DIR/terragrunt.hcl" -print | while read -r terragrunt_path; do
    project_dir=$(dirname "$terragrunt_path")

    yq eval -i "
      .projects += [{
        \"name\": \"${project_dir}\",
        \"dir\": \"${project_dir}\",
        \"workspace\": \"terragrunt\",
        \"autoplan\": {
          \"enabled\": true
        },
        \"workflow\": \"terragrunt\"
      }]
    " "${OUTPUT_FILE}"
done

echo -e "${GREEN}Atlantis configuration file '${OUTPUT_FILE}' generated successfully.${NC}"
