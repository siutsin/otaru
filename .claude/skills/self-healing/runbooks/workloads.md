# Workloads

## Checks

- `kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded`
- Scan `kubectl get pods -A -o wide` (grep or read the table) for
  `CrashLoopBackOff`, `ImagePullBackOff`, `ErrImagePull`,
  `CreateContainerConfigError`, or high `RESTARTS` — phase `Running` hides
  these from the field-selector above.
- `kubectl get deploy,sts,ds -A` — not fully available?
- **Jobs:** `kubectl get jobs -A` — any `Failed` or `Running` beyond
  expected duration?
- **Alerts:** `curl -s <prometheus-url-via-ingress>/api/v1/alerts` (same
  URL resolution as `right-sizing`'s KRR step) — any `firing` alerts. A
  pod stuck `CrashLoopBackOff` still reports phase `Running` and can look
  fine at a glance if this step is skipped, especially on an abbreviated
  hourly check; run it every pass, not just on a full sweep.

## Triage

- Owned `CrashLoopBackOff` pod → allowlisted delete (see
  `runbooks/merge-policy.md` for what counts as a safe live action).
- `ImagePullBackOff` / `ErrImagePull` → GitOps-fix public image tags or
  digests only. Registry auth / `imagePullSecrets` / pull-secret failures
  → **escalate** (do not dump Secret YAML; see journal redaction rules).
- Failed one-off Job → delete only after confirming it is not a backup or
  CronJob child (see `runbooks/merge-policy.md` and
  `references/escalation.md`).
- CronJob or backup Job failures → GitOps-fix or escalate.
- Pod `Pending` with `Insufficient memory` on every node, even when
  `kubectl describe node` shows real free memory somewhere: check every
  container's request in the pod spec (multi-container pods must fit
  entirely on one node) before assuming a real capacity shortfall — this
  cluster runs a paired descheduler `HighNodeUtilization` +
  kube-scheduler `MostAllocated` fix for exactly this scattered-memory
  case. See `documentation/gotcha.md` ("Multi-Container Pods Fail to
  Schedule Despite \"Enough\" Free Cluster Memory").
- Pod `Pending` with `Insufficient memory` on **every node of one
  architecture** while a node of the other architecture (`nuc-00`,
  amd64) sits well under capacity: check `kubectl get pod -o
  jsonpath='{.spec.nodeSelector}'` for a `kubernetes.io/arch` pin before
  treating this as a real capacity shortfall — it may be an
  architecture pin that only exists because of a mispinned single-arch
  digest, not a genuine constraint. See `documentation/gotcha.md` ("A
  Pinned Digest Can Silently Be Single-Arch, Not Multi-Arch" →
  "Recurrence"). If the arch pool genuinely is full and the pin is
  legitimate (or a fix is out of scope for this pass), a safe live
  remediation is evicting one redundant pod from a same-pool node with
  PDB headroom (multi-replica Deployment, `kubectl get pdb` allows the
  disruption) to free enough room — it will reschedule on its own.

## Known data-durability gotchas

- **changedetection watch list wipe:** pinning
  `ghcr.io/dgtlmoon/changedetection.io:latest@sha256:...` allows mutable
  `latest` + migrations (or a volume reformat) to reseed defaults. Longhorn
  backup for `changedetection-vol` has been weekly with `retain: 1`, so a
  bad state can overwrite the only restore point within a week. Prefer
  concrete version tags; escalate restore; treat watch data as
  low-durability until retention is deepened. See `documentation/gotcha.md`.
- **`latest` / floating tags on stateful apps:** when diagnosing sudden
  empty config or default data after a restart, check for floating tags
  and thin backup retention before assuming app logic alone failed.
