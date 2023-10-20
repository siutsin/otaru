#!/usr/bin/env bash

set -euxo pipefail

for dir in helm-charts/*; do
  if [ -d "$dir" ]; then
    helm dep update "$dir"
  fi
done

# Create Namespaces
helm upgrade --install namespaces helm-charts/namespaces -n default --wait --timeout 1m

# Init istio for sidecar injection
helm template helm-charts/istio-base -n istio-system | kubectl create -f - 2>/dev/null || true
helm template helm-charts/istiod -n istio-system | kubectl create -f - 2>/dev/null || true
kubectl rollout status deploy/istiod -n istio-system --timeout=15m
kubectl rollout restart deploy/prometheus -n istio-system
kubectl rollout restart deploy/jaeger -n istio-system

## Init Argo CD
helm upgrade --install argocd helm-charts/argocd -n argocd --wait --timeout 15m

## Init 1Password Secret Operator
helm upgrade --install onepassword-connect helm-charts/onepassword-connect \
  -n onepassword \
  --set-file connect.connect.credentials=1password-credentials.json \
  --wait --timeout 15m

## Create Secret for `onepassword-connect`
kubectl create secret generic onepassword-connect-token -n external-secrets --from-literal=token="$(tr -d '\n' < token)" 2>/dev/null || true

## Bootstrap
helm upgrade --install argocd-bootstrap helm-charts/argocd-bootstrap -n argocd --wait --timeout 1m
