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
    elif [[ $# -eq 1 ]] && [[ "$1" = "enableall" ]]; then
        __os-repository_enable_additional "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disableall" ]]; then
        __os-repository-disable_additional "$2"
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
    echo "   enableall    Enable all additional repository"
    echo "   disableall   Disable all additional repository"
    echo "   enableoff    Enable offline repository"
    echo "   disableoff   Disable offline repository"
    echo "   check     Check installable"
    echo "   run       Run tasks"
}

function __os-repository_install {
    log_debug "Trying to install os-repository."
    
    __os-repository_enable_offline
    apt update -qy
}

function __os-repository_enable_additional {
    for f in /etc/apt/sources.list.d/*.list.disabled; do mv "$f" "$(echo $f|sed 's/.list.disabled/.list/g')"; done
}

function __os-repository-disable_additional {
    for f in /etc/apt/sources.list.d/*.list; do mv "$f" "$(echo $f|sed 's/.list$/.list.disabled/g')"; done
}

function __os-repository_enable_offline {
    mkdir -p "${DURE_DEPLOY_PATH}/imgs/debian"

    # mount pkg iso img
    [[ $(mount|grep -c "${DURE_DEPLOY_PATH}/imgs/debian") -lt 1 ]] && \
        mount -o loop "${DURE_DEPLOY_PATH}/imgs/${DIST_PKG_IMG}" "${DURE_DEPLOY_PATH}/imgs/debian"

    # add offline repository
    if [[ $(grep -c "file:" < "/etc/apt/sources.list") -lt 1 ]]; then
        [[ -d "/etc/apt/source.list.d" ]] && mv /etc/apt/source.list.d /etc/apt/source.list.d_old
        [[ ! -f "/etc/apt/sources.list.orig" ]] && mv /etc/apt/sources.list /etc/apt/sources.list.orig
        mv "/etc/apt/sources.list" "/etc/apt/sources.list.$(date +"%Y%m%d")" 1>/dev/null 2>&1
        tee /etc/apt/sources.list > /dev/null <<EOT
deb [trusted=yes] file:${DURE_DEPLOY_PATH}/imgs/debian/ bookworm main contrib non-free non-free-firmware # DEBIAN SECURITY
EOT
    fi
}

function __os-repository-disable_offline {
    # remove offline repository
    sed -i "s|^.*# DEBIAN SECURITY||g" "/etc/apt/sources.list"

    # unmonting
    umount /opt/jangbi/imgs/debian
}

function __os-repository_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall os-repository."
    [[ -d "/etc/apt/source.list.d_old" ]] && mv /etc/apt/source.list.d_old /etc/apt/source.list.d
    mv "/etc/apt/sources.list" "/etc/apt/sources.list.$(date +"%Y%m%d")" 1>/dev/null 2>&1
    mv /etc/apt/sources.list.orig /etc/apt/sources.list
}

function __os-repository_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting os-repository Check"

    # check global variable
    [[ -z ${OFFLINE_REPOSITORY} ]] && \
        log_info "OFFLINE_REPOSITORY variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${OFFLINE_REPOSITORY} != 1 ]] && \
        log_info "OFFLINE_REPOSITORY is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    [[ ! -f "${DIST_PKG_IMG}" ]] && \
        log_info "Pkg image can not be found on ${DIST_PKG_IMG}" && [[ $running_status -lt 10 ]] && running_status=10

    # check img file mounted and apt source direct it # check apt repository directed to offline repo
    [[ $(mount |grep -c "${DURE_DEPLOY_PATH}/imgs/debian/") -gt 0 ]] && \
        log_info "INFO: offline image has mounted to ${DURE_DEPLOY_PATH}/imgs/debian." && \
        [[ $(grep -c "file:" < "/etc/apt/sources.list") -lt 1 ]] && \
        log_info "INFO: apt/sources.list has file directed to offline mounted path." && \
        [[ $running_status -lt 0 ]] && running_status=0
    return 0
}

function __os-repository_run {
    log_debug "Disabling All Additional Repositories..."
    __os-repository-disable_additional

    log_debug "Mounting debian image to ${DURE_DEPLOY_PATH}/imgs/debian/..."
    mkdir -p "${DURE_DEPLOY_PATH}/imgs/debian"
    [[ $(mount |grep -c "${DURE_DEPLOY_PATH}/imgs/debian/") -lt 1 ]] && \
        mount -o loop "${DURE_DEPLOY_PATH}/${DIST_PKG_IMG}" "${DURE_DEPLOY_PATH}/imgs/debian"
    
    log_debug "Apt Packages Fixing..."
    apt update -qy && apt install --fix-broken -qy
    return 0
}

complete -F __os-repository_run os-repository