# shellcheck shell=bash
cite about-plugin
about-plugin 'redis install configurations.'
# C : OSLOCAL_SETTING, DURE_SWAPSIZE, DURE_DEPLOY_PATH

function os-redis {
    about 'redis install configurations'
    group 'os'
    param '1: command'
    param '2: params'
    example '$ os-redis check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
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
    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install os-redis."
    apt -qy install lsb-release curl gpg
    curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
    apt -qy update
    apt -qy  install redis-server
    mkdir -p /var/log/redis
    chown redis:redis /var/log/redis
    systemctl enable redis-server
}

function __os-redis_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall os-redis."
    systemctl stop redis-server
    systemctl disable redis-server
}

function __os-redis_disable { # UPDATE_FIRMWARE=0
    systemctl stop redis-server
    systemctl disable redis-server
    return 0
}

function __os-redis_check { # check config, installation
    running_status=0
    log_debug "Starting os-redis Check"

    # check global variable
    [[ -z ${RUN_REDIS} ]] && \
        log_info "RUN_REDIS variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_REDIS} != 1 ]] && \
        log_info "RUN_REDIS is not enabled." && __os-redis_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(dpkg -l|awk '{print $2}'|grep -c "redis-server") -lt 1 ]] && \
        log_info "redis-server is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof redis-server) -lt 1 ]] && \
        log_info "redis-server is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __os-redis_run {
    log_debug "Starting os-redis Check"
    systemctl status redis-server 2>/dev/null
}

complete -F __os-redis_run os-redis