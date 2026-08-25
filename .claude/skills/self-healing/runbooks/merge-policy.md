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
  Do not park the whole fire (currently a 30-minute cycle) on an unbounded
  watch.
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

### Incident-revert exception

Auto-merge once green even when the diff would otherwise be non-trivial
(including a GitOps controller's own chart, e.g. `helm-charts/argocd`) when
**all** of the following hold:

- The PR fixes a currently active incident: a GitOps `Application` reporting
  `Degraded`, a pod stuck `CrashLoopBackOff`/`ImagePullBackOff`, or an
  equivalent live-broken state confirmed in this pass, not a hypothetical or
  future risk.
- The diff is a straight revert of a version/tag/digest field to the exact
  value that was deployed and healthy immediately before the incident began
  (confirm via `git log` / journal, not a guess) — not a new forward change,
  workaround, or anything touching secrets, RBAC, exposure, or destructive
  operations (those stay governed by `references/escalation.md` regardless
  of incident framing).
- `make test` passed and CI is green.

This does not relax the secrets/destructive boundaries in
`references/escalation.md` — an incident fixed by, say, a database restore
or a secret rotation is still escalate-only. It only covers the case where
the fix is provably identical to a prior known-good state.
Precedent: `argocd` chart reverted `10.2.3`/`10.3.0` -> `10.2.2` after a
same-day Renovate bump broke the repo-server (`--client-ca-path`/
`--disable-tls` conflict), PR #3034, 2026-08-12.

### Scoped application-logic bugfix exception

Auto-merge once green, even off the allowlist and not a revert, when **all**
hold:

- Fixes a currently active incident confirmed this pass (`Degraded`
  Application, `CrashLoopBackOff`/`ImagePullBackOff` pod, or equivalent).
- Single, narrow correction to existing app/template logic already in the
  chart (wrong format verb, typo'd field/env reference, off-by-one) — not a
  new feature, resource, chart rewrite, or CRD change.
- No secrets, RBAC, auth, exposure, mesh/gateway, or cluster-wide policy
  touched.
- Verified against rendered/live output (e.g. `helm template`), not lint
  alone.
- `make test` (or the affected chart's `helm lint`/`template` if `make test`
  is blocked by a known unrelated gap) passed and CI is green.

Precedent: `jung2bot` `MESSAGE_SAVE_QUEUE_URL` `printf %s` on an int64 →
literal `%!s(int64=...)`, invalid URL, crash loop; fixed to `%v`, PR #3144,
2026-08-25.

## Non-trivial

Push, watch CI to green, address review feedback, then stop and leave the
merge to the user. Includes: anything outside the allowlist, borderline
`values.yaml` edits, database/storage backup changes that are not pure
resource/image/probe/sync-wave tweaks (topology, schedule, storage class,
PVC size, crypto, restore), mesh/gateway policy, cluster-wide policy-chart
rewrites, multi-app bulk edits of **non-resource** fields, granting a new
Kyverno `PolicyException` or enabling the `policyExceptions` feature flag
(`runbooks/policy.md`), or any fix not confidently low-risk. A scope
correction to an **already-approved** `PolicyException` (for example adding
a missed autogen rule name) stays trivial when it is the only change in the
diff. Pure resource/image pins on a database or storage chart
remain trivial when they meet the bullets above. A revert fixing an active
incident stays trivial when it meets the Incident-revert exception above,
even if it would otherwise land here (e.g. it touches a GitOps controller's
own chart).

## Allowed unattended GitOps edits

Trivial when they alone form the PR: resource requests/limits, replicas
within PDB bounds, probe tweaks, public image tag pins, sync-wave fixes,
dashboard/log retention unrelated to backup storage, non-secret feature
flags that do not change exposure/auth/privilege, adding a
PodDisruptionBudget with `minAvailable: 1` to a single-replica hand-written
app chart (or enabling a bundled subchart's native PDB values option) that
has no PDB at all, manifest nits to satisfy an **existing** policy (no
policy chart rewrite), and the Cloudflare Access WebGazer IP allowlist
refresh described in `runbooks/ingress-mesh.md` (the one named exception to
the infrastructure-as-code escalate rule in `references/escalation.md`,
scoped strictly to that file and that `terragrunt plan` shape). Do not auto-merge `hostNetwork`, privileged
`securityContext`, Service exposure, or auth flag changes — treat those as
non-trivial. Excluding a workload from this PDB fix (vendored/generated
operator manifests, or anything where an eviction mid-operation has a
different risk profile — see `runbooks/workloads.md`) is a judgement call,
not a mechanical trivial/non-trivial split; when in doubt, leave it
unpatched and note it rather than auto-merge. See `references/escalation.md`
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
