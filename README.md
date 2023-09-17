# raspberrypi-k3s

## Bootstrap Cluster

Argo CD is not self-managed at present, for the sake of easier development.

```shell
# Pull dependency
helm dep update helm-charts/argocd && helm dep update helm-charts/1password-connect

# Init Argo CD
helm upgrade --install argocd helm-charts/argocd -n argocd --create-namespace

# Follow https://developer.1password.com/docs/connect/get-started/#step-2-deploy-1password-connect-server to create
# `1password-credentials.json` and get access token.

# Init 1Password Secret Operator
helm upgrade --install onepassword-connect helm-charts/onepassword-connect \
  -n onepassword \
  --create-namespace \
  --set-file connect.connect.credentials=1password-credentials.json

# Bootstrap
helm upgrade --install argocd-bootstrap helm-charts/argocd-bootstrap -n argocd
```
