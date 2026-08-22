# Ingress and Mesh

## P0 path: Gateway

- `kubectl get gateway,httproute -A` — backends unhealthy or routes not
  attached? Check `envoy-gateway-system` and `gateway` pods (user-facing
  ingress VIP `192.168.10.51`).

### Load-balancer VIP reachability

Gateway/HTTPRoute `Programmed`/`Attached` and pod `Running` can all be true
while the LoadBalancer VIP itself is silently unreachable at L2. On this
cluster the LoadBalancer is MetalLB — grep
`kubectl -n metallb-system logs -l app=metallb,component=speaker --tail=200`
for `"the specified interfaces used to announce LB IP don't exist"`.

This fires whenever a node's real NIC name does not match the
`L2Advertisement`'s `interfaces` list for the pool it is announcing — see
`documentation/gotcha.md` for the exact node/interface mismatch on this
cluster (`nuc-00` uses `eno1`, Pis use `eth0`). GitOps-fix by splitting
the `L2Advertisement` per node (`nodeSelectors` + the correct `interfaces`
value for that node). For the API VIP (`.50`) mirror
`helm-charts/metallb-vip/values.yaml`; for the gateway VIP (`.51`) mirror
the L2Advertisement split in `helm-charts/envoy-gateway` (same per-node
interface pattern).

If speaker logs are clean but a VIP still flaps unreachable from off-cluster
clients, also consider RPi ARP/promisc issues documented in
`documentation/gotcha.md` — host networking fixes are **escalate** (not
unattended GitOps).

### Envoy Gateway upgrade drops UDPRoute/TCPRoute after a Gateway API CRD version gap

**Symptom:** after bumping `helm-charts/envoy-gateway` (`gateway-helm`) to a
newer version, UDP/TCP-based routes stop working — this cluster's shared
Gateway VIP `192.168.10.51` serves DNS (Blocky, 53 TCP/UDP), CoAP
(Home Assistant, UDP 5683), and SFTP (Jellyfin, TCP 2022) alongside normal
HTTPS — while `HTTPRoute`-based ingress on the same VIP keeps working fine.
`kubectl get gateway <name> -n <ns> -o jsonpath='{range
.status.listeners[*]}{.name}{": "}{.attachedRoutes}{"\n"}{end}'` shows
`attachedRoutes: 0` for the affected TCP/UDP listeners while `https` stays
non-zero.

**Cause:** a newer Envoy Gateway version can require Gateway API **v1**
`TCPRoute`/`UDPRoute` CRDs. If this cluster's `gateway-api` CRD chart still
only serves `v1alpha2`, the controller logs (on the `envoy-gateway` pod)
exactly this at startup:

```text
UDPRoute CRD not found, skipping UDPRoute watch
TCPRoute CRD not found, skipping TCPRoute watch
```

Confirm which API versions are actually served:
`kubectl get crd udproutes.gateway.networking.k8s.io
tcproutes.gateway.networking.k8s.io -o jsonpath='{.spec.versions[*].name}'`.

**Fix (GitOps, trivial):** bump `helm-charts/gateway-api`'s CRDs to a version
that serves `v1` for `TCPRoute`/`UDPRoute` (this cluster: `v1.6.1`), and
update any `TCPRoute`/`UDPRoute` manifests' `apiVersion` from `v1alpha2` to
`v1` to match. After merge, apply the new CRDs server-side and restart
`envoy-gateway` rather than waiting for its own reconcile loop:

```bash
kubectl apply --server-side --force-conflicts -f helm-charts/gateway-api/crds/
kubectl rollout restart deployment/envoy-gateway -n envoy-gateway-system
```

Precedent: `gateway-helm` `1.9.0` (PR #3086) broke this; fixed by bumping
`gateway-api` CRDs to `1.6.1` (PR #3087), 2026-08-22.

**Verification caveat:** `attachedRoutes` on the Gateway status can lag —
it stayed `0` in one observed case even after Argo synced the fix and live
traffic had already recovered. Verify with a real protocol-level test
(e.g. `dig @<vip> <host>` for DNS) rather than trusting the counter alone.

## Heartbeat down: Cloudflare Access 403

**Symptom:** `kubectl get heartbeat -A` (or a user-reported "otaru heartbeat
down" alert) shows one `Heartbeat` `healthy: false` with `lastStatus: 403`
and `message: status code is not within expected ranges`, while every other
Heartbeat CR is healthy and the rest of the cluster (nodes, pods, Argo CD
Applications) checks out clean.

**Step 1 — confirm it is Cloudflare Access, not a workload problem:**

```bash
kubectl get heartbeat <name> -n <namespace> -o yaml   # read status + spec.endpointsSecret
TARGET=$(kubectl get secret <endpointsSecret.name> -n <namespace> \
  -o jsonpath='{.data.<targetEndpointKey>}' | base64 -d)
curl -sI "$TARGET"   # look for cf-access-domain / cf-access-aud response headers
```

Cloudflare Access response headers (`cf-access-domain`, `cf-access-aud`) on
a 403 confirm Cloudflare Access rejected the request before it reached the
cluster — this is not a workload or GitOps issue, do not chase pods/Argo CD
for this symptom.

**Step 2 — find out who is actually making the check. Do not assume it is an
external probe (e.g. WebGazer) without checking.** The `heartbeats-operator`
(`heartbeats-operator-controller-manager` in
`heartbeats-operator-system`) performs the target health check **itself,
from inside the cluster**, for every `Heartbeat` CR — the `healthyEndpoint`/
`unhealthyEndpoint` URLs it also calls (e.g. `heartbeat.webgazer.io/...`)
are only a dead-man's-switch status *report*, not the entity doing the
probing. Confirm which one actually returned the 403:

```bash
kubectl logs -n heartbeats-operator-system \
  deploy/heartbeats-operator-controller-manager --tail=200 \
  | grep '"name":"<heartbeat-name>"'
```

A `"Health check completed"` line with `"status_code":403` for the target
endpoint confirms the operator pod's own outbound request was denied — this
is the common case for any `Heartbeat` whose target is this cluster's own
public hostname (the request exits via the home router, then hairpins back
in through the Cloudflare Tunnel).

### Common cause: stale "Cluster IP List" after an ISP dynamic-IP change

Because the check originates in-cluster, the source IP Cloudflare Access
sees is the cluster's **own current public egress IP** — not any
third-party service's IP. The bypass policy for this is "Cluster IP List"
(fed by `tfconfig.cloudflare.zone.tunnel_ip_list`, see
`infrastructure/modules/cloudflare-access/cluster.tf`). If the home ISP
reassigns the public IP (e.g. during a WAN outage — see
`documentation/gotcha.md`) and this list still has the old value, the
operator's own check gets 403'd, indefinitely, until the list is updated.

Diagnose:

```bash
# Actual current public egress IP as seen from inside the cluster
kubectl run ip-check-$(date +%s) --image=curlimages/curl --restart=Never \
  --command -- curl -s https://ifconfig.me
# then kubectl logs/delete the pod

# Live Cloudflare Access bypass list contents (Cluster IP List)
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/gateway/lists/<cluster-list-id>/items?per_page=50"
```

If the egress IP is not covered by the list, that is the cause. Confirm it
is a genuine ISP reassignment (not a one-off fluke) by checking who owns
the new IP and how many unrelated ranges that ISP announces:

```bash
whois -h whois.ripe.net <ip>   # confirms owning org/ASN
curl -s "https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS<n>" \
  | python3 -c "import json,sys; print([p['prefix'] for p in json.load(sys.stdin)['data']['prefixes']])"
```

A residential ISP can announce many unrelated blocks (this cluster's ISP:
119 prefixes across 5+ unrelated /16-ish ranges, observed 2026-08-09) —
dynamic-IP reassignment can jump between completely different blocks, not
just rotate within one local pool, so **no CIDR is guaranteed safe
long-term**. Pinning the specific `/21` (or similar) containing the current
IP is a practical middle ground, not a permanent fix — a future
cross-pool reassignment will need this diagnosis repeated.

**Fix — escalate, do not auto-apply.** Unlike the WebGazer allowlist below,
this is **not** a pre-scoped, narrow exception: the right CIDR width is a
judgement call each time (and building an automated IP-sync job is a real
alternative worth raising with the user rather than assuming). Present the
diagnosis and let the user choose:

1. Update `tfconfig.cloudflare.zone.tunnel_ip_list` to the new value
  (`op document edit tfconfig ...` — editing `tfconfig` itself, and only
  `tfconfig`, is fine per `references/escalation.md`; do not read any
  other 1Password item).
2. Sync locally:
  `op document get tfconfig --vault github-otaru > "$OTARU_TF_CONFIG_FILE"`.
3. `terragrunt plan` in `infrastructure/cloud/cloudflare/access` — confirm
  the plan touches **only** `cloudflare_zero_trust_list.cluster` (`0 to
  add, 1 to change, 0 to destroy`).
4. **Escalate the `terragrunt apply` step itself** — ask the user to run it
  or explicitly approve it; do not run it unattended.
5. Verify the same way as the WebGazer fix below (wait for the next
  `Heartbeat` check interval, `status.healthy` flips to `true`).

## Heartbeat down: Cloudflare Access WebGazer IP allowlist stale

Only relevant when Step 2 above actually shows an **external** probe (not
the in-cluster operator) being denied, or as routine hygiene independent of
any specific incident — this list drifting stale does not, by itself,
explain a 403 on a `Heartbeat` whose check the operator performs itself
(the common case above).

**Root cause:** the target hostname sits behind a Cloudflare Zero Trust
Access application (`infrastructure/cloud/cloudflare/access`), with a
policy that lets WebGazer.io's own probe IPs bypass Access
(`infrastructure/modules/cloudflare-access/webgazer.tf`, backed by the
static file `infrastructure/modules/cloudflare-access/ip/webgazer.txt`).
WebGazer rotates its published probe IPs
(`https://api.webgazer.io/ip-addresses`) without notice; the static file
drifts out of sync, an unrecognised probe IP gets 403'd, and the heartbeat
that IP was checking flips unhealthy.

**Fix (routine, user-authorised 2026-08-08 — no need to ask first):**

1. Compare current vs live:
  `diff <(sort infrastructure/modules/cloudflare-access/ip/webgazer.txt) <(curl -s https://api.webgazer.io/ip-addresses | python3 -c "import json,sys; print('\n'.join(sorted(json.load(sys.stdin))))")`
2. Replace the file contents with the current API response, one IP per
  line, sorted the same way as the existing file, trailing newline.
3. `make test` (Terraform/Terragrunt lint only — this does not apply
  anything).
4. `cd infrastructure/cloud/cloudflare/access && terragrunt plan` — confirm
  the plan touches **only** `cloudflare_zero_trust_list.webgazer` (`0 to
  add, 1 to change, 0 to destroy`). If the plan shows anything else,
  stop and escalate instead — the narrow exception covers this exact
  scoped change, not any other drift in this stack.
5. `terragrunt apply -auto-approve` in that same directory.
6. Verify: wait for the `Heartbeat`'s next check (its `interval`, e.g. 5m)
  and confirm `status.healthy` flips to `true`. Note the check
  immediately after `apply` may still fail once (Cloudflare edge
  propagation lag) — that alone is not a fix failure, wait one more
  interval before treating it as unresolved.
7. Commit, push, open a PR referencing the stale-date and the new IP diff.
  Classify as **trivial** and auto-merge once green (same as any other
  single-concern, already-applied, no-secrets change) — the general
  infra-as-code escalation rule does not apply to this specific,
  narrow, pre-scoped fix.

## P2 path: Service mesh

- `kubectl -n istio-system get pods` — mesh dashboard or ambient components
  not ready (Istio on this cluster). Do not fix; skip the journal unless an
  app symptom ties to mesh (then journal as `open`).
