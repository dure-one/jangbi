## \brief dnsmasq install configurations.
## \desc This tool helps install, configure, and manage dnsmasq (DNS forwarder and DHCP server)
## for network services. It provides automated installation, configuration management,
## DNS blacklist updates, and service control capabilities. Dnsmasq serves as a lightweight
## DNS forwarder, DHCP server, and network boot server for small networks.

## \example Install and configure dnsmasq:
## \example-code bash
##   net-dnsmasq install
##   net-dnsmasq configgen
##   net-dnsmasq configapply
## \example-description
## In this example, we install dnsmasq, generate the configuration files,
## and apply them to the system for DNS and DHCP services.

## \example Update blacklist and run service:
## \example-code bash
##   net-dnsmasq updateblist
##   net-dnsmasq run
##   net-dnsmasq check
## \example-description
## In this example, we update the DNS blacklist for ad-blocking,
## start the dnsmasq service, and verify that it's running properly.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'dnsmasq install configurations.'

function net-dnsmasq {
    about 'dnsmasq install configurations'
    group 'postnet'
    runtype 'minmon'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ net-dnsmasq subcommand'
    local PKGNAME="dnsmasq"
    local DMNNAME="net-dnsmasq"
    BASH_IT_LOG_PREFIX="net-dnsmasq: "
    DNSMASQ_PORTS="${DNSMASQ_PORTS:-"LO:53"}"
    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-dnsmasq_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-dnsmasq_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-dnsmasq_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-dnsmasq_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-dnsmasq_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-dnsmasq_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-dnsmasq_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "updateblist" ]]; then
        __net-dnsmasq_update_blacklist "$2"
    else
        __net-dnsmasq_help
    fi
}

## \usage net-dnsmasq [COMMAND]
## \usage net-dnsmasq install|uninstall|configgen|configapply|check|run|download|updateblist
function __net-dnsmasq_help {
    echo -e "Usage: net-dnsmasq [COMMAND]\n"
    echo -e "Helper to dnsmasq install configurations.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install os firmware"
    echo "   uninstall   Uninstall installed firmware"
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   download    Download pkg files to pkg dir"
    echo "   updateblist Update blacklist"
    echo "   check       Check vars available"
    echo "   run         Run tasks"
}

function __net-dnsmasq_install { # RUN_NET_DNSMASQ
    log_debug "Installing ${DMNNAME}..."
    export DEBIAN_FRONTEND=noninteractive
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
        [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
        apt install -qy dnsmasq-base || log_error "${DMNNAME} online install failed."
    else
        local filepat="./pkgs/dnsmasq-base*.deb"
        local pkglist="./pkgs/dnsmasq-base.pkgs"
        [[ $(find ${filepat}|wc -l) -lt 1 ]] && log_error "${DMNNAME} pkg file not found."
        pkgslist_down=()
        while read -r pkg; do
            [[ $pkg ]] && pkgslist_down+=("./pkgs/${pkg}*.deb")
        done < ${pkglist}
        # shellcheck disable=SC2068
        apt install -qy ${pkgslist_down[@]} || log_error "${DMNNAME} offline install failed."
    fi
    if ! __net-dnsmasq_configgen; then # if gen config is different do apply
        __net-dnsmasq_configapply
        rm -rf /tmp/${PKGNAME}
    fi
}

function __net-dnsmasq_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    __net-dnsmasq_generate_config
    __net-dnsmasq_update_blacklist
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-dnsmasq_configapply {
    [[ ! -f /tmp/${PKGNAME}.diff ]] && log_error "/tmp/${PKGNAME}.diff file doesnt exist. please run configgen."
    log_debug "Applying config ${DMNNAME}..."
    local dtnow=$(date +%Y%m%d_%H%M%S)
    [[ -d "/etc/${PKGNAME}" ]] && cp -rf "/etc/${PKGNAME}" "/etc/.${PKGNAME}.${dtnow}"
    pushd /etc/${PKGNAME} 1>/dev/null 2>&1
    patch -i /tmp/${PKGNAME}.diff
    popd 1>/dev/null 2>&1
    rm /tmp/${PKGNAME}.diff
    return 0
}

function __net-dnsmasq_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_apt_pkgs dnsmasq-base
    return 0
}

function __net-dnsmasq_update_blacklist {
    log_debug "Updating blacklist ${DMNNAME}..."
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        IFS=$'|' read -d "" -ra urls <<< "${DNSMASQ_BLACKLIST_URLS}" # split
        for((j=0;j<${#urls[@]};j++)){
            echo "# ${urls[j]}" > /etc/dnsmasq/malware$j.conf
            wget -O- "${urls[j]}" | awk '$1 == "0.0.0.0" { print "address=/"$2"/0.0.0.0/"}' >> /etc/dnsmasq/malware$j.conf
        }
    fi
}

function __net-dnsmasq_generate_config {
    local no_dhcpv6_infs
    # mode
    # 1. gateway lan->wan, wlan->wan
    # 2. client local->wan
    # 3. wastunnel local->wan
    local additional_listenaddr additional_netinf additional_dhcprange netstate
    local netinf netrange netip netminip netmaxip 
    local addiinf addirange addiip addiminip addimaxip
    if [[ ${JB_ROLE} = 'gateway' ]]; then
        # 1. JB_LANINF exists 2. netinf not set 3. JB_LANINF is up
        if [[ -n ${JB_LANINF} && -z ${netinf} ]]; then
            netstate=$(< "/sys/class/net/${JB_LANINF}/operstate")
            if [[ $(< "/sys/class/net/${JB_LANINF}/operstate") = *"up"* ]]; then
                netinf=${JB_LANINF}
                netrange=${JB_LAN}
                [[ ${DISABLE_IPV6} -gt 0 ]] && no_dhcpv6_infs="no-dhcpv6-interface=${JB_LANINF}"
            else
                log_error "JB_LANINF(${JB_LANINF}|${netstate}) is not up, please check your network configuration and config file."
            fi
        fi
        
        if [[ -n ${JB_WLANINF} && -z ${netinf} ]]; then
            netstate=$(< "/sys/class/net/${JB_WLANINF}/operstate")
            if [[ ${netstate} = *"up"* ]]; then
                netinf=${JB_WLANINF}
                netrange=${JB_WLAN}
                [[ ${DISABLE_IPV6} -gt 0 ]] && no_dhcpv6_infs="${no_dhcpv6_infs}no-dhcpv6-interface=${JB_WLANINF}"
            else
                log_error "JB_WLANINF(${JB_WLANINF}|${netstate}) is not up, please check your network configuration."
            fi
        elif [[ -n ${JB_WLANINF} && -n ${netinf} ]]; then
            netstate=$(< "/sys/class/net/${JB_WLANINF}/operstate")
            if [[ ${netstate} = *"up"* ]]; then
                addiinf=${JB_WLANINF}
                addirange=${JB_WLAN}

                addiip=$(ipcalc-ng "${addirange}"|grep Address:|cut -f2)
                addiminip=$(ipcalc-ng "${addirange}"|grep HostMin:|cut -f2)
                addimaxip=$(ipcalc-ng "${addirange}"|grep HostMax:|cut -f2)

                additional_listenaddr="${additional_listenaddr}listen-address=${addiip}"
                additional_netinf="${additional_netinf}interface=${addiinf}"
                additional_dhcprange="${additional_dhcprange}dhcp-range=interface:${addiinf},${addiminip},${addimaxip},12h"
            else
                log_error "JB_WLANINF(${JB_WLANINF}|${netstate}) is not up, please check your network configuration."
            fi
        fi

        if [[ -z ${netinf} ]]; then
            netinf="lo"
            netrange="127.0.0.1/24"
        fi

        netip=$(ipcalc-ng "${netrange}"|grep Address:|cut -f2)
        netminip=$(ipcalc-ng "${netrange}"|grep HostMin:|cut -f2)
        netmaxip=$(ipcalc-ng "${netrange}"|grep HostMax:|cut -f2)
        
        # Additional Listening for Masqueraded Interface
        if [[ ${RUN_NET_IPTABLES} -gt 0 && -n ${IPTABLES_MASQ} && -z ${IPTABLES_OVERRIDE} ]]; then # RUN_NET_IPTABLES=1 IPTABLES_MASQ="WLAN2WAN"
            local additional_listenaddr additional_netinf additional_dhcprange
            IFS=$'|' read -d "" -ra MASQROUTES <<< "${IPTABLES_MASQ}" # split
            for((j=0;j<${#MASQROUTES[@]};j++)){
                local lanxinf lanxip lanxminip lanxmaxip
                IFS=$'<' read -d "" -ra MASQINFS <<< "${MASQROUTES[j]}"
                if [[ $(_trim_string "${MASQINFS[0]}") = "LAN0" && $(_trim_string "${MASQINFS[1]}") = "WAN" ]]; then
                    [[ -z ${JB_LAN0INF} ]] && log_error "JB_LAN0INF is not set, please check your network configuration." && continue
                    lanxinf=${JB_LAN0INF}
                    lanxipNET=${JB_LAN0}
                elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN1" && $(_trim_string "${MASQINFS[1]}") = "WAN" ]]; then
                    [[ -z ${JB_LAN1INF} ]] && log_error "JB_LAN1INF is not set, please check your network configuration." && continue
                    lanxinf=${JB_LAN1INF}
                    lanxipNET=${JB_LAN1}
                elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN2" && $(_trim_string "${MASQINFS[1]}") = "WAN" ]]; then
                    [[ -z ${JB_LAN2INF} ]] && log_error "JB_LAN2INF is not set, please check your network configuration." && continue
                    lanxinf=${JB_LAN2INF}
                    lanxipNET=${JB_LAN2}
                elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN3" && $(_trim_string "${MASQINFS[1]}") = "WAN" ]]; then
                    [[ -z ${JB_LAN3INF} ]] && log_error "JB_LAN3INF is not set, please check your network configuration." && continue
                    lanxinf=${JB_LAN3INF}
                    lanxipNET=${JB_LAN3}
                elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN4" && $(_trim_string "${MASQINFS[1]}") = "WAN" ]]; then
                    [[ -z ${JB_LAN4INF} ]] && log_error "JB_LAN4INF is not set, please check your network configuration." && continue
                    lanxinf=${JB_LAN4INF}
                    lanxipNET=${JB_LAN4}
                elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN5" && $(_trim_string "${MASQINFS[1]}") = "WAN" ]]; then
                    [[ -z ${JB_LAN5INF} ]] && log_error "JB_LAN5INF is not set, please check your network configuration." && continue
                    lanxinf=${JB_LAN5INF}
                    lanxipNET=${JB_LAN5}
                elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN6" && $(_trim_string "${MASQINFS[1]}") = "WAN" ]]; then
                    [[ -z ${JB_LAN6INF} ]] && log_error "JB_LAN6INF is not set, please check your network configuration." && continue
                    lanxinf=${JB_LAN6INF}
                    lanxipNET=${JB_LAN6}
                elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN7" && $(_trim_string "${MASQINFS[1]}") = "WAN" ]]; then
                    [[ -z ${JB_LAN7INF} ]] && log_error "JB_LAN7INF is not set, please check your network configuration." && continue
                    lanxinf=${JB_LAN7INF}
                    lanxipNET=${JB_LAN7}
                elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN8" && $(_trim_string "${MASQINFS[1]}") = "WAN" ]]; then
                    [[ -z ${JB_LAN8INF} ]] && log_error "JB_LAN8INF is not set, please check your network configuration." && continue
                    lanxinf=${JB_LAN8INF}
                    lanxipNET=${JB_LAN8}
                elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN9" && $(_trim_string "${MASQINFS[1]}") = "WAN" ]]; then
                    [[ -z ${JB_LAN9INF} ]] && log_error "JB_LAN9INF is not set, please check your network configuration." && continue
                    lanxinf=${JB_LAN9INF}
                    lanxipNET=${JB_LAN9}
                else
                    continue
                fi
                lanxip=$(ipcalc-ng "${lanxipNET}"|grep Address:|cut -f2)
                lanxminip=$(ipcalc-ng "${lanxipNET}"|grep HostMin:|cut -f2)
                lanxmaxip=$(ipcalc-ng "${lanxipNET}"|grep HostMax:|cut -f2)
                additional_listenaddr="${additional_listenaddr}listen-address=${lanxip}"
                additional_netinf="${additional_netinf}interface=${lanxinf}"
                additional_dhcprange="${additional_dhcprange}dhcp-range=interface:${lanxinf},${lanxminip},${lanxmaxip},12h"
                [[ ${DISABLE_IPV6} -gt 0 ]] && no_dhcpv6_infs="${no_dhcpv6_infs}no-dhcpv6-interface=${lanxinf}"
            }
        fi
    else # local->wan # client mode, tunnelonly mode
        netinf="lo"
        netip="127.0.0.1"
        netminip="127.0.0.1"
        netmaxip="127.0.0.1"
    fi
    # if [[ ${RUN_NET_ANYDNSDQY} -gt 0 ]]; then
    #    upstreamdns="127.0.0.1"
    #else
    upstreamdns="${DNS_UPSTREAM}"
    #fi
    tee /tmp/dnsmasq/dnsmasq.conf > /dev/null <<EOT
# JB_ROLE=${JB_ROLE}
domain-needed
bogus-priv
dnssec
dnssec-check-unsigned
filterwin2k
strict-order
no-resolv
no-poll
conf-file=/etc/dnsmasq/trust-anchors.conf
server=${upstreamdns}
listen-address=${netip}
$(printf '%s' "${additional_listenaddr}")
interface=${netinf}
$(printf '%s' "${additional_netinf}")
bind-interfaces
$(printf '%s' "${no_dhcpv6_infs}")
no-hosts
dhcp-range=interface:${netinf},${netminip},${netmaxip},12h
$(printf '%s' "${additional_dhcprange}")
dhcp-leasefile=/var/lib/misc/dnsmasq.leases
cache-size=1000
no-negcache
conf-dir=/etc/dnsmasq/,*.conf
local-service
dns-loop-detect
log-queries
log-dhcp
EOT
}

function __net-dnsmasq_uninstall { 
    log_debug "Uninstalling ${DMNNAME}..."
    pidof dnsmasq | xargs kill -9 2>/dev/null
    echo "nameserver ${DNS_UPSTREAM}"|tee /etc/resolv.conf
    _time_sync "${DNS_UPSTREAM}"
    chmod 444 /etc/resolv.conf
}

function __net-dnsmasq_disable {
    log_debug "Disabling ${DMNNAME}..."
    pidof dnsmasq | xargs kill -9 2>/dev/null
    echo "nameserver ${DNS_UPSTREAM}"|tee /etc/resolv.conf
    return 0
}

function __net-dnsmasq_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check global variable
    [[ -z ${RUN_NET_DNSMASQ} ]] && \
        log_error "RUN_NET_DNSMASQ variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_DNSMASQ} != 1 ]] && \
        log_error "RUN_NET_DNSMASQ is not enabled." && __net-dnsmasq_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package dnsmasq
    [[ $(dpkg -l|awk '{print $2}'|grep -c "dnsmasq") -lt 1 ]] && \
        log_info "dnsmasq is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof dnsmasq) -gt 0 ]] && \
        log_info "dnsmasq is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-dnsmasq_run {
    log_debug "Running ${DMNNAME}..."
    # add iptables rules
    # __bp_trim_whitespace JB_WANINF "${JB_WANINF}"
    # __bp_trim_whitespace JB_LANINF "${JB_LANINF}"
    # __bp_trim_whitespace JB_WLANINF "${JB_WLANINF}"

    # DNSMASQ_DENY_DHCP_WAN
    if [[ -n ${JB_WANINF} ]]; then # RUN_NET_IPTABLES=1
        if [[ $(< /sys/class/net/${JB_WANINF}/operstate) = *"up"* ]]; then
            log_debug "dnsmasq deny dhcp service for WAN"
            iptables -S | grep "DMQ_DW1_${JB_WANINF}" || \
                iptables -t filter -I INPUT -i ${JB_WANINF} -p udp --dport 67 --sport 68 -m comment --comment DMQ_DW1_${JB_WANINF} -j DROP
        fi
    fi

    # DNSMASQ_DHCPB DNSMASQ_DNSR
    if [[ -n ${JB_LANINF} ]]; then
        if [[ $(< /sys/class/net/${JB_LANINF}/operstate) = *"up"* ]]; then
            log_debug "dnsmasq accept dhcp for LAN"
            iptables -S | grep "DMQ_DLA_${JB_LANINF}" || \
                iptables -t filter -I INPUT -i ${JB_LANINF} -p udp --dport 67 --sport 68 -m comment --comment DMQ_DLA_${JB_LANINF} -j ACCEPT
            iptables -S | grep "DMQ_DLB_${JB_LANINF}" || \
                iptables -t filter -I INPUT -i ${JB_LANINF} -p udp --dport 68 --sport 67 -m comment --comment DMQ_DLB_${JB_LANINF} -j ACCEPT
            iptables -S | grep "DMQ_DLR_${JB_LANINF}" || \
                iptables -t filter -I INPUT -i ${JB_LANINF} -p udp --dport 53 -m comment --comment DMQ_DLR_${JB_LANINF} -j ACCEPT
        fi
    fi
    if [[ -n ${JB_WLANINF} ]]; then
        if [[ $(< /sys/class/net/${JB_WLANINF}/operstate) = *"up"*  ]]; then
            log_debug "dnsmasq accept dhcp for WLAN"
            iptables -S | grep "DMQ_DWLA_${JB_WLANINF}" || \
                iptables -t filter -I INPUT -i ${JB_WLANINF} -p udp --dport 67 --sport 68 -m comment --comment DMQ_DWLA_${JB_WLANINF} -j ACCEPT
            iptables -S | grep "DMQ_DWLB_${JB_WLANINF}" || \
                iptables -t filter -I INPUT -i ${JB_WLANINF} -p udp --dport 68 --sport 67 -m comment --comment DMQ_DWLB_${JB_WLANINF} -j ACCEPT
            iptables -S | grep "DMQ_DWLR_${JB_WLANINF}" || \
                iptables -t filter -A INPUT -i ${JB_WLANINF} -p udp --dport 53 -m comment --comment DMQ_DWLR_${JB_WLANINF} -j ACCEPT
        fi
    fi
    # Additional Listening for Masqueraded Interface
    if [[ ${RUN_NET_IPTABLES} -gt 0 && -n ${IPTABLES_MASQ} && -z ${IPTABLES_OVERRIDE} ]]; then # RUN_NET_IPTABLES=1 IPTABLES_MASQ="WLAN2WAN"
        log_debug "dnsmasq accept dhcp for MASQ"
        IFS=$'|' read -d "" -ra MASQROUTES <<< "${IPTABLES_MASQ}" # split
        for((j=0;j<${#MASQROUTES[@]};j++)){
            TARINF=""
            IFS=$'<' read -d "" -ra MASQINFS <<< "${MASQROUTES[j]}"
            if [[ $(_trim_string "${MASQINFS[0]}") = "LAN0" && $(_trim_string "${MASQINFS[1]}") = "WAN" && -n ${JB_LAN0INF} ]]; then
                TARINF=${JB_LAN0INF}
            elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN1" && $(_trim_string "${MASQINFS[1]}") = "WAN" && -n ${JB_LAN1INF} ]]; then
                TARINF=${JB_LAN1INF}
            elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN2" && $(_trim_string "${MASQINFS[1]}") = "WAN" && -n ${JB_LAN2INF} ]]; then
                TARINF=${JB_LAN2INF}
            elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN3" && $(_trim_string "${MASQINFS[1]}") = "WAN" && -n ${JB_LAN3INF} ]]; then
                TARINF=${JB_LAN3INF}
            elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN4" && $(_trim_string "${MASQINFS[1]}") = "WAN" && -n ${JB_LAN4INF} ]]; then
                TARINF=${JB_LAN4INF}
            elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN5" && $(_trim_string "${MASQINFS[1]}") = "WAN" && -n ${JB_LAN5INF} ]]; then
                TARINF=${JB_LAN5INF}
            elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN6" && $(_trim_string "${MASQINFS[1]}") = "WAN" && -n ${JB_LAN6INF} ]]; then
                TARINF=${JB_LAN6INF}
            elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN7" && $(_trim_string "${MASQINFS[1]}") = "WAN" && -n ${JB_LAN7INF} ]]; then
                TARINF=${JB_LAN7INF}
            elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN8" && $(_trim_string "${MASQINFS[1]}") = "WAN" && -n ${JB_LAN8INF} ]]; then
                TARINF=${JB_LAN8INF}
            elif [[ $(_trim_string "${MASQINFS[0]}") = "LAN9" && $(_trim_string "${MASQINFS[1]}") = "WAN" && -n ${JB_LAN9INF} ]]; then
                TARINF=${JB_LAN9INF}
            else
                continue
            fi
            iptables -S | grep "DMQ_DA_${TARINF}" || \
                iptables -t filter -I INPUT -i ${TARINF} -p udp --dport 67 --sport 68 -m comment --comment DMQ_DA_${TARINF} -j ACCEPT
            iptables -S | grep "DMQ_DB_${TARINF}" || \
                iptables -t filter -I INPUT -i ${TARINF} -p udp --dport 68 --sport 67 -m comment --comment DMQ_DB_${TARINF} -j ACCEPT
            iptables -S | grep "DMQ_DR_${TARINF}" || \
                iptables -t filter -A INPUT -i ${TARINF} -p udp --dport 53 -m comment --comment DMQ_DR_${TARINF} -j ACCEPT
        }
    fi
    
    __net-dnsmasq_update_blacklist
    # __net-dnsmasq_generate_config

    pidof dnsmasq | xargs kill -9 2>/dev/null
    dnsmasq -d --conf-file=/etc/dnsmasq/dnsmasq.conf 1>>/var/log/dnsmasq.log 2>&1 &
    
    echo "nameserver 127.0.0.1"|tee /etc/resolv.conf
    chmod 444 /etc/resolv.conf

    _time_sync "${DNS_UPSTREAM}"

    pidof dnsmasq && return 0 || \
        log_error "dnsmasq failed to run." && return 0
}

complete -F _blank net-dnsmasq