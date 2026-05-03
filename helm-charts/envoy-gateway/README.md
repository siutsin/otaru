# envoy-gateway

The Envoy Gateway controller and ingress proxy use different namespaces.

- `envoy-gateway-system` hosts the Envoy Gateway controller and stays
  `istio.io/dataplane-mode=none`
- `gateway` hosts the `Gateway` resource and generated Envoy proxy, and is
  `istio.io/dataplane-mode=ambient`

This chart enables Envoy Gateway Gateway Namespace Mode so the generated Envoy
proxy `Deployment` and `Service` live in `gateway`, not alongside the
controller. That lets TCP and HTTP ingress traffic originate from an ambient
workload and use the mesh path to ambient backends.

UDP listeners can remain on the same Envoy Gateway, but they still do not gain
Istio mTLS. This chart change is about the TCP and HTTP ingress path.

The shared ambient waypoint still lives in `istio-waypoints` for east-west L7
handling. The ingress proxy is ambient-enrolled, but it is not enrolled to use
that shared waypoint itself.
