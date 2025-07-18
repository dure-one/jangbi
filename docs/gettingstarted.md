---
title: Gettingstarted
hide:
- toc
---

# Getting Started with Jangbi

## Warning

* systemd plugin will remove many important packages for network. please consider network might disconnect. do not run it with remote connections.

## Quick Installation

### 1. Install Prerequisites

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required tools
sudo apt install -y ipcalc-ng git
```

### 2. Clone Repository

```bash
# Clone the Jangbi repository
git clone https://github.com/dure-one/jangbi.git
cd jangbi
```

### 3. Configure Your Device

```bash
# Copy gateway configuration template
cp .config.default .config

# Check your network interfaces
ip a

# Edit configuration file
nano .config
```

### 4. Network Interface Configuration

Identify your network interfaces and update the configuration:

```bash
# List available interfaces
ip link show
(jangbi) root@lap:/opt/jangbi# ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
3: eth1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
4: wlan0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff

# Example interface assignments for gateway mode:
JB_WANINF=eth0      # WAN interface (internet connection)
JB_WAN="dhcp"
JB_LANINF=eth1      # LAN interface (local network)
JB_LAN="192.168.79.1/24"
JB_WLANINF=wlan0    # WLAN interface (WiFi AP)
JB_WLAN="192.168.89.1/24"
```

### 5. Run Installation

```bash
# Initialize and configure the system
sudo ./init.sh
```

## Configuration File Reference

### Basic Settings

```bash
# Device identification
DIST_DEVICE="orangepi5-plus"
DIST_NAME="armbian_bookworm_aarch64"

# System configuration
CONF_TIMEZONE="Asia/Seoul"
JB_USERID=admin
JB_SSHPUBKEY="your-ssh-public-key-here"
```

### Network Configuration

```bash
# WAN Interface (Internet)
JB_WANINF=eth0
JB_WAN="dhcp"  # or static IP like "192.168.1.100/24"

# LAN Interface (Local Network)
JB_LANINF=eth1
JB_LAN="192.168.79.1/24"

# WiFi Interface (Access Point)
JB_WLANINF=wlan0
JB_WLAN="192.168.100.1/24"
JB_WLAN_APMODE=1
```

### Service Enablement

```bash
# Enable specific services (1=enabled, 0=disabled)
RUN_NET_IPTABLES=1      # Firewall
RUN_NET_DNSMASQ=1       # DNS/DHCP
RUN_NET_HOSTAPD=1       # WiFi AP
RUN_NET_DARKSTAT=1      # Network monitoring
RUN_OS_AUDITD=1         # System auditing
RUN_OS_AIDE=1           # File integrity
```

## Using Jangbi-IT

### Managing Services

Use the plugin system to control individual services:

```bash
# Check service status
./jangbi_it.sh net-iptables check
./jangbi_it.sh net-dnsmasq check

# Install and configure services
./jangbi_it.sh net-iptables install
./jangbi_it.sh net-iptables configgen
./jangbi_it.sh net-iptables configapply

# Start services
./jangbi_it.sh net-iptables run
./jangbi_it.sh net-dnsmasq run

# Monitor services
./jangbi_it.sh net-darkstat run  # Web interface at http://device-ip:666
```

### Available Plugins

#### Network Plugins
- `net-iptables` - Firewall management
- `net-dnsmasq` - DNS/DHCP server
- `net-hostapd` - WiFi access point
- `net-sshd` - SSH daemon hardening
- `net-darkstat` - Network traffic monitoring
- `net-knockd` - Port knocking daemon
- `net-wstunnel` - WebSocket tunnel proxy

#### OS Plugins
- `os-auditd` - System auditing
- `os-aide` - File integrity monitoring
- `os-sysctl` - Kernel parameter tuning
- `os-conf` - System configuration
- `os-minmon` - Minimal monitoring
- `os-vector` - Log management

### Plugin Usage Pattern

All plugins follow a consistent command structure:

```bash
./jangbi_it.sh <plugin-name> <command>

# Common commands:
install      # Install the service
uninstall    # Remove the service
configgen    # Generate configuration files
configapply  # Apply configuration changes
check        # Check service status
run          # Start/restart the service
download     # Download required packages
```

---

**Warning**: This software is still in development. Use with caution in production environments and always test in a lab environment first.