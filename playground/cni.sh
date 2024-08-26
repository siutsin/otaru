#!/bin/bash

set -euxo pipefail

# clean up
#helm template helm-charts/cilium -n kube-system | kubectl delete -f - || true
#for crd in $(kubectl get crds -o jsonpath='{.items[?(@.spec.group=="cilium.io")].metadata.name}'); do
#  kubectl delete crd "$crd"
#done
#for crd in $(kubectl get crds -o jsonpath='{.items[?(@.spec.group=="gateway.networking.k8s.io")].metadata.name}'); do
#  kubectl delete crd "$crd"
#done

# Apply Gateway API CRDs
helm template helm-charts/gateway-api \
  -n kube-system \
  --include-crds \
  | kubectl create -f - 2>/dev/null || true

# Apply Cilium with the first master node's API server address
helm template helm-charts/cilium \
  -n kube-system \
  --set cilium.k8sServiceHost="$(multipass info master00 --format json | jq -r '.info["master00"].ipv4[1]')" \
  | kubectl create -f - 2>/dev/null || true

# Wait for the deployment to be successfully rolled out.
kubectl rollout status deploy/cilium-operator -n kube-system --timeout=15m
kubectl rollout status ds/cilium-envoy -n kube-system --timeout=15m
kubectl rollout status ds/cilium -n kube-system --timeout=15m
kubectl rollout status deploy/hubble-relay -n kube-system --timeout=15m
kubectl rollout status deploy/hubble-ui -n kube-system --timeout=15m

# Apply L2 announcement for HA Kubernetes api-server
helm template helm-charts/cilium-ha-k8s-api-server \
  -n kube-system \
  --set k8sApiServer.l2AnnouncementPolicy.interfaces='{enp0s2}' \
  | kubectl create -f - 2>/dev/null || true
