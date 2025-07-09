# shellcheck shell=bash
cite about-plugin
about-plugin 'aide install configurations.'

function os-aide {
    about 'aide install configurations'
    group 'prenet'
    runtype 'none' # systemd, minmon, none
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-aide check/install/uninstall/run'

    if [[ -z ${JB_VARS} ]]; then
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
    log_debug "Trying to install os-aide."

    export DEBIAN_FRONTEND=noninteractive
    [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
    [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
    [[ $(dpkg -l|awk '{print $2}'|grep -c "aide") -lt 1 ]] && apt install -qy aide
    
    mkdir -p /etc/aide /var/lib/aide /var/log/aide
    cp -rf ./configs/aide/aide.conf /etc/aide/aide.conf # normal configurations
    cp -rf ./configs/aide/aide.minimal.conf /etc/aide/aide.minimal.conf # minimal configurations
    
    # log_debug "aide db is generating on background."
    aide --init --config=/etc/aide/aide.minimal.conf 2>/dev/null && \
        cp /var/lib/aide/aide.minimal.db.new.gz /var/lib/aide/aide.minimal.db.gz
    # aide --init --config=/etc/aide/aide.conf &>jangbi_aide.log &
}

function __os-aide_uninstall { 
    log_debug "Trying to uninstall os-aide."
    apt purge -yq aide
}

function __os-aide_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting os-aide Check"

    # check global variable
    [[ -z ${RUN_OS_AIDE} ]] && \
        log_error "RUN_OS_AIDE variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_AIDE} != 1 ]] && \
        log_error "RUN_OS_AIDE is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package aide
    [[ $(dpkg -l|awk '{print $2}'|grep -c "aide") -lt 1 ]] && \
        log_info "aide is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof aide) -gt 0 ]] && \
        log_info "aide is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __os-aide_run {
    ## aide minimal check for first run
    systemd-run -r aide --check --config=/etc/aide/aide.minimal.conf
    return 0
}

complete -F __os-aide_run os-aide