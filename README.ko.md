- WORK IN PROGRES
* this project has not been tested.

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
* logs : syslog, redism, crond, sysdig
* dhcp, dns : dnsmasq
* dns-over-https : any_dns_dqy
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
* block ip : ipsum -> iptables, darkstat -> cutcdn -> iptables
* block dns : steven blacklist -> dnsmasq
* (todo) remote gateway management app : buha app
* (todo) cumulate logs in timeseries db : suzip app

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
- Writing .config : boot live iso and planning by writing .config file
- Img Writing : write OS img to sdcard
- Patch : run embed.sh to embed init script to sdcard(build.sh output to image file)
- Use

### Default Network Settings
* single ethernet or wifi interface : client mode
* two ethernet or single ethernet and wifi : gateway mode(1wan, 1gateway or 1ap)

## Todo

### Before Next Release
- Stress Tests(iperf)
- (done)Sets numerous hardening kernel arguments (Inspired by Madaidan's Hardening Guide) details
- SSHd configuration with knockd
- (done)Wifi AP mode tests
- Basic Buha Application for installation of jangbi sdcard(eflasher, imgwrite)
- keep process running & working
- iptables : all occurence by modes cases
- network connections status flag
- windows setup builder on .github workflow.
- Reduce the sudo timeout to 1 minute
- change mac address(random) on wan interface
- (done)dhcp client replace for systemd-networkd
- system monitor with redis time series database
- (done)license listing
- dmz or twin ip(super dmz)
- internet restriction
- network monitoring
- tcp syn flood
- smurf
- ip source routing
- ip spoofing
- arp snooping
- block incoming icmp
- block outgoing icmp
- ddns settings
- wol settings
- host search by mac address network tools
- qos speed limit by ip, mac, hostname
- link status connection monitoring tui
- (done)time settings

### Later
- Installing usbguard and providing ujust commands to automatically configure it
- Automatic Functional Tests
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
- new dns client https://github.com/severinalexb/any-dns/ + https://github.com/dandyvica/dqy
- lkrg & kernel patches
- dns blacklist https://urlhaus.abuse.ch/api/#hostfile
- malware hash check online api https://hash.cymru.com/ https://www.team-cymru.com/mhr

# Credits
- [pstrap](https://github.com/shishouyuan/pstrap.git)
