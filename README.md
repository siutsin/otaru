# raspberrypi-k3s

## Bootstrap Cluster

Argo CD is not self-managed at present, for the sake of easier development.

```shell
cd helm-charts
helm dep update
helm upgrade --install argocd argocd -n argocd --create-namespace
helm upgrade --install argocd-bootstrap argocd-bootstrap -n argocd
```

## Cleanup Argo CD

```shell
helm uninstall argocd-bootstrap -n argocd
helm uninstall argocd -n argocd
```
