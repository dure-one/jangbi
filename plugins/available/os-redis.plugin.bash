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

function __os-redis_check { # check config, installation
    log_debug "Starting os-redis Check"
	systemctl status redis-server
}

function __os-redis_run {
    systemctl start redis-server
	return 0
}

complete -F __os-redis_run os-redis