# Monitoring

Prometheus is reachable from the remote runner through the tunnel proxy
(the same proxy `mcp-cli` uses) — no auth required. Verified 2026-09-21.

## Query

```bash
P="${HTTPS_PROXY%:*}:3130"
# If HTTPS_PROXY is unset, the substitution yields ":3130" — export it first.
HTTPS_PROXY="$P" https_proxy="$P" curl -s -m 25 \
  "https://prometheus.internal.siutsin.com/api/v1/query?query=<promql>"
```

The query API returns JSON (`status: success`, `data.result`). Keep
queries cheap and bounded — each takes ~1–2s. If the proxy query fails,
record this category as `partial`, not `ok`.

Grafana health (fallback liveness only):
`https://grafana.internal.siutsin.com/api/health` → 200.

## Checks (every pass)

| Check | PromQL — result must be empty |
| --- | --- |
| Scrape target down | `count(up == 0)` |
| Firing alerts | `ALERTS{alertstate="firing"}` |
| Node memory pressure | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1` |
| PVC nearly full | `kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.85` |
| Certificate expiring within 7 days | `(certmanager_certificate_expiration_timestamp_seconds - time()) < 604800` |

## Triage

- Firing alert → treat like any other finding: diagnose via the relevant
  runbook, GitOps-fix when safe, escalate when destructive.
- `up == 0` on a target → check the workload's category runbook first
  (workloads, data-plane); a down exporter is often a symptom, not the
  cause.
- Missing metric (empty result for a query that should return series) →
  the target may have no matching series on this cluster; verify with a
  broader query before concluding anything. Do not invent thresholds for
  metrics that do not exist here.
