# Starting the Hourly Loop

Start an hourly **session-only** self-healing loop for the otaru cluster in
the current agent session.

## Why session-only

This loop runs live `kubectl` actions and opens PRs. A durable, disk-persisted
schedule can be loaded and fired by every agent session open on this repo,
causing concurrent runs, duplicate PRs, and git races. Keep it session-only
so exactly one session drives it. Re-run this bootstrap in whichever session
you want to own the loop.

## Steps

**Step 1. List existing jobs.** List scheduled jobs (Claude: `CronList`).
Note any recurring job whose prompt contains `self-healing`.

**Step 2. Create the new session schedule first.** Create a recurring,
**non-durable** job. The non-durable flag is the anti-concurrency invariant —
do not omit it. Prefer **create-new, then delete-old** so a failed create does
not leave the loop unscheduled. Never leave two matching jobs after step 3.

Claude (`CronCreate`) example:

```text
cron:      37 * * * *   (hourly, off the :00/:30 marks)
recurring: true
durable:   false        (session-only; must not persist to disk)
prompt:
  1) if a prior fire in this session is still running, skip this fire.
  2) run /self-healing (full investigation + fixes per merge-policy).
  3) if healthy: full /right-sizing when no ### right-sizing pass in 24h;
  or merge-only resume when latest pass is result: open with a pr: URL.
  4) report start/end datetime and time until the job expires.
```

Other agent platforms: use the equivalent session-only / non-durable /
non-persisted schedule API with the same cron expression and prompt intent. If
the platform has no non-durable mode, do not start a multi-session schedule —
stop and tell the user.

**Step 3. Delete the old matching job** (if any) only after the new job is
confirmed (Claude: `CronDelete`). Re-running this bootstrap renews the expiry
window.

**Step 4. Confirm** the job ID, the `37 * * * *` cadence, session-only
(`durable: false`), auto-expiry (Claude: **7 days**), and how to cancel
sooner (`CronDelete <id>`).

**Step 5. Run once now.** Invoke `/self-healing` immediately. If healthy and
no `### right-sizing pass` in the last 24 hours, invoke `/right-sizing` in the
same session. Report start/end and time remaining until expiry.

The scheduler platform caps recurring jobs at a fixed auto-expiry (Claude: 7
days). Re-run this bootstrap before the window elapses to renew.

## Unattended PR rule

Scheduled fires are unattended. Classify and merge **every** GitOps fix —
including right-sizing — per `runbooks/merge-policy.md`. Escalation-list
issues get no PR. That file is the single source of truth.

## Notes

- Do not create a durable/disk-persisted job from this bootstrap unless the
  user explicitly asks for a single-session exception.
- Needs a kubeconfig to the otaru API VIP on the local network; stop if the
  checkout or kubeconfig is missing.
- Prefer `/self-healing` and this bootstrap runbook as the only entrypoints.
