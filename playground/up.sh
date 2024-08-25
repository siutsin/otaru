#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# Print each command and its expanded arguments before executing it.
# Treat unset variables as an error.
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euxo pipefail

# Configuration variables
NUM_MASTER_NODES=3
NUM_WORKER_NODES=1
NODE_MEMORY=2G
NODE_DISK=6G
ETCD_DISK=4G
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Clean up existing configurations and nodes
kubectl config unset current-context
kubectl config delete-cluster playground || true
kubectl config delete-context playground || true
kubectl config delete-user playground || true
multipass delete --all --purge

# Launch the external etcd node
multipass launch --name etcd --network en0 --memory $NODE_MEMORY --disk $ETCD_DISK --cloud-init "$SCRIPT_DIR/init_etcd.yaml"
ETCD_IP=$(multipass info etcd --format json | jq -r '.info["etcd"].ipv4[1]')

# Launch the first master node
# The first master node is critical as it will be used to generate the node token required by other master nodes.
# The etcd IP address is inserted into the cloud-init configuration before launching the node.
FIRST_MASTER_NODE="master-00"
sed "s/{{ETCD_IP}}/${ETCD_IP}/g" "$SCRIPT_DIR/init_first_master_template.yaml" > "$SCRIPT_DIR/init_master.yaml"
multipass launch --name $FIRST_MASTER_NODE --network en0 --memory $NODE_MEMORY --disk $NODE_DISK --cloud-init "$SCRIPT_DIR/init_master.yaml"
FIRST_MASTER_IP=$(multipass info $FIRST_MASTER_NODE --format json | jq -r ".info[\"$FIRST_MASTER_NODE\"].ipv4[1]")
NODE_TOKEN=$(multipass exec $FIRST_MASTER_NODE -- sudo cat /var/lib/rancher/k3s/server/node-token)

# Launch the remaining master nodes
sed "s/{{FIRST_MASTER_IP}}/${FIRST_MASTER_IP}/g; s/{{NODE_TOKEN}}/${NODE_TOKEN}/g; s/{{ETCD_IP}}/${ETCD_IP}/g" "$SCRIPT_DIR/init_other_master_template.yaml" > "$SCRIPT_DIR/init_master.yaml"
for i in $(seq 1 $((NUM_MASTER_NODES - 1))); do
  MASTER_NODE=$(printf "master-%02d" "$i")
  multipass launch --name "$MASTER_NODE" --network en0 --memory $NODE_MEMORY --disk $NODE_DISK --cloud-init "$SCRIPT_DIR/init_master.yaml" &
done

# Launch the worker nodes
sed "s/{{FIRST_MASTER_IP}}/${FIRST_MASTER_IP}/g; s/{{NODE_TOKEN}}/${NODE_TOKEN}/g" "$SCRIPT_DIR/init_worker_template.yaml" > "$SCRIPT_DIR/init_worker.yaml"
for i in $(seq 0 $((NUM_WORKER_NODES - 1))); do
  WORKER_NODE=$(printf "worker-%02d" "$i")
  multipass launch --verbose --name "$WORKER_NODE" --network en0 --memory $NODE_MEMORY --disk $NODE_DISK --cloud-init "$SCRIPT_DIR/init_worker.yaml" &
done

# Ensure all nodes are launched and clean up
wait
rm -f "$SCRIPT_DIR/init_worker.yaml" "$SCRIPT_DIR/init_master.yaml"

# Retrieves the kubeconfig from the first master node and updates it to use the first master node's IP address.
multipass exec "$FIRST_MASTER_NODE" -- sudo cat /etc/rancher/k3s/k3s.yaml > "$SCRIPT_DIR/kubeconfig"
sed -i '' "s/127.0.0.1/$FIRST_MASTER_IP/g" "$SCRIPT_DIR/kubeconfig"
sed -i '' "s/default/playground/g" "$SCRIPT_DIR/kubeconfig"
KUBECONFIG=~/.kube/config:$SCRIPT_DIR/kubeconfig kubectl config view --merge --flatten > "$SCRIPT_DIR/config"
mv "$SCRIPT_DIR/config" ~/.kube/config
chmod 600 ~/.kube/config
kubectl config set-context playground
rm -f "$SCRIPT_DIR/kubeconfig"

# Restart all instances
multipass restart --all
