## \brief custom OS configurations. <div style="text-align: right"> group:**prenet** | runtype:**none** | deps: **-** | port: **-**</div><br/>
## \desc 
## [OS Configuration](https://jangbi.org/docs/os-conf){:target="_blank"} provides custom operating system configurations for system hardening and optimization.
# It provides automated installation, configuration management, and system customization capabilities.
# The tool manages user accounts, file permissions, system settings, and various OS-level configurations
# to establish a secure and optimized system baseline.
## 
## # Jangbi Configs
## ```bash title="/opt/jangbi/.config"
## RUN_OS_CONF=1 # enable custom OS configurations
## ```
## # Check if running
## ```bash title="bash command"
## $ ls -la /etc/jangbi/
## -rw-r--r-- 1 root root custom.conf
## $ systemctl --no-pager list-unit-files | grep jangbi
## jangbi-hardening.service              enabled
## ```
## # Current Configuration
## Current configuration is stored in `/etc/jangbi/`. it is generated by `os-conf configgen` command on install.
## You can edit it manually and not run install or configapply commands to keep current configurations.
## ```bash title="/etc/jangbi/custom.conf"
## ```

# shellcheck shell=bash
cite about-plugin
about-plugin 'custom os configurations'

function os-conf {
    about 'helper function for os configuration'
    group 'prenet'
    runtype 'none'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-conf subcommand'
    local PKGNAME="conf"
    local DMNNAME="os-conf"
    BASH_IT_LOG_PREFIX="os-conf: "
    # OS_CONF_PORTS="${OS_CONF_PORTS:-""}"
    if _check_config_reload; then
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "help" ]]; then
        __os-conf_help "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-conf_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-conf_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __os-conf_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disable" ]]; then
        __os-conf_disable "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __os-conf_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __os-conf_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-conf_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-conf_run "$2"
    else
        __os-conf_help
    fi
}

## \usage os-conf help|install|uninstall|download|disable|configgen|configapply|check|run
## $ os-conf install - install custom OS configurations
## $ os-conf uninstall - uninstall custom OS configurations
## $ os-conf download - download OS configuration files to pkg dir
## $ os-conf disable - disable OS configuration plugin
## $ os-conf configgen - generate OS configuration files
## $ os-conf configapply - apply OS configuration files
## $ os-conf check - check OS configuration plugin status
## $ os-conf run - run OS configuration tasks
## $ os-conf help - show this help message
function __os-conf_help {
    echo -e "Usage: os-conf [COMMAND]\n"
    echo -e "Helper to os configuration installation.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install os configuration"
    echo "   uninstall   Uninstall installed os configuration"
    echo "   download    Download pkg files to pkg dir"
    echo "   disable     Disable os configuration"
    echo "   configgen   Generate configuration files"
    echo "   configapply Apply configuration files"
    echo "   check       Check vars available"
    echo "   run         Run tasks"
}

function __os-conf_install {
    # A. add user if not exists
    local random_text
    random_text=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo)
    if [[ $(grep -c "${JB_USERID}\:x:" < "/etc/passwd") -lt 1 && -n ${JB_USERID} ]]; then
        log_debug "Trying to do os-conf, adduser ${JB_USERID}."
        adduser --gecos "" --disabled-password "${JB_USERID}"
        chpasswd <<<"${JB_USERID}:${random_text}"
        mkdir -p "/home/${JB_USERID}/.ssh/"
        echo -e "${JB_SSHPUBKEY}" > "/home/${JB_USERID}/.ssh/authorized_keys"
        echo -e "${JB_USERID} ALL=(ALL:ALL) PASSWD: ALL, !/usr/bin/passwd" >> /etc/sudoers
        echo -e "${JB_USERID} ALL=(ALL:ALL) NOPASSWD: /usr/bin/passwd" >> /etc/sudoers
        echo "Defaults timestamp_timeout=60" | sudo tee /etc/sudoers.d/timeout
        visudo -cf /etc/sudoers.d/timeout
    fi

    # B. timezon fix
    log_debug "Trying to do os-conf, fix timezone to ${CONF_TIMEZONE}."
    rm -rf /etc/localtime
    ln -s "/usr/share/zoneinfo/${CONF_TIMEZONE}" "/etc/localtime"

    # C. swap enable
    # * dure_deploy_path should have more space than swap size
    if [[ -n ${CONF_SWAPSIZE} && $(awk '{ print $3 }' < "/proc/swaps"|grep -v Size) -lt 1000000 ]]; then
        if [[ ! -f ${JB_DEPLOY_PATH}/swapfile ]]; then # https://askubuntu.com/a/1162472
            log_debug "Trying to do os-conf, set swap size to ${CONF_SWAPSIZE}."
            truncate -s "${CONF_SWAPSIZE}" "${JB_DEPLOY_PATH}/swapfile"
            # fallocate -x -l "${CONF_SWAPSIZE}" "${JB_DEPLOY_PATH}/swapfile" 1>/dev/null 2>&1
            dd if=/dev/zero "of=${JB_DEPLOY_PATH}/swapfile" bs=1M count=4096 status=progress
            chown root:root "${JB_DEPLOY_PATH}/swapfile"
            chmod 0600 "${JB_DEPLOY_PATH}/swapfile"
            mkswap "${JB_DEPLOY_PATH}/swapfile"
        fi
        swapoff -a
        swapon "${JB_DEPLOY_PATH}/swapfile"
        swapon -s
    fi

    # D. cron enable
    log_debug "Installing cron..."
    export DEBIAN_FRONTEND=noninteractive
    if [[ ${INTERNET_AVAIL} -gt 0 ]]; then
        [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
        [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
        apt install -qy cron
    else
        local filepat="./pkgs/cron*.deb"
        local pkglist="./pkgs/cron.pkgs"
        [[ $(find ${filepat}|wc -l) -lt 1 ]] && apt update -qy && __os-conf_download
        pkgslist_down=()
        while read -r pkg; do
            [[ $pkg ]] && pkgslist_down+=("./pkgs/${pkg}*.deb")
        done < ${pkglist}
        # shellcheck disable=SC2068
        apt install -qy ${pkgslist_down[@]} || log_error "${DMNNAME} offline install failed."
    fi

    crontab -l > /tmp/mycron
    sed -i "s|^.*# CONF_TIMESYNC||g" "/tmp/mycron"
    if [[ ${CONF_TIMESYNC} == 'http' ]]; then # CONF_TIMESYNC=http
        echo "*/10 * * * * cd ${JB_DEPLOY_PATH} && source functions.sh _time_sync ${DNS_UPSTREAM} # CONF_TIMESYNC" >> /tmp/mycron
    else # CONF_TIMESYNC=ntp
        cp ./configs/ntpclient.pl /sbin/ntpclient.pl
        chmod +x /sbin/ntpclient.pl
        echo "*/10 * * * * /sbin/ntpclient.pl # CONF_TIMESYNC" >> /tmp/mycron
    fi
    crontab /tmp/mycron
    rm /tmp/mycron
}

function __os-conf_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_apt_pkgs cron || log_error "${DMNNAME} download failed."
    return 0
}

function __os-conf_uninstall { 
    log_debug "Uninstalling ${DMNNAME}..."
    # remove swapfile
    swapoff -a
    rm -rf "${JB_DEPLOY_PATH}/swapfile"

    # remove sudoers username lines
    sed -i "s|^${JB_USERID}.*||g" /etc/sudoers
    sudo rm -f /etc/sudoers.d/timeout
}

function __os-conf_disable { 
    log_debug "Disabling ${DMNNAME}..."
    swapoff -a
    return 0
}

function __os-conf_configgen {
    log_debug "Generating config for ${DMNNAME}..."
    return 0
}

function __os-conf_configapply {
    log_debug "Applying config for ${DMNNAME}..."
    return 0
}

function __os-conf_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check package file exists
    [[ $(find ./pkgs/cron*.pkgs|wc -l) -lt 1 ]] && \
        log_info "cron package file does not exist." && [[ $running_status -lt 15 ]] && running_status=15
    # check global variable
    [[ -z ${RUN_OS_CONF} ]] && \
        log_error "RUN_OS_CONF variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_CONF} != 1 ]] && \
        log_error "RUN_OS_CONF is not enabled." && __os-conf_disable && [[ $running_status -lt 20 ]] && running_status=20
    [[ -z ${CONF_TIMEZONE} ]] && \
        log_error "CONF_TIMEZONE variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    # [[ ${#CONF_SWAPSIZE[@]} -lt 1 ]] && \
    #     log_info "CONF_SWAPSIZE variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    # [[ ${#JB_USERID[@]} -lt 1 ]] && \
    #     log_info "JB_USERID variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    # [[ ${#JB_SSHPUBKEY[@]} -lt 1 ]] && \
    #     log_info "JB_SSHPUBKEY variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    
    # check user installed
    [[ $(grep -c "${JB_USERID}\:x:" < "/etc/passwd") -lt 1 ]] && \
        log_info "User ${JB_USERID} does not exist." && [[ $running_status -lt 5 ]] && running_status=5
    # check timezone installed
    [[ $(ls -l /etc/localtime) != *"${CONF_TIMEZONE}"* ]] && \
        log_info "Timezone ${CONF_TIMEZONE} not set correctly." && [[ $running_status -lt 5 ]] && running_status=5
    # check if swapfile exists
    # [[ ! -f "${JB_DEPLOY_PATH}/swapfile" ]] && \
    #     log_info "Swapfile does not exist at ${JB_DEPLOY_PATH}/swapfile." && [[ $running_status -lt 5 ]] && running_status=5
    # check if swap is enabled
    #[[ ! -f "/proc/swaps" ]] && \
    #    log_info "Swap is not enabled." && [[ $running_status -lt 5 ]] && running_status=5
    # check if swapfile is loaded
    # [[ $(cat /proc/swaps|awk '{ print $1 }'|grep -c "${JB_DEPLOY_PATH}/swapfile") -lt 1 ]] && \
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
    :
}

complete -F _blank os-conf