## \brief custom OS firmware install in kernel. <div style="text-align: right"> group:**postos** | runtype:**manual** | deps: **-** | port: **-**</div><br/>
## \desc 
## This tool helps install, configure, and manage custom firmware in the Linux kernel for hardware support and optimization.
# It provides automated installation, configuration management, and firmware update capabilities.
# The tool manages kernel firmware files, driver modules, and hardware-specific configurations
# to ensure proper hardware functionality and performance.
## 
## # Jangbi Configs
## ```bash title="/opt/jangbi/.config"
## RUN_OS_FIRMWARE=1 # enable firmware installation
## FIRMWARE_MODE="auto" # mode: auto|manual
## ```
## # Check if running
## ```bash title="bash command"
## $ ls -la /lib/firmware/
## drwxr-xr-x 2 root root 4096 Jan 01 12:00 firmware
## $ dmesg | grep firmware
## [    1.234567] firmware: loading firmware files
## ```
## # Current Configuration
## Current configuration is stored in `/etc/firmware/`. it is generated by `os-firmware configgen` command on install.
## You can edit it manually and not run install or configapply commands to keep current configurations.
## ```bash title="/etc/firmware/config"
## ```

# shellcheck shell=bash
cite about-plugin
about-plugin 'custom os firmware install in kernel.'

function os-firmware {
    about 'helper function for os firmware update'
    group 'prenet'
    runtype 'none'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-firmware subcommand'
    local PKGNAME="firmware"
    local DMNNAME="os-firmware"
    BASH_IT_LOG_PREFIX="os-firmware: "
    # OS_FIRMWARE_PORTS="${OS_FIRMWARE_PORTS:-""}"
    if _check_config_reload; then
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "help" ]]; then
        __os-firmware_help "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-firmware_install "$2"
    elif [[ $# -gt 0 ]] && [[ "$1" = "uninstall" ]]; then
        __os-firmware_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __os-firmware_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disable" ]]; then
        __os-firmware_disable "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __os-firmware_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __os-firmware_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-firmware_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-firmware_run "$2"
    else
        __os-firmware_help
    fi
}

## \usage os-firmware install|uninstall|download|disable|configgen|configapply|check|run
## $ os-firmware install - install firmware
## $ os-firmware uninstall - uninstall firmware
## $ os-firmware download - download firmware files to pkg dir
## $ os-firmware disable - disable firmware plugin
## $ os-firmware configgen - generate firmware configuration files
## $ os-firmware configapply - apply firmware configuration files
## $ os-firmware check - check firmware plugin status
## $ os-firmware run - run firmware installation
## $ os-firmware help - show this help message
function __os-firmware_help {
    echo -e "Usage: os-firmware [COMMAND]\n"
    echo -e "Helper to os firmware installation.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install os firmware"
    echo "   uninstall   Uninstall installed firmware(--force)"
    echo "   download    Download firmware files to pkg dir"
    echo "   disable     Disable firmware installation"
    echo "   configgen   Generate configuration files"
    echo "   configapply Apply configuration files"
    echo "   check       Check vars available"
    echo "   run         Run os-firmware task"
}

function __os-firmware_install {
    log_debug "Installing ${DMNNAME}..."
    
    local firmware_file
    firmware_file="./pkgs/$(basename "${FIRMWARE_URL}")"

    [[ ! -f ${firmware_file} ]] && log_debug "Downloading Firmware File..." && wget --directory-prefix=./pkgs "${FIRMWARE_URL}"

    log_debug "Trying to install os-firmware."
    if [[ -f ${firmware_file} ]]; then
        if [[ ! -f ".firmware_original.tar.gz" ]]; then
            log_debug "Starting to backup firware from system"
            # backup original firmware from system
            tar czf .firmware_original.tar.gz /lib/firmware #--strip-components=1
            log_debug "original /lib/firmware backed up to .firmware_original.tar.gz."
            # save original firmware checksum
            sha256sum .firmware_original.tar.gz > ".firmware_original.sha256"
            log_debug "checksum saved to .firmware_original.sha256."
            # save current firmware size
            du -s /lib/firmware > .firmware_updated.size
        fi
        # unzip new firmware
        # unzip -d "/lib/firmware" "${RUN_OS_FIRMWARE_file}" && f=("/lib/firmware"/*) && cp -rf "/lib/firmware"/*/* "/lib/firmware" && rm -rf "${f[@]}"
        tar xfv "${firmware_file}" -C /lib/firmware --strip-components=1
        log_debug "new firmware file unzip to /lib/firmware."
        systemctl restart systemd-modules-load.service # reload kernel modules
        log_debug "new firmware has loaded."
        # save installed firmware file size
        find "${firmware_file}" -printf "%s\n" > /lib/firmware/.last_firmware_updated.size
    fi
}

function __os-firmware_uninstall { 
    log_debug "Uninstalling ${DMNNAME}..."
    sha256sum -c ".firmware_original.sha256"
    # [[ $(du -s /lib/firmware| cut -f1) -ne $(cat .firmware_updated.size|cut -f1) ]] && echo "/lib/firmware folder has changed since last firmware installed. please retry with --force argument." && update_proceed=0
    tar -zxf .firmware_original.tar.gz -C /lib/firmware --strip-components=2
    echo "original firmware file has extracted to /lib/firmware."
    systemctl restart systemd-modules-load.service # reload kernel modules
    echo "firmware reloaded."
}

function __os-firmware_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check global variable
    [[ -z ${RUN_OS_FIRMWARE} ]] && \
        log_error "RUN_OS_FIRMWARE variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ -z ${FIRMWARE_URL} ]] && \
        log_error "FIRMWARE_URL variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_FIRMWARE} != 1 ]] && \
        log_error "RUN_OS_FIRMWARE is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    
    # check old firmware backup exists
    [[ ! -f .firmware_original.tar.gz ]] && \
        log_info "original firmware backup file(.firmware_original.tar.gz) does not exist" && [[ $running_status -lt 5 ]] && running_status=5
    
    # compare /lib/firmware with RUN_OS_FIRMWARE size
    local exists_size new_size
    exists_size=$( ( cut -f1 < /lib/firmware/.last_firmware_updated.size ) 2>/dev/null || echo 0)
    new_size=$(find "./pkgs/$(basename "${FIRMWARE_URL}")" -printf "%s\n" || echo 0)
    [[ $(( "${new_size}" - "${exists_size}" )) != 0 ]] &&
        log_info "new firmware size is different with pre-installed firmware." && running_status=5

    return 0
}

function __os-firmware_run {
    :
}

function __os-firmware_download {
    log_debug "Downloading ${DMNNAME}..."
    local firmware_file
    firmware_file="./pkgs/$(basename "${FIRMWARE_URL}")"
    [[ ! -f ${firmware_file} ]] && wget --directory-prefix=./pkgs "${FIRMWARE_URL}"
    return 0
}

function __os-firmware_disable {
    log_debug "Disabling ${DMNNAME}..."
    return 0
}

function __os-firmware_configgen {
    log_debug "Generating config for ${DMNNAME}..."
    return 0
}

function __os-firmware_configapply {
    log_debug "Applying config for ${DMNNAME}..."
    return 0
}

complete -F _blank os-firmware