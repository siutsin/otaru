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
vault_file="${VAULT_FILE:-$HOME/dotfiles/password/ansible_vault.yaml}"
local_pass_file=""
remote_pass_file="/root/luks-pass"

cleanup() {
  set +e
  if [[ -n "${local_pass_file}" && -f "${local_pass_file}" ]]; then
    rm -f "${local_pass_file}"
  fi
}
trap cleanup EXIT

if ! command -v yq >/dev/null 2>&1; then
  echo "Missing required command: yq" >&2
  exit 1
fi

luks_password="$(yq '.ubuntu_luks_password' "$vault_file")"
if [[ -z "${luks_password}" || "${luks_password}" == "null" ]]; then
  echo "Failed to read ubuntu_luks_password from $vault_file" >&2
  exit 1
fi

local_pass_file="$(mktemp)"
chmod 600 "${local_pass_file}"
printf '%s' "${luks_password}" > "${local_pass_file}"

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
    REMOTE_PASS_FILE=$(printf '%q' "$remote_pass_file") \
    AUTHORIZED_KEYS_B64=$(printf '%q' "$authorized_keys_b64") \
    bash -s" <<'EOF'
set -euo pipefail

img="${REMOTE_IMAGE_PATH}"
disk="${TARGET_DISK}"
boot="${disk}p1"
root="${disk}p2"
mapper="cryptroot"
src_boot="/mnt/src-boot"
src_root="/mnt/src-root"
dst_root="/mnt/dst-root"
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
  [[ -n "$loop_dev" ]] && losetup -d "$loop_dev" 2>/dev/null || true
  rm -f "$pass_file"
}
trap cleanup EXIT

mkdir -p "$src_boot" "$src_root" "$dst_root"

blkdiscard -f "$disk"
sgdisk -og \
  -n 1:2048:+512M -t 1:0700 -c 1:system-boot \
  -n 2:0:0 -t 2:8300 -c 2:writable \
  "$disk"
partprobe "$disk"
udevadm settle

mkfs.vfat -F 32 -n system-boot "$boot"
cryptsetup luksFormat --batch-mode --key-file "$pass_file" "$root"
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
$(printf '%s' "$AUTHORIZED_KEYS_B64" | base64 -d | sed 's/^/      - /')
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

mkdir -p "$dst_root/etc/dropbear/initramfs"
cat > "$dst_root/etc/dropbear/initramfs/dropbear.conf" <<DROPBEARCONF
DROPBEAR_OPTIONS="-I 180 -p ${DROPBEAR_PORT} -j -k -s"
DROPBEARCONF
printf '%s' "$AUTHORIZED_KEYS_B64" | base64 -d > "$dst_root/etc/dropbear/initramfs/authorized_keys"
printf '\n' >> "$dst_root/etc/dropbear/initramfs/authorized_keys"
chmod 600 "$dst_root/etc/dropbear/initramfs/authorized_keys"

mount --bind /dev "$dst_root/dev"
mount --bind /proc "$dst_root/proc"
mount --bind /sys "$dst_root/sys"
mount --bind /run "$dst_root/run"

chroot "$dst_root" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get update
chroot "$dst_root" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade
chroot "$dst_root" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get install -y cryptsetup-initramfs dropbear-initramfs

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

chroot "$dst_root" update-initramfs -u

kver="$(basename "$(find "$dst_root/lib/modules" -mindepth 1 -maxdepth 1 | sort | tail -n 1)")"
cp "$dst_root/boot/vmlinuz-$kver" "$dst_root/boot/firmware/vmlinuz"
cp "$dst_root/boot/initrd.img-$kver" "$dst_root/boot/firmware/initrd.img"
cp "$dst_root/usr/lib/firmware/$kver/device-tree/broadcom/"*.dtb "$dst_root/boot/firmware/"
rsync -a "$dst_root/usr/lib/firmware/$kver/device-tree/overlays/" "$dst_root/boot/firmware/overlays/"

lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS "$disk"
blkid "$boot" "$root" "/dev/mapper/$mapper"
sed -n '1,20p' "$dst_root/etc/crypttab"
sed -n '1,20p' "$dst_root/etc/fstab"
grep -E '^(DROPBEAR|IP)=' "$dst_root/etc/initramfs-tools/initramfs.conf"
grep '^DROPBEAR_OPTIONS=' "$dst_root/etc/dropbear/initramfs/dropbear.conf"
cat "$dst_root/boot/firmware/cmdline.txt"
EOF
