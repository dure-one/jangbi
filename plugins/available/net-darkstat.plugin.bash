# shellcheck shell=bash
cite about-plugin
about-plugin 'darkstat install configurations.'

function net-darkstat {
    about 'darkstat install configurations'
    group 'net'
    param '1: command'
    param '2: params'
    example '$ net-darkstat check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
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
    else
        __net-darkstat_help
    fi
}

function __net-darkstat_help {
    echo -e "Usage: net-darkstat [COMMAND] [profile]\n"
    echo -e "Helper to darkstat install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install darkstat"
    echo "   uninstall Uninstall installed  darkstat"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __net-darkstat_install {
    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install net-darkstat."
    apt install -qy ./pkgs/darkstat*
    cp ./configs/darkstat.init.cfg.default /etc/darkstat/init.cfg
    sed -i "s|START_DARKSTAT=.*|START_DARKSTAT=yes|g" /etc/darkstat/init.cfg
    sed -i "s|INTERFACE=.*|INTERFACE=${DURE_WANINF}|g" /etc/darkstat/init.cfg
}

function __net-darkstat_disable { # UPDATE_FIRMWARE=0
    pidof darkstat | xargs kill -9 2>/dev/null
    return 0
}

function __net-darkstat_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall net-darkstat."
    pidof darkstat | xargs kill -9 2>/dev/null
    apt purge -qy darkstat
}

function __net-darkstat_check { ## running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting net-darkstat Check"

    # check global variable
    [[ -z ${RUN_DARKSTAT} ]] && \
        log_info "RUN_DARKSTAT variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_DARKSTAT} != 1 ]] && \
        log_info "RUN_DARKSTAT is not enabled." && __net-darkstat_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(dpkg -l|awk '{print $2}'|grep -c "darkstat") -lt 1 ]] && \
        log_info "darkstat is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof darkstat) -lt 1 ]] && \
        log_info "darkstat is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-darkstat_run {
    log_debug "Running darkstat_run..."
    log_debug "Printing darkstat configuration:"
    log_debug "$(grep -v "#" < "/etc/darkstat/init.cfg"|grep -v -e '^[[:space:]]*$')"
    log_debug "==========================================================="

    pidof darkstat|xargs kill &>/dev/null
    # shellcheck disable=SC1091
    source /etc/darkstat/init.cfg && darkstat $INTERFACE $PORT --chroot $DIR --pidfile $PIDFILE $BINDIP $LOCAL $FIP $DNS $DAYLOG $DB $OPTIONS
    pidof darkstat && return 0 || return 1
}

complete -F __net-darkstat_run net-darkstat