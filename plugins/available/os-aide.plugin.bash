## \author Timothée Mazzucotelli / @pawamoy <dev@pawamoy.fr>

## \brief Save file paths in a buffer to move them somewhere else.
## \desc This tool lets you save file paths into a buffer before moving or copying
## them somewhere else. It acts like a drag-and-drop utility but for the command-line.
## It can be useful when you don't want to type the entire destination path and
## proceed in three or more steps instead, using shortcut commands to move around your
## filesystem, dragging files from multiple directories.

## \example Drag files from multiple directories, drop them in another:
## \example-code bash
##   cd ~/Documents
##   drag ThisPlaylist.s3u
##   cd ../Downloads
##   drag ThisTrack.ogg AndThisVideo.mp4
##   drag --drop ../project
## \example-description
## In this example, we simply move around in the filesystem, picking files in
## each of these directories. At the end, we drop them all in a specific
## directory.

## \example Define a convenient `drop` alias:
## \example-code bash
##   alias drop='drag -d'
##   drag file.txt
##   cd /somewhere/else
##   drop
## \example-description
## In this example, we define a `drop` alias that allows us to actually
## run `drag` then `drop` (instead of `drag --drop`).

## \exit 1 No arguments provided.

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
    local DMNNAME="os-aide"
    BASH_IT_LOG_PREFIX="os-aide: "
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
        __os-aide_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __os-aide_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __os-aide_download "$2"
    else
        __os-aide_help
    fi
}

## \usage os-aide FILES
## \usage os-aide -d|-p [DIR]
## \usage os-aide -c|-l
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
        apt install -qy aide || log_error "${DMNNAME} online install failed."
    else
        local filepat="./pkgs/aide*.deb"
        local pkglist="./pkgs/aide.pkgs"
        [[ $(find ${filepat}|wc -l) -lt 1 ]] && log_error "${DMNNAME} pkg file not found."
        pkgslist_down=()
        while read -r pkg; do
            [[ $pkg ]] && pkgslist_down+=("./pkgs/${pkg}*.deb")
        done < ${pkglist}
        # shellcheck disable=SC2068
        apt install -qy ${pkgslist_down[@]} || log_error "${DMNNAME} offline install failed."
    fi

    if ! __os-aide_configgen; then # if gen config is different do apply
        __os-aide_configapply
        rm -rf /tmp/${PKGNAME}
    fi

    aide --init --config=/etc/aide/aide.minimal.conf 2>/dev/null && \
        cp /var/lib/aide/aide.minimal.db.new.gz /var/lib/aide/aide.minimal.db.gz
}

function __os-aide_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __os-aide_configapply {
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

function __os-aide_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_apt_pkgs aide || log_error "${DMNNAME} download failed."
    return 0
}

function __os-aide_uninstall { 
    log_debug "Uninstalling ${DMNNAME}..."
    apt purge -yq aide
}

function __os-aide_disable {
    log_debug "Disabling ${DMNNAME}..."
    :
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
    log_debug "Checking ${DMNNAME}..."

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