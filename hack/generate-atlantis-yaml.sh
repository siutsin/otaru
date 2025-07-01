#!/bin/bash

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

BASE_DIR="${1:-infrastructure}"
OUTPUT_FILE="${2:-atlantis.yaml}"

# Dependency checks
for dep in yq find; do
  if ! command_exists $dep; then
    exit_with_error "$dep is not installed or not in PATH"
  fi
done

# Check if base directory exists
if ! directory_exists "$BASE_DIR"; then
  exit_with_error "Base directory '$BASE_DIR' does not exist"
fi

log_info "Generating Atlantis configuration..."

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

log_success "Atlantis configuration file '${OUTPUT_FILE}' generated successfully."
