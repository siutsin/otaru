# Data Plane

Database and storage backups. Today that is CloudNativePG (CNPG) for
Postgres and Longhorn for block storage — update the commands below if
either is ever replaced. Read-only for the database operator here — no
mutations (see `references/escalation.md`).

## Checks

- `kubectl get cluster -A` then `kubectl cnpg status <name> -n <ns>` per
  cluster.
- `kubectl get scheduledbackup,backup -A` — any failed or missing recent
  CNPG backups?
- `kubectl -n longhorn-system get recurringjobs.longhorn.io` — jobs
  present? Any failed backup Jobs or pods in `longhorn-system`?
- `kubectl get externalsecrets -A` — any not `Ready`?

## Triage

- CNPG healthy → continue.
- Backup failing, replica lag, or instance down → journal and
  **escalate** (no CNPG mutations) — unless the user explicitly approves
  a live fix (see `references/escalation.md`'s interim-fix exception).
- **Instance `CrashLoopBackOff` on a faulted/unrecoverable PVC:** first
  check `kubectl get cluster.postgresql.cnpg.io <name> -n <ns> -o
  jsonpath='{.status.currentPrimary} {.status.instancesStatus}'` — if the
  cluster already failed over to a healthy primary and
  `ContinuousArchiving`/`LastBackupSucceeded` conditions are `True`, the
  database service itself is not down, only that one instance. With user
  approval, `kubectl cnpg destroy <cluster> <instance-number> -n <ns>`
  removes the broken instance's pod and PVC together and lets the
  operator recreate it fresh, streaming from the healthy primary — this
  is the CNPG-native recovery path, not a manual PVC/pod delete. The
  operator may recreate it under a new, higher instance number rather
  than reusing the destroyed one.
- **Barman / WAL archiving `exit status 4`:** often disk full on the
  instance PVC. Recovery paths that delete DB PVCs or pods are
  **escalate** only — never unattended. See `documentation/gotcha.md`.
- Failed Longhorn recurring backup Jobs → **escalate**.
- ExternalSecret not `Ready`: only `force-sync` under the live-action
  rules in `runbooks/merge-policy.md` (concrete upstream-change proof
  required). Otherwise GitOps-fix or escalate if source keys or
  `values.yaml` secret payloads need edits.

PVC **resize** or delete on database volumes is always escalate (see
`references/escalation.md`), even when space pressure is obvious.
