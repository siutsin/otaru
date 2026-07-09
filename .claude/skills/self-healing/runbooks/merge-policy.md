# Trivial vs Non-Trivial (Merge Policy)

Classify every GitOps PR before deciding its merge policy. When in doubt,
treat it as non-trivial. This file owns the **unattended edit list**,
**trivial/non-trivial classification**, and **closed live-action allowlist**.
`references/escalation.md` owns only escalate / secrets / destructive
boundaries.

## Merge procedure

After branch, commit, push, and PR open:

1. Watch CI to green. Prefer
  `gh pr checks <number> --watch --fail-fast` (see `AGENTS.md`). In
  **unattended/loop** mode bound the wait (for example stop after ~15
  minutes, journal `result: open` with the PR URL, and re-check next cycle).
  Do not park the whole hourly fire on an unbounded watch.
2. Address review feedback if any.
3. Then apply the class below.

### Trivial — auto-merge once green

- Prefer `/pr-autofix` with default auto-merge when that skill is available
  (Claude).
- Otherwise enable GitHub auto-merge after green, for example:
  `gh pr merge <number> --auto --squash` (or the repo's usual merge method).
- Journal the PR URL and that merge was auto.

### Non-trivial — stop at green

- Prefer `/pr-autofix auto_merge=false` when available.
- Otherwise watch CI to green (with the same unattended timeout rule), then
  **do not merge**. Surface the PR URL and leave the merge to the user.
- Journal the PR URL and that merge was held.

Never invent a different merge path per agent session. Escalation-list issues
do not open a PR.

Before opening a PR for a known root cause, also check
`gh pr list --state open --search "<short cause>"` (and the journal `pr`
field) and continue an in-flight PR when one already covers it.

## Trivial

Merge automatically once green when **all** of the following hold:

- Diff is only an allowed unattended edit (see below)
- No secret-adjacent keys or paths (see `references/escalation.md`)
- No chart/template structural rewrite, CRD change, or GitOps controller
  Application delete/disable/prune-force
- **Single concern:** one app, one shared value, **or** one right-sizing
  pass whose every hunk is only resource requests/limits/replicas (multi-chart
  resource-only is still one concern). Not a mixed bulk rewrite of unrelated
  concerns.
- Tests already passed for this branch (`make test` before open; CI green)

## Non-trivial

Push, watch CI to green, address review feedback, then stop and leave the
merge to the user. Includes: anything outside the allowlist, borderline
`values.yaml` edits, database/storage backup changes that are not pure
resource/image/probe/sync-wave tweaks (topology, schedule, storage class,
PVC size, crypto, restore), mesh/gateway policy, cluster-wide policy-chart
rewrites, multi-app bulk edits of **non-resource** fields, or any fix not
confidently low-risk. Pure resource/image pins on a database or storage chart
remain trivial when they meet the bullets above.

## Allowed unattended GitOps edits

Trivial when they alone form the PR: resource requests/limits, replicas
within PDB bounds, probe tweaks, public image tag pins, sync-wave fixes,
dashboard/log retention unrelated to backup storage, non-secret feature
flags that do not change exposure/auth/privilege, and manifest nits to
satisfy an **existing** policy (no policy chart rewrite). Do not auto-merge
`hostNetwork`, privileged `securityContext`, Service exposure, or auth
flag changes — treat those as non-trivial. See `references/escalation.md`
for the secrets boundary.

## Live mutations

Do not `kubectl apply`, `patch`, or `edit` live resources. Escalate live
patches unless the user explicitly approves a time-boxed interim fix.

Closed live-action allowlist (journal each one):

- Delete a `CrashLoopBackOff` or stuck `Failed` pod when a Deployment (or
  ReplicaSet-owned) controller will recreate it — **not** StatefulSet pods
  unless the user approves. Confirm the Job/pod is not a backup or CronJob
  child before delete.
- Delete a failed one-off `Job` only after confirming it is not a backup /
  CronJob run (see `references/escalation.md`).
- `kubectl rollout restart` for a misbehaving Deployment when config is
  already correct in Git.
- Annotate ExternalSecret / PushSecret `force-sync` only when there is a
  concrete upstream-change proof (known rotation, user note, or verified
  upstream version bump). Do not thrash force-sync on a guess.
- Scale a Deployment **down** only as far as the PDB allows, and **up** at
  most +1 replica above the current ready count unless the user approves a
  larger step. Prefer GitOps replica changes over live scale when practical.

No other live mutations. Escalate everything else.

After a GitOps fix merges, wait for the reconciler's auto-sync and re-check
the symptom.
