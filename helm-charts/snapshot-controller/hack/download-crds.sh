#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SNAPSHOTTER_VERSION=$(yq -e '.appVersion' "$SCRIPT_DIR/../Chart.yaml")
CRD_BASE_URL="https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/${SNAPSHOTTER_VERSION}/client/config/crd"
CRD_PATH="$SCRIPT_DIR/../crds"

mkdir -p "$CRD_PATH"

for crd in \
  snapshot.storage.k8s.io_volumesnapshotclasses.yaml \
  snapshot.storage.k8s.io_volumesnapshotcontents.yaml \
  snapshot.storage.k8s.io_volumesnapshots.yaml; do
  curl --silent --show-error --retry-all-errors --fail --location "${CRD_BASE_URL}/${crd}" \
    | yq e 'select(.)' - > "$CRD_PATH/$crd"
done
