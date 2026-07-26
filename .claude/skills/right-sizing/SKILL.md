---
name: "right-sizing"
description: >-
  Right-size otaru workloads via KRR (CPU/memory) and Prometheus ephemeral-storage
  metrics. Read incident comments as guardrails, apply downsizes and upsizes in one
  GitOps PR, verify rollout. Also covers VPA (helm-charts/vpa), a complementary
  automated path for steady-state workloads with no spike pattern. Invoke as
  /right-sizing from /self-healing when healthy (including scheduled fires from
  /self-healing-loop), or manually.
metadata:
  short-description: "KRR, ephemeral-storage, and VPA right-sizing for otaru"
---

# Otaru workload right-sizing

Right-size cluster workloads on the otaru home-lab. The cluster is memory-tight —
apply **both** downsizes and upsizes in the same PR when safe.

Invoke as `/right-sizing`. Called by `/self-healing` when the pass is healthy
and the 24h / merge-only gates allow (including fires from `/self-healing-loop`),
or run it directly.

## Prerequisites

Confirm before starting. On failure: journal
`### right-sizing pass` with `result: failed`, then stop and tell the user.
Missing:

- Cluster reachability: prefer Kubernetes MCP; fall back to `kubectl` only if
  MCP is unavailable or errors (`kubectl cluster-info` reaching VIP
  `192.168.10.50`).
- Prometheus ingress reachable (same URL as KRR below). Do not use
  `*.svc.cluster.local` from off-cluster.
- `krr` on PATH (`krr --help`) — Part 1.
- `gh` authenticated (`gh auth status`) — Part 3.
- `helm` on PATH — `make test` needs it.
- Repo checkout present (work from it).

## When to run

- **Full pass** when the cluster is healthy and the journal has no
  `### right-sizing pass` in the last 24 hours (see Journal).
- **Merge-only resume** when the latest pass in 24 hours has `result: open`
  and a `pr:` URL: continue that branch (Parts 3–4 only; skip Parts 1–2).
- Sooner (full pass) when workloads show OOMKills, probe failures, scheduling
  pressure, or ephemeral-storage evictions / `DiskPressure` — may run even if
  `/self-healing` is not fully green, if the user or a manual invoke asks.
- Skip guarded workloads (see below) even when metrics suggest downsizing.

## Part 1 — CPU and memory (KRR)

### Collect recommendations

Resolve `<prometheus-url-via-ingress>` from `httpRoutes.prometheus` in
`helm-charts/monitoring/values.yaml` and the hostname pattern in
`helm-charts/monitoring/templates/route-internal.yaml` (HTTPS ingress for
the prometheus route key). Do not hardcode the domain.

```bash
krr simple -p <prometheus-url-via-ingress> -f json -q > /tmp/krr-otaru-$(date +%F).json
```

### Build the change set

Before editing any workload, check `kubectl get vpa -A` — skip anything with an
existing `VerticalPodAutoscaler` object (see **VPA-managed workloads** below).
KRR and VPA fighting over the same Deployment produces confusing drift, not a
better answer.

For each remaining candidate workload in `helm-charts/**/values.yaml` (and chart
templates when resources live there):

1. Read inline resource comments for past incidents (OOM, probe failures, scheduling pressure). **Do not downsize past those guardrails.**
2. **Downsize** when KRR peak is well below the request and no incident comment blocks it.
3. **Upsize** when KRR peak exceeds the request/limit or live pods show OOM risk.
4. Skip guarded workloads when comments document repeated OOM or sync spikes (for example changedetection app, blocky, grafanas, argocd, jellyfin).

### Helm chart rules

See `AGENTS.md`: memory request = limit; no CPU limits unless asked; explicit
ephemeral-storage; add `# KRR YYYY-MM-DD:` on CPU/memory changes with peak and
why the old value was wrong.

KRR covers **CPU and memory only** — not ephemeral-storage.

## Part 2 — Ephemeral-storage (Prometheus)

KRR does not recommend ephemeral-storage. Use metrics from
`k8s-ephemeral-storage-metrics` (subchart of `helm-charts/monitoring`) scraped
into Prometheus as job `k8s-ephemeral-storage-metrics`.

Query via the same `<prometheus-url-via-ingress>` as KRR (HTTP API or Grafana).

### Key metrics

| Metric                                         | Use                                      |
|------------------------------------------------|------------------------------------------|
| `ephemeral_storage_pod_usage`                  | Peak bytes per pod                       |
| `ephemeral_storage_container_volume_usage`     | Per-container emptyDir / writable layers |
| `ephemeral_storage_container_limit_percentage` | Usage vs configured limit                |
| `ephemeral_storage_node_percentage`            | Node-level disk pressure context         |

Compare configured limits with kube-state-metrics (example namespace filter;
replace `teslamate` with the workload under review):

```promql
kube_pod_container_resource_limits{resource="ephemeral_storage", namespace="teslamate"}
```

### Example queries

Peak pod ephemeral usage over 14 days:

```promql
max_over_time(ephemeral_storage_pod_usage{pod_namespace="teslamate"}[14d])
```

Workloads approaching their limit (>80%):

```promql
ephemeral_storage_container_limit_percentage > 80
```

Top consumers cluster-wide:

```promql
topk(20, max_over_time(ephemeral_storage_pod_usage[14d]))
```

### Build ephemeral-storage changes

1. Run the queries above (instant query API or `query_range` for history).
2. For each workload above ~70% of limit or with eviction history, bump `ephemeral-storage` request and limit together in the Helm chart.
3. Add an inline comment with the observed peak bytes or percentage and trigger (for example `DiskPressure`, eviction event) — not a `# KRR` comment.
4. Prefer `emptyDir.sizeLimit` for `/tmp` or cache volumes when the workload writes locally and the chart supports it.
5. Do **not** use these metrics for PVC/Longhorn volumes — exporter ignores CSI-backed storage.

### Limits

- Exporter does not monitor generic ephemeral volumes (CSI-backed).
- No CLI recommender — interpret PromQL peaks manually with headroom (~20–30%).
- Combine ephemeral changes with KRR CPU/memory in the same PR when both apply.

## Part 3 — GitOps PR

1. Before opening, check journal `### right-sizing pass` `pr:` fields and
  `gh pr list --state open` for an in-flight right-sizing PR; continue that
  branch when one exists.
2. Branch from `master` only when no in-flight PR; edit only in-scope chart
  values/templates (KRR + ephemeral-storage from Parts 1–2).
3. Run `make test` and fix failures (re-run after further commits on the same
  branch).
4. Open **one** PR for all safe changes this pass (or push to the continued
  branch).
5. Classify and merge per
  `.claude/skills/self-healing/runbooks/merge-policy.md` only — no separate
  matrix. After outcome, run
  `.claude/skills/self-healing/runbooks/branch-cleanup.md`.

## Part 4 — Verify rollout

After merge (prefer Kubernetes MCP; fall back to `kubectl`):

- Confirm Argo CD apps sync to the new revision for touched workloads.
- Inspect pod `resources` and `lastState.terminated.reason` for OOMKill.
- Note upsized workloads for a later cycle (prometheus CPU/memory, browser,
  umami, etc.) — do **not** block the unattended run for 24 hours.

### Hotfix regressions

Open a follow-up PR immediately if rollout breaks a workload:

- **OOM after downsize** — bump memory above the failing limit; comment exit code
  and workload (for example changedetection OOMKill exit 137 at 256Mi → 1Gi).
- **Init/exec format error on nuc-00** — arm64-only images on amd64; pin
  `nodeSelector: kubernetes.io/arch: arm64` when charts use arm64-only digests.

## VPA-managed workloads

`helm-charts/vpa/` deploys Kubernetes VPA (recommender, updater,
admission-controller). It is a **second, complementary** resource-management
path, not a replacement for KRR passes above — the two suit different shapes
of workload.

### Why VPA does not replace KRR here

VPA's memory algorithm targets the 95th percentile of **daily peak** usage
over an 8-day window, not typical/steady-state usage. That is the right
behaviour for a workload with roughly constant usage, but for a workload that
spikes briefly then idles (blocky's ~4h denylist refresh, changedetection's
hourly page-render), it recommends a request near the peak — undoing the
manual "steady-state request, higher limit" overcommit tuning already applied
to those charts. **Never add a `VerticalPodAutoscaler` for a guarded workload**
(the same list as the KRR guardrails above) unless it is scoped to
`controlledResources: [cpu]` only, since VPA's CPU algorithm is
percentile-based, not peak-based, and does not have this problem.

### Good VPA candidates

Workloads with no incident-history comment in their chart and no
periodic-spike shape — most single-purpose controllers and sidecars. `reloader`
and `k8s-cleaner` are the initial trial (`helm-charts/reloader/values.yaml`,
`helm-charts/k8s-cleaner/values.yaml`, both `vpa.enabled: true`).

### Onboarding a new workload to VPA

1. Add `vpa.enabled: true` to the chart's `values.yaml`.
2. Add `templates/verticalpodautoscaler.yaml` gated by that flag, following
    the pattern in `helm-charts/reloader/templates/verticalpodautoscaler.yaml`:
    `targetRef` at the Deployment, `minAllowed`/`maxAllowed` bounds derived
    from real Prometheus usage (not a guess), `controlledResources` scoped to
    what is safe for that workload's usage shape.
3. Start `updateMode: Initial` while validating the recommendation against
    real usage; a fresh VPA has near-zero history and its confidence-interval
    math inflates recommendations toward `maxAllowed` for the first ~24 hours,
    settling toward the real value over roughly a week (8-day histogram
    window). Do not trust or hand-tune bounds around an `Initial`-mode
    recommendation less than a day old.
4. Switch to `updateMode: InPlaceOrRecreate` once the recommendation has
    settled and looks sane. This cluster's k3s v1.36.2 supports in-place pod
    resize (GA since Kubernetes 1.35) and VPA 1.7+ needs no feature-gate flag
    for this mode, so most resizes apply live with no pod restart.

## Journal

Always append a `### right-sizing pass` marker to
`.scratchpad/SELF_HEALING.md` (even on prereq failure, no-op, or no chart
changes) using the template in
`.claude/skills/self-healing/SKILL.md` **Journal**. Allowed
`result` values: `applied` | `no-op` | `held` | `open` | `failed`
(`open` = PR in flight / CI re-check next cycle). Same redaction and
no-commit rules as self-healing.
