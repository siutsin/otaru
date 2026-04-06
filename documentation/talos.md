# Talos on Raspberry Pi 5 with NVMe

## Goal

Run Talos on a Raspberry Pi 5 booting from NVMe, without an SD card.

## Problem

The `sbc-raspberrypi` overlay bundles a U-Boot build that hangs on the U-Boot logo screen
when booting from NVMe or USB on RPi5.

Reference: [siderolabs/sbc-raspberrypi#81](https://github.com/siderolabs/sbc-raspberrypi/issues/81)

## Current Hardware Config

`/boot/firmware/config.txt`:

```ini
[all]
dtparam=nvme
dtparam=pciex1
dtparam=pciex1_gen=2
enable_uart=1
disable_splash=1
BOOT_UART=1
BOOT_DELAY=3
```

EEPROM:

```ini
[all]
BOOT_ORDER=0xf461
PCIE_PROBE=1
```

## What We Have Tried

### Attempt 1: Plain `metal arm64` (no overlay) + tinkerbell SD card

- SD card: tinkerbell U-Boot image (`v2026.04-rc4.1`)
- NVMe: plain `metal arm64` Talos image (no overlay)

Result: U-Boot logo passed, but Talos never came up on the network. The plain `metal arm64`
image does not initialise RPi5 hardware correctly - it lacks RPi5 firmware and uses the wrong
console (`ttyAMA0` instead of `ttyAMA10`).

### Attempt 2: `rpi_5` overlay + tinkerbell SD card (in progress)

- SD card: tinkerbell U-Boot image (`v2026.04-rc4.1`)
- NVMe: `rpi_5` Talos image with `sbc-raspberrypi:v0.2.0` overlay

The `rpi_5` overlay provides correct RPi5 firmware and kernel command line. The broken U-Boot
embedded in the overlay image is irrelevant - it is never executed because the SD card's
U-Boot takes over first.

Status: testing.

## Notes

- HDMI output does not work with the tinkerbell U-Boot build - expected
- The tinkerbell OCI image is not a Talos overlay; `--overlay-image` requires an OCI container
  image with install scripts, not a raw disk image artifact
- The `rpi_5` overlay image must be built with `--privileged` and `-v /dev:/dev` due to
  loopback device requirements in the imager

## Resources

| Resource                                                   | Description                                   |
|------------------------------------------------------------|-----------------------------------------------|
| [OneUptime: Talos on RPi5][oneuptime]                      | Setup guide for Talos Linux on Raspberry Pi 5 |
| [talos-rpi5/talos-builder][talos-builder]                  | Community builder for Talos RPi5 images       |
| [Talos Image Factory (RPi5)][image-factory]                | Official image factory for RPi5 SBC target    |
| [siderolabs/sbc-raspberrypi][sbc-rpi]                      | Official Talos SBC overlay for Raspberry Pi   |
| [sbc-raspberrypi#81][issue-81]                             | U-Boot bug tracking RPi5 NVMe boot issue      |
| [tinkerbell-community/uboot-raspberrypi][tinkerbell-uboot] | Patched U-Boot OCI image used as workaround   |

[oneuptime]: https://oneuptime.com/blog/post/2026-03-03-set-up-talos-linux-on-raspberry-pi-5/view
[talos-builder]: https://github.com/talos-rpi5/talos-builder
[image-factory]: https://factory.talos.dev/?arch=arm64&board=rpi_5&bootloader=auto&cmdline-set=true&extensions=-&platform=metal&target=sbc&version=1.12.6
[sbc-rpi]: https://github.com/siderolabs/sbc-raspberrypi
[issue-81]: https://github.com/siderolabs/sbc-raspberrypi/issues/81
[tinkerbell-uboot]: https://github.com/tinkerbell-community/uboot-raspberrypi/pkgs/container/uboot-raspberrypi
