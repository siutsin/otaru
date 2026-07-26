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

## Known availability gotchas

- **Missing PDB on a single-replica workload → descheduler eviction
  storm.** A Deployment/StatefulSet with one replica and no
  PodDisruptionBudget (or a PDB with `minAvailable: 0`) has zero
  protection against `sigs.k8s.io/descheduler`'s `HighNodeUtilization`
  strategy, which can evict it every scan cycle (roughly every 5
  minutes on this cluster) whenever its node is over threshold — this
  cluster runs several nodes at 95%+ memory requested most of the time,
  so this is not a rare edge case. Symptoms: the workload's ArgoCD
  Application flips to `Progressing` repeatedly; each individual check
  shows the pod reaching Ready again within a minute, making it look
  like unrelated one-off blips rather than one ongoing incident (see
  `runbooks/gitops-reconciliation.md` → `Progressing`). A component
  that never gets to run long enough between evictions can show real
  symptoms beyond a health-status flap — e.g. prometheus-server
  returning live HTTP 503s because it never finished loading its TSDB
  before the next eviction.
  - **Detect:** `kubectl get pdb -n <ns>` — is the workload covered at
    all? `kubectl get events -n <ns> --field-selector
    reason=HighNodeUtilization --sort-by='.lastTimestamp'` — how many
    distinct pod names for this workload were evicted, and over what
    time span?
  - **Fix (trivial, GitOps):** add a PDB with `minAvailable: 1`. For a
    hand-written app chart using this repo's `.Values.name` /
    `.Values.namespace` convention, copy the template already used by
    `helm-charts/jung2bot/templates/pdb.yaml` (and umami,
    home-assistant, changedetection, openclaw, teslamate, unifi-mcp —
    all fixed for this exact issue on 2026-07-25, PRs #2917-#2919). For
    a bundled third-party subchart, check its own values schema first
    (`helm show values <chart> --version <pinned>` or the vendored
    chart cache) — many prometheus-community / grafana charts expose a
    native `podDisruptionBudget.enabled` / `minAvailable` key, which is
    the correct fix instead of hand-writing a template (see
    `helm-charts/monitoring/values.yaml`'s `prometheus.server` block,
    PR #2922).
  - **Not a candidate for this fix:** vendored/generated operator
    manifests (helmify-style, hardcoded labels, no `.Values.name`
    convention) and anything serving live shared-cluster traffic where
    an eviction mid-operation has a different risk profile (e.g. a CNPG
    backup plugin mid-backup) — these need a case-by-case decision, not
    the same-day automated fix. `heartbeats`,
    `k3s-apiserver-loadbalancer`, and
    `cloudnative-pg-plugin-barman-cloud` were identified with this same
    gap and deliberately left unpatched for that reason.
  - This is now a recurring-enough pattern to spot-check on any
    `Progressing` finding, not just wait for a report.

- **VPA-driven resource changes are expected, not an incident.**
  `helm-charts/vpa/` runs a live admission-controller and updater for a
  growing set of workloads (`kubectl get vpa -A` lists them). A pod whose
  `resources.requests`/`limits` differ from its chart's declared values, or
  that shows a restart with no other explanation, may simply be VPA applying
  a recommendation (`InPlaceOrRecreate` resizes live with no restart when the
  kubelet supports it; it falls back to a normal pod recreate otherwise).
  Check `kubectl get vpa -n <namespace>` before treating this as drift or an
  issue. See `.claude/skills/right-sizing/SKILL.md` **VPA-managed workloads**
  for how these are configured and vetted.

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
