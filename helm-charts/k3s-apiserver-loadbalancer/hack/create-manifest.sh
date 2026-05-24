#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

CRD_PATH="$SCRIPT_DIR/../templates"

LATEST_TAG=$(curl -sL "https://api.github.com/repos/siutsin/k3s-apiserver-loadbalancer/releases/latest" | jq -r '.tag_name')
export LATEST_TAG

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

DEPLOYMENT_FILE="${CRD_PATH}/deployment-k3s-apiserver-loadbalancer-controller-manager.yaml"
NAMESPACE_FILE="${CRD_PATH}/namespace-k3s-apiserver-loadbalancer-system.yaml"
SERVICE_FILE="${CRD_PATH}/service-k3s-apiserver-loadbalancer-controller-manager-metrics-service.yaml"

if [[ -f "${DEPLOYMENT_FILE}" ]]; then
  yq -i '
    .metadata.labels."app.kubernetes.io/version" = strenv(LATEST_TAG) |
    .spec.template.metadata.labels."app.kubernetes.io/version" = strenv(LATEST_TAG) |
    del(.spec.template.spec.containers[] | select(.name == "manager").resources.limits.cpu) |
    (.spec.template.spec.containers[] | select(.name == "manager").resources.limits.memory) = "128Mi" |
    (.spec.template.spec.containers[] | select(.name == "manager").resources.limits."ephemeral-storage") = "64Mi" |
    (.spec.template.spec.containers[] | select(.name == "manager").resources.requests.cpu) = "10m" |
    (.spec.template.spec.containers[] | select(.name == "manager").resources.requests.memory) = "128Mi" |
    (.spec.template.spec.containers[] | select(.name == "manager").resources.requests."ephemeral-storage") = "64Mi"
  ' "${DEPLOYMENT_FILE}"
fi

if [[ -f "${NAMESPACE_FILE}" ]]; then
  yq -i '
    .metadata.annotations."argocd.argoproj.io/sync-options" = "Delete=false,Prune=false" |
    .metadata.labels."app.kubernetes.io/version" = strenv(LATEST_TAG) |
    .metadata.labels."istio.io/dataplane-mode" = "ambient" |
    .metadata.labels."istio.io/use-waypoint" = "waypoint" |
    .metadata.labels."istio.io/use-waypoint-namespace" = "istio-waypoints" |
    .metadata.labels."istio.io/ingress-use-waypoint" = "true"
  ' "${NAMESPACE_FILE}"
fi

if [[ -f "${SERVICE_FILE}" ]]; then
  yq -i '
    .metadata.labels."app.kubernetes.io/version" = strenv(LATEST_TAG)
  ' "${SERVICE_FILE}"
fi

echo "Created k3s-apiserver-loadbalancer manifest"
