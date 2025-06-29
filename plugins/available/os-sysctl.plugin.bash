# shellcheck shell=bash
cite about-plugin
about-plugin 'sysctl install configurations.'

function os-sysctl {
    about 'sysctl install configurations'
    group 'prenet'
    runtype 'none'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-sysctl check/install/uninstall/run'

    if [[ -z ${JB_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-sysctl_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-sysctl_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-sysctl_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-sysctl_run "$2"
    else
        __os-sysctl_help
    fi
}

function __os-sysctl_help {
    echo -e "Usage: os-sysctl [COMMAND] [profile]\n"
    echo -e "Helper to sysctl install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os firmware"
    echo "   uninstall Uninstall installed firmware"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-sysctl_install {
    log_debug "Trying to install sysctl_install."
    # backup original sysctl on first run
    [[ ! -f "/etc/sysctl.orig" ]] && sysctl -a > /etc/sysctl.orig
    chmod 400 /etc/sysctl.orig
}

function __os-sysctl_uninstall { 
    log_debug "Trying to uninstall sysctl_install."
    sysctl -e -p /etc/sysctl.orig &>/dev/null
}

function __os-sysctl_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting os-sysctl Check"
    [[ -z ${RUN_OS_SYSCTL} ]] && \
        log_info "RUN_OS_SYSCTL variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_SYSCTL} != 1 ]] && \
        log_info "RUN_OS_SYSCTL is not enabled." && [[ $running_status -lt 20 ]] && running_status=20

    return 0
}

function __os-sysctl_run {
    # core dump limit
    if [[ $(grep -c "hard\ core\ 0" < "/etc/security/limits.conf") -lt 1 ]]; then
        echo "* hard core 0" >> /etc/security/limits.conf
        echo "* soft core 0" >> /etc/security/limits.conf
    fi

    if [[ $(sysctl kernel.printk|wc -l) -gt 0 ]]; then
        # sysctl hardening
        sysctl -e -p ./configs/sysctl/98-mikehoen-sysctl.conf &>/dev/null
        sysctl -e -p ./configs/sysctl/98-imthenachoman-sysctl.conf &>/dev/null
        sysctl -e -p ./configs/sysctl/98-2dure-sysctl.conf &>/dev/null
        sysctl -e -p ./configs/sysctl/99-disable-coredump.conf &>/dev/null
        sysctl -e -p ./configs/sysctl/99-disable-maxusernamespaces.conf &>/dev/null
    fi

    [[ $(sysctl kernel.panic|awk '{print $3}') == '10' ]]

    return 0
}

complete -F __os-sysctl_run os-sysctl