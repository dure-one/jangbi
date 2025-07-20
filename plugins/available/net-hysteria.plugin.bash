## \brief hysteria install configurations.
## \desc This tool helps install, configure, and manage Hysteria
## for high-performance proxy and tunneling. It provides automated installation, configuration management,
## and service control capabilities. Hysteria is a feature-packed proxy & relay tool optimized for
## lossy, unstable connections with brutal performance.

## \example Install and configure Hysteria:
## \example-code bash
##   net-hysteria install
##   net-hysteria configgen
##   net-hysteria configapply
## \example-description
## In this example, we install Hysteria, generate the configuration files,
## and apply them to the system for high-performance proxy services.

## \example Download package and run service:
## \example-code bash
##   net-hysteria download
##   net-hysteria run
##   net-hysteria check
## \example-description
## In this example, we download the Hysteria package,
## start the service, and verify its running status.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'hysteria install configurations.'

function net-hysteria {
    about 'hysteria install configurations'
    group 'postnet'
    runtype 'minmon'
    deps ''
    param '1: command'
    param '2: params'
    example '$ net-hysteria subcommand'
    local PKGNAME="hysteria"
    local DMNNAME="net-hysteria"
    BASH_IT_LOG_PREFIX="net-hysteria: "
    HYSTERIA_PORTS="${HYSTERIA_PORTS:-"LO:1080"}"
    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config || exit 1
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "help" ]]; then
        __net-hysteria_help "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-hysteria_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-hysteria_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-hysteria_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disable" ]]; then
        __net-hysteria_disable "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-hysteria_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-hysteria_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-hysteria_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-hysteria_run "$2"
    else
        __net-hysteria_help
    fi
}

## \usage net-hysteria help|install|uninstall|download|disable|configgen|configapply|check|run
function __net-hysteria_help {
    echo -e "Usage: net-hysteria [COMMAND]\n"
    echo -e "Helper to hysteria install configurations.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install hysteria"
    echo "   uninstall   Uninstall installed hysteria"
    echo "   download    Download pkg files to pkg dir"
    echo "   disable     Disable hysteria service"
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   check       Check vars available"
    echo "   run         run"
}

function __net-hysteria_install {
    log_debug "Installing ${DMNNAME}..."

    local filepat="./pkgs/hysteria-linux-*"
    local tmpdir="/tmp/hysteria"
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    mkdir -p ${tmpdir} 1>/dev/null 2>&1

    [[ $(find ${filepat}|wc -l) -lt 1 ]] && __net-hysteria_download 
    cp ${filepat} /usr/sbin/hysteria
    chmod 755 /usr/sbin/hysteria
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    touch /var/log/hysteria.log

    if ! __net-hysteria_configgen; then # if gen config is different do apply
        __net-hysteria_configapply
        rm -rf ${tmpdir}
    fi
}

function __net-hysteria_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    # generate certs
    openssl req -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -out /tmp/${PKGNAME}/some.crt -keyout /tmp/${PKGNAME}/some.key -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=localhost"
    # diff check
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-hysteria_configapply {
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

function __net-hysteria_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_github_pkgs apernet/hysteria hysteria-linux-* || log_error "${DMNNAME} download failed."
    return 0
}

function __net-hysteria_disable {
    log_debug "Disabling ${DMNNAME}..."
    pidof hysteria | xargs kill -9 2>/dev/null
    return 0
}

function __net-hysteria_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    pidof hysteria | xargs kill -9 2>/dev/null
    rm -rf /usr/sbin/hysteria
}

function __net-hysteria_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check package file exists
    [[ $(find ./pkgs/hysteria-linux-*|wc -l) -lt 1 ]] && \
        log_info "hysteria package file does not exist." && [[ $running_status -lt 15 ]] && running_status=15
    # check global variable
    [[ -z ${RUN_NET_HYSTERIA} ]] && \
        log_info "RUN_NET_HYSTERIA variable is not set." && __net-hysteria_disable && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_HYSTERIA} != 1 ]] && \
        log_info "RUN_NET_HYSTERIA is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which hysteria|wc -l) -lt 1 ]] && \
        log_info "hysteria is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof hysteria) -gt 0 ]] && \
        log_info "hysteria is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-hysteria_run {
    log_debug "Running ${DMNNAME}..."
    
    pidof hysteria | xargs kill &>/dev/null
    
    log_debug "Starting hysteria" 
    hysteria -c /etc/hysteria/config.yaml &
    
    pidof hysteria && return 0 || \
        log_error "hysteria failed to run." && return 0
}

complete -F _blank net-hysteria