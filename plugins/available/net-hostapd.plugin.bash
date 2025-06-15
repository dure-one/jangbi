# shellcheck shell=bash
cite about-plugin
about-plugin 'hostapd install configurations.'

function net-hostapd {
    about 'hostapd install configurations'
    group 'net'
    param '1: command'
    param '2: params'
    example '$ net-hostapd check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
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
    WLANINF=${DURE_WLANINF}
    WLANIP="${DURE_WLAN}"
    WLANIP=$(ipcalc-ng ${DURE_WLAN}|grep Address:|cut -f2)
    WLANMINIP=$(ipcalc-ng ${DURE_WLAN}|grep HostMin:|cut -f2)
    WLANMAXIP=$(ipcalc-ng ${DURE_WLAN}|grep HostMax:|cut -f2)

    apt install -yq hostapd
    mkdir -p /etc/hostapd
    cp -rf ./configs/hostapd.conf.default /etc/hostapd/
    tee /etc/hostapd/hostapd.conf > /dev/null <<EOT
interface=${WLANINF}
ssid=${DURE_WLAN_SSID}
hw_mode=g
channel=6
ieee80211n=1
wpa=2
wpa_passphrase=${DURE_WLAN_PASS}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wmm_enabled=1
EOT
}

function __net-hostapd_uninstall { # UPDATE_FIRMWARE=0
    echo $(pidof hostapd) | xargs kill -9 2>/dev/null
    apt purge -qy hostapd
}

function __net-hostapd_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    local return_code=0
    # check variable exists
    [[ -z ${RUN_HOSTAPD} ]] && log_info "RUN_HOSTAPD variable is not set." && return 1
    # check pkg installed
    [[ $(dpkg -l|grep hostapd|wc -l) -lt 1 ]] && log_info "hostapd is not installed." && return 0
    # check dnsmasq started
    [[ $(ps aux|grep hostapd|wc -l) -gt 1 ]] && log_info "hostapd is started." && return_code=2

    return 0
}

function __net-hostapd_run {
    echo $(pidof hostapd) | xargs kill -9 2>/dev/null
    hostapd /etc/hostapd/hostapd.conf &>>/var/log/hostapd.log &

    return 0
}

complete -F __net-hostapd_run net-hostapd