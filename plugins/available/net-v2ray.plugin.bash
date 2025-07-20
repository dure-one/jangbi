## \brief v2ray install configurations.
## \desc This tool helps install, configure, and manage V2Ray
## for secure proxy and tunneling. It provides automated installation, configuration management,
## and service control capabilities. V2Ray is a platform for building proxies to bypass network
## restrictions and protect privacy with advanced routing capabilities.

## \example Install and configure V2Ray:
## \example-code bash
##   net-v2ray install
##   net-v2ray configgen
##   net-v2ray configapply
## \example-description
## In this example, we install V2Ray, generate the configuration files,
## and apply them to the system for secure proxy services.

## \example Download package and run service:
## \example-code bash
##   net-v2ray download
##   net-v2ray run
##   net-v2ray check
## \example-description
## In this example, we download the V2Ray package,
## start the service, and verify its running status.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'v2ray install configurations.'

function net-v2ray {
    about 'v2ray install configurations'
    group 'postnet'
    runtype 'minmon'
    deps ''
    param '1: command'
    param '2: params'
    example '$ net-v2ray subcommand'
    local PKGNAME="v2ray"
    local DMNNAME="net-v2ray"
    BASH_IT_LOG_PREFIX="net-v2ray: "
    V2RAY_PORTS="${V2RAY_PORTS:-"LO:1080"}"
    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config || exit 1
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-v2ray_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-v2ray_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-v2ray_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-v2ray_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-v2ray_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-v2ray_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-v2ray_download "$2"
    else
        __net-v2ray_help
    fi
}

## \usage net-v2ray install|uninstall|configgen|configapply|check|run|download
function __net-v2ray_help {
    echo -e "Usage: net-v2ray [COMMAND]\n"
    echo -e "Helper to v2ray install configurations.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install v2ray"
    echo "   uninstall   Uninstall installed v2ray"
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   download    Download pkg files to pkg dir"
    echo "   check       Check vars available"
    echo "   run         run"
}

function __net-v2ray_install {
    log_debug "Installing ${DMNNAME}..."

    local filepat="./pkgs/v2ray-linux-*.zip"
    local tmpdir="/tmp/v2ray"
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    mkdir -p ${tmpdir} 1>/dev/null 2>&1

    [[ $(find ${filepat}|wc -l) -lt 1 ]] && __net-v2ray_download
    # tar -zxvf ${filepat} -C ${tmpdir} --strip-components=1 1>/dev/null 2>&1
    unzip ${filepat} -d ${tmpdir} 1>/dev/null 2>&1
    if [[ ! -f /tmp/v2ray/v2ray ]]; then
        log_error "v2ray binary not found in package."
        return 1
    fi

    # copy to /usr/local/v2ray and link to /usr/sbin
    cp ${tmpdir}/v2ray /usr/sbin/v2ray
    chmod 755 /usr/sbin/v2ray
    # rm -rf ${tmpdir} 1>/dev/null 2>&1
    touch /var/log/v2ray.log

    if ! __net-v2ray_configgen; then # if gen config is different do apply
        __net-v2ray_configapply
        rm -rf ${tmpdir}
    fi
    mkdir -p /var/log/v2ray
}

function __net-v2ray_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1

    unzip ${filepat} -d ${tmpdir} 1>/dev/null 2>&1
    rm -rf /tmp/v2ray/v2ray /tmp/v2ray/systemd
    mv /tmp/v2ray/config.json /tmp/v2ray/config.json.default
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    
    # diff check
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-v2ray_configapply {
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

function __net-v2ray_download {
    log_debug "Downloading ${DMNNAME}..."
    arch1_=$(dpkg --print-architecture)
    arch1=${3:-${arch1_}}
    [[ ${arch1} == "amd64" ]] && comparch="-64-"
    [[ ${arch1} == "arm64" ]] && comparch="-arm64-v8a-"

    _download_github_pkgs v2fly/v2ray-core v2ray-linux-*.zip "${comparch}" || log_error "${DMNNAME} download failed."
    return 0
}

function __net-v2ray_disable {
    log_debug "Disabling ${DMNNAME}..."
    pidof v2ray | xargs kill -9 2>/dev/null
    return 0
}

function __net-v2ray_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    pidof v2ray | xargs kill -9 2>/dev/null
    rm -rf /usr/sbin/v2ray
}

function __net-v2ray_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check package file exists
    [[ $(find ./pkgs/v2ray-linux-*.zip|wc -l) -lt 1 ]] && \
        log_info "v2ray package file does not exist." && [[ $running_status -lt 10 ]] && running_status=10
    # check global variable
    [[ -z ${RUN_NET_V2RAY} ]] && \
        log_info "RUN_NET_V2RAY variable is not set." && __net-v2ray_disable && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_V2RAY} != 1 ]] && \
        log_info "RUN_NET_V2RAY is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which v2ray|wc -l) -lt 1 ]] && \
        log_info "v2ray is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof v2ray) -gt 0 ]] && \
        log_info "v2ray is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-v2ray_run {
    log_debug "Running ${DMNNAME}..."
    
    pidof v2ray | xargs kill &>/dev/null
    
    log_debug "Starting v2ray" 
    v2ray run --config=/etc/v2ray/config.json &
    
    pidof v2ray && return 0 || \
        log_error "v2ray failed to run." && return 0
}

complete -F _blank net-v2ray