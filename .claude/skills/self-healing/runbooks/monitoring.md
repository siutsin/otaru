# Monitoring

Prometheus is reachable from the remote runner through the tunnel proxy
(the same proxy `mcp-cli` uses) — no auth required. Verified 2026-09-21.

## Query

Run `.claude/skills/self-healing/bin/monitoring-checks.py` from the
repo root. The script probes the tunnel first and exits 1 fast when the
proxy flaps. Then it runs the five checks below in parallel, each with
up to 3 attempts 15s apart (25s per attempt). It prints one JSON object
with per-check `ok`, `finding`, or `partial`.

A non-empty result on any attempt is a real finding, never noise. A
series with value 0 (for example `count(up == 0)` with no down targets)
is ok. Record the category as `partial` when the script exits 1 or any
check reports `partial`.

Manual query (when you must debug one check):

```bash
P="${HTTPS_PROXY%:*}:3130"
# If HTTPS_PROXY is unset, the substitution yields ":3130" — export it first.
HTTPS_PROXY="$P" https_proxy="$P" curl -s -m 25 \
  "https://prometheus.internal.siutsin.com/api/v1/query?query=<promql>"
```

Grafana health (fallback liveness only):
`https://grafana.internal.siutsin.com/api/health` → 200.

## Retry

The retry policy lives in `bin/monitoring-checks.py`: one probe query
first, then up to 3 attempts per check, 15s apart, 25s per attempt.

The tunnel proxy drops requests often enough that a single-shot query
misreads a transport blip as a finding (2026-09-23: `count(up == 0)`
returned on three attempts while the other four checks failed the same
way — transport, not the cluster). A check that errors on early attempts
but returns an empty result on retry is transport noise, not a finding.
A non-empty result on any attempt is a real finding — never dismiss it
as noise.

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
