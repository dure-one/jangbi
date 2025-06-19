# shellcheck shell=bash
cite about-plugin
about-plugin 'custom os configurations'

function os-conf {
    about 'helper function for os configuration'
    group 'os'
    param '1: command'
    param '2: params'
    example '$ os-conf check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-conf_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-conf_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-conf_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-conf_run "$2"
    else
        __os-conf_help
    fi
}

function __os-conf_help {
    echo -e "Usage: os-conf [COMMAND] [profile]\n"
    echo -e "Helper to os configuration installation.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os configuration"
    echo "   uninstall Uninstall installed os configuration"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-conf_install {
    # add user if not exists
    local random_text
    random_text=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo)
    if [[ $(grep -c "${DURE_USERID}\:x:" < "/etc/passwd") -lt 1 && -n ${DURE_USERID} ]]; then
        log_debug "Trying to do os-conf, adduser ${DURE_USERID}."
        adduser --gecos "" --disabled-password "${DURE_USERID}"
        chpasswd <<<"${DURE_USERID}:${random_text}"
        mkdir -p "/home/${DURE_USERID}/.ssh/"
        echo -e "${DURE_SSHPUBKEY}" > "/home/${DURE_USERID}/.ssh/authorized_keys"
        echo -e "${DURE_USERID} ALL=(ALL:ALL) PASSWD: ALL, !/usr/bin/passwd" >> /etc/sudoers
        echo -e "${DURE_USERID} ALL=(ALL:ALL) NOPASSWD: /usr/bin/passwd" >> /etc/sudoers
        echo "Defaults timestamp_timeout=60" | sudo tee /etc/sudoers.d/timeout
        visudo -cf /etc/sudoers.d/timeout
    fi

    # timezon fix
    log_debug "Trying to do os-conf, fix timezone to ${OS_TIMEZONE}."
    rm -rf /etc/localtime
    ln -s "/usr/share/zoneinfo/${OS_TIMEZONE}" "/etc/localtime"

    # swap enable
    # * dure_deploy_path should have more space than swap size
    if [[ -n ${DURE_SWAPSIZE} && $(awk '{ print $3 }' < "/proc/swaps"|grep -v Size) -lt 1000000 ]]; then
        if [[ ! -f ${DURE_DEPLOY_PATH}/swapfile ]]; then # https://askubuntu.com/a/1162472
            log_debug "Trying to do os-conf, set swap size to ${DURE_SWAPSIZE}."
            truncate -s "${DURE_SWAPSIZE}" "${DURE_DEPLOY_PATH}/swapfile"
            # fallocate -x -l "${DURE_SWAPSIZE}" "${DURE_DEPLOY_PATH}/swapfile" 1>/dev/null 2>&1
            dd if=/dev/zero "of=${DURE_DEPLOY_PATH}/swapfile" bs=1M count=4096 status=progress
            chown root:root "${DURE_DEPLOY_PATH}/swapfile"
            chmod 0600 "${DURE_DEPLOY_PATH}/swapfile"
            mkswap "${DURE_DEPLOY_PATH}/swapfile"
        fi
        swapoff -a
        swapon "${DURE_DEPLOY_PATH}/swapfile"
        swapon -s
    fi
}

function __os-conf_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall os-conf."
    # remove swapfile
    swapoff -a
    rm -rf "${DURE_DEPLOY_PATH}/swapfile"

    # remove sudoers username lines
    sed -i "s|^${DURE_USERID}.*||g" /etc/sudoers
    sudo rm -f /etc/sudoers.d/timeout
}

function __os-conf_disable { # UPDATE_FIRMWARE=0
    # remove swapfile
    swapoff -a
    return 0
}

function __os-conf_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting os-conf Check"

    # check global variable
    [[ -z ${RUN_OS_CONF} ]] && \
        log_info "RUN_OS_CONF variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_CONF} != 1 ]] && \
        log_info "RUN_OS_CONF is not enabled." && __os-conf_disable && [[ $running_status -lt 20 ]] && running_status=20
    [[ -z ${OS_TIMEZONE} ]] && \
        log_info "OS_TIMEZONE variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    # [[ ${#DURE_SWAPSIZE[@]} -lt 1 ]] && \
    #     log_info "DURE_SWAPSIZE variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    # [[ ${#DURE_USERID[@]} -lt 1 ]] && \
    #     log_info "DURE_USERID variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    # [[ ${#DURE_SSHPUBKEY[@]} -lt 1 ]] && \
    #     log_info "DURE_SSHPUBKEY variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    
    # check user installed
    [[ $(grep -c "${DURE_USERID}\:x:" < "/etc/passwd") -lt 1 ]] && \
        log_info "User ${DURE_USERID} does not exist." && [[ $running_status -lt 5 ]] && running_status=5
    # check timezone installed
    [[ $(ls -l /etc/localtime) != *"${OS_TIMEZONE}"* ]] && \
        log_info "Timezone ${OS_TIMEZONE} not set correctly." && [[ $running_status -lt 5 ]] && running_status=5
    # check if swapfile exists
    # [[ ! -f "${DURE_DEPLOY_PATH}/swapfile" ]] && \
    #     log_info "Swapfile does not exist at ${DURE_DEPLOY_PATH}/swapfile." && [[ $running_status -lt 5 ]] && running_status=5
    # check if swap is enabled
    #[[ ! -f "/proc/swaps" ]] && \
    #    log_info "Swap is not enabled." && [[ $running_status -lt 5 ]] && running_status=5
    # check if swapfile is loaded
    # [[ $(cat /proc/swaps|awk '{ print $1 }'|grep -c "${DURE_DEPLOY_PATH}/swapfile") -lt 1 ]] && \
    #     log_info "Swapfile is not loaded." && [[ $running_status -lt 10 ]] && running_status=10
    # check if swap size is enough
    [[ $(free|grep Swap|awk '{print $2}') -lt 900000 ]] && \
         log_info "Mounted swap size is less than 1GB." && [[ $running_status -lt 5 ]] && running_status=5
    # swap is loaded
    #[[ $(free|grep Swap|awk '{print $2}') != '0' ]] && \
    #    log_info "INFO: swap is enabled." && \
    #    running_status=0

    return 0
}

function __os-conf_run {
    return 0
}

complete -F __os-conf_run os-conf