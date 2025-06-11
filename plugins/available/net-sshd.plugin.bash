# shellcheck shell=bash
cite about-plugin
about-plugin 'sshd install configurations.'
# C : OSLOCAL_SETTING, DURE_SWAPSIZE, DURE_DEPLOY_PATH

function net-sshd {
	about 'sshd install configurations'
	group 'net'
    param '1: command'
    param '2: params'
    example '$ net-sshd check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

	if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
		__net-sshd_install "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
		__net-sshd_uninstall "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
		__net-sshd_check "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
		__net-sshd_run "$2"
	else
		__net-sshd_help
	fi
}

function __net-sshd_help {
	echo -e "Usage: net-sshd [COMMAND] [profile]\n"
	echo -e "Helper to sshd install configurations.\n"
	echo -e "Commands:\n"
	echo "   help      Show this help message"
	echo "   install   Install os firmware"
	echo "   uninstall Uninstall installed firmware"
	echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __net-sshd_install {
    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install net-sshd."
    apt install -qy openssh-server
    # config settings
    SSH_CONFIG=""
    [[ ${SSHD_PORT} -gt 0 ]] && SSH_CONFIG="${SSH_CONFIG}\nPort ${SSHD_PORT}" && sed -i "s|Port=.*||g" /etc/ssh/sshd_config
    [[ ${SSHD_ADDR} -gt 0 ]] && SSH_CONFIG="${SSH_CONFIG}\nListenAddress ${SSHD_ADDR}" && sed -i "s|ListenAddress=.*||g" /etc/ssh/sshd_config
    [[ ${DISABLE_IPV6} -gt 0 ]] && SSH_CONFIG="${SSH_CONFIG}\nAddressFamily inet" && sed -i "s|AddressFamily=.*||g" /etc/ssh/sshd_config
    echo -e "\n\n${SSH_CONFIG}\n\n" >> /etc/ssh/sshd_config
}

function __net-sshd_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall net-sshd."
    systemctl stop ssh
    systemctl disable ssh
}

function __net-sshd_check { # return 0 can install, return 1 can't install, return 2 installed
	local return_code=0
    log_debug "Starting net-sshd Check"
    # check variable exists
    [[ -z ${RUN_SSHD} ]] && echo "ERROR: RUN_SSHD variable is not set." && return 1
    # check pkg installed
    [[ $(dpkg -l|grep openssh-server|wc -l) -lt 1 ]] && echo "ERROR: sshd is not installed." && return 0
    # check dnsmasq started
    [[ $(pidof openssh-server|wc -l) -gt 1 ]] && echo "INFO: sshd is started." && return_code=2

    return 0
}

function __net-sshd_run {
    systemctl start ssh
	return 0
}

complete -F __net-sshd_run net-sshd