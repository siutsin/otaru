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

## Heartbeat down: Cloudflare Access WebGazer IP allowlist stale

**Symptom:** `kubectl get heartbeat -A` (or a user-reported "otaru heartbeat
down" alert) shows one `Heartbeat` `healthy: false` with `lastStatus: 403`
and `message: status code is not within expected ranges`, while every other
Heartbeat CR is healthy and the rest of the cluster (nodes, pods, Argo CD
Applications) checks out clean.

**Confirm it is this, not a real backend problem:**

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
