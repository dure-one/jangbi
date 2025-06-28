# shellcheck shell=bash
cite about-plugin
about-plugin 'aide install configurations.'

function os-aide {
    about 'aide install configurations'
    group 'prenet'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-aide check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-aide_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-aide_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-aide_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-aide_run "$2"
    else
        __os-aide_help
    fi
}

function __os-aide_help {
    echo -e "Usage: os-aide [COMMAND] [profile]\n"
    echo -e "Helper to aide install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os aide"
    echo "   uninstall Uninstall installed aide"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-aide_install {
    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install os-aide."
    apt install -yq ./pkgs/aide*.deb
    mkdir -p /etc/aide
    mkdir -p /var/lib/aide
    mkdir -p /var/log/aide
    cp -rf ./configs/aide.conf /etc/aide/aide.conf # normal configurations
    cp -rf ./configs/aide.minimal.conf /etc/aide/aide.minimal.conf # minimal configurations
    # aide --init --config=/etc/aide/aide.conf &>jangbi_aide.log &
    log_debug "aide db is generating on background."
}

function __os-aide_uninstall { # RUN_OS_FIRMWARE=0
    log_debug "Trying to uninstall os-aide."
    apt purge -yq aide
}

function __os-aide_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting os-aide Check"

    # check global variable
    [[ -z ${RUN_OS_AIDE} ]] && \
        log_info "RUN_OS_AIDE variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_AIDE} != 1 ]] && \
        log_info "RUN_OS_AIDE is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package aide
    [[ $(dpkg -l|awk '{print $2}'|grep -c "aide") -lt 1 ]] && \
        log_info "aide is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof aide) -lt 1 ]] && \
        log_info "aide is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __os-aide_run {
    ## aide minimal check for first run
    if [[ ! -f /var/lib/aide/aide.minimal.db.new.gz ]]; then
      ( aide --init --config=/etc/aide/aide.minimal.conf 2>/dev/null && \
        cp /var/lib/aide/aide.minimal.db.new.gz /var/lib/aide/aide.minimal.db.gz ) &
    fi
    return 0
}

complete -F __os-aide_run os-aide