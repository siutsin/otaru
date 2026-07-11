# Unused / Orphan Resources

Low priority, slow-moving category — cadence-gated like right-sizing, not
run every pass. Detects resources that are no longer referenced by
anything, not misconfiguration.

## Cadence gate

Run only if there is no `### unused-resources pass` entry in
`.scratchpad/SELF_HEALING.md` within the last 7 days. Otherwise skip this
category entirely for the current pass.

## Checks

Run `kor`, scoped to the kinds that have produced real signal in practice
(skip `replicaset` and `crd` entirely — expected steady-state noise, not
drift; treat `clusterrolebinding`/`rolebinding` output with heavy
scepticism, see below):

```bash
kor configmap --show-reason -o json
kor secret --show-reason -o json
kor storageclass --show-reason -o json
kor serviceaccount --show-reason -o json
kor job --show-reason -o json
```

## Triage

Read `documentation/gotcha.md` ("`kor` unused-resource scanner has a high
false-positive rate") before acting on any finding — most raw hits are not
real. Do not treat a raw `kor` result as evidence on its own:

- **ConfigMap / Secret:** most hits are resources read via the Kubernetes
  API by a controller (Istio CA distribution, leader-election, webhook
  TLS, heartbeat-operator, cert-manager `Issuer`/`Certificate` spec refs)
  rather than mounted into a pod — `kor` cannot see this reference style.
  Before flagging anything as genuine, check whether a controller in the
  same or a related namespace reads it via the API (logs, CRD spec
  fields) before assuming it is orphaned.
- **ClusterRoleBinding / RoleBinding:** verify every hit directly with
  `kubectl get clusterrole <name>` / confirm the subject ServiceAccount
  exists in its own namespace with `kubectl get sa -n <subject-namespace>
  <name>`. A prior run hit a `kor` internal bug
  (`Failed to get clusterRoles: ... parsing "kyverno"`) that made every
  `ClusterRoleBinding` in that scan look like a false orphan — see
  `documentation/gotcha.md`.
- **StorageClass:** cross-check with `kubectl get pvc -A -o
  jsonpath='{range .items[*]}{.spec.storageClassName}{"\n"}{end}' | sort
  -u` — only flag a StorageClass with zero PVCs referencing its exact
  name.
- **Job:** a `kor`-flagged Job that has simply completed
  (CronJob-spawned) is expected, not a finding.

Only journal a candidate once cross-checked and still looking genuine.

## Action

**Never auto-delete or open an unattended removal PR from this check —
always escalate**, even for a candidate that looks clearly safe. The
demonstrated false-positive rate is too high, and unlike a resource
request/limit tweak, a wrong deletion is not easily undone. Journal the
candidate and its cross-check evidence, then stop:

```markdown
### issue unused resource: <namespace>/<kind>/<name>

- **symptom:** kor flagged <kind> as unused; cross-checked <what you checked>
- **cause:** appears genuinely unreferenced
- **action:** none — escalated
- **result:** escalated
```

Journal marker for the cadence gate (write this even when nothing new was
found, so the 7-day gate above has something to check against):

```markdown
### unused-resources pass

- **kor:** kinds scanned and raw counts, or path to saved output
- **new-genuine-candidates:** list or `none`
- **result:** `no-op` | `escalated`
```
