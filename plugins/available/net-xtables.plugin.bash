## \brief xtables extended netfilter configurations.
## \desc This tool helps install, configure, and manage xtables (extended netfilter)
## for advanced packet filtering and network security. It provides automated installation,
## configuration management, and extended firewall capabilities. Xtables includes support
## for additional netfilter modules, advanced matching criteria, and enhanced packet
## manipulation features beyond standard iptables functionality.

## \example Install and configure extended netfilter:
## \example-code bash
##   net-xtables install
##   net-xtables configgen
##   net-xtables configapply
## \example-description
## In this example, we install xtables, generate extended firewall configurations,
## and apply them to enable advanced packet filtering capabilities.

## \example Apply advanced rules and check status:
## \example-code bash
##   net-xtables run
##   net-xtables check
## \example-description
## In this example, we activate the extended netfilter rules and verify
## that the advanced firewall features are working properly.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin a
about-plugin 'xtables install configurations.'

function net-xtables {
    about 'xtables install configurations'
    group 'postnet'
    runtype 'systemd'
    deps  'net-iptables'
    param '1: command'
    param '2: params'
    example '$ net-xtables subcommand'
    local PKGNAME="xtables"
    local DMNNAME="net-xtables"
    BASH_IT_LOG_PREFIX="net-xtables: "
    # XTABLES_PORTS="${XTABLES_PORTS:-""}"
    if [[ -z ${JB_VARS} ]]; then
        _load_config || exit 1
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-xtables_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-xtables_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-xtables_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-xtables_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-xtables_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-xtables_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-xtables_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "build" ]]; then
        __net-xtables_build "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "watch" ]]; then
        __net-xtables_watch "$2"
    else
        __net-xtables_help
    fi
}  

## \usage net-xtables [COMMAND]
## \usage net-xtables install|uninstall|configgen|configapply
## \usage net-xtables check|run|download|build|watch
function __net-xtables_help {
    echo -e "Usage: net-xtables [COMMAND]\n"
    echo -e "Helper to xtables install configurations.\n"
    echo -e "Commands:\n"
    echo "   help                       Show this help message"
    echo "   install                    Install os xtables"
    echo "   uninstall                  Uninstall installed xtables"
    echo "   configgen                  Generates xtables configs"
    echo "   configapply                Apply Configs"
    echo "   download                   download pkg files to pkg dir"
    echo "   check                      Check vars available"
    echo "   run                        do task at bootup"
    echo "   build                      rebuild xtables by configs"
    echo "   watch                      watch nftables"
}

function __net-xtables_install {
    log_debug "Installing ${DMNNAME}..."
    export DEBIAN_FRONTEND=noninteractive
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
        [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
        apt install -qy xtables-addon-common xtables-addons-dkms || log_error "${DMNNAME} online install failed."
    else
        local filepat="./pkgs/${PKGNAME}*.deb"
        local pkglist="./pkgs/${PKGNAME}.pkgs"
        [[ $(find ${filepat}|wc -l) -lt 1 ]] && log_error "${DMNNAME} pkg file not found."
        pkgslist_down=()
        while read -r pkg; do
            [[ $pkg ]] && pkgslist_down+=("./pkgs/${pkg}*.deb")
        done < "${pkglist}"
        # shellcheck disable=SC2068
        apt install -qy ${pkgslist_down[@]} || log_error "${DMNNAME} offline install failed."
    fi
    if ! __net-xtables_configgen; then # if gen config is different do apply
        __net-xtables_configapply
        rm -rf /tmp/xtables
    fi
}

function __net-xtables_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    # cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    
    # generate rulesfile without putting in iptables.
    touch "/tmp/${PKGNAME}/rulesfile.conf"
    __net-xtables_build "/tmp/${PKGNAME}/rulesfile.conf"

    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-xtables_configapply {
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

function __net-xtables_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_apt_pkgs "xtables-addon-common xtables-addons-dkms" || log_error "${DMNNAME} download failed."
    return 0
}

function __net-xtables_uninstall { 
    log_debug "Uninstalling ${DMNNAME}..."
}

function __net-xtables_disable { 
    log_debug "Disabling ${DMNNAME}..."
}

function __net-xtables_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."
    # check cmd exists
    [[ $(which nft|wc -l) -lt 1 ]] && \
        log_error "nft command does not exist. please install it." && [[ $running_status -lt 10 ]] && running_status=10
    # check global variable
    [[ -z ${RUN_NET_XTABLES} ]] && \
        log_error "RUN_NET_XTABLES variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_XTABLES} != 1 ]] && \
        log_error "RUN_NET_XTABLES is not enabled." && __net-xtables_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package xtables
    [[ $(dpkg -l|awk '{print $2}'|grep -c xtables-addons-common) -lt 1 ]] && \
        log_info "xtables-addons-common is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(systemctl status nftables 2>/dev/null|awk '{ print $2 }'|grep -c inactive) -lt 1 ]] && \
        log_info "nftables is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-xtables_run {
    # this will insert rules to iptables xtables
    __net-xtables_build
}

function __net-xtables_watch {
    watch -n 1 'nft list ruleset |grep -v 0\ drop|grep -v }'
}

function __net-xtables_build {
    local RULESFILE
    RULESFILE=$(_trim_string $1)
    [[ -z ${RULESFILE} ]] && log_debug "no rulesfile specified. direct insert mode"

    # GET VARs
    local wanip lanip wlanip
    wanip=$(_get_ip_of_infmark "WAN")
    [[ -z ${wanip} ]] && wanip="127.0.0.1"
    lanip=$(_get_ip_of_infmark "LAN")
    [[ -z ${lanip} ]] && lanip="127.0.0.1"
    wlanip=$(_get_ip_of_infmark "WLAN")
    [[ -z ${wlanip} ]] && wlanip="127.0.0.1"

    #
    # NET RULES
    #
    # XTABLES_CONNLIMIT_PER_IP=100
    log_debug "xtables_mangle_all_both_conlimitperip"
    [[ ${XTABLES_CONNLIMIT_PER_IP} -gt 0 ]] && __net-xtables_mangle_all_both_conlimitperip
    # XTABLES_DROP_INVALID_STATE
    log_debug "xtables_mangle_all_both_dropinvalidstate"
    [[ ${XTABLES_DROP_INVALID_STATE} -gt 0 ]] && __net-xtables_mangle_all_both_dropinvalidstate
    # XTABLES_DROP_NON_SYN
    log_debug "xtables_mangle_all_both_dropnonsyn"
    [[ ${XTABLES_DROP_NON_SYN} -gt 0 ]] && __net-xtables_mangle_all_both_dropnonsyn
    # XTABLES_LIMIT_MSS
    log_debug "xtables_mangle_all_both_limitmss"
    [[ ${XTABLES_LIMIT_MSS} -gt 0 ]] && __net-xtables_mangle_all_both_limitmss
    # XTABLES_GUARD_OVERLOAD
    log_debug "xtables_raw_all_both_limitudppps"
    [[ ${XTABLES_GUARD_OVERLOAD} -gt 0 ]] && __net-xtables_raw_all_both_limitudppps
    # XTABLES_INVALID_TCPFLAG
    log_debug "xtables_raw_all_both_dropinvtcpflag"
    [[ ${XTABLES_INVALID_TCPFLAG} -gt 0 ]] && __net-xtables_raw_all_both_dropinvtcpflag
    # XTABLES_GUARD_PORT_SCANNER
    log_debug "xtables_raw_all_both_portscanner"
    [[ ${XTABLES_GUARD_PORT_SCANNER} -gt 0 ]] && __net-xtables_raw_all_both_portscanner
    # XTABLES_CHAOS_PORTS
    log_debug "xtables_filter_all_both_chaos"
    [[ ${XTABLES_CHAOS_PORTS} -gt 0 ]] && __net-xtables_filter_all_both_chaos
    # XTABLES_DELUDE_PORTS="22,23,80,443,21,25,53,110,143,993,995"
    log_debug "xtables_filter_all_both_delude"
    [[ ${XTABLES_DELUDE_PORTS} -gt 0 ]] && __net-xtables_filter_all_both_delude
    # XTABLES_PKNOCK_PORTS="3001,3002,3003" XTABLES_PKNOCK_OPEN_PORT="3306" XTABLES_PKNOCK_TIMEOUT="20"
    log_debug "xtables_filter_all_inc_pknock_db"
    [[ ${#XTABLES_PKNOCK_PORTS[@]} -gt 0 ]] && __net-xtables_filter_all_inc_pknock_db
    
    # XTABLES_SNAT="LAN<WAN|LAN1<WAN"
    # [[ ${XTABLES_SNAT} -gt 0 ]] && __net-xtables_filternat_all_both_snat # laninf lannet waninf wanip
    # nft list ruleset > /tmp/xtables/nftables.conf
    return 0
}

# MODES : Gateway, Tunnelonly, Client
# TABLES : filter(IFO), nat(PIOP), mangle(IFP), raw(PO), security(IOF) https://gist.github.com/egernst/2c39c6125d916f8caa0a9d3bf421767a
# PREFIX : int/ext/all inc/oug/both contents

# Mangle Prerouting : Ip Connection Limit per IP
# XTABLES_CONNLIMIT_PER_IP=100
function __net-xtables_mangle_all_both_conlimitperip {
    local funcname="xtmab_conlimitperip"
    local conlimitperip
    conlimitperip=$(_trim_string "$XTABLES_CONNLIMIT_PER_IP")
    [[ ${conlimitperip} -lt 1 ]] && log_error "${funcname}: conlimitperip is not set" && return 1
    [[ -z $conlimitperip ]] && conlimitperip=50
    
    IPTABLE="PREROUTING -p tcp -m connlimit --connlimit-above ${conlimitperip} --connlimit-mask 32 -m comment --comment ${funcname} -j DROP"
    [[ -z ${RULESFILE} ]] && ( iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -A ${IPTABLE} )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t mangle \-A ${IPTABLE}" ${RULESFILE} 1>/dev/null || echo "-t mangle -A ${IPTABLE}" >> "${RULESFILE}" )
}

# Mangle Prerouting : Drop Invalid State
# XTABLES_DROP_INVALID_STATE=1
function __net-xtables_mangle_all_both_dropinvalidstate {
    local funcname="xtmab_dropinvalidstate"

    IPTABLE="PREROUTING -p all -m conntrack --ctstate INVALID -m comment --comment ${funcname} -j DROP"
    [[ -z ${RULESFILE} ]] && ( iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -I ${IPTABLE} )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t mangle \-I ${IPTABLE}" ${RULESFILE} 1>/dev/null || echo "-t mangle -I ${IPTABLE}" >> "${RULESFILE}" )
}

# Mangle Prerouting : Drop new non-SYN TCP Packets
# XTABLES_DROP_NON_SYN=1
function __net-xtables_mangle_all_both_dropnonsyn {
    local funcname="xtmab_dropnonsyn"

    IPTABLE="PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -m comment --comment ${funcname} -j DROP"
    [[ -z ${RULESFILE} ]] && ( iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -I ${IPTABLE} )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t mangle \-I ${IPTABLE}" ${RULESFILE} 1>/dev/null || echo "-t mangle -I ${IPTABLE}" >> "${RULESFILE}" )
}

# Mangle Prerouting : Limit MSS
# XTABLES_LIMIT_MSS=1
function __net-xtables_mangle_all_both_limitmss {
    local funcname="xtmab_limitmss"
    local mss="536:65535" # port range

    IPTABLE="PREROUTING -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss "${mss}" -m comment --comment ${funcname} -j DROP"
    [[ -z ${RULESFILE} ]] && ( iptables -t mangle -S | grep "${funcname}" || iptables -t mangle -I ${IPTABLE} )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t mangle \-I ${IPTABLE}" ${RULESFILE} 1>/dev/null || echo "-t mangle -I ${IPTABLE}" >> "${RULESFILE}" )
}

# Raw Prerouting : Guard Overload Limit UDP PPS
# XTABLES_GUARD_OVERLOAD=1
function __net-xtables_raw_all_both_limitudppps {
    local funcname="xtrab_limitudppps"
    # Safeguard against CPU overload during amplificated DDoS attacks by limiting DNS/NTP packets per second rate (PPS).
    # Limited UDP source ports (against amplification
    local lusp="19,53,123,111,123,137,389,1900,3702,5353"

    IPTABLE="PREROUTING -p udp -m multiport --sports "${lusp}" -m hashlimit --hashlimit-mode srcip,srcport --hashlimit-name ${funcname} --hashlimit-above 256/m -m comment --comment ${funcname} -j DROP"
    [[ -z ${RULESFILE} ]] && ( iptables -t raw -S | grep "${funcname}" || iptables -t raw -A ${IPTABLE} )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t raw \-A ${IPTABLE}" ${RULESFILE} 1>/dev/null || echo "-t raw -A ${IPTABLE}" >> "${RULESFILE}" )
}

# Raw Prerouting : Drop Invalid Tcp Flag
# XTABLES_INVALID_TCPFLAG=1
function __net-xtables_raw_all_both_dropinvtcpflag {
    local funcname="xtrab_dropinvtcpflag"
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

    [[ -z ${RULESFILE} ]] && ( iptables -t raw -S | grep "${funcname}1" || iptables -t raw -A ${IPTABLE1} )
    [[ -z ${RULESFILE} ]] && ( iptables -t raw -S | grep "${funcname}2" || iptables -t raw -A ${IPTABLE2} )
    [[ -z ${RULESFILE} ]] && ( iptables -t raw -S | grep "${funcname}3" || iptables -t raw -A ${IPTABLE3} )
    [[ -z ${RULESFILE} ]] && ( iptables -t raw -S | grep "${funcname}4" || iptables -t raw -A ${IPTABLE4} )
    [[ -z ${RULESFILE} ]] && ( iptables -t raw -S | grep "${funcname}5" || iptables -t raw -A ${IPTABLE5} )
    [[ -z ${RULESFILE} ]] && ( iptables -t raw -S | grep "${funcname}6" || iptables -t raw -A ${IPTABLE6} )
    [[ -z ${RULESFILE} ]] && ( iptables -t raw -S | grep "${funcname}7" || iptables -t raw -A ${IPTABLE7} )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t raw \-A ${IPTABLE1}" ${RULESFILE} 1>/dev/null || echo "-t raw -A ${IPTABLE1}" >> "${RULESFILE}" )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t raw \-A ${IPTABLE2}" ${RULESFILE} 1>/dev/null || echo "-t raw -A ${IPTABLE2}" >> "${RULESFILE}" )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t raw \-A ${IPTABLE3}" ${RULESFILE} 1>/dev/null || echo "-t raw -A ${IPTABLE3}" >> "${RULESFILE}" )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t raw \-A ${IPTABLE4}" ${RULESFILE} 1>/dev/null || echo "-t raw -A ${IPTABLE4}" >> "${RULESFILE}" )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t raw \-A ${IPTABLE5}" ${RULESFILE} 1>/dev/null || echo "-t raw -A ${IPTABLE5}" >> "${RULESFILE}" )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t raw \-A ${IPTABLE6}" ${RULESFILE} 1>/dev/null || echo "-t raw -A ${IPTABLE6}" >> "${RULESFILE}" )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-t raw \-A ${IPTABLE7}" ${RULESFILE} 1>/dev/null || echo "-t raw -A ${IPTABLE7}" >> "${RULESFILE}" )
}

# Filter Input : Drop Port Scanner IP
# XTABLES_GUARD_PORT_SCANNER=1
function __net-xtables_raw_all_both_portscanner {
    SETNAME=XTABLES_GUARD_PORT_SCANNER
    ipset list | grep -q XTABLES_GUARD_PORT_SCANNER || ipset create XTABLES_GUARD_PORT_SCANNER hash:ip family inet hashsize 32768 maxelem 65536 timeout 600
    ipset list | grep -q XTABLES_GUARD_SCANNED_PORTS || ipset create XTABLES_GUARD_SCANNED_PORTS hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60

    IPTABLE1='INPUT -m state --state INVALID -m comment --comment XTABLES_GUARD_PORT_SCANNER1 -j DROP'
    IPTABLE2='INPUT -m state --state NEW -m set ! --match-set XTABLES_GUARD_SCANNED_PORTS src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name XTABLES_GUARD_PORT_SCANNER --hashlimit-htable-expire 10000 -j SET --add-set XTABLES_GUARD_PORT_SCANNER src --exist'
    IPTABLE3='INPUT -m state --state NEW -m set --match-set XTABLES_GUARD_PORT_SCANNER src -j DROP'
    IPTABLE4='INPUT -m state --state NEW -j SET --add-set XTABLES_GUARD_SCANNED_PORTS src,dst'

    [[ -z ${RULESFILE} ]] && ( iptables -S | grep "XTABLES_GUARD_PORT_SCANNER1" || iptables -A ${IPTABLE1} )
    [[ -z ${RULESFILE} ]] && ( iptables -S | grep -- "-A ${IPTABLE}2" || iptables -A ${IPTABLE2} )
    [[ -z ${RULESFILE} ]] && ( iptables -S | grep -- "-A ${IPTABLE}3" || iptables -A ${IPTABLE3} )
    [[ -z ${RULESFILE} ]] && ( iptables -S | grep -- "-A ${IPTABLE}4" || iptables -A ${IPTABLE4} )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-A ${IPTABLE1}" ${RULESFILE} 1>/dev/null || echo "-A ${IPTABLE1}" >> "${RULESFILE}" )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-A ${IPTABLE2}" ${RULESFILE} 1>/dev/null || echo "-A ${IPTABLE2}" >> "${RULESFILE}" )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-A ${IPTABLE3}" ${RULESFILE} 1>/dev/null || echo "-A ${IPTABLE3}" >> "${RULESFILE}" )
    [[ -n ${RULESFILE} ]] && ( grep -c "\-A ${IPTABLE4}" ${RULESFILE} 1>/dev/null || echo "-A ${IPTABLE4}" >> "${RULESFILE}" )
}

# Filter Input : CHAOS responses to confuse attackers
# XTABLES_CHAOS_PORTS="22,23,80,443"
function __net-xtables_filter_all_both_chaos {
    local funcname="xtfab_chaos"
    local chaos_ports
    chaos_ports=$(_trim_string "${XTABLES_CHAOS_PORTS}")
    [[ ${#chaos_ports} -lt 1 ]] && log_error "${funcname}: chaos_ports is not set" && return 1
    
    # Apply CHAOS to specified ports
    IFS=',' read -ra ports <<< "${chaos_ports}"
    for port in "${ports[@]}"; do
        IPTABLE="INPUT -p tcp --dport ${port} -m comment --comment ${funcname}_${port} -j CHAOS --tarpit" #  --delude
        [[ -z ${RULESFILE} ]] && ( iptables -S | grep "${funcname}_${port}" || iptables -A ${IPTABLE} )
        [[ -n ${RULESFILE} ]] && ( grep -c "\-A ${IPTABLE}" ${RULESFILE} 1>/dev/null || echo "-A ${IPTABLE}" >> "${RULESFILE}" )
    done
}

# Filter Input : DELUDE responses to make closed ports appear open
# XTABLES_DELUDE_PORTS="22,23,80,443,21,25,53,110,143,993,995"
function __net-xtables_filter_all_both_delude {
    local funcname="fab_delude"
    local delude_ports
    delude_ports=$(_trim_string "${XTABLES_DELUDE_PORTS}")
    [[ ${#delude_ports} -lt 1 ]] && log_error "${funcname}: delude_ports is not set" && return 1
    
    # Apply DELUDE to specified ports
    IFS=',' read -ra ports <<< "${delude_ports}"
    for port in "${ports[@]}"; do
        IPTABLE="INPUT -p tcp --dport ${port} -m comment --comment ${funcname}_${port} -j DELUDE"
        [[ -z ${RULESFILE} ]] && ( iptables -S | grep "${funcname}_${port}" || iptables -A ${IPTABLE} )
        [[ -n ${RULESFILE} ]] && ( grep -c "\-A ${IPTABLE}" ${RULESFILE} 1>/dev/null || echo "-A ${IPTABLE}" >> "${RULESFILE}" )
    done
}

# Filter Input : Database Port Knocking with Logging
# XTABLES_PKNOCK_PORTS="3001,3002,3003" XTABLES_PKNOCK_OPEN_PORT="3306" XTABLES_PKNOCK_TIMEOUT="20"
function __net-xtables_filter_all_inc_pknock_db {
    local funcname="fai_pknock_db"
    local knock_ports=${XTABLES_PKNOCK_PORTS}
    local db_port=${XTABLES_PKNOCK_OPEN_PORT}
    local timeout=${XTABLES_PKNOCK_TIMEOUT}
    
    # Parse knock ports
    IFS=',' read -ra KNOCK_ARRAY <<< "$knock_ports"
    
    # Set up database knocking sequence with logging
    local i=1
    for port in "${KNOCK_ARRAY[@]}"; do
        # Log knock attempts
        IPTABLE_LOG="INPUT -p tcp --dport ${port} -m pknock --knockports ${knock_ports} --name db_knock --time ${timeout} -m comment --comment ${funcname}_log${i} -j LOG --log-prefix 'DB_KNOCK_${i}: '"
        iptables -S | grep "${funcname}_log${i}" || iptables -A $IPTABLE_LOG
        
        # Accept knock
        IPTABLE="INPUT -p tcp --dport ${port} -m pknock --knockports ${knock_ports} --name db_knock --time ${timeout} -m comment --comment ${funcname}${i} -j ACCEPT"
        iptables -S | grep "${funcname}${i}" || iptables -A $IPTABLE
        ((i++))
    done
    
    # Log successful database access
    IPTABLE_DB_LOG="INPUT -p tcp --dport ${db_port} -m pknock --checkknock db_knock -m comment --comment ${funcname}_db_log -j LOG --log-prefix 'DB_ACCESS_GRANTED: '"
    iptables -S | grep "${funcname}_db_log" || iptables -A $IPTABLE_DB_LOG
    
    # Allow database access after successful knock
    IPTABLE_DB="INPUT -p tcp --dport ${db_port} -m pknock --checkknock db_knock -m comment --comment ${funcname}_db -j ACCEPT"
    iptables -S | grep "${funcname}_db" || iptables -A $IPTABLE_DB
}

complete -F _blank net-xtables

# https://codeberg.org/jengelh/xtables-addons
# xtables-common - shared libs
# xtables-dkms - kernel modules
# libxt_ACCOUNT.so # sed for counting packets
# > iptables -A OUTPUT -j ACCOUNT --addr 0.0.0.0/0 --tname all_outgoing
# > iptcount -a -l all_outgoing
# > iptables -A FORWARD -j ACCOUNT --addr 192.168.1.0/24 --tname lan_traffic
# > iptables -A INPUT -j ACCOUNT --addr 0.0.0.0/0 --tname incoming_traffic
# > iptables -A OUTPUT -j ACCOUNT --addr 0.0.0.0/0 --tname outgoing_traffic

# libxt_CHAOS.so # CHAOS will randomly reply (or not) with one of its configurable subtargets
# > iptables -A INPUT -p tcp --dport 22 -j CHAOS --delude
# > iptables -A INPUT -p tcp --dport 23 -j CHAOS --tarpit
# > iptables -A INPUT -p tcp --dport 80 -j CHAOS --tarpit --reject

# libxt_DELUDE.so # The DELUDE target will reply to a SYN packet with SYN-ACK, and to all other packets with an RST
# # Make a closed port appear open
# > iptables -A INPUT -p tcp --dport 22 -j DELUDE
# # Delude a range of ports
# > iptables -A INPUT -p tcp --dport 1000:2000 -j DELUDE
# # Delude common service ports
# > iptables -A INPUT -p tcp -m multiport --dports 21,22,23,25,53,80,110,143,443,993,995 -j DELUDE

# libxt_DHCPMAC.so # completely change all MAC addresses from and to a VMware-based virtual machine
# libxt_dhcpmac.so # Matches the DHCP "Client Host" address (a MAC address) in a DHCP message
# # Change MAC addresses for VMware VMs
# > iptables -t mangle -A PREROUTING -j DHCPMAC
# # Block DHCP requests from specific MAC
# > iptables -A INPUT -p udp --dport 67 -m dhcpmac --mac 00:11:22:33:44:56 -j DROP

# libxt_DNETMAP.so #  allows dynamic two-way 1:1 mapping of IPv4 subnets
# # Map internal subnet to external subnet
# > iptables -t nat -A PREROUTING -d 203.0.113.0/24 -j DNETMAP --to 192.168.1.0/24
# # Map different internal subnets to different external subnets
# > iptables -t nat -A PREROUTING -d 203.0.113.0/24 -j DNETMAP --to 192.168.1.0/24
# > iptables -t nat -A PREROUTING -d 198.51.100.0/24 -j DNETMAP --to 192.168.2.0/24
# > iptables -t nat -A PREROUTING -d 192.0.2.0/24 -j DNETMAP --to 192.168.3.0/24

# libxt_ECHO.so # will send back all packets it received
# # Echo all packets back to sender
# iptables -A INPUT -j ECHO
# # Echo packets on port range
# iptables -A INPUT -p tcp --dport 8000:8999 -j ECHO

# libxt_IPMARK.so # mark a received packet basing on its IP address
# # Mark packets based on source IP address
# > iptables -t mangle -A PREROUTING -j IPMARK --addr src
# # Mark packets going out specific interface
# > iptables -t mangle -A POSTROUTING -o eth0 -j IPMARK --addr dst

# libxt_LOGMARK.so #  will log packet and connection marks to syslog
# # Log marks with specific log level
# > iptables -t mangle -A PREROUTING -j LOGMARK --log-level 4

# libxt_PROTO.so # modifies the protocol number in IP packet header
# # Change protocol to ICMP
# > iptables -t mangle -A PREROUTING -p tcp --dport 80 -j PROTO --proto icmp
# # Modify protocols on specific interfaces
# > iptables -t mangle -A PREROUTING -i eth0 -p tcp -j PROTO --proto udp

# libxt_SYSRQ.so # allows one to remotely trigger sysrq on the local machine over the network
# # Enable SYSRQ for emergency remote reboot
# > iptables -A INPUT -p icmp --icmp-type 8 -s 192.168.1.100 -j SYSRQ --password "emergency123" --hash sha1
# # Enable SYSRQ for system information via TCP
# > iptables -A INPUT -p tcp --dport 9999 -s 192.168.1.0/24 -j SYSRQ --password "sysinfo456" --hash md5
# # Rate-limited SYSRQ to prevent abuse
# > iptables -A INPUT -p icmp --icmp-type 8 -s 192.168.1.100 -m limit --limit 1/min --limit-burst 3 -j SYSRQ --password "limited_sysrq" --hash sha1
# # Time-based SYSRQ access
# > iptables -A INPUT -p tcp --dport 9999 -s 192.168.1.0/24 -m time --timestart 09:00 --timestop 17:00 -j SYSRQ --password "business_hours" --hash sha256

# libxt_TARPIT.so # Captures and holds incoming TCP connections using no local per-connection resources
# # Basic TARPIT - trap all incoming connections on port 23 (telnet)
# > iptables -A INPUT -p tcp --dport 23 -j TARPIT
# # TARPIT with rate limiting to prevent resource exhaustion
# > iptables -A INPUT -p tcp --dport 22 -m limit --limit 3/min --limit-burst 5 -j TARPIT
# > iptables -A INPUT -p tcp --dport 22 -j DROP
# # TARPIT for specific source networks
# > iptables -A INPUT -s 192.168.100.0/24 -p tcp --dport 80 -j TARPIT
# # TARPIT with time-based restrictions
# > iptables -A INPUT -p tcp --dport 80 -m time --timestart 02:00 --timestop 06:00 -j TARPIT
# # TARPIT for port ranges (honeypot services)
# > iptables -A INPUT -p tcp --dport 8000:8999 -j TARPIT
# > iptables -A INPUT -p tcp --dport 9000:9999 -j TARPIT

# libxt_asn.so # Match a packet by its source or destination autonomous system number (ASN)
# # Block traffic from multiple ASNs
# > iptables -A INPUT -m asn --src-asn 64512,64513,64514 -j DROP
# # Allow traffic from specific ASN ranges
# > iptables -A INPUT -m asn --src-asn 64496-64511 -j ACCEPT
# # Block traffic from ASNs in a file
# > iptables -A INPUT -m asn --src-asn-file /etc/blocked-asns.txt -j DROP
# # Block HTTP traffic from specific ASN
# > iptables -A INPUT -p tcp --dport 80 -m asn --src-asn 64512 -j DROP
# # Block SSH from specific ASNs
# > iptables -A INPUT -p tcp --dport 22 -m asn --src-asn 64513,64514 -j DROP

# libxt_condition.so # This matches if a specific condition variable is (un)set
# # Enable rule only when a specific file exists
# > iptables -A INPUT -p tcp --dport 22 -m condition --condition ssh_enabled -j ACCEPT
# # Create condition file
# > echo 1 > /proc/net/xt_condition/ssh_enabled
# # Disable condition
# > echo 0 > /proc/net/xt_condition/ssh_enabled
# # Allow traffic only during maintenance window
# > iptables -A INPUT -p tcp --dport 80 -m condition --condition maintenance_mode -j DROP
# # Enable maintenance mode
# > echo 1 > /proc/net/xt_condition/maintenance_mode
# # Disable maintenance mode  
# > echo 0 > /proc/net/xt_condition/maintenance_mode
# # Dynamically controlled SSH access
# > iptables -A INPUT -p tcp --dport 22 -m condition --condition ssh_allowed -j ACCEPT
# > iptables -A INPUT -p tcp --dport 22 -j DROP
# # Allow SSH temporarily
# > echo 1 > /proc/net/xt_condition/ssh_allowed
# > sleep 3600  # Allow for 1 hour
# > echo 0 > /proc/net/xt_condition/ssh_allowed
# # Combine with rate limiting
# > iptables -A INPUT -p tcp --dport 80 -m condition --condition rate_limit_enabled -m limit --limit 10/sec -j ACCEPT
# > iptables -A INPUT -p tcp --dport 80 -m condition --condition rate_limit_enabled -j DROP
# > iptables -A INPUT -p tcp --dport 80 -j ACCEPT
# # Enable rate limiting during attacks
# > echo 1 > /proc/net/xt_condition/rate_limit_enabled

# libxt_fuzzy.so # This module matches a rate limit based on a fuzzy logic controller (FLC)
# # Basic fuzzy rate limiting
# > iptables -A INPUT -p tcp --dport 80 -m fuzzy --lower-limit 10 --upper-limit 100 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 80 -j DROP
# # SSH brute force protection with fuzzy logic
# > iptables -A INPUT -p tcp --dport 22 -m fuzzy --lower-limit 3 --upper-limit 20 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 22 -j DROP
# # Web server protection with fuzzy rate control
# > iptables -A INPUT -p tcp --dport 443 -m fuzzy --lower-limit 50 --upper-limit 500 -j ACCEPT
# # DNS query rate limiting
# > iptables -A INPUT -p udp --dport 53 -m fuzzy --lower-limit 20 --upper-limit 200 -j ACCEPT
# > iptables -A INPUT -p udp --dport 53 -j DROP
# # SMTP rate limiting with fuzzy logic
# > iptables -A INPUT -p tcp --dport 25 -m fuzzy --lower-limit 5 --upper-limit 50 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 25 -j REJECT
# # API endpoint protection
# > iptables -A INPUT -p tcp --dport 8080 -m fuzzy --lower-limit 30 --upper-limit 300 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 8080 -j DROP
# # Time-based fuzzy rate limiting
# > iptables -A INPUT -p tcp --dport 80 -m time --timestart 09:00 --timestop 17:00 -m fuzzy --lower-limit 100 --upper-limit 1000 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 80 -m time --timestart 17:00 --timestop 09:00 -m fuzzy --lower-limit 20 --upper-limit 200 -j ACCEPT
# # Source-based fuzzy rate limiting
# > iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport 80 -m fuzzy --lower-limit 50 --upper-limit 500 -j ACCEPT
# > iptables -A INPUT -s 10.0.0.0/8 -p tcp --dport 80 -m fuzzy --lower-limit 10 --upper-limit 100 -j ACCEPT
# # Combined with connection tracking
# > iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m fuzzy --lower-limit 20 --upper-limit 200 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# libxt_geoip.so # Match a packet by its source or destination country
# # Block traffic from specific countries
# > iptables -A INPUT -m geoip --src-cc CN,RU,KP -j DROP
# # Allow traffic only from specific countries
# > iptables -A INPUT -m geoip --src-cc US,CA,GB,DE,FR -j ACCEPT
# > iptables -A INPUT -j DROP
# # Block SSH access from high-risk countries
# > iptables -A INPUT -p tcp --dport 22 -m geoip --src-cc CN,RU,KP,IR -j DROP
# # Allow HTTP/HTTPS only from specific regions
# > iptables -A INPUT -p tcp --dport 80 -m geoip --src-cc US,CA,MX -j ACCEPT
# > iptables -A INPUT -p tcp --dport 443 -m geoip --src-cc US,CA,MX -j ACCEPT
# # Block outgoing traffic to specific countries
# > iptables -A OUTPUT -m geoip --dst-cc CN,RU -j DROP
# # Allow SMTP only from trusted countries
# > iptables -A INPUT -p tcp --dport 25 -m geoip --src-cc US,CA,GB,DE,FR -j ACCEPT
# > iptables -A INPUT -p tcp --dport 25 -j DROP
# # Block countries with inverted match (allow all except specified)
# > iptables -A INPUT -m geoip ! --src-cc US,CA -j DROP
# # Time-based geo-blocking
# > iptables -A INPUT -p tcp --dport 80 -m time --timestart 02:00 --timestop 06:00 -m geoip --src-cc CN,RU -j DROP
# # Rate limit by country
# > iptables -A INPUT -p tcp --dport 80 -m geoip --src-cc CN -m limit --limit 5/sec -j ACCEPT
# > iptables -A INPUT -p tcp --dport 80 -m geoip --src-cc CN -j DROP
# # Block specific services by country
# > iptables -A INPUT -p tcp --dport 3389 -m geoip --src-cc CN,RU,KP -j DROP  # RDP
# > iptables -A INPUT -p tcp --dport 5900 -m geoip --src-cc CN,RU,KP -j DROP  # VNC
# # Allow database access only from specific countries
# > iptables -A INPUT -p tcp --dport 3306 -m geoip --src-cc US,CA -j ACCEPT
# > iptables -A INPUT -p tcp --dport 3306 -j DROP
# # Block P2P traffic from specific countries
# > iptables -A INPUT -p tcp --dport 6881:6999 -m geoip --src-cc CN,RU -j DROP
# # Allow VPN access only from trusted countries
# > iptables -A INPUT -p udp --dport 1194 -m geoip --src-cc US,CA,GB,DE,FR -j ACCEPT
# > iptables -A INPUT -p udp --dport 1194 -j DROP
# # Log and block suspicious countries
# > iptables -A INPUT -p tcp --dport 22 -m geoip --src-cc CN,RU,KP -j LOG --log-prefix "GEO-BLOCK: "
# > iptables -A INPUT -p tcp --dport 22 -m geoip --src-cc CN,RU,KP -j DROP

# libxt_gradm.so # This module matches packets based on grsecurity RBAC status
# ** outdated **

# libxt_iface.so # allows you to check interface states.
# # Block traffic when interface is down
# > iptables -A INPUT -m iface --iface eth0 --up -j ACCEPT
# > iptables -A INPUT -m iface --iface eth0 --down -j DROP
# # Allow traffic only when WAN interface is up
# > iptables -A FORWARD -m iface --iface eth0 --up -j ACCEPT
# > iptables -A FORWARD -j DROP
# # Block outgoing traffic when backup interface is down
# > iptables -A OUTPUT -m iface --iface eth1 --down -j DROP
# # Load balancing based on interface state
# > iptables -A OUTPUT -m iface --iface eth0 --up -j ACCEPT
# > iptables -A OUTPUT -m iface --iface eth1 --up -j ACCEPT
# > iptables -A OUTPUT -j DROP
# # Failover routing control
# > iptables -t mangle -A OUTPUT -m iface --iface eth0 --up -j MARK --set-mark 1
# > iptables -t mangle -A OUTPUT -m iface --iface eth1 --up -j MARK --set-mark 2
# # VPN tunnel state monitoring
# > iptables -A INPUT -m iface --iface tun0 --up -j ACCEPT
# > iptables -A INPUT -m iface --iface tun0 --down -j LOG --log-prefix "VPN-DOWN: "
# # Wireless interface state control
# > iptables -A INPUT -m iface --iface wlan0 --up -j ACCEPT
# > iptables -A INPUT -m iface --iface wlan0 --down -j DROP
# # Bridge interface monitoring
# > iptables -A FORWARD -m iface --iface br0 --up -j ACCEPT
# > iptables -A FORWARD -m iface --iface br0 --down -j DROP
# # VLAN interface state checking
# > iptables -A INPUT -m iface --iface eth0.100 --up -j ACCEPT
# > iptables -A INPUT -m iface --iface eth0.100 --down -j DROP
# # Bond interface failover
# > iptables -A OUTPUT -m iface --iface bond0 --up -j ACCEPT
# > iptables -A OUTPUT -m iface --iface bond0 --down -j DROP
# # PPP interface state monitoring
# > iptables -A INPUT -m iface --iface ppp0 --up -j ACCEPT
# > iptables -A INPUT -m iface --iface ppp0 --down -j REJECT
# # Container interface state
# > iptables -A FORWARD -m iface --iface docker0 --up -j ACCEPT
# > iptables -A FORWARD -m iface --iface docker0 --down -j DROP
# # Time-based interface monitoring
# > iptables -A INPUT -m time --timestart 09:00 --timestop 17:00 -m iface --iface eth0 --up -j ACCEPT
# > iptables -A INPUT -m time --timestart 17:00 --timestop 09:00 -m iface --iface eth1 --up -j ACCEPT
# # Multi-interface redundancy
# > iptables -A OUTPUT -m iface --iface eth0 --up -j ACCEPT
# > iptables -A OUTPUT -m iface --iface eth1 --up -j ACCEPT
# > iptables -A OUTPUT -m iface --iface eth2 --up -j ACCEPT
# > iptables -A OUTPUT -j DROP
# # Log interface state changes
# > iptables -A INPUT -m iface --iface eth0 --down -j LOG --log-prefix "ETH0-DOWN: "
# > iptables -A INPUT -m iface --iface eth0 --up -j LOG --log-prefix "ETH0-UP: "

# libxt_ipp2p.so # This module matches certain packets in P2P flows. 
# # Block all P2P traffic
# > iptables -A FORWARD -m ipp2p --ipp2p -j DROP
# # Block specific P2P protocols
# > iptables -A FORWARD -m ipp2p --bit -j DROP
# > iptables -A FORWARD -m ipp2p --edk -j DROP
# > iptables -A FORWARD -m ipp2p --kazaa -j DROP
# > iptables -A FORWARD -m ipp2p --gnu -j DROP
# # Rate limit P2P traffic
# > iptables -A FORWARD -m ipp2p --ipp2p -m limit --limit 50/sec -j ACCEPT
# > iptables -A FORWARD -m ipp2p --ipp2p -j DROP
# # Time-based P2P blocking
# > iptables -A FORWARD -m ipp2p --ipp2p -m time --timestart 09:00 --timestop 17:00 -j DROP
# > iptables -A FORWARD -m ipp2p --ipp2p -m time --timestart 17:00 --timestop 09:00 -j ACCEPT
# # Block P2P on specific interfaces
# > iptables -A FORWARD -i eth0 -m ipp2p --ipp2p -j DROP
# > iptables -A FORWARD -o eth0 -m ipp2p --ipp2p -j DROP
# # Log P2P traffic before blocking
# > iptables -A FORWARD -m ipp2p --ipp2p -j LOG --log-prefix "P2P-BLOCK: "
# > iptables -A FORWARD -m ipp2p --ipp2p -j DROP
# # Block BitTorrent specifically
# > iptables -A FORWARD -m ipp2p --bit -j DROP
# > iptables -A FORWARD -p tcp --dport 6881:6999 -j DROP
# # Block eMule/eDonkey
# > iptables -A FORWARD -m ipp2p --edk -j DROP
# > iptables -A FORWARD -p tcp --dport 4661:4662 -j DROP
# # Block Kazaa/FastTrack
# > iptables -A FORWARD -m ipp2p --kazaa -j DROP
# > iptables -A FORWARD -p tcp --dport 1214 -j DROP
# # Block Gnutella
# > iptables -A FORWARD -m ipp2p --gnu -j DROP
# > iptables -A FORWARD -p tcp --dport 6346 -j DROP
# # QoS for P2P traffic (mark for low priority)
# > iptables -t mangle -A FORWARD -m ipp2p --ipp2p -j MARK --set-mark 3
# > iptables -t mangle -A FORWARD -m ipp2p --ipp2p -j DSCP --set-dscp 8
# # Allow P2P for specific users/IPs
# > iptables -A FORWARD -s 192.168.1.100 -m ipp2p --ipp2p -j ACCEPT
# > iptables -A FORWARD -m ipp2p --ipp2p -j DROP
# # Block P2P on WAN interface only
# > iptables -A FORWARD -i eth0 -m ipp2p --ipp2p -j DROP
# > iptables -A FORWARD -o eth0 -m ipp2p --ipp2p -j DROP
# # Bandwidth limiting for P2P
# > iptables -A FORWARD -m ipp2p --ipp2p -m hashlimit --hashlimit-mode srcip --hashlimit-name p2p_limit --hashlimit-above 1024/sec -j DROP
# # Block P2P except during off-hours
# > iptables -A FORWARD -m ipp2p --ipp2p -m time --timestart 08:00 --timestop 18:00 -j DROP
# # Log different P2P protocols separately
# > iptables -A FORWARD -m ipp2p --bit -j LOG --log-prefix "BITTORRENT: "
# > iptables -A FORWARD -m ipp2p --edk -j LOG --log-prefix "EDONKEY: "
# > iptables -A FORWARD -m ipp2p --kazaa -j LOG --log-prefix "KAZAA: "
# > iptables -A FORWARD -m ipp2p --gnu -j LOG --log-prefix "GNUTELLA: "
# # Country-based P2P blocking
# > iptables -A FORWARD -m ipp2p --ipp2p -m geoip --src-cc CN,RU -j DROP
# # Combined P2P and port blocking
# > iptables -A FORWARD -m ipp2p --ipp2p -j DROP
# > iptables -A FORWARD -p tcp --dport 6881:6999 -j DROP
# > iptables -A FORWARD -p tcp --dport 4661:4662 -j DROP
# # User-specific P2P policies
# > iptables -A FORWARD -s 192.168.1.0/24 -m ipp2p --ipp2p -m limit --limit 10/sec -j ACCEPT
# > iptables -A FORWARD -s 192.168.2.0/24 -m ipp2p --ipp2p -j DROP

# libxt_ipv4options.so # The "ipv4options" module allows one to match against a set of IPv4 header options.
# # Block packets with specific IPv4 options
# > iptables -A INPUT -m ipv4options --ssrr -j DROP
# > iptables -A INPUT -m ipv4options --lsrr -j DROP
# > iptables -A INPUT -m ipv4options --rr -j DROP
# # Block packets with timestamp option
# > iptables -A INPUT -m ipv4options --ts -j DROP
# # Block packets with router alert option
# > iptables -A INPUT -m ipv4options --ra -j DROP
# # Log and block source routing attacks
# > iptables -A INPUT -m ipv4options --ssrr -j LOG --log-prefix "SSRR-ATTACK: "
# > iptables -A INPUT -m ipv4options --ssrr -j DROP
# > iptables -A INPUT -m ipv4options --lsrr -j LOG --log-prefix "LSRR-ATTACK: "
# > iptables -A INPUT -m ipv4options --lsrr -j DROP
# # Block packets with any IP options
# > iptables -A INPUT -m ipv4options --any-opt -j DROP
# # Allow only specific IP options
# > iptables -A INPUT -m ipv4options --any-opt -j DROP
# > iptables -A INPUT -j ACCEPT
# # Block IP options on WAN interface
# > iptables -A INPUT -i eth0 -m ipv4options --any-opt -j DROP
# # Rate limit packets with IP options
# > iptables -A INPUT -m ipv4options --any-opt -m limit --limit 5/min -j LOG --log-prefix "IP-OPTIONS: "
# > iptables -A INPUT -m ipv4options --any-opt -j DROP
# # Block specific combinations of options
# > iptables -A INPUT -m ipv4options --ssrr --ts -j DROP
# > iptables -A INPUT -m ipv4options --lsrr --rr -j DROP
# # Security audit - log all IP options
# > iptables -A INPUT -m ipv4options --ssrr -j LOG --log-prefix "IP-SSRR: "
# > iptables -A INPUT -m ipv4options --lsrr -j LOG --log-prefix "IP-LSRR: "
# > iptables -A INPUT -m ipv4options --rr -j LOG --log-prefix "IP-RR: "
# > iptables -A INPUT -m ipv4options --ts -j LOG --log-prefix "IP-TS: "
# > iptables -A INPUT -m ipv4options --ra -j LOG --log-prefix "IP-RA: "
# # Block IP options from specific networks
# > iptables -A INPUT -s 192.168.1.0/24 -m ipv4options --any-opt -j DROP
# > iptables -A INPUT -s 10.0.0.0/8 -m ipv4options --any-opt -j DROP
# # Time-based IP options blocking
# > iptables -A INPUT -m ipv4options --any-opt -m time --timestart 00:00 --timestop 06:00 -j DROP
# # Allow IP options for specific services
# > iptables -A INPUT -p tcp --dport 22 -m ipv4options --any-opt -j DROP
# > iptables -A INPUT -p tcp --dport 80 -m ipv4options --any-opt -j DROP
# # Block malformed IP options
# > iptables -A INPUT -m ipv4options --any-opt -m length --length 0:39 -j DROP
# # Forward chain IP options control
# > iptables -A FORWARD -m ipv4options --any-opt -j DROP
# # Country-based IP options blocking
# > iptables -A INPUT -m ipv4options --any-opt -m geoip --src-cc CN,RU -j DROP
# # QoS marking for packets with IP options
# > iptables -t mangle -A PREROUTING -m ipv4options --any-opt -j MARK --set-mark 10
# > iptables -t mangle -A PREROUTING -m ipv4options --any-opt -j DSCP --set-dscp 0

# libxt_length2.so # This module matches the length of a packet against a specific value or range of values.
# # Match packets of exactly 1500 bytes (typical MTU)
# > iptables -A FORWARD -m length2 --length 1500 -j LOG --log-prefix "MTU_PACKET: "
# # Match packets between 100-500 bytes
# > iptables -A INPUT -m length2 --length 100:500 -j ACCEPT
# # Drop oversized packets (potential DoS)
# > iptables -A INPUT -m length2 --length 9000: -j DROP
# # Rate limit small packets (potential ping flood)
# > iptables -A INPUT -m length2 --length :64 -m limit --limit 10/sec -j ACCEPT
# > iptables -A INPUT -m length2 --length :64 -j DROP
# # Allow only standard HTTP request sizes
# > iptables -A INPUT -p tcp --dport 80 -m length2 --length 100:8192 -j ACCEPT
# # Block suspiciously large DNS queries
# > iptables -A INPUT -p udp --dport 53 -m length2 --length 512: -j DROP
# # Mark large packets for different QoS treatment
# > iptables -t mangle -A PREROUTING -m length2 --length 1000: -j MARK --set-mark 1
# # Shape traffic based on packet size
# > iptables -t mangle -A POSTROUTING -m length2 --length :500 -j DSCP --set-dscp 10
# > iptables -t mangle -A POSTROUTING -m length2 --length 500: -j DSCP --set-dscp 20

# libxt_lscan.so # Detects simple low-level scan attempts based upon the packet's contents.
# # Block packets detected as scan attempts
# > iptables -A INPUT -m lscan -j DROP
# # Log scan attempts before dropping
# > iptables -A INPUT -m lscan -j LOG --log-prefix "SCAN_DETECTED: "
# > iptables -A INPUT -m lscan -j DROP
# # Monitor scans on WAN interface
# > iptables -A INPUT -i eth0 -m lscan -j LOG --log-prefix "WAN_SCAN: "
# > iptables -A INPUT -i eth0 -m lscan -j DROP
# # Rate limit scan detection logging to prevent log flooding
# > iptables -A INPUT -m lscan -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "SCAN_RATE_LIMITED: "
# > iptables -A INPUT -m lscan -j DROP
# # Time-based scan monitoring
# > iptables -A INPUT -m lscan -m time --timestart 22:00 --timestop 06:00 -j LOG --log-prefix "NIGHT_SCAN: "
# > iptables -A INPUT -m lscan -j DROP
# # Block scans from specific countries
# > iptables -A INPUT -m lscan -m geoip --src-cc CN,RU,KP -j DROP
# # Rate limit scan attempts per IP
# > iptables -A INPUT -m lscan -m hashlimit --hashlimit-mode srcip --hashlimit-name scan_limit --hashlimit-above 3/hour -j DROP
# # Monitor scans on new connections only
# > iptables -A INPUT -m conntrack --ctstate NEW -m lscan -j LOG --log-prefix "NEW_CONN_SCAN: "
# > iptables -A INPUT -m conntrack --ctstate NEW -m lscan -j DROP
# # Allow established connections even if they trigger scan detection
# > iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# > iptables -A INPUT -m lscan -j DROP

# # libxt_pknock.so # Pknock match implements so-called "port knocking", a stealthy system
# # Create a port knocking sequence: knock on ports 1001, 1002, 1003 to open SSH
# > iptables -A INPUT -p tcp --dport 1001 -m pknock --knockports 1001,1002,1003 --name ssh_knock --time 10 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 1002 -m pknock --knockports 1001,1002,1003 --name ssh_knock --time 10 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 1003 -m pknock --knockports 1001,1002,1003 --name ssh_knock --time 10 -j ACCEPT
# # Allow SSH access after successful knock sequence
# > iptables -A INPUT -p tcp --dport 22 -m pknock --checkknock ssh_knock -j ACCEPT
# # SSH access with complex knocking sequence
# > iptables -A INPUT -p tcp --dport 2001 -m pknock --knockports 2001,2002,2003,2004 --name ssh_secure --time 15 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 2002 -m pknock --knockports 2001,2002,2003,2004 --name ssh_secure --time 15 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 2003 -m pknock --knockports 2001,2002,2003,2004 --name ssh_secure --time 15 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 2004 -m pknock --knockports 2001,2002,2003,2004 --name ssh_secure --time 15 -j ACCEPT
# > iptables -A INPUT -p tcp --dport 22 -m pknock --checkknock ssh_secure -j ACCEPT
# # Allow port knocking only during specific hours
# > iptables -A INPUT -p tcp --dport 4001 -m time --timestart 09:00 --timestop 17:00 -m pknock --knockports 4001,4002 --name work_hours --time 30 -j ACCEPT
# # Allow port knocking only from specific countries
# > iptables -A INPUT -p tcp --dport 5001 -m geoip --src-cc US,CA -m pknock --knockports 5001,5002,5003 --name geo_knock --time 10 -j ACCEPT
# # Prevent brute force attacks on knocking sequence
# > iptables -A INPUT -p tcp --dport 6001 -m limit --limit 3/min -m pknock --knockports 6001,6002 --name rate_knock --time 5 -j ACCEPT

# # libxt_psd.so # Attempt to detect TCP and UDP port scans.
# # Detect and block TCP port scans
# > iptables -A INPUT -p tcp -m psd --psd-weight-threshold 21 --psd-delay-threshold 300 --psd-lo-ports-weight 3 --psd-hi-ports-weight 1 -j DROP
# # Detect and block UDP port scans
# > iptables -A INPUT -p udp -m psd --psd-weight-threshold 21 --psd-delay-threshold 300 --psd-lo-ports-weight 3 --psd-hi-ports-weight 1 -j DROP
# # Monitor scans on WAN interface only
# > iptables -A INPUT -i eth0 -p tcp -m psd --psd-weight-threshold 15 --psd-delay-threshold 200 --psd-lo-ports-weight 3 --psd-hi-ports-weight 1 -j LOG --log-prefix "WAN_TCP_SCAN: "
# > iptables -A INPUT -i eth0 -p tcp -m psd --psd-weight-threshold 15 --psd-delay-threshold 200 --psd-lo-ports-weight 3 --psd-hi-ports-weight 1 -j DROP
# # More sensitive detection for high-value ports
# > iptables -A INPUT -p tcp -m psd --psd-weight-threshold 12 --psd-delay-threshold 150 --psd-lo-ports-weight 5 --psd-hi-ports-weight 1 -j LOG --log-prefix "SENSITIVE_SCAN: "
# > iptables -A INPUT -p tcp -m psd --psd-weight-threshold 12 --psd-delay-threshold 150 --psd-lo-ports-weight 5 --psd-hi-ports-weight 1 -j DROP
# # Less sensitive detection to avoid false positives
# > iptables -A INPUT -p tcp -m psd --psd-weight-threshold 30 --psd-delay-threshold 500 --psd-lo-ports-weight 2 --psd-hi-ports-weight 1 -j LOG --log-prefix "SCAN_MODERATE: "
# > iptables -A INPUT -p tcp -m psd --psd-weight-threshold 30 --psd-delay-threshold 500 --psd-lo-ports-weight 2 --psd-hi-ports-weight 1 -j DROP

# libxt_quota2.so # a named counter which can be increased or decreased on a per-match basis. Available modes are packet counting or byte counting.
# # Set a 1GB download quota for a specific user
# > iptables -A OUTPUT -m owner --uid-owner 1000 -m quota2 --name "user1000_download" --quota 1073741824 -j ACCEPT
# # Block traffic after quota is exceeded
# > iptables -A OUTPUT -m owner --uid-owner 1000 -m quota2 --name "user1000_download" --quota 0 -j DROP
# # Set packet count quota (1000 packets)
# > iptables -A INPUT -s 192.168.1.100 -m quota2 --name "host100_packets" --quota 1000 --packet-count -j ACCEPT
# # Rate limiting with quota
# > iptables -A INPUT -p tcp --dport 80 -m quota2 --name "web_hourly" --quota 104857600 -j ACCEPT
# >iptables -A INPUT -p tcp --dport 80 -m quota2 --name "web_hourly" --quota 0 -j TARPIT
# # DDoS protection with quotas
# >iptables -A INPUT -p tcp --syn -m quota2 --name "syn_flood_protection" --quota 1000 --packet-count -j ACCEPT
# >iptables -A INPUT -p tcp --syn -m quota2 --name "syn_flood_protection" --quota 0 --packet-count -j DROP
# # Bandwidth monitoring per application
# >iptables -A OUTPUT -m owner --uid-owner 1001 -m quota2 --name "app1001_bandwidth" --quota 2147483648 -j ACCEPT
# >iptables -A OUTPUT -m owner --uid-owner 1001 -m quota2 --name "app1001_bandwidth" --quota 0 -j LOG --log-prefix "APP1001_LIMIT: "
