# Otaru Cluster Reference

## Paths

All paths below are relative to the otaru repo root.

| Item                 | Path (relative to repo root)                                                       |
|----------------------|------------------------------------------------------------------------------------|
| Self-healing journal | `.scratchpad/SELF_HEALING.md`                                                      |
| Helm charts          | `helm-charts/`                                                                     |
| Argo CD apps         | `argocd/`                                                                          |
| Gotchas              | `documentation/gotcha.md`                                                          |
| Secrets layout       | `documentation/secrets.md`                                                         |
| LUKS unlock          | `documentation/luks_remote_unlock.md`                                              |
| Local secrets        | Outside this repo, machine-local (see `documentation/secrets.md` for the boundary) |

## Network

| IP              | Role                             |
|-----------------|----------------------------------|
| `192.168.10.50` | Kubernetes API VIP               |
| `192.168.10.51` | Internal ingress VIP             |
| `192.168.10.60` | `raspberrypi-00` (control plane) |
| `192.168.10.61` | `raspberrypi-01` (control plane) |
| `192.168.10.62` | `raspberrypi-02` (control plane) |
| `192.168.10.63` | `raspberrypi-03` (worker)        |
| `192.168.10.80` | `nuc-00` (worker)                |

Runtime gate (`SKILL.md`): all five node names above must exist. **Ready** is
checked in `runbooks/access-and-nodes.md`, not at the gate.

## kubectl

Prefer Kubernetes MCP tools for read-only diagnostics when available; fall
back to `kubectl` for the same checks. Use the otaru kubeconfig context. If
multiple contexts exist, select the one that reaches `192.168.10.50` (API
VIP). Port `:6443` may or may not appear in `cluster-info` output — match on
host/VIP. Verify with:

```bash
kubectl cluster-info
kubectl get nodes -o wide
```

## Validation

Before opening a PR, from the repo root:

```bash
make test
```

## Useful namespaces

| Namespace              | Contents                                              |
|------------------------|-------------------------------------------------------|
| `argocd`               | GitOps controller and Application CRs (Argo CD today) |
| `longhorn-system`      | Block storage (Longhorn today); keep out of ambient   |
| `cnpg-system`          | Postgres operator and clusters (CNPG today)           |
| `monitoring`           | Metrics, dashboards, and logs                         |
| `envoy-gateway-system` | Gateway controller (ingress P0)                       |
| `gateway`              | Ingress proxy data plane (VIP `.51`)                  |
| `istio-system`         | Service mesh (P2 unless app symptom ties to it)       |
| `cert-manager`         | TLS certificate operator                              |
| `external-secrets`     | External secrets sync operator                        |
| `kyverno`              | Admission policy engine                               |
| `keda`                 | Event-driven autoscaling; keep out of ambient         |
| `metallb-system`       | LoadBalancer VIP announcer (L2)                       |

## Reconciler notes

Sync waves and prune behaviour live in Helm chart / Application annotations.
Check them before any destructive sync suggestion. Application deletes and
force sync with prune are escalate-only (`references/escalation.md`).

## Node and storage pointers

- NotReady after hardware replace: stale
  `kube-system/<node>.node-password.k3s` — escalate
  (`documentation/gotcha.md`).
- LUKS unlock / reboot policy: `AGENTS.md`,
  `documentation/luks_remote_unlock.md`, `runbooks/access-and-nodes.md`.
- Longhorn ambient, trim, stuck delete: `documentation/gotcha.md`,
  `runbooks/storage.md`.
