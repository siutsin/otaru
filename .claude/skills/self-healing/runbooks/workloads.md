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
