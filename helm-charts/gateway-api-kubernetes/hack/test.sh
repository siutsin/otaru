#!/bin/bash

set -euxo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CERT_PATH="$SCRIPT_DIR/certs"

mkdir -p "$CERT_PATH"

kubectl config view --minify --raw -o jsonpath='{.users[0].user.client-certificate-data}' | base64 --decode > "$CERT_PATH/client.crt"
kubectl config view --minify --raw -o jsonpath='{.users[0].user.client-key-data}' | base64 --decode > "$CERT_PATH/client.key"
kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode > "$CERT_PATH/ca.crt"

LOAD_BALANCER_API_SERVER=https://192.168.1.52

curl -vvvv -m 2 --cert "$CERT_PATH/client.crt" --key "$CERT_PATH/client.key" --cacert "$CERT_PATH/ca.crt" "$LOAD_BALANCER_API_SERVER/livez?verbose" || true

rm -rf "$CERT_PATH"
