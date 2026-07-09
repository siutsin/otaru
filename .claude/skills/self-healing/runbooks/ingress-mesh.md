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

## P2 path: Service mesh

- `kubectl -n istio-system get pods` — mesh dashboard or ambient components
  not ready (Istio on this cluster). Do not fix; skip the journal unless an
  app symptom ties to mesh (then journal as `open`).
