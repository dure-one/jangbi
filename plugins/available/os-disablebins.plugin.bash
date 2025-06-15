# shellcheck shell=bash
cite about-plugin
about-plugin 'disable binaries.'
# C : DISABLE_BIN

function os-disablebins {
    about 'helper function for disable binaries'
    group 'os'
    param '1: command'
    param '2: params'
    example '$ os-disablebins check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-disablebins_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-disablebins_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-disablebins_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-disablebins_run "$2"
    else
        __os-disablebins_help
    fi
}

function __os-disablebins_help {
    echo -e "Usage: disablebins [COMMAND] [profile]\n"
    echo -e "Helper to disable binaries.\n"
    echo -e "Commands:\n"
    echo "   help	  	Show this help message"
    echo "   install   	Install disable binaries"
    echo "   uninstall 	Uninstall disable binaries"
    echo "   check	 	Check installable"
    echo "   run	 	run disable binaries"
}

function __os-disablebins_blankrep() { # binary file replacement
    local TBIN="${1}"
    local TDIR=$(dirname $(which "${TBIN}"))
    # echo "${TDIR}/${TBIN}"
    if [[ ${DISABLE_BIN} -gt 0 ]]; then # DISABLE_BIN=1
        [[ ! -f ${TDIR}/${TBIN}___ ]] && pushd "${TDIR}" && mv "${TBIN}" "${TBIN}___" && cp /usr/bin/true "${TBIN}" && popd
    else # DISABLE_BIN=0
        [[ -f ${TDIR}/${TBIN}___ ]] && pushd "${TDIR}" && rm -rf "${TBIN}" && mv "${TBIN}___" "${TBIN}" && popd
    fi
}

function __os-disablebins_install {
    [[ ${DISABLE_BIN} -gt 0 ]] && log_debug "Trying to install os-disablebins."
    # kernel module blacklist
    cp -rf ./configs/blacklist.conf /etc/modprobe.d/blacklist.conf
    # https://github.com/MikeHorn-git/Kernel-Hardening/blob/main/conf/blacklist.conf
    __os-disablebins_blankrep avahi-daemon &>/dev/null # disable avahi completely
    __os-disablebins_blankrep af_802154 &>/dev/null				# 6LoWPAN/IEEE 802.15.4 networking
    __os-disablebins_blankrep amdgpu &>/dev/null				# AMD GPU driver
    __os-disablebins_blankrep appletalk &>/dev/null				# AppleTalk networking protocol
    __os-disablebins_blankrep ath9k &>/dev/null					# Atheros 802.11n wireless LAN driver
    __os-disablebins_blankrep atm &>/dev/null					# Asynchronous Transfer Mode networking
    __os-disablebins_blankrep asus_acpi &>/dev/null				# Advanced Configuration and Power Interface support on ASUS laptops
    __os-disablebins_blankrep ax25 &>/dev/null					# AX.25 packet radio protocol
    __os-disablebins_blankrep b43 &>/dev/null					# Broadcom 43xx wireless driver
    __os-disablebins_blankrep bcm43xx &>/dev/null			   # Older wireless driver
    __os-disablebins_blankrep bluetooth &>/dev/null				# Bluetooth protocol stack
    __os-disablebins_blankrep btusb &>/dev/null					# Bluetooth protocol stack
    __os-disablebins_blankrep can &>/dev/null					# Controller Area Network protocol
    __os-disablebins_blankrep cdrom &>/dev/null					# CD ROM module
    __os-disablebins_blankrep cifs &>/dev/null					# CIFS/SMB networking protocol
    __os-disablebins_blankrep cramfs &>/dev/null				# Compressed ROM filesystem
    __os-disablebins_blankrep dccp &>/dev/null					# Datagram Congestion Control Protocol
    __os-disablebins_blankrep decnet &>/dev/null				# DECnet networking protocol
    __os-disablebins_blankrep de4x5 &>/dev/null					# Older Network driver
    __os-disablebins_blankrep dvb_core &>/dev/null				# Core module for DVB devices
    __os-disablebins_blankrep dvb_usb_rtl2832u &>/dev/null		# DVB-T USB devices with RTL2832U chipset
    __os-disablebins_blankrep dvb_usb_rtl28xxu &>/dev/null		# DVB-T USB devices with RTL28xx chipset
    __os-disablebins_blankrep dvb_usb_v2 &>/dev/null			# Newer DVB USB framework
    __os-disablebins_blankrep econet &>/dev/null				# Acorn Econet protocol
    __os-disablebins_blankrep eepro100 &>/dev/null			  # Older Network driver
    __os-disablebins_blankrep eth1394 &>/dev/null			   # Older Network driver
    __os-disablebins_blankrep exfat &>/dev/null					# ExFAT filesystem
    __os-disablebins_blankrep fddi &>/dev/null					# Fiber Distributed Data Interface networking
    __os-disablebins_blankrep firewire &>/dev/null				# FireWire support
    __os-disablebins_blankrep firewire-core &>/dev/null			# Core FireWire module
    __os-disablebins_blankrep firewire_core &>/dev/null			# Core FireWire module
    __os-disablebins_blankrep firewire-ohci &>/dev/null			# FireWire OHCI driver
    __os-disablebins_blankrep firewire_ohci &>/dev/null			# FireWire OHCI driver
    __os-disablebins_blankrep firewire-sbp2 &>/dev/null			# FireWire SCSI protocol driver
    __os-disablebins_blankrep firewire_sbp2 &>/dev/null			# FireWire SCSI protocol driver
    __os-disablebins_blankrep floppy &>/dev/null				# Floppy disk support
    __os-disablebins_blankrep freevxfs &>/dev/null				# FreeVxFS filesystem
    __os-disablebins_blankrep garmin_gps &>/dev/null			# Garmin GPS module
    __os-disablebins_blankrep gfs2 &>/dev/null					# GFS2 filesystem
    __os-disablebins_blankrep gnss &>/dev/null				  # GPS module (Global Navigation Satellite System)
    __os-disablebins_blankrep gnss-mtk &>/dev/null			  # GPS module (Global Navigation Satellite System)
    __os-disablebins_blankrep gnss-serial &>/dev/null		   # GPS module (Global Navigation Satellite System)
    __os-disablebins_blankrep gnss-sirf &>/dev/null			 # GPS module (Global Navigation Satellite System)
    __os-disablebins_blankrep gnss-usb &>/dev/null			  # GPS module (Global Navigation Satellite System)
    __os-disablebins_blankrep gnss-ubx &>/dev/null			  # GPS module (Global Navigation Satellite System)
    __os-disablebins_blankrep hamradio &>/dev/null				# Amateur radio protocols
    __os-disablebins_blankrep hfs &>/dev/null					# Hierarchical File System
    __os-disablebins_blankrep hfsplus &>/dev/null				# HFS+ filesystem
    __os-disablebins_blankrep ib_ipoib &>/dev/null				# InfiniBand over IP
    __os-disablebins_blankrep ipx &>/dev/null					# IPX networking protocol
    __os-disablebins_blankrep jffs2 &>/dev/null					# Journaling Flash File System v2
    __os-disablebins_blankrep jfs &>/dev/null					# IBM's Journaled File System
    __os-disablebins_blankrep joydev &>/dev/null				# Joystick support
    __os-disablebins_blankrep ksmbd &>/dev/null					# SMB Direct
    __os-disablebins_blankrep lp &>/dev/null					# Printer support for parallel port
    __os-disablebins_blankrep mei &>/dev/null				   # Interface between the Intel ME and the OS
    __os-disablebins_blankrep mei-me &>/dev/null				# Interface between the Intel ME and the OS
    __os-disablebins_blankrep msr &>/dev/null					# Model-Specific Register (is a control register
    __os-disablebins_blankrep n-hdlc &>/dev/null				# HDLC networking protocol
    __os-disablebins_blankrep netrom &>/dev/null				# Amateur radio networking
    __os-disablebins_blankrep nfs &>/dev/null					# Network File System
    __os-disablebins_blankrep nfsv3 &>/dev/null					# NFS version 3
    __os-disablebins_blankrep nfsv4 &>/dev/null					# NFS version 4
    __os-disablebins_blankrep ntfs &>/dev/null					# NTFS filesystem
    __os-disablebins_blankrep nvidia &>/dev/null				# NVIDIA graphics driver
    __os-disablebins_blankrep ohci1394 &>/dev/null				# FireWire related module
    __os-disablebins_blankrep p8022 &>/dev/null					# 802.2 LLC
    __os-disablebins_blankrep p8023 &>/dev/null					# 802.3 Ethernet
    __os-disablebins_blankrep parport &>/dev/null				# Parallel port support
    __os-disablebins_blankrep pmt_class &>/dev/null				# Platform Monitoring Telemetry (Intel)
    __os-disablebins_blankrep pmt_telemetry &>/dev/null			# Platform Monitoring Telemetry (Intel)
    __os-disablebins_blankrep ppp_async &>/dev/null				# Point-to-Point Protocol for asynchronous connections
    __os-disablebins_blankrep ppp_deflate &>/dev/null			# Compression module for PPP
    __os-disablebins_blankrep ppp_generic &>/dev/null			# Generic PPP support
    __os-disablebins_blankrep pppoe &>/dev/null					# PPP over Ethernet
    __os-disablebins_blankrep pppox &>/dev/null					# PPP over various transports
    __os-disablebins_blankrep prism54 &>/dev/null			   # Older wireless driver
    __os-disablebins_blankrep psnap &>/dev/null					# SNAP protocol
    __os-disablebins_blankrep r820t &>/dev/null					# Rafael Micro R820T tuner
    __os-disablebins_blankrep radeon &>/dev/null				# Radeon GPU driver
    __os-disablebins_blankrep raw1394 &>/dev/null			   # FireWire related module
    __os-disablebins_blankrep rds &>/dev/null					# Reliable Datagram Sockets
    __os-disablebins_blankrep reiserfs &>/dev/null				# ReiserFS filesystem
    __os-disablebins_blankrep rose &>/dev/null					# Amateur radio protocol
    __os-disablebins_blankrep rtl2830 &>/dev/null				# Realtek RTL2830 DVB-T receiver
    __os-disablebins_blankrep rtl2832 &>/dev/null				# Realtek RTL2832 DVB-T receiver
    __os-disablebins_blankrep rtl2832_sdr &>/dev/null			# RTL2832-based SDR devices
    __os-disablebins_blankrep rtl2838 &>/dev/null				# Realtek RTL2838 DVB-T receiver
    __os-disablebins_blankrep rtl8187 &>/dev/null				# Realtek RTL8187 wireless LAN driver
    __os-disablebins_blankrep sbp2 &>/dev/null					# FireWire related module
    __os-disablebins_blankrep sctp &>/dev/null					# Stream Control Transmission Protocol
    __os-disablebins_blankrep slhc &>/dev/null					# SLIP/PPP compression and decompression
    __os-disablebins_blankrep squashfs &>/dev/null				# SquashFS filesystem
    __os-disablebins_blankrep sr_mod &>/dev/null				# CD ROM module
    __os-disablebins_blankrep thunderbolt &>/dev/null			# Thunderbolt support
    __os-disablebins_blankrep tipc &>/dev/null					# Transparent Inter-process Communication
    __os-disablebins_blankrep tr &>/dev/null					# Token Ring protocol
    __os-disablebins_blankrep udf &>/dev/null					# Universal Disk Format filesystem
    __os-disablebins_blankrep usb_storage &>/dev/null			# USB storage devices
    __os-disablebins_blankrep uvcvideo &>/dev/null				# USB Video Class driver
    __os-disablebins_blankrep uinput &>/dev/null				# User-level input driver
    __os-disablebins_blankrep video1394 &>/dev/null			 # FireWire related module
    __os-disablebins_blankrep vivid &>/dev/null					# Virtual video driver
    __os-disablebins_blankrep x25 &>/dev/null					# X.25 networking protocol
    __os-disablebins_blankrep wsdd &>/dev/null					# wsdd
    __os-disablebins_blankrep /usr/libexec/tracker-miner-fs-3 &>/dev/null # disable file indexing
    __os-disablebins_blankrep /usr/libexec/tracker-miner-rss-3 &>/dev/null # disable file indexing
}

function __os-disablebins_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall os-disablebins."
    __os-disablebins_install
    rm -rf /etc/modprobe.d/blacklist.conf
}

function __os-disablebins_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting os-disablebins Check"
    [[ ${#DISABLE_BIN[@]} -lt 1 ]] && \
        log_info "DISABLE_BIN variable is not set." && [[ $running_status -lt 10 ]] && running_status=10

    # check avahi-daemon exists
    [[ $(which avahi-daemon|wc -l) -eq 0 ]] && \
        log_info "avahi-daemon is disabled. it seems disabled." && \
        [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __os-disablebins_run {
    # no need
    return 0
}

complete -F __os-disablebins_run os-disablebins