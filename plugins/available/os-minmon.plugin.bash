## \brief minimal monitoring system configurations.
## \desc This tool helps install, configure, and manage a minimal monitoring system
## for basic system health and performance tracking. It provides automated installation,
## configuration management, and monitoring service control capabilities. The tool sets up
## lightweight monitoring scripts, cron-based checks, and basic alerting for system resources,
## services, and network connectivity.

## \example Install and configure minimal monitoring:
## \example-code bash
##   os-minmon install
##   os-minmon configgen
##   os-minmon configapply
## \example-description
## In this example, we install the minimal monitoring system, generate configurations,
## and apply them to enable basic system monitoring.

## \example Start monitoring and check status:
## \example-code bash
##   os-minmon run
##   os-minmon check
## \example-description
## In this example, we start the monitoring system and verify
## that the monitoring services are functioning properly.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'minmon install configurations.'

function os-minmon {
    about 'minmon install configurations'
    group 'prenet'
    runtype 'cron'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-minmon subcommand'
    local PKGNAME="minmon"
    local DMNNAME="os-minmon"
    BASH_IT_LOG_PREFIX="os-minmon: "
    # MINMON_PORTS="${MINMON_PORTS:-""}"
    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-minmon_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-minmon_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-minmon_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-minmon_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __os-minmon_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __os-minmon_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __os-minmon_download "$2"
    else
        __os-minmon_help
    fi
}

## \usage os-minmon [COMMAND]
## \usage os-minmon install|uninstall|configgen|configapply
## \usage os-minmon check|run|download
function __os-minmon_help {
    echo -e "Usage: os-minmon [COMMAND]\n"
    echo -e "Helper to minmon install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os firmware"
    echo "   uninstall Uninstall installed firmware"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-minmon_install {
    log_debug "Installing ${DMNNAME}..."

    local filepat="./pkgs/minmon-linux-*.tar.gz"
    local tmpdir="/tmp/minmon"
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    mkdir -p ${tmpdir} 1>/dev/null 2>&1

    [[ $(find ${filepat}|wc -l) -lt 1 ]] && __net-minmon_download
    tar -zxvf ${filepat} -C ${tmpdir} 1>/dev/null 2>&1
    if [[ ! -f /tmp/minmon/minmon ]]; then
        log_error "minmon binary not found in package."
        return 1
    fi
    cp ${tmpdir}/minmon /usr/sbin/minmon
    chmod 700 /sbin/minmon
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    touch /var/log/minmon.log

    if ! __net-minmon_configgen; then # if gen config is different do apply
        __net-minmon_configapply
        rm -rf ${tmpdir}
    fi
}


function __os-minmon_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    __os-minmon_generate_config
    # diff check
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __os-minmon_configapply {
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

function __os-minmon_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_apt_pkgs hostapd || log_error "${DMNNAME} download failed."
    return 0
}

function __os-minmon_generate_config {
    mkdir -p /tmp/minmon
    cp ./configs/minmon/minmon.toml /tmp/minmon/minmon.toml
    enabled_plugins=$(_jangbi-it-describe "plugins" "a" "plugin" "Plugin"|grep \[x\]|awk '{print $1}')
    IFS=$'\n' read -d "" -ra lvars <<< "${enabled_plugins}" # split
    for((j=0;j<${#lvars[@]};j++)){
        log_debug "${lvars[j]}"
        runtype=$(typeset -f -- "${lvars[j]}"|metafor runtype)
        log_debug "runtype: ${runtype}"
        if [[ ${runtype} == "minmon" ]]; then
            cp ./configs/minmon/template.toml /tmp/minmon/template.toml
            sed -i "s|__PLUGINNAME__|${lvars[j]}|g" "/tmp/minmon/template.toml"
            cat /tmp/minmon/template.toml >> /tmp/minmon/minmon.toml
        fi
    }
    rm -rf /tmp/minmon
}

function __os-minmon_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    pidof minmon | xargs kill -9 2>/dev/null
    rm /usr/sbin/minmon
}

function __os-minmon_disabled {
    log_debug "Disabling ${DMNNAME}..."
    pidof minmon | xargs kill -9 2>/dev/null
    return 0
}

function __os-minmon_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check global variable
    [[ -z ${RUN_OS_MINMON} ]] && \
        log_error "RUN_OS_MINMON variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_MINMON} != 1 ]] && \
        log_error "RUN_OS_MINMON is not enabled." && __os-minmon_disabled && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which minmon|grep -c "minmon") -lt 1 ]] && \
        log_info "minmon is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof minmon) -gt 0 ]] && \
        log_info "minmon is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __os-minmon_run {
    log_debug "Running ${DMNNAME}..."
    pidof minmon | xargs kill -9 2>/dev/null
    systemd-run -r minmon /etc/minmon/minmon.toml 2>&1 1>/var/log/minmon.log
    pidof minmon && return 0 || return 1
}

complete -F _blank os-minmon