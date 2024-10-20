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

    depth=$(echo "$project_dir" | awk -F'/' '{print NF-1}')
    relative_module_path=$(printf '../%.0s' $(seq 1 "$depth"))"modules/**/*.tf"

    yq eval -i "
      .projects += [{
        \"name\": \"${project_dir}\",
        \"dir\": \"${project_dir}\",
        \"workspace\": \"terragrunt\",
        \"autoplan\": {
          \"enabled\": true,
          \"when_modified\": [\"${relative_module_path}\"]
        },
        \"workflow\": \"terragrunt\"
      }]
    " "${OUTPUT_FILE}"
done

echo "Atlantis configuration file '${OUTPUT_FILE}' generated successfully."
