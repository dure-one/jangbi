- WORK IN PROGRES
* this project has not been tested.
* running this script might break your system.

# JANGBI(Device)
this project is part of dure ecosystem.<br/>
poor firewalla alternatives with iptables and dnsmasq on top of armbian/dietpi/debian.

## Features
* os hardening(disable kernel modules, sysctl, disable binaries)
* enable/disable iptables, auditd, aide, dnsmasq, darkstat, hostapd, knockd, sshd, wstunnel, redis, crond, sysdig
* pre-configured iptables cases
* sysctl configs hardening
* mac whitelisting
* port forwarding target interface to internal hosts

### Used application by purpose
* os hardening : firmware updates, disable kernel modules, sysctl hardening, disable binaries
* sys firewall : iptables
* intrusion detection : aide, auditd
* logs : syslog, redis, crond, sysdig
* dhcp, dns : dnsmasq
* dns-over-quic : anydnsdqy
* one time programmable : step-cli
* wifi-ap : hostapd
* ssh : knockd, openssh-server
* socks5 proxy : wstunnel

### Device Modes
* gateway : traditional Wan-Lan router gateway with iptables masquerade.
* wstunnel : dual network interface with socks5 routing only.
* client : being selected on a single network interface.

#### Gateway Mode(Blacklist Mode)
traditional nat gateway with iptables(nft).

* dns/dhcp/dnsblock : dnsmasq
* block ip : ipset -> iptables, darkstat -> cutcdn -> iptables
* block dns : steven blacklist -> dnsmasq
* (todo) remote gateway management app : buha app

#### WStunnel Mode(Whitelist Mode)
without nat routing, client only connect to wstunnel to outside. normal internet disconnected for client.

* dhcp, dns service with dnsmasq
* firewall with iptables
* block dns with dnsmasq
* socks5 proxy with wstunnel

## Prerequisite
- armbian/debian/dietpi compatible host
- ipcalc-ng net-tools unzip installed
- debian-dvd.iso bookworm image download
- additional package download(dure.pkgs.list)

## Installation
- on any bookworm distributions

```bash
# clone repository
$ git clone https://github.com/dure-one/jangbi.git

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
- host search by mac address network tools
- qos speed limit by ip, mac, hostname
- (done)new dns client : anydnsdqy
- bugs on ifupdown network interfaces for WLAN, dnsmasq network for WLAN

### Later
- Stress Tests(iperf)
- automatic wan interface selecting
- smurf when icmp on
- arp snooping no way https://superuser.com/questions/1532095/how-to-block-arp-spoofing-with-arptables
- ddns settings - https://github.com/ddclient/ddclient
- network connections status flag https://github.com/Lissy93/AdGuardian-Term/tree/main
- ip source static routing
- internet restriction
- system monitor with redis time series database => suzip
- Basic Buha Application for installation of jangbi sdcard(eflasher, imgwrite)
- link status connection monitoring tui
- Installing usbguard and providing ujust commands to automatically configure it
- Automatic Functional Tests
- windows setup builder on .github workflow. => buha
- buha application(jangbi client) for android vpn, windows simplewall mgmt
- suzip application for windows/linux ip by app sender, android ip by app sender
- totp to knockd integration(later yubikey/tokenkey integration)
- change aide for malware hash check
- multicast forward igmp
- static routing table
- vpn server settings
- tcp, udp, icmp connection control timeout setting tcp syn, tcp estab,
- syslog, auditd, aide, auth, dpkg, daemon, syslog, kern, cron, user, boot, dnsmasq, redis logs
- config backup/ restore
- remote log/debug log submit
- lkrg & kernel patches or kernel-installer.sh integration
- dns blacklist https://urlhaus.abuse.ch/api/#hostfile
- malware hash check online api https://hash.cymru.com/ https://www.team-cymru.com/mhr
- option to disable gui logind and replace it to tty autologin and startx automatically and vlock
- hiding sensitive information on confiuration logs.
- pstrap https://github.com/shishouyuan/pstrap.git
