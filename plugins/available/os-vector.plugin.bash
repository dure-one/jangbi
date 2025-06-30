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
    example '$ os-vector check/install/uninstall/run'

    if [[ -z ${JB_DEPLOY_PATH} ]]; then
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
    else
        __os-vector_help
    fi
}

function __os-vector_help {
    echo -e "Usage: os-vector [COMMAND] [profile]\n"
    echo -e "Helper to vector install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os firmware"
    echo "   uninstall Uninstall installed firmware"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-vector_install {
    export DEBIAN_FRONTEND=noninteractive
    apt install -yq ./pkgs/vector*.deb ./pkgs/sysdig*.deb
    
    mkdir -p /etc/vector
    cp -rf ./configs/vector/vector.conf.default /etc/vector/
   
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
    log_debug "Starting os-vector Check"

    # check global variable
    [[ -z ${RUN_OS_VECTOR} ]] && \
        log_info "RUN_OS_VECTOR variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_VECTOR} != 1 ]] && \
        log_info "RUN_OS_VECTOR is not enabled." && __os-vector_disabled && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(dpkg -l|awk '{print $2}'|grep -c "vector") -lt 1 ]] && \
        log_info "vector is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof vector) -lt 1 ]] && \
        log_info "vector is not running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __os-vector_run {
    pidof vector | xargs kill -9 2>/dev/null
    vector -c /etc/vector/vector.toml &
    pidof vector && return 0 || return 1
}

complete -F __os-vector_run os-vector