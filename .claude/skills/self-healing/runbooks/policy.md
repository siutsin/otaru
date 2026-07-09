# Policy

Kyverno enforces admission policy on this cluster today; if that changes,
update the commands below.

## Checks

- `kubectl get clusterpolicyreports,policyreports -A` — policy failures
  blocking workloads?

## Triage

- Policy deny on a new or changed workload → GitOps-fix the manifest or
  chart to comply.
- Cluster-wide policy chart change → escalate.
