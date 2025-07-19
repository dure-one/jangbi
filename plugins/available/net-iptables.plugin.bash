## \brief iptables firewall configurations.
## \desc This tool helps install, configure, and manage iptables firewall rules
## for network security and traffic filtering. It provides automated installation,
## configuration management, and firewall rule control capabilities. The tool manages
## packet filtering, NAT, port forwarding, and network security policies using iptables
## and netfilter framework with support for IPv4 and IPv6.

## \example Install and configure firewall rules:
## \example-code bash
##   net-iptables install
##   net-iptables configgen
##   net-iptables configapply
## \example-description
## In this example, we install iptables, generate firewall configurations,
## and apply them to secure the network with proper filtering rules.

## \example Apply rules and check firewall status:
## \example-code bash
##   net-iptables run
##   net-iptables check
## \example-description
## In this example, we activate the firewall rules and verify
## that the iptables configuration is working properly.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin a
about-plugin 'iptables install configurations.'

# filter(INPUT FORWARD OUTPUT)
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
    group 'postnet'
    runtype 'systemd'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ net-iptables subcommand'
    local PKGNAME="iptables"
    local DMNNAME="net-iptables"
    BASH_IT_LOG_PREFIX="net-iptables: "
    # IPTABLES_PORTS="${IPTABLES_PORTS:-""}"
    if [[ -z ${JB_VARS} ]]; then
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
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-iptables_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-iptables_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-iptables_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-iptables_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "build" ]]; then
        __net-iptables_build "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "watch" ]]; then
        __net-iptables_watch "$2"
    else
        __net-iptables_help
    fi
}  

function __net-iptables_help {
    echo -e "Usage: net-iptables [COMMAND]\n"
    echo -e "Helper to iptables install configurations.\n"
    echo -e "Commands:\n"
    echo "   help                       Show this help message"
    echo "   install                    Install os iptables"
    echo "   uninstall                  Uninstall installed iptables"
    echo "   configgen                  Configs Generator"
    echo "   configapply                Apply Configs"
    echo "   download                   download pkg files to pkg dir"
    echo "   check                      Check vars available"
    echo "   run                        do task at bootup"
    echo "   build                      rebuild iptables by configs"
    echo "   watch                      watch nftables"
}

function __net-iptables_install {
    log_debug "Installing ${DMNNAME}..."
    export DEBIAN_FRONTEND=noninteractive
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
        [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
        apt install -qy nftables iptables arptables net-tools ipset iprange || log_error "${DMNNAME} online install failed."
    else
        local filepat="./pkgs/nftables*.deb"
        local pkglist="./pkgs/nftables.pkgs"
        [[ $(find ${filepat}|wc -l) -lt 1 ]] && log_error "${DMNNAME} pkg file not found."
        pkgslist_down=()
        while read -r pkg; do
            [[ $pkg ]] && pkgslist_down+=("./pkgs/${pkg}*.deb")
        done < ${pkglist}
        # shellcheck disable=SC2068
        apt install -qy ${pkgslist_down[@]} || log_error "${DMNNAME} offline install failed."
    fi
    if ! __net-iptables_configgen; then # if gen config is different do apply
        __net-iptables_configapply
        rm -rf /tmp/iptables
    fi
}

function __net-iptables_configgen { # config generator and diff
    [[ -z ${PKGNAME} ]] && log_error "please run this function from ${DMNNAME} cmd." && return 1
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/

    __net-iptables_build # after build, /etc/nftables.conf /etc/iptables/nftables.conf have same contents
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-iptables_configapply {
    [[ ! -f /tmp/${PKGNAME}.diff ]] && log_error "/tmp/${PKGNAME}.diff file doesnt exist. please run configgen."
    local dtnow=$(date +%Y%m%d_%H%M%S)
    [[ -d "/etc/${PKGNAME}" ]] && cp -rf "/etc/${PKGNAME}" "/etc/.${PKGNAME}.${dtnow}"
    pushd /etc/${PKGNAME} 1>/dev/null 2>&1
    patch -i /tmp/${PKGNAME}.diff
    popd 1>/dev/null 2>&1
    rm /tmp/${PKGNAME}.diff
    return 0
}

function __net-iptables_download {
    _download_apt_pkgs "nftables iptables arptables net-tools ipset iprange" || log_error "${DMNNAME} download failed."
    return 0
}

function __net-iptables_uninstall { 
    log_debug "Uninstalling ${DMNNAME}..."
    systemctl stop nftables
    systemctl disable nftables
}

function __net-iptables_disable { 
    systemctl stop nftables
    systemctl disable nftables
    return 0
}

function __net-iptables_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."
    # check cmd exists
    [[ $(which ipcalc-ng|wc -l) -lt 1 ]] && \
        log_error "ipcacl-ng command does not exist. please install it." && [[ $running_status -lt 10 ]] && running_status=10
    # check global variable
    [[ -z ${RUN_NET_IPTABLES} ]] && \
        log_error "RUN_NET_IPTABLES variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_IPTABLES} != 1 ]] && \
        log_error "RUN_NET_IPTABLES is not enabled." && __net-iptables_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package iptables
    [[ $(dpkg -l|awk '{print $2}'|grep -c iptables) -lt 1 ]] && \
        log_info "iptables is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(systemctl status nftables 2>/dev/null|awk '{ print $2 }'|grep -c inactive) -lt 1 ]] && \
        log_info "nftables is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-iptables_run {
    # echo ""> /etc/nftables.conf # prevent not running because of xttables for nftables
    systemctl restart nftables
    systemctl status nftables && return 0 || return 1
}

function __net-iptables_watch {
    watch -n 1 'nft list ruleset |grep -v 0\ drop|grep -v }'
}

function __net-iptables_build {
    # read config apply
    # EMPTY RULES
    nft flush ruleset

    # GET VARs
    local wanip lanip wlanip
    wanip=$(_get_ip_of_infmark "WAN")
    [[ -z ${wanip} ]] && wanip="127.0.0.1"
    lanip=$(_get_ip_of_infmark "LAN")
    [[ -z ${lanip} ]] && lanip="127.0.0.1"
    wlanip=$(_get_ip_of_infmark "WLAN")
    [[ -z ${wlanip} ]] && wlanip="127.0.0.1"
    
    #
    # ARP RULES
    #
    # IPTABLES_WHITELISTED_MACADDRESSES
    [[ ${#WHITELISTED_MACADDRESSES[@]} -gt 0 ]] && __net-iptables_mangle_all_both_macwhitelist "${waninf}" "${GW_MAC}" # targetinf macaddrs
    # IPTABLES_GWMACONLY
    log_debug "iptables_mangle_ext_both_gwmaconly"
    [[ ${IPTABLES_GWMACONLY} -gt 0 ]] && __net-iptables_mangle_ext_both_gwmaconly
    # IPTABLES_ARPALLINFS # Arptables : Allow all other network except gateway
    log_debug "iptables_mangle_all_both_arpallinfs"
    [[ ${IPTABLES_ARPALLINFS} -gt 0 ]] && __net-iptables_mangle_all_both_arpallinfs

    # Base Rules
    if [[ -n ${IPTABLES_OVERRIDE} ]]; then # IPTABLES_OVERRIDE ON
        echo "${IPTABLES_OVERRIDE}" > /tmp/iptables_override.conf
        if ! iptables-restore /tmp/iptables_override.conf; then # on error
            echo "ERROR: \$IPTABLES_OVERRIDE has error."
            return 1
        else # on success
            iptables-restore /tmp/iptables_override.conf
        fi
        rm /tmp/iptables_override.conf
    else # NFTABLES_OVERRIDE OFF
        if [[ ${DISABLE_IPV6} -gt 0 ]]; then # disable ipv6
            iptables-restore /etc/iptables/rules-ipv4.iptables
            ip6tables -I FORWARD -j DROP && ip6tables -I OUTPUT -j DROP && ip6tables -I INPUT -j DROP
        else # enable ipv6
            iptables-restore /etc/iptables/rules-both.iptables
        fi
    fi

    #
    # NET RULES
    #
    # IPTABLES_DROP_ICMP
    log_debug "iptables_mangle_all_both_dropicmp"
    [[ ${IPTABLES_DROP_ICMP} -gt 0 ]] && __net-iptables_mangle_all_both_dropicmp
    # IPTABLES_DROP_NON_SYN
    log_debug "iptables_mangle_all_both_dropnonsyn"
    [[ ${IPTABLES_DROP_NON_SYN} -gt 0 ]] && __net-iptables_mangle_all_both_dropnonsyn
    # IPTABLES_DROP_SPOOFING=1
    log_debug "iptables_mangle_all_both_dropspoofing"
    [[ ${IPTABLES_DROP_SPOOFING} -gt 0 ]] && __net-iptables_mangle_all_both_dropspoofing
    # IPTABLES_LIMIT_MSS
    log_debug "iptables_mangle_all_both_limitmss"
    [[ ${IPTABLES_LIMIT_MSS} -gt 0 ]] && __net-iptables_mangle_all_both_limitmss
    # IPTABLES_INVALID_TCPFLAG
    log_debug "iptables_raw_all_both_dropinvtcpflag"
    [[ ${IPTABLES_INVALID_TCPFLAG} -gt 0 ]] && __net-iptables_raw_all_both_dropinvtcpflag
    # IPTABLES_BLACK_NAMELIST
    log_debug "iptables_filter_all_both_ipblacklist"
    [[ ${#IPTABLES_BLACK_NAMELIST[@]} -gt 0 ]] && __net-iptables_filter_all_both_ipblacklist

    #
    # HOST RULES
    #    

    # PORT FORWARDING WAN->LAN
    # IPTABLES_PORTFORWARD="8090:192.168.0.1:8090,8010:192.168.0.1:8010"
    log_debug "iptables_nat_ext_both_portforward"
    [[ ${#IPTABLES_PORTFORWARD[@]} -gt 0 ]] && __net-iptables_nat_ext_both_portforward

    # DMZ SETTINGS WAN->HOST
    # IPTABLES_DMZ="192.168.0.1" IPTABLES_SUPERDMZ=1
    log_debug "iptables_nat_ext_both_dmzsdmz"
    [[ ${#IPTABLES_DMZ[@]} -gt 0 ]] && __net-iptables_nat_ext_both_dmzsdmz

    # MASQUERADE WAN->NET
    # IPTABLES_MASQ="LAN<WAN,LAN1<WAN"
    if [[ -n ${IPTABLES_MASQ} ]]; then
        IFS=$',' read -d "" -ra MASQROUTES <<< "${IPTABLES_MASQ}" # split
        for((j=0;j<${#MASQROUTES[@]};j++)){
            local frominf="" toinf="" fromnet="" tonet=""
            IFS=$'<' read -d "" -ra masqinfs <<< "${MASQROUTES[j]}"
            if [[ $(_trim_string ${masqinfs[0]}) = "LAN" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${laninf}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_LAN}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "WLAN" && $(_trim_string ${masqinfs[1]}) = "WAN"  ]]; then
                frominf=${wlaninf}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_WLAN}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN0" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${JB_LAN0INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_LAN0}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN1" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${JB_LAN1INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_LAN1}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN2" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${JB_LAN2INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_LAN2}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN3" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${JB_LAN3INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_LAN3}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN4" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${JB_LAN4INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_LAN4}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN5" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${JB_LAN5INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_LAN5}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN6" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${JB_LAN6INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_LAN6}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN7" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${JB_LAN7INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_LAN7}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN8" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${JB_LAN8INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_LAN8}|grep Network:|cut -f2)
            elif [[ $(_trim_string ${masqinfs[0]}) = "LAN9" && $(_trim_string ${masqinfs[1]}) = "WAN" ]]; then
                frominf=${JB_LAN9INF}
                toinf=${waninf}
                fromnet=$(ipcalc-ng ${JB_LAN9}|grep Network:|cut -f2)
            fi

            if [[ -n ${frominf} && -n ${toinf} ]]; then
                log_debug "iptables_filternat_all_both_masquerade"
                __net-iptables_filternat_all_both_masquerade  "${frominf}" "${fromnet}" "${toinf}" # laninf lannet waninf
            fi
        }
    fi
    # nft --check --file /tmp/iptables/nftables.conf
    # IPTABLES_SNAT="LAN<WAN,LAN1<WAN"
    # [[ ${IPTABLES_SNAT} -gt 0 ]] && __net-iptables_filternat_all_both_snat # laninf lannet waninf wanip
    iptables-save > /tmp/iptables/iptables.iptables
    nft list ruleset > /tmp/iptables/nftables.conf

    log_debug "iptables build done."
    return 0
}

# MODES : Gateway, Wstunnel, Client
# TABLES : filter(IFO), nat(PIOP), mangle(IFP), raw(PO), security(IOF) https://gist.github.com/egernst/2c39c6125d916f8caa0a9d3bf421767a
# PREFIX : int/ext/all inc/oug/both contents

# Arptables : MAC Whitelisting (inf)-(mac), inf: LAN/WAN/WLAN/ALL
# WHITELISTED_MACADDRESSES?=LAN-aa:bb:cc:dd:ee,WAN-ab:cd:be:c0:a1
function __net-iptables_mangle_all_both_macwhitelist {
    local funcname targetinf macaddrs
    funcname="mab_macwhitelist"
    targetinf=$(_trim_string "$1")
    macaddrs=$(_trim_string "$2")

    [[ ${#targetinf} -lt 1 ]] && log_error "${funcname}: targetinf is not set" && return 1
    [[ ${#macaddrs} -lt 1 ]] && log_error "${funcname}: macaddrs is not set" && return 1

    IFS=$',' read -d "" -ra blockconf <<< "${macaddrs}" # split
    for((j=0;j<${#blockconf[@]};j++)){
        local targetinf infmac
        IFS=$'-' read -d "" -ra infmac <<< "${blockconf[j]}" # split
        [[ ${#infmac[@]} != 2 ]] && log_error "${funcname}: wrong params(${blockconf[j]})."
        [[ ${infmac[0]} = "WAN" ]] && targetinf=${waninf}
        [[ ${infmac[0]} = "LAN" ]] && targetinf=${laninf}
        [[ ${infmac[0]} = "WLAN" ]] && targetinf=${wlaninf}
        arptables -A INPUT -i "${targetinf}" --source-mac "${infmac[1]}" -j ACCEPT
        log_debug "arptables -A INPUT -i ${targetinf} --source-mac ${infmac[1]} -j ACCEPT"
    }
    [[ $(arptables -S|grep -c "INPUT DROP") -lt 1 ]] && arptables -P INPUT DROP
}

# Arptables : Allow only from Gateway on wan
# IPTABLES_GWMACONLYIPTABLES_GWMACONLY=1
function __net-iptables_mangle_ext_both_gwmaconly {
    local funcname targetinf gwip gwmac
    funcname="meb_gwmaconly"
    
    targetinf=$(route|grep default|awk '{print $8}') # net-tools
    targetinf=$(_trim_string ${targetinf})
    gwip=$(routel|grep default|awk '{print $2}') # net-tools
    gwip=$(_trim_string ${gwip})
    gwmac=$(cat /proc/net/arp|grep "${gwip}"|awk '{print $4}')
    gwmac=$(_trim_string ${gwmac})

    [[ ${#targetinf} -lt 1 ]] && log_error "${funcname}: targetinf is not set" && return 1
    [[ ${#gwip} -lt 1 ]] && log_error "${funcname}: gwip is not set" && return 1
    [[ ${#gwmac} -lt 1 ]] && log_error "${funcname}: gwmac is not set" && return 1

    arptables -A INPUT -i "${targetinf}" --source-mac "${gwmac}" -j ACCEPT
    log_debug "arptables -A INPUT -i ${targetinf} --source-mac ${gwmac} -j ACCEPT"
    [[ $(arptables -S|grep -c "INPUT DROP") -lt 1 ]] && arptables -P INPUT DROP
}

# Arptables : Allow all other network except gateway
# IPTABLES_ARPALLINFS=1
function __net-iptables_mangle_all_both_arpallinfs {
    local funcname targetinf allinfx infs
    funcname="mab_arpallinfs"

    targetinf=$(route|grep default|awk '{print $8}') # net-tools
    targetinf=$(_trim_string ${targetinf})
    log_debug "check network interfaces for arptables"

    infs=$(cat /proc/net/dev|grep :|awk '{print $1}'|sed 's/://g')
    IFS=$'\n' read -rd '' -a allinfx <<<"$infs"
    for((i=0;i<${#allinfx[@]};i++)){ 
        if [[ ${allinfx[i]} = "lo" ]]; then
            log_debug "skip lo interface for arptables"
            continue
        fi
        if [[ ${allinfx[i]} = ${targetinf} ]]; then # except gateway interface
            log_debug "skip ${targetinf} interface for arptables"
            continue
        fi
        arptables -A INPUT -i "${allinfx[i]}" -j ACCEPT
        log_debug "arptables -A INPUT -i ${allinfx[i]} -j ACCEPT"
    }
    [[ $(arptables -S|grep -c "INPUT DROP") -lt 1 ]] && arptables -P INPUT DROP
}

# Mangle Prerouting : Drop ICMP
# IPTABLES_DROP_ICMP=1
function __net-iptables_mangle_all_both_dropicmp {
    local funcname="mab_dropicmp"

    IPTABLE="PREROUTING -p icmp -m comment --comment ${funcname} -j DROP"
    iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -A ${IPTABLE}
}

# Mangle Prerouting : Drop Invalid State
# IPTABLES_DROP_INVALID_STATE=1
function __net-iptables_mangle_all_both_dropinvalidstate {
    local funcname="mab_dropinvalidstate"

    IPTABLE="PREROUTING -p all -m conntrack --ctstate INVALID -m comment --comment ${funcname} -j DROP"
    iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -I ${IPTABLE}
}

# Mangle Prerouting : Drop new non-SYN TCP Packets
# IPTABLES_DROP_NON_SYN=1
function __net-iptables_mangle_all_both_dropnonsyn {
    local funcname="mab_dropnonsyn"

    IPTABLE="PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -m comment --comment ${funcname} -j DROP"
    iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -I ${IPTABLE}
}

# Mangle Prerouting : Drop Spoofing Packets
# IPTABLES_DROP_SPOOFING=1 IPTABLES_DROP_SPOOFING_TARINF=WAN IPTABLES_DROP_SPOOFING_NET="224.0.0.0/3,169.254.0.0/16,172.16.0.0/12,192.0.2.0/24,192.168.0.0/16,10.0.0.0/8,0.0.0.0/8,240.0.0.0/5,127.0.0.0/8"
function __net-iptables_mangle_all_both_dropspoofing {
    local funcname="mab_dropspoofing"
    local tarinf tarnets
    tarinf=$(_trim_string "${IPTABLES_DROP_SPOOFING_TARINF}")
    tarnets=$(_trim_string "${IPTABLES_DROP_SPOOFING_NET}")
    
    [[ ${#tarinf} -lt 1 ]] && log_error "${funcname}: tarinf is not set" && return 1
    [[ ${#tarnets} -lt 1 ]] && log_error "${funcname}: tarnets is not set" && return 1

    IFS=$'\n' read -d "" -ra routing_allow_list <<< "$(routel|grep /|grep -v 127.0.0.0/8|cut -d" " -f1)" # split
    routing_allow_list+=("127.0.0.1/29") # add localhost range 127.0.0.1-14 for anydnsdqy and dnsmasq
    IFS=$',' read -d "" -ra routing_block_list <<< "${tarnets}" # split
    for((j=0;j<${#routing_block_list[@]};j++)){
        __bp_trim_whitespace iptables_block_ip "${routing_block_list[j]}"
        for((k=0;k<${#routing_allow_list[@]};k++)){
            __bp_trim_whitespace iptables_allow_ip "${routing_allow_list[k]}"
            # log_debug "${iptables_allow_ip} ${iptables_block_ip}"
            ALMINIP=$(_ip2conv "$(ipcalc-ng "${iptables_allow_ip}"|grep HostMin:|cut -f2)")
            ALMAXIP=$(_ip2conv "$(ipcalc-ng "${iptables_allow_ip}"|grep HostMax:|cut -f2)")
            BLMINIP=$(_ip2conv "$(ipcalc-ng "${iptables_block_ip}"|grep HostMin:|cut -f2)")
            BLMAXIP=$(_ip2conv "$(ipcalc-ng "${iptables_block_ip}"|grep HostMax:|cut -f2)")
            if [[ ${ALMINIP} -gt ${BLMINIP} && ${ALMAXIP} -lt ${BLMAXIP} ]]; then
                log_debug "allowing ip ${iptables_allow_ip}"
                IPTABLE="PREROUTING -s ${iptables_allow_ip} -m comment --comment ${funcname}_allow_${j}${k} -j ACCEPT"
                iptables -t mangle -S | grep "${funcname}_allow_${j}${k}" || iptables -t mangle -A ${IPTABLE}
            fi
        }
        log_debug "blocking ip ${iptables_block_ip}"
        [[ ${#tarinf[@]} -gt 0 ]] && IPTABLE="PREROUTING -s ${iptables_block_ip} -i ${tarinf} -m comment --comment ${funcname}_block_${j} -j DROP"
        [[ ${#tarinf[@]} -eq 0 ]] && IPTABLE="PREROUTING -s ${iptables_block_ip} -m comment --comment ${funcname}_block_${j} -j DROP"
        iptables -t mangle -S | grep "${funcname}_block_${j}" || iptables -t mangle -A ${IPTABLE}
    }
}

# Mangle Prerouting : Limit MSS
# IPTABLES_LIMIT_MSS=1
function __net-iptables_mangle_all_both_limitmss {
    local funcname="mab_limitmss"
    local mss="536:65535" # port range

    IPTABLE="PREROUTING -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss "${mss}" -m comment --comment ${funcname} -j DROP"
    iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -I ${IPTABLE}
}

# Filter/NAT Forward/Postrouting Masqurade
# IPTABLES_MASQ?="WLAN<WAN|LAN<WAN" # enP3p49s0>enP4p65s0(not implemented) #laninf lannet waninf
function __net-iptables_filternat_all_both_masquerade {
    local funcname="fab_masquerade"
    local frominf
    frominf=$(_trim_string "$1")
    local fromnet
    fromnet=$(_trim_string "$2")
    local toinf
    toinf=$(_trim_string "$3")

    [[ ${#frominf} -lt 1 ]] && log_error "${funcname}: frominf is not set" && return 1
    [[ ${#fromnet} -lt 1 ]] && log_error "${funcname}: fromnet is not set" && return 1
    [[ ${#toinf} -lt 1 ]] && log_error "${funcname}: toinf is not set" && return 1

    IPTABLE="FORWARD -i ${frominf} -o ${toinf} -m comment --comment ${funcname}_${j}_filter1 -j ACCEPT"
    iptables -t filter -S | grep "${funcname}_${j}_filter1" || iptables -t filter -A ${IPTABLE}
    IPTABLE="FORWARD -i ${toinf} -o ${frominf} -m state --state ESTABLISHED,RELATED -m comment --comment ${funcname}_${j}_filter2 -j ACCEPT"
    iptables -t filter -S | grep "${funcname}_${j}_filter2" || iptables -t filter -A ${IPTABLE}
    IPTABLE="POSTROUTING ! -d ${fromnet} -o ${toinf} -m comment --comment ${funcname}_${j}_masq -j MASQUERADE"
    iptables -t nat -S | grep "${funcname}_${j}_masq" || iptables -t nat -A ${IPTABLE}
    # iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source 192.0.2.123
}

# Filter/NAT Forward/Postrouting SNAT
# IPTABLES_SNAT?="WLAN<WAN,LAN<WAN" # enP3p49s0>enP4p65s0(not implemented) # laninf lannet waninf wanip
#function __net-iptables_filternat_all_both_snat {
#    local funcname="fnab_masquerade"
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
# IPTABLES_DMZ="192.68.79.10" IPTABLES_SUPERDMZ=1
function __net-iptables_nat_ext_both_dmzsdmz {
    local funcname waninf laninf dmzip sdmz
    funcname="neb_dmzsdmz"
    waninf=$(_get_inf_of_infmark "WAN")
    laninf=$(_get_inf_of_infmark "LAN")
    dmzip=$(_trim_string "${IPTABLES_DMZ}")
    sdmz=$(_trim_string "${IPTABLES_SUPERDMZ}")

    [[ ${#waninf} -lt 1 ]] && log_error "${funcname}: waninf is not set" && return 1
    [[ ${#laninf} -lt 1 ]] && log_error "${funcname}: laninf is not set" && return 1
    [[ ${#dmzip} -lt 1 ]] && log_error "${funcname}: dmzip is not set" && return 1
    [[ ${#sdmz} -lt 1 ]] && log_error "${funcname}: sdmz is not set" && return 1

    local ruleaddoverinsert="-A"
    [[ ${sdmz} -eq "1" ]] && ruleaddoverinsert="-I"
    # dmz input rule1
    IPTABLE="INPUT -p ALL -i ${laninf} -d ${dmzip} -j ACCEPT -m comment --comment ${funcname}_dmzinput"
    log_debug "${IPTABLE}"
    iptables -t filter -S | grep "${funcname}_dmzinput" || iptables -t filter ${ruleaddoverinsert} ${IPTABLE}
    # dmz filter forward network
    IPTABLE="FORWARD -i ${laninf} -o ${waninf} -j ACCEPT -m comment --comment ${funcname}_dmznetforward1"
    log_debug "${IPTABLE}"
    iptables -t filter -S | grep "${funcname}_dmznetforward1" || iptables -t filter ${ruleaddoverinsert} ${IPTABLE}
    log_debug "${IPTABLE}"
    IPTABLE="FORWARD -i ${waninf} -o ${laninf} -m state --state ESTABLISHED,RELATED -j ACCEPT -m comment --comment ${funcname}_dmznetforward2"
    iptables -t filter -S | grep "${funcname}_dmznetforward2" || iptables -t filter ${ruleaddoverinsert} ${IPTABLE}
    # dmz filter forward host
    IPTABLE="FORWARD -p ALL -i ${waninf} -o ${laninf} -d ${dmzip} -j ACCEPT -m comment --comment ${funcname}_dmzhostforward"
    log_debug "${IPTABLE}"
    iptables -t filter -S | grep "${funcname}_dmzhostforward" || iptables -t filter ${ruleaddoverinsert} ${IPTABLE}
    # nat rule
    IPTABLE="PREROUTING -p ALL -i ${waninf} -j DNAT --to-destination ${dmzip} -m comment --comment ${funcname}_dmznat"
    log_debug "${IPTABLE}"
    iptables -t nat -S | grep "${funcname}_dmznat" || iptables -t nat ${ruleaddoverinsert} ${IPTABLE}
}

# NAT Prerouting/Postrouting Port forward
# IPTABLES_PORTFORWARD="8090:192.168.79.11:8090,8010:192.168.79.12:8010"
function __net-iptables_nat_ext_both_portforward {
    local pforwards funcname wanip wanport lanip lanport
    funcname="neb_portforward"
    pforwards=${IPTABLES_PORTFORWARD}
    wanip=$(_get_ip_of_infmark "WAN")
    
    [[ ${#pforwards} -lt 1 ]] && log_error "${funcname}: \"${pforwards}\" is not set" && return 1
    log_debug "${pforwards}"

    IFS=$',' read -d "" -ra pforw <<< "${pforwards}" # split
    for((j=0;j<${#pforw[@]};j++)){
        IFS=$':' read -d "" -ra target <<< "${pforw[j]}" # split
        wanport=${target[0]}
        lanip=${target[1]}
        lanport=${target[2]}

        [[ ${#wanip} -lt 1 ]] && log_error "${funcname}: wanip is not set" && return 1
        [[ ${#wanport} -lt 1 ]] && log_error "${funcname}: wanport is not set" && return 1
        [[ ${#lanip} -lt 1 ]] && log_error "${funcname}: lanip is not set" && return 1
        [[ ${#lanport} -lt 1 ]] && log_error "${funcname}: lanport is not set" && return 1
        IPTABLE="PREROUTING -p tcp --dst ${wanip} --dport ${wanport} -j DNAT --to-destination ${lanip}:${lanport} -m comment --comment ${funcname}_pre"
        log_debug "${IPTABLE}"
        iptables -t nat -S | grep "${funcname}_pre" || iptables -t nat -A ${IPTABLE}
        IPTABLE="POSTROUTING -p tcp --dst ${lanip} --dport ${lanport} -j SNAT --to ${wanip} -m comment --comment ${funcname}_post"
        log_debug "${IPTABLE}"
        iptables -t nat -S | grep "${funcname}_post" || iptables -t nat -I ${IPTABLE}
    }
    # iptables -t nat -F customipchain > /dev/null || iptables -t nat -N customipchain
    # iptables -t nat -A PREROUTING -i eth1 -j customipchain
    # iptables -t nat -A customipchain -p tcp -m multiport --dports 27015:27030 -j DNAT --to-destination 192.168.0.5
    # iptables -t nat -A customipchain -p udp -m udp --dport 33540 -j DNAT --to-destination 192.168.0.5
}

# Raw Prerouting : Drop Invalid Tcp Flag
# IPTABLES_INVALID_TCPFLAG=1
function __net-iptables_raw_all_both_dropinvtcpflag {
    local funcname="rab_dropinvtcpflag"
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

    iptables -t raw -S | grep "${funcname}1" || iptables -t raw -A ${IPTABLE1}
    iptables -t raw -S | grep "${funcname}2" || iptables -t raw -A ${IPTABLE2}
    iptables -t raw -S | grep "${funcname}3" || iptables -t raw -A ${IPTABLE3}
    iptables -t raw -S | grep "${funcname}4" || iptables -t raw -A ${IPTABLE4}
    iptables -t raw -S | grep "${funcname}5" || iptables -t raw -A ${IPTABLE5}
    iptables -t raw -S | grep "${funcname}6" || iptables -t raw -A ${IPTABLE6}
    iptables -t raw -S | grep "${funcname}7" || iptables -t raw -A ${IPTABLE7}
}

# Filter Input : Drop IPs from blacklist
# IPTABLES_BLACK_NAMELIST="url|url" blockurls
function __net-iptables_filter_all_both_ipblacklist {
    local funcname="fab_ipblacklist"
    local blockurls filename_with_suffix filename #"https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt"
    blockurls=$(_trim_string "${IPTABLES_BLACK_NAMELIST}")
    [[ ${#blockurls} -lt 1 ]] && log_error "${funcname}: blockurls is not set" && return 1
    IFS=$'|' read -d "" -ra blist_url <<< "${blockurls}" # split
    local urlcount=$(echo "${blockurls}" | grep -o "|" | wc -l)
    for((j=0;j<=${urlcount};j++)){
        filename_with_suffix=${urlcount[j]##*/} # Extracts "file.html?param=value#fragment"
        filename=${filename_with_suffix%%[?#]*} # Removes query and fragment, resulting in "file.html"
        local blist_name="bl$j_$filename"
        ipset -q flush "${blist_name}"
        ipset -q create "${blist_name}" hash:net
        for ip in $(curl --compressed "${blist_url[j]}" 2>/dev/null | grep -v "#" | grep -v -E "\s[1-2]$" | cut -f 1); do ipset add "${blist_name}" "$ip"; done
        iptables -D INPUT -m set --match-set "${blist_name}" src -j DROP 2>/dev/null
        iptables -I INPUT -m set --match-set "${blist_name}" src -j DROP
    }
    ipset save > /etc/iptables/ipset.conf
}

complete -F _blank net-iptables
