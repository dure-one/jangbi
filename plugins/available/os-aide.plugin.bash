# shellcheck shell=bash
cite about-plugin
about-plugin 'aide install configurations.'

function os-aide {
    about 'aide install configurations'
    group 'prenet'
    runtype 'none' # systemd, minmon, none
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-aide subcommand'
    local PKGNAME="aide"
    local DMNNAME="net-aide"

    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-aide_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-aide_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-aide_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "checkpoint" ]]; then
        __os-aide_checkpoint "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-aide_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-aide_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-aide_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-aide_download "$2"
    else
        __os-aide_help
    fi
}

function __os-aide_help {
    echo -e "Usage: os-aide [COMMAND] [profile]\n"
    echo -e "Helper to aide install configurations.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install os aide"
    echo "   uninstall   Uninstall installed aide"
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   download    Download pkg files to pkg dir"
    echo "   checkpoint  Make new checkpoint"
    echo "   check       Check vars available"
    echo "   run         Run tasks"
}

function __os-aide_install {
    log_debug "Installing ${DMNNAME}..."
    export DEBIAN_FRONTEND=noninteractive
    mkdir -p /etc/aide /var/lib/aide /var/log/aide
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
        [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
        apt install -qy aide
    else
        local filepat="./pkgs/aide*.deb"
        local pkglist="./pkgs/aide.pkgs"
        [[ ! -f ${filepat} ]] && apt update -qy && __net-aide_download
        pkgslist_down=()
        while read -r pkg; do
            [[ $pkg ]] && pkgslist_down+=("./pkgs/${pkg}*.deb")
        done < ${pkglist}
        apt install -qy $(<${pkgslist_down[@]})
    fi

    if ! __net-aide_configgen; then # if gen config is different do apply
        __net-aide_configapply
        rm -rf /tmp/${PKGNAME}
    fi

    aide --init --config=/etc/aide/aide.minimal.conf 2>/dev/null && \
        cp /var/lib/aide/aide.minimal.db.new.gz /var/lib/aide/aide.minimal.db.gz
}

function __net-aide_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 2>&1 1>/dev/null
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 2>&1 1>/dev/null
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-aide_configapply {
    [[ ! -f /tmp/${PKGNAME}.diff ]] && log_error "/tmp/${PKGNAME}.diff file doesnt exist. please run configgen."
    log_debug "Applying config ${DMNNAME}..."
    local dtnow=$(date +%Y%m%d_%H%M%S)
    [[ -d "/etc/${PKGNAME}" ]] && cp -rf "/etc/${PKGNAME}" "/etc/.${PKGNAME}.${dtnow}"
    pushd /etc/${PKGNAME} 2>&1 1>/dev/null
    patch -i /tmp/${PKGNAME}.diff
    popd 2>&1 1>/dev/null
    rm /tmp/${PKGNAME}.diff
    return 0
}

function __net-aide_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_apt_pkgs aide
    return 0
}

function __os-aide_uninstall { 
    log_debug "Uninstalling ${DMNNAME}..."
    apt purge -yq aide
}

function __os-aide_checkpoint {
    log_debug "Make new checkpoint for os-aide."
    local dtnow=$(date +%Y%m%d_%H%M%S)
    mkdir -p /tmp/aidecp
    if ! aide --check --config=/etc/aide/aide.minimal.conf 2>&1 1>/tmp/aidecp/aide_${dtnow}.log; then
        mkdir -p /var/log/aide/checkpoints
        mv /tmp/aidecp/aide_${dtnow}.log /var/log/aide/checkpoints
        cp /var/lib/aide/aide.minimal.db.new.gz /var/lib/aide/aide.minimal.db.gz
    fi
}

function __os-aide_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting os-aide Check"

    # check global variable
    [[ -z ${RUN_OS_AIDE} ]] && \
        log_error "RUN_OS_AIDE variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_AIDE} != 1 ]] && \
        log_error "RUN_OS_AIDE is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package aide
    [[ $(dpkg -l|awk '{print $2}'|grep -c "aide") -lt 1 ]] && \
        log_info "aide is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof aide) -gt 0 ]] && \
        log_info "aide is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __os-aide_run {
    ## aide minimal check for first run
    systemd-run -r aide --check --config=/etc/aide/aide.minimal.conf
    return 0
}

complete -F _blank os-aide