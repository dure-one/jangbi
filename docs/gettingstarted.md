---
title: Gettingstarted
---

# Getting Started with Jangbi

## Warning

* systemd plugin will remove many important packages for network. please consider network might disconnect. do not run it with remote connections.

## Quick Installation

### 1. Install Prerequisites

```bash
# Install required tools
sudo apt install -y ipcalc-ng git patch
```

### 2. Clone Repository

Install in /opt folder where init system can find easily.<br/>
Use root accoutfor install and edit config files.

```bash
# Clone the Jangbi repository
git clone https://github.com/dure-one/jangbi.git /opt/jangbi
cd /opt/jangbi
```

### 3. Configure Your Device

```bash
# Copy gateway configuration template
cp .config.default .config

# Check your network interfaces
ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
    inet 192.168.79.186/24 brd 192.168.79.255 scope global dynamic enx00e04c680686
       valid_lft 37293sec preferred_lft 37293sec
3: eth1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
4: wlan0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff

# Edit configuration file
nano .config
# Example interface assignments for gateway mode:
JB_WANINF=eth0      # WAN interface (internet connection)
JB_WAN="dhcp"
JB_LANINF=eth1      # LAN interface (local network)
JB_LAN="192.168.79.1/24"
JB_WLANINF=wlan0    # WLAN interface (WiFi AP)
JB_WLAN="192.168.89.1/24"
```

### 4. Configure Plugins to run

```bash
# Edit configuration file
$ nano .config
# gateway apps
RUN_NET_HOSTAPD=1
RUN_NET_DNSMASQ=1
DNSMASQ_BLACKLIST_URLS="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
RUN_NET_DNSCRYPTPROXY=1
RUN_NET_DARKSTAT=1
RUN_OS_REDIS=1
RUN_OS_MINMON=1
```

### 4. Run Installation

```bash
# Initialize and configure the system
$ ./init.sh
```

## Using Jangbi-IT

### Managing Services

Use the plugin system to control individual services:

```bash
# load jangbi-it
$ cd /opt/jangbi
$ source jangbi_it.sh

# Check service status
$ net-iptables check
$ net-dnsmasq check

# Install and configure services
$ net-iptables install
$ net-iptables configgen
$ net-iptables configapply

# Start services
$ net-iptables run
$ net-dnsmasq run

# Monitor services
$ net-darkstat run  # Web interface at http://device-ip:666
```

### Available Plugins

#### Network Plugins
- `net-darkstat` - Network traffic monitoring
- `net-dnsmasq` - DNS/DHCP server
- `net-dnscryptproxy` - Encrypted DNS proxy
- `net-hostapd` - WiFi access point
- `net-hysteria` - Hysteria high-performance QUIC proxy
- `net-iptables` - Firewall management
- `net-knockd` - Port knocking daemon
- `net-omnip` - Omnip all-in-one QUIC proxy
- `net-shoes` - Shoes multi-protocol proxy server
- `net-sshd` - SSH daemon hardening
- `net-v2ray` - V2Ray comprehensive proxy platform

#### OS Plugins
- `os-auditd` - System auditing
- `os-aide` - File integrity monitoring
- `os-sysctl` - Kernel parameter tuning
- `os-conf` - System configuration
- `os-minmon` - Minimal monitoring
- `os-vector` - Log management

All plugins follow a consistent command structure:

```bash
<plugin-name> <command>

# Common commands:
install      # Install the service
uninstall    # Remove the service
configgen    # Generate configuration files
configapply  # Apply configuration changes
check        # Check service status
run          # Start/restart the service
download     # Download required packages
```

## Configuration File Reference
```bash
$ cat .config.default 
--8<-- ".config.default"
```

---

**Warning**: This software is still in development. Use with caution in production environments and always test in a lab environment first.