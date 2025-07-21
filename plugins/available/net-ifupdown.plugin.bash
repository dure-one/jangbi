## \brief miscellaneous tools and utilities.
## \desc This plugin provides a collection of miscellaneous utility functions
## for network diagnostics, file operations, and system information gathering.
## It includes tools for IP address detection, website availability checking,
## random file operations, and various system utilities for daily administration tasks.

## \example Check your public IP and network information:
## \example-code bash
##   myip
##   ips
## \example-description
## In this example, we check the public IP address as seen from the internet
## and list all local IP addresses on the system.

## \example Test website availability and pick random content:
## \example-code bash
##   down4me http://example.com
##   pickfrom /path/to/file.txt
## \example-description
## In this example, we check if a website is down and pick a random line
## from a specified file for various utility purposes.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'network configurations.'

function net-ifupdown {
    about 'network configurations'
    group 'net'
    runtype 'systemd'
    deps  'os-systemd'
    param '1: command'
    param '2: params'
    example '$ net-ifupdown subcommand'
    local PKGNAME="ifupdown"
    local DMNNAME="net-ifupdown"
    BASH_IT_LOG_PREFIX="net-ifupdown: "
    # IFUPDOWN_PORTS="${IFUPDOWN_PORTS:-""}"
    if _check_config_reload; then
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "help" ]]; then
        __net-ifupdown_help "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-ifupdown_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-ifupdown_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-ifupdown_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disable" ]]; then
        __net-ifupdown_disable "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-ifupdown_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-ifupdown_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-ifupdown_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-ifupdown_run "$2"
    else
        __net-ifupdown_help
    fi
}

## \usage net-ifupdown help|install|uninstall|download|disable|configgen|configapply|check|run
function __net-ifupdown_help {
    echo -e "Usage: net-ifupdown [COMMAND]\n"
    echo -e "Helper to network configurations.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install os ifupdown"
    echo "   uninstall   Uninstall installed ifupdown"
    echo "   download    Download pkg files to pkg dir"
    echo "   disable     Disable ifupdown service"
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   check       Check vars available"
    echo "   run         Run tasks"
}

function __net-ifupdown_install {
    log_debug "Installing ${DMNNAME}..."
    export DEBIAN_FRONTEND=noninteractive
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
        [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
        apt install -qy ifupdown iproute2 || log_error "${DMNNAME} online install failed."
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
    if ! __net-ifupdown_configgen; then # if gen config is different do apply
        __net-ifupdown_configapply
        rm -rf /tmp/${PKGNAME}
    fi
}

function __net-ifupdown_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/network 1>/dev/null 2>&1
    mkdir -p /tmp/ifupdown/if-post-down.d /tmp/ifupdown/if-pre-up.d /tmp/ifupdown/if-up.d /tmp/ifupdown/if-down.d
    __net-ifupdown_generate
    diff -Naur /etc/network /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    mkdir -p /etc/ifupdown/if-post-down.d /etc/ifupdown/if-pre-up.d /etc/ifupdown/if-up.d /etc/ifupdown/if-down.d
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-ifupdown_configapply {
    [[ ! -f /tmp/${PKGNAME}.diff ]] && log_error "/tmp/${PKGNAME}.diff file doesnt exist. please run configgen."
    log_debug "Applying config ${DMNNAME}..."
    local dtnow=$(date +%Y%m%d_%H%M%S)
    [[ -d "/etc/network" ]] && cp -rf "/etc/network" "/etc/.network.${dtnow}"
    pushd /etc/network 1>/dev/null 2>&1
    patch -i /tmp/${PKGNAME}.diff
    popd 1>/dev/null 2>&1
    rm /tmp/${PKGNAME}.diff
    return 0
}

function __net-ifupdown_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_apt_pkgs "ifupdown iproute2" || log_error "${DMNNAME} download failed."
    return 0
}

function __net-ifupdown_disable {
    log_debug "Disabling ${DMNNAME}..."
    systemctl stop networking
    systemctl disable networking
    return 0
}

function __net-ifupdown_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    systemctl stop networking
    systemctl disable networking
}

function __net-ifupdown_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check package file exists
    [[ $(find ./pkgs/${PKGNAME}*.pkgs|wc -l) -lt 1 ]] && \
        log_info "${PKGNAME} package file does not exist." && [[ $running_status -lt 15 ]] && running_status=15
    # RUN_OS_SYSTEMD 1 - full systemd, 0 - disable completely, 2 - only journald
    log_debug "check RUN_OS_SYSTEMD" 
    [[ -z ${RUN_OS_SYSTEMD} ]] && \
        log_error "RUN_OS_SYSTEMD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_SYSTEMD} == 1 ]] && \
        log_error "RUN_OS_SYSTEMD set to full systemd(RUN_OS_SYSTEMD=1)." && __net-ifupdown_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package ifupdown
    log_debug "check ifupdown is installed"
    [[ $(dpkg -l|awk '{print $2}'|grep -c "ifupdown") -lt 1 ]] && \
        log_info "ifupdown is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    log_debug "check networking is running"
    [[ $(systemctl status networking 2>/dev/null|grep -c "active") -gt 0 ]] && \
        log_info "networking(ifupdown) is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-ifupdown_run {
    # remove dhcp from interfaces not connected for preventing systemd networking from hanging
    # local infs=$(cat /proc/net/dev|awk '{ print $1 };'|grep :|grep -v lo:)
    # IFS=$'\n' read -rd '' -a dure_infs <<< "${infs//:}"
    # for((j=0;j<${#dure_infs[@]};j++)){
    #     operstate=$(cat /sys/class/net/${dure_infs[j]}/operstate)
    #     if [[ ${operstate} == *"up"* ]]; then
    #         sed -i "s|iface ${dure_infs[j]} inet manual.*|iface ${dure_infs[j]} inet dhcp|g" /etc/network/interfaces
    #     elif [[ ${operstate} == "down" ]]; then
    #         sed -i "s|iface ${dure_infs[j]} inet dhcp.*|iface ${dure_infs[j]} inet manual|g" /etc/network/interfaces
    #     fi
    # }
    systemctl restart networking
    systemctl status networking && return 0 || \
        log_error "ifupdown failed to run." && return 1
}

complete -F _blank net-ifupdown

function __net-ifupdown_generate {
    if [[ -n ${JB_IFUPDOWN} ]]; then # custom interfaces exists
        log_debug "Generating /tmp/${PKGNAME}/interfaces from JB_IFUPDOWN config."
        echo "${JB_IFUPDOWN}" > /tmp/${PKGNAME}/interfaces
        chmod 600 /tmp/${PKGNAME}/interfaces 1>/dev/null 2>&1
        return
    fi

    # custom interfaces not exists - generate from config
    log_debug "Generating /tmp/${PKGNAME}/interfaces from config."
    tee /tmp/${PKGNAME}/interfaces > /dev/null <<EOT
auto lo
iface lo inet loopback
EOT
    chmod 600 /tmp/${PKGNAME}/interfaces 1>/dev/null 2>&1

    local waninf=${JB_WANINF} laninf=${JB_LANINF} wlaninf=${JB_WLANINF}
    log_debug "waninf=${waninf} laninf=${laninf} wlaninf=${wlaninf}"

    # Auto-select interfaces if not defined
    if [[ -z ${waninf} && -z ${laninf} && -z ${wlaninf} ]]; then
        log_debug "Starting to select wan, lan, wlan interfaces..."
        local dure_infs=($(cat /proc/net/dev | awk '{ print $1 }' | grep : | grep -v lo: | sed 's/:$//'))
        
        for inf in "${dure_infs[@]}"; do
            [[ ! ${waninf} && ${inf:0:1} != 'w' && ${inf} != ${laninf} && ${inf} != ${wlaninf} ]] && waninf=${inf} && continue
            [[ ! ${laninf} && ${inf:0:1} != 'w' && ${inf} != ${waninf} && ${inf} != ${wlaninf} ]] && laninf=${inf} && continue
            [[ ! ${wlaninf} && ${inf:0:1} == 'w' && ${inf} != ${laninf} && ${inf} != ${waninf} ]] && wlaninf=${inf} && continue
        done

        log_debug "Writing selected interface WAN:${waninf} LAN:${laninf} WLAN:${wlaninf} to .config..."
        sed -i "s|JB_WANINF=.*|JB_WANINF=${waninf}|g" "${JB_DEPLOY_PATH}/.config"
        [[ -z ${JB_WAN} ]] && sed -i "s|JB_WAN=.*|JB_WAN=\"dhcp\"|g" "${JB_DEPLOY_PATH}/.config"
        sed -i "s|JB_LANINF=.*|JB_LANINF=${laninf}|g" "${JB_DEPLOY_PATH}/.config"
        [[ -z ${JB_LAN} ]] && sed -i "s|JB_LAN=.*|JB_LAN=\"192.168.1.1/24\"|g" "${JB_DEPLOY_PATH}/.config"
        sed -i "s|JB_WLANINF=.*|JB_WLANINF=${wlaninf}|g" "${JB_DEPLOY_PATH}/.config"
        [[ -z ${JB_WLAN} ]] && sed -i "s|JB_WLAN=.*|JB_WLAN=\"192.168.100.1/24\"|g" "${JB_DEPLOY_PATH}/.config"
        [[ -z ${JB_WLAN_SSID} ]] && sed -i "s|JB_WLAN_SSID=.*|JB_WLAN_SSID=\"durejangbi\"|g" "${JB_DEPLOY_PATH}/.config"
        [[ -z ${JB_WLAN_PASS} ]] && sed -i "s|JB_WLAN=.*|JB_WLAN=\"durejangbi\"|g" "${JB_DEPLOY_PATH}/.config"
    fi

    # Helper function to generate interface config
    _generate_interface_config() {
        local inf_name=$1 inf_var=$2 gw_var=$3 inf_type=${4:-"lan"}
        
        [[ -z ${!inf_var} || ${!inf_var,,} == "dhcp" ]] && {
            tee -a /tmp/${PKGNAME}/interfaces > /dev/null <<EOT
auto ${inf_name}
iface ${inf_name} inet dhcp
EOT
            return
        }

        local gateway_line=""
        if [[ -n ${!gw_var} ]]; then
            gateway_line="gateway ${!gw_var}"
        elif [[ ${inf_type} == "wan" ]]; then
            local gw=$(ipcalc-ng ${!inf_var} | grep HostMin: | cut -f2)
            gateway_line="gateway ${gw}"
        fi

        tee -a /tmp/${PKGNAME}/interfaces > /dev/null <<EOT
auto ${inf_name}
iface ${inf_name} inet static
address ${!inf_var}${gateway_line:+
$gateway_line}
EOT
    }

    # Get active interfaces
    local dure_infs=($(cat /proc/net/dev | awk '{ print $1 }' | grep : | grep -v lo: | sed 's/:$//'))
    
    for inf in "${dure_infs[@]}"; do
        local operstate=$(cat /sys/class/net/${inf}/operstate 2>/dev/null || echo "down")
        [[ ${operstate} == "down" ]] && continue

        case ${inf} in
            ${waninf})
                _generate_interface_config "${inf}" "JB_WAN" "JB_WANGW" "wan"
                ;;
            ${laninf})
                _generate_interface_config "${inf}" "JB_LAN" "JB_LANGW" "lan"
                ;;
            ${wlaninf})
                _generate_interface_config "${inf}" "JB_WLAN" "JB_WLANGW" "wlan"
                ;;
            ${JB_LAN0INF}|${JB_LAN1INF}|${JB_LAN2INF}|${JB_LAN3INF}|${JB_LAN4INF}|${JB_LAN5INF}|${JB_LAN6INF}|${JB_LAN7INF}|${JB_LAN8INF}|${JB_LAN9INF})
                # Find matching LAN interface
                for i in {0..9}; do
                    local lan_inf_var="JB_LAN${i}INF"
                    local lan_var="JB_LAN${i}"
                    [[ ${inf} == ${!lan_inf_var} ]] && {
                        _generate_interface_config "${inf}" "${lan_var}" "" "lan"
                        break
                    }
                done
                ;;
            *)
                # Default DHCP for unmatched interfaces
                tee -a /tmp/${PKGNAME}/interfaces > /dev/null <<EOT
auto ${inf}
iface ${inf} inet dhcp
EOT
                ;;
        esac
    done
}