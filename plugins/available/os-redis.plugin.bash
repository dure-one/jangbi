## \brief redis server install configurations. <div style="text-align: right"> group:**postnet** | runtype:**systemd** | deps: **-** | port: **LO:6379**</div><br/>
## \desc 
## [Redis](https://redis.io/){:target="_blank"} is an in-memory data structure store used as a database, cache, and message broker.
# It provides automated installation, configuration management, and Redis service control capabilities.
# Redis supports various data types and advanced features for modern applications requiring
# high-performance data storage and caching.
## 
## # Jangbi Configs
## ```bash title="/opt/jangbi/.config"
## RUN_OS_REDIS=1 # enable redis server
## REDIS_PORTS="LO:6379" # ports to listen, LO - localhost, 6379 - Redis port
## ```
## # Check if running
## ```bash title="bash command"
## $ ss -nltup|grep redis
## tcp   LISTEN 0      128        127.0.0.1:6379       0.0.0.0:*    users:(("redis-server",pid=12345,fd=6))
## $ redis-cli ping
## PONG
## ```
## # Current Configuration
## Current configuration is stored in `/etc/redis/`. it is generated by `os-redis configgen` command on install.
## You can edit it manually and not run install or configapply commands to keep current configurations.
## ```bash title="/etc/redis/redis.conf"
## ```

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
    example '$ os-redis subcommand'
    local PKGNAME="redis"
    local DMNNAME="os-redis"
    BASH_IT_LOG_PREFIX="os-redis: "
    REDIS_PORTS="${REDIS_PORTS:-"LO:6379"}"
    if _check_config_reload; then
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "help" ]]; then
        __os-redis_help "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-redis_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-redis_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __os-redis_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disable" ]]; then
        __os-redis_disable "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __os-redis_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __os-redis_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-redis_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-redis_run "$2"
    else
        __os-redis_help
    fi
}

## \usage os-redis help|install|uninstall|download|disable|configgen|configapply|check|run
## $ os-redis install - install Redis server
## $ os-redis uninstall - uninstall Redis server
## $ os-redis download - download Redis package files to pkg dir
## $ os-redis disable - disable Redis plugin
## $ os-redis configgen - generate Redis configuration files
## $ os-redis configapply - apply Redis configuration files
## $ os-redis check - check Redis plugin status
## $ os-redis run - run Redis service
## $ os-redis help - show this help message
function __os-redis_help {
    echo -e "Usage: os-redis [COMMAND]\n"
    echo -e "Helper to redis install configurations.\n"
    echo -e "Commands:\n"
    echo "   help         Show this help message"
    echo "   install      Install redis server"
    echo "   uninstall    Uninstall installed redis"
    echo "   download     Download pkg files to pkg dir"
    echo "   disable      Disable redis server"
    echo "   configgen    Configs Generator"
    echo "   configapply  Apply Configs"
    echo "   check        Check vars available"
    echo "   run          Run tasks"
}

function __os-redis_install {
    log_debug "Installing ${DMNNAME}..."
    export DEBIAN_FRONTEND=noninteractive
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        [[ $(find /etc/apt/sources.list.d|grep -c "redis") -lt 1 ]] && extrepo enable redis && apt update -qy
        apt install -qy redis-server || log_error "${DMNNAME} online install failed."
        # apt-get update -qy -o Dir::Etc::sourcelist="sources.list.d/redis.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
    else
        local filepat="./pkgs/${PKGNAME}*.deb"
        local pkglist="./pkgs/${PKGNAME}.pkgs"
        [[ $(find ${filepat}|wc -l) -lt 1 ]] && log_error "${DMNNAME} pkg file not found."
        pkgslist_down=()
        while read -r pkg; do
            [[ $pkg ]] && pkgslist_down+=("./pkgs/${pkg}*.deb")
        done < ${pkglist}
        # shellcheck disable=SC2068
        apt install -qy ${pkgslist_down[@]} || log_error "${DMNNAME} offline install failed."
    fi
    if ! __os-redis_configgen; then # if gen config is different do apply
        __os-redis_configapply
        rm -rf /tmp/${PKGNAME}
    fi
    mkdir -p /var/log/redis
    chown redis:redis /var/log/redis
}

function __os-redis_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    
    # diff check
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __os-redis_configapply {
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

function __os-redis_download {
    log_debug "Downloading ${DMNNAME}..."
    [[ $(find /etc/apt/sources.list.d|grep -c "redis") -lt 1 ]] && extrepo enable redis && apt update -qy
    _download_apt_pkgs redis-server || log_error "${DMNNAME} download failed."
    return 0
}

function __os-redis_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    systemctl stop redis-server
    systemctl disable redis-server
}

function __os-redis_disable {
    log_debug "Disabling ${DMNNAME}..."
    systemctl stop redis-server
    systemctl disable redis-server
    return 0
}

function __os-redis_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

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
    log_debug "Running ${DMNNAME}..."
    systemctl restart redis-server
    pidof redis-server && return 0 || \
        log_error "redis-server failed to run." && return 0
}

complete -F _blank os-redis