# Gotchas

Non-obvious behaviours and workarounds discovered while working in this repo.

## changedetection `latest` image tag resets the watch list

**Problem:** The changedetection deployment lost its entire watch list and
came back with only the fresh-install defaults.

**Why it happens:** The image was pinned as
`ghcr.io/dgtlmoon/changedetection.io:latest@sha256:...`. The `latest` label is
mutable, so a Renovate digest bump or a fresh pull can land a newer
changedetection release on restart. Newer releases run datastore migrations
(the datastore moved to a per-watch `{uuid}/watch.json` layout with settings
in `changedetection.json`). A migration that does not carry the old watches
over leaves the app looking freshly installed.

**Recovery limits:** The Longhorn `backup` recurring job for
`changedetection-vol` is weekly (`0 4 * * 0`) with `retain: 1`. Only the most
recent weekly snapshot/backup is kept, so once a bad state is captured it
overwrites the last good copy within a week. There is no restore point older
than the loss. Treat changedetection watch data as low-durability until the
retention window is deepened.

**Fix:** Pin the image to a concrete version tag instead of `latest` in
`helm-charts/changedetection/values.yaml`. Version `0.55.7` resolves to the
same digest `latest` currently points to, so pinning is a no-op for the
running pod while stopping uncontrolled migrations. Renovate then proposes
controlled version bumps that can be reviewed before they apply.
