#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

CRD_VERSION=$(yq -e '.appVersion' "$SCRIPT_DIR/../Chart.yaml")
CRD_URL="https://github.com/kubernetes-sigs/gateway-api/releases/download/v$CRD_VERSION/experimental-install.yaml"
CRD_PATH="$SCRIPT_DIR/../crds"

pushd "${CRD_PATH}" >/dev/null

echo "Downloading Gateway API CRDs from ${CRD_URL}."

# Fetch the YAML content from the URL and remove empty documents.
yaml_content=$(curl --silent --retry-all-errors --fail --location "${CRD_URL}" | yq e 'select(.)')

# Split objects into multiple files with normalized names.
echo "${yaml_content}" | yq --split-exp '.kind + "-" + (.metadata.name | sub("\.", "-")) + ".yaml" | downcase'

popd >/dev/null
