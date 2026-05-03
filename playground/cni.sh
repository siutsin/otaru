#!/bin/bash

set -euxo pipefail

# Apply Gateway API CRDs
helm upgrade --install gateway-api helm-charts/gateway-api \
  -n kube-system

# Apply MetalLB before assigning LoadBalancer IP addresses
helm upgrade --install metallb helm-charts/metallb \
  -n metallb-system \
  --create-namespace

# Wait for the deployment to be successfully rolled out.
kubectl rollout status deployment/metallb-controller -n metallb-system --timeout=15m
kubectl rollout status daemonset/metallb-speaker -n metallb-system --timeout=15m

# Deploy k3s-apiserver-loadbalancer to watch and update the Kubernetes service to LoadBalancer type
helm upgrade --install k3s-apiserver-loadbalancer helm-charts/k3s-apiserver-loadbalancer \
  -n k3s-apiserver-loadbalancer-system \
  --create-namespace

# Assign dedicated virtual IP to Kubernetes api-server service
helm upgrade --install gateway-api-kubernetes helm-charts/gateway-api-kubernetes \
  -n default \
  --set l2AnnouncementPolicy.interface=eth0

# Apply Envoy Gateway
helm upgrade --install envoy-gateway helm-charts/envoy-gateway \
  -n envoy-gateway-system \
  --create-namespace \
  --set bootstrap.enabled=true \
  --set tls.secretName=envoy

kubectl rollout status deployment/envoy-gateway -n envoy-gateway-system --timeout=15m
kubectl wait deployment -n gateway -l gateway.envoyproxy.io/owning-gateway-name=gateway --for=condition=Available=True --timeout=15m

# Configure nodes to use LB api-server IP
LB_API_SERVER_IP="https://192.168.10.50"
# master nodes except the first master node
for master_node in $(multipass list --format json | jq -r '.list[] | select(.name | test("^master[0-9]{2}$")) | select(.name != "master00") | .name'); do
    multipass exec "$master_node" -- sudo sed -i "s|'https://.*:6443'|'https://$LB_API_SERVER_IP'|" /etc/systemd/system/k3s.service
    multipass exec "$master_node" -- sudo systemctl daemon-reload
    multipass exec "$master_node" -- sudo systemctl restart k3s
done
for worker_node in $(multipass list --format json | jq -r '.list[] | select(.name | test("^worker[0-9]{2}$")) | .name'); do
    multipass exec "$worker_node" -- sudo sed -i "s|^K3S_URL=.*|K3S_URL='$LB_API_SERVER_IP'|" /etc/systemd/system/k3s-agent.service.env
    multipass exec "$worker_node" -- sudo systemctl daemon-reload
    multipass exec "$worker_node" -- sudo systemctl restart k3s-agent
done
