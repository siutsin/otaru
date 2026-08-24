# Policy

Kyverno enforces admission policy on this cluster today; if that changes,
update the commands below.

## Checks

- `kubectl get clusterpolicyreports,policyreports -A` — policy failures
  blocking workloads?

## Triage

- Policy deny on a new or changed workload → GitOps-fix the manifest or
  chart to comply.
- Policy audit after a Helm value change → inspect both the live workload and
  the rendered chart. A values key can be accepted but ignored by the chart.
  Do not close the issue until the affected container has the required field.
- After a Prometheus chart upgrade or hardening change, inspect the rendered
  Alertmanager, Prometheus server, and config-reloader container security
  contexts. The current chart uses
  `prometheus.alertmanager.securityContext` and
  `prometheus.configmapReload.prometheus.containerSecurityContext`.
- Cluster-wide policy chart change → escalate.
