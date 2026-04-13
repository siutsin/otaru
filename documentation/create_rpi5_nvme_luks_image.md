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
./hack/luks-rpi5-rescue-rebuild.sh
```

The wrapper:

- reads `ubuntu_luks_password` from `~/dotfiles/password/ansible_vault.yaml`
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
3. The local vault file contains `ubuntu_luks_password`.
4. Do not pass the LUKS password on the command line during rescue work.

If the passphrase was ever exposed in command text during debugging, rotate `ubuntu_luks_password`
before the next real rebuild or boot attempt.

## Current status

On `raspberrypi-01`, the one-pass rescue rebuild path has already been exercised live and now gets
through the rebuild itself.

The remaining validation is:

1. first encrypted NVMe boot
2. remote unlock
3. clean rejoin while keeping the node cordoned

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
- etcd quorum is healthy
- Argo returns `Synced/Healthy`
- Longhorn recovers cleanly

## Related references

- [Create a bootable NVMe drive with Ubuntu on Raspberry Pi 5](create_rpi5_nvme_image.md)
- [LUKS remote unlock and recovery](luks_remote_unlock.md)
- [LUKS vault variables](luks_vault.md)
- [Gotchas and Workarounds](gotcha.md)
