#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

NODE_NAME="${1:-raspberrypi-00}"

if ! command_exists kubectl; then
  exit_with_error "kubectl is not installed or not in PATH"
fi

log_info "Checking node status for ${NODE_NAME}"
kubectl get node "${NODE_NAME}" -o wide
echo ""

log_info "Checking Argo application health"
kubectl -n argocd get applications.argoproj.io \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
echo ""

log_info "Checking Longhorn node health"
kubectl -n longhorn-system get nodes.longhorn.io -o wide
echo ""

log_info "Checking Longhorn volume health"
kubectl -n longhorn-system get volumes.longhorn.io \
  -o custom-columns='NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness,NODE:.status.currentNodeID'
echo ""

log_info "Checking workloads currently on ${NODE_NAME}"
kubectl get pods -A -o wide --field-selector "spec.nodeName=${NODE_NAME}"
echo ""

log_info "Running drain dry-run for ${NODE_NAME}"
kubectl drain "${NODE_NAME}" --ignore-daemonsets --delete-emptydir-data --dry-run=client
echo ""

log_success "Pre-flight checks completed for ${NODE_NAME}"
