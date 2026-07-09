# Storage

## Checks

- `kubectl get pvc -A` — any `Pending` or `Lost`?
- `kubectl -n longhorn-system get volumes.longhorn.io` — any `faulted` or
  `degraded`?
- Workloads stuck in `ContainerCreating` with `AttachVolume.Attach failed`
  and webhook errors mentioning `mutator.longhorn.io` /
  `validator.longhorn.io` — often ambient mesh on `longhorn-system` (see
  gotchas).

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
