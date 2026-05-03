# Create a Raspberry Pi Image

This is the standard Raspberry Pi 5 encrypted NVMe path for this repo.

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

1. The target node is removed from the cluster or otherwise safe to rebuild.
2. The rescue SD is booted and reachable at `192.168.10.40`.
3. The local vault file contains `otaru_luks_password`.
4. Do not pass the LUKS password on the command line during rescue work.
5. Set `EXPECTED_DISK_MODEL_SUBSTRING` to a stable substring for the target NVMe model.
6. Provide the passphrase to the wrapper explicitly:

```shell
umask 077
printf '%s' '...' > /tmp/otaru-luks-password
export EXPECTED_DISK_MODEL_SUBSTRING='<disk-model-substring>'
LUKS_NODE_INIT_CONFIRM=yes \
LUKS_PASSWORD_FILE=/tmp/otaru-luks-password \
./hack/luks-node-init.sh
rm -f /tmp/otaru-luks-password
```

If you must use an environment variable, use `OTARU_LUKS_PASSWORD` only for the current shell
session and clear it immediately afterward.

## After the rebuild

1. Power off the rescue system.
2. Remove the rescue SD card.
3. Boot from NVMe.
4. Unlock the encrypted root through initramfs SSH.
5. Verify normal boot:

```shell
make unlock <node-name>
ssh pi@<node-ip>
findmnt /
lsblk
```

Expected target shape:

- `/` mounted from `/dev/mapper/cryptroot`
- `/boot/firmware` mounted from `nvme0n1p1`

## Rejoin validation

After the encrypted node is back:

```shell
./hack/luks-postflight-check.sh <node-name>
```

Keep the node cordoned until:

- it is `Ready`
- it is `SchedulingDisabled`
- etcd quorum is healthy
- Argo is healthy apart from any workload left pending by the cordon
- Longhorn recovers cleanly

## Related references

- [LUKS remote unlock and recovery](luks_remote_unlock.md)
- [LUKS passphrase handling](luks_passphrase.md)
- [Gotchas and Workarounds](gotcha.md)
