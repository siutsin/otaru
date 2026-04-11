# Cluster Rebuild Plan

Rebuild the k3s cluster on a dedicated 192.168.10.0/24 VLAN using RPi 5 nodes with NVMe boot
and k3s embedded etcd (no external etcd host).

## IP allocation

| IP            | Role                  |
|---------------|-----------------------|
| 192.168.10.1  | Gateway               |
| 192.168.10.50 | Kubernetes API Server |
| 192.168.10.51 | Internal Ingress      |
| 192.168.10.60 | raspberrypi-00        |
| 192.168.10.61 | raspberrypi-01        |
| 192.168.10.62 | raspberrypi-02        |
| 192.168.10.63 | raspberrypi-03        |

## Progress

### Done

- [x] Flash raspberrypi-00 with Ubuntu on NVMe (Step 1-7 of create_rpi5_nvme_image.md)
- [x] Configure cloud-init: hostname raspberrypi-00, static IP 192.168.10.60, SSH key
- [x] Verify boot from NVMe, root partition expanded to 235G
- [x] Assign switch port to 192.168.10.0/24 VLAN in Unifi
- [x] Verify connectivity from Mac to 192.168.10.60 via inter-VLAN routing
- [x] Update EEPROM boot order to 0xf461 (SD, NVMe, USB, restart)
- [x] Update RPi5 NVMe guide: reorder GPT conversion before cloud-init, fix BOOT_ORDER
- [x] Migrate ansible, helm charts, infrastructure, and docs from 192.168.1.x to 192.168.10.x
- [x] Remove external etcd: delete etcd playbooks, switch k3s to embedded etcd (--cluster-init)
- [x] Rack raspberrypi-00 with PoE+ power supply, verified healthy

### To do

- [ ] Flash raspberrypi-01, raspberrypi-02, raspberrypi-03 with Ubuntu on NVMe
- [ ] Configure cloud-init for each node (hostnames, static IPs, SSH keys)
- [ ] Assign switch ports to 192.168.10.0/24 VLAN for each node
- [ ] Run `make setup-cluster` or `make reconcile-node-k3s` to bootstrap the cluster
- [ ] Verify all nodes joined and k3s is healthy
- [ ] Verify Cilium CNI, Gateway API, and CoreDNS are operational
- [ ] Verify ArgoCD, 1Password Connect, and External Secrets bootstrap
- [ ] Update kubeconfig to use LB API server IP (192.168.10.50)
- [ ] Apply Cloudflare tunnel and Unifi infrastructure changes via Terragrunt
- [ ] LUKS full-disk encryption for all RPi nodes (deferred, does not conflict with current setup)

## Notes

- The old 192.168.1.0/24 subnet remains for non-cluster devices
- The brcmfmac Wi-Fi driver options are kept in case Wi-Fi is needed as backup connectivity
- LUKS can be added later without affecting the k3s or networking configuration
- The `documentation/set_up_rpi.md` is a legacy guide and was not updated
- The `playground/init_etcd.yaml` is a historical reference and was not updated
