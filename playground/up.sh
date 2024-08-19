#!/bin/bash

set -euxo pipefail

NUM_MASTER_NODES=1
NUM_WORKER_NODES=3
NODE_MEMORY=2G
NODE_DISK=8G
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# clean up
kubectl config unset current-context
kubectl config delete-cluster playground || true
kubectl config delete-context playground || true
kubectl config delete-user playground || true
multipass delete --all --purge

# master nodes (only 1 for now)
for i in $(seq 0 $((NUM_MASTER_NODES - 1))); do
  MASTER_NODE=$(printf "master-%02d" "$i")
  multipass launch --name "$MASTER_NODE" --network en0 --memory $NODE_MEMORY --disk $NODE_DISK --cloud-init "$SCRIPT_DIR/init_master.yaml"
  MASTER_IP=$(multipass info "$MASTER_NODE" --format json | jq -r ".info[\"$MASTER_NODE\"].ipv4[1]")
  NODE_TOKEN=$(multipass exec "$MASTER_NODE" -- sudo cat /var/lib/rancher/k3s/server/node-token)
done

# worker nodes
sed "s/{{MASTER_IP}}/${MASTER_IP}/g; s/{{NODE_TOKEN}}/${NODE_TOKEN}/g" "$SCRIPT_DIR/init_worker_template.yaml" > "$SCRIPT_DIR/init_worker.yaml"
for i in $(seq 0 $((NUM_WORKER_NODES - 1))); do
  WORKER_NODE=$(printf "worker-%02d" "$i")
  multipass launch --verbose --name "$WORKER_NODE" --network en0 --memory $NODE_MEMORY --disk $NODE_DISK --cloud-init "$SCRIPT_DIR/init_worker.yaml" &
done

wait
rm -f "$SCRIPT_DIR/init_worker.yaml"

# setup kubeconfig
multipass exec "$MASTER_NODE" -- sudo cat /etc/rancher/k3s/k3s.yaml > "$SCRIPT_DIR/kubeconfig"
sed -i '' "s/127.0.0.1/$MASTER_IP/g" "$SCRIPT_DIR/kubeconfig"
sed -i '' "s/default/playground/g" "$SCRIPT_DIR/kubeconfig"
KUBECONFIG=~/.kube/config:$SCRIPT_DIR/kubeconfig kubectl config view --merge --flatten > "$SCRIPT_DIR/config"
mv "$SCRIPT_DIR/config" ~/.kube/config
chmod 600 ~/.kube/config
kubectl config set-context playground
