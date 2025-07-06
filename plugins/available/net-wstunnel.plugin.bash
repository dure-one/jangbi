# shellcheck shell=bash
cite about-plugin
about-plugin 'wstunnel install configurations.'

function net-wstunnel {
    about 'wstunnel install configurations'
    group 'postnet'
    runtype 'minmon'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ net-wstunnel check/install/uninstall/run'

    if [[ -z ${JB_VARS} ]]; then
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
    pidof wstunnel | xargs kill -9 2>/dev/null
    rm -rf /sbin/wstunnel
}

function __net-wstunnel_disable {
    pidof wstunnel | xargs kill -9 2>/dev/null
    return 0
}

function __net-wstunnel_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-wstunnel Check"

    # check global variable
    [[ -z ${RUN_NET_WSTUNNEL} ]] && \
        log_info "RUN_NET_WSTUNNEL variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_WSTUNNEL} != 1 ]] && \
        log_info "RUN_NET_WSTUNNEL variable is not enabled." && __net-wstunnel_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check wstunnel bin exists
    [[ $(which wstunnel|wc -l) -lt 1 ]] && \
        log_info "wstunnel is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof wstunnel) -gt 0 ]] && \
        log_info "wstunnel is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-wstunnel_run { # run socks proxy $NET
    local ip_addr
    ip_addr=$(ipcalc-ng "$1" 2>/dev/null|grep Address:)
    if [[ -n ${ip_addr} ]]; then
        # ws proxy only
        wstunnel server "wss://${ip_addr}:38080" &
        # socks proxy on top
        # wstunnel client -L socks5://${ip_addr}:38888 --connection-min-idle 5 wss://${ip_addr}:38080  &
    fi

    return 0
}

complete -F __net-wstunnel_run net-wstunnel