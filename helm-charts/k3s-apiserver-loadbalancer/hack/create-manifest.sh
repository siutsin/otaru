#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

CRD_PATH="$SCRIPT_DIR/../templates"

LATEST_TAG=$(curl -sL "https://api.github.com/repos/siutsin/k3s-apiserver-loadbalancer/releases/latest" | jq -r '.tag_name')

if [ -z "${LATEST_TAG}" ] || [ "${LATEST_TAG}" = "null" ]; then
  echo "Error: Failed to get latest release tag" >&2
  exit 1
fi

echo "Using latest release: ${LATEST_TAG}"

MANIFEST_URL="https://github.com/siutsin/k3s-apiserver-loadbalancer/releases/download/${LATEST_TAG}/install.yaml"

pushd "${CRD_PATH}" >/dev/null

yaml_content=$(curl -sL "${MANIFEST_URL}" | yq e 'select(.)')
echo "${yaml_content}" | yq --split-exp '.kind + "-" + (.metadata.name | sub("\.", "-")) + ".yaml" | downcase'

popd >/dev/null

echo "Created k3s-apiserver-loadbalancer manifest"
