# shellcheck shell=bash
cite about-plugin
about-plugin 'step-cli install configurations.'
# todo

function misc-step {
    about 'step-cli install configurations'
    group 'misc'
    param '1: command'
    param '2: params'
    example '$ misc-step check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __misc-step_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __misc-step_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __misc-step_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __misc-step_run "$2"
    else
        __misc-step_help
    fi
}

function __misc-step_help {
    echo -e "Usage: misc-step [COMMAND] [profile]\n"
    echo -e "Helper to step-cli install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install step-cli"
    echo "   uninstall Uninstall installed step-cli"
    echo "   check     Check vars available"
    echo "   run       run"
}

function __misc-step_install {
    log_debug "Trying to install misc-step."
    apt install -qy ./pkgs/step-cli*.deb
}

function __misc-step_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall misc-step."
    apt purge -qy step-cli
}

function __misc-step_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting misc-step Check"
    [[ ${#RUN_KNOCKD_WITH_STEPTOTP[@]} -lt 1 ]] && \
        log_info "RUN_KNOCKD_WITH_STEPTOTP variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ $(dpkg -l|awk '{print $2}'|grep step-cli|wc -l) -lt 1 ]] && \
        log_info "step-cli is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    return 0
}

function __misc-step_run {
    return 0
}

complete -F __misc-step_run misc-step