# Gotchas and Workarounds

This document outlines some known issues and their corresponding solutions encountered in the environment.

---

## Inability to Create a Service for Selecting Kubernetes API Server IPs

In **k3s**, the API server runs as a binary on the host rather than as a pod. This means there is no API server pod available for selection.
The only way to retrieve the IP addresses of the master nodes is by using the `kubernetes` service in the `default` namespace.

To enable external access to the API server, the `kubernetes` service needs to be changed to a `LoadBalancer` type. However, when a new master node joins or is restarted,
the `kubernetes` service will be automatically updated, reverting any changes made to it.

### Resolution: API Server Load Balancer

A custom operator, `k3s-apiserver-loadbalancer`, was created to monitor and update the service type to `LoadBalancer` whenever a change is detected in the `kubernetes` service.

---

## Envoy Image Recompilation Issue

There is an issue with the current Envoy image that requires recompilation when running on certain platforms. This issue is discussed in detail in the [Envoy GitHub issue][envoy-issue].

### Resolution: Ubuntu Server 24.04 LTS

Switching to **Ubuntu Server 24.04 LTS** resolves this issue, avoiding the need for Envoy image recompilation.

---

## Inaccessibility of Services Over Network Interfaces on Raspberry Pi

When using **network interfaces** (e.g., Wi-Fi or Ethernet) on devices such as Raspberry Pi, services may become unreachable after an initial successful connection.
This issue is caused by the device not responding to ARP requests, leading to service inaccessibility after a short period.

### Symptoms: Network Interface Issues

- The service is initially accessible but becomes unreachable over time.
- `arping` commands result in timeouts, and the service cannot be reached.
- `sudo tcpdump -i <interface> arp` shows no response to ARP requests.
- **cilium_l2_responder_v4** map shows no responses sent:

```shell
$ kubectl -n kube-system exec ds/cilium -- bpftool map dump pinned /sys/fs/bpf/tc/globals/cilium_l2_responder_v4
[{
        "key": {
            "ip4": 855746752,
            "ifindex": 3
        },
        "value": {
            "responses_sent": 0
        }
    }
]
```

### Resolution: Enable Promiscuous Mode

Enable **promiscuous mode** on the network interface using the following command can temporarily resolve this issue.
Replace `<interface>` with the actual interface name (e.g., `wlan0`, `eth0`).

```bash
sudo ifconfig <interface> promisc
```

A permanent solution is to add the following configuration to the `/etc/systemd/system/promisc-mode.service` file, replacing `<interface>` with the correct interface name:

```shell
[Unit]
Description=Enable promiscuous mode for <interface>
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ifconfig <interface1> promisc
ExecStart=/sbin/ifconfig <interface2> promisc

[Install]
WantedBy=multi-user.target
```

Then run the following commands to enable and start the service:

```shell
sudo systemctl daemon-reload
sudo systemctl enable promisc-mode.service
sudo systemctl start promisc-mode.service
```

This configuration ensures the Raspberry Pi can respond to ARP requests, keeping services accessible over the network interface.

For more details, see the [MetalLB troubleshooting guide][metallb-troubleshooting].

---

## Pod Unable to Reach External Networks

There can be connectivity issues where pod-to-pod traffic works, but pod-to-external world traffic times out.
Hubble may indicate that the traffic is forwarded, but it still times out.

### Symptoms: External Network Connectivity

The following error was found in the `cilium-agent` logs:

```shell
cilium-tkzx5 cilium-agent time="2024-09-16T01:31:39Z" level=error msg="iptables rules full reconciliation failed, will retry another one later"
error="failed to remove old backup rules: unable to run 'iptables -t nat -D OLD_CILIUM_POST_nat -s 10.42.0.0/24 ! -d nnn.nnn.nnn.nnn/24 ! -o cilium_+ -m comment --comment cilium masquerade non-cluster -j MASQUERADE' iptables command: exit status 1 stderr="iptables: Bad rule (does a matching rule exist in that chain?).\n"" subsys=iptables
```

This error occurs when Cilium tries but fails to delete a backup iptables rule that still exists on the host.

```shell
Chain OLD_CILIUM_POST_nat (0 references)
  pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  0    --  *      !cilium_+  10.42.0.0/24        !10.42.0.0/24         /* cilium masquerade non-cluster */
    0     0 ACCEPT     0    --  *      *       0.0.0.0/0            0.0.0.0/0            mark match 0xa00/0xe00 /* exclude proxy return traffic from masquerade */
    0     0 SNAT       0    --  *      cilium_host !10.42.0.0/24        !10.42.0.0/24         /* cilium host->cluster masquerade */ to:10.42.0.167
    0     0 SNAT       0    --  *      cilium_host  127.0.0.1            0.0.0.0/0            /* cilium host->cluster from 127.0.0.1 masquerade */ to:10.42.0.167
    0     0 SNAT       0    --  *      cilium_host  0.0.0.0/0            0.0.0.0/0            mark match 0xf00/0xf00 ctstate DNAT /* hairpin traffic that originated from a local pod */ to:10.42.0.167
```

### Solution: Flush Iptables Chain

To resolve this, SSH into each host and flush the chain with the following command:

```bash
sudo iptables -t nat -F OLD_CILIUM_POST_nat
```

Once the chain is flushed on all nodes, pods will be able to reach external networks.

---

## Cilium Restart Causes API Server VIP Inaccessibility

Occasionally, Cilium may restart, and if too many Cilium restarts occur across nodes, all nodes may go down.
This can result in no node announcing the Virtual IP for the API server, making the API server Virtual IP inaccessible.

### Symptoms: API Server VIP Issues

The issue arises when no node is able to announce the API server's Virtual IP, leading to a disruption in access to the Kubernetes API server.

### Solution: Cilium Kubernetes Host Configuration

One potential solution is to set the Cilium Kubernetes host to `127.0.0.1` with the port set to `6443`. However, this solution requires all nodes to be master nodes.
Open GitHub issue related to this problem: [Cilium GitHub issue][cilium-issue]

---

## Unable to Delete Longhorn Volume

When attempting to delete a Longhorn volume, it may become stuck due to validation errors, preventing its removal.

### Symptoms: Longhorn Volume Deletion Issues

The volume remains in the `deleting` state with validation errors, making it impossible to delete.
For more details, refer to the related GitHub issue: [Longhorn GitHub issue][longhorn-issue].

### Solution: Manual Webhook Configuration Removal

1. Run `kubectl edit validatingwebhookconfigurations.admissionregistration.k8s.io longhorn-webhook-validator` and locate the block related to the `volume` resource.
2. Delete the entire rule block associated with the `volume` resource.
3. Manually delete the volume.
4. Restart the Longhorn components to regenerate the webhook configuration by running `kubectl rollout restart deploy,ds -n longhorn-system`.

---

## Barman Cloud WAL Archiving Failure: `exit status 4`

This error is probably due to running out of disk space.

To recover, forcefully delete the affected PersistentVolumeClaim (PVC) and the corresponding pod.
Replace `example-db-20250724-0023-2` with the actual pod/PVC name as appropriate:

```shell
kubectl delete pvc example-db-20250724-0023-2 -n cnpg-system
kubectl delete pod example-db-20250724-0023-2 -n cnpg-system
```

---

## RPi5 Wi-Fi Stuck in Association Loop (status_code=16)

On RPi5, wpa_supplicant logs show `CTRL-EVENT-ASSOC-REJECT bssid=<bssid> status_code=16` repeatedly and the node
cannot associate with any AP. Rebooting the node does not resolve it. This was observed on node02 against a UniFi
mesh network running a WPA2/WPA3 mixed-mode SSID.

### Root Cause

The `brcmfmac` firmware has two features that combine to cause this:

1. **SWSUP** - the firmware offloads WPA authentication to itself rather than delegating to wpa_supplicant.
    When the SSID runs WPA2/WPA3 mixed mode, the firmware's SAE implementation is incompatible with the AP,
    causing an initial `status_code=16` rejection.

2. **Firmware-assisted roaming** - the firmware follows 802.11v BSS Transition Requests at the kernel level,
    bypassing wpa_supplicant's BSSID preference. This steers the node to an AP that then rejects it.

Together, these trigger a retry storm: wpa_supplicant retries rapidly after each rejection, which hits the AP's
internal rate-limiter. The rate-limiter then blocks all subsequent association attempts until the AP is rebooted.
The blocking state lives on the AP, not the node, so rebooting the node does not help.

This does not affect RPi4 nodes because the firmware version behaves differently.

### Symptoms

- wpa_supplicant logs show `CTRL-EVENT-ASSOC-REJECT bssid=<bssid> status_code=16` repeatedly.
- Setting `bssid=` or `freq_list=` in wpa_supplicant config has no effect.
- Other nodes on the same SSID connect successfully.
- Rebooting the node does not resolve the issue.

### Resolution

Add the following to `/etc/modprobe.d/brcmfmac.conf` on the RPi5 node:

```text
# Disable firmware-assisted roaming (roamoff) and firmware-side SAE/SWSUP (feature_disable).
# Without this, the brcmfmac firmware follows 802.11v BSS Transition Requests and handles
# WPA authentication internally. On WPA2/WPA3 mixed-mode APs this causes status_code=16
# rejections and a retry storm that triggers the AP rate-limiter.
# See documentation/gotcha.md - RPi5 Wi-Fi Stuck in Association Loop.
options brcmfmac roamoff=1 feature_disable=0x82000
```

Then reload the module:

```shell
sudo modprobe -r brcmfmac_wcc brcmfmac && sudo modprobe brcmfmac
```

If the AP rate-limiter has already been triggered, reboot the AP to clear its state before applying the fix.

This fix is also applied by Home Assistant OS to all RPi nodes for the same reason. See
[home-assistant/operating-system#4056](https://github.com/home-assistant/operating-system/pull/4056) and
[RPi-Distro/firmware-nonfree#34](https://github.com/RPi-Distro/firmware-nonfree/issues/34).

---

## Raspberry Pi 5 NVMe LUKS Boot Checklist

For Pi 5 NVMe encrypted-root boots, the boot partition must be treated as part of the migration, not just the root
filesystem.

### Must Do

1. Ensure `/boot/firmware/config.txt` includes:

    ```text
    dtparam=pciex1
    dtparam=pciex1_gen=3
    ```

2. After rebuilding or upgrading the encrypted root, sync the matching boot artifacts onto `/boot/firmware`:
    `/boot/vmlinuz-*` -> `/boot/firmware/vmlinuz`, `/boot/initrd.img-*` -> `/boot/firmware/initrd.img`,
    `/usr/lib/firmware/<kernel>/device-tree/broadcom/*.dtb` -> `/boot/firmware/`, and
    `/usr/lib/firmware/<kernel>/device-tree/overlays/` -> `/boot/firmware/overlays/`.

3. Keep the installed kernel line on the rebuilt root aligned with the node's working Ubuntu Pi kernel line before
    booting it.

4. If you add a recovery passphrase from rescue, create it without a trailing newline, for example:
    `printf '%s' 'otaru-clean-01' > /tmp/luks-clean-pass`

5. Verify the recovery passphrase in both modes before using it for initramfs boot:
    `cryptsetup open /dev/nvme0n1p2 cryptroot-test --key-file /tmp/luks-clean-pass`
    and
    `printf '%s\n' 'otaru-clean-01' | cryptsetup open --test-passphrase /dev/nvme0n1p2`

6. For shell-mode initramfs `dropbear`, use `cryptroot-unlock` rather than writing directly to
    `/lib/cryptsetup/passfifo`. `cryptroot-unlock` waits for the real `askpass` process and
    confirms whether the passphrase actually unlocked the device. Opening `cryptroot` manually with
    `cryptsetup open` is still useful for debugging, but it does not necessarily resume boot if
    `/lib/cryptsetup/askpass` is still waiting.
    When feeding the passphrase remotely, do not append a trailing newline.

7. Do not pass the LUKS password in command arguments during rescue work. Stage it via stdin or a
    root-only temporary file and rotate it if you ever expose it in command text.

8. The one-pass rescue wrapper avoids the earlier manual rebuild failure modes:
    mount ordering, `/boot/firmware` rsync conflicts, and `resolv.conf` symlink handling.

9. If a rebuilt control-plane node fails to rejoin with
    `etcd cluster join failed: duplicate node name found`, cleanly rejoin it:
    uninstall `k3s` on the rebuilt node, delete the stale Kubernetes `Node` object, confirm etcd only has the healthy
    members, then rerun the normal `k3s` join play for that node.

[envoy-issue]: https://github.com/envoyproxy/envoy/issues/23339
[metallb-troubleshooting]: https://metallb.universe.tf/troubleshooting/#using-wifi-and-cant-reach-the-service
[cilium-issue]: https://github.com/cilium/cilium/issues/19038
[longhorn-issue]: https://github.com/longhorn/longhorn/issues/4143
