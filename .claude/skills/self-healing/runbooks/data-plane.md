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
  **escalate** (no CNPG mutations).
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
