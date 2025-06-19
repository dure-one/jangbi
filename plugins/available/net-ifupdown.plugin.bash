# shellcheck shell=bash
cite about-plugin
about-plugin 'network configurations.'

function net-ifupdown {
    about 'network configurations'
    group 'net'
    param '1: command'
    param '2: params'
    example '$ net-ifupdown check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
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
    apt install -qy ./pkgs/ifupdown*.deb
    mkdir -p /etc/network/default
    mv /etc/network/* /etc/network/default 2>/dev/null
    mkdir -p /etc/network/if-post-down.d /etc/network/if-pre-up.d /etc/network/if-up.d /etc/network/if-down.d
    __net-ifupdown_generate
}

function __net-ifupdown_generate {
    if [[ -n ${DURE_IFUPDOWN} ]];then # custom interfaces exists
        log_debug "Generating /etc/network/interfaces from DURE_IFUPDOWN config."
        echo "${DURE_IFUPDOWN}" > /etc/network/interfaces
        chmod 600 /etc/network/interfaces 2>&1 1>/dev/null
    else # custom interfaces not exists
        log_debug "Generating /etc/network/interfaces from config."
        tee /etc/network/interfaces > /dev/null <<EOT
auto lo
iface lo inet loopback
EOT
        log_debug "waninf=${DURE_WANINF} laninf=${DURE_LANINF} wlaninf=${DURE_WLANINF}"
        local waninf=${DURE_WANINF} laninf=${DURE_LANINF} wlaninf=${DURE_WLANINF}
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
            sed -i "s|DURE_WANINF=.*|DURE_WANINF=${waninf}|g" "${DURE_DEPLOY_PATH}/.config"
            [[ -z ${DURE_WAN} ]] && sed -i "s|DURE_WAN=.*|DURE_WAN=\"dhcp\"|g" "${DURE_DEPLOY_PATH}/.config"
            sed -i "s|DURE_LANINF=.*|DURE_LANINF=${laninf}|g" "${DURE_DEPLOY_PATH}/.config"
            [[ -z ${DURE_LAN} ]] && sed -i "s|DURE_LAN=.*|DURE_LAN=\"192.168.1.1/24\"|g" "${DURE_DEPLOY_PATH}/.config"
            sed -i "s|DURE_WLANINF=.*|DURE_WLANINF=${wlaninf}|g" "${DURE_DEPLOY_PATH}/.config"
            [[ -z ${DURE_WLAN} ]] && sed -i "s|DURE_WLAN=.*|DURE_WLAN=\"192.168.100.1/24\"|g" "${DURE_DEPLOY_PATH}/.config"
            [[ -z ${DURE_WLAN_SSID} ]] && sed -i "s|DURE_WLAN_SSID=.*|DURE_WLAN_SSID=\"durejangbi\"|g" "${DURE_DEPLOY_PATH}/.config"
            [[ -z ${DURE_WLAN_PASS} ]] && sed -i "s|DURE_WLAN=.*|DURE_WLAN=\"durejangbi\"|g" "${DURE_DEPLOY_PATH}/.config"
        fi

        dure_infs=$(cat /proc/net/dev|awk '{ print $1 };'|grep :|grep -v lo:)
        IFS=$'\n' read -rd '' -a dure_infs <<< "${dure_infs//:}"
        for((j=0;j<${#dure_infs[@]};j++)){
            operstate=$(cat /sys/class/net/${dure_infs[j]}/operstate)
            [[ ${operstate} == "down" ]] && continue # iface ${dure_infs[j]} inet manual

            if [[ ${dure_infs[j]} = "${waninf}" ]]; then # match DURE_WANINF
                # DURE_WANINF="enp4s0"
                # DURE_WAN="192.168.56.2/24" # or DHCP
                # DURE_WANGW="192.168.56.1" # or blank
                if [[ ${DURE_WAN,,} = "dhcp" || ${DURE_WAN} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${waninf}
iface ${waninf} inet dhcp
EOT
                else
                    # WANNET=$(ipcalc-ng ${DURE_WAN}|grep Network:|cut -f2)
                    # WANIP=$(ipcalc-ng ${DURE_WAN}|grep Address:|cut -f2)
                    if [[ ! ${DURE_WANGW} ]]; then
                        WANGW=$(ipcalc-ng ${DURE_WAN}|grep HostMin:|cut -f2)
                    else
                        WANGW=${DURE_WANGW}
                    fi
                    # WANSUBNET=$(ipcalc-ng ${DURE_WAN}|grep Netmask:|cut -f2|cut -d ' ' -f1)
                    # WANMINIP=$(ipcalc-ng ${DURE_WAN}|grep HostMin:|cut -f2)
                    # WANMAXIP=$(ipcalc-ng ${DURE_WAN}|grep HostMax:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${waninf}
iface ${waninf} inet static
address ${DURE_WAN}
gateway ${WANGW}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${laninf}" ]]; then # match DURE_LANINF
                # DURE_LANINF="enp4s0"
                # DURE_LAN="192.168.57.2/24" # or DHCP
                if [[ ${DURE_LAN,,} = "dhcp" || ${DURE_LAN} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${laninf}
iface ${laninf} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${DURE_LAN}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${DURE_LAN}|grep Address:|cut -f2)
                    if [[ ! ${DURE_LANGW} ]]; then
                        LANGW=$(ipcalc-ng ${DURE_LAN}|grep HostMin:|cut -f2)
                        tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${laninf}
iface ${laninf} inet static
    address ${DURE_LAN}
EOT
                    else
                        LANGW=${DURE_LANGW}
                        tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${laninf}
iface ${laninf} inet static
address ${DURE_LAN}
gateway ${LANGW}
EOT
                    fi
                fi
                continue
            fi
            #
            # searching & match DURE_LAN0INF ~ DURE_LAN9INF
            #
            if [[ ${dure_infs[j]} = "${DURE_LAN0INF}" ]]; then # match DURE_LAN0INF
                # DURE_LAN0INF="enp4s0"
                # DURE_LAN0="192.168.57.2/24" # or DHCP
                if [[ ${DURE_LAN0,,} = "dhcp" || ${DURE_LAN0} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN0INF}
iface ${DURE_LAN0INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${DURE_LAN0}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${DURE_LAN0}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${DURE_LAN0}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN0INF}
iface ${DURE_LAN0INF} inet static
    address ${DURE_LAN0}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${DURE_LAN1INF}" ]]; then # match DURE_LAN1INF
                # DURE_LAN1INF="enp4s0"
                # DURE_LAN1="192.168.57.2/24" # or DHCP
                if [[ ${DURE_LAN1,,} = "dhcp" || ${DURE_LAN1} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN1INF}
iface ${DURE_LAN1INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${DURE_LAN1}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${DURE_LAN1}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${DURE_LAN1}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN1INF}
iface ${DURE_LAN1INF} inet static
    address ${DURE_LAN1}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${DURE_LAN2INF}" ]]; then # match DURE_LAN2INF
                # DURE_LAN2INF="enp4s0"
                # DURE_LAN2="192.168.57.2/24" # or DHCP
                if [[ ${DURE_LAN2,,} = "dhcp" || ${DURE_LAN2} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN2INF}
iface ${DURE_LAN2INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${DURE_LAN2}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${DURE_LAN2}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${DURE_LAN2}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN2INF}
iface ${DURE_LAN2INF} inet static
    address ${DURE_LAN2}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${DURE_LAN3INF}" ]]; then # match DURE_LAN3INF
                # DURE_LAN3INF="enp4s0"
                # DURE_LAN3="192.168.57.2/24" # or DHCP
                if [[ ${DURE_LAN3,,} = "dhcp" || ${DURE_LAN3} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN3INF}
iface ${DURE_LAN3INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${DURE_LAN3}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${DURE_LAN3}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${DURE_LAN3}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN3INF}
iface ${DURE_LAN3INF} inet static
    address ${DURE_LAN3}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${DURE_LAN4INF}" ]]; then # match DURE_LAN4INF
                # DURE_LAN4INF="enp4s0"
                # DURE_LAN4="192.168.57.2/24" # or DHCP
                if [[ ${DURE_LAN4,,} = "dhcp" || ${DURE_LAN4} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN4INF}
iface ${DURE_LAN4INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${DURE_LAN4}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${DURE_LAN4}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${DURE_LAN4}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN4INF}
iface ${DURE_LAN4INF} inet static
    address ${DURE_LAN4}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${DURE_LAN5INF}" ]]; then # match DURE_LAN5INF
                # DURE_LAN5INF="enp4s0"
                # DURE_LAN5="192.168.57.2/24" # or DHCP
                if [[ ${DURE_LAN5,,} = "dhcp" || ${DURE_LAN5} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN5INF}
iface ${DURE_LAN5INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${DURE_LAN5}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${DURE_LAN5}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${DURE_LAN5}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN5INF}
iface ${DURE_LAN5INF} inet static
    address ${DURE_LAN5}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${DURE_LAN6INF}" ]]; then # match DURE_LAN6INF
                # DURE_LAN6INF="enp4s0"
                # DURE_LAN6="192.168.57.2/24" # or DHCP
                if [[ ${DURE_LAN6,,} = "dhcp" || ${DURE_LAN6} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN6INF}
iface ${DURE_LAN6INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${DURE_LAN6}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${DURE_LAN6}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${DURE_LAN6}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN6INF}
iface ${DURE_LAN6INF} inet static
    address ${DURE_LAN6}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${DURE_LAN7INF}" ]]; then # match DURE_LAN7INF
                # DURE_LAN7INF="enp4s0"
                # DURE_LAN7="192.168.57.2/24" # or DHCP
                if [[ ${DURE_LAN7,,} = "dhcp" || ${DURE_LAN7} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN7INF}
iface ${DURE_LAN7INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${DURE_LAN1}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${DURE_LAN1}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${DURE_LAN1}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN7INF}
iface ${DURE_LAN7INF} inet static
    address ${DURE_LAN7}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${DURE_LAN8INF}" ]]; then # match DURE_LAN8INF
                # DURE_LAN8INF="enp4s0"
                # DURE_LAN8="192.168.57.2/24" # or DHCP
                if [[ ${DURE_LAN8,,} = "dhcp" || ${DURE_LAN8} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN8INF}
iface ${DURE_LAN8INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${DURE_LAN1}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${DURE_LAN1}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${DURE_LAN1}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN8INF}
iface ${DURE_LAN8INF} inet static
    address ${DURE_LAN8}
EOT
                fi
                continue
            fi
            if [[ ${dure_infs[j]} = "${DURE_LAN9INF}" ]]; then # match DURE_LAN9INF
                # DURE_LAN9INF="enp4s0"
                # DURE_LAN9="192.168.57.2/24" # or DHCP
                if [[ ${DURE_LAN9,,} = "dhcp" || ${DURE_LAN9} = "" ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN9INF}
iface ${DURE_LAN9INF} inet dhcp
EOT
                else
                    # LANNET=$(ipcalc-ng ${DURE_LAN1}|grep Network:|cut -f2)
                    # LANIP=$(ipcalc-ng ${DURE_LAN1}|grep Address:|cut -f2)
                    # LANGW=$(ipcalc-ng ${DURE_LAN1}|grep HostMin:|cut -f2)
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${DURE_LAN9INF}
iface ${DURE_LAN9INF} inet static
    address ${DURE_LAN9}
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
            if [[ ${dure_infs[j]} = "${wlaninf}" ]]; then # match DURE_WLANINF
                # DURE_WLANINF="enp4s0"
                # DURE_WLAN="192.168.58.2/24" # or DHCP
                if [[ ${DURE_WLAN,,} = "dhcp" || ${DURE_WLAN} = "" ]]; then # client, dhcp mode
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${wlaninf}
iface ${wlaninf} inet dhcp
EOT
                else # gateway, wstunnel, ap mode, static gateway ip
                    # WLANNET=$(ipcalc-ng ${DURE_WLAN}|grep Network:|cut -f2)
                    # WLANIP=$(ipcalc-ng ${DURE_WLAN}|grep Address:|cut -f2)
                    if [[ ! ${DURE_WLANGW} ]]; then
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${wlaninf}
iface ${wlaninf} inet static
    address ${DURE_WLAN}
EOT
                    else
                    WLANGW=${DURE_WLANGW}
                    tee -a /etc/network/interfaces > /dev/null <<EOT
auto ${wlaninf}
iface ${wlaninf} inet static
address ${DURE_WLAN}
gateway ${WLANGW}
EOT
                    fi
                    # WLANSUBNET=$(ipcalc-ng ${DURE_WLAN}|grep Netmask:|cut -f2|cut -d ' ' -f1)
                    # WLANMINIP=$(ipcalc-ng ${DURE_WLAN}|grep HostMin:|cut -f2)
                    # WLANMAXIP=$(ipcalc-ng ${DURE_WLAN}|grep HostMax:|cut -f2)
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
    fi

}

function __net-ifupdown_uninstall { # UPDATE_FIRMWARE=0
    systemctl stop networking
    systemctl disable networking
}

function __net-ifupdown_disable { # UPDATE_FIRMWARE=0
    systemctl stop networking
    systemctl disable networking
    return 0
}

function __net-ifupdown_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting net-ifupdown Check $running_status"

    # DISABLE_SYSTEMD 0 - full systemd, 1 - disable completely, 2 - only journald
    log_debug "check DISABLE_SYSTEMD" 
    [[ -z ${DISABLE_SYSTEMD} ]] && \
        log_info "DISABLE_SYSTEMD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${DISABLE_SYSTEMD} == 0 ]] && \
        log_info "DISABLE_SYSTEMD set to full systemd(DISABLE_SYSTEMD=0)." && __net-ifupdown_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package ifupdown
    log_debug "check ifupdown is installed"
    [[ $(dpkg -l|awk '{print $2}'|grep -c "ifupdown") -lt 1 ]] && \
        log_info "ifupdown is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    log_debug "check networking is running"
    [[ $(systemctl status networking 2>/dev/null|grep -c "Active") -gt 0 ]] && \
        log_info "networking(ifupdown) is started." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-ifupdown_run {
    # remove dhcp from interfaces not connected for preventing systemd networking from hanging
    # local infs=$(cat /proc/net/dev|awk '{ print $1 };'|grep :|grep -v lo:)
    # IFS=$'\n' read -rd '' -a dure_infs <<< "${infs//:}"
    # for((j=0;j<${#dure_infs[@]};j++)){
    #     operstate=$(cat /sys/class/net/${dure_infs[j]}/operstate)
    #     if [[ ${operstate} == "up" ]]; then
    #         sed -i "s|iface ${dure_infs[j]} inet manual.*|iface ${dure_infs[j]} inet dhcp|g" /etc/network/interfaces
    #     elif [[ ${operstate} == "down" ]]; then
    #         sed -i "s|iface ${dure_infs[j]} inet dhcp.*|iface ${dure_infs[j]} inet manual|g" /etc/network/interfaces
    #     fi
    # }
    systemctl restart networking
    systemctl status networking && return 0 || return 1
}

complete -F __net-ifupdown_run net-ifupdown