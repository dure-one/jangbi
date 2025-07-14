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
    example '$ net-wstunnel subcommand'
    local PKGNAME="wstunnel"
    local DMNNAME="net-wstunnel"

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
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-wstunnel_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-wstunnel_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-wstunnel_download "$2"
    else
        __net-wstunnel_help
    fi
}

function __net-wstunnel_help {
    echo -e "Usage: net-wstunnel [COMMAND] [profile]\n"
    echo -e "Helper to wstunnel install configurations.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install os firmware"
    echo "   uninstall   Uninstall installed firmware"
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   download    Download pkg files to pkg dir"
    echo "   check       Check vars available"
    echo "   run         Run tasks"
}

function __net-wstunnel_install {
    export DEBIAN_FRONTEND=noninteractive
    log_debug "Installing ${DMNNAME}..."

    local filepat="./pkgs/wstunnel_*.tar.gz"
    local tmpdir="/tmp/wstunnel"
    rm -rf ${tmpdir} 2>&1 1>/dev/null
    mkdir -p ${tmpdir} 2>&1 1>/dev/null

    [[ $(find ${filepat}|wc -l) -lt 1 ]] && __net-wstunnel_download
    tar -zxvf ${filepat} -C ${tmpdir} 2>/dev/null 2>&1
    if [[ ! -f /tmp/wstunnel/wstunnel ]]; then
        log_error "wstunnel binary not found in package."
        return 1
    fi
    mv /tmp/wstunnel/wstunnel /usr/sbin/wstunnel
    chmod 600 /sbin/wstunnel
    rm -rf ${tmpdir} 2>&1 1>/dev/null

    # if ! __net-wstunnel_configgen; then # if gen config is different do apply
    #     __net-wstunnel_configapply
    #     rm -rf ${tmpdir}
    # fi
}

function __net-wstunnel_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 2>&1 1>/dev/null
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 2>&1 1>/dev/null
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    
    # diff check
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-wstunnel_configapply {
    [[ ! -f /tmp/${PKGNAME}.diff ]] && log_error "/tmp/${PKGNAME}.diff file doesnt exist. please run configgen."
    log_debug "Applying config ${DMNNAME}..."
    local dtnow=$(date +%Y%m%d_%H%M%S)
    [[ -d "/etc/${PKGNAME}" ]] && cp -rf "/etc/${PKGNAME}" "/etc/.${PKGNAME}.${dtnow}"
    pushd /etc/${PKGNAME} 2>&1 1>/dev/null
    patch -i /tmp/${PKGNAME}.diff
    popd 2>&1 1>/dev/null
    rm /tmp/${PKGNAME}.diff
    return 0
}

function __net-wstunnel_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_github_pkgs erebe/wstunnel wstunnel_*.tar.gz
    return 0
}

function __net-wstunnel_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    pidof wstunnel | xargs kill -9 2>/dev/null
    rm -rf /sbin/wstunnel
}

function __net-wstunnel_disable {
    log_debug "Disabling ${DMNNAME}..."
    pidof wstunnel | xargs kill -9 2>/dev/null
    return 0
}

function __net-wstunnel_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check global variable
    [[ -z ${RUN_NET_WSTUNNEL} ]] && \
        log_error "RUN_NET_WSTUNNEL variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_WSTUNNEL} != 1 ]] && \
        log_error "RUN_NET_WSTUNNEL variable is not enabled." && __net-wstunnel_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check wstunnel bin exists
    [[ $(which wstunnel|wc -l) -lt 1 ]] && \
        log_info "wstunnel is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof wstunnel) -gt 0 ]] && \
        log_info "wstunnel is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-wstunnel_run { # run socks proxy $NET
    log_debug "Running ${DMNNAME}..."

    local ip_addr
    ip_addr=$(ipcalc-ng "$1" 2>/dev/null|grep Address:)
    if [[ -n ${ip_addr} ]]; then
        # ws proxy only
        systemd-run -r wstunnel server "wss://${ip_addr}:38080"
        # socks proxy on top
        # wstunnel client -L socks5://${ip_addr}:38888 --connection-min-idle 5 wss://${ip_addr}:38080  &
    fi

    return 0
}

complete -F _blank net-wstunnel