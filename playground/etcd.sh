#!/bin/bash

set -euxo pipefail

NODE_MEMORY=2G
ETCD_DISK=4G
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
OTARU_SECRETS_DIR="${OTARU_SECRETS_DIR:-$HOME/dotfiles/secrets/otaru}"
OTARU_ETCD_SECRETS_DIR="${OTARU_ETCD_SECRETS_DIR:-$OTARU_SECRETS_DIR/etcd}"

multipass launch --name etcd --network en0 --memory $NODE_MEMORY --disk $ETCD_DISK --cloud-init "$SCRIPT_DIR/init_etcd.yaml"
ETCD_IP=$(multipass info etcd --format json | jq -r '.info["etcd"].ipv4[1]')
echo "$ETCD_IP"

mkdir -p "$OTARU_ETCD_SECRETS_DIR"
multipass transfer etcd:/home/ubuntu/ca.pem "$OTARU_ETCD_SECRETS_DIR/"
multipass transfer etcd:/home/ubuntu/client.pem "$OTARU_ETCD_SECRETS_DIR/"
multipass transfer etcd:/home/ubuntu/client-key.pem "$OTARU_ETCD_SECRETS_DIR/"

# get all data in etcd
# etcdctl get "" --prefix=true

# wipe all data in etcd
# etcdctl del "" --prefix=true
