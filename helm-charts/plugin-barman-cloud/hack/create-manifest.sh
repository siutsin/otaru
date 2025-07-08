#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

CRD_PATH="$SCRIPT_DIR/../templates"
CHART_PATH="$SCRIPT_DIR/.."
APP_VERSION=$(yq e '.appVersion' "${CHART_PATH}/Chart.yaml")
MANIFEST_URL="https://github.com/cloudnative-pg/plugin-barman-cloud/releases/download/${APP_VERSION}/manifest.yaml"

pushd "${CRD_PATH}" >/dev/null

yaml_content=$(curl -sL "${MANIFEST_URL}" | yq e 'select(.)')
echo "${yaml_content}" | yq --split-exp '.kind + "-" + (.metadata.name | sub("\.", "-")) + ".yaml" | downcase'

popd >/dev/null

echo "Created plugin-barman-cloud manifest"
