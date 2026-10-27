# zot

This chart deploys zot. Zot is the OCI registry that caches the
images and charts the cluster pulls. The wrapper chart pins the
upstream zot chart. The wrapper also carries the cluster-specific
parts: the internal route, the gateway and mesh authorisation
policies, the sync credentials ExternalSecret, the service account
and the PodDisruptionBudget.

## Files

- `values.yaml` holds the full zot configuration. It holds the
  sync entries, the retention policy, the resources and the data
  volume. Edit this file by hand.
- `cidrs.json` holds one /32 per node. The /32 is the base address
  of the node pod CIDR. The route SecurityPolicy allows exactly
  these sources.
- `templates/` holds the internal HTTPRoute, the SecurityPolicy,
  the AuthorizationPolicies, the sync ExternalSecret, the service
  account and the PodDisruptionBudget.

## Sync configuration

The sync configuration lives in `values.yaml`. It has one
on-demand entry per upstream host, for 12 hosts in total. Zot
fetches an image or a chart from the upstream host at the first
pull. Zot then serves the content from its own storage. The
dhi.io entry checks its manifests every 24 hours. Each other
entry checks every 1 hour. Each entry uses a 60 second sync
timeout.

## Retention

One retention policy covers all repositories. The policy deletes
untagged content. The policy keeps a tag for 90 days after the
last pull of that tag. After 90 days without a pull, garbage
collection deletes the tag. A tag that must survive must get a
pull at least once in each 90 day window.

A tag that a client pulls in full is safe from the stale prune.
Content that a client fetches by manifest only can get a prune
at the next garbage collection, even when a retention policy
keeps it. Zot v2.1.22 logs the retention keep and the stale
prune for the same digest in that case.

## Node changes

When a node is added or replaced, edit `cidrs.json` by hand in
the same change. Add the node with its pod CIDR, and set its
`cidr` field to the base address of that pod CIDR as a /32. The
route SecurityPolicy then matches the live node pod CIDRs.

## Upgrades

Re-run Gate 2 after every zot upgrade. Gate 2 is the live
verification set for the registry. It checks a pinned image
pull and an on-demand pull. Each pull must match its digest
exactly. It checks that a pull from an ordinary pod gets a
denial. It checks that the metrics scrape answers with the zot
target up. An upgrade is not done when the pod is healthy. An
upgrade is done when Gate 2 passes on the new version.

## Before maintenance

Zot is an accelerator. It is never a dependency. Before
Longhorn, gateway or internal DNS maintenance, remove the node
mirror block or scale zot to zero. Then prove that direct pulls
work. Charts need no equivalent action. Chart renders fall back
to the upstream chart repositories when zot does not answer.

## Access

Zot has no local users and no auth of its own. The mesh grants
the gateway method- and path-scoped access at the waypoint. The
workload policy is port-only, because ztunnel cannot apply L7
rules. The gateway route admits the node sources for GET and
HEAD only.

## Sync credential rotation

The sync credential is the existing 1Password item `Docker`.
This chart creates no credential for zot. A rotation ends only
when all three proofs hold. The new credential works. The old
credential no longer authenticates. The provider revoked the
old credential. A rotation that skips revocation is not
complete.
