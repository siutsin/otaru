# otaru

> Over-Engineering to the Finest.

Bare-Metal Home Lab for Kubernetes and Technical Playground.

## Status

| GitHub Actions                                                                                                                                                                                        |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [![Delete Untagged Images](https://github.com/siutsin/otaru/actions/workflows/delete-untagged-images.yaml/badge.svg)](https://github.com/siutsin/otaru/actions/workflows/delete-untagged-images.yaml) |
| [![Publish Docker Image](https://github.com/siutsin/otaru/actions/workflows/publish-docker-image.yml/badge.svg)](https://github.com/siutsin/otaru/actions/workflows/publish-docker-image.yml)         |
| [![Terragrunt](https://github.com/siutsin/otaru/actions/workflows/terragrunt.yaml/badge.svg)](https://github.com/siutsin/otaru/actions/workflows/terragrunt.yaml)                                     |

## Architecture

![architecture](https://i.imgur.com/zZpZAF9.png)

## Hardware

| ID             | Device                     | HAT                   | Role   | bootfs                | /dev/sda                                        |
|----------------|----------------------------|-----------------------|--------|-----------------------|-------------------------------------------------|
| raspberrypi-00 | Raspberry Pi 4 Model B 8GB | Waveshare PoE HAT (B) | master | SanDisk Extreme 32 GB | -                                               |
| raspberrypi-01 | Raspberry Pi 4 Model B 8GB | Waveshare PoE HAT (B) | worker | SanDisk Extreme 32 GB | Samsung 980 PRO NVMe™ M.2 SSD 2TB (MZ-V8P2T0BW) |
| raspberrypi-02 | Raspberry Pi 4 Model B 8GB | Waveshare PoE HAT (B) | worker | SanDisk Extreme 32 GB | -                                               |

## Components

| Category            | Name                                                                                                | Remarks                                                                                  |
|---------------------|-----------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| Application         | [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)                                          | Ads & trackers blocking DNS server                                                       |
| Application         | [Jellyfin](https://jellyfin.org/)                                                                   | Home Media System                                                                        |
| Connectivity        | [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Cloudflare Zero Trust Edge                                                               |
| Connectivity        | [Istio](https://github.com/istio/istio)                                                             | Inbound North-South traffic & East-West traffic with mTLS                                |
| Connectivity        | [MetalLB](https://github.com/metallb/metallb)                                                       | Internal bare-metal network load-balancer with layer 2 operating mode                    |
| Connectivity        | [httpbin](https://github.com/Kong/httpbin)                                                          | Generic health check service                                                             |
| Continuous Delivery | [Argo CD](https://github.com/argoproj/argo-cd)                                                      | GitOps, drift detection, and reconcile                                                   |
| Monitoring          | [Kiali](https://github.com/kiali/kiali)                                                             | Monitor Istio Network - Read Only                                                        |
| Security            | [1Password Connect](https://github.com/1Password/connect)                                           | Proxy service connecting to 1Password and act as a secret provider                       |
| Security            | [External Secrets Operator](https://github.com/external-secrets/external-secrets)                   | Extract secrets from a secret provider                                                   |
| Security            | [cert-manager](https://github.com/cert-manager/cert-manager)                                        | Automatically provision and manage TLS certificates with Let's Encrypt via ACME protocol |
| Storage             | [Longhorn](https://github.com/longhorn/longhorn)                                                    | Distributed block storage system. Backup/restore from/to a remote destination            |

## IaaS, PaaS, and SaaS

| Name           | Service                                                                                                      | Remarks                       |
|----------------|--------------------------------------------------------------------------------------------------------------|-------------------------------|
| 1Password      | [Connect](https://developer.1password.com/docs/connect/)                                                     | Secrets Automation            |
| AWS            | [Route53 Health Check](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/welcome-health-checks.html) | Health Check                  |
| AWS            | [S3](https://aws.amazon.com/s3/)                                                                             | Terraform Remote State        |
| Backblaze      | [B2](https://www.backblaze.com/cloud-storage)                                                                | Volume Backup                 |
| Cloudflare     | [Access](https://developers.cloudflare.com/cloudflare-one/policies/access/)                                  | Edge Access Control           |
| Cloudflare     | [DNS](https://developers.cloudflare.com/dns/)                                                                | Authoritative DNS Service     |
| Cloudflare     | [Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)                     | Edge Connectivity             |
| Cloudflare     | [WARP](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/)                   | VPN to Internal Network       |
| Healthcheck.io | [Healthchecks.io](https://healthchecks.io/)                                                                  | Health Check and Notification |
| Let's Encrypt  | [Let's Encrypt ](https://letsencrypt.org/)                                                                   | Certificate Authority         |

## Bootstrap Cluster

> [!NOTE]
> Argo CD is not self-managed at present, for the sake of easier development.

### Prerequisites

- Setup nodes with [How to Set Up RPI with Waveshare PoE HAT (B) and Install K3s from scratch](doc/how_to_set_up_rpi_with_waveshare_poe_hat_b_and_install_k3s_from_scratch.md)

### Bootstrap

```shell
# Pull dependency
./hack/helm_charts_pull_all_dep.sh

# Create Namespaces
helm upgrade --install namespaces helm-charts/namespaces -n default

# Init Argo CD
helm upgrade --install argocd helm-charts/argocd -n argocd

# Follow https://developer.1password.com/docs/connect/get-started/#step-2-deploy-1password-connect-server to create
# `1password-credentials.json` and save the access token to the file `token`.

# Init 1Password Secret Operator
helm upgrade --install onepassword-connect helm-charts/onepassword-connect \
  -n onepassword \
  --set-file connect.connect.credentials=1password-credentials.json

# Create Secret for `onepassword-connect`
kubectl create secret generic onepassword-connect-token -n external-secrets --from-literal=token=`tr -d '\n' < token`

# Bootstrap
helm upgrade --install argocd-bootstrap helm-charts/argocd-bootstrap -n argocd

# Restart all workloads after bootstrap
kubectl get namespaces -o custom-columns=':metadata.name' --no-headers | xargs -n2 -I {} kubectl rollout restart deploy,sts,ds -n {}
```

## Repository Secrets for GitHub Actions

| Key                             |
|---------------------------------|
| AWS_ACCESS_KEY_ID               |
| AWS_SECRET_ACCESS_KEY           |
| B2_APPLICATION_KEY              |
| B2_APPLICATION_KEY_ID           |
| CLOUDFLARE_ACCOUNT_ID           |
| CLOUDFLARE_API_TOKEN            |
| CLOUDFLARE_TUNNEL_SECRET        |
| CLOUDFLARE_ZONE                 |
| CLOUDFLARE_ZONE_ID              |
| CLOUDFLARE_ZONE_SUBDOMAIN       |
| CLOUDFLARE_ZONE_TUNNEL_IP_LIST  |
| GH_ADD_COMMENT_TOKEN            |
| GH_DELETE_UNTAGGED_IMAGES_TOKEN |
