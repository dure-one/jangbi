# shellcheck shell=bash
cite about-plugin
about-plugin 'redis install configurations.'

function os-redis {
    about 'redis install configurations'
    group 'postnet'
    runtype 'systemd'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-redis check/install/uninstall/run'

    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-redis_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-redis_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-redis_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-redis_run "$2"
    else
        __os-redis_help
    fi
}

function __os-redis_help {
    echo -e "Usage: os-redis [COMMAND] [profile]\n"
    echo -e "Helper to redis install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os firmware"
    echo "   uninstall Uninstall installed firmware"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-redis_install {
    log_debug "Trying to install os-redis."
    export DEBIAN_FRONTEND=noninteractive
    [[ $(find /etc/apt/sources.list.d|grep -c "redis") -lt 1 ]] && extrepo enable redis; apt update -qy
    [[ $(dpkg -l|awk '{print $2}'|grep -c "redis-server") -lt 1 ]] && apt install -qy redis-server
    # apt-get update -qy -o Dir::Etc::sourcelist="sources.list.d/redis.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
    mkdir -p /var/log/redis
    chown redis:redis /var/log/redis
    systemctl enable redis-server
}

function __os-redis_uninstall { 
    log_debug "Trying to uninstall os-redis."
    systemctl stop redis-server
    systemctl disable redis-server
}

function __os-redis_disable { 
    systemctl stop redis-server
    systemctl disable redis-server
    return 0
}

function __os-redis_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting os-redis Check"

    # check global variable
    [[ -z ${RUN_OS_REDIS} ]] && \
        log_error "RUN_OS_REDIS variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_REDIS} != 1 ]] && \
        log_error "RUN_OS_REDIS is not enabled." && __os-redis_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(dpkg -l|awk '{print $2}'|grep -c "redis-server") -lt 1 ]] && \
        log_info "redis-server is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof redis-server) -gt 0 ]] && \
        log_info "redis-server is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __os-redis_run {
    log_debug "Starting os-redis Check"
    systemctl status redis-server 2>/dev/null
}

complete -F __os-redis_run os-redis