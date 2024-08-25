#!/bin/bash

set -euxo pipefail

helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --set k8sServiceHost="$(multipass info master-00 --format json | jq -r '.info["master-00"].ipv4[1]')" \
  --set k8sServicePort=6443 \
  --set kubeProxyReplacement=true \
  --set operator.replicas=1
