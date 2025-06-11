# shellcheck shell=bash
cite about-plugin
about-plugin 'iptables install configurations.'
# C : OSLOCAL_SETTING, DURE_SWAPSIZE, DURE_DEPLOY_PATH

# filter(INPUT FORWARD OUTPUT .ICMPFLOOD .SSHBRUTE)
# nat(PREROUTING INPUT OUTPUT POSTROUTING)
# mangle(PREROUTING INPUT FORWARD OUTPUT POSTROUTING)
# raw(PREROUTING OUTPUT)
# security(INPUT FORWARD OUTPUT)

# https://ipset.netfilter.org/iptables-extensions.man.html#lbAP
# https://gist.github.com/egernst/2c39c6125d916f8caa0a9d3bf421767a
# https://andrewpage.tistory.com/38
# https://postfiles.pstatic.net/MjAxOTExMjZfMjA1/MDAxNTc0NzI0NDk2OTQ1.MBOrliBXqYltD27U5rpO9EqEKEOh2_ERcGvTDf7c3gQg.XlVAiDi6coPTftr1C7RbvBQkIrEYd4x2d-N7spdrKf4g.PNG.firstpw/2.png?type=w3840
# https://www.frozentux.net/iptables-tutorial/iptables-tutorial.html#RETURNTARGET
# https://ipset.netfilter.org/ipset.man.html
# iptables order2
#                                    netfilter hooks
#
#                                   +-----------> local +-----------+
#                                   |             process           |
#                                   |                               |
#                                   |                               |
#                                   |                               |
#                                   |                               v
#   MANGLE            +-------------+--------+
#   FILTER            |                      |               +----------------------+    RAW
#   SECURITY          |        input         |               |                      |    conntrack
#   SNAT              |                      |               |     output           |    MANGLE
#                     +------+---------------+               |                      |    DNAT
#                            ^                               +-------+--------------+    routing
#                            |                                       |                   FILTER
#                            |                                       |                   SECURITY
#                            |            +---------------------+    |         +-------------+
#      +-----------+                      |                     |    +-------> |             |
# +--> |pre routing+----  route    -----> |      forward        |              |post routing +---->
#      |           |      lookup          |                     +------------> |             |
#      +-----------+                      +---------------------+              +-------------+
#
#      RAW                                       MANGLE                         MANGLE
#      conntrack                                 FILTER                         SNAT
#      MANGLE                                    SECURITY
#      DNAT
#      routing

# bridge filters(ebtables)
#                                                       +-----------> local +-----------+
#                                                       |                               |
#                                                       |                               |
#                                                       |                               |
#                                                       |                               |
#                                                       |                               v
#                                         +-------------+--------+
#                                         |                      |               +----------------------+
#                                         |        input         |               |                      |
#                                         |                      |               |     output           |
#                                         +------+---------------+               |                      |
#                                                ^                               +-------+--------------+
#                                                |                                       |
#                                                |                                       |
#                                                |            +---------------------+    |         +-------------+
#  ---------------         +-----------+                      |                     |    +-------> |             |
#   |  brouting   |    --> |pre routing+----  route    -----> |      forward        |              |post routing +---->
#   |             |        |           |      lookup          |                     +------------> |             |
#   --------------         +-----------+                      +---------------------+              +-------------+

function net-iptables {
	about 'iptables install configurations'
	group 'net'
    param '1: command'
    param '2: params'
    example '$ net-iptables check/install/uninstall/run/build'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

	if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
		__net-iptables_install "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
		__net-iptables_uninstall "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
		__net-iptables_check "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
		__net-iptables_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "build" ]]; then
		__net-iptables_build "$2"
#    elif [[ $# -eq 1 ]] && [[ "$1" = "backup" ]]; then
#		__net-iptables_backup "$2"
#    elif [[ $# -eq 1 ]] && [[ "$1" = "restore" ]]; then
#		__net-iptables_apply "$2"
	else
		__net-iptables_help
	fi
}

function __net-iptables_help {
	echo -e "Usage: net-iptables [COMMAND] [profile]\n"
	echo -e "Helper to iptables install configurations.\n"
	echo -e "Commands:\n"
	echo "   help                       Show this help message"
	echo "   install 1 nft_rules        Install os iptables ex) install $ipv6enabled $nft_rules"
	echo "   uninstall                  Uninstall installed iptables"
	echo "   check                      Check vars available"
    echo "   run                        do task at bootup"
    echo "   build                      rebuild iptables by configs"
#    echo "   backup                     backup current iptables to /etc/nftables"
#    echo "   apply                    restore nftables from /etc/nftables"
}

function __net-iptables_install {
    log_debug "Trying to install net-iptables."
    local nftables_override="$1" # $NFTABLES_OVERRIDE
    local disable_ipv6="$2"

    export DEBIAN_FRONTEND=noninteractive
    apt install -yq nftables iptables xtables-addons-common
    apt install -yq ./pkgs/arptables*.deb
    systemctl enable nftables
    mkdir -p /etc/iptables

    cp -rf ./configs/rules-both.iptables /etc/iptables/rules-both.iptables
    cp -rf ./configs/rules-ipv4.iptables /etc/iptables/rules-ipv4.iptables
    cp -rf ./configs/rules-ipv6.ip6tables /etc/iptables/rules-ipv6.ip6tables

    systemctl stop nftables
    echo ""> /etc/nftables.conf
    systemctl start nftables
    systemctl stop nftables

    if [[ ! -z ${nftables_override} ]]; then # NFTABLES_OVERRIDE ON
        echo "${nftables_override}" > /tmp/nftables.tmp.conf
        if ! nft -c -f /tmp/nftables.tmp.conf; then # on error
            echo "ERROR: \$NFTABLES_OVERRIDE has error."
            exit 1
        else # on success
            nft -f /tmp/nftables.tmp.conf
        fi
    else # NFTABLES_OVERRIDE OFF
        if [[ ${disable_ipv6} -gt 0 ]]; then # disable ipv6
            iptables-restore /etc/iptables/rules-ipv4.iptables
            ip6tables -I FORWARD -j DROP && ip6tables -I OUTPUT -j DROP && ip6tables -I INPUT -j DROP
        else # enable ipv6
            iptables-restore /etc/iptables/rules-both.iptables
        fi
    fi
}

function __net-iptables_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall net-iptables."
    systemctl stop nftables
    systemctl disable nftables
}

function __net-iptables_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-iptables Check"

    [[ $(which ipcalc-ng|wc -l) -lt 1 ]] && \
        log_info "ipcacl-ng command does not exist. please install it." && [[ $running_status -lt 10 ]] && running_status=10

    [[ ${DISABLE_SYSTEMD} -lt 1 ]] && \
        log_info "DISABLE_SYSTEMD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10

    [[ $(dpkg -l|grep iptables|wc -l) -lt 1 ]] && \
        log_info "iptables is not installed." && [[ $running_status -lt 5 ]] && running_status=5

    [[ $(systemctl status nftables|grep Active|grep running) -gt 0 ]] && \
        log_info "nftables is started." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-iptables_run {
    #[[ ! -d /etc/nftables ]] && __net-iptables_build && __net-iptables_backup
    #__net-iptables_apply
    __net-iptables_build
    systemctl start nftables
	return 0
}

#function __net-iptables_backup {
#    local arp=$(nft list ruleset arp)
#    local ip=$(nft list ruleset ip)
#    local iplegacy=$(iptables-nft-save|wc -l)
#    local ip6=$(nft list ruleset ip6)
#    local ip6legacy=$(ip6tables-nft-save|wc -l)
#    local bridge=$(nft list ruleset bridge)
#    local inet=$(nft list ruleset inet)
#    mkdir -p /etc/nftables
#    [[ ${#arp[@]} -gt 0 ]] && nft list ruleset arp > /etc/nftables/arp.nft
#    [[ ${#ip[@]} -gt 0 ]] && nft list ruleset ip > /etc/nftables/ip.nft
#    [[ ${iplegacy} -gt 0 ]] && iptables-legacy-save > /etc/nftables/iplegacy.iptables
#    [[ ${#ip6[@]} -gt 0 ]] && nft list ruleset ip6 > /etc/nftables/ip6.nft
#    [[ ${ip6legacy} -gt 0 ]] && ip6tables-legacy-save > /etc/nftables/ip6legacy.iptables
#    [[ ${#bridge[@]} -gt 0 ]] && nft list ruleset bridge > /etc/nftables/bridge.nft
#    [[ ${#inet[@]} -gt 0 ]] && nft list ruleset inet > /etc/nftables/inet.nft
#
#	return 0
#}
#
#function __net-iptables_apply {
#    nft flush ruleset
#    nft -f /etc/nftables/arp.nft
#    nft -f /etc/nftables/ip.nft &>/dev/null
#    iptables-legacy-restore /etc/nftables/iplegacy.iptables
#    nft -f /etc/nftables/ip6.nft &>/dev/null
#    ip6tables-legacy-restore /etc/nftables/ip6legacy.iptables
#    nft -f /etc/nftables/bridge.nft
#    nft -f /etc/nftables/inet.nft
#
#	return 0
#}

function __net-iptables_build {
    # read config apply
    # EMPTY RULES
    nft flush ruleset

    #
    # ARP RULES
    #
    # WAN_INF WHITELISTED_MACADDRESSES
    [[ ${#WHITELISTED_MACADDRESSES[@]} -gt 0 ]] && __net-iptables_mangle_all_both_macwhitelist # targetinf macaddrs
    # IPTABLES_GWMACONLY
    [[ ${IPTABLES_GWMACONLY} -gt 0 ]] && __net-iptables_mangle_ext_both_gwmaconly

    #
    # NET RULES
    #
    # IPTABLES_CONNLIMIT_PER_IP
    [[ ${IPTABLES_CONNLIMIT_PER_IP} -gt 0 ]] && __net-iptables_mangle_all_both_conlimitperip "${IPTABLES_CONNLIMIT_PER_IP}" # conlimitperip:null
    # IPTABLES_DROP_ICMP
    [[ ${IPTABLES_DROP_ICMP} -gt 0 ]] && __net-iptables_mangle_all_both_dropicmp
    # IPTABLES_DROP_INVALID_STATE
    [[ ${IPTABLES_DROP_INVALID_STATE} -gt 0 ]]  && __net-iptables_mangle_all_both_dropinvalidstate
    # IPTABLES_DROP_NON_SYN
    [[ ${IPTABLES_DROP_NON_SYN} -gt 0 ]] && __net-iptables_mangle_all_both_dropnonsyn
    # IPTABLES_DROP_SPOOFING=1
    [[ ${IPTABLES_DROP_SPOOFING} -gt 0 ]] && __net-iptables_mangle_all_both_dropspoofing  "${DURE_WANINF}"# tarinf:null
    # IPTABLES_LIMIT_MSS
    [[ ${IPTABLES_LIMIT_MSS} -gt 0 ]] && __net-iptables_mangle_all_both_limitmss
    # IPTABLES_GUARD_OVERLOAD
    [[ ${IPTABLES_GUARD_OVERLOAD} -gt 0 ]] && __net-iptables_raw_all_both_limitudppps
    # IPTABLES_INVALID_TCPFLAG
    [[ ${IPTABLES_INVALID_TCPFLAG} -gt 0 ]] && __net-iptables_raw_all_both_dropinvtcpflag
    # IPTABLES_GUARD_PORT_SCANNER
    [[ ${IPTABLES_GUARD_PORT_SCANNER} -gt 0 ]] && __net-iptables_raw_all_both_portscanner
    # IPTABLES_BLACK_NAMELIST
    [[ ${#IPTABLES_BLACK_NAMELIST[@]} -gt 0 ]] && __net-iptables_filter_all_both_ipblacklist "${IPTABLES_BLACK_NAMELIST}" # blockurls

    #
    # HOST RULES
    #
    # GET VARs
    local waninf=${DURE_WANINF}
    local laninf=${DURE_laninf}
    local wlaninf=${DURE_wlaninf}

    # PORT FORWARDING WAN->LAN
    # IPTABLES_PORTFORWARD="8090:192.168.0.1:8090|8010:192.168.0.1:8010"
    if [[ ${IPTABLES_PORTFORWARD} -gt 0 ]]; then
        IFS=$'|' read -d "" -ra forwardsinfo <<< "${IPTABLES_PORTFORWARD}" # split
        for((j=0;j<${#forwardsinfo[@]};j++)){
            IFS=$':' read -d "" -ra forwardinfo <<< "${forwardsinfo[j]}" # split
            if [[ ${#forwardinfo[@]} -eq 3 ]]; then
                local wanport=${forwardinfo[0]}
                local lanip=${forwardinfo[1]}
                local lanport=${forwardinfo[2]}
                __net-iptables_nat_ext_both_portforward "${}" "${wanport}" "${lanip}" "${lanport}"# waninf wanport lanip lanport
            fi
        }
    fi
    # DMZ SETTINGS WAN->HOST
    # IPTABLES_DMZ="192.168.0.1" IPTABLES_SUPERDMZ=1
    [[ ${IPTABLES_DMZ} -gt 0 ]] && __net-iptables_nat_ext_both_dmzsdmz # waninf laninf dmzip sdmz

    # MASQUERADE WAN->NET
    # IPTABLES_MASQ="LAN<WAN|LAN1<WAN"
    if [[ ! -z ${IPTABLES_MASQ} ]]; then # RUN_IPTABLES=1 IPTABLES_MASQ="WLAN2WAN"
        IFS=$'|' read -d "" -ra MASQROUTES <<< "${IPTABLES_MASQ}" # split
        for((j=0;j<${#MASQROUTES[@]};j++)){
            local frominf="" toinf="" fromnet="" tonet=""
            IFS=$'<' read -d "" -ra masqinfs <<< "${MASQROUTES[j]}"
            if [[ $(_trim_string ${masqinfs[0]}) = "LAN" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${laninf}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_LAN}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "WLAN" && $(_trim_string ${masqinfs[1]}) = "WAN"  ]]; then
                frominf=${wlaninf}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_WLAN}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN0" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${DURE_LAN0INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_LAN0}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN1" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${DURE_LAN1INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_LAN1}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN2" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${DURE_LAN2INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_LAN2}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN3" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${DURE_LAN3INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_LAN3}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN4" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${DURE_LAN4INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_LAN4}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN5" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${DURE_LAN5INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_LAN5}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN6" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${DURE_LAN6INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_LAN6}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN7" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${DURE_LAN7INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_LAN7}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN8" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${DURE_LAN8INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_LAN8}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN9" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${DURE_LAN9INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${DURE_LAN9}|grep Network:|cut -f2)
            fi

            if [[ ! -z ${frominf} && ! -z ${toinf} ]]; then
                __net-iptables_filternat_all_both_masquerade  "${frominf}" "${fromnet}" "${toinf}" # laninf lannet waninf
            fi
        }
    fi

    # IPTABLES_SNAT="LAN<WAN|LAN1<WAN"
    # [[ ${IPTABLES_SNAT} -gt 0 ]] && __net-iptables_filternat_all_both_snat # laninf lannet waninf wanip

	return 0
}

# MODES : Gateway, Wstunnel, Client
# TABLES : filter(IFO), nat(PIOP), mangle(IFP), raw(PO), security(IOF) https://gist.github.com/egernst/2c39c6125d916f8caa0a9d3bf421767a
# PREFIX : int/ext/all inc/oug/both contents

# Arptables : MAC Whitelisting
# WHITELISTED_MACADDRESSES?=aa:bb:cc:dd:ee|ab:cd:be:c0:a1
function __net-iptables_mangle_all_both_macwhitelist {
    local funcname="mangle_all_both_macwhitelist"
    local targetinf="$1"
    local macaddrs="$2"

    if [[ ${#macaddrs[@]} -gt 0 ]]; then
        IFS=$'|' read -d "" -ra MACADDR <<< "${macaddrs}" # split
        for((j=0;j<${#MACADDR[@]};j++)){
            arptables -A INPUT -i ${targetinf} --source-mac ${MACADDR[j]} -j ACCEPT
            arptables -A INPUT -i ${targetinf} --source-mac ${MACADDR[j]} -j ACCEPT
        }
        [[ $(arptables -S|grep "INPUT DROP"|wc -l) -lt 1 ]] && arptables -P INPUT DROP
    fi
}

# Arptables : Allow only from Gateway on wan
# IPTABLES_GWMACONLYIPTABLES_GWMACONLY=1
function __net-iptables_mangle_ext_both_gwmaconly {
    local funcname="mangle_ext_both_gwonly"
    local targetinf=$(route |grep default|awk '{print $8}') # net-tools
    local gwip=$(route |grep default|awk '{print $2}') # net-tools
    local gwmac=$(arp -a|grep ${gwip}|grep ${targetinf}|awk '{print $4}') # net-tools
    local macaddrs="$2"
    arptables -A INPUT -i ${targetinf} --source-mac ${gwmac} -j ACCEPT
    [[ $(arptables -S|grep "INPUT DROP"|wc -l) -lt 1 ]] && arptables -P INPUT DROP
}

# Mangle Prerouting : Ip Connection Limit per IP
# IPTABLES_CONNLIMIT_PER_IP=50
function __net-iptables_mangle_all_both_conlimitperip {
    local funcname="mangle_all_both_conlimitperip"
    local conlimitperip="$1"
    [[ -z $conlimitperip ]] && conlimitperip=50
    IPTABLE="PREROUTING -p tcp -m connlimit --connlimit-above ${conlimitperip} --connlimit-mask 32 -m comment --comment ${funcname} -j DROP"
    iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -A ${IPTABLE}
}

# Mangle Prerouting : Drop ICMP
# IPTABLES_DROP_ICMP=1
function __net-iptables_mangle_all_both_dropicmp {
    local funcname="mangle_all_both_dropicmp"

    IPTABLE="PREROUTING -p icmp -m comment --comment ${funcname} -j DROP"
    iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -A ${IPTABLE}
}

# Mangle Prerouting : Drop Invalid State
# IPTABLES_DROP_INVALID_STATE=1
function __net-iptables_mangle_all_both_dropinvalidstate {
    local funcname="mangle_all_both_dropinvalidstate"

    IPTABLE="PREROUTING -p all -m conntrack --ctstate INVALID -m comment --comment ${funcname} -j DROP"
    iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -I ${IPTABLE}
}

# Mangle Prerouting : Drop new non-SYN TCP Packets
# IPTABLES_DROP_NON_SYN=1
function __net-iptables_mangle_all_both_dropnonsyn {
    local funcname="mangle_all_both_dropnonsyn"

    IPTABLE="PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -m comment --comment ${funcname} -j DROP"
    iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -I ${IPTABLE}
}

# Mangle Prerouting : Drop Spoofing Packets
# IPTABLES_DROP_SPOOFING=1 TARINF?=eth0
function __net-iptables_mangle_all_both_dropspoofing {
    local funcname="mangle_all_both_dropspoofing"
    local tarinf="${1}"
    local BLOCKING_LIST="224.0.0.0/3|169.254.0.0/16|172.16.0.0/12|192.0.2.0/24|192.168.0.0/16|10.0.0.0/8|0.0.0.0/8|240.0.0.0/5|127.0.0.0/8"

    IFS=$'\n' read -d "" -ra routing_allow_list <<< "$(routel|grep /|grep -v 127.0.0.0/8|cut -d" " -f1)" # split
    IFS=$'|' read -d "" -ra routing_block_list <<< "${BLOCKING_LIST}" # split
    for((j=0;j<${#routing_block_list[@]};j++)){
        for((k=0;k<${#routing_allow_list[@]};k++)){
            ALMINIP=$(_ip2conv $(ipcalc-ng ${routing_allow_list[k]}|grep HostMin:|cut -f2))
            ALMAXIP=$(_ip2conv $(ipcalc-ng ${routing_allow_list[k]}|grep HostMax:|cut -f2))
            BLMINIP=$(_ip2conv $(ipcalc-ng ${routing_block_list[j]}|grep HostMin:|cut -f2))
            BLMAXIP=$(_ip2conv $(ipcalc-ng ${routing_block_list[j]}|grep HostMax:|cut -f2))
            if [[ ${ALMINIP} -gt ${BLMINIP} && ${ALMAXIP} -lt ${BLMAXIP} ]]; then
                IPTABLE="PREROUTING -s "${routing_allow_list[k]}" -m comment --comment ${funcname}_allow_${j}${k} -j ACCEPT"
                iptables -t mangle -S | grep "${funcname}_allow_${j}${k}" || iptables -t mangle -A ${IPTABLE}
            fi
        }
        [[ ${#tarinf[@]} -gt 0 ]] && IPTABLE="PREROUTING -s "${routing_block_list[j]}" -i "${tarinf}" -m comment --comment ${funcname}_block_${j} -j DROP"
        [[ ${#tarinf[@]} -eq 0 ]] && IPTABLE="PREROUTING -s "${routing_block_list[j]}" -m comment --comment ${funcname}_block_${j} -j DROP"
        iptables -t mangle -S | grep "${funcname}B${j}" || iptables -t mangle -A ${IPTABLE}
    }
}

# Mangle Prerouting : Limit MSS
# IPTABLES_LIMIT_MSS=1
function __net-iptables_mangle_all_both_limitmss {
    local funcname="mangle_all_both_limitmss"
    local mss="536:65535" # port range

    IPTABLE="PREROUTING -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss "${mss}" -m comment --comment ${funcname} -j DROP"
    iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -I $IPTABLE
}

# Filter/NAT Forward/Postrouting Masqurade
# IPTABLES_MASQ?="WLAN<WAN|LAN<WAN" # enP3p49s0>enP4p65s0(not implemented) #laninf lannet waninf
function __net-iptables_filternat_all_both_masquerade {
    local funcname="filternat_all_both_masquerade"
    local frominf="$1"
    local fromnet="$2"
    local toinf="$3"

    IPTABLE="FORWARD -i ${frominf} -o ${toinf} -m comment --comment ${funcname}_${j}_filter1 -j ACCEPT"
    iptables -t filter -S | grep "${funcname}_${j}_filter1" || iptables -t filter -A ${IPTABLE}
    IPTABLE="FORWARD -i ${toinf} -o ${frominf} -m state --state ESTABLISHED,RELATED -m comment --comment ${funcname}_${j}_filter2 -j ACCEPT"
    iptables -t filter -S | grep "${funcname}_${j}_filter2" || iptables -t filter -A ${IPTABLE}
    IPTABLE="POSTROUTING ! -d ${fromnet} -o ${toinf} -m comment --comment ${funcname}_${j}_masq -j MASQUERADE"
    iptables -t nat -S | grep "${funcname}_${j}_masq" || iptables -t nat -A ${IPTABLE}
    # iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source 192.0.2.123
}

## Filter/NAT Forward/Postrouting SNAT
## IPTABLES_SNAT?="WLAN<WAN|LAN<WAN" # enP3p49s0>enP4p65s0(not implemented) # laninf lannet waninf wanip
#function __net-iptables_filternat_all_both_snat {
#    local funcname="filternat_all_both_masquerade"
#    local frominf="$1" # internal network
#    local fromnet="$2" # internal network
#    local toinf="$4" # external network
#    local toip="$5" # external ip
#
#    IPTABLE="FORWARD -i ${frominf} -o ${toinf} -m comment --comment ${funcname}_${j}_filter1 -j ACCEPT"
#    iptables -t filter -S | grep "${funcname}_${j}_filter1" || iptables -t filter -A ${IPTABLE}
#    IPTABLE="FORWARD -i ${toinf} -o ${frominf} -m state --state ESTABLISHED,RELATED -m comment --comment ${funcname}_${j}_filter2 -j ACCEPT"
#    iptables -t filter -S | grep "${funcname}_${j}_filter2" || iptables -t filter -A ${IPTABLE}
#    IPTABLE="POSTROUTING ! -d ${fromnet} -o ${toinf} -m comment --comment ${funcname}_${j}_snat -j SNAT --to-source ${toip}"
#    iptables -t nat -S | grep "${funcname}_${j}_snat" || iptables -t nat -A ${IPTABLE}
#}

# DMZ - after portforward, SDMZ - prior to portforward
# IPTABLES_DMZ="DMZ" or SDMZ waninf laninf dmzip sdmz
function __net-iptables_nat_ext_both_dmzsdmz {
    local funcname="nat_ext_both_portforward"
    local waninf="$1"
    local laninf="$2"
    local dmzip="$3"
    local sdmz="${4:0}"

    local addorinsert="-A"
    [[ ${sdmz} -eq "1" ]] && ruleaddoverinsert="-I"
    # dmz input rule1
    IPTABLE="INPUT -p ALL -i ${laninf} -d ${dmzip} -j ACCEPT -m comment -comment ${funcname}_dmzinput"
    iptables -t filter -S | grep "${funcname}_dmzinput" || iptables -t filter ${ruleaddoverinsert} $IPTABLE
    # dmz filter forward network
    IPTABLE="FORWARD -i ${laninf} -o ${waninf} -j ACCEPT -m comment -comment ${funcname}_dmznetforward1"
    iptables -t filter -S | grep "${funcname}_dmznetforward1" || iptables -t filter ${ruleaddoverinsert} $IPTABLE
    IPTABLE="FORWARD -i ${waninf} -o ${laninf} -m state --state ESTABLISHED,RELATED -j ACCEPT -m comment -comment ${funcname}_dmznetforward2"
    iptables -t filter -S | grep "${funcname}_dmznetforward2" || iptables -t filter ${ruleaddoverinsert} $IPTABLE
    # dmz filter forward host
    IPTABLE="FORWARD -p ALL -i ${waninf} -o ${laninf} -d ${dmzip} -j allowed -m comment -comment ${funcname}_dmzhostforward"
    iptables -t filter -S | grep "${funcname}_dmzhostforward" || iptables -t filter ${ruleaddoverinsert} $IPTABLE
    # nat rule
    IPTABLE="PREROUTING -p ALL -i ${waninf} -j DNAT --to-destination ${dmzip} -m comment -comment ${funcname}_dmznat"
    iptables -t nat -S | grep "${funcname}_dmznat" || iptables -t nat ${ruleaddoverinsert} $IPTABLE
}

# NAT Prerouting/Postrouting Port forward
# IPTABLES_PORTFORWARD="" waninf wanport lanip lanport
function __net-iptables_nat_ext_both_portforward {
    local funcname="nat_ext_both_portforward"
    local waninf="$1"
    local wanport="$2"
    local lanip="$3"
    local lanport="$4"

    IPTABLE="PREROUTING -p tcp --dst ${waninf} --dport ${wanport} -j DNAT --to-destination ${lanip}:${lanport} -m comment -comment ${funcname}_pre"
    iptables -t nat -S | grep "${funcname}_pre" || iptables -t nat -A $IPTABLE
    IPTABLE="POSTROUTING -p tcp --dst ${lanip} --dport ${lanport} -j SNAT --to ${wanip} -m comment -comment ${funcname}_post"
    iptables -t nat -S | grep "${funcname}_post" || iptables -t nat -I $IPTABLE
    # iptables -t nat -F customipchain > /dev/null || iptables -t nat -N customipchain
    # iptables -t nat -A PREROUTING -i eth1 -j customipchain
    # iptables -t nat -A customipchain -p tcp -m multiport --dports 27015:27030 -j DNAT --to-destination 192.168.0.5
    # iptables -t nat -A customipchain -p udp -m udp --dport 33540 -j DNAT --to-destination 192.168.0.5
}

# Raw Prerouting : Guard Overload Limit UDP PPS
# IPTABLES_GUARD_OVERLOAD=1
function __net-iptables_raw_all_both_limitudppps {
    local funcname="raw_all_both_limitudppps"
    # Safeguard against CPU overload during amplificated DDoS attacks by limiting DNS/NTP packets per second rate (PPS).
    # Limited UDP source ports (against amplification
    local lusp="19,53,123,111,123,137,389,1900,3702,5353"

    IPTABLE="PREROUTING -p udp -m multiport --sports "${lusp}" -m hashlimit --hashlimit-mode srcip,srcport --hashlimit-name ${funcname} --hashlimit-above 256/m -m comment --comment ${funcname} -j DROP"
    iptables -t raw -S | grep "${funcname}" || iptables -t raw -A $IPTABLE
}

# Raw Prerouting : Drop Invalid Tcp Flag
# IPTABLES_INVALID_TCPFLAG=1
function __net-iptables_raw_all_both_dropinvtcpflag {
    local funcname="raw_all_both_dropinvtcpflag"
    # Invalid TCP Flag packet action
    # Default: DROP
    local ITFPA="DROP"

    IPTABLE1="PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST -m comment --comment ${funcname}1 -j "$ITFPA
    IPTABLE2="PREROUTING -p tcp --tcp-flags FIN,ACK FIN -m comment --comment ${funcname}2 -j "$ITFPA
    IPTABLE3="PREROUTING -p tcp --tcp-flags ACK,URG URG -m comment --comment ${funcname}3 -j "$ITFPA
    IPTABLE4="PREROUTING -p tcp --tcp-flags ACK,FIN FIN -m comment --comment ${funcname}4 -j "$ITFPA
    IPTABLE5="PREROUTING -p tcp --tcp-flags ACK,PSH PSH -m comment --comment ${funcname}5 -j "$ITFPA
    IPTABLE6="PREROUTING -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -m comment --comment ${funcname}6 -j "$ITFPA
    IPTABLE7="PREROUTING -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG FIN,SYN,RST,PSH,ACK,URG -m comment --comment ${funcname}7 -j "$ITFPA

    iptables -t raw -S | grep "${funcname}1" || iptables -t raw -A $IPTABLE1
    iptables -t raw -S | grep "${funcname}2" || iptables -t raw -A $IPTABLE2
    iptables -t raw -S | grep "${funcname}3" || iptables -t raw -A $IPTABLE3
    iptables -t raw -S | grep "${funcname}4" || iptables -t raw -A $IPTABLE4
    iptables -t raw -S | grep "${funcname}5" || iptables -t raw -A $IPTABLE5
    iptables -t raw -S | grep "${funcname}6" || iptables -t raw -A $IPTABLE6
    iptables -t raw -S | grep "${funcname}7" || iptables -t raw -A $IPTABLE7
}

# Filter Input : Drop Port Scanner IP
# IPTABLES_GUARD_PORT_SCANNER=1
function __net-iptables_raw_all_both_portscanner {
    SETNAME=IPTABLES_GUARD_PORT_SCANNER
    ipset list | grep -q IPTABLES_GUARD_PORT_SCANNER || ipset create IPTABLES_GUARD_PORT_SCANNER hash:ip family inet hashsize 32768 maxelem 65536 timeout 600
    ipset list | grep -q IPTABLES_GUARD_SCANNED_PORTS || ipset create IPTABLES_GUARD_SCANNED_PORTS hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60

    IPTABLE1='INPUT -m state --state INVALID -m comment --comment IPTABLES_GUARD_PORT_SCANNER1 -j DROP'
    IPTABLE2='INPUT -m state --state NEW -m set ! --match-set IPTABLES_GUARD_SCANNED_PORTS src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name IPTABLES_GUARD_PORT_SCANNER --hashlimit-htable-expire 10000 -j SET --add-set IPTABLES_GUARD_PORT_SCANNER src --exist'
    IPTABLE3='INPUT -m state --state NEW -m set --match-set IPTABLES_GUARD_PORT_SCANNER src -j DROP'
    IPTABLE4='INPUT -m state --state NEW -j SET --add-set IPTABLES_GUARD_SCANNED_PORTS src,dst'

    iptables -S | grep "IPTABLES_GUARD_PORT_SCANNER1" || iptables -A $IPTABLE1
    iptables -S | grep -- "-A $IPTABLE2" || iptables -A $IPTABLE2
    iptables -S | grep -- "-A $IPTABLE3" || iptables -A $IPTABLE3
    iptables -S | grep -- "-A $IPTABLE4" || iptables -A $IPTABLE4
}

# Filter Input : Drop IPs from blacklist
# IPTABLES_BLACK_NAMELIST="url|url" blockurls
function __net-iptables_filter_all_both_ipblacklist {
    local funcname="filter_all_both_ipblacklist"
    local blockurls="$1" #"https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt"
    IFS=$'|' read -d "" -ra blist_url <<< "${blockurls}" # split
    local urlcount=$(echo ${blockurls} | grep -o "|" | wc -l)
    for((j=0;j<=${urlcount};j++)){
        local blist_name=$(echo "${blist_url[j]}"|sed 's/[^0-9A-Za-z]*//g')
        blist_name=${blist_name:0:30}
        ipset -q flush ${blist_name}
        ipset -q create ${blist_name} hash:net
        for ip in $(curl --compressed ${blist_url[j]} 2>/dev/null | grep -v "#" | grep -v -E "\s[1-2]$" | cut -f 1); do ipset add ${blist_name} "$ip"; done
        iptables -D INPUT -m set --match-set ${blist_name} src -j DROP 2>/dev/null
        iptables -I INPUT -m set --match-set ${blist_name} src -j DROP
    }
}

complete -F __net-iptables_run net-iptables