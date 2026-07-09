# CI/CD Health

Scheduled workflows can fail silently for a long time — nothing in the
cluster reflects a broken automation until a human notices. Check for it
directly rather than only reacting to reports.

## Checks

Discover scheduled workflows under the repo root:

```bash
# list workflow files that declare an on.schedule trigger
rg -l 'schedule:' .github/workflows
```

For each matching file, check recent runs:

```bash
gh run list --workflow <file> --limit 5 --json conclusion,status,displayTitle,createdAt
```

Three or more consecutive `failure` conclusions means it is silently broken,
not flaky.

## Triage

- Diagnose via `gh run view <id> --log-failed`.
- A transient infrastructure error (network 5xx during a tool download,
  runner setup failure) unrelated to the workflow content just needs
  `gh run rerun <id> --failed` — do not treat it as a code problem.
- Otherwise GitOps-fix the workflow file. Treat workflow / CI-config
  edits as **non-trivial** (stop at green for the user) unless the change
  is a pure syntax nit with no trigger/permission/secret impact.
