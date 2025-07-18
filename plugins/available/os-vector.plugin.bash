## \brief vector log management configurations.
## \desc This tool helps install, configure, and manage Vector log management system
## for high-performance log collection, transformation, and routing. It provides automated installation,
## configuration management, and Vector service control capabilities. Vector is a lightweight
## and ultra-fast tool for building observability pipelines, collecting and transforming
## logs, metrics, and traces from various sources to multiple destinations.

## \example Install and configure Vector:
## \example-code bash
##   os-vector install
##   os-vector configgen
##   os-vector configapply
## \example-description
## In this example, we install Vector, generate log pipeline configurations,
## and apply them to establish efficient log management.

## \example Start Vector service and verify status:
## \example-code bash
##   os-vector run
##   os-vector check
## \example-description
## In this example, we start the Vector service and verify
## that log collection and processing is working properly.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'vector install configurations.'

function os-vector {
    about 'vector install configurations'
    group 'postnet'
    runtype 'minmon'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-vector subcommand'
    local PKGNAME="vector"
    local DMNNAME="os-vector"
    BASH_IT_LOG_PREFIX="os-vector: "
    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-vector_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-vector_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-vector_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-vector_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __os-vector_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __os-vector_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __os-vector_download "$2"
    else
        __os-vector_help
    fi
}

## \usage os-vector [COMMAND] [profile]
## \usage os-vector install|uninstall|configgen|configapply
## \usage os-vector check|run|download
function __os-vector_help {
    echo -e "Usage: os-vector [COMMAND] [profile]\n"
    echo -e "Helper to vector install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os firmware"
    echo "   uninstall Uninstall installed firmware"
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   download    Download pkg files to pkg dir"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-vector_install {
    log_debug "Installing ${DMNNAME}..."

    local filepat="./pkgs/vector*.deb"
    [[ $(find ${filepat}|wc -l) -lt 1 ]] && __net-vector_download
    apt install -yq ./pkgs/vector*.deb ./pkgs/sysdig*.deb
    mkdir -p /var/log/vector 1>/dev/null 2>&1

    if ! __os-vector_configgen; then # if gen config is different do apply
        __os-vector_configapply
        rm -rf ${tmpdir}
    fi
   
}

function __os-vector_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    cp -rf /etc/${PKGNAME}/* /tmp/${PKGNAME}/
    cp -rf ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    
    # diff check
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __os-vector_configapply {
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

function __os-vector_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_github_pkgs vectordotdev/vector vector_*.deb || log_error "${DMNNAME} download failed."
    _download_github_pkgs draios/sysdig sysdig-*.deb || log_error "${DMNNAME} download failed."
    return 0
}

function __os-vector_uninstall { 
    pidof vector | xargs kill -9 2>/dev/null
    apt purge -qy vector sysdig
}

function __os-vector_disabled { 
    pidof vector | xargs kill -9 2>/dev/null
    return 0
}

function __os-vector_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check global variable
    [[ -z ${RUN_OS_VECTOR} ]] && \
        log_error "RUN_OS_VECTOR variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_VECTOR} != 1 ]] && \
        log_error "RUN_OS_VECTOR is not enabled." && __os-vector_disabled && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(dpkg -l|awk '{print $2}'|grep -c "vector") -lt 1 ]] && \
        log_info "vector is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof vector) -gt 0 ]] && \
        log_info "vector is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __os-vector_run {
    pidof vector | xargs kill -9 2>/dev/null
    systemd-run -r vector -c /etc/vector/vector.toml
    pidof vector && return 0 || return 1
}

complete -F _blank os-vector