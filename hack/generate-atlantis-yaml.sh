#!/bin/sh

BASE_DIR="infrastructure"
OUTPUT_FILE="atlantis.yaml"

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
find "${BASE_DIR}" -type d -name ".terragrunt-cache" -prune -o -type f -name "terragrunt.hcl" ! -path "${BASE_DIR}/terragrunt.hcl" -print | while read -r terragrunt_path; do
    project_dir=$(dirname "$terragrunt_path")
    project_name=$(echo "$project_dir" | sed 's/\//-/g' | sed 's/^infrastructure-//')

    yq eval -i "
      .projects += [{
        \"name\": \"${project_name}\",
        \"dir\": \"${project_dir}\",
        \"workspace\": \"terragrunt\",
        \"autoplan\": {
          \"enabled\": true
        },
        \"workflow\": \"terragrunt\"
      }]
    " "${OUTPUT_FILE}"
done

echo "Atlantis configuration file '${OUTPUT_FILE}' generated successfully."
