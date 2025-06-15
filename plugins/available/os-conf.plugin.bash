# shellcheck shell=bash
cite about-plugin
about-plugin 'custom os configurations'
# C : TIMEZONE DURE_SWAPSIZE DURE_DEPLOY_PATH

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
    local random_text=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo)
    if [[ $(cat /etc/passwd|grep ${DURE_USERID}\:x:|wc -l) -lt 1 && ! -z ${DURE_USERID} ]]; then
        log_debug "Trying to do os-conf, adduser ${DURE_USERID}."
        adduser --gecos "" --disabled-password ${DURE_USERID}
        chpasswd <<<"${DURE_USERID}:${random_text}"
        mkdir -p /home/${DURE_USERID}/.ssh/
        echo -e "${DURE_SSHPUBKEY}" > /home/${DURE_USERID}/.ssh/authorized_keys
        echo -e "${DURE_USERID} ALL=(ALL:ALL) PASSWD: ALL, !/usr/bin/passwd" >> /etc/sudoers
        echo -e "${DURE_USERID} ALL=(ALL:ALL) NOPASSWD: /usr/bin/passwd" >> /etc/sudoers
        echo "Defaults timestamp_timeout=60" | sudo tee /etc/sudoers.d/timeout
        visudo -cf /etc/sudoers.d/timeout
    fi

    # timezon fix
    log_debug "Trying to do os-conf, fix timezone to ${TIMEZONE}."
    rm -rf /etc/localtime
    ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

    # swap enable
    # * dure_deploy_path should have more space than swap size
    if [[ ! -z ${DURE_SWAPSIZE} && $(cat /proc/swaps|awk '{ print $3 }'|grep -v Size) -lt 1000000 ]]; then
        if [[ ! -f ${DURE_DEPLOY_PATH}/swapfile ]]; then # https://askubuntu.com/a/1162472
            log_debug "Trying to do os-conf, set swap size to ${DURE_SWAPSIZE}."
            truncate -s ${DURE_SWAPSIZE} ${DURE_DEPLOY_PATH}/swapfile
            fallocate -x -l ${DURE_SWAPSIZE} ${DURE_DEPLOY_PATH}/swapfile 2>&1 1>/dev/null
            dd if=/dev/zero of=${DURE_DEPLOY_PATH}/swapfile bs=1G seek=12 count=0
            chown root:root ${DURE_DEPLOY_PATH}/swapfile
            chmod 0600 ${DURE_DEPLOY_PATH}/swapfile
            mkswap ${DURE_DEPLOY_PATH}/swapfile
        fi
        swapoff -a
        swapon ${DURE_DEPLOY_PATH}/swapfile
        swapon -s
    fi
}

function __os-conf_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall os-conf."
    # remove swapfile
    swapoff -a
    rm -rf ${DURE_DEPLOY_PATH}/swapfile

    # remove sudoers username lines
    sed -i "s|^${DURE_USERID}.*||g" /etc/sudoers
    sudo rm -f /etc/sudoers.d/timeout
}

function __os-conf_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=5
    log_debug "Starting os-conf Check"

    [[ ${#DURE_SWAPSIZE[@]} -lt 1 ]] && \
        log_info "DURE_SWAPSIZE variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${#DURE_USERID[@]} -lt 1 ]] && \
        log_info "DURE_USERID variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${#DURE_SSHPUBKEY[@]} -lt 1 ]] && \
        log_info "DURE_SSHPUBKEY variable is not set." && [[ $running_status -lt 10 ]] && running_status=10

    # swap is loaded # swap file is existed
    [[ $(free|grep Swap|awk '{print $2}') != '0' ]] && \
        log_info "INFO: swap is enabled." && \
        running_status=0

    return 0
}

function __os-conf_run {
    # systemctl restart systemd-modules-load.service
    return 0
}

complete -F __os-conf_run os-conf