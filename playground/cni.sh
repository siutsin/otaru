#!/bin/bash

set -euxo pipefail

# Apply Gateway API CRDs
helm upgrade --install gateway-api helm-charts/gateway-api \
  -n kube-system

# Apply Cilium with the first master node's API server address
helm upgrade --install cilium helm-charts/cilium \
  -n kube-system \
  --set cilium.k8sServiceHost="$(multipass info master00 --format json | jq -r '.info["master00"].ipv4[1]')"

# Wait for the deployment to be successfully rolled out.
kubectl rollout status deploy/cilium-operator -n kube-system --timeout=15m
kubectl rollout status ds/cilium-envoy -n kube-system --timeout=15m
kubectl rollout status ds/cilium -n kube-system --timeout=15m
kubectl rollout status deploy/hubble-relay -n kube-system --timeout=15m
kubectl rollout status deploy/hubble-ui -n kube-system --timeout=15m

# Assign dedicated virtual IP to Kubernetes api-server service
helm upgrade --install gateway-api-kubernetes helm-charts/gateway-api-kubernetes \
  -n default \
  --set l2AnnouncementPolicy.interface=enp0s2

# Apply service routes
helm upgrade --install gateway-api-routes helm-charts/gateway-api-routes \
  -n kube-system \
  --set l2AnnouncementPolicy.interface=enp0s2

# Configure nodes to use LB api-server IP
LB_API_SERVER_IP="https://192.168.1.52"
# master nodes except the first master node
for master_node in $(multipass list --format json | jq -r '.list[] | select(.name | test("^master[0-9]{2}$")) | select(.name != "master00") | .name'); do
    multipass exec "$master_node" -- sudo sed -i "s|'https://.*:6443'|'https://$LB_API_SERVER_IP'|" /etc/systemd/system/k3s.service
    multipass exec "$master_node" -- sudo systemctl daemon-reload
    multipass exec "$master_node" -- sudo systemctl restart k3s
    # when k3s server restart, it will update the kubernetes service and revert the change of LoadBalancer type
    kubectl patch service kubernetes -n default -p '{"spec": {"type": "LoadBalancer"}}'
done
for worker_node in $(multipass list --format json | jq -r '.list[] | select(.name | test("^worker[0-9]{2}$")) | .name'); do
    multipass exec "$worker_node" -- sudo sed -i "s|^K3S_URL=.*|K3S_URL='$LB_API_SERVER_IP'|" /etc/systemd/system/k3s-agent.service.env
    multipass exec "$worker_node" -- sudo systemctl daemon-reload
    multipass exec "$worker_node" -- sudo systemctl restart k3s-agent
done

