#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

CRD_PATH="$SCRIPT_DIR/../templates"

LATEST_TAG=$(curl -sL "https://api.github.com/repos/siutsin/heartbeats/releases/latest" | jq -r '.tag_name')

if [ -z "${LATEST_TAG}" ] || [ "${LATEST_TAG}" = "null" ]; then
  echo "Error: Failed to get latest release tag" >&2
  exit 1
fi

echo "Using latest release: ${LATEST_TAG}"

MANIFEST_URL="https://github.com/siutsin/heartbeats/releases/download/${LATEST_TAG}/install.yaml"

pushd "${CRD_PATH}" >/dev/null

# Split filenames come from kind/name, so drop docs without both: a stray
# doc otherwise becomes templates/-.yaml and breaks helm lint.
yaml_content=$(curl -sL --fail "${MANIFEST_URL}" | yq e 'select(.kind != null and .metadata.name != null)')
echo "${yaml_content}" | yq --split-exp '.kind + "-" + (.metadata.name | sub("\.", "-")) + ".yaml" | downcase'

popd >/dev/null

DEPLOYMENT_FILE="${CRD_PATH}/deployment-heartbeats-operator-controller-manager.yaml"

if [[ -f "${DEPLOYMENT_FILE}" ]]; then
  yq -i '
    (.spec.template.spec.containers[] | select(.name == "manager").resources.requests.memory) = "32Mi"
  ' "${DEPLOYMENT_FILE}"
fi

echo "Created heartbeats manifest"
