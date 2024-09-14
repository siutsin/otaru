# Gotchas and Workarounds

This document outlines some known issues and their corresponding solutions encountered in the environment.

---

## Inability to Create a Service for Selecting Kubernetes API Server IPs

In **k3s**, the API server runs as a binary on the host rather than as a pod. This means there is no API server pod available for selection. The only way to retrieve the IP
addresses of the master nodes is by using the `kubernetes` service in the `default` namespace.

To enable external access to the API server, the `kubernetes` service needs to be changed to a `LoadBalancer` type. However, when a new master node joins or is restarted, the
`kubernetes` service will be automatically updated, reverting any changes made to it.

### Workaround

A custom operator, `kubernetes-service-patcher`, was created to monitor and update the service type to `LoadBalancer` whenever a change is detected in the `kubernetes` service.

---

## Envoy Image Recompilation Issue

There is an issue with the current Envoy image that requires recompilation when running on certain platforms. This issue is discussed in detail in
the [Envoy GitHub issue](https://github.com/envoyproxy/envoy/issues/23339).

### Resolution

Switching to **Ubuntu Server 24.04 LTS** resolves this issue, avoiding the need for Envoy image recompilation.

---

## Inaccessibility of Services Over Wi-Fi on Raspberry Pi

When using **Wi-Fi** on devices such as Raspberry Pi, services may become unreachable after an initial successful connection. This issue is caused by the device not responding to
ARP requests over Wi-Fi, leading to service inaccessibility after a short period.

### Symptoms

- The service is initially accessible but becomes unreachable over time.
- `arping` commands result in timeouts, and the service cannot be reached.

### Workaround

Enable **promiscuous mode** on the Wi-Fi network interface using the following command:

```bash
sudo ifconfig <device> promisc
```

For example, if the device is `wlan0`, run:

```bash
sudo ifconfig wlan0 promisc
```

This configuration ensures the Raspberry Pi can respond to ARP requests, keeping services accessible over Wi-Fi.

For more details, see the [MetalLB troubleshooting guide](https://metallb.universe.tf/troubleshooting/#using-wifi-and-cant-reach-the-service).

---

## Pod Unable to Reach External Networks

There can be connectivity issues where pod-to-pod traffic works, but pod-to-external world traffic times out. Hubble may indicate that the traffic is forwarded, but it still times
out. The following error was found in the `cilium-agent` logs:

```shell
cilium-tkzx5 cilium-agent time="2024-09-16T01:31:39Z" level=error msg="iptables rules full reconciliation failed, will retry another one later" error="failed to remove old backup rules: unable to run 'iptables -t nat -D OLD_CILIUM_POST_nat -s 10.42.0.0/24 ! -d nnn.nnn.nnn.nnn/24 ! -o cilium_+ -m comment --comment cilium masquerade non-cluster -j MASQUERADE' iptables command: exit status 1 stderr="iptables: Bad rule (does a matching rule exist in that chain?).\n"" subsys=iptables
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

### Solution

To resolve this, SSH into each host and flush the chain with the following command:

```bash
sudo iptables -t nat -F OLD_CILIUM_POST_nat
```

Once the chain is flushed on all nodes, pods will be able to reach external networks.

---

