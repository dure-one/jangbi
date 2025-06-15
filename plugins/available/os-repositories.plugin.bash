# shellcheck shell=bash
cite about-plugin
about-plugin 'setup for offline os repository.'
# VARS DURE_DEPLOY_PATH DIST_PKG_IMG OS_PKG_UPSTREAM

function os-repository {
	about 'helper function for offline os repository'
	group 'os'
    param '1: command'
    param '2: params'
    example '$ os-repository check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

	if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
		__os-repository_install "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
		__os-repository_uninstall "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
		__os-repository_check "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
		__os-repository_run "$2"
	else
		__os-repository_help
	fi
}

function __os-repository_help {
	echo -e "Usage: os-repository [COMMAND] [profile]\n"
	echo -e "Helper to offline packgage repository.\n"
	echo -e "Commands:\n"
	echo "   help      Show this help message"
	echo "   install   Install os repository"
	echo "   uninstall Uninstall installed repository"
	echo "   check     Check installable"
    echo "   run       Run tasks"
}

function __os-repository_install {
    log_debug "Trying to install os-repository."
    mkdir -p ${DURE_DEPLOY_PATH}/imgs/debian
    # mount pkg iso img
    [[ $(mount|grep ${DURE_DEPLOY_PATH}/imgs/debian|wc -l) -lt 1 ]] && mount -o loop ${DURE_DEPLOY_PATH}/imgs/${DIST_PKG_IMG} ${DURE_DEPLOY_PATH}/imgs/debian
    # add offline repository
    if [[ $(cat /etc/apt/sources.list|grep file:|wc -l) -lt 1 ]]; then
        [[ -d "/etc/apt/source.list.d" ]] && mv /etc/apt/source.list.d /etc/apt/source.list.d_old
        [[ ! -f "/etc/apt/sources.list.orig" ]] && mv /etc/apt/sources.list /etc/apt/sources.list.orig
        mv /etc/apt/sources.list /etc/apt/sources.list.$(date +"%Y%m%d") 2>&1 1>/dev/null
        tee /etc/apt/sources.list > /dev/null <<EOT
deb [trusted=yes] file:${DURE_DEPLOY_PATH}/imgs/debian/ bookworm main contrib non-free non-free-firmware
deb ${OS_PKG_UPSTREAM}/debian-security bookworm-security main contrib non-free non-free-firmware
EOT
        apt update -qy
    fi
}

function __os-repository_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall os-repository."
    [[ -d "/etc/apt/source.list.d_old" ]] && mv /etc/apt/source.list.d_old /etc/apt/source.list.d
    mv /etc/apt/sources.list /etc/apt/sources.list.$(date +"%Y%m%d") 2>&1 1>/dev/null
    mv /etc/apt/sources.list.orig /etc/apt/sources.list
}

function __os-repository_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting os-repository Check"

    [[ ${#OFFLINE_REPOSITORY[@]} -lt 1 ]] && \
        log_info "OFFLINE_REPOSITORY variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ! -f "${DIST_PKG_IMG}" ]] && \
        log_info "Pkg image can not be found on ${DIST_PKG_IMG}" && [[ $running_status -lt 10 ]] && running_status=10

    # check img file mounted and apt source direct it # check apt repository directed to offline repo
    [[ $(mount |grep "${DURE_DEPLOY_PATH}/imgs/debian/"|wc -l) -gt 0 ]] && \
        log_info "INFO: offline image has mounted to ${DURE_DEPLOY_PATH}/imgs/debian." && \
        [[ $(cat /etc/apt/sources.list|grep file:|wc -l) -lt 1 ]] && \
        log_info "INFO: apt/sources.list has file directed to offline mounted path." && \
        [[ $running_status -lt 0 ]] && running_status=0
    return 0
}

function __os-repository_run {
    mkdir -p ${DURE_DEPLOY_PATH}/imgs/debian
    [[ $(mount |grep "${DURE_DEPLOY_PATH}/imgs/debian/"|wc -l) -lt 1 ]] && \
        mount -o loop ${DURE_DEPLOY_PATH}/imgs/${DIST_PKG_IMG} ${DURE_DEPLOY_PATH}/imgs/debian
        apt install --fix-broken
	return 0
}

complete -F __os-repository_run os-repository