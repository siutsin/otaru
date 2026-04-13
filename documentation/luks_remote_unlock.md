# LUKS remote unlock and recovery

This runbook covers the early-boot unlock flow for LUKS-encrypted root on SSD-backed nodes.

Current development target:

- `raspberrypi-01`

Assumptions:

- the node has `dropbear-initramfs` configured
- initramfs networking is statically configured
- initramfs `dropbear` gives a shell on port `1024`
- your SSH public key is present in `/etc/dropbear/initramfs/authorized_keys`
- the first-node workflow uses explicit manual SSH unlock, not automated reboot helpers

## Expected connection details

Current defaults from inventory:

- host: node static IP, for example `192.168.10.61`
- user: `root`
- initramfs SSH port: `1024`

The initramfs environment is temporary. Host keys and prompts there are not the same as the normal
host OS after boot.

## Unlock the node

Preferred path when initramfs is already waiting on `Please unlock disk cryptroot`:

```shell
printf '%s' '<your LUKS passphrase>' | ./hack/luks-cryptroot-unlock.sh 192.168.10.61 --passfifo
```

You can use the Make shortcut:

```shell
make unlock raspberrypi-01
```

If you keep the passphrase in local `.envrc`, use:

```shell
direnv exec . ./hack/luks-cryptroot-unlock.sh 192.168.10.61 1024 --env-passfifo
```

To target a different node:

```shell
make unlock raspberrypi-02
```

This feeds the exact passphrase bytes into initramfs'
`cryptroot-unlock` helper, which waits for the real `askpass` process and only
returns once cryptsetup has accepted or rejected the passphrase.

Do not append a trailing newline here. The remote helper is now wired to match
the working console prompt semantics exactly.

To inspect the initramfs shell directly, use the helper script without a
command:

```shell
./hack/luks-cryptroot-unlock.sh 192.168.10.61
```

Or use plain SSH directly:

```shell
ssh -p 1024 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.10.61
```

If you manually run:

```shell
cryptsetup open /dev/nvme0n1p2 cryptroot
```

that opens the mapper device, but it does not necessarily resume boot if the
original initramfs `cryptroot` process is still blocked on `askpass`. Use the
`cryptroot-unlock` path above for the normal recovery flow.

If you are using a temporary recovery passphrase added from rescue, make sure it
was created without a trailing newline and tested with typed-passphrase
semantics before relying on it in initramfs.

Use the current `otaru_luks_password` value from `~/dotfiles/password/ansible_vault.yaml`, but
provide it explicitly yourself. Do not make repo helpers read the vault file directly.

If the unlock succeeds, the node should continue booting and eventually expose its normal SSH
service on port `22`.

This path is now proven on `raspberrypi-01` across a full reboot.

## Verify the handoff into normal boot

Wait for normal SSH:

```shell
ssh pi@192.168.10.61
```

Then confirm:

```shell
findmnt /
lsblk
systemctl is-system-running
```

Expected target shape:

- `/` mounted from `/dev/mapper/cryptroot`
- the underlying encrypted partition still visible, for example `/dev/nvme0n1p2`
- system reaches normal boot state

## Verify Kubernetes recovery

After the node returns:

```shell
kubectl get nodes -o wide
kubectl -n argocd get applications.argoproj.io
```

Check:

- the node returns `Ready`
- cordon it again immediately if you do not want regular workloads there
- Argo applications return healthy, allowing for any workload intentionally left pending by the cordon
- etcd quorum remains healthy
- Longhorn recovers replicas before moving on to the next node

## If unlock SSH does not come up

Check:

- the node really rebooted into initramfs and is waiting for unlock
- the configured IP, gateway, and interface in `/etc/initramfs-tools/initramfs.conf`
- switch/VLAN reachability to the node IP
- whether another service is already using the configured port

Useful validation on the node before reboot:

```shell
grep -E '^(DROPBEAR|IP)=' /etc/initramfs-tools/initramfs.conf
grep '^DROPBEAR_OPTIONS=' /etc/dropbear/initramfs/dropbear.conf
ls -l /etc/dropbear/initramfs/authorized_keys
```

## If the node still does not finish booting after unlock

Check:

- `/etc/crypttab`
- `/etc/fstab`
- whether the mapped device name matches the expected mapper name
- whether initramfs is still blocked on `/lib/cryptsetup/askpass`
- `journalctl -b` after recovery access is restored

Do not continue to another node until the current node is fully healthy again.
