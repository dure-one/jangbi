# shellcheck shell=bash
cite about-plugin
about-plugin 'dnsmasq install configurations.'
#VAR RUN_IPTABLES

function net-dnsmasq {
	about 'dnsmasq install configurations'
	group 'net'
    param '1: command'
    param '2: params'
    example '$ net-dnsmasq check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
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
	else
		__net-dnsmasq_help
	fi
}

function __net-dnsmasq_help {
	echo -e "Usage: net-dnsmasq [COMMAND] [profile]\n"
	echo -e "Helper to dnsmasq install configurations.\n"
	echo -e "Commands:\n"
	echo "   help      Show this help message"
	echo "   install   Install os firmware"
	echo "   uninstall Uninstall installed firmware"
	echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __net-dnsmasq_install { # RUN_DNSMASQ
    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install net-dnsmasq.."
    local no_dhcpv6_infs=
    # mode
    # 1. gateway lan->wan, wlan->wan
    # 2. client local->wan
    # 3. wastunnel local->wan
    local additional_listenaddr= additional_netinf= additional_dhcprange=
    local netinf= netip= netminip= netmaxip=
    if [[ ${DURE_ROLE} = 'gateway' ]]; then
        # ** fix this to working on LAN & WLAN interface together **
        if [[ ! -z ${DURE_LANINF} ]]; then
            netinf=${DURE_LANINF}
            netip=$(ipcalc-ng ${DURE_LAN}|grep Address:|cut -f2)
            netminip=$(ipcalc-ng ${DURE_LAN}|grep HostMin:|cut -f2)
            netmaxip=$(ipcalc-ng ${DURE_LAN}|grep HostMax:|cut -f2)
            [[ ${DISABLE_IPV6} -gt 0 ]] && no_dhcpv6_infs="${no_dhcpv6_infs}no-dhcpv6-interface=${DURE_LANINF}\n"
        elif [[ ! -z ${DURE_WLANINF} ]]; then
            netinf=${DURE_WLANINF}
            netip=$(ipcalc-ng ${DURE_WLAN}|grep Address:|cut -f2)
            netminip=$(ipcalc-ng ${DURE_WLAN}|grep HostMin:|cut -f2)
            netmaxip=$(ipcalc-ng ${DURE_WLAN}|grep HostMax:|cut -f2)
            # ip link set ${DURE_WLANINF} up
            # ip addr add ${DURE_WLAN} dev ${DURE_WLANINF}
            [[ ${DISABLE_IPV6} -gt 0 ]] && no_dhcpv6_infs="${no_dhcpv6_infs}no-dhcpv6-interface=${DURE_WLANINF}\n"
        else
            netinf="lo"
            netip="127.0.0.1"
            netminip="127.0.0.1"
            netmaxip="127.0.0.1"
        fi
        # Additional Listening for Masqueraded Interface
        if [[ ${RUN_IPTABLES} -gt 0 && ! -z ${IPTABLES_MASQ} && -z ${IPTABLES_OVERRIDE} ]]; then # RUN_IPTABLES=1 IPTABLES_MASQ="WLAN2WAN"
            local additional_listenaddr= additional_netinf= additional_dhcprange=
            IFS=$'|' read -d "" -ra MASQROUTES <<< "${IPTABLES_MASQ}" # split
            for((j=0;j<${#MASQROUTES[@]};j++)){
                local lanxinf= lanxip= lanxminip= lanxmaxip=
                IFS=$'<' read -d "" -ra MASQINFS <<< "${MASQROUTES[j]}"
                if [[ $(_trim_string ${MASQINFS[0]}) = "LAN0" && $(_trim_string ${MASQINFS[1]}) = "WAN" ]]; then
                    lanxinf=${DURE_LAN0INF}
                    lanxipNET=${DURE_LAN0}
                elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN1" && $(_trim_string ${MASQINFS[1]}) = "WAN" ]]; then
                    lanxinf=${DURE_LAN1INF}
                    lanxipNET=${DURE_LAN1}
                elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN2" && $(_trim_string ${MASQINFS[1]}) = "WAN" ]]; then
                    lanxinf=${DURE_LAN2INF}
                    lanxipNET=${DURE_LAN2}
                elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN3" && $(_trim_string ${MASQINFS[1]}) = "WAN" ]]; then
                    lanxinf=${DURE_LAN3INF}
                    lanxipNET=${DURE_LAN3}
                elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN4" && $(_trim_string ${MASQINFS[1]}) = "WAN" ]]; then
                    lanxinf=${DURE_LAN4INF}
                    lanxipNET=${DURE_LAN4}
                elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN5" && $(_trim_string ${MASQINFS[1]}) = "WAN" ]]; then
                    lanxinf=${DURE_LAN5INF}
                    lanxipNET=${DURE_LAN5}
                elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN6" && $(_trim_string ${MASQINFS[1]}) = "WAN" ]]; then
                    lanxinf=${DURE_LAN6INF}
                    lanxipNET=${DURE_LAN6}
                elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN7" && $(_trim_string ${MASQINFS[1]}) = "WAN" ]]; then
                    lanxinf=${DURE_LAN7INF}
                    lanxipNET=${DURE_LAN7}
                elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN8" && $(_trim_string ${MASQINFS[1]}) = "WAN" ]]; then
                    lanxinf=${DURE_LAN8INF}
                    lanxipNET=${DURE_LAN8}
                elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN9" && $(_trim_string ${MASQINFS[1]}) = "WAN" ]]; then
                    lanxinf=${DURE_LAN9INF}
                    lanxipNET=${DURE_LAN9}
                else
                    continue
                fi
                lanxip=$(ipcalc-ng ${lanxipNET}|grep Address:|cut -f2)
                lanxminip=$(ipcalc-ng ${lanxipNET}|grep HostMin:|cut -f2)
                lanxmaxip=$(ipcalc-ng ${lanxipNET}|grep HostMax:|cut -f2)
                additional_listenaddr="${additional_listenaddr}listen-address=${lanxip}\n"
                additional_netinf="${additional_netinf}interface=${lanxinf}\n"
                additional_dhcprange="${additional_dhcprange}dhcp-range=interface:${lanxinf},${lanxminip},${lanxmaxip},12h\n"
                [[ ${DISABLE_IPV6} -gt 0 ]] && no_dhcpv6_infs="${no_dhcpv6_infs}no-dhcpv6-interface=${lanxinf}\n"
            }
        fi
    else # local->wan
        netinf="lo"
        netip="127.0.0.1"
        netminip="127.0.0.1"
        netmaxip="127.0.0.1"
    fi
    apt install -yq dnsmasq-base
    mkdir -p /etc/dnsmasq.d
    cp -rf ./configs/dnsmasq.conf.default /etc/dnsmasq.d/
    cp -rf ./configs/trust-anchors.conf /etc/dnsmasq.d/
    tee /etc/dnsmasq.d/dnsmasq.conf > /dev/null <<EOT
# ${DURE_ROLE}
domain-needed
bogus-priv
dnssec
dnssec-check-unsigned
filterwin2k
strict-order
no-resolv
no-poll
conf-file=/etc/dnsmasq.d/trust-anchors.conf
server=${DNS_UPSTREAM}
listen-address=${netip}
$(printf ${additional_listenaddr})
interface=${netinf}
$(printf ${additional_netinf})
bind-interfaces
$(printf ${no_dhcpv6_infs})
no-hosts
dhcp-range=interface:${netinf},${netminip},${netmaxip},12h
$(printf ${additional_dhcprange})
dhcp-leasefile=/var/lib/misc/dnsmasq.leases
cache-size=1000
no-negcache
conf-dir=/etc/dnsmasq.d/,*.conf
local-service
dns-loop-detect
log-queries
log-dhcp
EOT
}

function __net-dnsmasq_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall net-dnsmasq.."
    echo $(pidof dnsmasq) | xargs kill -9 2>/dev/null
    echo "nameserver ${DNS_UPSTREAM}"|tee /etc/resolv.conf
    _time_sync ${DNS_UPSTREAM}
    chmod 444 /etc/resolv.conf
}

function __net-dnsmasq_check { # return 0 can install, return 1 can't install, return 2 installed
    local return_code=0
    log_debug "Starting net-dnsmasq Check"
    # check variable exists
    [[ -z ${RUN_DNSMASQ} ]] && echo "ERROR: RUN_DNSMASQ variable is not set." && return 1
    # check pkg installed
    [[ $(dpkg -l|grep dnsmasq|wc -l) -lt 1 ]] && echo "ERROR: dnsmasq is not installed." && return 0
    # check dnsmasq started
    [[ $(pidof dnsmasq|wc -l) -gt 1 ]] && echo "INFO: dnsmasq is started." && return_code=2

    return 0
}

function __net-dnsmasq_run {
    # do on everyboot

    # add iptables rules
    # DNSMASQ_DENY_DHCP_WAN
    if [[ ${RUN_IPTABLES} -gt 0 && ! -z ${DURE_WANINF} ]]; then # RUN_IPTABLES=1
        IPTABLE="INPUT -i ${DURE_WANINF} -p udp --dport 67 --sport 68 -m comment --comment DNSMASQ_DENY_DHCP1_${DURE_WANINF} -j DROP"
        iptables -S | grep "DNSMASQ_DENY_DHCP1_${DURE_WANINF}" || iptables -I ${IPTABLE}
        IPTABLE="OUTPUT -i ${DURE_WANINF} -p udp --dport 68 --sport 67 -m comment --comment DNSMASQ_DENY_DHCP2_${DURE_WANINF} -j DROP"
        iptables -S | grep "DNSMASQ_DENY_DHCP2_${DURE_WANINF}" || iptables -I ${IPTABLE}
    fi

    # DNSMASQ_DHCPB DNSMASQ_DNSR
    if [[ ! -z ${DURE_LANINF} ]]; then
        IPTABLE="INPUT -i ${DURE_LANINF} -p udp --dport 67 --sport 68 -m comment --comment DNSMASQ_DHCPA_${DURE_LANINF} -j ACCEPT"
        iptables -S | grep "DNSMASQ_DHCPA_${DURE_LANINF}" || iptables -I ${IPTABLE}
        IPTABLE="INPUT -i ${DURE_LANINF} -p udp --dport 68 --sport 67 -m comment --comment DNSMASQ_DHCPB_${DURE_LANINF} -j ACCEPT"
        iptables -S | grep "DNSMASQ_DHCPB_${DURE_LANINF}" || iptables -I ${IPTABLE}
        IPTABLE="INPUT -i ${DURE_LANINF} -p udp --dport 53 -m comment --comment DNSMASQ_DNSR_${DURE_LANINF} -j ACCEPT"
        iptables -S | grep "DNSMASQ_DNSR_${DURE_LANINF}" || iptables -A ${IPTABLE}
    fi
    if [[ ! -z ${DURE_WLANINF} ]]; then
        IPTABLE="INPUT -i ${DURE_WLANINF} -p udp --dport 67 --sport 68 -m comment --comment DNSMASQ_DHCPA_${DURE_WLANINF} -j ACCEPT"
        iptables -S | grep "DNSMASQ_DHCPA_${DURE_WLANINF}" || iptables -I ${IPTABLE}
        IPTABLE="INPUT -i ${DURE_WLANINF} -p udp --dport 68 --sport 67 -m comment --comment DNSMASQ_DHCPB_${DURE_WLANINF} -j ACCEPT"
        iptables -S | grep "DNSMASQ_DHCPB_${DURE_WLANINF}" || iptables -I ${IPTABLE}
        IPTABLE="INPUT -i ${DURE_WLANINF} -p udp --dport 53 -m comment --comment DNSMASQ_DNSR_${DURE_WLANINF} -j ACCEPT"
        iptables -S | grep "DNSMASQ_DNSR_${DURE_WLANINF}" || iptables -A ${IPTABLE}
    fi

    # Additional Listening for Masqueraded Interface
    if [[ ${RUN_IPTABLES} -gt 0 && ! -z ${IPTABLES_MASQ} && -z ${IPTABLES_OVERRIDE} ]]; then # RUN_IPTABLES=1 IPTABLES_MASQ="WLAN2WAN"
        IFS=$'|' read -d "" -ra MASQROUTES <<< "${IPTABLES_MASQ}" # split
        for((j=0;j<${#MASQROUTES[@]};j++)){
        TARINF=""
        IFS=$'<' read -d "" -ra MASQINFS <<< "${MASQROUTES[j]}"
        if [[ $(_trim_string ${MASQINFS[0]}) = "LAN0" && $(_trim_string ${MASQINFS[1]}) = "WAN" && ! -z ${DURE_LAN0INF} ]]; then
            TARINF=${DURE_LAN0INF}
        elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN1" && $(_trim_string ${MASQINFS[1]}) = "WAN" && ! -z ${DURE_LAN1INF} ]]; then
            TARINF=${DURE_LAN1INF}
        elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN2" && $(_trim_string ${MASQINFS[1]}) = "WAN" && ! -z ${DURE_LAN2INF} ]]; then
            TARINF=${DURE_LAN2INF}
        elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN3" && $(_trim_string ${MASQINFS[1]}) = "WAN" && ! -z ${DURE_LAN3INF} ]]; then
            TARINF=${DURE_LAN3INF}
        elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN4" && $(_trim_string ${MASQINFS[1]}) = "WAN" && ! -z ${DURE_LAN4INF} ]]; then
            TARINF=${DURE_LAN4INF}
        elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN5" && $(_trim_string ${MASQINFS[1]}) = "WAN" && ! -z ${DURE_LAN5INF} ]]; then
            TARINF=${DURE_LAN5INF}
        elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN6" && $(_trim_string ${MASQINFS[1]}) = "WAN" && ! -z ${DURE_LAN6INF} ]]; then
            TARINF=${DURE_LAN6INF}
        elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN7" && $(_trim_string ${MASQINFS[1]}) = "WAN" && ! -z ${DURE_LAN7INF} ]]; then
            TARINF=${DURE_LAN7INF}
        elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN8" && $(_trim_string ${MASQINFS[1]}) = "WAN" && ! -z ${DURE_LAN8INF} ]]; then
            TARINF=${DURE_LAN8INF}
        elif [[ $(_trim_string ${MASQINFS[0]}) = "LAN9" && $(_trim_string ${MASQINFS[1]}) = "WAN" && ! -z ${DURE_LAN9INF} ]]; then
            TARINF=${DURE_LAN9INF}
        else
            continue
        fi
        IPTABLE="INPUT -i ${TARINF} -p udp --dport 67 --sport 68 -m comment --comment DNSMASQ_DHCPA_${TARINF} -j ACCEPT"
        iptables -S | grep "DNSMASQ_DHCPA_${TARINF}" || iptables -I ${IPTABLE}
        IPTABLE="INPUT -i ${TARINF} -p udp --dport 68 --sport 67 -m comment --comment DNSMASQ_DHCPB_${TARINF} -j ACCEPT"
        iptables -S | grep "DNSMASQ_DHCPB_${TARINF}" || iptables -I ${IPTABLE}
        IPTABLE="INPUT -i ${TARINF} -p udp --dport 53 -m comment --comment DNSMASQ_DNSR_${TARINF} -j ACCEPT"
        echo "${IPTABLE}"
        iptables -S | grep "DNSMASQ_DNSR_${TARINF}" || iptables -A ${IPTABLE}
        }
    fi
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        # download blacklist files
        IFS=$'|' read -d "" -ra urls <<< "${DNSMASQ_BLACKLIST_URLS}" # split
        for((j=0;j<${#urls[@]};j++)){
            echo "# ${urls[j]}" > /etc/dnsmasq.d/malware$j.conf
            wget -O- ${urls[j]} | awk '$1 == "0.0.0.0" { print "address=/"$2"/0.0.0.0/"}' >> /etc/dnsmasq.d/malware$j.conf
        }
    fi
    echo $(pidof dnsmasq) | xargs kill -9 2>/dev/null
    dnsmasq -d --conf-file=/etc/dnsmasq.d/dnsmasq.conf &>/var/log/dnsmasq.log &

    echo "nameserver ${DNS_UPSTREAM}"|tee /etc/resolv.conf
    _time_sync ${DNS_UPSTREAM}
    chmod 444 /etc/resolv.conf

	return 0
}

complete -F __net-dnsmasq_run net-dnsmasq