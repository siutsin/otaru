# Create a bootable encrypted NVMe drive with Ubuntu on Raspberry Pi 5

This is the encrypted-root variant of [create_rpi5_nvme_image.md](create_rpi5_nvme_image.md).

Current rollout scope:

- `raspberrypi-01` only during development
- later `raspberrypi-02`
- later `raspberrypi-00`

Out of scope for now:

- `raspberrypi-03`
- `nuc-00`

## Preferred path

Use the one-pass rescue rebuild wrapper:

```shell
./hack/luks-node-init.sh
```

The wrapper:

- uses the rescue host at `192.168.10.40`
- wipes `/dev/nvme0n1`
- rebuilds the disk as `system-boot` plus LUKS `cryptroot`
- copies the Ubuntu image into the new layout
- upgrades the copied root to the current kernel line
- configures shell-mode initramfs `dropbear` on port `1024`
- rebuilds initramfs and syncs `/boot/firmware`

## Preconditions

Before running the wrapper:

1. `raspberrypi-01` is removed from the cluster or otherwise safe to rebuild.
2. The rescue SD is booted and reachable at `192.168.10.40`.
3. The local vault file contains `otaru_luks_password`.
4. Do not pass the LUKS password on the command line during rescue work.
5. Provide the passphrase to the wrapper explicitly:

```shell
umask 077
printf '%s' '...' > /tmp/otaru-luks-password
LUKS_PASSWORD_FILE=/tmp/otaru-luks-password \
./hack/luks-node-init.sh
rm -f /tmp/otaru-luks-password
```

If you must use an environment variable, use `OTARU_LUKS_PASSWORD` only for the current shell
session and clear it immediately afterward.

## Current status

On `raspberrypi-01`, the full flow is now proven live:

1. one-pass rescue rebuild
2. first encrypted NVMe boot
3. remote unlock through initramfs `dropbear`
4. clean `k3s` rejoin as a control-plane/etcd node

`raspberrypi-01` is intentionally left cordoned after rejoin so regular workloads do not schedule
there during the rollout.

## After the rebuild

1. Power off the rescue system.
2. Remove the rescue SD card.
3. Boot from NVMe.
4. Unlock the encrypted root through initramfs SSH.
5. Verify normal boot:

```shell
ssh pi@192.168.10.61
findmnt /
lsblk
```

Expected target shape:

- `/` mounted from `/dev/mapper/cryptroot`
- `/boot/firmware` mounted from `nvme0n1p1`

## Rejoin validation

After the encrypted node is back:

```shell
./hack/luks-postflight-check.sh raspberrypi-01
```

Keep the node cordoned until:

- it is `Ready`
- it is `SchedulingDisabled`
- etcd quorum is healthy
- Argo is healthy apart from any workload left pending by the cordon
- Longhorn recovers cleanly

## Related references

- [Create a bootable NVMe drive with Ubuntu on Raspberry Pi 5](create_rpi5_nvme_image.md)
- [LUKS remote unlock and recovery](luks_remote_unlock.md)
- [LUKS vault variables](luks_vault.md)
- [Gotchas and Workarounds](gotcha.md)
