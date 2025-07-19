## \brief shoes install configurations.
## \desc This tool helps install, configure, and manage shoes
## for HTTP/HTTPS proxy and tunneling. It provides automated installation, configuration management,
## and service control capabilities. shoes is a multi-protocol proxy server that supports
## HTTP, HTTPS, and SOCKS protocols for secure network communication.

## \example Install and configure shoes:
## \example-code bash
##   net-shoes install
##   net-shoes configgen
##   net-shoes configapply
## \example-description
## In this example, we install shoes, generate the configuration files,
## and apply them to the system for proxy services.

## \example Download package and run service:
## \example-code bash
##   net-shoes download
##   net-shoes run
##   net-shoes check
## \example-description
## In this example, we download the shoes package,
## start the service, and verify its running status.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'shoes install configurations.'

function net-shoes {
    about 'shoes install configurations'
    group 'postnet'
    runtype 'minmon'
    deps ''
    param '1: command'
    param '2: params'
    example '$ net-shoes subcommand'
    local PKGNAME="shoes"
    local DMNNAME="net-shoes"
    BASH_IT_LOG_PREFIX="net-shoes: "
    SHOES_PORTS="${SHOES_PORTS:-"LO:8080"}"
    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-shoes_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-shoes_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-shoes_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-shoes_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-shoes_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-shoes_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-shoes_download "$2"
    else
        __net-shoes_help
    fi
}

## \usage net-shoes [COMMAND]
## \usage net-shoes install|uninstall|configgen|configapply|check|run|download
function __net-shoes_help {
    echo -e "Usage: net-shoes [COMMAND]\n"
    echo -e "Helper to shoes install configurations.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install shoes"
    echo "   uninstall   Uninstall installed shoes"
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   download    Download pkg files to pkg dir"
    echo "   check       Check vars available"
    echo "   run         run"
}

function __net-shoes_install {
    log_debug "Installing ${DMNNAME}..."

    local filepat="./pkgs/shoes-*-unknown-linux-musl.tar.gz"
    local tmpdir="/tmp/shoes"
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    mkdir -p ${tmpdir} 1>/dev/null 2>&1

    [[ $(find ${filepat}|wc -l) -lt 1 ]] && __net-shoes_download 
    tar -zxvf ${filepat} -C ${tmpdir} 1>/dev/null 2>&1
    if [[ ! -f /tmp/shoes/shoes ]]; then
        log_error "shoes binary not found in package."
        return 1
    fi
    cp ${tmpdir}/shoes /usr/sbin/shoes
    chmod 755 /usr/sbin/shoes
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    touch /var/log/shoes.log

    if ! __net-shoes_configgen; then # if gen config is different do apply
        __net-shoes_configapply
        rm -rf ${tmpdir}
    fi
}

function __net-shoes_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    openssl req -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -out /tmp/${PKGNAME}/some.crt -keyout /tmp/${PKGNAME}/some.key -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=localhost"
    # diff check
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-shoes_configapply {
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

function __net-shoes_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_github_pkgs cfal/shoes  shoes-*-unknown-linux-musl.tar.gz  || log_error "${DMNNAME} download failed."
    return 0
}

function __net-shoes_disable {
    log_debug "Disabling ${DMNNAME}..."
    pidof shoes | xargs kill -9 2>/dev/null
    return 0
}

function __net-shoes_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    pidof shoes | xargs kill -9 2>/dev/null
    rm -rf /usr/sbin/shoes
}

function __net-shoes_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check package file exists
    [[ $(find ./pkgs/shoes-*-linux-*|wc -l) -lt 1 ]] && \
        log_info "shoes package file does not exist." && [[ $running_status -lt 10 ]] && running_status=10
    # check global variable
    [[ -z ${RUN_NET_SHOES} ]] && \
        log_info "RUN_NET_SHOES variable is not set." && __net-shoes_disable && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_SHOES} != 1 ]] && \
        log_info "RUN_NET_SHOES is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which shoes|wc -l) -lt 1 ]] && \
        log_info "shoes is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof shoes) -gt 0 ]] && \
        log_info "shoes is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-shoes_run {
    log_debug "Running ${DMNNAME}..."
    
    pidof shoes | xargs kill &>/dev/null
    
    log_debug "Starting shoes" 
    shoes -t 2 /etc/shoes/config.yaml 1>>/var/log/shoes.log 2>&1 &
    
    pidof shoes && return 0 || \
        log_error "shoes failed to run." && return 0
}

complete -F _blank net-shoes