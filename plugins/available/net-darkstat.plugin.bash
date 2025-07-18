## \brief darkstat install configurations.
## \desc This tool helps install, configure, and manage darkstat (network traffic analyzer)
## for network monitoring. It provides automated installation, configuration management,
## and service control capabilities. Darkstat captures network packets on a specified
## interface and provides web-based statistics about network usage and traffic patterns.

## \example Install and configure darkstat:
## \example-code bash
##   net-darkstat install
##   net-darkstat configgen
##   net-darkstat configapply
## \example-description
## In this example, we install darkstat, generate the configuration files,
## and apply them to the system for network traffic monitoring.

## \example Run darkstat and check status:
## \example-code bash
##   net-darkstat run
##   net-darkstat check
## \example-description
## In this example, we start the darkstat service to begin network monitoring
## and verify that the service is running properly.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'darkstat install configurations.'

function net-darkstat {
    about 'darkstat install configurations'
    group 'postnet'
    runtype 'minmon'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ net-darkstat subcommand'
    local PKGNAME="darkstat"
    local DMNNAME="net-darkstat"
    BASH_IT_LOG_PREFIX="net-darkstat: "
    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-darkstat_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-darkstat_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-darkstat_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-darkstat_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-darkstat_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-darkstat_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-darkstat_download "$2"
    else
        __net-darkstat_help
    fi
}

## \usage net-darkstat [COMMAND] [profile]
## \usage net-darkstat install|uninstall|configgen|configapply
## \usage net-darkstat check|run|download
function __net-darkstat_help {
    echo -e "Usage: net-darkstat [COMMAND] [profile]\n"
    echo -e "Helper to darkstat install configurations.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install darkstat"
    echo "   offinstall  Offline install darkstat"
    echo "   uninstall   Uninstall darkstat"
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   download    Download pkg files to pkg dir"
    echo "   check       Check vars available"
    echo "   run         Run tasks"
}

function __net-darkstat_install {
    INTERNET_AVAIL=0
    log_debug "Installing ${DMNNAME}..."
    export DEBIAN_FRONTEND=noninteractive
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
        [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
        apt install -qy darkstat || log_error "${DMNNAME} online install failed."
    else
        local filepat="./pkgs/darkstat*.deb"
        local pkglist="./pkgs/darkstat.pkgs"
        [[ $(find ${filepat}|wc -l) -lt 1 ]] && log_error "${DMNNAME} pkg file not found."
        pkgslist_down=()
        while read -r pkg; do
            [[ $pkg ]] && pkgslist_down+=("./pkgs/${pkg}*.deb")
        done < ${pkglist}
        # shellcheck disable=SC2068
        apt install -qy ${pkgslist_down[@]} || log_error "${DMNNAME} offline install failed."
    fi
    if ! __net-darkstat_configgen; then # if gen config is different do apply
        __net-darkstat_configapply
        rm -rf /tmp/darkstat
    fi
}

function __net-darkstat_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    [[ ${#JB_WANINF} -lt 1 ]] && log_error "JB_WANINF is not set" && exit 1

    rm -rf "/tmp/${PKGNAME}" 1>/dev/null 2>&1
    mkdir -p "/tmp/${PKGNAME}" "/etc/${PKGNAME}" 1>/dev/null 2>&1
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    # instant edit
    sed -i "s|START_DARKSTAT=.*|START_DARKSTAT=yes|g" /tmp/darkstat/init.conf
    sed -i "s|INTERFACE=.*|INTERFACE=${JB_WANINF}|g" /tmp/darkstat/init.conf
    # diff check
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-darkstat_configapply {
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

function __net-darkstat_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_apt_pkgs darkstat || log_error "${DMNNAME} download failed."
    return 0
}

function __net-darkstat_disable {
    log_debug "Disabling ${DMNNAME}..."
    pidof darkstat | xargs kill -9 2>/dev/null
    return 0
}

function __net-darkstat_uninstall { 
    log_debug "Uninstalling ${DMNNAME}..."
    pidof darkstat | xargs kill -9 2>/dev/null
    apt purge -qy darkstat
}

function __net-darkstat_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check global variable
    [[ -z ${RUN_NET_DARKSTAT} ]] && \
        log_error "RUN_NET_DARKSTAT variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_DARKSTAT} != 1 ]] && \
        log_error "RUN_NET_DARKSTAT is not enabled." && __net-darkstat_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(dpkg -l|awk '{print $2}'|grep -c "darkstat") -lt 1 ]] && \
        log_info "darkstat is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof darkstat) -gt 0 ]] && \
        log_info "darkstat is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-darkstat_run {
    log_debug "Running ${DMNNAME}..."
    
    pidof darkstat|xargs kill &>/dev/null
    # darkstat binary does killed right after its run. for make sure, running it twice. 
    # shellcheck disable=SC1091
    source /etc/darkstat/init.conf && \
        systemd-run -r darkstat -i $INTERFACE $PORT --chroot $DIR --pidfile $PIDFILE $BINDIP $LOCAL $FIP $DNS $DAYLOG $DB $OPTIONS && \
        systemd-run -r darkstat -i $INTERFACE $PORT --chroot $DIR --pidfile $PIDFILE $BINDIP $LOCAL $FIP $DNS $DAYLOG $DB $OPTIONS
    pidof darkstat && return 0 || return 1
}

complete -F _blank net-darkstat
