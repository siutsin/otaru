# Platform

## Checks

- `kubectl get certificates -A` — any not `Ready`?
- `kubectl get apiservice` — metrics or HPA / external-metrics APIs
  unavailable?
  - `v1beta1.metrics.k8s.io` (metrics-server)
  - `v1beta1.external.metrics.k8s.io` (KEDA, when installed)

## Triage

- Certificate `Issuing` or a recent event → wait one cycle, re-check.
- Certificate stuck `not Ready` beyond one cycle → GitOps-fix the
  `Certificate` or issuer config, or escalate if DNS/LUKS/secret rotation
  is involved.
- **APIService `FailedDiscoveryCheck` / EOF to pod IPs** while adapter pods
  look Running: often ambient redirection on kube-apiserver → aggregated
  API paths.
  - metrics-server: pods in `monitoring` must keep
    `istio.io/dataplane-mode: none` (chart values); GitOps-fix or
    escalate a rollout restart after label fix.
  - KEDA: `keda` namespace must stay `ambient: false`.
  - Full symptom/resolution detail: `documentation/gotcha.md`.
