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

find "${CRD_PATH}" "${TEMPLATE_PATH}" -maxdepth 1 -type f -name '*.yaml' -exec rm -f {} +

pushd "${CRD_PATH}" >/dev/null
echo "${yaml_content}" | yq e 'select(.kind == "CustomResourceDefinition")' | yq --split-exp '.kind + "-" + (.metadata.name | sub("\.", "-")) + ".yaml" | downcase'
popd >/dev/null

pushd "${TEMPLATE_PATH}" >/dev/null
echo "${yaml_content}" | yq e 'select(.kind != "CustomResourceDefinition")' | yq --split-exp '.kind + "-" + (.metadata.name | sub("\.", "-")) + ".yaml" | downcase'
popd >/dev/null

# The apiserver defaults these fields, and Argo CD already owns the live
# defaults in this cluster. Keep the generated templates explicit so setup's
# server-side apply can co-own the fields instead of conflicting with Argo.
POLICY_FILE="${TEMPLATE_PATH}/validatingadmissionpolicy-safe-upgrades-gateway-networking-k8s-io.yaml"
POLICY_BINDING_FILE="${TEMPLATE_PATH}/validatingadmissionpolicybinding-safe-upgrades-gateway-networking-k8s-io.yaml"

if [[ -f "${POLICY_FILE}" ]]; then
  yq -i '
    .spec.matchConstraints.matchPolicy = "Equivalent" |
    .spec.matchConstraints.namespaceSelector = {} |
    .spec.matchConstraints.objectSelector = {} |
    .spec.matchConstraints.resourceRules[].scope = "*"
  ' "${POLICY_FILE}"
fi

if [[ -f "${POLICY_BINDING_FILE}" ]]; then
  yq -i '
    .spec.matchResources.matchPolicy = "Equivalent" |
    .spec.matchResources.namespaceSelector = {} |
    .spec.matchResources.objectSelector = {} |
    .spec.matchResources.resourceRules[].scope = "*"
  ' "${POLICY_BINDING_FILE}"
fi
