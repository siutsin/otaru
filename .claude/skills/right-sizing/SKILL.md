---
name: "right-sizing"
description: >-
  Right-size otaru workloads via KRR (CPU/memory) and Prometheus ephemeral-storage
  metrics. Read incident comments as guardrails, apply downsizes and upsizes in one
  GitOps PR, verify rollout. Invoke as /right-sizing from /self-healing when
  healthy (including scheduled fires from /self-healing-loop), or manually.
metadata:
  short-description: "KRR and ephemeral-storage right-sizing for otaru"
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

For each candidate workload in `helm-charts/**/values.yaml` (and chart templates
when resources live there):

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
replace `happy` with the workload under review):

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
  and workload (for example happy OOMKill exit 137 at 640Mi → 896Mi).
- **Init/exec format error on nuc-00** — arm64-only images on amd64; pin
  `nodeSelector: kubernetes.io/arch: arm64` when charts use arm64-only digests.

## Journal

Always append a `### right-sizing pass` marker to
`.scratchpad/SELF_HEALING.md` (even on prereq failure, no-op, or no chart
changes) using the template in
`.claude/skills/self-healing/SKILL.md` **Journal**. Allowed
`result` values: `applied` | `no-op` | `held` | `open` | `failed`
(`open` = PR in flight / CI re-check next cycle). Same redaction and
no-commit rules as self-healing.
