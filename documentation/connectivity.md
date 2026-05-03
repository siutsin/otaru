# Istio Connectivity

Current state as of `2026-05-03`:

- Istio runs in ambient mode
- most application namespaces are ambient-enrolled
- one shared waypoint provides L7 handling for enrolled services
- that shared waypoint lives in `istio-waypoints`
- Envoy Gateway uses a split control plane and data plane

## Components

- `istiod`: control plane in `istio-system`
- `istio-cni`: ambient redirection setup on nodes
- `ztunnel`: one pod per node for L4 ambient transport
- `waypoint`: shared Envoy waypoint in `istio-waypoints`
- `envoy-gateway`: controller in `envoy-gateway-system`
- `gateway`: Envoy Gateway proxy in `gateway`

## Namespace Model

The cluster uses four connectivity roles:

- application namespaces: ambient-enrolled and configured to use the shared waypoint
- `gateway`: ambient-enrolled ingress data plane
- `istio-waypoints`: hosts the shared waypoint and stays outside ambient
- `envoy-gateway-system`: hosts the Envoy Gateway controller and stays outside ambient

Some platform namespaces also stay outside ambient when they do not need the
ambient traffic path.

## North-South Connectivity

Traffic entering the cluster follows this path:

1. a client reaches the Envoy Gateway load balancer at `192.168.10.51`
2. the Envoy Gateway proxy in `gateway` matches a `Gateway` listener and `HTTPRoute`
3. if the destination service is ambient-enrolled and configured to use the shared waypoint, ingress traffic is sent through the shared waypoint
4. the destination node `ztunnel` forwards traffic to the target pod

This applies to TCP and HTTP traffic. UDP listeners can stay on Envoy Gateway,
but they do not gain Istio mTLS.

### Current North-South Path

```mermaid
flowchart LR
  U["Client"] --> EG["Envoy Gateway Proxy\nNamespace=gateway\nGateway=gateway\nVIP=192.168.10.51"]
  EG --> W["Shared Waypoint\nNamespace=istio-waypoints\nGateway=waypoint\nHBONE 15008"]
  W --> ZD["Destination ztunnel"]
  ZD --> P["Application Pod"]
```

### Important Constraint

The controller and proxy need different ambient treatment:

- `envoy-gateway-system` stays `istio.io/dataplane-mode=none`
- `gateway` is ambient-enrolled so TCP and HTTP traffic from the ingress proxy can use the mesh path to backends

## East-West Connectivity

For ambient-enrolled services, the path is:

1. the source workload sends traffic normally
2. source node `ztunnel` captures it
3. traffic is forwarded over HBONE to the shared waypoint
4. the waypoint applies service-level L7 handling
5. traffic is forwarded toward the destination workload

### Current East-West Path

```mermaid
flowchart LR
  subgraph N1["Source Namespace (ambient)"]
    A["Source Pod"]
  end

  subgraph Z1["Source Node"]
    ZS["ztunnel"]
  end

  subgraph G["istio-waypoints"]
    W["Shared Waypoint\nGateway=waypoint\nService=waypoint:15008"]
  end

  subgraph Z2["Destination Node"]
    ZD["ztunnel"]
  end

  subgraph N2["Destination Namespace (ambient)"]
    B["Destination Pod"]
  end

  A --> ZS
  ZS -->|"HBONE / mTLS"| W
  W -->|"service-level L7 handling"| ZD
  ZD --> B
```

### What This Means

- L4 transport and mTLS come from `ztunnel`
- L7 policy and HTTP/gRPC telemetry come from the shared waypoint
- east-west traffic does not use sidecars
- the shared waypoint is the main L7 choke point for enrolled services

## Non-Ambient Connectivity

Workloads outside ambient do not use the ambient service path.

```mermaid
flowchart LR
  A["Source Pod"] --> B["Kubernetes networking"]
  B --> C["Destination Pod or Service"]
```

Current examples:

- `envoy-gateway-system`
- `istio-system`
- `istio-waypoints`
- `kube-system`
- UDP ingress paths such as `blocky` DNS and Home Assistant CoAP

## Operational Consequences

- enrolled services get ambient L4 transport through `ztunnel`
- enrolled services get L7 visibility through the shared waypoint
- Kiali HTTP insights depend on traffic passing through the waypoint path
- the shared waypoint reduces resource usage compared with one waypoint per namespace
- the tradeoff is a shared L7 blast radius across many namespaces
