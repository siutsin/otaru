# raspberrypi-k3s

## Bootstrap Cluster

```shell
cd helm-charts/argocd
helm dep update
kubectl create ns argocd
helm template -n argocd argocd . | kubectl apply -f -
# run again if getting the `ensure CRDs are installed first` error
helm template -n argocd argocd . | kubectl apply -f -
```

## Cleanup Argo CD

```shell
cd helm-charts/argocd
helm dep update
helm template -n argocd argocd . | kubectl delete -f -
```
