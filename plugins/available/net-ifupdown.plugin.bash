# shellcheck shell=bash
cite about-plugin
about-plugin 'network configurations.'

function net-ifupdown {
    about 'network configurations'
    group 'net'
    runtype 'systemd'
    deps  'os-systemd'
    param '1: command'
    param '2: params'
    example '$ net-ifupdown check/install/uninstall/run'

    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-ifupdown_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-ifupdown_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-ifupdown_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-ifupdown_run "$2"
    else
        __net-ifupdown_help
    fi
}

function __net-ifupdown_help {
    echo -e "Usage: net-ifupdown [COMMAND] [profile]\n"
    echo -e "Helper to network configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os ifupdown"
    echo "   uninstall Uninstall installed ifupdown"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __net-ifupdown_install {
    # install ifupdown
    [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
    [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
    [[ $(dpkg -l|awk '{print $2}'|grep -c "ifupdown") -lt 1 ]] && apt install -qy ifupdown
    mkdir -p /etc/network/default
    mv /etc/network/* /etc/network/default 2>/dev/null
    mkdir -p /etc/network/if-post-down.d /etc/network/if-pre-up.d /etc/network/if-up.d /etc/network/if-down.d
    log_debug "JB_DEPLOY_PATH : ${JB_DEPLOY_PATH}"
    __net-ifupdown_generate
}

function __net-ifupdown_generate {
    if [[ -n ${JB_IFUPDOWN} ]];then # custom interfaces exists
        log_debug "Generating /etc/network/interfaces from JB_IFUPDOWN config."
        echo "${JB_IFUPDOWN}" > /etc/network/interfaces
        chmod 600 /etc/network/interfaces 2>&1 1>/dev/null
    else # custom interfaces not exists
        log_debug "Generating /etc/network/interfaces from config."
        tee /etc/network/interfaces > /dev/null <<EOT
auto lo
iface lo inet loopback
EOT
        log_debug "waninf=${JB_WANINF} laninf=${JB_LANINF} wlaninf=${JB_WLANINF}"
        local waninf=${JB_WANINF} laninf=${JB_LANINF} wlaninf=${JB_WLANINF}
        # generate netplan based netinf
        if [[ -z ${waninf} && -z ${laninf} && -z ${wlaninf} ]]; then
            log_debug "Starting to select wan, lan, wlan interfaces..."
            local dure_infs=$(cat /proc/net/dev|awk '{ print $1 };'|grep :|grep -v lo:)
            IFS=$'\n' read -rd '' -a dure_infs <<< "${dure_infs//:}"
            # match interface name
            for((j=0;j<${#dure_infs[@]};j++)){
                if [[ ${dure_infs[j]:0:1} != 'w' && ! ${waninf} ]]; then
                    [[ ! ${waninf} && ${dure_infs[j]} != ${laninf} && ${dure_infs[j]} != ${wlaninf} ]] && waninf=${dure_infs[j]} && continue
                fi
                if [[ ${dure_infs[j]:0:1} != 'w' && ! ${laninf} ]]; then
                    [[ ! ${laninf} && ${dure_infs[j]} != ${waninf} && ${dure_infs[j]} != ${wlaninf} ]] && laninf=${dure_infs[j]} && continue
                fi
                if [[ ${dure_infs[j]:0:1} = 'w' && ! ${wlaninf} ]]; then
                    [[ ! ${wlaninf} && ${dure_infs[j]} != ${laninf} && ${dure_infs[j]} != ${waninf} ]] && wlaninf=${dure_infs[j]} && continue
                fi
            }
            log_debug "Writing selected interface WAN:${waninf} LAN:${laninf} WLAN:${wlaninf} to .config..."
            sed -i "s|JB_WANINF=.*|JB_WANINF=${waninf}|g" "${JB_DEPLOY_PATH}/.config"
            [[ -z ${JB_WAN} ]] && sed -i "s|JB_WAN=.*|JB_WAN=\"dhcp\"|g" "${JB_DEPLOY_PATH}/.config"
            sed -i "s|JB_LANINF=.*|JB_LANINF=${laninf}|g" "${JB_DEPLOY_PATH}/.config"
            [[ -z ${JB_LAN} ]] && sed -i "s|JB_LAN=.*|JB_LAN=\"192.168.1.1/24\"|g" "${JB_DEPLOY_PATH}/.config"
            sed -i "s|JB_WLANINF=.*|JB_WLANINF=${wlaninf}|g" "${JB_DEPLOY_PATH}/.config"
            [[ -z ${JB_WLAN} ]] && sed -i "s|JB_WLAN=.*|JB_WLAN=\"192.168.100.1/24\"|g" "${JB_DEPLOY_PATH}/.config"
            [[ -z ${JB_WLAN_SSID} ]] && sed -i "s|JB_WLAN_SSID=.*|JB_WLAN_SSID=\"durejangbi\"|g" "${JB_DEPLOY_PATH}/.config"
            [[ -z ${JB_WLAN_PASS} ]] && sed -i "s|JB_WLAN=.*|JB_WLAN=\"durejangbi\"|g" "${JB_DEPLOY_PATH}/.config"
        fi

        dure_infs=$(cat /proc/net/dev|awk '{ print $1 };'|grep :|grep -v lo:)
        IFS=$'\n' read -rd '' -a dure_infs <<< "${dure_infs//:}"
        for((j=0;j<${#dure_infs[@]};j++)){
            operstate=$(cat /sys/class/net/${dure_infs[j]}/operstate)
            [[ ${operstate} == "down" ]] && continue # iface ${dure_infs[j]} inet manual

            if [[ ${dure_infs[j]} = "${waninf}" ]]; then # match JB_WANINF
                # JB_WANINF="enp4s0"
                # JB_WAN="192.168.56.2/24" # or DHCP
                # JB_WANGW="192.168.56.1" # or blank
                if [[ ${JB_WAN,,} = "dhcp" || ${JB_WAN} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${waninf}
iface ${waninf} inet dhcp
EOT
                else
                    # WANNET=$(ipcalc-ng ${JB_WAN}|grep Network:|cut -f2)
                    # WANIP=$(ipcalc-ng ${JB_WAN}|grep Address:|cut -f2)
                    if [[ ! ${JB_WANGW} ]]; then
                        WANGW=$(ipcalc-ng ${JB_WAN}|grep HostMin:|cut -f2)
                    else
                        WANGW=${JB_WANGW}
                    fi
                    # WANSUBNET=$(ipcalc-ng ${JB_WAN}|grep Netmask:|cut -f2|cut -d ' ' -f1)
                    # WANMINIP=$(ipcalc-ng ${JB_WAN}|grep HostMin:|cut -f2)
                    # WANMAXIP=$(ipcalc-ng ${JB_WAN}|grep HostMax:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${waninf}
iface ${waninf} inet static
address ${JB_WAN}
gateway ${WANGW}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${laninf}" ]]; then # match JB_LANINF
                # JB_LANINF="enp4s0"
                # JB_LAN="192.168.57.2/24" # or DHCP
                if [[ ${JB_LAN,,} = "dhcp" || ${JB_LAN} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${laninf}
iface ${laninf} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${JB_LAN}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${JB_LAN}|grep Address:|cut -f2)
                    if [[ ! ${JB_LANGW} ]]; then
                        LANGW=$(ipcalc-ng ${JB_LAN}|grep HostMin:|cut -f2)
                        tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${laninf}
iface ${laninf} inet static
    address ${JB_LAN}
EOT
                    else
                        LANGW=${JB_LANGW}
                        tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${laninf}
iface ${laninf} inet static
address ${JB_LAN}
gateway ${LANGW}
EOT
                    fi
                fi
                continue
            fi
            #
            # searching & match JB_LAN0INF ~ JB_LAN9INF
            #
            if [[ ${dure_infs[j]} = "${JB_LAN0INF}" ]]; then # match JB_LAN0INF
                # JB_LAN0INF="enp4s0"
                # JB_LAN0="192.168.57.2/24" # or DHCP
                if [[ ${JB_LAN0,,} = "dhcp" || ${JB_LAN0} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN0INF}
iface ${JB_LAN0INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${JB_LAN0}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${JB_LAN0}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${JB_LAN0}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN0INF}
iface ${JB_LAN0INF} inet static
    address ${JB_LAN0}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${JB_LAN1INF}" ]]; then # match JB_LAN1INF
                # JB_LAN1INF="enp4s0"
                # JB_LAN1="192.168.57.2/24" # or DHCP
                if [[ ${JB_LAN1,,} = "dhcp" || ${JB_LAN1} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN1INF}
iface ${JB_LAN1INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${JB_LAN1}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${JB_LAN1}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${JB_LAN1}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN1INF}
iface ${JB_LAN1INF} inet static
    address ${JB_LAN1}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${JB_LAN2INF}" ]]; then # match JB_LAN2INF
                # JB_LAN2INF="enp4s0"
                # JB_LAN2="192.168.57.2/24" # or DHCP
                if [[ ${JB_LAN2,,} = "dhcp" || ${JB_LAN2} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN2INF}
iface ${JB_LAN2INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${JB_LAN2}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${JB_LAN2}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${JB_LAN2}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN2INF}
iface ${JB_LAN2INF} inet static
    address ${JB_LAN2}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${JB_LAN3INF}" ]]; then # match JB_LAN3INF
                # JB_LAN3INF="enp4s0"
                # JB_LAN3="192.168.57.2/24" # or DHCP
                if [[ ${JB_LAN3,,} = "dhcp" || ${JB_LAN3} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN3INF}
iface ${JB_LAN3INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${JB_LAN3}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${JB_LAN3}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${JB_LAN3}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN3INF}
iface ${JB_LAN3INF} inet static
    address ${JB_LAN3}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${JB_LAN4INF}" ]]; then # match JB_LAN4INF
                # JB_LAN4INF="enp4s0"
                # JB_LAN4="192.168.57.2/24" # or DHCP
                if [[ ${JB_LAN4,,} = "dhcp" || ${JB_LAN4} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN4INF}
iface ${JB_LAN4INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${JB_LAN4}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${JB_LAN4}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${JB_LAN4}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN4INF}
iface ${JB_LAN4INF} inet static
    address ${JB_LAN4}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${JB_LAN5INF}" ]]; then # match JB_LAN5INF
                # JB_LAN5INF="enp4s0"
                # JB_LAN5="192.168.57.2/24" # or DHCP
                if [[ ${JB_LAN5,,} = "dhcp" || ${JB_LAN5} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN5INF}
iface ${JB_LAN5INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${JB_LAN5}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${JB_LAN5}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${JB_LAN5}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN5INF}
iface ${JB_LAN5INF} inet static
    address ${JB_LAN5}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${JB_LAN6INF}" ]]; then # match JB_LAN6INF
                # JB_LAN6INF="enp4s0"
                # JB_LAN6="192.168.57.2/24" # or DHCP
                if [[ ${JB_LAN6,,} = "dhcp" || ${JB_LAN6} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN6INF}
iface ${JB_LAN6INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${JB_LAN6}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${JB_LAN6}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${JB_LAN6}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN6INF}
iface ${JB_LAN6INF} inet static
    address ${JB_LAN6}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${JB_LAN7INF}" ]]; then # match JB_LAN7INF
                # JB_LAN7INF="enp4s0"
                # JB_LAN7="192.168.57.2/24" # or DHCP
                if [[ ${JB_LAN7,,} = "dhcp" || ${JB_LAN7} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN7INF}
iface ${JB_LAN7INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${JB_LAN1}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${JB_LAN1}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${JB_LAN1}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN7INF}
iface ${JB_LAN7INF} inet static
    address ${JB_LAN7}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${JB_LAN8INF}" ]]; then # match JB_LAN8INF
                # JB_LAN8INF="enp4s0"
                # JB_LAN8="192.168.57.2/24" # or DHCP
                if [[ ${JB_LAN8,,} = "dhcp" || ${JB_LAN8} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN8INF}
iface ${JB_LAN8INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${JB_LAN1}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${JB_LAN1}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${JB_LAN1}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN8INF}
iface ${JB_LAN8INF} inet static
    address ${JB_LAN8}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${JB_LAN9INF}" ]]; then # match JB_LAN9INF
                # JB_LAN9INF="enp4s0"
                # JB_LAN9="192.168.57.2/24" # or DHCP
                if [[ ${JB_LAN9,,} = "dhcp" || ${JB_LAN9} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN9INF}
iface ${JB_LAN9INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${JB_LAN1}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${JB_LAN1}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${JB_LAN1}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${JB_LAN9INF}
iface ${JB_LAN9INF} inet static
    address ${JB_LAN9}
EOT
                fi
                continue
            fi

            #
            # rest non-prematched non-wireless adapters
            #
            if [[ ${dure_infs[j]:0:1} != 'w' ]]; then # match REST
                tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${dure_infs[j]}
iface ${dure_infs[j]} inet dhcp
EOT
                continue
            fi

            #
            # wireless adapters
            #
            if [[ ${dure_infs[j]} = "${wlaninf}" ]]; then # match JB_WLANINF
                # JB_WLANINF="enp4s0"
                # JB_WLAN="192.168.58.2/24" # or DHCP
                if [[ ${JB_WLAN,,} = "dhcp" || ${JB_WLAN} = "" ]]; then # client, dhcp mode
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${wlaninf}
iface ${wlaninf} inet dhcp
EOT
                else # gateway, wstunnel, ap mode, static gateway ip
                    # WLANNET=$(ipcalc-ng ${JB_WLAN}|grep Network:|cut -f2)
                    # WLANIP=$(ipcalc-ng ${JB_WLAN}|grep Address:|cut -f2)
                    if [[ ! ${JB_WLANGW} ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${wlaninf}
iface ${wlaninf} inet static
    address ${JB_WLAN}
EOT
                    else
                    WLANGW=${JB_WLANGW}
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${wlaninf}
iface ${wlaninf} inet static
address ${JB_WLAN}
gateway ${WLANGW}
EOT
                    fi
                    # WLANSUBNET=$(ipcalc-ng ${JB_WLAN}|grep Netmask:|cut -f2|cut -d ' ' -f1)
                    # WLANMINIP=$(ipcalc-ng ${JB_WLAN}|grep HostMin:|cut -f2)
                    # WLANMAXIP=$(ipcalc-ng ${JB_WLAN}|grep HostMax:|cut -f2)
                fi
                continue
            fi
            if [[ ${dure_infs[j]:0:1} = 'w' ]]; then  # match REST
                tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${dure_infs[j]}
iface ${dure_infs[j]} inet dhcp
EOT
                continue
            fi
        }
        chmod 600 /etc/network/interfaces 2>&1 1>/dev/null
        log_debug "Generated ifupdown config ===="
        cat /etc/network/interfaces
        log_debug "===="
    fi

}

function __net-ifupdown_uninstall { 
    systemctl stop networking
    systemctl disable networking
}

function __net-ifupdown_disable { 
    systemctl stop networking
    systemctl disable networking
    return 0
}

function __net-ifupdown_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-ifupdown Check $running_status"

    # RUN_OS_SYSTEMD 1 - full systemd, 0 - disable completely, 2 - only journald
    log_debug "check RUN_OS_SYSTEMD" 
    [[ -z ${RUN_OS_SYSTEMD} ]] && \
        log_error "RUN_OS_SYSTEMD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_SYSTEMD} == 1 ]] && \
        log_error "RUN_OS_SYSTEMD set to full systemd(RUN_OS_SYSTEMD=1)." && __net-ifupdown_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package ifupdown
    log_debug "check ifupdown is installed"
    [[ $(dpkg -l|awk '{print $2}'|grep -c "ifupdown") -lt 1 ]] && \
        log_info "ifupdown is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    log_debug "check networking is running"
    [[ $(systemctl status networking 2>/dev/null|grep -c "Active") -lt 1 ]] && \
        log_info "networking(ifupdown) is not running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-ifupdown_run {
    # remove dhcp from interfaces not connected for preventing systemd networking from hanging
    # local infs=$(cat /proc/net/dev|awk '{ print $1 };'|grep :|grep -v lo:)
    # IFS=$'\n' read -rd '' -a dure_infs <<< "${infs//:}"
    # for((j=0;j<${#dure_infs[@]};j++)){
    #     operstate=$(cat /sys/class/net/${dure_infs[j]}/operstate)
    #     if [[ ${operstate} == *"up"* ]]; then
    #         sed -i "s|iface ${dure_infs[j]} inet manual.*|iface ${dure_infs[j]} inet dhcp|g" /etc/network/interfaces
    #     elif [[ ${operstate} == "down" ]]; then
    #         sed -i "s|iface ${dure_infs[j]} inet dhcp.*|iface ${dure_infs[j]} inet manual|g" /etc/network/interfaces
    #     fi
    # }
    systemctl restart networking
    systemctl status networking && return 0 || return 1
}

complete -F __net-ifupdown_run net-ifupdown