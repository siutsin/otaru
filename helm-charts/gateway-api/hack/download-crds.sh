#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

CRD_VERSION=$(yq -e '.appVersion' "$SCRIPT_DIR/../Chart.yaml")
CRD_URL="https://github.com/kubernetes-sigs/gateway-api/releases/download/v$CRD_VERSION/experimental-install.yaml"
CRD_PATH="$SCRIPT_DIR/../crds"
TEMPLATE_PATH="$SCRIPT_DIR/../templates"

mkdir -p "${CRD_PATH}" "${TEMPLATE_PATH}"

echo "Downloading Gateway API CRDs from ${CRD_URL}."

# Fetch the YAML content from the URL and remove empty documents.
yaml_content=$(curl --silent --retry-all-errors --fail --location "${CRD_URL}" | yq e 'select(.)')

pushd "${CRD_PATH}" >/dev/null
echo "${yaml_content}" | yq e 'select(.kind == "CustomResourceDefinition")' | yq --split-exp '.kind + "-" + (.metadata.name | sub("\.", "-")) + ".yaml" | downcase'
popd >/dev/null

pushd "${TEMPLATE_PATH}" >/dev/null
echo "${yaml_content}" | yq e 'select(.kind != "CustomResourceDefinition")' | yq --split-exp '.kind + "-" + (.metadata.name | sub("\.", "-")) + ".yaml" | downcase'
popd >/dev/null
