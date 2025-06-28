# shellcheck shell=bash
cite about-plugin
about-plugin 'minmon install configurations.'

function net-minmon {
    about 'minmon install configurations'
    group 'postnet'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ net-minmon check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-minmon_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-minmon_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-minmon_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-minmon_run "$2"
    else
        __net-minmon_help
    fi
}

function __net-minmon_help {
    echo -e "Usage: net-minmon [COMMAND] [profile]\n"
    echo -e "Helper to minmon install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os firmware"
    echo "   uninstall Uninstall installed firmware"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __net-minmon_install {
    export DEBIAN_FRONTEND=noninteractive
    WLANINF=${DURE_WLANINF}
    # WLANIP="${DURE_WLAN}"
    # WLANIP=$(ipcalc-ng "${DURE_WLAN}"|grep Address:|cut -f2)
    # WLANMINIP=$(ipcalc-ng "${DURE_WLAN}"|grep HostMin:|cut -f2)
    # WLANMAXIP=$(ipcalc-ng "${DURE_WLAN}"|grep HostMax:|cut -f2)

    apt install -yq minmon
    mkdir -p /etc/minmon
    cp -rf ./configs/minmon.conf.default /etc/minmon/
    
}

function __net-minmon_uninstall { # RUN_OS_FIRMWARE=0
    pidof minmon | xargs kill -9 2>/dev/null
    apt purge -qy minmon
}

function __net-minmon_disabled { # RUN_OS_FIRMWARE=0
    pidof minmon | xargs kill -9 2>/dev/null
    return 0
}

function __net-minmon_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-minmon Check"

    # check global variable
    [[ -z ${RUN_NET_MINMON} ]] && \
        log_info "RUN_NET_MINMON variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_MINMON} != 1 ]] && \
        log_info "RUN_NET_MINMON is not enabled." && __net-minmon_disabled && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(dpkg -l|awk '{print $2}'|grep -c "minmon") -lt 1 ]] && \
        log_info "minmon is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof minmon) -lt 1 ]] && \
        log_info "minmon is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-minmon_run {
    pidof minmon | xargs kill -9 2>/dev/null
    minmon /etc/minmon/minmon.conf &>>/var/log/minmon.log &
    pidof minmon && return 0 || return 1
}

complete -F __net-minmon_run net-minmon