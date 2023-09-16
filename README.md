# raspberrypi-k3s

## Bootstrap Cluster

```shell
cd helm-charts/argocd
helm dep update
helm template argocd . | kubectl apply -f -
# run again if getting the `ensure CRDs are installed first` error
helm template argocd . | kubectl apply -f -
```
