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
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __os-redis_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __os-redis_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __os-redis_download "$2"
    else
        __os-redis_help
    fi
}

function __os-redis_help {
    echo -e "Usage: os-redis [COMMAND] [profile]\n"
    echo -e "Helper to redis install configurations.\n"
    echo -e "Commands:\n"
    echo "   help         Show this help message"
    echo "   install      Install os firmware"
    echo "   uninstall    Uninstall installed firmware"
    echo "   configgen    Configs Generator"
    echo "   configapply  Apply Configs"
    echo "   download     Download pkg files to pkg dir"
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
    systemctl status redis-server 2>/dev/null
}

complete -F _blank os-redis