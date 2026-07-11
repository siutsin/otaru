# Escalation Guide

When in doubt, escalate. The user prefers a short alert over a bad auto-fix.

This file owns **secrets boundaries** and **always-escalate** classes only.
Unattended-edit allowlists, trivial merge rules, and the closed live-action
list live in `runbooks/merge-policy.md` — do not fork them here.

## Secrets

**Escalate** any change that touches credentials or secret material:

- Keys or paths matching `password`, `token`, `secret`, `credential`,
  `apiKey`, `privateKey`, `existingSecret`, `dockerconfigjson`,
  `tls.key`, `connectionString`, `op://`, or entries in
  `documentation/secrets.md`
- `ExternalSecret` / `PushSecret` source keys or remote refs
- Any file under the machine-local secrets store described in
  `documentation/secrets.md` (outside this repo)

When a `values.yaml` edit is borderline for secrets, escalate (or hold the
merge).

## Always escalate

- **Database operator** — restore, PITR, major upgrade, delete, failover, PVC
  **resize or delete** on DB volumes, operator topology changes.
- **Storage** — volume delete, restore, recurring-job backup target changes,
  crypto secret rotation, stuck-volume webhook work.
- **Disk encryption / nodes** — unlock (`make unlock`), hardware replace,
  stale node-password cleanup, plain reboot of LUKS-root nodes.
- **Cluster ops** — full teardown, version upgrade, reboot-all maintenance
  (`make nuke`, `make upgrade`, `make maintenance`), etcd repair, k3s
  reinstall.
- **Mass impact** — cluster-wide restart, draining **multiple** nodes, bulk
  deletes across namespaces.
- **Infrastructure as code** — any Terraform/OpenTofu/Terragrunt apply,
  Ansible setup/disk-encryption playbooks.
- **Secrets** — editing chart secret payloads, password-manager items,
  ExternalSecret source keys.
- **GitOps controller** — Application/resource delete, force sync with prune,
  disabling auto-sync permanently.
- **Data loss** — any command that deletes PVCs, PVs, namespaces with state,
  or object-storage backups.
- **Jobs** — failed CronJob, backup Job, or Job whose command touches data or
  secrets.
- **Unused-resource findings** (`runbooks/unused-resources.md`, `kor`) —
  never auto-delete or open an unattended removal PR, even for a candidate
  that looks clearly safe. The scanner has a demonstrated high
  false-positive rate (see `documentation/gotcha.md`); always escalate to
  the user first.

## GitOps reminder

The GitOps controller reconciles from the base branch (HEAD). A live
`kubectl edit` without a matching PR will drift and may be reverted.
Escalate if the only apparent fix is a one-off live patch with no clear
GitOps follow-up.
