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

[envoy-issue]: https://github.com/envoyproxy/envoy/issues/23339
[metallb-troubleshooting]: https://metallb.universe.tf/troubleshooting/#using-wifi-and-cant-reach-the-service
[cilium-issue]: https://github.com/cilium/cilium/issues/19038
[longhorn-issue]: https://github.com/longhorn/longhorn/issues/4143
