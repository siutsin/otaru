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
sudo apt update -y && sudo apt full-upgrade -y && sudo apt install vim -y && sudo rpi-eeprom-update -a
```

Reboot to apply the EEPROM update, then reconnect via SSH:

```shell
sudo reboot
```

After reconnecting, set the boot order to prioritise NVMe:

```shell
sudo EDITOR=vim rpi-eeprom-config --edit
```

Set the following values:

```text
BOOT_ORDER=0xf461
PCIE_PROBE=1
```

`BOOT_ORDER=0xf461` means SD (1) → NVMe (6) → USB (4) → restart (f).

Edit the boot firmware:

```shell
sudo vim /boot/firmware/config.txt
```

Add the NVMe configuration to the `all` block:

```vim
[all]
dtparam=pciex1
dtparam=pciex1_gen=3
```

Reboot to apply the configuration, then reconnect via SSH:

```shell
sudo reboot
```

Verify NVMe is available:

```shell
lsblk
```

Example output:

```shell
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0         7:0    0     2G  0 loop
mmcblk0     179:0    0  29.7G  0 disk
├─mmcblk0p1 179:1    0   512M  0 part /boot/firmware
└─mmcblk0p2 179:2    0  29.2G  0 part /
zram0       254:0    0     2G  0 disk [SWAP]
nvme0n1     259:0    0 238.5G  0 disk
├─nvme0n1p1 259:1    0   200M  0 part
└─nvme0n1p2 259:2    0 238.3G  0 part
```

## Step 2: Find the correct Ubuntu image filename

Run on the **Pi**:

```shell
curl -s "https://cdimage.ubuntu.com/releases/24.04/release/" | grep -o 'ubuntu-24\.04[^"]*raspi\.img\.xz' | sort -u
```

## Step 3: Flash Ubuntu to NVMe

Run on the **Pi**. Replace the filename with the latest version from Step 2. Downloading first caches
the image locally in case the flash fails:

```shell
curl -LO https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.4-preinstalled-server-arm64+raspi.img.xz
xz -d ubuntu-24.04.4-preinstalled-server-arm64+raspi.img.xz
sudo dd if=ubuntu-24.04.4-preinstalled-server-arm64+raspi.img of=/dev/nvme0n1 bs=4M status=progress conv=fsync
```

## Step 4: Convert or fix partition table (GPT)

Run this **immediately after flashing**. The Ubuntu image uses MBR, which must be converted to GPT
before cloud-init configuration or booting. The conversion must happen after `dd` because `dd`
overwrites the entire disk, including any existing partition table.

Run on the **Pi**:

```bash
sudo gdisk /dev/nvme0n1
```

---

In gdisk, convert MBR to GPT:

```shell
w
y
```

---

If the conversion fails with GPT errors (CRC / invalid header), re-flash with `dd` (Step 3) and
try again. If errors persist, repair in gdisk:

```shell
r
b
c
v
w
y
```

---

Verify:

```shell
lsblk
```

Volume `nvme0n1` is detected and no corruption:

```shell
nvme0n1     259:0    0 238.5G  0 disk
├─nvme0n1p1 259:3    0   200M  0 part
└─nvme0n1p2 259:4    0 238.3G  0 part
```

## Step 5: Configure cloud-init before first boot

Run on the **Pi**. Mount the boot partition:

```shell
sudo mkdir -p /mnt/boot && sudo mount /dev/nvme0n1p1 /mnt/boot
```

**REPLACE PLACEHOLDER VALUE**. Write `user-data` with hostname, user, and SSH public key:

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

**REPLACE PLACEHOLDER VALUE**. Write `network-config` with static IPs:

```shell
sudo tee /mnt/boot/network-config << 'EOF'
version: 2
ethernets:
  eth0:
    dhcp4: false
    addresses:
      - <REPLACE: 192.168.10.XX>/24
    routes:
      - to: default
        via: 192.168.10.1
    nameservers:
      addresses:
        - 192.168.10.1
EOF
```

Unmount the partition:

```shell
sudo umount /mnt/boot
```

## Step 6: Boot from NVMe

Power off the Pi, remove the SD card, then power it on. The EEPROM boot order set in
Step 1 prioritises the SD card if it is inserted.

```shell
sudo poweroff
```

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
make setup
```
