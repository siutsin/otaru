# otaru

![Kubernetes Version](https://img.shields.io/badge/Kubernetes-v1.34.6+k3s1-blue)
[![Cluster Health](https://img.shields.io/static/v1?label=Cluster%20Health&message=WebGazer&color=brightgreen)](https://www.webgazer.io/s?id=493)

> Over-Engineering at Its Finest.

Bare-metal `k3s` home lab and technical playground.

Current cluster shape:

- Dedicated `192.168.10.0/24` VLAN for cluster nodes and service virtual IPs
- `k3s` with embedded etcd on three Raspberry Pi 5 control-plane nodes
- Flannel `wireguard-native` for pod networking
- MetalLB + Envoy Gateway for service and ingress load balancing
- Istio ambient mesh for east-west traffic and Kiali for mesh observability

## Architecture

![Otaru cluster architecture diagram](assets/otaru-architecture.png)

## Hardware

![Raspberry Pi rack setup](assets/rack.jpeg)

<!-- markdownlint-disable MD060 -->
| Node             | Device                                    | Role           | Boot | Storage                                              |
|------------------|-------------------------------------------|----------------|------|------------------------------------------------------|
| `raspberrypi-00` | [Raspberry Pi 5 8GB][rpi5]                | Control plane  | NVMe | [Lexar NM620 256GB][lexar-nm620]                     |
| `raspberrypi-01` | Raspberry Pi 5 8GB                        | Control plane  | NVMe | [Samsung 980 PRO 2TB (MZ-V8P2T0BW)][samsung-980-pro] |
| `raspberrypi-02` | Raspberry Pi 5 8GB                        | Control plane  | NVMe | [Crucial P3 Plus 4TB][crucial-p3-plus]               |
| `raspberrypi-03` | [Raspberry Pi 4 Model B 8GB][rpi4]        | Worker         | SD   | SanDisk Max Endurance 32 GB                          |
| `ucg-ultra`      | [UniFi Cloud Gateway Ultra][ucg-ultra]    | Router/Gateway | -    | -                                                    |
| `usw-ultra`      | [UniFi Switch Ultra][usw-ultra]           | PoE switch     | -    | -                                                    |
| `rackmate-t1`    | [GeeekPi DeskPi RackMate T1][rackmate-t1] | Rack enclosure | -    | -                                                    |
| `rack-mount`     | [GeeekPi 10" 2U Rack Mount][rack-mount]   | Pi rack mount  | -    | -                                                    |
<!-- markdownlint-enable MD060 -->

The cluster now runs embedded etcd on `raspberrypi-00`, `raspberrypi-01`, and `raspberrypi-02`.
Longhorn uses the root filesystem on the NVMe-backed nodes directly. `raspberrypi-03` remains a worker
and is intentionally unschedulable for Longhorn storage.

## Pending Node

| Node     | Device                                     | Planned role  | Boot      | Storage             |
|----------|--------------------------------------------|---------------|-----------|---------------------|
| `nuc-00` | [Intel NUC Mini PC Core i3-3217U 8GB][nuc] | Future worker | mSATA/LVM | 64 GB local storage |

## Network Layout

| IP              | Role                 |
|-----------------|----------------------|
| `192.168.10.1`  | VLAN gateway         |
| `192.168.10.50` | Kubernetes API VIP   |
| `192.168.10.51` | Internal ingress VIP |
| `192.168.10.60` | `raspberrypi-00`     |
| `192.168.10.61` | `raspberrypi-01`     |
| `192.168.10.62` | `raspberrypi-02`     |
| `192.168.10.63` | `raspberrypi-03`     |
| `192.168.10.64` | `nuc-00`             |

[nuc]: https://www.intel.com/content/www/us/en/products/sku/71275/intel-nuc-kit-dc3217iye/specifications.html
[lexar-nm620]: https://www.lexar.com/global/products/Lexar-NM620-M-2-2280-NVMe-SSD/
[crucial-p3-plus]: https://www.crucial.com/ssd/p3-plus/ct4000p3pssd8
[samsung-980-pro]: https://www.samsung.com/uk/memory-storage/nvme-ssd/980-pro-2tb-nvme-pcie-gen-4-mz-v8p2t0bw/
[rackmate-t1]: https://www.amazon.co.uk/dp/B0CS6MHCY8
[rack-mount]: https://www.amazon.co.uk/dp/B0DRGF68Z9
[ucg-ultra]: https://uk.store.ui.com/uk/en/category/cloud-gateways-compact/products/ucg-ultra
[rpi4]: https://thepihut.com/products/raspberry-pi-4-model-b?variant=31994565689406
[rpi5]: https://thepihut.com/products/raspberry-pi-5?src=raspberrypi&variant=42531604955331
[usw-ultra]: https://uk.store.ui.com/uk/en/category/switching-utility/collections/pro-ultra/products/usw-ultra

## Cluster Components

<!-- markdownlint-disable MD060 -->
| Category     | Name                                                                                                | Description                                                                                            |
|--------------|-----------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| Application  | [Blocky](https://0xerr0r.github.io/blocky/latest/)                                                  | Stateless DNS server                                                                                   |
| Application  | [changedetection.io](https://github.com/dgtlmoon/changedetection.io)                                | Self-hosted website change detection and alerting                                                      |
| Application  | [CyberChef](https://github.com/gchq/CyberChef)                                                      | The Cyber Swiss Army Knife by GCHQ                                                                     |
| Application  | [Excalidraw](https://github.com/excalidraw/excalidraw)                                              | Virtual whiteboard for sketching hand-drawn like diagrams                                              |
| Application  | [Home Assistant](https://www.home-assistant.io/)                                                    | Home Automation                                                                                        |
| Application  | [JSON Crack](https://github.com/AykutSarac/jsoncrack.com)                                           | JSON, YAML, etc. visualizer and editor                                                                 |
| Application  | [Kubernetes MCP Server](https://github.com/containers/kubernetes-mcp-server)                        | Model Context Protocol server for Kubernetes cluster operations                                        |
| Application  | [TeslaMate](https://github.com/teslamate-org/teslamate/)                                            | Self-hosted data logger for Tesla                                                                      |
| Application  | [k3s-apiserver-loadbalancer](https://github.com/siutsin/k3s-apiserver-loadbalancer)                 | An operator to update the `kubernetes` service type to `LoadBalancer`                                  |
| Application  | [冗PowerBot](https://github.com/siutsin/telegram-jung2-bot)                                          | Telegram bot tracks and counts individual message counts in groups                                     |
| CI/CD        | [Argo CD](https://github.com/argoproj/argo-cd)                                                      | GitOps, drift detection, and reconciliation                                                            |
| CI/CD        | [Atlantis](https://github.com/runatlantis/atlantis)                                                 | OpenTofu Pull Request Automation, currently disabled in Argo CD                                        |
| Connectivity | [Envoy Gateway](helm-charts/envoy-gateway)                                                          | Gateway API ingress controller with TLS termination and shared MetalLB virtual IP                      |
| Connectivity | [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Cloudflare Zero Trust Edge                                                                             |
| Connectivity | [Flannel](https://github.com/flannel-io/flannel)                                                    | `wireguard-native` encrypted pod networking for `k3s`                                                  |
| Connectivity | [Gateway API Kubernetes](helm-charts/gateway-api-kubernetes)                                        | Virtual IP and Layer 2 announcement for `kubernetes` service's External IP                             |
| Connectivity | [Gateway API](https://gateway-api.sigs.k8s.io/)                                                     | Kubernetes standard CRDs for managing network traffic                                                  |
| Connectivity | [MetalLB](helm-charts/metallb)                                                                      | Bare metal `LoadBalancer` implementation for service virtual IP allocation and L2 advertisement        |
| Connectivity | [httpbin](https://github.com/Kong/httpbin)                                                          | Generic health check service                                                                           |
| Database     | [CloudNativePG Barman Cloud Plugin](helm-charts/cloudnative-pg-plugin-barman-cloud)                 | PostgreSQL backup plugin for cloud storage providers                                                   |
| Database     | [CloudNativePG Clusters](helm-charts/cloudnative-pg-clusters)                                       | Multi-cluster PostgreSQL management with B2 backup integration                                         |
| Database     | [CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg)                                   | A Kubernetes operator that manages PostgreSQL clusters                                                 |
| Monitoring   | [Grafana](https://github.com/grafana/grafana)                                                       | Grafana LGTM Stack. Visualisation dashboards                                                           |
| Monitoring   | [Heartbeats](helm-charts/heartbeats)                                                                | Kubernetes operator for heartbeat monitoring                                                           |
| Monitoring   | [Kiali](helm-charts/kiali)                                                                          | Service mesh observability UI for Istio                                                                |
| Monitoring   | [Kubernetes Metrics Server](https://github.com/kubernetes-sigs/metrics-server)                      | Scalable, efficient source of container resource metrics for Kubernetes built-in autoscaling pipelines |
| Monitoring   | [Monitoring Stack](helm-charts/monitoring)                                                          | Complete monitoring stack with Grafana, Prometheus, and Loki                                           |
| Scheduling   | [Descheduler](https://github.com/kubernetes-sigs/descheduler)                                       | Evicts pods for optimal cluster node utilisation                                                       |
| Scheduling   | [k8s-cleaner](https://github.com/gianlucam76/k8s-cleaner)                                           | Automated failed pod cleanup and periodic workload repaving                                            |
| Scheduling   | [KEDA](https://keda.sh/)                                                                            | Event Driven Autoscaler                                                                                |
| Scheduling   | [Reloader](https://github.com/stakater/Reloader)                                                    | Watch changes in ConfigMap and Secret and do rolling upgrades                                          |
| Security     | [1Password Connect](https://github.com/1Password/connect)                                           | Proxy service for 1Password; acts as a secret provider                                                 |
| Security     | [External Secrets Operator](https://github.com/external-secrets/external-secrets)                   | Extracts secrets from a secret provider                                                                |
| Security     | [amazon-eks-pod-identity-webhook](https://github.com/aws/amazon-eks-pod-identity-webhook)           | Amazon EKS Pod Identity Webhook for IRSA in bare metal Kubernetes clusters                             |
| Security     | [cert-manager](https://github.com/cert-manager/cert-manager)                                        | Manages TLS certificates via Let's Encrypt and ACME protocol                                           |
| Security     | [Istio](helm-charts/istio-base)                                                                     | Service mesh control plane and ambient dataplane (`istiod`, `istio-cni`, `ztunnel`)                    |
| Security     | [oidc-provider](helm-charts/oidc-provider)                                                          | Kubernetes OIDC provider and JWKS endpoint                                                             |
| Security     | [zizmor](https://docs.zizmor.sh/)                                                                   | Static analysis for GitHub Actions                                                                     |
| Storage      | [Longhorn Config](helm-charts/longhorn-config)                                                      | Longhorn configuration and recurring jobs                                                              |
| Storage      | [Longhorn Volume Lib](helm-charts/longhorn-volume-lib)                                              | Reusable volume templates for Longhorn storage                                                         |
| Storage      | [Longhorn](https://github.com/longhorn/longhorn)                                                    | Distributed block storage system; backup and restore from/to remote destinations                       |
<!-- markdownlint-enable MD060 -->

## IaaS, PaaS, and SaaS

<!-- markdownlint-disable MD060 -->
| Category     | Name          | Service                                                                                  | Description                                  |
|--------------|---------------|------------------------------------------------------------------------------------------|----------------------------------------------|
| CI/CD        | GitHub        | [Actions](https://github.com/features/actions)                                           | Run Terragrunt                               |
| CI/CD        | Sourcery      | [AI Code Reviews](https://docs.sourcery.ai/)                                             | Instant feedback for Pull Requests           |
| Connectivity | Cloudflare    | [Access](https://developers.cloudflare.com/cloudflare-one/policies/access/)              | Edge Access Control                          |
| Connectivity | Cloudflare    | [DNS](https://developers.cloudflare.com/dns/)                                            | Authoritative DNS Service                    |
| Connectivity | Cloudflare    | [Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Edge Connectivity                            |
| Connectivity | UniFi         | [Wifiman](https://ui.com/)                                                               | VPN gateway to home network                  |
| Monitoring   | Heartbeats    | [Heartbeats Operator](helm-charts/heartbeats)                                            | Kubernetes operator for heartbeat monitoring |
| Monitoring   | WebGazer      | [Uptime Monitoring](https://www.webgazer.io/)                                            | Health Check                                 |
| Security     | 1Password     | [Connect](https://developer.1password.com/docs/connect/)                                 | Secrets Automation                           |
| Security     | AWS           | [STS](https://aws.amazon.com/iam/features/sts/)                                          | OIDC/IRSA JWT token exchange                 |
| Security     | Let's Encrypt | [Let's Encrypt](https://letsencrypt.org/)                                                | Certificate Authority                        |
| Security     | Snyk          | [Snyk](https://app.snyk.io/)                                                             | Detects vulnerabilities                      |
| Storage      | AWS           | [DynamoDB](https://aws.amazon.com/dynamodb/)                                             | Database backend for 冗PowerBot               |
| Storage      | AWS           | [S3](https://aws.amazon.com/s3/)                                                         | OpenTofu Remote State                        |
| Storage      | Backblaze     | [B2](https://www.backblaze.com/cloud-storage)                                            | Volume Backup                                |
<!-- markdownlint-enable MD060 -->

## Bootstrap Cluster

1. **Install Tooling**

    ```shell
    brew install \
      ansible \
      direnv \
      go-jsonnet \
      helm \
      kubectl \
      opentofu \
      terragrunt
    ```

2. **Add SSH Keys to `known_hosts`**

    ```shell
    for ip in 192.168.10.{60..63}; do ssh-keygen -R "$ip" && ssh-keyscan "$ip" >> ~/.ssh/known_hosts; done
    ```

3. **Set Up Service Credentials**

    Follow the [1Password Connect Doc](https://developer.1password.com/docs/connect/get-started/#step-2-deploy-1password-connect-server) to create `1password-credentials.json` and
    save the access token to the file `token`. Additionally, save your AWS Account ID to the file `argocd-secret`.
    Copy `.envrc.sample` to `.envrc` and fill in the required environment variables for Terragrunt and OpenTofu.

    ```shell
    ❯ tree $(pwd) -L 1
    /path/to/project/otaru
    ├── .envrc
    ├── .envrc.sample
    ├── 1password-credentials.json
    ├── 1password-credentials.json.sample
    ├── ...
    ├── argocd-secret
    ├── argocd-secret.sample
    ├── ...
    ├── token
    └── token.sample
    ```

4. **Bootstrap Cluster**

    ```shell
    make setup
    ```

## Oopsy

Update host packages and reboot the entire cluster.

```shell
make maintenance
```

Upgrade k3s kubernetes version and restart workloads.

```shell
make upgrade
```

Wipe everything and start from scratch.

```shell
make nuke
```

Set up Raspberry Pi nodes and K3s cluster.

```shell
make setup
```
