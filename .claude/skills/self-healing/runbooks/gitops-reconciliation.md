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
- `OutOfSync` for more than one loop cycle (currently 30 minutes) with no
  in-flight PR → investigate drift; GitOps-fix when the live diff is wrong,
  otherwise escalate if sync needs prune/force.
- **`Progressing`:** do not treat "the current pod reached Ready" as proof
  the issue is resolved. A single point-in-time check cannot tell a
  one-off restart apart from a workload that is being repeatedly killed
  and just happens to be mid-recovery at the moment you looked. Before
  logging `Progressing` as a self-resolved transient, widen the events
  query beyond the exact pod name currently running — for example
  `kubectl get events -n <ns> --field-selector reason=HighNodeUtilization
  --sort-by='.lastTimestamp'` (or grep `kubectl get events -n <ns>` for
  the workload label/name prefix) — and look back further than "since
  this pod started." If several *different* pod names for the same
  workload were each evicted within the last hour, that is an ongoing
  incident, not a blip, even though every individual check would show
  the pod Ready a minute later. See `documentation/gotcha.md`
  ("Descheduler Eviction Storms Look Like Self-Resolving Blips, One
  Check At A Time") and `runbooks/workloads.md` for the underlying
  missing-PDB root cause and fix pattern.
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
- **`Degraded` persisting for hours after a one-off `CronJob`/`Job`
  failure, with every tracked resource in `status.resources[]` showing
  `health: None` and no `Job` object even present any more:** this can be
  a stale `status.health` field that never got recomputed after the
  failed Job was garbage-collected, not an ongoing problem. Confirm live
  (pods `Running`, no `Job` resource, `Heartbeat`/`ExternalSecret`/`PDB`/
  `VPA` all healthy) before treating the app-level field as ground truth
  — same category of lag as `attachedRoutes` in
  `runbooks/ingress-mesh.md`, but here the field can stay stuck well past
  the next successful reconcile (`status.reconciledAt` moving forward
  does not guarantee `status.health` gets re-evaluated). Observed on
  `teslamate` for 2+ hours after its daily `verify-pg-dump` Job failed
  and was cleaned up, 2026-08-25. No fix needed; a live protocol/resource
  check is the source of truth, not this field, in this specific case.
