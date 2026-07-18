# Gotchas and Workarounds

Non-obvious behaviours and workarounds discovered while working in this repo.
This is the single gotcha document — do not add a second `GOTCHA.md` at the
repo root.

---

## Inability to Create a Service for Selecting Kubernetes API Server IPs

In **k3s**, the API server runs as a binary on the host rather than as a pod. This means there is no API server pod available for selection.
The only way to retrieve the IP addresses of the master nodes is by using the `kubernetes` service in the `default` namespace.

To enable external access to the API server, the `kubernetes` service needs to be changed to a `LoadBalancer` type. However, when a new master node joins or is restarted,
the `kubernetes` service will be automatically updated, reverting any changes made to it.

### Resolution: API Server Load Balancer

A custom operator, `k3s-apiserver-loadbalancer`, was created to monitor and update the service type to `LoadBalancer` whenever a change is detected in the `kubernetes` service.

---

## Reused K3s Node Name Cannot Join After Hardware Replacement

When replacing a node in place, the new host may reuse the same Kubernetes node name. K3s stores a per-node
password secret in `kube-system`, so a fresh install with the same node name can fail to join if the old
password secret is still present.

This was observed when replacing `raspberrypi-03` hardware. The new RPi5 came up with the same hostname, but
`k3s-agent` failed until the stale password secret was removed.

### Symptoms: Stale K3s Node Password

- `make setup` reaches the worker install step, but the replacement worker does not become Ready.
- `k3s-agent` logs on the replacement node mention a rejected node password.
- The cluster still has a secret named after the old node:

```shell
kubectl -n kube-system get secret raspberrypi-03.node-password.k3s
```

### Resolution: Delete the Stale Node Password Secret

Confirm the old physical node is gone and the replacement host is the intended machine. Then delete the stale
secret and rerun setup:

```shell
kubectl -n kube-system delete secret raspberrypi-03.node-password.k3s
make setup
```

After the agent joins successfully, K3s recreates the secret for the replacement node. Verify the node and secret:

```shell
kubectl get node raspberrypi-03 -o wide
kubectl -n kube-system get secret raspberrypi-03.node-password.k3s
```

---

## Atlantis Is Unsafe for This Public Repo

Atlantis is not a safe fit for this repository while it remains public.

### Why

- `terraform plan` is not a harmless read-only action. It can execute provider code, `external` data sources, and
  repo-controlled workflow steps.
- Public pull requests are not fully trusted, even when `apply` is locked down.
- Fork PR restrictions and webhook validation are necessary, but they do not remove the core risk of running
  untrusted infrastructure code during `plan`.

### Recommendation

Do not run Atlantis against this repo. Prefer GitHub Actions or other CI where credentials, workflow scope, and
execution paths are tightly controlled per job.

Infrastructure changes under [`infrastructure/`](../infrastructure) are
manual now. Run `terragrunt` directly from the relevant stack directory, for example:

```shell
cd infrastructure/cloud/cloudflare/dns
terragrunt plan
terragrunt apply
```

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

## Longhorn Webhook Breaks When Enrolled in Ambient Mesh

Longhorn should not run in an ambient-enrolled namespace in this cluster. The Longhorn manager pods serve the
admission webhook, recovery backend, and storage control-plane APIs that CSI and Longhorn itself call while
attaching volumes. Routing those paths through the shared waypoint can make volume attach fail even when the
Longhorn pods are otherwise running.

This removes Istio ambient mTLS and waypoint policy from Longhorn traffic. Longhorn is treated as platform
infrastructure instead: access is constrained by Kubernetes RBAC and namespace ownership, the webhook uses
Kubernetes service TLS, and inter-node traffic remains protected by Flannel `wireguard-native`.

### Symptoms: Longhorn Ambient Mesh

- Workload pods stay in `ContainerCreating` while waiting for Longhorn volumes.
- Pod events show `AttachVolume.Attach failed` for a Longhorn-backed PVC.
- The error mentions failed calls to `mutator.longhorn.io` or `validator.longhorn.io`.
- The failing URL points at `https://longhorn-admission-webhook.longhorn-system.svc:9502/...`.

Example event:

```text
AttachVolume.Attach failed for volume "...": rpc error: code = Internal desc = Bad response statusCode [500].
message=unable to attach volume ...: failed calling webhook "mutator.longhorn.io":
Post "https://longhorn-admission-webhook.longhorn-system.svc:9502/v1/webhook/mutation?timeout=10s": EOF
```

### Resolution: Keep Longhorn Outside Ambient

Keep `longhorn-system` out of the ambient mesh in `helm-charts/namespaces/values.yaml`:

```yaml
- name: longhorn-system
  ambient: false
```

If ArgoCD has already applied ambient labels, remove them and restart Longhorn manager pods so they are created
without ambient redirection:

```shell
kubectl label ns longhorn-system \
  istio.io/dataplane-mode- \
  istio.io/use-waypoint- \
  istio.io/use-waypoint-namespace- \
  istio.io/ingress-use-waypoint-
kubectl -n longhorn-system delete pod -l app=longhorn-manager
```

After the restart, confirm Longhorn manager pods no longer have ambient redirection and that affected volumes
return to `healthy`:

```shell
kubectl -n longhorn-system get pods -l app=longhorn-manager \
  -o custom-columns='NAME:.metadata.name,NODE:.spec.nodeName,AMBIENT:.metadata.annotations.ambient\.istio\.io/redirection'
kubectl -n longhorn-system get volumes.longhorn.io
```

---

## KEDA External Metrics API Fails Through Ambient

KEDA exposes `external.metrics.k8s.io` through a Kubernetes aggregated APIService. The kube-apiserver calls
the KEDA metrics adapter directly on its HTTPS endpoint, and the adapter calls the KEDA operator gRPC metrics
service.

### Symptoms: KEDA External Metrics

- The `keda` ArgoCD application stays `Progressing`.
- The KEDA pods are `Running` and ready, but the APIService is unavailable:

```shell
kubectl get apiservice v1beta1.external.metrics.k8s.io
```

Typical failure:

```text
FailedDiscoveryCheck ... Get "https://<pod-ip>:6443/apis/external.metrics.k8s.io/v1beta1": EOF
```

The metrics adapter logs can also show gRPC handshake failures when it cannot reach `keda-operator:9666`.

### Resolution: Keep KEDA Outside Ambient

Keep `keda` out of the ambient mesh in `helm-charts/namespaces/values.yaml`:

```yaml
- name: keda
  ambient: false
```

If ArgoCD has already applied ambient labels, remove them and restart the KEDA deployments:

```shell
kubectl label ns keda \
  istio.io/dataplane-mode- \
  istio.io/use-waypoint- \
  istio.io/use-waypoint-namespace- \
  istio.io/ingress-use-waypoint-
kubectl -n keda rollout restart deploy/keda-admission-webhooks deploy/keda-operator deploy/keda-operator-metrics-apiserver
kubectl -n keda rollout status deploy/keda-admission-webhooks
kubectl -n keda rollout status deploy/keda-operator
kubectl -n keda rollout status deploy/keda-operator-metrics-apiserver
```

After the restart, confirm the external metrics API is available:

```shell
kubectl get apiservice v1beta1.external.metrics.k8s.io
```

---

## Metrics Server API Fails Through Ambient

Metrics Server exposes `metrics.k8s.io` through a Kubernetes aggregated APIService. The kube-apiserver calls
metrics-server directly on its HTTPS endpoint. In this cluster, metrics-server pods must opt out of ambient
redirection even though the `monitoring` namespace remains ambient-enrolled.

### Symptoms: Metrics Server API

- `kubectl top nodes` or `kubectl top pods` intermittently returns `ServiceUnavailable`.
- HPAs show `FailedGetResourceMetric` or `FailedComputeMetricsReplicas`.
- The metrics APIService is unavailable or flaps:

```shell
kubectl get apiservice v1beta1.metrics.k8s.io
```

Typical failure:

```text
FailedDiscoveryCheck ... Get "https://<pod-ip>:10250/apis/metrics.k8s.io/v1beta1": EOF
```

### Resolution: Keep Metrics Server Pods Outside Ambient

Keep the metrics-server pod template out of ambient in `helm-charts/metrics-server/values.yaml`:

```yaml
metrics-server:
  podLabels:
    istio.io/dataplane-mode: none
```

If ArgoCD has already applied ambient labels to running metrics-server pods, restart the deployment:

```shell
kubectl -n monitoring rollout restart deploy/metrics-server
kubectl -n monitoring rollout status deploy/metrics-server
```

After the restart, confirm the metrics API is available and stable:

```shell
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
```

---

## Encrypted Longhorn Volumes Do Not Reclaim Space After Trim

Encrypted Longhorn volumes can keep consuming backing storage after files are deleted, even when the
Longhorn `filesystem-trim` recurring job exists.

An earlier workaround used the `cypto-volume-allow-discards` DaemonSet to run the refresh loop on every
node. That solved the trim flag problem, but it created a worse security posture: an always-running
privileged pod mounted host `/dev`, mounted the `longhorn-crypto` Secret, installed packages at runtime,
and logged host `dmsetup table` output including device-mapper state.

### Symptoms: Longhorn Encrypted Trim

- Longhorn volume `actualSize` does not drop after deleting data from a filesystem.
- The Longhorn `filesystem-trim` recurring job runs, but little or no space is reclaimed.
- `cryptsetup luksDump /dev/longhorn/<volume>` does not show `allow-discards` in the `Flags` line.
- A helper pod named `cypto-volume-allow-discards-*` is running in `longhorn-system`, keeping privileged
  host-device and crypto-key access alive continuously.

### Cause: Missing Dm-Crypt Discard Flag

Longhorn can trim filesystems with the `filesystem-trim` recurring job, but encrypted Longhorn volumes need
the dm-crypt mapping to allow discards first. Longhorn does not provide a supported StorageClass or chart
setting for this because upstream treats automatic encrypted discard enablement as a security tradeoff.

Enabling discards can reveal allocation patterns, used space, and deletion activity to a layer that can observe
the backing device. This repo accepts that tradeoff for selected Longhorn volumes to recover disk space, but
the operation should be short-lived and explicit.

### Resolution: Enable Persistent Discards

Use `make trim` after creating or restoring encrypted Longhorn volumes. The same idempotent check also runs at
the end of `make maintenance`.

Do not keep a privileged pod running for this task. The old `cypto-volume-allow-discards` DaemonSet is
replaced by the `make trim` workflow and should not exist in the chart or cluster.

To target one attached encrypted volume:

```shell
make trim <longhorn-volume-name>
```

The target checks matching attached encrypted volumes first. If a volume is missing `allow-discards`, it
feeds the `longhorn-crypto` key to `cryptsetup` over stdin with `--key-file=-`, runs
`cryptsetup --allow-discards --persistent refresh`, and verifies the flag. The Ansible path does not write
the key to a local or remote filesystem.

### Manual Diagnosis

List encrypted Longhorn volumes and the node where each attached volume is currently mounted:

```shell
kubectl -n longhorn-system get volumes.longhorn.io -o json \
  | jq -r '
      .items[]
      | select(.spec.encrypted == true)
      | [
          .metadata.name,
          .status.state,
          (.status.robustness // "unknown"),
          (.status.currentNodeID // "")
        ]
      | @tsv' \
  | sort
```

Check a target volume:

```shell
VOLUME=<longhorn-volume-name>
NODE=<node-name>
ssh "pi@${NODE}" "sudo cryptsetup luksDump /dev/longhorn/${VOLUME} | awk -F: '/Flags/ {print \$2}'"
```

If the output already includes `allow-discards`, no refresh is needed for that volume.

### Manual Recovery

If `make trim` is not available, refresh the mapping manually without writing the key to disk:

```shell
kubectl -n longhorn-system get secret longhorn-crypto \
  -o jsonpath='{.data.CRYPTO_KEY_VALUE}' \
  | base64 --decode \
  | ssh "pi@${NODE}" \
      "sudo -n cryptsetup --key-file=- --allow-discards --persistent refresh '${VOLUME}'"
```

Verify the flag:

```shell
ssh "pi@${NODE}" "sudo cryptsetup luksDump /dev/longhorn/${VOLUME} | awk -F: '/Flags/ {print \$2}'"
```

Expected output includes:

```text
allow-discards
```

The next scheduled Longhorn `filesystem-trim` job should reclaim space where Longhorn can safely unmap
blocks. Existing snapshots may limit how much space can be recovered.

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
    When feeding the passphrase remotely, do not append a trailing newline. If you store the
    passphrase in the external direnv file, use `direnv exec . ./hack/luks-cryptroot-unlock.sh ... --env-passfifo`
    so the helper gets the value without reading the vault file itself.

7. Do not pass the LUKS password in command arguments during rescue work. Stage it via stdin or a
    root-only temporary file and rotate it if you ever expose it in command text.

8. The one-pass rescue wrapper avoids the earlier manual rebuild failure modes:
    mount ordering, `/boot/firmware` rsync conflicts, and `resolv.conf` symlink handling.

9. If a rebuilt control-plane node fails to rejoin with
    `etcd cluster join failed: duplicate node name found`, cleanly rejoin it:
    uninstall `k3s` on the rebuilt node, delete the stale Kubernetes `Node` object, confirm etcd only has the healthy
    members, then rerun the normal `k3s` join play for that node.

10. After rebuilding a node in place, SSH host key verification can block the rejoin play even
    when the node is otherwise healthy. Remove the old key for both the hostname and IP, or
    temporarily disable host key checking for that one rejoin run.

---

## Missing Child Manifest After Interrupted Pull Causes `exec format error`

**Note:** `exec format error` has at least two unrelated root causes in
this cluster -- this entry (a corrupted local pull, isolated to one
node) and a completely different one where the pinned digest itself is
wrong (see "A Pinned Digest Can Silently Be Single-Arch, Not Multi-Arch"
below). Diagnose which one first: if the same digest works fine on
other nodes of the *same* architecture, it's this entry; if it fails on
every node of one architecture consistently, check the digest itself
next.

**Problem:** After `raspberrypi-03` (arm64) came back from an unrelated
outage and rejoined the cluster, three of the four `istiod` replicas that
landed on it went into `CrashLoopBackOff` with:

```text
exec /usr/local/bin/pilot-discovery: exec format error
```

The fourth replica, on an amd64 node, ran fine. Every other pod already
running on `raspberrypi-03` was unaffected -- this was isolated to one
image. Deleting the pods did not help: the replacements landed on the same
node and hit the same error immediately.

**Why it happens:** `exec format error` means the runtime executed a
binary built for the wrong CPU architecture. The image
(`registry.istio.io/release/pilot:1.30.2-distroless`) is a correctly
published multi-arch manifest list (`linux/amd64,linux/arm64`), so the
image itself is fine. The node's pull was interrupted mid-transfer during
its earlier instability: `k3s ctr -n k8s.io content ls` showed the
top-level manifest-list object present and intact, but one of its two
child platform manifests (found via its
`containerd.io/gc.ref.content.m.*` labels) was **entirely missing** --
`ctr content get <child-digest>` returned `content digest ... not found`.
Since the manifest-list metadata itself looked complete, containerd never
identified the pull as broken and never re-fetched, so every platform
resolution silently fell back to whichever single child manifest actually
existed on disk -- the amd64 one.

A plain `k3s ctr -n k8s.io images rm <ref>` was not enough to fix this: it
only removes the name-to-digest mapping, not the actual content-addressed
blobs, so a fresh pull under the same digest kept resolving against the
same incomplete on-disk content. Restarting `k3s-agent` (which restarts
containerd) also did not help, since the corruption was on disk, not just
an in-memory cache.

### Symptoms: Missing Child Manifest

- `CrashLoopBackOff` with `exec format error` in the pod's log, but only on
  one node, and only for one image.
- Other pods on the same node, including ones using other multi-arch
  images, are unaffected.
- Coincides with that node having recently rejoined the cluster after an
  outage or reboot (an unclean shutdown mid-pull is the likely trigger).
- Deleting the pod, or even restarting `k3s-agent`, does not clear it --
  the replacement pod hits the same error on the same node.

### Resolution: Remove the Content Blob Directly, Not Just the Image Reference

SSH to the affected node. First confirm the diagnosis by checking whether
a child manifest referenced by the top-level manifest-list is actually
missing (k3s bundles its own containerd, so the plain `ctr` binary will
not see the right namespace -- use `k3s ctr`):

```shell
kubectl get pod -n <namespace> <pod> -o jsonpath='{.spec.containers[0].image}{"\n"}{.status.containerStatuses[0].imageID}{"\n"}'
ssh pi@<node-ip> "sudo k3s ctr -n k8s.io content ls | grep <manifest-list-digest>"
# note the containerd.io/gc.ref.content.m.* digests in the label column, then:
ssh pi@<node-ip> "sudo k3s ctr -n k8s.io content get <child-digest>"
# "not found" confirms the missing-child-manifest failure mode
```

Remove the actual content blob (not just the image name), then the
now-dangling image reference, then delete the pod so its controller
recreates it and pulls genuinely fresh content:

```shell
ssh pi@<node-ip> "sudo k3s ctr -n k8s.io content rm <manifest-list-digest> <the-present-child-digest>"
ssh pi@<node-ip> "sudo k3s ctr -n k8s.io images rm <image>:<tag> <image>@<manifest-list-digest>"
kubectl delete pod -n <namespace> <pod>
```

### Variant: Corruption in the Unpacked Snapshot, Not the Content Blob

The same `exec format error` symptom can also occur when the
manifest-list and every content blob (including all layers) check out as
present and intact, but the extracted overlayfs snapshot on disk is
corrupt -- for example a 0-byte file where an entrypoint script should
be. An empty file triggers `ENOEXEC` on `exec`, surfacing as the same
"exec format error".

Confirm by locating the container's snapshot chain and checking the
suspect file directly:

```shell
ssh pi@<node-ip> "sudo k3s crictl inspect <container-id>" # get the SnapshotKey / container id
ssh pi@<node-ip> "sudo k3s ctr -n k8s.io c info <container-id>" # get lowerdir snapshot ids
ssh pi@<node-ip> "sudo file /var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/<id>/fs/<path-to-entrypoint>"
```

Fix the same way as the missing-child-manifest case -- remove the CRI
image record, the image name mapping, and **every** content blob for the
image (manifest-list, platform manifest, config, all layers), then
delete the pod to force a fully fresh pull and re-extraction:

```shell
ssh pi@<node-ip> "sudo k3s crictl rmi <resolved-image-sha>"
ssh pi@<node-ip> "sudo k3s ctr -n k8s.io images rm <image>@<manifest-list-digest>"
ssh pi@<node-ip> "sudo k3s ctr -n k8s.io content rm <manifest-list-digest> <platform-manifest-digest> <config-digest> <layer-digest-1> ..."
kubectl delete pod -n <namespace> <pod>
```

---

## e1000e Detected Hardware Unit Hang

The `nuc-00` worker uses an onboard Intel 82579V Gigabit NIC (`eno1`, PCI
`8086:1503`) driven by `e1000e`. This chipset can stall its transmit queue and
log `Detected Hardware Unit Hang` repeatedly, after which the driver never
recovers. The host stays up but loses all network, so the kubelet cannot reach
the API server and the node goes NotReady while the box appears alive.

### Symptoms: e1000e Hang

- A node goes NotReady but its power light stays on and it keeps logging locally.
- `ping` and the initramfs dropbear port are both unreachable.
- The previous boot's kernel log shows repeated entries like:

```text
e1000e 0000:00:19.0 eno1: Detected Hardware Unit Hang:
  TDH <f8>  TDT <e0>  next_to_use <e0>  next_to_clean <f6>
```

The TX descriptor head (`TDH`) and tail (`TDT`) never advance for the duration of
the hang.

### Cause: TX Offload Stall on 82579

The hang is triggered by the NIC's TCP/generic segmentation offload path on this
silicon. It is a long-standing `e1000e`/82579 hardware quirk, not a Kubernetes or
k3s fault.

### Resolution: Disable Segmentation and Receive Offloads

Persist offload-disabling link settings with a systemd-networkd `.link` file. The
`nuc/000-e1000e-offload.yaml` play (run by `make setup`) writes
`/etc/systemd/network/10-eno1-offload.link`:

```ini
[Match]
OriginalName=eno1

[Link]
TCPSegmentationOffload=false
GenericSegmentationOffload=false
GenericReceiveOffload=false
```

systemd-udevd applies these at device initialisation. To apply live without a
reboot (toggling offloads does not bounce the carrier):

```shell
sudo udevadm control --reload
sudo udevadm trigger --action=add /sys/class/net/eno1
ethtool -k eno1 | grep -E 'segmentation-offload|generic-receive'
```

If the hang recurs after offloads are disabled, the cause is likely deeper:
disable PCIe ASPM (`pcie_aspm=off` or BIOS C-states) or treat the NIC as failing
hardware.

### Recovery After a Hang

`nuc-00` is a LUKS-root node. A hung NIC means a power cycle is required, then a
LUKS unlock before it rejoins:

```shell
make unlock nuc-00
```

Once booted, Longhorn re-attaches its volumes automatically.

## MetalLB LoadBalancer VIP Unreachable When nuc-00 Announces It

### Symptoms: LoadBalancer VIP Unreachable

An off-cluster client can reach the k3s API server VIP (`192.168.10.50`) but
gets no response at all from another MetalLB LoadBalancer VIP on the same
`192.168.10.0/24` subnet (for example the `gateway` Service at
`192.168.10.51`). `traceroute` to the working VIP shows the router forwarding
the packet onto the cluster segment and getting an answer; `traceroute` to
the broken VIP shows the router itself returning `!H` (host unreachable) at
the first hop, meaning nothing ever answered ARP for that IP.

### Cause: L2Advertisement Interface Name Does Not Exist on nuc-00

`nuc-00`'s onboard NIC is named `eno1`, not `eth0` (see the e1000e entry
above). An `L2Advertisement` that specifies `interfaces: [eth0]` with no
node restriction works fine while a Raspberry Pi is announcing the VIP, but
the moment MetalLB elects `nuc-00` as the announcing node for that IP, its
speaker cannot find an interface named `eth0` and logs:

```text
"the specified interfaces used to announce LB IP don't exist","localIfs":["eno1"]
```

No local interface then answers ARP for the VIP, so it goes dark for every
off-cluster client until leadership moves to a different node — which can
take hours or days, since MetalLB does not fail over an already-announced IP
just because the interface list is wrong.

### Resolution: Split the L2Advertisement Per Node

Give `nuc-00` its own `L2Advertisement` for the same `IPAddressPool`, scoped
to `nodeSelectors: [{matchLabels: {kubernetes.io/hostname: nuc-00}}]` with
`interfaces: [eno1]`, and restrict the original `eth0` advertisement to the
four Raspberry Pi nodes. `helm-charts/metallb-vip/values.yaml` already used
this pattern for the API server VIP; `helm-charts/envoy-gateway` did not,
which is why only the `gateway` VIP was affected. Check any other
`L2Advertisement` in the repo for the same single-interface, no-node-split
shape before it bites the same way.

---

## changedetection `latest` image tag resets the watch list

**Problem:** The changedetection deployment lost its entire watch list and
came back with only the fresh-install defaults.

**Why it happens:** The image was pinned as
`ghcr.io/dgtlmoon/changedetection.io:latest@sha256:...`. The `latest` label is
mutable, so a Renovate digest bump or a fresh pull can land a newer
changedetection release on restart. Newer releases run datastore migrations
(the datastore moved to a per-watch `{uuid}/watch.json` layout with settings
in `changedetection.json`). A migration that does not carry the old watches
over leaves the app looking freshly installed.

A separate observed wipe path is a filesystem reformat at the CSI/crypto
attach layer on `changedetection-vol` (encrypted, single-replica). That also
reseeds defaults and is not recoverable from app-level migrations.

**Recovery limits:** The Longhorn `backup` recurring job for
`changedetection-vol` has been weekly (`0 4 * * 0`) with `retain: 1`. Only the
most recent weekly snapshot/backup is kept, so once a bad state is captured
it overwrites the last good copy within a week. There is no restore point
older than the loss. Treat changedetection watch data as low-durability until
the retention window is deepened.

**Fix:** Pin the image to a concrete version tag instead of `latest` in
`helm-charts/changedetection/values.yaml`. Version `0.55.7` resolved to the
same digest `latest` pointed to at the time of the pin, so pinning was a no-op
for the running pod while stopping uncontrolled migrations. Renovate then
proposes controlled version bumps that can be reviewed before they apply.
Deepen backup retention in a separate change if watch data must survive a
bad state.

---

## `kor` unused-resource scanner has a high false-positive rate

**Problem:** `kor all` flags dozens of ConfigMaps, Secrets,
RoleBindings, and ClusterRoleBindings as "unused" that are, in fact, all
in active use.

**Why it happens:** `kor` only detects a resource as "used" if a pod
mounts it as a volume or pulls it in via `env`/`envFrom`. It cannot see
several other legitimate reference styles that are common in this
cluster:

- **Read via the Kubernetes API by a controller, never mounted.** Istio
  ambient mesh distributes `istio-ca-crl` and `istio-ca-root-cert`
  ConfigMaps into every namespace for `ztunnel`/`istiod` to read directly
  via the API — this alone accounted for ~74 of 93 flagged ConfigMaps in
  one scan. The same pattern explains flagged leader-election ConfigMaps
  (`kyverno`, `istio-leader`, `istio-namespace-controller-election`,
  `cnpg-controller-manager-config`), heartbeat-operator Secrets
  (`*-heartbeat`), and webhook TLS Secrets
  (`cert-manager-webhook-ca`, `longhorn-webhook-ca`, `envoy*`).
- **Referenced by a CRD's spec field, not a pod.** cert-manager
  `Issuer`/`Certificate` objects reference Secrets
  (`letsencrypt`, `tls-certificate`,
  `cloudflare-acme-verification-secret`) by name in their own CRD spec —
  `kor` has no notion of this.
- **Cross-namespace RoleBinding subjects.** A `RoleBinding` in
  `kube-system` binding a ServiceAccount that lives in a *different*
  namespace (for example `cert-manager-cainjector:leaderelection` binds
  `cert-manager/cert-manager-cainjector`) is reported as "references a
  non-existing ServiceAccount". The subject exists; `kor` does not
  correctly resolve the subject's own `namespace` field for this check.
- **A separate live bug** can poison the `ClusterRoleBinding` check
  entirely: `Failed to get clusterRoles: couldn't convert string to bool
  strconv.ParseBool: parsing "kyverno": invalid syntax` (seen on v0.6.8).
  When this error fires, every `ClusterRoleBinding` in the scan may be
  reported as referencing a non-existing `ClusterRole` even when the role
  exists — verify with `kubectl get clusterrole <name>` before trusting
  any `ClusterRoleBinding` finding from a scan where this error appeared.
- `ReplicaSet` and `Crd` findings are expected noise, not orphans: old
  ReplicaSets are normal `revisionHistoryLimit` retention, and "unused"
  CRDs are bundled platform schema (Istio, Gateway API, external-secrets,
  Kyverno, Longhorn, KEDA) with zero instances of that particular kind
  created yet, not something to remove.

**Fix:** Never act on a raw `kor` finding. Cross-check with `kubectl get
<kind> <name>` (for RBAC) or trace the actual consumer (controller
logs/spec references) before treating anything as a genuine orphan.
Confirmed genuine finds so far: the leftover `monitoring-grafana-test`
ConfigMap/ServiceAccount pair (also flagged separately by `popeye`'s
`POP-400`), and the unused `longhorn`/`longhorn-static` StorageClasses
(every PVC in the cluster uses `longhorn-crypto-global` instead).

---

## `runAsNonRoot: true` Needs a Numeric `runAsUser` for Named-User Images

**Problem:** A container-hardening pass added `securityContext.
runAsNonRoot: true` to several apps' charts without also setting
`runAsUser`, leaving each new ReplicaSet stuck in
`CreateContainerConfigError`. The old ReplicaSet kept running each time, so
there was no outage, but the rollout could not complete. Hit repeatedly
across unrelated apps in the same change: `httpbin`, `teslamate`, `umami`,
and `changedetection`'s browser sidecar.

**Why it happens:** Each image's non-root user is a named user in the
image's config (`httpbin`, `nonroot`, `nextjs`, `chrome` respectively), not
a numeric UID. Kubelet can only verify `runAsNonRoot` against a numeric
UID; it cannot resolve a named user from the image, so it refuses to start
the container rather than risk running as root. A plain `docker run` with
the same `securityContext` does not reproduce this, since Docker does not
enforce Kubernetes' stricter numeric-UID check — verifying a hardening
change via Docker alone is not sufficient.

**Detection before rollout:** Check the image's config `User` field
directly rather than trusting a `docker run ... id` resolution (that
resolves a name to a UID at runtime and looks fine either way):
`docker image inspect <image>@<digest> --format '{{.Config.User}}'`. If the
result is a name rather than a number, an explicit numeric `runAsUser` is
required.

**Fix:** Set an explicit numeric `runAsUser` (and `runAsGroup` where the
image's group is also named) alongside `runAsNonRoot: true`. Find the
correct UID/GID from a still-running pre-hardening pod: `kubectl exec <pod>
-- id`, or from the image directly: `docker run --rm --entrypoint id
<image>@<digest>`.

---

## `longhorn-csi-plugin` OOMKilled Mounting Many LUKS Volumes Concurrently

**Problem:** A pod requesting many Longhorn PVCs at once (`jellyfin`, with
13 volumes including one 320Gi volume) got stuck in `ContainerCreating`
indefinitely. `longhorn-csi-plugin` on the node it landed on repeatedly
crashed with `OOMKilled` (exit 137), dying within 16 seconds of starting
each time, even after its memory limit was raised several times (64Mi up
through 2Gi). Every one of the pod's volumes failed to mount at once with
`rpc error: code = Unavailable desc = error reading from server: EOF` or
`connection refused` to the CSI socket, since the whole plugin process
(handling every volume on that node, not just this pod's) was down.

**Why it happens:** Every PVC on this cluster uses the `longhorn-crypto-
global` StorageClass, which is LUKS-encrypted. `cryptsetup luksDump
/dev/longhorn/<volume>` shows the key-derivation function is `argon2i`,
deliberately memory-hard, with a `Memory` cost of ~65MiB *per unlock*.
When a single pod's volumes are all mounted at pod-start, `longhorn-csi-
plugin` runs `NodeStageVolume` for all of them concurrently in the same
container, so the KDF memory cost multiplies by the number of volumes:
13 volumes x ~65MiB is already ~845MiB, before the plugin's own per-volume
gRPC/goroutine overhead and page-cache pressure from probing several
100+Gi filesystems at once. There is no Longhorn setting to throttle or
serialise concurrent mount/attach operations (checked the full Helm values
schema -- the only concurrency limits are for replica rebuilds, backups,
and engine upgrades), and there is no official per-volume memory sizing
formula for this container. Two related upstream issues,
[longhorn/longhorn#12225][longhorn-12225] and
[longhorn/longhorn#6645][longhorn-6645], confirm this class of memory
scaling is a known, unresolved, undocumented area.

### Symptoms: LUKS Concurrent-Mount OOM

- A pod with many PVCs sits in `ContainerCreating` indefinitely.
- `kubectl get pod -n longhorn-system -l app=longhorn-csi-plugin
  --field-selector spec.nodeName=<node>` shows `CrashLoopBackOff` with
  `OOMKilled`, often within seconds of each restart.
- Every volume the stuck pod needs fails to mount at the same instant with
  `connection refused` or `error reading from server: EOF` against the CSI
  socket -- because the plugin process itself is down, not because of a
  problem with any individual volume.
- Other pods with only one or two volumes on the same node are unaffected
  until the crash-loop is bad enough to take the whole node's CSI plugin
  down for everyone.
- Raising `systemManagedCSIComponentsResourceLimits.longhorn-csi-
  plugin.limits.memory` in steps (doubling) keeps getting further before
  crashing but does not resolve on the first few attempts, since the real
  requirement scales with volume count, not a fixed baseline.

### Resolution: Confirm the KDF Cost, Then Size for the Worst Case

Confirm the mechanism before assuming a fixed number will work:

```shell
ssh <user>@<node-ip> "sudo cryptsetup luksDump /dev/longhorn/<a-volume> | grep -iE 'PBKDF|Memory'"
```

Multiply the reported `Memory` (in KiB) by the worst-case number of
volumes any single pod in the cluster requests concurrently, then size
`helm-charts/longhorn/values.yaml`'s
`systemManagedCSIComponentsResourceLimits.longhorn-csi-plugin.limits.memory`
with solid margin above that (this cluster settled on 4Gi for a 13-volume,
~845MiB-KDF-floor workload). Keep the matching `.requests.memory` low
(e.g. 64Mi) and decoupled from the limit -- this is a rare startup spike,
not a steady-state need, and reserving the full limit as a request on
every node (it is a DaemonSet) will itself cause scheduling failures on an
already busy cluster.

---

[envoy-issue]: https://github.com/envoyproxy/envoy/issues/23339
[metallb-troubleshooting]: https://metallb.universe.tf/troubleshooting/#using-wifi-and-cant-reach-the-service
[cilium-issue]: https://github.com/cilium/cilium/issues/19038
[longhorn-issue]: https://github.com/longhorn/longhorn/issues/4143
[longhorn-12225]: https://github.com/longhorn/longhorn/issues/12225
[longhorn-6645]: https://github.com/longhorn/longhorn/issues/6645

---

## Multi-Container Pods Fail to Schedule Despite "Enough" Free Cluster Memory

**Problem:** `teslamate-verify-pitr`'s daily PITR (point-in-time-recovery)
verification Job repeatedly got stuck `Pending` for hours, failing with
`0/5 nodes are available: 5 Insufficient memory`, even though the cluster
had roughly 2-3GiB of memory free in aggregate at the time. The obvious
assumption -- "the job barely needs any memory, why is this failing?" --
was also wrong: the visible CronJob controller container only requests
128Mi, but it spins up a separate, dynamically-created recovery pod with
**three** containers (`bootstrap-controller` 512Mi,
`plugin-barman-cloud` 1Gi, `full-recovery` 512Mi) totalling **2Gi**, and
all three must land on the same node. Manually re-running the job
(`kubectl create job --from=cronjob/teslamate-verify-pitr ...`) confirmed
it failing live, ruling out a one-off fluke.

**Why it happens:** free memory was real but scattered -- every node
individually had less than 2GiB free, even though summed together there
was enough. This is a distribution problem, not a capacity problem, and
it's made structurally worse by two Kubernetes defaults fighting each
other:

- `kube-scheduler`'s default `NodeResourcesFit` scoring strategy is
  `LeastAllocated`, which always prefers placing new pods on the
  emptiest node.
- Descheduler's `LowNodeUtilization` strategy (this cluster's original
  config) is a no-op once every node is simultaneously above its
  `targetThresholds` -- it needs an already-underutilized node to land
  evicted pods on, and a cluster running hot everywhere never has one.
- Even after adding descheduler's `HighNodeUtilization` strategy (which
  *does* evict pods off the least-loaded node to grow contiguous free
  space there), the default `LeastAllocated` scheduler bias immediately
  refills that same node with new pods, since it's still the emptiest
  choice available. Confirmed live: evicting several pods from the
  least-loaded node only netted a partial, temporary improvement before
  the scheduler placed replacements straight back onto it.

### Symptoms: Scattered-Memory Scheduling Failures

- `FailedScheduling` events citing `Insufficient memory` (or `cpu`/`pods`)
  across **all** nodes, for a Job or Deployment that "shouldn't" need
  that much.
- `kubectl describe node <node>` shows meaningful free memory on
  individual nodes, but always less than the failing pod's *combined*
  container requests -- check every container in the pod spec, not just
  the one you expect, since sidecars/init containers add up.
- Descheduler logs (`kubectl logs -n descheduler -l
  app.kubernetes.io/name=descheduler`) show `HighNodeUtilization`
  evicting pods, but the same or similar pods reappear on the same node
  shortly after in `kubectl get pods -A -o wide`.
- Node memory-request percentages sit in a narrow, uniformly-high band
  (e.g. 83-97%) across every node -- no single node is meaningfully more
  free than the rest.

### Resolution: Pair Descheduler's HighNodeUtilization With a MostAllocated Scheduler

Two changes, both required -- one alone just causes eviction churn
without net progress:

1. **`helm-charts/descheduler/values.yaml`** -- add a second profile
    (`HighNodeUtilization` cannot share a profile with
    `LowNodeUtilization`; they have opposite goals) that evicts pods from
    whichever node is below a memory threshold, to be rescheduled
    elsewhere:

    ```yaml
    - name: consolidate
      pluginConfig:
        - name: DefaultEvictor
          args:
            podProtections:
              defaultDisabled:
                - PodsWithLocalStorage
        - name: HighNodeUtilization
          args:
            thresholds:
              cpu: 100
              memory: 90
              pods: 100
      plugins:
        balance:
          enabled:
            - HighNodeUtilization
    ```

2. **`kube-scheduler` config** -- flip the default `LeastAllocated`
    scoring to `MostAllocated`, so newly-scheduled pods actively prefer
    already-fuller nodes instead of refilling whatever descheduler just
    freed up:

    ```yaml
    apiVersion: kubescheduler.config.k8s.io/v1
    kind: KubeSchedulerConfiguration
    clientConnection:
      kubeconfig: /var/lib/rancher/k3s/server/cred/scheduler.kubeconfig
    profiles:
      - schedulerName: default-scheduler
        pluginConfig:
          - name: NodeResourcesFit
            args:
              scoringStrategy:
                type: MostAllocated
                resources:
                  - name: memory
                    weight: 1
                  - name: cpu
                    weight: 1
    ```

    On k3s, this file must exist on disk on every control-plane node
    *before* the server starts, referenced via
    `--kube-scheduler-arg --config=<path>` on the `curl ... | sh -s -`
    install command (see `ansible/playbooks/k3s/000-init-cluster.yaml`
    and `002-nodes.yaml`). Applying it means restarting the k3s server
    process (scheduler is embedded in the same binary as the API server)
    on every control-plane node -- roll out **one node at a time**, not
    all at once, and confirm each one starts cleanly
    (`journalctl -u k3s`, look for `"Starting Kubernetes Scheduler"` with
    no immediately-following fatal errors) before moving to the next.

Applied together, node memory usage stops being uniform: the
least-loaded node keeps getting emptier (consolidation actually sticks)
while the rest absorb the difference. Verified live in this incident --
the previously-failing Job's pod scheduled and completed successfully
immediately after rollout, with no other change needed.

### Gotcha During Rollout: Transient API VIP Blip

Restarting all 3 control-plane nodes' k3s processes (even one at a time)
can briefly disrupt the cluster's API VIP if it is itself backed by a
MetalLB-announced `LoadBalancer` Service (see
[k3s-apiserver-loadbalancer][k3s-apiserver-loadbalancer]) rather than a
static IP -- `metallb-controller`'s L2 announcement election can lag by
under a minute while it re-settles after a node it was scheduled on
restarts. Confirmed via direct `https://<node-ip>:6443/livez` checks on
every master that the cluster itself was never actually down, only the
VIP's announcement was briefly stale. No action needed; it resolves on
its own once MetalLB's speakers re-converge.

[k3s-apiserver-loadbalancer]: https://github.com/siutsin/k3s-apiserver-loadbalancer

---

## A Pinned Digest Can Silently Be Single-Arch, Not Multi-Arch

**Problem:** `changedetection-browser`'s pinned `busybox:1.38.0` digest
(`sha256:8f2ffdcb...`) worked fine for months, then both containers using
it (`cleanup-browser-metrics` init container and the
`cleanup-browser-metrics-loop` sidecar) suddenly hit `exec /bin/sh: exec
format error` the moment the pod first landed on `nuc-00` (amd64) --
descheduler's `PodLifeTime` plugin repaved it there for the first time
after it had spent its whole life on arm64 raspberrypi nodes. Only one
replica exists, so this was real, immediate user-facing impact.

**Why it happens:** the pinned digest was never actually a multi-arch
manifest -- it was the **arm64-specific child manifest** of the
`busybox:1.38.0` tag, not the top-level multi-arch index. This is an easy
mistake when copying a digest from `docker inspect`, a registry UI, or a
CI log on an arm64 machine: several of those paths report the
platform-specific manifest digest, not the index digest, and nothing
about the digest string itself reveals which one you have. It works
perfectly forever as long as the pod only ever schedules onto nodes of
that one architecture -- which is exactly what happened here until
`PodLifeTime` started deliberately reshuffling pods across the whole
fleet.

This is a different failure mode from "Missing Child Manifest After
Interrupted Pull" above: there, a *correct* multi-arch digest becomes
locally corrupted on one node. Here, the digest itself was wrong from
the start, cluster-wide, on every node -- it just never got exercised on
the "wrong" architecture before.

### Symptoms: Wrong-Architecture Pinned Digest

- `exec format error` for a pinned-digest image, but -- unlike the
  corrupted-pull case -- it fails the **same way on every node of one
  architecture**, not just one specific node.
- Coincides with a pod landing on an architecture it has never run on
  before (a manual reschedule, a new descheduler policy, a node taken
  out of rotation, etc.) rather than a node outage/rejoin.
- `kubectl describe pod` shows no scheduling errors -- the pod scheduled
  fine, pulled fine, and only fails at container start.

### Resolution: Verify and Re-Pin the Index Digest

Confirm what a pinned digest actually resolves to before trusting it,
directly against a node's own containerd (k3s bundles its own, so use
`k3s ctr`, not plain `ctr`):

```shell
ssh <user>@<node-ip> "sudo k3s ctr -n k8s.io images ls | grep <image>"
```

The `PLATFORMS` column tells the truth: a real multi-arch index lists
several platforms (`linux/amd64,linux/arm64,...`); a single-arch child
manifest lists exactly one. If a pinned digest shows one platform, it is
wrong regardless of how long it has worked.

Get the correct index digest from the registry directly (works for any
public Docker Hub image, no `docker` daemon required):

```shell
TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/<image>:pull" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")
curl -s -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json" \
  -I "https://registry-1.docker.io/v2/library/<image>/manifests/<tag>" \
  | grep -i docker-content-digest
```

Re-pin the chart to that digest. Cross-check it matches what a node of
each architecture actually has cached as a multi-platform index before
considering it confirmed.

### Recurrence: Forced Architecture Pins Masking the Same Bug

The same mispinning recurred three more times, discovered on
2026-07-18 while investigating two separate stuck-`Pending` incidents
(`monitoring-prometheus-node-exporter` and `argocd-repo-server`, both
`FailedScheduling` on insufficient memory): `ghcr.io/openclaw/openclaw`,
`busybox:1.38.0` (openclaw's init container), and
`ghcr.io/siutsin/images/go-jsonnet` (the `argocd-repo-server` CMP
sidecar) were all pinned to their arm64 child manifest instead of the
index. Because these images were believed arm64-only, `openclaw` and
`argocd-repoServer` both carried a `nodeSelector: kubernetes.io/arch:
arm64`, which is exactly what turned an ordinary memory-pressure
scheduling squeeze into a stuck rollout: neither pod could fall back to
`nuc-00` (amd64) even when it had free headroom. One of the three --
`go-jsonnet` -- had a comment stating it "ships an arm64-only binary"
that was accurate when written; the image gained a real amd64 build
later and nobody revisited the pin or the nodeSelector. Removing the
mispinned digest and the nodeSelector let the next rollout land on
`nuc-00` immediately, confirming the fix.

**Lesson:** an "arch-only" comment on an image pin is a claim about the
image at the time it was written, not a durable fact. Treat any
`nodeSelector: kubernetes.io/arch` on a workload as a hypothesis to
re-verify, not a permanent constraint -- especially once the underlying
digest has been re-pinned to a real multi-arch index.

### Prevention: Automated CI Check

`hack/check-image-digests.sh` (wired into `make test` as
`check-image-digests`) scans every `helm-charts/**/*.yaml` for pinned
`repository:tag@digest` references, queries each image's registry for
the tag's current manifest, and fails the build if a pinned digest
matches a single-platform child manifest of an index rather than the
index itself. Network or auth failures against a registry are reported
as warnings, not build failures, so a transient registry hiccup doesn't
block unrelated PRs -- only a confirmed mispin does.

---

## ArgoCD Cannot Sync Some Large CRDs -- No Safe Fix Found, Accepted As-Is

**Problem:** forcing a fresh sync of the `external-secrets` Application
reproducibly failed with:

```text
CustomResourceDefinition.apiextensions.k8s.io
"clustersecretstores.external-secrets.io" is invalid:
metadata.annotations: Too long: may not be more than 262144 bytes
```

Live objects were small and healthy (tens of bytes of annotations,
nowhere near the 256KiB cap), and a plain `kubectl apply --server-side`
or `kubectl replace` of the identical rendered manifest succeeded
cleanly every time run directly. **Only ArgoCD's own sync attempt for
these two specific CRDs fails -- there is no live impact.** The CRDs
stay `Synced` and functional; the `onepassword-secret-store`
`ClusterSecretStore` and every `ExternalSecret` in the cluster keep
working throughout.

**Four fixes were tried and investigated; none were safe/effective:**

1. `ServerSideApply=true` in `syncOptions` -- already the repo default
    for every Application. No effect.
2. `argocd.argoproj.io/compare-options: ServerSideDiff=true` -- a
    separate setting from `ServerSideApply` (the former governs the
    *diff* step, the latter the *apply* step). Tested live with a fresh
    forced sync: identical failure.
3. `Replace=true` in `syncOptions` -- ArgoCD's own docs describe this
    as the fix for "resource specifications too large for the standard
    last-applied-configuration annotation" and say it takes precedence
    over Server-Side Apply. Tested live (automated sync disabled first
    so `selfHeal` couldn't silently revert the test config).
    `argocd-application-controller` logs still showed
    `serverSideApply:false` and the identical error -- not actually
    honored for this resource in this ArgoCD version.
4. `helm.skipCrds: true` -- has no effect here because these CRDs are
    rendered via a normal Helm *template*
    (`templates/crds/clustersecretstore.yaml`), not the dedicated Helm
    `crds/` directory convention that `skipCrds` actually targets.
    Confirmed live: identical failure, and the CRDs correctly stayed
    `Synced`/not-pruned throughout (this option would have been
    dangerous if it *had* worked as originally assumed -- removing a
    still-referenced CRD from the desired manifest with `prune: true`
    enabled marks it for deletion, cascading to delete every live
    custom resource of that kind).
5. **Considered, ruled out without testing:** the upstream chart does
    expose `crds.createClusterSecretStore`/`processClusterStore` (and
    the `SecretStore` equivalents) to disable these CRDs entirely at
    the chart level. Not used -- disabling `processClusterStore` stops
    the operator from reconciling `ClusterSecretStore` at all, which
    would break the `onepassword-secret-store` this entire cluster's
    secret-fetching depends on. A real fix for the sync error, but with
    consequences far worse than the problem it solves.

**Why it happens:** not fully root-caused at the ArgoCD-internals
level -- despite three different documented sync-option fixes and one
Helm-level toggle, this specific combination of a very large CRD
(`external-secrets`' generator CRDs carry huge embedded OpenAPI
schemas) and this ArgoCD version's sync engine could not be made to
apply it successfully through any option tried. The failure is
specific to ArgoCD's own sync/apply codepath for these two resources,
not the objects themselves, not the cluster, and not anything that
depends on them.

### Current status: real upstream fix identified, waiting on a stable release

Confirmed via the upstream issue tracker (2026-07-14) that this is a
known bug, root-caused and properly fixed upstream:
[argoproj/argo-cd#28440][argocd-28440] ("fix: fix failure on Sync of
resources that do not fit into last-applied-configuration") replaces
the previous broken client-dry-run/server-dry-run workaround with a
proper one, and adds e2e tests specifically for manifests over 256KiB.

- Merged into `argoproj/argo-cd` main on 2026-06-30.
- Cherry-picked into `v3.5.0-rc2` (pre-release, 2026-07-01) --
  confirmed present in that release's changelog.
- **Not** in `v3.4.5` (latest *stable* release, 2026-07-09) -- checked
  its changelog directly, this fix is not cherry-picked into the 3.4.x
  line. This cluster runs `v3.4.4`.

**Decision:** wait for `v3.5.0` to reach a stable (non-`-rc`) release
rather than run a release candidate on the GitOps control plane for a
cosmetic issue with zero live impact. Revisit this Application's sync
once the cluster's ArgoCD version is upgraded to `v3.5.0` or later --
check the release changelog for `#28440`/`#28421` to confirm the fix
landed before assuming it's resolved.

[argocd-28440]: https://github.com/argoproj/argo-cd/pull/28440

## Ambient DNS Capture Steals Envoy Gateway North-South DNS to Blocky

**Problem:** Blocky pods are healthy and block ads when queried on the pod IP
from a hostNetwork probe, but digs to the gateway VIP `192.168.10.51:53`
return real A records for denylisted domains (for example `doubleclick.net`)
and Blocky's `blocky_query_total` barely moves. Grafana shows almost no
requests even though clients appear to use the VIP.

**Why it happens:** the `gateway` namespace is ambient-enrolled so Envoy can
use the mesh path to TCP/HTTP backends. Ambient DNS capture (default from
Istio 1.25) intercepts **outbound** connections from those Envoy pods to
destination port 53. Envoy's UDPRoute/TCPRoute still thinks it is proxying
to `blocky-dns` endpoints, but ztunnel answers the query via the cluster DNS
path instead of delivering the packet to Blocky. Access logs can show
`upstream_host` set to a Blocky pod IP with a ~155-byte unblocked answer,
which is misleading.

**Fingerprint:**

| Path | `doubleclick.net` | `unifi` |
| ---- | ----------------- | ------ |
| Blocky pod IP (hostNetwork dig) | `0.0.0.0` | `192.168.10.1` TTL 3600, one answer |
| VIP while capture is on | real Google IPs | often TTL 5 / two answers / wrong source |
| VIP after capture is off | `0.0.0.0` | `192.168.10.1` TTL 3600, one answer |

**Resolution:** set `ambient.istio.io/dns-capture: "false"` on the Envoy
proxy pod template (`EnvoyProxy` → `envoyDeployment.pod.annotations`). Also
keep the `blocky-dns` Service off the shared waypoint
(`istio.io/use-waypoint: none`) so plain DNS stays L4 to Blocky endpoints;
the HTTP `blocky` Service can remain waypoint-bound for DoH/metrics AuthZ.

**Verify after change:**

```shell
dig @192.168.10.51 doubleclick.net +short   # expect 0.0.0.0
dig @192.168.10.51 unifi +short             # expect 192.168.10.1
```

Do not dig Blocky pod IPs from a LAN laptop: `10.42.0.0/16` is not routed
off-cluster, so those queries time out without saying anything about Blocky
health.
