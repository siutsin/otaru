# otaru

![Kubernetes Version](https://img.shields.io/badge/Kubernetes-v1.28.4+k3s2-blue)
[![Publish Docker Image](https://github.com/siutsin/otaru/actions/workflows/publish-docker-image.yml/badge.svg)](https://github.com/siutsin/otaru/actions/workflows/publish-docker-image.yml)
[![Terragrunt](https://github.com/siutsin/otaru/actions/workflows/terragrunt.yaml/badge.svg)](https://github.com/siutsin/otaru/actions/workflows/terragrunt.yaml)

> Over-Engineering at Its Finest.

Bare-Metal Home Lab for Kubernetes and Technical Playground.

<!-- TOC -->
* [otaru](#otaru)
  * [Architecture](#architecture)
  * [Hardware](#hardware)
  * [Cluster Components](#cluster-components)
  * [IaaS, PaaS, and SaaS](#iaas-paas-and-saas)
  * [CronJobs](#cronjobs)
  * [Bootstrap Cluster](#bootstrap-cluster)
  * [Oopsy](#oopsy)
  * [Repository Configuration](#repository-configuration)
<!-- TOC -->

## Architecture

![Architecture](https://i.imgur.com/Eu9AD55.png)

## Hardware

| ID             | Device                     | HAT                   | Role   | /dev/mmcblk0          | /dev/sda                                                          | Remarks                                                                           |
|----------------|----------------------------|-----------------------|--------|-----------------------|-------------------------------------------------------------------|-----------------------------------------------------------------------------------|
| raspberrypi-00 | Raspberry Pi 4 Model B 8GB | Waveshare PoE HAT (B) | Master | SanDisk Extreme 32 GB | -                                                                 | -                                                                                 |
| raspberrypi-01 | Raspberry Pi 4 Model B 8GB | Waveshare PoE HAT (B) | Worker | SanDisk Extreme 32 GB | Samsung 980 PRO NVMe™ M.2 SSD 2TB (MZ-V8P2T0BW) + RTL9210 Chipset | NVMe is problematic with RPi[^1][^2]. Switch to USB2 port resolved the issue[^3]. |
| raspberrypi-02 | Raspberry Pi 4 Model B 8GB | Waveshare PoE HAT (B) | Worker | SanDisk Extreme 32 GB | -                                                                 | -                                                                                 |

## Cluster Components

| Category     | Name                                                                                                | Remarks                                                                          |
|--------------|-----------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------|
| Application  | [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)                                          | Ad and tracker-blocking DNS server                                               |
| Application  | [Home Assistant](https://www.home-assistant.io/)                                                    | Home Automation                                                                  |
| Application  | [Jellyfin](https://jellyfin.org/)                                                                   | Home Media System                                                                |
| Application  | [Repave](helm-charts/repave)                                                                        | Daily restart of workloads within the cluster                                    |
| Application  | [SFTPGo](https://github.com/drakkan/sftpgo)                                                         | SFTP for Jellyfin                                                                |
| Application  | [冗PowerBot](helm-charts/jung2bot)                                                                   | Telegram bot tracks and counts individual message counts in groups.              |
| CI/CD        | [Argo CD](https://github.com/argoproj/argo-cd)                                                      | GitOps, drift detection, and reconciliation                                      |
| Connectivity | [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Cloudflare Zero Trust Edge                                                       |
| Connectivity | [Istio](https://github.com/istio/istio)                                                             | Inbound North-South and East-West traffic with mTLS                              |
| Connectivity | [MetalLB](https://github.com/metallb/metallb)                                                       | Internal bare-metal network load-balancer with L2 operating mode                 |
| Connectivity | [httpbin](https://github.com/Kong/httpbin)                                                          | Generic health check service                                                     |
| Monitoring   | [Kiali](https://github.com/kiali/kiali)                                                             | Monitor Istio Network; Read-Only                                                 |
| Security     | [1Password Connect](https://github.com/1Password/connect)                                           | Proxy service for 1Password; acts as a secret provider                           |
| Security     | [External Secrets Operator](https://github.com/external-secrets/external-secrets)                   | Extracts secrets from a secret provider                                          |
| Security     | [cert-manager](https://github.com/cert-manager/cert-manager)                                        | Manages TLS certificates via Let's Encrypt and ACME protocol                     |
| Storage      | [Longhorn](https://github.com/longhorn/longhorn)                                                    | Distributed block storage system; backup and restore from/to remote destinations |

## IaaS, PaaS, and SaaS

| Category     | Name            | Service                                                                                    | Remarks                   |
|--------------|-----------------|--------------------------------------------------------------------------------------------|---------------------------|
| CI/CD        | Github          | [Actions](https://github.com/features/actions)                                             | Run Terragrunt            |
| Connectivity | Cloudflare      | [Access](https://developers.cloudflare.com/cloudflare-one/policies/access/)                | Edge Access Control       |
| Connectivity | Cloudflare      | [DNS](https://developers.cloudflare.com/dns/)                                              | Authoritative DNS Service |
| Connectivity | Cloudflare      | [Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)   | Edge Connectivity         |
| Connectivity | Cloudflare      | [WARP](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/) | VPN to Internal Network   |
| Monitoring   | Healthchecks.io | [Healthchecks.io](https://healthchecks.io/)                                                | Health Check - Heartbeat  |
| Monitoring   | UptimeRobot     | [UptimeRobot](https://uptimerobot.com/)                                                    | Health Check              |
| Security     | 1Password       | [Connect](https://developer.1password.com/docs/connect/)                                   | Secrets Automation        |
| Security     | Let's Encrypt   | [Let's Encrypt](https://letsencrypt.org/)                                                  | Certificate Authority     |
| Storage      | AWS             | [S3](https://aws.amazon.com/s3/)                                                           | Terraform Remote State    |
| Storage      | Backblaze       | [B2](https://www.backblaze.com/cloud-storage)                                              | Volume Backup             |

## CronJobs

| Job                      | Schedule    |
|--------------------------|-------------|
| Repave                   | 02:00 Daily |
| Longhorn Filesystem Trim | 04:00 Daily |
| Longhorn Backup          | 06:00 Daily |

## Bootstrap Cluster

1. **Install Tooling**
    ```shell
    brew install ansible go-jsonnet helm kubectl terraform terragrunt
    ```
2. **Add SSH Keys to `known_hosts`**
    ```shell
    for i in {00..02}; do ssh-keygen -R "raspberrypi-$i.local"; done && for i in {00..02}; do ssh-keyscan "raspberrypi-$i.local" >> ~/.ssh/known_hosts; done
    ```
3. **Set Up 1Password Credentials**
    - Follow the [1Password Connect Doc](https://developer.1password.com/docs/connect/get-started/#step-2-deploy-1password-connect-server) to create `1password-credentials.json`.
    - Save the access token to the file `token`.
        ```shell
        ❯ tree $(pwd) -L 1
        /path/to/project/otaru
        ├── 1password-credentials.json
        ├── 1password-credentials.json.sample
        ├── ...
        ├── token
        └── token.sample
        ```
4. **Bootstrap Cluster**
    ```shell
    ansible-playbook -i ansible/inventory.ini ansible/playbooks/main.yaml
    ```
5. **Update AdGuard Home Password**
    - Update the password in the ConfigMap.

## Oopsy

```shell
make maintenance
```

```shell
make upgrade-cluster
```

```shell
make nuke-cluster
```

```shell
make rebuild-cluster
```

```shell
make restart-all
```

## Repository Configuration

<details>
<summary>Secrets for GitHub Actions</summary>

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
| UPTIME_ROBOT_API_KEY            |

</details>

<!-- Footnotes -->

[^1]: https://forums.raspberrypi.com/viewtopic.php?t=296491

[^2]: https://forums.raspberrypi.com/viewtopic.php?t=332503&start=25

[^3]: https://github.com/raspberrypi/linux/issues/5060#issuecomment-1718290328
