## \brief sshd install configurations.
## \desc This tool helps install, configure, and manage SSH daemon (sshd)
## for secure remote access and administration. It provides automated installation,
## configuration management, and SSH service control capabilities. The tool manages
## SSH security settings, authentication methods, access controls, and service hardening
## for secure remote system administration.

## \example Install and configure SSH daemon:
## \example-code bash
##   net-sshd install
##   net-sshd configgen
##   net-sshd configapply
## \example-description
## In this example, we install SSH daemon, generate secure configurations,
## and apply them to enable secure remote access.

## \example Start SSH service and verify status:
## \example-code bash
##   net-sshd run
##   net-sshd check
## \example-description
## In this example, we start the SSH daemon and verify
## that the service is running and accessible.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'sshd install configurations.'

function net-sshd {
    about 'sshd install configurations'
    group 'postnet'
    runtype 'systemd'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ net-sshd subcommand'
    local PKGNAME="sshd"
    local DMNNAME="net-sshd"
    BASH_IT_LOG_PREFIX="net-sshd: "
    SSHD_PORTS="${SSHD_PORTS:-"LO:22"}"
    if [[ -z ${JB_VARS} ]]; then
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
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-sshd_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-sshd_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-sshd_download "$2"
    else
        __net-sshd_help
    fi
}

## \usage net-sshd [COMMAND]
## \usage net-sshd install|uninstall|configgen|configapply
## \usage net-sshd check|run|download
function __net-sshd_help {
    echo -e "Usage: net-sshd [COMMAND]\n"
    echo -e "Helper to sshd install configurations.\n"
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

function __net-sshd_install {
    log_debug "Installing ${DMNNAME}..."
    export DEBIAN_FRONTEND=noninteractive
    mkdir -p /run/sshd
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
        [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
        apt install -qy openssh-server || log_error "${DMNNAME} online install failed."
    else
        local filepat="./pkgs/openssh-server*.deb"
        local pkglist="./pkgs/openssh-server.pkgs"
        [[ $(find ${filepat}|wc -l) -lt 1 ]] && log_error "${DMNNAME} pkg file not found."
        pkgslist_down=()
        while read -r pkg; do
            [[ $pkg ]] && pkgslist_down+=("./pkgs/${pkg}*.deb")
        done < ${pkglist}
        # shellcheck disable=SC2068
        apt install -qy ${pkgslist_down[@]} || log_error "${DMNNAME} offline install failed."
        
    fi
    if ! __net-sshd_configgen; then # if gen config is different do apply
        __net-sshd_configapply
        rm -rf /tmp/${PKGNAME}
    fi
}

function __net-sshd_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/ssh 1>/dev/null 2>&1
    cp -rf /etc/ssh/* /tmp/sshd/
    cp -rf ./configs/${PKGNAME}/* /tmp/${PKGNAME}/

    local ssh_config="# JB_SSHD_CONFIG" infip
    cp ./configs/ssh/sshd_config /tmp/sshd/sshd_config
    if [[ $(grep -c "JB_SSHD_CONFIG" < "/tmp/sshd/sshd_config") -lt 1 ]]; then
        [[ ${SSHD_PORT} -gt 0 ]] && ssh_config="${ssh_config}\nPort ${SSHD_PORT} # JB_SSHD_PORT" && sed -i "s|Port=.*||g" /tmp/sshd/sshd_config
        if [[ ${#SSHD_INFS[@]} -gt 0 ]]; then
            IFS=$',' read -d "" -ra ssh_infs <<< "${SSHD_INFS}" # split
            for((j=0;j<${#ssh_infs[@]};j++)){
                __bp_trim_whitespace tinf "${ssh_infs[j]}"
                infip=$(_get_ip_of_infmark "${tinf}")
                [[ -z ${tip} ]] && log_error "Interface ${tinf} is not valid. Please set correct interface name in config." && continue
                echo "Setting ListenAddress for ${tinf}"
                ssh_config="${ssh_config}\nListenAddress ${infip} # JB_SSHD_INFS" && sed -i "s|ListenAddress=.*||g" /tmp/sshd/sshd_config
            }
        fi
        [[ ${DISABLE_IPV6} -gt 0 ]] && ssh_config="${ssh_config}\nAddressFamily inet # JB_DISABLE_IPV6" && sed -i "s|AddressFamily=.*||g" /tmp/sshd/sshd_config
        echo -e "\n\n${ssh_config}\n\n" >> /tmp/sshd/sshd_config
    fi
    
    # diff check
    diff -Naur /etc/ssh /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-sshd_configapply {
    [[ ! -f /tmp/${PKGNAME}.diff ]] && log_error "/tmp/${PKGNAME}.diff file doesnt exist. please run configgen."
    log_debug "Applying config ${DMNNAME}..."
    local dtnow=$(date +%Y%m%d_%H%M%S)
    [[ -d "/etc/ssh" ]] && cp -rf "/etc/ssh" "/etc/.ssh.${dtnow}"
    pushd /etc/ssh 1>/dev/null 2>&1
    patch -i /tmp/${PKGNAME}.diff
    popd 1>/dev/null 2>&1
    rm /tmp/${PKGNAME}.diff
    return 0
}

function __net-sshd_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_apt_pkgs openssh-server || log_error "${DMNNAME} download failed."
    return 0
}

function __net-sshd_uninstall { 
    log_debug "Uninstalling ${DMNNAME}..."
    systemctl stop ssh
    systemctl disable ssh
}

function __net-sshd_disable { 
    systemctl stop ssh
    systemctl disable ssh
    return 0
}

function __net-sshd_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check global variable
    [[ -z ${RUN_NET_SSHD} ]] && \
        log_error "RUN_NET_SSHD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_SSHD} != 1 ]] && \
        log_error "RUN_NET_SSHD is not enabled." && __net-sshd_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package dnsmasq
    [[ $(dpkg -l|awk '{print $2}'|grep -c "openssh-server") -lt 1 ]] && \
        log_info "openssh-server is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof sshd) -gt 0 ]] && \
        log_info "sshd is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-sshd_run {
    systemctl restart ssh
    pidof sshd && return 0 || return 1
}

complete -F _blank net-sshd