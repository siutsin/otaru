---
name: "self-healing-loop"
description: >-
  Use when starting, renewing, or extending the session-only hourly self-healing
  schedule to the platform max TTL (currently 7 days from this run). Not for
  one-off cluster investigation or GitOps fixes (use /self-healing). Every
  invoke: create a full-window /loop job, confirm, delete other matchers, run
  /self-healing once when possible, report timing.
metadata:
  short-description: "Bootstrap/renew hourly self-healing schedule to max TTL"
---

# Self-healing loop (orchestrator)

**Role:** **every** invoke **bootstraps or renews** the hourly session loop to
the **platform maximum TTL** (currently **7 days from this run**), keeps a
**single** matching job, then **delegates one** `/self-healing` after a
successful renew (or skips when investigation already ran this round). Composes
fires so **`/self-healing`** does the one-off work.

**Not this skill:** implementing cluster investigation, GitOps fixes,
merge/hold policy, right-sizing gates, issue journal content, or escalation.
Those live in `.claude/skills/self-healing` (`/self-healing`) and
`.claude/skills/right-sizing` (`/right-sizing`).

Invoke as `/self-healing-loop`.

## Platform max window

`MAX_WINDOW` = Claude Code session-loop max TTL from **this create**
(currently **7 days**). All full-window checks use this value.

## Renew contract (always max length)

Running `/self-healing-loop` **always** resets the schedule clock to
`MAX_WINDOW`. Do **not**:

- only list or “check” the existing job without recreating it
- extend, patch, or reuse the old job’s remaining TTL
- copy the previous `expires_local` into the new fire body
- skip create because a matching job already exists
- treat agent-written body timestamps alone as proof when platform metadata
  shows a shorter remaining TTL

Always: **create a new** session-only hourly job with
`created_local = now` and `expires_local = now + MAX_WINDOW`, **confirm**
full-window success, **then** delete every other matcher so exactly one job
remains with remaining **≥ MAX_WINDOW − 1 hour** at confirm. That is both
first-time bootstrap and mid-life renew.

## Why session-only

Fires open PRs and touch the live cluster. A durable multi-session schedule
can run in every open agent session and cause concurrent runs, duplicate PRs,
and git races. Keep the schedule **session-only** so one session owns it.
Re-run this skill in the session that should own the loop (and whenever you
want a fresh full-window TTL). One renew at a time in a session — if another
`/self-healing-loop` is already mid-run, **wait** for it to finish; if you
cannot wait, **fail-closed** (do not create/delete), emit the timing table
with `renew: fail-closed`, and stop. Do **not** silent-skip or race deletes.
On concurrent fail-closed, best-effort read-only list to fill expire/remaining
when possible.

Do **not** use Routines, Desktop `/schedule`, or other durable multi-session
schedulers unless the user explicitly accepts concurrent-session risk.

## Journal path (orchestrator only)

Investigation journal content is owned by `/self-healing`. This skill only
ensures the shared path exists:

- **Path:** `.scratchpad/SELF_HEALING.md` at the repo root
- Create `.scratchpad/` and the file if missing (empty file is fine)
- Do not invent a second journal, rewrite history, or commit `.scratchpad/`

## Matcher (single-job invariant)

A job is a **match** when its prompt contains the fixed token
`otaru-self-healing-loop-fire` **or** (legacy) is a recurring **hourly** fire
that instructs running `/self-healing` as the body (not
`/self-healing-loop`). Prefer over-delete of matching self-healing schedules
over leaving a second fire path. When deleting, note match reason
(`token` | `legacy-hourly`).

## Fire composition (what the schedule runs)

Materialize **absolute** fields into the fire body (`job_id`,
`created_local`, `expires_local` = this create’s `now + MAX_WINDOW`). Do
**not** paraphrase or expand the fire with investigation, right-sizing gates,
or merge-policy. Use this template **verbatim** (fill fields; use local
datetimes as `YYYY-MM-DD HH:MM` with explicit offset/zone, e.g.
`2026-07-09 20:15 +0100`):

```text
otaru-self-healing-loop-fire
job_id: <id>
created_local: <YYYY-MM-DD HH:MM ±ZZZZ>
expires_local: <created_local + MAX_WINDOW>

F1) if re-list shows not exactly one matcher (renew mid-flight), or a prior
    /self-healing or /right-sizing run in this session is still running, skip
    investigation (F3) but still run finally (F4). Reason e.g.
    skipped: renew in progress (N matchers) | skipped: prior run in progress.
F2) record local start datetime.
F3) run /self-healing once (that skill owns investigation, fixes, journal
    content, merge-policy, branch-cleanup, and whether to invoke
    /right-sizing).
F4) finally (always — success, skip, or failure of F3):
    - ensure .scratchpad/SELF_HEALING.md exists (create if missing)
    - re-list the single matcher if possible; effective_expire =
      platform metadata if present, else expires_local from this body
    - report local time:
      - this round start datetime (or skip time)
      - this round end datetime
      - scheduled job expire datetime (= effective_expire)
      - time remaining (= effective_expire − now)
      - if skipped: one-line reason
```

**Never** put `/self-healing-loop` in the fire body (bootstrap churn).

## Timing table (every exit)

**Record Round start at skill entry** (before Step 1). Emit this table on
**every** exit after entry (success, skip, or fail-closed), with best-known
fields and `n/a` where unknown. Set **Round end** only when the run stops
(after Step 5 investigate/skip/**failure**, or on earlier fail-closed).

| Field                | Meaning                                                                 |
| -------------------- | ----------------------------------------------------------------------- |
| Round start          | Skill entry (local)                                                     |
| Round end            | When this run stops (local)                                             |
| Keeper job_id        | Confirmed new keeper, or `n/a`                                          |
| Deleted match ids    | Removed ids, or `none` / `n/a`                                          |
| Leftover match ids   | Matchers still present that should not be; `none` on success            |
| pre_remaining        | Step 1 baseline (min if multi; or `n/a`)                                |
| Job expires          | Effective expire (platform or body); prior if fail-closed               |
| Remaining at confirm | After Step 3/4; **≥ MAX_WINDOW − 1h** required for `renew: full-window` |
| Remaining at report  | At Round end (informational; may be lower after long Step 5)            |
| renew                | `full-window` (Steps 1–4 succeeded) or `fail-closed`                    |
| investigation        | `ran` / `skipped: …` / `failed: …` / `n/a`                              |

`renew` reflects **schedule** outcome only. Investigation outcome goes in
`investigation`, never flips a proven `full-window` renew to fail-closed.

## Bootstrap / renew steps

Every run executes **all** steps below (bootstrap and renew are the same
path). Goal after Step 4: **exactly one** matcher whose id is the keeper and
whose remaining at confirm is **≥ MAX_WINDOW − 1 hour**.

**Effective expire** (everywhere): platform expire/remaining if present, else
body `expires_local`. Never treat body alone as proof when platform shows a
shorter remaining TTL.

**Step 1. List existing jobs (pre-renew baseline).** `CronList` or equivalent.
Require a **successful complete** list. If list fails or is inconclusive after
a bounded retry: do **not** create or delete, emit the timing table
(`renew: fail-closed`), stop, and tell the user.

For every **match**, record: `id`, body timestamps if present, platform
expire/remaining if present, and
`pre_remaining = effective_expire − now`. Do **not** stop here even if a
match already exists — renew requires a new full-window job.

**Step 2. Create the new schedule first (max window from now).** Prefer Claude
native `/loop` with a **fixed hourly** interval (not bare maintenance `/loop`,
not dynamic-only). Prefer cadence off wall-clock `:00` / `:30` when the
platform lets you pin cron; otherwise `/loop 1h`. Example shape:

```text
/loop 1h
otaru-self-healing-loop-fire
job_id: pending
created_local: <now>
expires_local: <now + MAX_WINDOW>
…rest of fire template verbatim…
```

When the platform accepts a TTL/expires parameter, set it to **`MAX_WINDOW`**
at create (both `/loop` and CronCreate).

**Materialize absolute fields (required) — clock starts at this run:**

1. Set `created_local` = **now** and `expires_local` = **now + MAX_WINDOW**
    **before** create. Never reuse the previous job’s timestamps.
2. Create with matcher token + those absolute timestamps. Use
    `job_id: pending` only until the platform returns an id.
3. After create: fill `job_id` on **this newly created keeper only**
    (in-place update of the keeper prompt if supported). If a second create is
    required to bake the id, treat the second as keeper and the first as an
    “other” to delete later. **Never** patch timestamps/TTL on a pre-existing
    (Step 1) matcher as a renew.
4. Do **not** finish Step 2 while the keeper body still has unfilled
    placeholders. If absolute fields cannot be written, or the platform cannot
    create a session-only max-TTL job: cancel only the new job(s), leave prior
    matchers intact, emit the **timing table** (`renew: fail-closed`), stop,
    and tell the user.
5. Run Steps 2–3 contiguously — do not handle scheduled fires until re-list
    shows exactly one matcher after Step 4 cleanup. Fires deferred during
    Steps 2–4 are **covered by Step 5** — do not also execute those fire
    bodies after cleanup.

**CronCreate fallback** (only if `/loop` unavailable):

```text
recurring: true
durable:   false   # session-only; do not omit
cron:      37 * * * *   # hourly; any fixed minute except :00/:30 if 37 taken
prompt:    <verbatim fire template with absolute timestamps>
```

**Step 3. Confirm the keeper (before deleting olds).** Re-list with a
**bounded retry/backoff** after create (create→list lag). Require:

- session-only / **`durable: false`** (or equivalent)
- keeper body has matcher token + concrete `expires_local`
- **keeper id is new:** when Step 1 was non-empty, keeper id **must not** be
  in the Step 1 id set (platform full-window metadata alone is not enough to
  re-own a pre-renew id). When Step 1 was empty, the create result is the
  keeper
- **full-window band:** effective remaining (platform first if present, else
  body) **≥ MAX_WINDOW − 1 hour** — this is the only place the band gates
  success

**Fail-closed (do not delete olds yet):** if durable without explicit user
opt-in, if keeper is not proven full-window/new, or if re-list stays
inconclusive after retries — cancel/delete **only the new job(s)**, leave
prior matchers intact, re-list and record **Leftover match ids**, emit the
**timing table** (`renew: fail-closed`), stop, and tell the user.

**Step 4. Delete every other matching job.** Only after Step 3 passes. Keep
only the keeper id (the Step 2 create confirmed in Step 3). Bounded loop:
re-list → delete every match whose id **≠** keeper → re-list. **Success only
when** the sole matcher id **equals** the keeper **and** remaining at confirm
is still **≥ MAX_WINDOW − 1 hour**. Never delete the keeper. If retries cannot
reach that state: stop before Step 5, emit the **timing table**
(`renew: fail-closed`) with **Leftover match ids**, and do not claim renew
success.

**Step 5. Run once now (delegate).** Ensure journal path exists. Then:

- **skip** investigation if any `/self-healing` or `/right-sizing` **started
  or finished since Round start** (including a fire during Steps 2–4), or if
  one is still running; note that under `investigation`
- else invoke **`/self-healing` once**

Do not re-implement investigation or right-sizing here.

**Always** (success, skip, or failure of the delegated run, including missing
kubeconfig/VIP): set Round end, fill `investigation`, and emit the timing
table. If Steps 1–4 already succeeded, keep `renew: full-window` even when
investigation fails or is skipped. Remaining at report is informational.

## Notes

- Default is session-only `/loop` with **`durable: false`**. Durable /
  multi-session only if the user explicitly asks and accepts concurrent-
  session risk. **Even then**, single matching job, verbatim fire composition,
  max window, expire/remaining report, and never schedule `/self-healing-loop`
  as the fire still apply.
- **Checkout** is required for skill/journal paths. **Kubeconfig** is required
  only for Step 5’s `/self-healing`. Always run Steps 1–4 renew-to-max even if
  the API VIP is unreachable; if kubeconfig/VIP is missing, skip or fail only
  Step 5 after a successful full-window renew and still report the table with
  `renew: full-window` and `investigation: failed: …` or `skipped: …`.
- Entrypoints: `/self-healing-loop` = schedule orchestrator only;
  `/self-healing` = one-off investigation work (including each scheduled fire).
