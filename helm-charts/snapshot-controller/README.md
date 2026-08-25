# snapshot-controller

This chart vendors the official Kubernetes CSI snapshot CRDs and deploys the matching snapshot controller.

Update the CRDs after changing `appVersion` in `Chart.yaml`:

```shell
make
```
