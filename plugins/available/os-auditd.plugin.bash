## \brief auditd install configurations.
## \desc This tool helps install, configure, and manage auditd (Linux Audit Daemon)
## for system security monitoring and compliance. It provides automated installation,
## configuration management, and audit log monitoring capabilities. Auditd tracks
## system calls, file access, user activities, and security events for forensics and compliance.

## \example Install and configure auditd:
## \example-code bash
##   os-auditd install
##   os-auditd configgen
##   os-auditd configapply
## \example-description
## In this example, we install auditd, generate security audit configurations,
## and apply them to enable comprehensive system monitoring.

## \example Start auditing and check status:
## \example-code bash
##   os-auditd run
##   os-auditd check
## \example-description
## In this example, we start the audit daemon to begin security monitoring
## and verify that the auditing service is functioning properly.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'auditd install configurations.'

function os-auditd {
    about 'auditd install configurations'
    group 'prenet'
    runtype 'systemd'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-auditd subcommand'
    local PKGNAME="auditd"
    local DMNNAME="os-auditd"
    BASH_IT_LOG_PREFIX="os-auditd: "
    # AUIDITD_PORTS="${AUIDITD_PORTS:-""}"
    if [[ -z ${JB_VARS} ]]; then
        _load_config || exit 1
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-auditd_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-auditd_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-auditd_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-auditd_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __os-auditd_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __os-auditd_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __os-auditd_download "$2"
    else
        __os-auditd_help
    fi
}

## \usage net-auditd install|uninstall|configgen|configapply|check|run|download
function __os-auditd_help {
    echo -e "Usage: os-auditd [COMMAND]\n"
    echo -e "Helper to auditd install configurations.\n"
    echo -e "Commands:\n"
    echo "   help         Show this help message"
    echo "   install      Install os auditd"
    echo "   uninstall    Uninstall installed auditd"
    echo "   configgen    Configs Generator"
    echo "   configapply  Apply Configs"
    echo "   download     Download pkg files to pkg dir"
    echo "   check        Check vars available"
    echo "   run          Run tasks"
}

function __os-auditd_install {
    log_debug "Installing ${DMNNAME}..."
    export DEBIAN_FRONTEND=noninteractive
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
        [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
        apt install -qy auditd
    else
        local filepat="./pkgs/auditd*.deb"
        local pkglist="./pkgs/auditd.pkgs"
        [[ $(find ${filepat}|wc -l) -lt 1 ]] && apt update -qy && __os-auditd_download
        pkgslist_down=()
        while read -r pkg; do
            [[ $pkg ]] && pkgslist_down+=("./pkgs/${pkg}*.deb")
        done < ${pkglist}
        # shellcheck disable=SC2068
        apt install -qy ${pkgslist_down[@]} || log_error "${DMNNAME} offline install failed."
    fi

    if ! __os-auditd_configgen; then # if gen config is different do apply
        __os-auditd_configapply
        rm -rf /tmp/${PKGNAME}
    fi
    mkdir -p /var/log/audit
}

function __os-auditd_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    __os-auditd_generate_config
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __os-auditd_generate_config {
    mkdir -p /tmp/auditd
    cp -rf ./configs/auditd/audit.rules  /tmp/auditd/audit.rules
    # auditctl -R /tmp/auditd/audit.rules
    # add rules by force
    local string_with_newlines=$(cat /tmp/auditd/audit.rules|grep -v "#"|grep -v -e '^[[:space:]]*$')
    while IFS= read -r line; do
        echo "auditctl ${line}"|sh -i &>/dev/null
    done <<< "$string_with_newlines"
    # check unserted lines
    echo "# generated on $(date +%s)" > /tmp/auditd/audit.rules.rejected
    while IFS= read -r line; do
        found=$(auditctl -l|grep "\\$line"|wc -l)
        [[ ${found} == 0 ]] && echo "${line}" >> /tmp/auditd/audit.rules.rejected
    done <<< "$string_with_newlines"
    # backup accepted lines
    echo "# generated on $(date +%s)" > /tmp/auditd/audit.rules
    auditctl -l >> /tmp/auditd/audit.rules
    return 0
}

function __os-auditd_configapply {
    [[ ! -f /tmp/${PKGNAME}.diff ]] && log_error "/tmp/${PKGNAME}.diff file doesnt exist. please run configgen."
    log_debug "Applying config ${DMNNAME}..."
    local dtnow=$(date +%Y%m%d_%H%M%S)
    [[ -d "/etc/${PKGNAME}" ]] && cp -rf "/etc/${PKGNAME}" "/etc/.${PKGNAME}.${dtnow}"
    pushd /etc/${PKGNAME} 1>/dev/null 2>&1
    patch -i /tmp/${PKGNAME}.diff
    popd 1>/dev/null 2>&1
    rm /tmp/${PKGNAME}.diff
    return 0
}

function __os-auditd_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_apt_pkgs aide || log_error "${DMNNAME} download failed."
    return 0
}

function __os-auditd_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    systemctl stop auditd
    systemctl disable auditd
}

function __os-auditd_disable {
    log_debug "Disabling ${DMNNAME}..."
    systemctl stop auditd
    systemctl disable auditd
    return 0
}

function __os-auditd_check {  # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check global variable
    [[ -z ${RUN_OS_AUDITD} ]] && \
        log_error "RUN_OS_AUDITD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_AUDITD} != 1 ]] && \
        log_error "RUN_OS_AUDITD is not enabled." && __os-auditd_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package dnsmasq
    [[ $(dpkg -l|awk '{print $2}'|grep -c "auditd") -lt 1 ]] && \
        log_info "auditd is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof auditd) -gt 0 ]] && \
        log_info "auditd is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __os-auditd_run {
    log_debug "Running ${DMNNAME}..."
    systemctl restart auditd
    systemctl status auditd && return 0 || \
        log_error "auditd failed to run." && return 1
    return 0
}

complete -F _blank os-auditd