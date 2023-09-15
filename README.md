# raspberrypi-k3s

## Bootstrap Cluster

```shell
cd helm-charts/argocd
helm template argocd . | kubectl apply -f -
```
