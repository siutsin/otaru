# otaru

> Over-Engineering to the Finest.

Bare-Metal Home Lab for Kubernetes and Technical Playground.

<!-- TOC -->
* [otaru](#otaru)
  * [Status](#status)
  * [Architecture](#architecture)
  * [Hardware](#hardware)
  * [Cluster Components](#cluster-components)
  * [IaaS, PaaS, and SaaS](#iaas-paas-and-saas)
  * [Bootstrap Cluster](#bootstrap-cluster)
  * [Nuke Cluster](#nuke-cluster)
  * [Rebuild Cluster](#rebuild-cluster)
  * [Repository Secrets for GitHub Actions](#repository-secrets-for-github-actions)
<!-- TOC -->

## Status

| GitHub Actions                                                                                                                                                                                        |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [![Delete Untagged Images](https://github.com/siutsin/otaru/actions/workflows/delete-untagged-images.yaml/badge.svg)](https://github.com/siutsin/otaru/actions/workflows/delete-untagged-images.yaml) |
| [![Publish Docker Image](https://github.com/siutsin/otaru/actions/workflows/publish-docker-image.yml/badge.svg)](https://github.com/siutsin/otaru/actions/workflows/publish-docker-image.yml)         |
| [![Terragrunt](https://github.com/siutsin/otaru/actions/workflows/terragrunt.yaml/badge.svg)](https://github.com/siutsin/otaru/actions/workflows/terragrunt.yaml)                                     |



## Architecture

![architecture](https://i.imgur.com/zZpZAF9.png)

## Hardware

| ID             | Device                     | HAT                   | Role   | /dev/mmcblk0          | /dev/sda                                                          | Remarks                                                                                                                      |
|----------------|----------------------------|-----------------------|--------|-----------------------|-------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| raspberrypi-00 | Raspberry Pi 4 Model B 8GB | Waveshare PoE HAT (B) | master | SanDisk Extreme 32 GB | -                                                                 | -                                                                                                                            |
| raspberrypi-01 | Raspberry Pi 4 Model B 8GB | Waveshare PoE HAT (B) | worker | SanDisk Extreme 32 GB | Samsung 980 PRO NVMe™ M.2 SSD 2TB (MZ-V8P2T0BW) + RTL9210 Chipset | NVMe doesn't work well with RPi[^1][^2]. Use the official RPi power adapter and switch to the USB2 port as a workaround[^3]. |
| raspberrypi-02 | Raspberry Pi 4 Model B 8GB | Waveshare PoE HAT (B) | worker | SanDisk Extreme 32 GB | -                                                                 | -                                                                                                                            |

## Cluster Components

| Category     | Name                                                                                                | Remarks                                                                                  |
|--------------|-----------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| Application  | [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)                                          | Ads & trackers blocking DNS server                                                       |
| Application  | [Jellyfin](https://jellyfin.org/)                                                                   | Home Media System                                                                        |
| Application  | [SFTPGo](https://github.com/drakkan/sftpgo)                                                         | SFTP for Jellyfin                                                                        |
| Connectivity | [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Cloudflare Zero Trust Edge                                                               |
| Connectivity | [Istio](https://github.com/istio/istio)                                                             | Inbound North-South traffic & East-West traffic with mTLS                                |
| Connectivity | [MetalLB](https://github.com/metallb/metallb)                                                       | Internal bare-metal network load-balancer with OSI Layer 2 operating mode                |
| Connectivity | [httpbin](https://github.com/Kong/httpbin)                                                          | Generic health check service                                                             |
| CI/CD        | [Argo CD](https://github.com/argoproj/argo-cd)                                                      | GitOps, drift detection, and reconcile                                                   |
| Monitoring   | [Kiali](https://github.com/kiali/kiali)                                                             | Monitor Istio Network - Read Only                                                        |
| Security     | [1Password Connect](https://github.com/1Password/connect)                                           | Proxy service connecting to 1Password and act as a secret provider                       |
| Security     | [External Secrets Operator](https://github.com/external-secrets/external-secrets)                   | Extract secrets from a secret provider                                                   |
| Security     | [cert-manager](https://github.com/cert-manager/cert-manager)                                        | Automatically provision and manage TLS certificates with Let's Encrypt via ACME protocol |
| Storage      | [Longhorn](https://github.com/longhorn/longhorn)                                                    | Distributed block storage system. Backup/restore from/to a remote destination            |

## IaaS, PaaS, and SaaS

| Name           | Service                                                                                    | Remarks                       |
|----------------|--------------------------------------------------------------------------------------------|-------------------------------|
| 1Password      | [Connect](https://developer.1password.com/docs/connect/)                                   | Secrets Automation            |
| AWS            | [S3](https://aws.amazon.com/s3/)                                                           | Terraform Remote State        |
| Backblaze      | [B2](https://www.backblaze.com/cloud-storage)                                              | Volume Backup                 |
| Cloudflare     | [Access](https://developers.cloudflare.com/cloudflare-one/policies/access/)                | Edge Access Control           |
| Cloudflare     | [DNS](https://developers.cloudflare.com/dns/)                                              | Authoritative DNS Service     |
| Cloudflare     | [Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)   | Edge Connectivity             |
| Cloudflare     | [WARP](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/) | VPN to Internal Network       |
| Healthcheck.io | [Healthchecks.io](https://healthchecks.io/)                                                | Health Check and Notification |
| Let's Encrypt  | [Let's Encrypt ](https://letsencrypt.org/)                                                 | Certificate Authority         |

## Bootstrap Cluster

> [!NOTE]
> Argo CD is not self-managed at present, for the sake of easier development.

1. Install tooling.
    ```shell
    brew install ansible helm kubectl terraform terragrunt
    ```
2. Add SSH keys to `known_hosts`.
    ```shell
    for i in {00..02}; do ssh-keygen -R "raspberrypi-$i.local"; done && for i in {00..02}; do ssh-keyscan "raspberrypi-$i.local" >> ~/.ssh/known_hosts; done
    ```
3. Follow the [1Password Connect Doc](https://developer.1password.com/docs/connect/get-started/#step-2-deploy-1password-connect-server) to create `1password-credentials.json`
   and save the access token to the file `token`.
    ```shell
    ❯ tree $(pwd) -L 1
    /path/to/project/otaru
    ├── 1password-credentials.json
    ├── 1password-credentials.json.sample
    ├── ...
    ├── token
    └── token.sample
    ```
4. Bootstrap cluster.
    ```shell
    ansible-playbook -i ansible/inventory.ini ansible/playbooks/main.yaml
    ```
5. update AdGuard Home's password in the ConfigMap.

## Nuke Cluster

```shell
ansible-playbook -i ansible/inventory.ini ansible/playbooks/k3s-uninstall.yaml
```

## Rebuild Cluster

```shell
ansible-playbook -i ansible/inventory.ini ansible/playbooks/k3s-install.yaml
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

<!-- Footnotes -->

[^1]: https://forums.raspberrypi.com/viewtopic.php?t=296491

[^2]: https://forums.raspberrypi.com/viewtopic.php?t=332503&start=25

[^3]: https://github.com/raspberrypi/linux/issues/5060#issuecomment-1718290328
