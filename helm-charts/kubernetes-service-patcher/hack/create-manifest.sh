#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

MANIFEST_PATH="$SCRIPT_DIR/../../../applications/kubernetes-service-patcher/dist/install.yaml"
CRD_PATH="$SCRIPT_DIR/../templates"

pushd "${CRD_PATH}" >/dev/null

yaml_content=$(yq e 'select(.)' < "$MANIFEST_PATH")
echo "${yaml_content}" | yq --split-exp '.kind + "-" + (.metadata.name | sub("\.", "-")) + ".yaml" | downcase'

popd >/dev/null

echo "Created kubernetes-service-patcher manifest"
