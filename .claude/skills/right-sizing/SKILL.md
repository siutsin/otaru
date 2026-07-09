---
name: "right-sizing"
description: >-
  Right-size otaru workloads via KRR (CPU/memory) and Prometheus ephemeral-storage
  metrics. Read incident comments as guardrails, apply downsizes and upsizes in one
  GitOps PR, verify rollout. Invoke as /right-sizing from self-heal loops or manually.
metadata:
  short-description: "KRR and ephemeral-storage right-sizing for otaru"
---

# Otaru workload right-sizing

Right-size cluster workloads on the otaru home-lab. The cluster is memory-tight —
apply **both** downsizes and upsizes in the same PR when safe.

Invoke as `/right-sizing`. Called from the hourly self-heal loop when healthy and
no pass ran in the last 24 hours.

## When to run

- Cluster healthy and journal has no right-sizing pass in the last 24 hours.
- Sooner when workloads show OOMKills, probe failures, scheduling pressure, or
  ephemeral-storage evictions / `DiskPressure`.
- Skip guarded workloads (see below) even when metrics suggest downsizing.

## Part 1 — CPU and memory (KRR)

### Collect recommendations

Resolve `<prometheus-url-via-ingress>` from `httpRoutes.prometheus` in
`helm-charts/monitoring/values.yaml` (hostname pattern in
`templates/route-internal.yaml`: `https://<route-key>.internal.siutsin.com`).
Do not use `*.svc.cluster.local` from off-cluster; use the ingress URL.

```bash
krr simple -p <prometheus-url-via-ingress> -f json -q > /tmp/krr-otaru-$(date +%F).json
```

### Build the change set

For each candidate workload in `helm-charts/**/values.yaml` (and chart templates
when resources live there):

1. Read inline resource comments for past incidents (OOM, probe failures, scheduling pressure). **Do not downsize past those guardrails.**
2. **Downsize** when KRR peak is well below the request and no incident comment blocks it.
3. **Upsize** when KRR peak exceeds the request/limit or live pods show OOM risk.
4. Skip guarded workloads when comments document repeated OOM or sync spikes (for example changedetection app, blocky, grafanas, argocd, jellyfin).

### Helm chart rules

See `AGENTS.md`:

- Set memory requests equal to memory limits.
- Do not set CPU limits unless the user explicitly asks.
- Set explicit ephemeral-storage requests and limits.
- Add an inline `# KRR YYYY-MM-DD:` comment for CPU/memory changes stating the observed peak/symptom and why the previous value was wrong.

KRR covers **CPU and memory only** — not ephemeral-storage.

## Part 2 — GitOps PR

1. Branch from `master`, edit only in-scope chart values/templates.
2. Run `make test` and fix failures.
3. Open one PR covering all safe changes for that pass (KRR + ephemeral-storage).
4. Run `/pr-autofix` — `auto_merge=false` on unattended cron fires; merge when the user is present and the PR is green.

## Part 3 — Verify rollout

After merge:

- Confirm Argo CD apps sync to the new revision for touched workloads.
- Inspect pod `resources` and `lastState.terminated.reason` for OOMKill.
- Watch upsized workloads for 24h (prometheus CPU/memory, browser, umami, etc.).

### Hotfix regressions

Open a follow-up PR immediately if rollout breaks a workload:

- **OOM after downsize** — bump memory above the failing limit; comment exit code
  and workload (for example happy OOMKill exit 137 at 640Mi → 896Mi).
- **Init/exec format error on nuc-00** — arm64-only images on amd64; pin
  `nodeSelector: kubernetes.io/arch: arm64` when charts use arm64-only digests.

Journal each pass in `.scratchpad/SELF_HEALING.md` with KRR score, workloads
changed, PR URL, and rollout result.

## Part 4 — Ephemeral-storage (Prometheus)

KRR does not recommend ephemeral-storage. Use metrics from
`k8s-ephemeral-storage-metrics` (subchart of `helm-charts/monitoring`) scraped
into Prometheus as job `k8s-ephemeral-storage-metrics`.

Query via the same `<prometheus-url-via-ingress>` as KRR (HTTP API or Grafana).

### Key metrics

| Metric | Use |
| ------ | --- |
| `ephemeral_storage_pod_usage` | Peak bytes per pod |
| `ephemeral_storage_container_volume_usage` | Per-container emptyDir / writable layers |
| `ephemeral_storage_container_limit_percentage` | Usage vs configured limit |
| `ephemeral_storage_node_percentage` | Node-level disk pressure context |

Compare configured limits with kube-state-metrics:

```promql
kube_pod_container_resource_limits{resource="ephemeral_storage", namespace="happy"}
```

### Example queries

Peak pod ephemeral usage over 14 days:

```promql
max_over_time(ephemeral_storage_pod_usage{pod_namespace="happy"}[14d])
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
