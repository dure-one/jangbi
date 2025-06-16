# shellcheck shell=bash
cite about-plugin
about-plugin 'crond install configurations.'
# C : DURE_TIMESYNC DURE_DEPLOY_PATH DNS_UPSTREAM

function os-crond {
    about 'crond install configurations'
    group 'os'
    param '1: command'
    param '2: params'
    example '$ os-crond check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-crond_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-crond_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-crond_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-crond_run "$2"
    else
        __os-crond_help
    fi
}

function __os-crond_help {
    echo -e "Usage: os-crond [COMMAND] [profile]\n"
    echo -e "Helper to crond install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install crond"
    echo "   uninstall Uninstall installed crond"
    echo "   check     Check vars available"
    echo "   run       Run crond jobs"
}

function __os-crond_install {
    log_debug "Trying to install os-crond."

    export DEBIAN_FRONTEND=noninteractive
    apt install -qy cron
    systemctl enable cron

    # add to crontab for root
    echo "" > /tmp/mycron
    if [[ ${DURE_TIMESYNC} == 'http' ]]; then # DURE_TIMESYNC=http
        echo "*/10 * * * * cd ${DURE_DEPLOY_PATH} && source functions.sh _time_sync ${DNS_UPSTREAM} # DURE_TIMESYNC" >> /tmp/mycron
    else # DURE_TIMESYNC=ntp
        cp ./configs/ntpclient.pl /sbin/ntpclient.pl
        chmod +x /sbin/ntpclient.pl
        echo "*/10 * * * * /sbin/ntpclient.pl # DURE_TIMESYNC" >> /tmp/mycron
    fi
    crontab /tmp/mycron
    rm /tmp/mycron
}

function __os-crond_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall os-crond."
    systemctl stop cron
    systemctl disable cron
}

function __os-crond_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting os-crond Check"
    # check global variable
    [[ ${RUN_CRON} -lt 1 ]] && \
        log_info "RUN_CRON variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    # check package installed
    [[ $(dpkg -l|awk '{print $2}'|grep -c "cron") -lt 1 ]] && \
        log_info "cron is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(systemctl status cron 2>/dev/null|grep Active|grep -c "running") -gt 0 ]] && \
        log_info "cron is started." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __os-crond_run {
    systemctl start cron
    pidof cron && return 0 || return 1
}

complete -F __os-crond_run os-crond