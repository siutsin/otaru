---
name: "self-healing"
description: >-
  Investigate the otaru k3s home-lab cluster for unhealthy nodes, GitOps
  reconciliation, workloads, storage, data plane, platform, ingress/mesh,
  policy, and CI health; fix safe issues via GitOps PRs; escalate destructive
  or database work. Invoke as /self-healing, including hourly loop schedules.
metadata:
  short-description: "otaru cluster self-healing runbooks and loop"
---

# Otaru Self-Healing

> **Paths:** runbooks live under `runbooks/` and reference material lives
> under `references/`. Read a runbook only when its category is reached in
> the investigation order below; read a reference file only when relevant.

Requires a kubeconfig reaching the cluster's API VIP over the local
network — not usable from a machine without that network path (for example
a CI runner or a remote devserver). Investigate the otaru home-lab `k3s`
cluster, fix safe issues, and journal findings. Designed for hourly
scheduled runs as well as manual invocation.

Invoke as `/self-healing`.

## Scope

- **Cluster:** otaru bare-metal `k3s` on `192.168.10.0/24` (see the otaru
  repo `README.md` and `references/cluster.md`).
- **GitOps repo:** this repo — the reconciler syncs from it; durable fixes
  belong here, not as orphaned live edits.
- **Journal:** `.scratchpad/SELF_HEALING.md` at the repo root.
- **Out of scope:** any machine without a kubeconfig reaching the API VIP.
  If kubeconfig or the repo checkout is missing, stop and tell the user.

## Runtime gate

Before any cluster command or otaru repo write (**identity** only):

1. Confirm you are working from an otaru repo checkout.
2. Confirm the API server is the otaru VIP `192.168.10.50` (with or without
    `:6443` — both forms are fine). Prefer Kubernetes MCP for this check
    when available; otherwise `kubectl cluster-info`.
3. Confirm `kubectl get nodes -o wide` (or MCP equivalent) lists all five
    expected names (Ready or not): `raspberrypi-00`, `raspberrypi-01`,
    `raspberrypi-02`, `raspberrypi-03`, `nuc-00`. Wrong or missing names mean
    the wrong cluster — stop.

If any identity check fails, stop. Do not mutate a cluster. NotReady nodes
are handled in `runbooks/access-and-nodes.md` — do not treat them as a gate
failure.

**Tooling (soft):** the Postgres-operator CLI plugin (`kubectl cnpg version`)
is required only for `runbooks/data-plane.md`. If it is missing, skip
CNPG-specific checks, journal a note, and continue other categories.

## Cluster inspection

Prefer **Kubernetes MCP tools** for read-only diagnostics (list pods,
events, Applications, logs, metrics) when they are available. Fall back to
`kubectl` for the same checks or when MCP is unavailable. Exact resource
checks in the runbooks remain the source of truth either way. Mutating
operations stay GitOps-first (see Fixes).

## Journal

Write only when you find an issue or attempt a fix. Skip the journal when
the cluster is healthy.

Use simple, concise English. Every word must earn its place. Use local time
in headings.

Format:

```markdown
## <YYYY-MM-DD> <HH:MM>

### issue <short title>

- **symptom:** what you observed
- **cause:** root cause if known; `unknown` if not
- **action:** what you did, or `none — escalated`
- **result:** `fixed` | `open` | `escalated`
- **pr:** PR URL if a GitOps change was opened; omit if none
```

Right-sizing pass marker (always write when `/right-sizing` runs, even if
healthy and no chart changes — used for the 24h gate):

```markdown
### right-sizing pass

- **krr:** score or summary path
- **workloads:** list changed or `none`
- **pr:** URL or `none`
- **result:** `applied` | `no-op` | `held` | `open` | `failed`
```

Rules:

- Create `.scratchpad/SELF_HEALING.md` on first write if missing.
- Append new sections at the end; do not rewrite history.
- Never log secrets, tokens, or raw credential output. No Secret,
  ExternalSecret, or PushSecret dumps; no `kubectl get secret -o yaml`;
  no raw CI `--log-failed` dumps or pod env dumps. Summarise with
  namespace, name, and key names only. Use `[REDACTED]` for values.
  Reference paths instead of pasting values.
- Do not commit or push the journal. Before any otaru commit, run
  `git status` and abort if `.scratchpad/` is staged.

## Investigation

Read `references/escalation.md` and `runbooks/merge-policy.md` before
live mutations. Read `references/cluster.md` and
`references/escalation.md` before any otaru repo edit.

Start by reading the last few journal entries. For each latest entry with
`result: open` or `result: escalated`, re-check its symptom before new
work. A run is healthy only when the checklist passes **and** every such
entry is resolved or still correctly escalated.

Then work through this checklist in order. On the first P0 (NotReady node
or a GitOps reconciler reporting degraded), fix or escalate before
lower-priority categories.

Prerequisites: otaru repo checkout, kubeconfig reaching API VIP
`192.168.10.50`.

1. `runbooks/access-and-nodes.md` — cluster reachability, node readiness,
    node pressure. **P0.**
2. `runbooks/gitops-reconciliation.md` — reconciler health and drift.
    **P0.**
3. `runbooks/workloads.md` — pods, deployments, jobs.
4. `runbooks/storage.md` — PVCs and volumes.
5. `runbooks/data-plane.md` — database and storage backups (read-only).
6. `runbooks/platform.md` — certificates and aggregated APIs.
7. `runbooks/ingress-mesh.md` — gateway, load-balancer VIP reachability,
    service mesh.
8. `runbooks/policy.md` — admission policy failures.
9. `runbooks/ci-cd.md` — scheduled workflow health.

Prioritise: node NotReady → reconciler degraded → data-loss risk →
user-facing app down → everything else.

**End of every run** (healthy or not, PR or not): run
`runbooks/branch-cleanup.md`.

## Fixes

Default to GitOps:

1. Diagnose in the live cluster.
2. Patch the otaru repo (`helm-charts/`, `argocd/`, manifests).
3. Run `make test` in the otaru repo before opening a PR. If it fails on
    unrelated drift, journal the failure and escalate — do not bypass
    checks.
4. Before opening, check journal `pr` and `gh pr list --state open` for the
    same root cause; continue an in-flight PR when one exists.
5. Branch, commit, push, open a PR.
6. Classify and merge per `runbooks/merge-policy.md`. Journal the PR URL
    and whether merge was auto or held.
7. Immediately after this PR's outcome is known (merged, or held green for
    the user), run `runbooks/branch-cleanup.md` — do not wait for the next
    scheduled run. A PR can merge before you notice; continuing to commit
    to a closed PR's branch wastes work.

See `runbooks/merge-policy.md` for classification, allowlists, and live
actions. See `runbooks/branch-cleanup.md` for cleanup and stuck-PR notes.

## Escalate — do not auto-fix

See `references/escalation.md` for the full table. In short: stop and ask
the user to review whenever the change is destructive or irreversible —
database restore/failover/major-upgrade, storage volume delete or crypto
config, cluster lifecycle operations, infrastructure-as-code applies,
secret rotation, or Application/resource deletes with prune.

Log these as `result: escalated` with a clear symptom and recommended next
step. Do not patch the repo or run destructive commands.

## Loop mode

When a scheduled run invokes this skill:

- **Re-entrancy:** if a prior fire in this session is still running, skip
  this fire (do not start a second investigation/PR loop in parallel).
- Run the full investigation each time, including journal closure for
  `open` / `escalated` entries.
- If healthy, report that the cluster is healthy: nodes Ready, no
  reconciler apps degraded, no lingering out-of-sync state without an
  in-flight PR, no open journal issues (escalated items waiting on the
  user are OK — mention them). Skip issue journal entries; still allow
  right-sizing pass markers when `/right-sizing` runs.
- If an issue persists, append a short update under the same `### issue`
  title with changed `action` / `result`, or a new timestamped block with
  delta only.
- Before opening a PR, search journal `pr` fields for open issues with
  the same root cause and run `gh pr list --state open`; continue that
  branch/PR when one is already in flight.
- Always end with `runbooks/branch-cleanup.md`.

To bootstrap the hourly scheduled loop itself, see
`runbooks/loop-bootstrap.md`.

## Right-sizing

Workload right-sizing is `.claude/skills/right-sizing` (`/right-sizing`).
When the cluster is healthy:

- **Full pass** (KRR + ephemeral + PR): if no `### right-sizing pass` in the
  last 24 hours.
- **Merge-only resume:** if the latest pass in 24 hours has
  `result: open` and a `pr:` URL, invoke `/right-sizing` only to continue
  that branch (CI re-check / merge-policy / branch-cleanup) — skip KRR and
  ephemeral collection.

Classify any PR with `runbooks/merge-policy.md`.

## Skill maintenance

If a run turns up something worth folding into this routine — a new
runbook, a gotcha class not yet covered, a merge-policy correction, a
troubleshooting technique that saved real time — edit the relevant file
under `runbooks/` or `references/` directly (or add a new runbook file; the
structure is designed to grow). Prefer short pointers into
`documentation/gotcha.md` over copying long write-ups.
Keep runbook and reference file names and headings capability-based rather
than tied to the current product name (for example
`gitops-reconciliation.md`, not `argocd.md`) so swapping a tool later is a
content edit, not a restructure.

## References

- `references/cluster.md` — paths, network, namespaces.
- `references/escalation.md` — safe vs escalate boundaries.
- `runbooks/` — one file per investigation category, plus merge policy,
  branch cleanup, and loop bootstrap.
- `documentation/gotcha.md` — known issues and workarounds.
