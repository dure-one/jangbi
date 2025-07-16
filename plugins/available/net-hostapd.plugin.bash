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
    example '$ net-hostapd subcommand'
    local PKGNAME="hostapd"
    local DMNNAME="net-hostapd"

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
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-hostapd_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-hostapd_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-hostapd_download "$2"
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
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   download    download pkg files to pkg dir"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __net-hostapd_install {
    log_debug "Installing ${DMNNAME}..."
    export DEBIAN_FRONTEND=noninteractive
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
        [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
        apt install -qy ${PKGNAME} || log_error "${DMNNAME} online install failed."
    else
        local filepat="./pkgs/${PKGNAME}*.deb"
        local pkglist="./pkgs/${PKGNAME}.pkgs"
        [[ $(find ${filepat}|wc -l) -lt 1 ]] && log_error "${DMNNAME} pkg file not found."
        pkgslist_down=()
        while read -r pkg; do
            [[ $pkg ]] && pkgslist_down+=("./pkgs/${pkg}*.deb")
        done < ${pkglist}
        # shellcheck disable=SC2068
        apt install -qy ${pkgslist_down[@]} || log_error "${DMNNAME} offline install failed."
        
    fi
    if ! __net-hostapd_configgen; then # if gen config is different do apply
        __net-hostapd_configapply
        rm -rf /tmp/${PKGNAME}
    fi
}

function __net-hostapd_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    tee /tmp/hostapd/hostapd.conf > /dev/null <<EOT
interface=${JB_WLANINF}
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
    # diff check
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-hostapd_configapply {
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

function __net-hostapd_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_apt_pkgs hostapd || log_error "${DMNNAME} download failed."
    return 0
}

function __net-hostapd_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    pidof hostapd | xargs kill -9 2>/dev/null
    apt purge -qy hostapd
}

function __net-hostapd_disabled { 
    log_debug "Disabling ${DMNNAME}..."
    pidof hostapd | xargs kill -9 2>/dev/null
    return 0
}

function __net-hostapd_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check global variable
    [[ -z ${RUN_NET_HOSTAPD} ]] && \
        log_error "RUN_NET_HOSTAPD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_HOSTAPD} != 1 ]] && \
        log_error "RUN_NET_HOSTAPD is not enabled." && __net-hostapd_disabled && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(dpkg -l|awk '{print $2}'|grep -c "hostapd") -lt 1 ]] && \
        log_info "hostapd is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof hostapd) -gt 0 ]] && \
        log_info "hostapd is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-hostapd_run {
    log_debug "Running ${DMNNAME}..."
    pidof hostapd | xargs kill -9 2>/dev/null
    systemd-run -r hostapd /etc/hostapd/hostapd.conf -f /var/log/hostapd.log
    pidof hostapd && return 0 || return 1
}

complete -F _blank net-hostapd