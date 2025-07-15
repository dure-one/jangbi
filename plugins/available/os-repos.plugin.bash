# shellcheck shell=bash
cite about-plugin
about-plugin 'setup for offline os repository.'

function os-repos {
    about 'helper function for offline os repository'
    group 'postnet'
    runtype 'none'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-repos subcommand'
    local PKGNAME="repos"
    local DMNNAME="os-repos"

    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-repos_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-repos_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-repos_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-repos_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "enableall" ]]; then
        __os-repos_extrepo_enable_all "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disableall" ]]; then
        __os-repos_extrepo_disable_all "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "enableoff" ]]; then
        __os-repos_enable_offline "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disableoff" ]]; then
        __os-repos_disable_offline "$2"
    else
        __os-repos_help
    fi
}

function __os-repos_help {
    echo -e "Usage: os-repos [COMMAND] [profile]\n"
    echo -e "Helper to offline packgage repository.\n"
    echo -e "Commands:\n"
    echo "   help          Show this help message"
    echo "   install       Install os repository"
    echo "   uninstall     Uninstall installed repository"
    echo "   enableall     Enable all additional repository"
    echo "   disableall    Disable all additional repository"
    echo "   enableoff     Enable offline repository"
    echo "   disableoff    Disable offline repository"
    echo "   check         Check installable"
    echo "   run           Run tasks"
}

function __os-repos_install {
    log_debug "Trying to install os-repos."

    log_debug "Removing all sources.list, source.list.d..."
    __os-repos_empty_all_repo
    log_debug "Add Offline repository..."
    __os-repos_enable_offline
}

function __os-repos_empty_all_repo {
    mv /etc/apt/sources.list /etc/apt/sources.list_$(date +"%Y%m%d").bak
    touch /etc/apt/sources.list
    mv /etc/apt/sources.list.d /etc/apt/sources.list.d_$(date +"%Y%m%d").bak
    mkdir -p /etc/apt/sources.list.d
}

function __os-repos_extrepo_enable_all {
    for f in /etc/apt/sources.list.d/*.sources; do sed -i "s|Enabled:.*||g" "${f}" && echo "Enabled: yes" >> "${f}"; done
}

function __os-repos_extrepo_disable_all {
    for f in /etc/apt/sources.list.d/*.sources; do sed -i "s|Enabled:.*||g" "${f}" && echo "Enabled: no" >> "${f}"; done
}

function __os-repos_enable_offline {
    mkdir -p "${JB_DEPLOY_PATH}/imgs/debian"

    # mount pkg iso img
    [[ $(mount|grep -c "imgs/debian") -lt 1 ]] && \
        mount -o loop "${JB_DEPLOY_PATH}/imgs/${DIST_PKG_IMG}" "${JB_DEPLOY_PATH}/imgs/debian"
    
    # add offline repository
    if [[ $(grep -c "file:" < "/etc/apt/sources.list") -lt 1 ]]; then
        tee -a /etc/apt/sources.list > /dev/null <<EOT
deb [trusted=yes] file:${JB_DEPLOY_PATH}/imgs/debian bookworm main contrib non-free non-free-firmware # DEBIAN OFFLINEREPO
EOT
    fi
    # if [[ $(grep -c "cdrom:" < "/etc/apt/sources.list") -lt 1 ]]; then
    #     apt-cdrom --cdrom="${JB_DEPLOY_PATH}/imgs/${DIST_PKG_IMG}" add --no-mount
    # fi
}

function __os-repos_disable_offline {
    # remove offline repository
    sed -i "s|^.*# DEBIAN SECURITY||g" "/etc/apt/sources.list"

    # unmonting
    umount /opt/jangbi/imgs/debian
}

function __os-repos_uninstall { 
    log_debug "Trying to uninstall os-repos."

    __os-repos_disable_offline
    __os-repos_extrepo_disable_all
    extrepo enable debian_official
}

function __os-repos_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting os-repos Check"
    # REPOS_UPSTREAM

    # check global variable
    [[ -z ${RUN_OS_REPOS} ]] && \
        log_error "RUN_OS_REPOS variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_REPOS} != 1 ]] && \
        log_error "RUN_OS_REPOS is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    [[ ! -f "${DIST_PKG_IMG}" ]] && \
        log_error "Pkg image can not be found on ${DIST_PKG_IMG}" && [[ $running_status -lt 10 ]] && running_status=10

    # check img file mounted and apt source direct it # check apt repository directed to offline repo
    [[ $(mount |grep -c "imgs/debian") -lt 1 ]] && \
        log_info "offline image not mounted." && [[ $running_status -lt 5 ]] && running_status=5

    [[ $(grep -c "cdrom:" < "/etc/apt/sources.list") -lt 1 ]] && \
        log_info "apt/sources.list don't have offline mounted path." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __os-repos_run {
    log_debug "Mounting debian image to ${JB_DEPLOY_PATH}/imgs/debian/..."
    mkdir -p "${JB_DEPLOY_PATH}/imgs/debian"
    [[ $(mount |grep -c "${JB_DEPLOY_PATH}/imgs/debian") -lt 1 ]] && \
        mount -o loop "${JB_DEPLOY_PATH}/${DIST_PKG_IMG}" "${JB_DEPLOY_PATH}/imgs/debian"
    
    log_debug "Apt Packages Fixing..."
    apt update -qy && apt install --fix-broken -qy
    return 0
}

complete -F _blank os-repos