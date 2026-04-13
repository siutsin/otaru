#!/usr/bin/env bash

set -euo pipefail

if [[ $# -gt 0 ]]; then
  echo "Usage: $0" >&2
  exit 1
fi

rescue_host="${RESCUE_HOST:-pi@192.168.10.40}"
remote_image_path="${REMOTE_IMAGE_PATH:-/home/pi/ubuntu-24.04.4-preinstalled-server-arm64+raspi.img}"
target_disk="${TARGET_DISK:-/dev/nvme0n1}"
target_hostname="${TARGET_HOSTNAME:-raspberrypi-01}"
target_ip="${TARGET_IP:-192.168.10.61}"
target_gateway="${TARGET_GATEWAY:-192.168.10.1}"
target_netmask="${TARGET_NETMASK:-255.255.255.0}"
target_dns="${TARGET_DNS:-192.168.10.1}"
dropbear_port="${DROPBEAR_PORT:-1024}"
expected_disk_model_substring="${EXPECTED_DISK_MODEL_SUBSTRING:-}"
minimum_disk_size_bytes="${MINIMUM_DISK_SIZE_BYTES:-100000000000}"
local_pass_file=""
remote_pass_file="/root/luks-pass"

if [[ "${LUKS_NODE_INIT_CONFIRM:-}" != "yes" ]]; then
  cat >&2 <<EOF
Refusing to wipe ${target_disk} without explicit confirmation.
Set LUKS_NODE_INIT_CONFIRM=yes to continue.
EOF
  exit 1
fi

if [[ -z "${expected_disk_model_substring}" ]]; then
  cat >&2 <<EOF
Refusing to wipe ${target_disk} without an expected disk model guard.
Set EXPECTED_DISK_MODEL_SUBSTRING to a stable model substring for the target NVMe first.
EOF
  exit 1
fi

cleanup() {
  set +e
  if [[ -n "${local_pass_file}" && -f "${local_pass_file}" ]]; then
    rm -f "${local_pass_file}"
  fi
}
trap cleanup EXIT

local_pass_file="$(mktemp)"
chmod 600 "${local_pass_file}"
if [[ -n "${LUKS_PASSWORD_FILE:-}" ]]; then
  cp "${LUKS_PASSWORD_FILE}" "${local_pass_file}"
elif [[ -n "${OTARU_LUKS_PASSWORD:-}" ]]; then
  printf '%s' "${OTARU_LUKS_PASSWORD}" > "${local_pass_file}"
else
  echo "Set LUKS_PASSWORD_FILE or OTARU_LUKS_PASSWORD before running this script" >&2
  exit 1
fi
chmod 600 "${local_pass_file}"

# Capture the operator SSH keys before touching the target disk so the rebuilt node can preserve
# both normal SSH access and initramfs recovery access without depending on the target root state.
authorized_keys_b64="$(
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$rescue_host" \
    "base64 -w0 /home/pi/.ssh/authorized_keys 2>/dev/null || base64 /home/pi/.ssh/authorized_keys | tr -d '\n'"
)"
if [[ -z "${authorized_keys_b64}" ]]; then
  echo "Failed to read /home/pi/.ssh/authorized_keys from $rescue_host" >&2
  exit 1
fi

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$rescue_host" \
  "sudo install -m 600 /dev/null ${remote_pass_file}"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$rescue_host" \
  "sudo tee ${remote_pass_file} >/dev/null" < "${local_pass_file}"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$rescue_host" \
  "sudo env \
    REMOTE_IMAGE_PATH=$(printf '%q' "$remote_image_path") \
    TARGET_DISK=$(printf '%q' "$target_disk") \
    TARGET_HOSTNAME=$(printf '%q' "$target_hostname") \
    TARGET_IP=$(printf '%q' "$target_ip") \
    TARGET_GATEWAY=$(printf '%q' "$target_gateway") \
    TARGET_NETMASK=$(printf '%q' "$target_netmask") \
    TARGET_DNS=$(printf '%q' "$target_dns") \
    DROPBEAR_PORT=$(printf '%q' "$dropbear_port") \
    EXPECTED_DISK_MODEL_SUBSTRING=$(printf '%q' "$expected_disk_model_substring") \
    MINIMUM_DISK_SIZE_BYTES=$(printf '%q' "$minimum_disk_size_bytes") \
    REMOTE_PASS_FILE=$(printf '%q' "$remote_pass_file") \
    AUTHORIZED_KEYS_B64=$(printf '%q' "$authorized_keys_b64") \
    bash -s" <<'EOF'
set -euo pipefail

img="${REMOTE_IMAGE_PATH}"
disk="${TARGET_DISK}"
boot="${disk}p1"
root="${disk}p2"
mapper="cryptroot"
work_dir="$(mktemp -d /tmp/luks-node-init.XXXXXX)"
src_boot="$work_dir/src-boot"
src_root="$work_dir/src-root"
dst_root="$work_dir/dst-root"
loop_dev=""
pass_file="${REMOTE_PASS_FILE}"

cleanup() {
  set +e
  umount "$dst_root/boot/firmware" 2>/dev/null || true
  umount "$dst_root/dev" 2>/dev/null || true
  umount "$dst_root/proc" 2>/dev/null || true
  umount "$dst_root/sys" 2>/dev/null || true
  umount "$dst_root/run" 2>/dev/null || true
  umount "$src_boot" 2>/dev/null || true
  umount "$src_root" 2>/dev/null || true
  umount "$dst_root" 2>/dev/null || true
  cryptsetup close "$mapper" 2>/dev/null || true
  if [[ -n "$loop_dev" ]]; then
    losetup -d "$loop_dev"
  fi
  rm -f "$pass_file"
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$src_boot" "$src_root" "$dst_root"

# Older rescue runs used fixed mount paths under /mnt. Clean those first so repeated test runs
# start from a known state instead of inheriting stale mounts from a previous interrupted run.
umount -R /mnt/dst-root/boot/firmware 2>/dev/null || true
umount -R /mnt/dst-root 2>/dev/null || true
cryptsetup close "$mapper" 2>/dev/null || true

# Also unmount any active mounts for the current target devices. This makes the wrapper safe to rerun
# during development without needing a rescue reboot between attempts.
for mounted_target in $(findmnt -rn -S "$boot" -o TARGET 2>/dev/null); do
  umount -R "$mounted_target" 2>/dev/null || true
done
for mounted_target in $(findmnt -rn -S "/dev/mapper/$mapper" -o TARGET 2>/dev/null); do
  umount -R "$mounted_target" 2>/dev/null || true
done
cryptsetup close "$mapper" 2>/dev/null || true

if [[ ! -b "$disk" ]]; then
  echo "Refusing to wipe $disk because it is not a block device." >&2
  exit 1
fi

disk_type="$(lsblk -dn -o TYPE "$disk" 2>/dev/null || true)"
if [[ "$disk_type" != "disk" ]]; then
  echo "Refusing to wipe $disk because its device type is '$disk_type', not 'disk'." >&2
  exit 1
fi

disk_removable="$(lsblk -dn -o RM "$disk" 2>/dev/null || true)"
if [[ "$disk_removable" == "1" ]]; then
  echo "Refusing to wipe $disk because it is marked removable on the rescue host." >&2
  exit 1
fi

disk_model="$(lsblk -dn -o MODEL "$disk" 2>/dev/null || true)"
if [[ -n "$expected_disk_model_substring" && "$disk_model" != *"$expected_disk_model_substring"* ]]; then
  echo "Refusing to wipe $disk because model '$disk_model' does not contain '$expected_disk_model_substring'." >&2
  exit 1
fi

disk_size_bytes="$(blockdev --getsize64 "$disk" 2>/dev/null || true)"
if [[ -z "$disk_size_bytes" || "$disk_size_bytes" -lt "$minimum_disk_size_bytes" ]]; then
  echo "Refusing to wipe $disk because size '$disk_size_bytes' is below minimum '$minimum_disk_size_bytes' bytes." >&2
  exit 1
fi

if findmnt -rn -S "$disk" >/dev/null 2>&1; then
  echo "Refusing to wipe $disk because it is mounted on the rescue host." >&2
  exit 1
fi

root_source="$(findmnt -rn -o SOURCE / || true)"
if [[ "$root_source" == "$disk" || "$root_source" == "$boot" || "$root_source" == "$root" ]]; then
  echo "Refusing to wipe $disk because it backs the rescue host root filesystem." >&2
  exit 1
fi

lsblk -o NAME,TYPE,RM,SIZE,MODEL,FSTYPE,MOUNTPOINTS "$disk"
echo "About to wipe $disk on $HOSTNAME" >&2

blkdiscard -f "$disk"
sgdisk -og \
  -n 1:2048:+512M -t 1:0700 -c 1:system-boot \
  -n 2:0:0 -t 2:8300 -c 2:writable \
  "$disk"
partprobe "$disk"
udevadm settle

mkfs.vfat -F 32 -n system-boot "$boot"
cryptsetup luksFormat --batch-mode --type luks2 --pbkdf argon2id --key-file "$pass_file" "$root"
cryptsetup open --key-file "$pass_file" "$root" "$mapper"
mkfs.ext4 -F -L writable "/dev/mapper/$mapper"

loop_dev="$(losetup --show -Pf "$img")"
mount -o ro "${loop_dev}p1" "$src_boot"
mount -o ro "${loop_dev}p2" "$src_root"
mount "/dev/mapper/$mapper" "$dst_root"
mkdir -p "$dst_root/boot/firmware"
mount "$boot" "$dst_root/boot/firmware"

rsync -aHAX --delete --exclude=/boot/firmware "$src_root/" "$dst_root/"
rsync -aHAX --delete "$src_boot/" "$dst_root/boot/firmware/"

# Write cloud-init directly onto the rebuilt boot partition so the first encrypted NVMe boot comes
# up with the intended hostname, network, and SSH access without any manual first-boot repair.
cat > "$dst_root/boot/firmware/user-data" <<USERDATA
#cloud-config
hostname: ${TARGET_HOSTNAME}
manage_etc_hosts: true

users:
  - name: pi
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
$(printf '%s' "$AUTHORIZED_KEYS_B64" | base64 -d | sed '/^$/d; s/^/      - /')
USERDATA

cat > "$dst_root/boot/firmware/network-config" <<NETCFG
version: 2
ethernets:
  eth0:
    dhcp4: false
    addresses:
      - ${TARGET_IP}/24
    routes:
      - to: default
        via: ${TARGET_GATEWAY}
    nameservers:
      addresses:
        - ${TARGET_DNS}
NETCFG

if ! grep -q '^dtparam=pciex1$' "$dst_root/boot/firmware/config.txt"; then
  printf '\n[all]\ndtparam=pciex1\ndtparam=pciex1_gen=3\n' >> "$dst_root/boot/firmware/config.txt"
fi

sed -i 's#root=LABEL=writable#root=/dev/mapper/cryptroot#' "$dst_root/boot/firmware/cmdline.txt"
if ! grep -q 'rootdelay=10' "$dst_root/boot/firmware/cmdline.txt"; then
  sed -i 's# rootwait# rootwait rootdelay=10#' "$dst_root/boot/firmware/cmdline.txt"
fi

root_uuid="$(blkid -s UUID -o value "$root")"
boot_uuid="$(blkid -s UUID -o value "$boot")"

cat > "$dst_root/etc/crypttab" <<CRYPTTAB
cryptroot UUID=${root_uuid} none luks,discard
CRYPTTAB

cat > "$dst_root/etc/fstab" <<FSTAB
/dev/mapper/cryptroot / ext4 defaults 0 1
UUID=${boot_uuid} /boot/firmware vfat defaults 0 1
FSTAB

rm -f "$dst_root/etc/resolv.conf"
cp /etc/resolv.conf "$dst_root/etc/resolv.conf"

# Package triggers may run update-initramfs before the script reaches its final explicit rebuild.
# Seed authorized_keys early so those trigger-driven initramfs builds already contain a valid
# recovery key and do not emit a broken-authorized_keys warning.
mkdir -p "$dst_root/etc/dropbear/initramfs"
printf '%s' "$AUTHORIZED_KEYS_B64" | base64 -d | sed '/^$/d' > "$dst_root/etc/dropbear/initramfs/authorized_keys"
printf '\n' >> "$dst_root/etc/dropbear/initramfs/authorized_keys"
chmod 600 "$dst_root/etc/dropbear/initramfs/authorized_keys"

mount --bind /dev "$dst_root/dev"
mount --bind /proc "$dst_root/proc"
mount --bind /sys "$dst_root/sys"
mount --bind /run "$dst_root/run"

chroot "$dst_root" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get update
chroot "$dst_root" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade
chroot "$dst_root" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get \
  -o Dpkg::Options::=--force-confdef \
  -o Dpkg::Options::=--force-confold \
  install -y cryptsetup-initramfs dropbear-initramfs

# Write the final dropbear config after package installation so dpkg cannot prompt about replacing
# our custom config, while still keeping the final initramfs SSH behavior deterministic.
cat > "$dst_root/etc/dropbear/initramfs/dropbear.conf" <<DROPBEARCONF
DROPBEAR_OPTIONS="-I 180 -p ${DROPBEAR_PORT} -j -k -s"
DROPBEARCONF

if grep -q '^DROPBEAR=' "$dst_root/etc/initramfs-tools/initramfs.conf"; then
  sed -i 's/^DROPBEAR=.*/DROPBEAR=y/' "$dst_root/etc/initramfs-tools/initramfs.conf"
else
  echo 'DROPBEAR=y' >> "$dst_root/etc/initramfs-tools/initramfs.conf"
fi

if grep -q '^IP=' "$dst_root/etc/initramfs-tools/initramfs.conf"; then
  sed -i "s#^IP=.*#IP=${TARGET_IP}::${TARGET_GATEWAY}:${TARGET_NETMASK}:${TARGET_HOSTNAME}:eth0:off:${TARGET_DNS}#" "$dst_root/etc/initramfs-tools/initramfs.conf"
else
  echo "IP=${TARGET_IP}::${TARGET_GATEWAY}:${TARGET_NETMASK}:${TARGET_HOSTNAME}:eth0:off:${TARGET_DNS}" >> "$dst_root/etc/initramfs-tools/initramfs.conf"
fi

cat > "$dst_root/etc/initramfs-tools/modules" <<MODULES
nvme
nvme-core
dm_mod
dm_crypt
MODULES

chroot "$dst_root" update-initramfs -u -k all

# Reassert the target mounts before syncing the final kernel artifacts. Package triggers and cleanup
# around update-initramfs can leave the target root no longer mounted, and the boot partition must
# end up with the exact kernel/initrd/DTB set that matches the rebuilt root.
mkdir -p "$dst_root/boot/firmware"
mountpoint -q "$dst_root" || mount "/dev/mapper/$mapper" "$dst_root"
mountpoint -q "$dst_root/boot/firmware" || mount "$boot" "$dst_root/boot/firmware"

kver="$(chroot "$dst_root" /bin/sh -c 'ls -1 /lib/modules | sort -V | tail -n 1')"
dtb_dir="$dst_root/usr/lib/firmware/$kver/device-tree/broadcom"

if [[ ! -d "$dtb_dir" ]]; then
  echo "Expected DTB directory not found: $dtb_dir" >&2
  exit 1
fi

cp "$dst_root/boot/vmlinuz-$kver" "$dst_root/boot/firmware/vmlinuz"
cp "$dst_root/boot/initrd.img-$kver" "$dst_root/boot/firmware/initrd.img"
shopt -s nullglob
dtb_files=("$dtb_dir"/*.dtb)
shopt -u nullglob
if [[ ${#dtb_files[@]} -eq 0 ]]; then
  echo "Expected at least one DTB under $dtb_dir" >&2
  exit 1
fi
cp "${dtb_files[@]}" "$dst_root/boot/firmware/"
rsync -a "$dst_root/usr/lib/firmware/$kver/device-tree/overlays/" "$dst_root/boot/firmware/overlays/"

lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS "$disk"
blkid "$boot" "$root" "/dev/mapper/$mapper"
sed -n '1,20p' "$dst_root/etc/crypttab"
sed -n '1,20p' "$dst_root/etc/fstab"
grep -E '^(DROPBEAR|IP)=' "$dst_root/etc/initramfs-tools/initramfs.conf"
grep '^DROPBEAR_OPTIONS=' "$dst_root/etc/dropbear/initramfs/dropbear.conf"
cat "$dst_root/boot/firmware/cmdline.txt"
EOF
