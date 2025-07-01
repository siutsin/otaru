#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

CRD_PATH="$SCRIPT_DIR/../templates"
MANIFEST_URL="https://github.com/siutsin/heartbeats/raw/refs/heads/master/dist/install.yaml"

pushd "${CRD_PATH}" >/dev/null

yaml_content=$(curl -sL "${MANIFEST_URL}" | yq e 'select(.)')
echo "${yaml_content}" | yq --split-exp '.kind + "-" + (.metadata.name | sub("\.", "-")) + ".yaml" | downcase'

popd >/dev/null

echo "Created heartbeats manifest"
