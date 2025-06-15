# shellcheck shell=bash
cite about-plugin
about-plugin 'wstunnel install configurations.'

function net-wstunnel {
    about 'wstunnel install configurations'
    group 'net'
    param '1: command'
    param '2: params'
    example '$ net-wstunnel check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-wstunnel_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-wstunnel_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-wstunnel_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-wstunnel_run "$2"
    else
        __net-wstunnel_help
    fi
}

function __net-wstunnel_help {
    echo -e "Usage: net-wstunnel [COMMAND] [profile]\n"
    echo -e "Helper to wstunnel install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os firmware"
    echo "   uninstall Uninstall installed firmware"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __net-wstunnel_install {
    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install net-wstunnel."
    mkdir -p /tmp/wstunnel
    tar -zxf ./pkg/wstunnel*.tar.gz -C /tmp/wstunnel
    mv /tmp/wstunnel/wstunnel /usr/sbin/wstunnel
    chmod 600 /sbin/wstunnel
}

function __net-wstunnel_uninstall {
    log_debug "Trying to uninstall net-wstunnel."
    echo $(pidof wstunnel) | xargs kill -9 2>/dev/null
    rm -rf /sbin/wstunnel
}

function __net-wstunnel_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    local return_code=0
    log_debug "Starting net-wstunnel Check"
    # check variable exists
    [[ -z ${RUN_WSTUNNEL} ]] && log_info "RUN_WSTUNNEL variable is not set." && return 1
    # check pkg installed
    [[ $(which wstunnel|wc -l) -lt 1 ]] && log_info "wstunnel is not installed." && return 0
    # check dnsmasq started
    [[ $(ps aux|grep wstunnel) -gt 1 ]] && log_info "wstunnel is started." && return_code=2

    return 0
}

function __net-wstunnel_run { # run socks proxy $NET
    local ip_addr=$(ipcalc-ng $1 2>/dev/null|grep Address:)
    if [[ ${#ip_adrr[@]} -gt 0 ]]; then
        # ws proxy only
        wstunnel server wss://${ip_addr}:38080 &
        # socks proxy on top
        # wstunnel client -L socks5://${ip_addr}:38888 --connection-min-idle 5 wss://${ip_addr}:38080  &
    fi

    return 0
}

complete -F __net-wstunnel_run net-wstunnel