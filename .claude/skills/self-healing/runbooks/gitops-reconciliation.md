# GitOps Reconciliation

This cluster currently reconciles from Git via Argo CD. If that ever changes
(for example a FluxCD migration), update the commands below in place — the
category and its place in the investigation order do not need to change.

## Checks

- `kubectl -n argocd get applications.argoproj.io` — any `Degraded`,
  `Unknown`, or `OutOfSync`?
- For unhealthy apps, read sync status and recent events before acting.

## Triage

- `Degraded` or `Unknown` → P0; diagnose then GitOps-fix or escalate.
- `OutOfSync` for more than one hourly loop cycle with no in-flight PR →
  investigate drift; GitOps-fix when the live diff is wrong, otherwise
  escalate if sync needs prune/force.
- **`Unknown` + `fork/exec ... jsonnet: exec format error`:** the
  jsonnet CMP sidecar image may be arm64-only while the repo-server landed
  on amd64 (`nuc-00`). Prefer pinning `argocd.repoServer` to
  `kubernetes.io/arch: arm64` in GitOps (see recent journal / chart), not a
  force-sync.
- Before suggesting Application deletes or prune/force sync, check Helm
  chart / Application annotations for **sync waves** and prune behaviour.
  Destructive sync is escalate-only (`references/escalation.md`).
