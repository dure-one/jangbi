# shellcheck shell=bash
cite about-plugin
about-plugin 'setup systemd.'
# VARS REMOVE_RAREPKGS

function os-systemd {
    about 'helper function for local os repository'
    group 'os'
    param '1: command'
    param '2: params'
    example '$ os-systemd check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
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

function __os-systemd_install {
    case "${DISABLE_SYSTEMD}" in
        0)
            __os-systemd_full_systemd
        ;;
        1)
            __os-systemd_disable_completely
        ;;
        2)
            __os-systemd_only_journald
        ;;
    esac
}

function __os-systemd_disable_completely {
    log_debug "Starting os-systemd disable completely(DISABLE_SYSTEMD=${DISABLE_SYSTEMD})"
    if [[ ${REMOVE_RAREPKGS} -gt 0 ]]; then
        apt purge -yq alsa-utils figlet toilet toilet-fonts v4l-utils v4l2loopback-dkms v4l2loopback-utils
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
    apt install -yq ./pkgs/ifupdown*.deb isc-dhcp-client
    systemctl enable networking.service
}

function __os-systemd_only_journald {
    log_debug "Starting os-systemd only journald(DISABLE_SYSTEMD=${DISABLE_SYSTEMD})"
    if [[ ${REMOVE_RAREPKGS} -gt 0 ]]; then
        apt purge -yq alsa-utils figlet toilet toilet-fonts v4l-utils v4l2loopback-dkms v4l2loopback-utils
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
    apt install -yq ./pkgs/ifupdown*.deb isc-dhcp-client
    systemctl enable networking.service
}

function __os-systemd_full_systemd {
    log_debug "Starting os-systemd full systemd(DISABLE_SYSTEMD=${DISABLE_SYSTEMD})"
    if [[ ${REMOVE_RAREPKGS} -gt 0 ]]; then
        apt purge -yq figlet toilet toilet-fonts v4l-utils v4l2loopback-dkms v4l2loopback-utils
        apt purge -yq ntpsec wpasupplicant xsane cups avahi-daemon avahi-autoipd
    fi
}

function __os-systemd_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Starting os-systemd Uninstall"
    # recover system
    systemctl disable networking.service
    systemctl enable \
        systemd-journald systemd-journald-dev-log.socket systemd-journald-audit.socket systemd-journald.socket systemd-journal-flush.service \
        systemd-logind.service \
        systemd-networkd systemd-networkd.socket
    systemctl start \
        systemd-journald systemd-journald-dev-log.socket systemd-journald-audit.socket systemd-journald.socket systemd-journal-flush.service \
        systemd-logind.service \
        systemd-networkd systemd-networkd.socket
    systemctl unmask systemd-networkd systemd-networkd-wait-online.service systemd-journald systemd-logind.service wpa_supplicant.service
    systemctl unmask systemd-journald systemd-journald-dev-log.socket systemd-journald-audit.socket systemd-journald.socket
    apt remove -yq ifupdown isc-dhcp-client
    apt install -yq systemd-timesyncd systemd-resolved rsyslog
}

function __os-systemd_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=5
    log_debug "Starting os-systemd Check"
    [[ ${#UPDATE_FIRMWARE[@]} -lt 1 ]] && \
        log_info "UPDATE_FIRMWARE variable is not set." && [[ $running_status -lt 10 ]] && running_status=10

    # check disable systemd installed
    [[ $(dpkg -l|grep systemd-networkd|wc -l) -lt 1 ]] && \
        log_info "systemd-networkd is not exists." && \
        [[ $(dpkg -l|grep systemd-resolved|wc -l) -lt 1 ]] && \
        log_info "systemd-resolved is not exists." && [[ $running_status -lt 0 ]] && running_status=0

    # # check rare packages
    # if [[ ${REMOVE_RAREPKGS} -gt 0 ]]; then
    #     [[ $(dpkg -l|grep modemmanager|wc -l) -gt 0 ]] \
    #         && echo "INFO: rare packages not remoted" && return_code=0
    # fi

    # show masked services
    log_info $(systemctl list-unit-files --state=masked)

    return 0
}

function __os-systemd_run {

    return 0
}

complete -F __os-systemd_run os-systemd