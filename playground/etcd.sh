#!/bin/bash

set -euxo pipefail

NODE_MEMORY=2G
ETCD_DISK=4G
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

multipass launch --name etcd --network en0 --memory $NODE_MEMORY --disk $ETCD_DISK --cloud-init "$SCRIPT_DIR/init_etcd.yaml"
ETCD_IP=$(multipass info etcd --format json | jq -r '.info["etcd"].ipv4[1]')
echo "$ETCD_IP"

multipass transfer etcd:/home/ubuntu/ca.pem "$SCRIPT_DIR/../certs/"
multipass transfer etcd:/home/ubuntu/client.pem "$SCRIPT_DIR/../certs/"
multipass transfer etcd:/home/ubuntu/client-key.pem "$SCRIPT_DIR/../certs/"

# get all data in etcd
# etcdctl get "" --prefix=true

# wipe all data in etcd
# etcdctl del "" --prefix=true
