# Branch Cleanup

Trivial PRs auto-merge and usually clean up remotes; non-trivial PRs hold at
green for the user, and squash-merges still leave local branches with
`: gone]` remotes either way. Run this:

- Immediately after every PR's outcome is known.
- Once at the end of **every** self-healing run, whether invoked manually
  or via a scheduled loop, regardless of cluster health and even if no PR
  was opened this run — a safety net for anything merged since the last
  run.

## Steps

1. `git fetch --prune origin`
2. `git branch -vv` — local branches whose remote shows `: gone]` had
    their upstream deleted (a "delete branch after merge" repo setting
    fires on merge).
3. For each `gone` branch, confirm it is actually merged — do not trust
    ancestry alone (`git merge-base --is-ancestor` can say "no" for a
    squash merge even though the PR merged, since squash rewrites the
    commit onto the base branch). Check via
    `gh pr list --state merged --head <branch> --json number,state,mergedAt`.
4. Delete only branches with a confirmed merged PR: `git branch -D <branch>`
    (`-D` because squash-merged history means `-d` will refuse even though
    the branch is genuinely done).
5. Never delete the branch checked out for an in-flight PR, or any branch
    whose PR is not yet merged.

## If CI/PR state looks stuck

If CI checks or `gh pr view` look stuck on a stale commit across multiple
pushes (the same `head.sha` keeps showing despite `git ls-remote` confirming
the push landed), do not assume a sync delay or client-side caching bug.
Check `gh api repos/<owner>/<repo>/pulls/<number> -q '.state, .merged'`
first — the PR has very likely already merged or closed, and every push
after that point went to a dead branch. Reopen from the current base branch
with the missing diff (`git diff <old_head>..<new_head> -- <path> | git
apply -`) rather than pushing further commits to the closed PR's branch.
