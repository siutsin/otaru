# How to Set Up RPI with Waveshare PoE HAT (B) and Install K3s from scratch

## Update and Install Packages

```
sudo apt update && sudo apt upgrade -y && sudo apt install open-iscsi cryptsetup -y && sudo apt autoremove -y
```

## Install Python Library

```
sudo apt update && sudo apt install python3-pip -y && sudo pip install RPi.GPIO && sudo apt install python3-smbus -y && sudo apt autoremove -y
```

## Load dm_crypt Kernel Module

```
sudo modprobe dm_crypt && lsmod | grep dm_crypt
```

## Enable I2C Interface

Follow the official [guide](https://www.waveshare.com/wiki/PoE_HAT_(B)) to enable the I2C Interface. Or

```shell
sudo sed -i 's/#dtparam=i2c_arm=on/dtparam=i2c_arm=on/' /boot/config.txt

sudo reboot
```

## Install WiringPi

Check for the latest version
at [https://github.com/WiringPi/WiringPi/releases](https://github.com/WiringPi/WiringPi/releases).

```
cd /tmp
wget https://github.com/WiringPi/WiringPi/releases/download/2.61-1/wiringpi-2.61-1-arm64.deb && sudo dpkg -i wiringpi-2.61-1-arm64.deb && gpio -v
```

## Install bcm2835

```
cd /tmp
wget -qO- https://www.airspayce.com/mikem/bcm2835/bcm2835-1.73.tar.gz | tar xvz
cd bcm2835-1.73 && sudo ./configure && sudo make && sudo make check && sudo make install && cd /tmp
```

## Display Info on OLED Display

```
cd /tmp
git clone https://github.com/siutsin/Waveshare_PoE_HAT-B.git && bash Waveshare_PoE_HAT-B/setup.sh
```

## Set static IP for the wireless interface

Obtain the router's IP address. Take the address after "default via".

```
ip r
```

Add the following lines to `/etc/dhcpcd.conf`.

```
interface wlan0
static ip_address=192.168.1.150/24
static routers=192.168.1.254
static domain_name_servers=192.168.1.254
```

## Master Node

> Note: This is not a High Availability (HA) setup; it consists of 1 master and 2 worker nodes.

Install master node

* Bind master node IP Address
* Disable Traefik - use Istio Ingress Gateway instead
* Disable ServiceLB - use MetalLB instead
* Enable secrets encryption
* chmod for the kubeconfig

```
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--bind-address 192.168.1.150" sh -s - --disable traefik --disable=servicelb --secrets-encryption --write-kubeconfig-mode=644
```

## Worker Node

Retrieve the `node-token`.

```
sudo cat /var/lib/rancher/k3s/server/node-token
```

Install `k3s-agent`.

```
curl -sfL https://get.k3s.io | K3S_TOKEN=<node-token> K3S_URL="https://192.168.1.150:6443" sh -
```

## Accessing the Cluster from Outside with kubectl

Copy `/etc/rancher/k3s/k3s.yaml` on your machine located outside the cluster as `~/.kube/config`. Then replace the value of the server field with the IP or name of your K3s server. kubectl can now manage your K3s cluster.
