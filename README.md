- **WORK IN PROGRES**
- running this script might break your system.
- written in pure bash, works only **bookworm** dist.

## JANGBI(Device)

Jangbi is a comprehensive security-focused network appliance framework designed as a poor man's Firewalla alternative. It combines iptables, dnsmasq, and various security tools on top of Armbian/DietPi/Debian to create a powerful network security device. The framework is part of the Dure ecosystem and provides enterprise-grade security features for home and small business networks.<br/>
similar projects: [pi-hole](https://pi-hole.net/), [technitium](https://technitium.com/dns/), [adguardhome](https://github.com/AdguardTeam/AdGuardHome), [blocky](https://github.com/0xERR0R/blocky), [portmaster](https://github.com/safing/portmaster?tab=readme-ov-file)

## Features

### Core Security Features
- **OS Hardening**: Disable kernel modules, sysctl hardening, disable dangerous binaries
- **Network Security**: Pre-configured iptables rules, port forwarding, MAC whitelisting
- **Intrusion Detection**: AIDE (file integrity), auditd (system auditing)
- **DNS Security**: DNS blocking with Dnsmasq, Dnscrypt-proxy support
- **Traffic Analysis**: Network monitoring with darkstat, log analysis with Vector
- **Access Control**: Port knocking with knockd, SSH hardening

### Supported Services
- **Firewall**: iptables/nftables with advanced rules
- **DNS/DHCP**: dnsmasq with ad-blocking capabilities  
- **WiFi Access Point**: hostapd for wireless networking
- **VPN/Proxy**: WSTunnel for secure remote access
- **Monitoring**: darkstat, auditd, AIDE, Vector, Redis
- **Remote Access**: OpenSSH with security hardening

## Device Operating Modes

### 1. Gateway Mode (Traditional Router)
Acts as a traditional NAT router with WAN-LAN separation:
- DNS/DHCP/DNS blocking via dnsmasq
- IP blocking via ipset and iptables
- DNS blacklist filtering
- NAT masquerading for LAN clients

### 2. WSTunnel Mode (Proxy-Only)
Secure proxy mode without NAT routing:
- Clients connect only through WSTunnel proxy
- No direct internet routing
- Enhanced security through proxy filtering
- DNS/DHCP without masquerading

### 3. Client Mode
Single interface mode for endpoint protection:
- Host-based firewall rules
- Local security hardening
- Monitoring and intrusion detection

## Prerequisites

Before installing Jangbi-IT, ensure your system meets these requirements:

- **Operating System**: Armbian, Debian Bookworm, or DietPi
- **Hardware**: Minimum 1GB RAM, 8GB storage
- **Network**: At least one network interface
- **Tools**: `ipcalc-ng` package installed
- **Access**: Root or sudo privileges

#### Gateway Mode(Blacklist Mode)
traditional nat gateway with iptables(nft).

* dns/dhcp/dnsblock : dnsmasq
* block ip : ipset -> iptables, darkstat -> cutcdn/cdncheck -> iptables, vector(sysdig) -> iptables
* block dns : steven blacklist -> dnsmasq/dnscrypt-proxy
* (todo) remote gateway management app : buha app

#### WStunnel Mode(Whitelist Mode)
without nat routing, client only connect to wstunnel to outside. no route. only through wstunnel.

* dns/dhcp : dnsmasq(no masquerade)
* block ip : iptables
* block dns : dnsmasq
* (todo) remote gateway management app : buha app

## Prerequisite
- armbian/debian/dietpi compatible host with **bookworm** distribution
- ipcalc-ng installed

## Installation
- on any **bookworm** distributions

```bash
# install ipcalc-ng
$ apt install ipcalc-ng

# clone repository
$ git clone https://github.com/dure-one/jangbi.git /opt/jangbi

# copy .config.gateway.sample to .config file
$ cp .config.gateway .config

# check interface name
# consider which interface is for WAN, LAN, WLAN
$ ip a

# edit settings, add interface name on WAN, LAN, WLAN
$ nano .config

# run configurator
$ ./init.sh
```

### Default Network Settings
* single ethernet or wifi interface : client mode
* two ethernet or single ethernet and wifi : gateway mode(1wan, 1gateway or 1ap)

## Todo

### Before Next Release
- (done)Sets numerous hardening kernel arguments (Inspired by Madaidan's Hardening Guide) details
- (done)SSHd configuration with knockd
- (done)Wifi AP mode tests
- (done)dhcp client replace for systemd-networkd
- (done)license listing
- (done)time settings with script based ntp client
- (done)dmz or twin ip(super dmz)
- (done)keep process running & working : wstunnel hostapd dnsmasq anydnsdqy darkstat
- (done)iptables : all occurence by modes cases
- (done)Reduce the sudo timeout to 1 minute
- change mac address(random) on wan interface - macchanger
- (done)network monitoring(darkstat)
- tcp syn flood https://superuser.com/a/1852992
- (done)ip spoofing
- (done)block incoming,outgoing icmp IPTABLES_DROP_ICMP
- wol settings
- (done)new dns client : anydnsdqy
- (done)bugs on ifupdown network interfaces for WLAN, dnsmasq network for WLAN
- dns blacklist https://urlhaus.abuse.ch/api/#hostfile


### Later
- (feat)
- qos speed limit by ip, mac, hostname
- host search by mac address network tools
- Stress Tests(iperf)
- automatic wan interface selecting
- smurf when icmp on
- arp snooping no way https://superuser.com/questions/1532095/how-to-block-arp-spoofing-with-arptables
- ddns settings - https://github.com/ddclient/ddclient
- ip source static routing
- Installing usbguard and providing ujust commands to automatically configure it
- Automatic Functional Tests
- totp to knockd integration(later yubikey/tokenkey integration)
- change aide for malware hash check
- multicast forward igmp
- static routing table
- vpn server settings
- tcp, udp, icmp connection control timeout setting tcp syn, tcp estab,
- config backup/ restore
- lkrg & kernel patches or kernel-installer.sh integration
- malware hash check online api https://hash.cymru.com/ https://www.team-cymru.com/mhr
- option to disable gui logind and replace it to tty autologin and startx automatically and vlock
- hiding sensitive information on confiuration logs.
- pstrap https://github.com/shishouyuan/pstrap.git
- dns over tor
- dns over cloudflared
- (rsyslog)
- syslog, auditd, aide, auth, dpkg, daemon, syslog, kern, cron, user, boot, dnsmasq, redis logs
- remote log/debug log submit
- (buha)
- buha application(jangbi client) for android vpn, windows simplewall mgmt
- windows setup builder on .github workflow. => buha
- network connections status flag https://github.com/Lissy93/AdGuardian-Term/tree/main
- system monitor data collect with rsyslog
- link status connection monitoring tui
- Basic Buha Application for installation of jangbi sdcard(eflasher, imgwrite)
- wstunnel client
- knockd client

