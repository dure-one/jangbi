# shellcheck shell=bash
cite about-plugin
about-plugin 'sshd install configurations.'

function net-sshd {
    about 'sshd install configurations'
    group 'postnet'
    deps  ''
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
    mkdir -p /run/sshd
    # config settings
    SSH_CONFIG="# DURE_SSHD_CONFIG"
    local infip

    cp ./configs/sshd_config /etc/ssh/sshd_config
    if [[ $(grep -c "DURE_SSHD_CONFIG" < "/etc/ssh/sshd_config") -lt 1 ]]; then
        [[ ${SSHD_PORT} -gt 0 ]] && SSH_CONFIG="${SSH_CONFIG}\nPort ${SSHD_PORT} # DURE_SSHD_PORT" && sed -i "s|Port=.*||g" /etc/ssh/sshd_config
        if [[ ${#SSHD_INFS[@]} -gt 0 ]]; then
            IFS=$'|' read -d "" -ra ssh_infs <<< "${SSHD_INFS}" # split
            for((j=0;j<${#ssh_infs[@]};j++)){
                __bp_trim_whitespace tinf "${ssh_infs[j]}"
                echo "Setting ListenAddress for ${tinf}"
                infip=$(ipcalc-ng "$(_get_rip "${tinf}")"|grep Address:|cut -f2)
                SSH_CONFIG="${SSH_CONFIG}\nListenAddress ${infip} # DURE_SSHD_INFS" && sed -i "s|ListenAddress=.*||g" /etc/ssh/sshd_config
            }
        fi
        [[ ${DISABLE_IPV6} -gt 0 ]] && SSH_CONFIG="${SSH_CONFIG}\nAddressFamily inet # DURE_DISABLE_IPV6" && sed -i "s|AddressFamily=.*||g" /etc/ssh/sshd_config
        echo -e "\n\n${SSH_CONFIG}\n\n" >> /etc/ssh/sshd_config
    fi
}

function __net-sshd_uninstall { # RUN_OS_FIRMWARE=0
    log_debug "Trying to uninstall net-sshd."
    systemctl stop ssh
    systemctl disable ssh
}

function __net-sshd_disable { # RUN_OS_FIRMWARE=0
    systemctl stop ssh
    systemctl disable ssh
    return 0
}

function __net-sshd_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-sshd Check"

    # check global variable
    [[ -z ${RUN_NET_SSHD} ]] && \
        log_info "RUN_NET_SSHD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_SSHD} != 1 ]] && \
        log_info "RUN_NET_SSHD is not enabled." && __net-sshd_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package dnsmasq
    [[ $(dpkg -l|awk '{print $2}'|grep -c "openssh-server") -lt 1 ]] && \
        log_info "openssh-server is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof sshd) -lt 1 ]] && \
        log_info "sshd is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-sshd_run {
    systemctl start ssh
    pidof sshd && return 0 || return 1
}

complete -F __net-sshd_run net-sshd