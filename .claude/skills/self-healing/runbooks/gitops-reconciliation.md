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
- **`Unknown` + `fork/exec ... jsonnet: exec format error`:** almost
  certainly a mispinned single-arch digest on the jsonnet CMP sidecar
  image, not a genuine arch limitation — see `documentation/gotcha.md`
  ("A Pinned Digest Can Silently Be Single-Arch, Not Multi-Arch" →
  "Recurrence: Forced Architecture Pins Masking the Same Bug"). Verify
  and re-pin to the multi-arch index digest; do **not** add a
  `kubernetes.io/arch` nodeSelector as the fix — that masks the bug and
  can itself cause stuck-`Pending` rollouts once that architecture's
  nodes fill up (same doc entry, 2026-07-18 incident).
- Before suggesting Application deletes or prune/force sync, check Helm
  chart / Application annotations for **sync waves** and prune behaviour.
  Destructive sync is escalate-only (`references/escalation.md`).
