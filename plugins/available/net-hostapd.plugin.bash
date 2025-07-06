# shellcheck shell=bash
cite about-plugin
about-plugin 'hostapd install configurations.'

function net-hostapd {
    about 'hostapd install configurations'
    group 'postnet'
    runtype 'minmon'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ net-hostapd check/install/uninstall/run'

    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-hostapd_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-hostapd_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-hostapd_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-hostapd_run "$2"
    else
        __net-hostapd_help
    fi
}

function __net-hostapd_help {
    echo -e "Usage: net-hostapd [COMMAND] [profile]\n"
    echo -e "Helper to hostapd install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os firmware"
    echo "   uninstall Uninstall installed firmware"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __net-hostapd_install {
    export DEBIAN_FRONTEND=noninteractive
    WLANINF=${JB_WLANINF}
    # WLANIP="${JB_WLAN}"
    # WLANIP=$(ipcalc-ng "${JB_WLAN}"|grep Address:|cut -f2)
    # WLANMINIP=$(ipcalc-ng "${JB_WLAN}"|grep HostMin:|cut -f2)
    # WLANMAXIP=$(ipcalc-ng "${JB_WLAN}"|grep HostMax:|cut -f2)
    [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official; apt update -qy
    [[ $(dpkg -l|awk '{print $2}'|grep -c "hostapd") -lt 1 ]] && apt install -qy hostapd
    mkdir -p /etc/hostapd
    cp -rf ./configs/hostapd.conf.default /etc/hostapd/
    tee /etc/hostapd/hostapd.conf > /dev/null <<EOT
interface=${WLANINF}
ssid=${JB_WLAN_SSID}
hw_mode=g
channel=6
ieee80211n=1
wpa=2
wpa_passphrase=${JB_WLAN_PASS}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wmm_enabled=1
EOT
}

function __net-hostapd_uninstall { 
    pidof hostapd | xargs kill -9 2>/dev/null
    apt purge -qy hostapd
}

function __net-hostapd_disabled { 
    pidof hostapd | xargs kill -9 2>/dev/null
    return 0
}

function __net-hostapd_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-hostapd Check"

    # check global variable
    [[ -z ${RUN_NET_HOSTAPD} ]] && \
        log_info "RUN_NET_HOSTAPD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_HOSTAPD} != 1 ]] && \
        log_info "RUN_NET_HOSTAPD is not enabled." && __net-hostapd_disabled && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(dpkg -l|awk '{print $2}'|grep -c "hostapd") -lt 1 ]] && \
        log_info "hostapd is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof hostapd) -lt 1 ]] && \
        log_info "hostapd is not running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-hostapd_run {
    pidof hostapd | xargs kill -9 2>/dev/null
    hostapd /etc/hostapd/hostapd.conf &>>/var/log/hostapd.log &
    pidof hostapd && return 0 || return 1
}

complete -F __net-hostapd_run net-hostapd