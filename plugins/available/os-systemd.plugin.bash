# shellcheck shell=bash
cite about-plugin
about-plugin 'setup systemd.'
# VARS SYSTEMD_REMOVERAREPKGS

function os-systemd {
    about 'helper function for local os repository'
    group 'prenet'
    runtype 'none'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-systemd subcommand'
    local PKGNAME="systemd"
    local DMNNAME="os-systemd"
    BASH_IT_LOG_PREFIX="os-systemd: "
    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-systemd_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-systemd_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-systemd_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-systemd_run "$2"
    else
        __os-systemd_help
    fi
}

function __os-systemd_help {
    echo -e "Usage: os-systemd [COMMAND] [profile]\n"
    echo -e "Helper to local packgage repository.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install remove systemd pkgs"
    echo "   uninstall Uninstall remove systemd pkgs"
    echo "   check     Check installable"
    echo "   run       Run tasks"
}

function __os-systemd_install { # 0 - disable completely, 1 - full systemd, 2 - only journald
    case "${RUN_OS_SYSTEMD}" in
        1)
            __os-systemd_full_systemd
        ;;
        0)
            __os-systemd_disable_completely
        ;;
        2)
            __os-systemd_only_journald
        ;;
    esac

    log_debug "Reduce network timeout 5Min to 15Sec"
    mkdir -p /etc/systemd/system/networking.service.d/
    echo "[Service]" > /etc/systemd/system/networking.service.d/override.conf
    echo "TimeoutStartSec=15" >> /etc/systemd/system/networking.service.d/override.conf
    systemctl daemon-reload
}

function __os-systemd_disable_completely { # 0 - disable completely(ifupdown), 1 - full systemd(netplan), 2 - only journald(ifupdown)
    log_debug "Starting os-systemd disable completely(RUN_OS_SYSTEMD=${RUN_OS_SYSTEMD})"
    if [[ ${SYSTEMD_REMOVERAREPKGS} -gt 0 ]]; then
        apt purge -yq alsa-utils v4l-utils v4l2loopback-dkms v4l2loopback-utils
        apt purge -yq modemmanager network-manager ntpsec polkitd wpasupplicant xsane cups avahi-daemon avahi-autoipd
    fi
    # disable systemd services
    apt purge -yq systemd-timesyncd systemd-resolved rsyslog
    systemctl stop \
        systemd-journald systemd-journald-dev-log.socket systemd-journald-audit.socket systemd-journald.socket systemd-journal-flush.service \
        systemd-logind.service \
        systemd-networkd systemd-networkd.socket
    systemctl disable \
        systemd-journald systemd-journald-dev-log.socket systemd-journald-audit.socket systemd-journald.socket systemd-journal-flush.service \
        systemd-logind.service \
        systemd-networkd systemd-networkd.socket
    systemctl mask systemd-networkd systemd-networkd-wait-online.service systemd-journald systemd-logind.service wpa_supplicant.service
    systemctl mask systemd-journald systemd-journald-dev-log.socket systemd-journald-audit.socket systemd-journald.socket

    export DEBIAN_FRONTEND=noninteractive
    [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
    [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
    apt install -qy isc-dhcp-client ifupdown iproute2

    systemctl enable networking.service
}

function __os-systemd_only_journald { # 0 - disable completely, 1 - full systemd, 2 - only journald
    log_debug "Starting os-systemd only journald(RUN_OS_SYSTEMD=${RUN_OS_SYSTEMD})"
    if [[ ${SYSTEMD_REMOVERAREPKGS} -gt 0 ]]; then
        apt purge -yq alsa-utilsv v4l-utils v4l2loopback-dkms v4l2loopback-utils
        apt purge -yq modemmanager network-manager ntpsec polkitd wpasupplicant xsane cups avahi-daemon avahi-autoipd
    fi
    # disable systemd services
    apt purge -yq systemd-timesyncd systemd-resolved
    systemctl stop \
        systemd-logind.service \
        systemd-networkd systemd-networkd.socket
    systemctl disable \
        systemd-logind.service \
        systemd-networkd systemd-networkd.socket
    systemctl mask systemd-networkd systemd-networkd-wait-online.service systemd-journald systemd-logind.service wpa_supplicant.service
    systemctl mask systemd-journald systemd-journald-dev-log.socket systemd-journald-audit.socket systemd-journald.socket
    
    export DEBIAN_FRONTEND=noninteractive
    [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
    [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
    apt install -qy isc-dhcp-client ifupdown iproute2
    systemctl enable networking.service
}

function __os-systemd_full_systemd { # 0 - disable completely, 1 - full systemd, 2 - only journald
    log_debug "Starting os-systemd full systemd(RUN_OS_SYSTEMD=${RUN_OS_SYSTEMD})"
    if [[ ${SYSTEMD_REMOVERAREPKGS} -gt 0 ]]; then
        apt purge -yq v4l-utils v4l2loopback-dkms v4l2loopback-utils
        apt purge -yq ntpsec wpasupplicant xsane cups avahi-daemon avahi-autoipd
    fi
    __os-systemd_uninstall
}

function __os-systemd_uninstall { 
    log_debug "Starting os-systemd Uninstall"
    # recover system
    systemctl disable networking.service
    systemctl enable \
        systemd-journald systemd-journald-dev-log.socket systemd-journald-audit.socket systemd-journald.socket systemd-journal-flush.service \
        systemd-logind.service \
        systemd-networkd systemd-networkd.socket
    systemctl restart \
        systemd-journald systemd-journald-dev-log.socket systemd-journald-audit.socket systemd-journald.socket systemd-journal-flush.service \
        systemd-logind.service \
        systemd-networkd systemd-networkd.socket
    systemctl unmask systemd-networkd systemd-networkd-wait-online.service systemd-journald systemd-logind.service wpa_supplicant.service
    systemctl unmask systemd-journald systemd-journald-dev-log.socket systemd-journald-audit.socket systemd-journald.socket
    
    apt remove -yq isc-dhcp-client ifupdown
    export DEBIAN_FRONTEND=noninteractive
    [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
    [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
    apt install -qy systemd-timesyncd systemd-resolved rsyslog netplan.io iproute2
}

function __os-systemd_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check package file exists
    
    # check global variable
    [[ -z ${RUN_OS_SYSTEMD} ]] && \
        log_error "RUN_OS_SYSTEMD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    
    # check disabled systemd components installed
    # 0 - disable completely, 1 - full systemd, 2 - only journald
    case "${RUN_OS_SYSTEMD}" in
        1)
            # 1 - full systemd
            [[ $(dpkg -l|awk '{print $2}'|grep -c "systemd-networkd") -lt 1 ]] && \
                log_info "systemd-networkd is not installed." && [[ $running_status -lt 5 ]] && running_status=5
            [[ $(dpkg -l|awk '{print $2}'|grep -c "systemd-journald") -lt 1 ]] && \
                log_info "systemd-journald is not installed." && [[ $running_status -lt 5 ]] && running_status=5
            
            # check if disable completely. if systemd-journald is not running, force run install
            [[ $(systemctl status systemd-journald 2>/dev/null|awk '{ print $2 }'|grep -c inactive) -gt 0 ]] && \
                log_info "systemd-journald is not running." && running_status=5
            ;; 
        2)
            # 2 - only journald
            [[ $(dpkg -l|awk '{print $2}'|grep -c "isc-dhcp-client") -lt 1 ]] && \
                log_info "isc-dhcp-client is not installed." && [[ $running_status -lt 5 ]] && running_status=5
            [[ $(dpkg -l|awk '{print $2}'|grep -c "systemd-journald") -lt 1 ]] && \
                log_info "systemd-journald is not installed." && [[ $running_status -lt 5 ]] && running_status=5
            
            # check if not full systemd. if systemd-networkd is running, force run install
            [[ $(systemctl status systemd-networkd 2>/dev/null|awk '{ print $2 }'|grep -c inactive) -lt 1 ]] && \
                log_info "systemd-networkd is running." && running_status=5
            
            # check if disable completely. if systemd-journald is not running, force run install
            [[ $(systemctl status systemd-journald 2>/dev/null|awk '{ print $2 }'|grep -c inactive) -gt 0 ]] && \
                log_info "systemd-journald is not running." && running_status=5
            ;;
        0)
            # 0 - disable completely
            [[ $(dpkg -l|awk '{print $2}'|grep -c "isc-dhcp-client") -lt 1 ]] && \
                log_info "isc-dhcp-client is not installed." && [[ $running_status -lt 5 ]] && running_status=5
            
            # check if not full systemd. if systemd-networkd is running, force run install
            [[ $(systemctl status systemd-networkd 2>/dev/null|awk '{ print $2 }'|grep -c inactive) -lt 1 ]] && \
                log_info "systemd-networkd is running." && running_status=5

            # check if not only journald. if systemd-networkd is running, force run install
            [[ $(systemctl status systemd-journald 2>/dev/null|awk '{ print $2 }'|grep -c inactive) -lt 1 ]] && \
                log_info "systemd-journald is running." && running_status=5
            ;;
    esac

    return 0
}

function __os-systemd_run {
    systemctl restart systemd-udevd
    systemctl status systemd-udevd && return 0 || return 1
}

complete -F _blank os-systemd