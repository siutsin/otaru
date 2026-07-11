# Storage

## Checks

- `kubectl get pvc -A` — any `Pending` or `Lost`?
- `kubectl -n longhorn-system get volumes.longhorn.io` — any `faulted` or
  `degraded`?
- Workloads stuck in `ContainerCreating` with `AttachVolume.Attach failed`
  and webhook errors mentioning `mutator.longhorn.io` /
  `validator.longhorn.io` — often ambient mesh on `longhorn-system` (see
  gotchas).
- **Node disk over-provisioning:** `kubectl get nodes.longhorn.io <node> -n
  longhorn-system -o json` → `.status.diskStatus.<disk>.scheduledReplica`
  (sum the values) vs `.storageMaximum` minus the disk's
  `storageReserved`. A new replica failing to schedule
  (`longhorn.io/volume-scheduling-error` on the PV, or a
  `FailedScheduling`/"Scheduling space condition failed" event) with real
  free bytes still available (`storageAvailable`) means the *declared*
  sizes already scheduled there exceed the allowed limit — not an actually
  full disk.

## Triage

- Read `documentation/gotcha.md` before acting on Longhorn.
- `Pending` PVC → check events; GitOps storage-class or quota fix, or
  escalate.
- `faulted` / `degraded` volume → journal and **escalate** unless
  `documentation/gotcha.md` documents a safe rollout restart only (no
  volume delete, no crypto change).
- **Ambient on Longhorn:** `longhorn-system` must stay outside ambient
  (`ambient: false` in `helm-charts/namespaces/values.yaml`). If labels
  drifted on, escalate label cleanup + manager restart — do not delete
  volumes. See `documentation/gotcha.md`.
- **Volume stuck `deleting`:** webhook/validation blocks are documented in
  `documentation/gotcha.md`. Removing webhook rules and force-deleting
  volumes is **always escalate** (data loss).
- **Encrypted volume space not reclaimed after delete/trim:** missing
  dm-crypt `allow-discards`; recovery is `make trim` / `make maintenance`,
  not a privileged always-on DaemonSet. Escalate; do not reintroduce
  `cypto-volume-allow-discards`. See `documentation/gotcha.md`.
- **Moving a single-replica volume off an over-provisioned node** (only
  with user approval — this is a live storage mutation): patch
  `spec.evictionRequested: true` on the Replica CR on the node to vacate
  (`kubectl patch replicas.longhorn.io <replica> -n longhorn-system --type
  merge -p '{"spec":{"evictionRequested":true}}'`). Longhorn schedules a
  new replica elsewhere and rebuilds; confirm via the volume's Engine
  `status.replicaModeMap` that the new replica reached `RW` before
  treating the source as replaceable — `evictionRequested` can reset to
  `false` on its own once the rebuild completes without Longhorn actually
  deleting the source replica object, so a manual `kubectl delete
  replicas.longhorn.io <old-replica>` may still be needed to finish
  vacating it. The consuming pod does not need to restart.
- **Faulted single-replica volume with zero live replicas:** eviction
  needs a live source and does not apply. Check
  `auto-salvage` (`kubectl get settings.longhorn.io auto-salvage -n
  longhorn-system`) and the longhorn-manager logs for that volume name —
  `"Bringing up 0 replicas for auto-salvage"` means Longhorn itself
  found nothing recoverable at that attempt. Re-check current
  `status.robustness` before concluding data loss: a replica that failed
  from node disk pressure (not corruption) can self-recover on a later
  attempt with `salvageExecuted: false` — a stale single reading is not
  proof of permanent loss. If it stays faulted, a completed backup
  (`kubectl get backups.longhorn.io -n longhorn-system`) is the escalation
  path, not a forced restart of the dead replica.
