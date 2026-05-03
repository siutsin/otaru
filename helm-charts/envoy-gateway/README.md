# envoy-gateway

`gateway-api` must stay out of the Istio ambient dataplane.

This chart explicitly sets `istio.io/dataplane-mode: none` on the
`gateway-api` namespace and on the generated Envoy Gateway pods. The shared
ambient waypoint lives in `istio-waypoints` and is for application services
behind the gateway, not for the gateway proxy itself.

If Envoy Gateway is ambient-enrolled, ingress traffic can fail with `503
upstream_reset_before_response_started{connection_termination}` even when the
backend services are healthy. In-cluster traffic to the services will still
work, but external requests through the ingress VIP can break.

Keep `gateway-api` outside ambient unless the ingress design is changed and
re-validated end to end.
