#!/bin/bash

set -euxo pipefail

# clean up
helm uninstall gateway-api-kubernetes -n default || true
helm uninstall gateway-api-routes -n kube-system || true
helm uninstall cilium -n kube-system || true
helm uninstall gateway-api -n kube-system || true

kubectl rollout status deploy/cilium-operator -n kube-system --timeout=15m || true
kubectl rollout status ds/cilium-envoy -n kube-system --timeout=15m || true
kubectl rollout status ds/cilium -n kube-system --timeout=15m || true
kubectl rollout status deploy/hubble-relay -n kube-system --timeout=15m || true
kubectl rollout status deploy/hubble-ui -n kube-system --timeout=15m || true

for crd in $(kubectl get crds -o jsonpath='{.items[?(@.spec.group=="cilium.io")].metadata.name}'); do
  kubectl delete crd "$crd"
done
for crd in $(kubectl get crds -o jsonpath='{.items[?(@.spec.group=="gateway.networking.k8s.io")].metadata.name}'); do
  kubectl delete crd "$crd"
done
