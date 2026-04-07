# Create a bootable NVMe drive with Ubuntu on Raspberry Pi 5

## Prerequisites

- Raspberry Pi 5 with NVMe drive attached
- Raspberry Pi OS Lite (64-bit) flashed to an SD card — follow [create_rpi4_image.md](create_rpi4_image.md),
  use `Raspberry Pi 5` as the device, and set the hostname, username (`pi`), SSH public key, and
  Wi-Fi credentials during imaging
- Pi booted from the SD card with SSH access confirmed

## Step 1: Update EEPROM and enable NVMe boot

Run on the **Pi** (via SSH, booted from SD card):

```shell
sudo apt update
sudo apt full-upgrade -y
sudo rpi-eeprom-update -a
```

Reboot to apply the EEPROM update, then reconnect via SSH:

```shell
sudo reboot
```

After reconnecting, set the boot order to prioritise NVMe:

```shell
sudo rpi-eeprom-config --edit
```

Set the following values:

```text
BOOT_ORDER=0xf416
PCIE_PROBE=1
```

`BOOT_ORDER=0xf416` means NVMe (6) → SD (1) → USB (4) → restart.

## Step 2: Find the correct Ubuntu image filename

Run on the **Pi**:

```shell
curl -s "https://cdimage.ubuntu.com/releases/24.04/release/" | grep -o 'ubuntu-24\.04[^"]*raspi\.img\.xz' | sort -u
```

## Step 3: Flash Ubuntu to NVMe

Run on the **Pi**. Replace the filename with the latest version from Step 2. Downloading first caches
the image locally in case the flash fails:

```shell
curl -LO https://cdimage.ubuntu.com/releases/24.04/release/<REPLACE: ubuntu-24.04.X-preinstalled-server-arm64+raspi.img.xz>
xz -d <REPLACE: ubuntu-24.04.X-preinstalled-server-arm64+raspi.img.xz>
sudo dd if=<REPLACE: ubuntu-24.04.X-preinstalled-server-arm64+raspi.img> of=/dev/nvme0n1 bs=4M status=progress conv=fsync
```

## Step 4: Configure cloud-init before first boot

Run on the **Pi**. Mount the boot partition:

```shell
sudo mkdir -p /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot
```

Write `user-data` with hostname, user, and SSH public key:

```shell
sudo tee /mnt/boot/user-data << 'EOF'
#cloud-config
hostname: <REPLACE: raspberrypi-XX>
manage_etc_hosts: true

users:
  - name: pi
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-ed25519 AAAA... <REPLACE: your SSH public key, see ~/.ssh/id_ed25519.pub>
EOF
```

Write `network-config` with static IPs. Replace SSID and password with your values:

```shell
sudo tee /mnt/boot/network-config << 'EOF'
version: 2
ethernets:
  eth0:
    dhcp4: false
    addresses:
      - <REPLACE: 192.168.1.XX>/24
    routes:
      - to: default
        via: 192.168.1.1
    nameservers:
      addresses:
        - 192.168.1.1
wifis:
  wlan0:
    dhcp4: false
    addresses:
      - <REPLACE: 192.168.1.XX>/24
    routes:
      - to: default
        via: 192.168.1.1
    nameservers:
      addresses:
        - 192.168.1.1
    access-points:
      "<REPLACE: YourSSID>":
        password: "<REPLACE: your-wifi-password>"
EOF
```

Unmount the partition:

```shell
sudo umount /mnt/boot
```

## Step 5: Convert partition table to GUID Partition Table (GPT)

Run on the **Pi**. The Ubuntu preinstalled image uses MBR, which has a 2 TB limit. NVMe drives larger
than 2 TB require GPT (GUID Partition Table). The conversion takes effect on next boot.

```shell
sudo gdisk /dev/nvme0n1
```

In gdisk, type `w` then `y` to convert MBR to GPT without touching data.

## Step 6: Boot from NVMe

Power off the Pi, then power on. The SD card can remain inserted — the EEPROM boot order set in
Step 1 ensures the NVMe is tried first.

Run on the **Pi** (now booted into Ubuntu from NVMe). Verify the root device is the NVMe:

```shell
findmnt /
```

The root mount should show `/dev/nvme0n1p2`, not an SD card partition (`mmcblk`).

## Step 7: Expand root partition

Run on the **Pi**. Reboot to trigger cloud-init partition expansion after the GPT conversion:

```shell
sudo reboot
```

After reconnecting, verify the full disk is available:

```shell
df -h /
```

If the partition was not expanded, run manually:

```shell
sudo growpart /dev/nvme0n1 2
sudo resize2fs /dev/nvme0n1p2
```

## Step 8: Join the cluster

Run on the **host** (Mac). Add the new node to `ansible/inventory.yaml`, then run:

```shell
make build-cluster
```
