## \brief omnip install configurations.
## \desc This tool helps install, configure, and manage omnip
## for proxy and network tunneling. It provides automated installation, configuration management,
## and service control capabilities. omnip is a lightweight proxy tool that supports various
## protocols for secure network communication and traffic forwarding.

## \example Install and configure omnip:
## \example-code bash
##   net-omnip install
##   net-omnip configgen
##   net-omnip configapply
## \example-description
## In this example, we install omnip, generate the configuration files,
## and apply them to the system for proxy services.

## \example Download package and run service:
## \example-code bash
##   net-omnip download
##   net-omnip run
##   net-omnip check
## \example-description
## In this example, we download the omnip package,
## start the service, and verify its running status.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'omnip install configurations.'

function net-omnip {
    about 'omnip install configurations'
    group 'postnet'
    runtype 'minmon'
    deps ''
    param '1: command'
    param '2: params'
    example '$ net-omnip subcommand'
    local PKGNAME="omnip"
    local DMNNAME="net-omnip"
    BASH_IT_LOG_PREFIX="net-omnip: "
    OMNIP_PORTS="${OMNIP_PORTS:-"LO:1080"}"
    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config || exit 1
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-omnip_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-omnip_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-omnip_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-omnip_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-omnip_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-omnip_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-omnip_download "$2"
    else
        __net-omnip_help
    fi
}

## \usage net-omnip install|uninstall|configgen|configapply|check|run|download
function __net-omnip_help {
    echo -e "Usage: net-omnip [COMMAND]\n"
    echo -e "Helper to omnip install configurations.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install omnip"
    echo "   uninstall   Uninstall installed omnip"
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   download    Download pkg files to pkg dir"
    echo "   check       Check vars available"
    echo "   run         run"
}

function __net-omnip_install {
    log_debug "Installing ${DMNNAME}..."

    local filepat="./pkgs/omnip-linux-gnu-*"
    local tmpdir="/tmp/omnip"
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    mkdir -p ${tmpdir} 1>/dev/null 2>&1

    # [[ $(find ${filepat}|wc -l) -lt 1 ]] && __net-omnip_download 
    # tar -zxvf ${filepat} -C ${tmpdir} --strip-components=1 1>/dev/null 2>&1
    # if [[ ! -f /tmp/omnip/omnip ]]; then
    #     log_error "omnip binary not found in package."
    #     return 1
    # fi
    cp ${filepat} /usr/sbin/omnip
    chmod 755 /usr/sbin/omnip
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    touch /var/log/omnip.log

    if ! __net-omnip_configgen; then # if gen config is different do apply
        __net-omnip_configapply
        rm -rf ${tmpdir}
    fi
}

function __net-omnip_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    # cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    # diff check
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-omnip_configapply {
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

function __net-omnip_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_github_pkgs neevek/omnip omnip-linux-gnu-* || log_error "${DMNNAME} download failed."
    return 0
}

function __net-omnip_disable {
    log_debug "Disabling ${DMNNAME}..."
    pidof omnip | xargs kill -9 2>/dev/null
    return 0
}

function __net-omnip_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    pidof omnip | xargs kill -9 2>/dev/null
    rm -rf /usr/sbin/omnip
}

function __net-omnip_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check package file exists
    [[ $(find ./pkgs/omnip-linux-gnu-*|wc -l) -lt 1 ]] && \
        log_info "omnip package file does not exist." && [[ $running_status -lt 10 ]] && running_status=10
    # check global variable
    [[ -z ${RUN_NET_OMNIP} ]] && \
        log_info "RUN_NET_OMNIP variable is not set." && __net-omnip_disable && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_OMNIP} != 1 ]] && \
        log_info "RUN_NET_OMNIP is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which omnip|wc -l) -lt 1 ]] && \
        log_info "omnip is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof omnip) -gt 0 ]] && \
        log_info "omnip is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-omnip_run {
    log_debug "Running ${DMNNAME}..."
    
    pidof omnip | xargs kill &>/dev/null
    
    log_debug "Starting omnip"
    omnip -a socks5+quic://127.0.0.1:8000 1>> /var/log/omnip.log 2>&1 &
    # omnip -a socks5+quic://DOMAIN:8000 -p passward123 -c CERT_FILE -k KEY_FILE
    
    pidof omnip && return 0 || \
        log_error "omnip failed to run." && return 0
}

complete -F _blank net-omnip