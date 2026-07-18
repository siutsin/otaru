# Monitoring Helm Chart — Agent Guide

GitOps source of truth for Prometheus, Grafana, Loki, blackbox, and related
cluster monitoring. Prefer chart/values changes; only live-patch for emergency
diagnostics, then backport.

## Dashboards

Path: `dashboards/*.yaml` (Grafana helm `grafana.dashboards.default` embeds).

| Key | Grafana title | Notes |
| --- | --- | --- |
| `blocky` | Blocky | Custom SRE layout; v0.28 metric names |
| `onzack-cluster-monitoring` | Standard Cluster Monitoring | ONZACK 17404 + recording rules + otaru sections |
| `prometheus-stats` | Prometheus Stats | Prometheus process stats |
| `container-log-dashboard` | (gnet 16966) | Loki logs; `gnetId`+`revision` download |

**Dashboards are vendored GitOps artifacts**, not live upstream sync (except
`container-log-dashboard`, which pins a Grafana.com revision). Editing UI is
disabled (`allowUiUpdates: false`). Changes require a PR and Argo reconcile.

Every Standard Cluster Monitoring panel (and row) should keep a **description**
explaining the metric in plain language (hover in Grafana). When re-vendoring,
re-apply or regenerate descriptions rather than shipping empty ones.

Standard Cluster Monitoring auto-refreshes with Grafana **`auto`** (same as the blocky dashboard). Keep `refresh: auto` when re-vendoring.

Validate with `python3 scripts/validate-grafana-dashboards.py` (also via
`make test`). Forbidden selectors include bare `job="node-exporter"` and the
broken `cattle-.*openshift` regex.

### Prometheus datasource

Hardcoded dashboard UID: `PBFA97CFB590B2093` (must match
`grafana.datasources` in `values.yaml`).

`jsonData.timeInterval` must equal Prometheus scrape interval (**1m**). A
shorter Grafana interval collapses `$__rate_interval` and causes **No data** on
`rate()` / `increase()` panels.

## ONZACK Standard Cluster Monitoring

- Upstream: [Grafana.com 17404](https://grafana.com/grafana/dashboards/17404)
  (with recording rules), GitHub
  [onzack/grafana-dashboards](https://github.com/onzack/grafana-dashboards).
- File: `dashboards/onzack-cluster-monitoring.yaml`
- UID: `ozk-std-clstr-mon` (not the legacy `…-norec` without-rules fork).
- Required Prometheus rules: `prometheus.serverFiles.recording_rules.yml`
  groups named `onzack-cluster-*` in `values.yaml`.

### otaru adaptations (do not drop on upgrade)

When re-vendoring 17404, re-apply:

1. **Node-exporter job** — scrapes are
   `job="kubernetes-service-endpoints"`, not `job="node-exporter"`. Memory
   rules use `job=~"kubernetes-service-endpoints|node-exporter"`.
2. **Unlabeled nodes** — worker nodes may have no `kube_node_role` series.
   `instance:kube_node_role` ORs a synthetic `role="worker"` from
   `kube_node_info` so every node appears in capacity panels.
3. **cAdvisor node label** — container series use `instance` (hostname), not
   `node`. Container recording rules must
   `label_replace(..., "node", "$1", "instance", "(.*)")` before joining
   `instance:kube_node_role` on `node`. Without this, Capacity “used/wasted”
   panels show **No data**.
4. **Dashboard** — `noderole` include All (`.*`); kubelet errors match
   `job=~"kubelet|kubernetes-api-servers"`. Recording metric names use the
   `role:` prefix where upstream records `role:kube_node_status_*:avg`.
5. **Empty limits** — many workloads set no CPU limits. Pure sum panels for
   limits (especially `namespace=~"kube-.*|..."`) use `or vector(0)` so Grafana
   shows **0** instead of **No data**.
6. **`refresh: auto`** and plain-language **panel descriptions** on every
   panel/row (including otaru-only sections below).
7. **otaru-only collapsed sections** (not in upstream 17404) — copy forward
   from the previous vendored JSON after re-embedding upstream. Identify rows
   whose titles end with `(cAdvisor)` or `(KRR)`, plus variables
   `cadvisor_instance` and `namespace`. Details:

   | Collapsed row title | Source (retired board) | Contents |
   | --- | --- | --- |
   | Workload usage by namespace (cAdvisor) | gnet 15282 / k3s-cluster-monitoring | CPU + memory by namespace |
   | Pods resource usage (cAdvisor) | gnet 15282 | Pod CPU, memory, network I/O |
   | Containers resource usage (cAdvisor) | gnet 15282 | Container CPU/memory, network I/O |
   | Resource requests vs usage (KRR) | resource-requests-vs-usage | Request vs 6h usage tables (CPU/mem), cluster requested vs used, ephemeral-storage top 20 |

   Section rules when re-applying:

   - Datasource UID must be `${datasource}` (not hardcoded Prometheus UID).
   - cAdvisor workload queries filter with
     `instance=~"$cadvisor_instance"` and `namespace=~"$namespace"`
     (variables: All = `.*`, multi-select).
   - Prefer `$__rate_interval` for live rates (scrape is 1m). Keep the KRR
     tables’ fixed `6h` / `avg_over_time(...[6h])` windows — those are
     intentional right-sizing horizons.
   - Skip re-adding host-level “All processes” charts from old k3s; node
     views already live in ONZACK CPU/Memory/Network rows.
   - Do **not** reintroduce standalone
     `k3s-cluster-monitoring.yaml` or `resource-requests-vs-usage.yaml`.

### Upgrading the dashboard

1. Download latest 17404 JSON (or GitHub
   `with-recording-rules/standard-cluster-monitoring.json`).
2. Diff against current `recording_rules` groups; merge new records into
   `values.yaml` **with** the adaptations above.
3. Re-embed JSON under `onzack-cluster-monitoring`.
4. Re-apply items 1–7: scrape/job fixes, descriptions, `refresh: auto`, and
   **copy the otaru-only cAdvisor + KRR rows and variables** from the previous
   dashboard revision (or rebuild from the table above). Bump description with
   gnet revision and note that otaru sections were re-applied.
5. After deploy: ConfigMap reload is enough (see below). Confirm
   `count(instance:kube_node_role)` equals node count and
   `count(container_cpu_usage_seconds_total:sum_rate5m:namespace) > 0`.
   Open the new cAdvisor/KRR sections once and confirm tables/series populate.

## Prometheus config reload

Recording/alerting rules live in `serverFiles` on the prometheus-server
ConfigMap. The **configmap-reload** sidecar watches `/etc/config` and POSTs
`/-/reload` (`--web.enable-lifecycle`). **No pod restart** is required for
rule or scrape config file updates.

Wait one evaluation interval (~1m for Onzack groups) before judging empty
series.

## Blocky dashboard

Custom board for DNS. Prefer per-pod resource series (`process_*` with
`{{pod}}` legend). Blocky v0.28 renamed several metrics (e.g. durations in
seconds, `*_entries`, `*_hits_total`). Health tiles should not use opaque
totals without units or unexplained abbreviations.

## Resource policy (chart workloads)

Follow root `AGENTS.md`: memory request = limit unless told otherwise; no CPU
limits unless asked; set ephemeral-storage request/limit; comment every
resource change with the observed trigger (OOM, probe fail, etc.).

## Checks

```bash
make test
# or focused:
python3 scripts/validate-grafana-dashboards.py
helm template monitoring helm-charts/monitoring -f helm-charts/monitoring/values.yaml >/dev/null
```
