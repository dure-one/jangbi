## \brief bandwhich network monitoring tool. <div style="text-align: right"> group:**postnet** | runtype:**minmon** | deps: **-** | port: **-**</div><br/>
## \desc
## [bandwhich](https://github.com/imsnif/bandwhich){:target="_blank"} is a CLI utility for displaying current network utilization by process, connection and remote IP/hostname.
# It provides real-time network bandwidth monitoring and logging capabilities.
# bandwhich offers detailed network statistics for monitoring and troubleshooting network activity.
##
## # Jangbi Configs
## ```bash title="/opt/jangbi/.config"
## RUN_NET_BANDWHICH=1 # enable bandwhich monitoring
## BANDWHICH_TARGET="1.1.1.1" # target IP for monitoring
## ```
## # Check if running
## ```bash title="bash command"
## $ ps aux|grep bandwhich
## root     12345  0.0  0.0 123456 12345 ?        S    00:00   0:00 bandwhich -r -s -d 1.1.1.1 -c
## $ pidof bandwhich
## 12345
## ```
## # Log files
## Network traffic logs are stored in `/var/log/bandwhich/bandwhich.log`

# shellcheck shell=bash
cite about-plugin
about-plugin 'bandwhich network monitoring tool.'

function net-bandwhich {
    about 'bandwhich network monitoring tool'
    group 'postnet'
    runtype 'minmon'
    deps ''
    param '1: command'
    param '2: params'
    example '$ net-bandwhich subcommand'
    local PKGNAME="bandwhich"
    local DMNNAME="net-bandwhich"
    BASH_IT_LOG_PREFIX="net-bandwhich: "
    BANDWHICH_TARGET="${BANDWHICH_TARGET:-"1.1.1.1"}"
    if _check_config_reload; then
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "help" ]]; then
        __net-bandwhich_help "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-bandwhich_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-bandwhich_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-bandwhich_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disable" ]]; then
        __net-bandwhich_disable "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-bandwhich_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-bandwhich_run "$2"
    else
        __net-bandwhich_help
    fi
}

## \usage net-bandwhich help|install|uninstall|download|disable|check|run
## $ net-bandwhich install - install bandwhich network monitoring tool
## $ net-bandwhich uninstall - uninstall bandwhich
## $ net-bandwhich download - download bandwhich package files to pkg dir
## $ net-bandwhich disable - disable bandwhich plugin
## $ net-bandwhich check - check bandwhich plugin status
## $ net-bandwhich run - run bandwhich monitoring service
## $ net-bandwhich help - show this help message
function __net-bandwhich_help {
    echo -e "Usage: net-bandwhich [COMMAND]\n"
    echo -e "Helper to bandwhich network monitoring tool.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install bandwhich"
    echo "   uninstall   Uninstall installed bandwhich"
    echo "   download    Download pkg files to pkg dir"
    echo "   disable     Disable bandwhich service"
    echo "   check       Check vars available"
    echo "   run         run"
}

function __net-bandwhich_install {
    log_debug "Installing ${DMNNAME}..."

    local filepat="./pkgs/bandwhich-*-unknown-linux-musl.tar.gz"
    local tmpdir="/tmp/bandwhich"
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    mkdir -p ${tmpdir} 1>/dev/null 2>&1

    [[ $(find ${filepat} 2>/dev/null|wc -l) -lt 1 ]] && __net-bandwhich_download
    tar -zxf ${filepat} -C ${tmpdir} 2>/dev/null
    if [[ ! -f /tmp/bandwhich/bandwhich ]]; then
        log_error "bandwhich binary not found in package."
        return 1
    fi

    # copy to /usr/sbin
    cp ${tmpdir}/bandwhich /usr/sbin/bandwhich
    chmod 755 /usr/sbin/bandwhich
    rm -rf ${tmpdir} 1>/dev/null 2>&1

    # create log directory
    mkdir -p /var/log/bandwhich
    touch /var/log/bandwhich/bandwhich.log
}

function __net-bandwhich_download {
    log_debug "Downloading ${DMNNAME}..."
    arch1_=$(dpkg --print-architecture)
    arch1=${3:-${arch1_}}
    [[ ${arch1} == "amd64" ]] && comparch="x86_64"
    [[ ${arch1} == "arm64" ]] && comparch="aarch64"

    _download_github_pkgs imsnif/bandwhich bandwhich-*-unknown-linux-musl.tar.gz "${comparch}" || log_error "${DMNNAME} download failed."
    return 0
}

function __net-bandwhich_disable {
    log_debug "Disabling ${DMNNAME}..."
    pidof bandwhich | xargs kill -9 2>/dev/null
    return 0
}

function __net-bandwhich_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    pidof bandwhich | xargs kill -9 2>/dev/null
    rm -rf /usr/sbin/bandwhich
}

function __net-bandwhich_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check package file exists
    [[ $(find ./pkgs/bandwhich-*-unknown-linux-musl.tar.gz 2>/dev/null|wc -l) -lt 1 ]] && \
        log_info "bandwhich package file does not exist." && [[ $running_status -lt 15 ]] && running_status=15
    # check global variable
    [[ -z ${RUN_NET_BANDWHICH} ]] && \
        log_info "RUN_NET_BANDWHICH variable is not set." && __net-bandwhich_disable && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_BANDWHICH} != 1 ]] && \
        log_info "RUN_NET_BANDWHICH is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which bandwhich 2>/dev/null|wc -l) -lt 1 ]] && \
        log_info "bandwhich is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof bandwhich) -gt 0 ]] && \
        log_info "bandwhich is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-bandwhich_run {
    log_debug "Running ${DMNNAME}..."

    pidof bandwhich | xargs kill &>/dev/null

    log_debug "Starting bandwhich monitoring for ${BANDWHICH_TARGET}"
    bandwhich -r -s -d "${BANDWHICH_TARGET}" -c 2>&1 | grep -v Refreshing | grep -v "NO TRAFFIC" >> /var/log/bandwhich/bandwhich.log &

    pidof bandwhich && return 0 || \
        log_error "bandwhich failed to run." && return 0
}

complete -F _blank net-bandwhich
