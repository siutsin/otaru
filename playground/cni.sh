#!/bin/bash

set -euxo pipefail

helm install cilium cilium/cilium \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$(multipass info master-00 --format json | jq -r '.info["master-00"].ipv4[1]')"
