## \brief custom kernel parameters in cmdline. <div style="text-align: right"> group:**postos** | runtype:**manual** | deps: **-** | port: **-**</div><br/>
## \desc 
## This tool helps install, configure, and manage custom kernel parameters in the kernel command line for system optimization and hardware control.
# It provides automated installation, configuration management, and kernel parameter modification capabilities.
# The tool manages boot parameters, kernel options, and system-level settings that are applied at boot time
# for enhanced performance and functionality.
## 
## # Jangbi Configs
## ```bash title="/opt/jangbi/.config"
## RUN_OS_KPARAMS=1 # enable kernel parameters
## KPARAMS_MODE="auto" # mode: auto|manual
## ```
## # Check if running
## ```bash title="bash command"
## $ cat /proc/cmdline
## BOOT_IMAGE=/vmlinuz root=/dev/sda1 custom_param=value
## $ dmesg | grep "Command line"
## [    0.000000] Command line: BOOT_IMAGE=/vmlinuz custom_param=value
## ```
## # Current Configuration
## Current configuration is stored in `/etc/kparams/`. it is generated by `os-kparams configgen` command on install.
## You can edit it manually and not run install or configapply commands to keep current configurations.
## ```bash title="/etc/kparams/config"
## ```

# shellcheck shell=bash
cite about-plugin
about-plugin 'custom kernel params in cmdline.'

function os-kparams {
    about 'helper function for os firmware update'
    group 'prenet'
    runtype 'none'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-kparams subcommand'
    local PKGNAME="kparams"
    local DMNNAME="os-kparams"
    BASH_IT_LOG_PREFIX="os-kparams: "
    # OS_KPARAMS_PORTS="${OS_KPARAMS_PORTS:-""}"
    if _check_config_reload; then
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "help" ]]; then
        __os-kparams_help "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-kparams_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-kparams_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __os-kparams_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disable" ]]; then
        __os-kparams_disable "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __os-kparams_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __os-kparams_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-kparams_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-kparams_run "$2"
    else
        __os-kparams_help
    fi
}

## \usage os-kparams install|uninstall|check|run
## $ os-kparams install - install kernel parameters
## $ os-kparams uninstall - uninstall kernel parameters
## $ os-kparams check - check kernel parameters plugin status
## $ os-kparams run - run kernel parameters
## $ os-kparams help - show this help message
function __os-kparams_help {
    echo -e "Usage: os-kparams [COMMAND]\n"
    echo -e "Helper to kernel params installation.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install kernel parameters"
    echo "   uninstall Uninstall kernel parameters"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-kparams_install {
    log_debug "Installing ${DMNNAME}..."
}

function __os-kparams_uninstall { 
    log_debug "Uninstalling ${DMNNAME}..."
    local kparams_cmdline="/etc/kernel_cmdline"
    umount /root/cmdline
    rm ${kparams_cmdline}
}

function __os-kparams_disable {
    log_debug "Disabling ${DMNNAME}..."
    umount /root/cmdline
    return 0
}

function __os-kparams_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    [[ -z ${RUN_OS_KPARAMS} ]] && \
        log_error "RUN_OS_KPARAMS variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${#RUN_OS_KPARAMS[@]} -lt 1 ]] && \
        log_error "RUN_OS_KPARAMS is not enabled." && __os-kparams_disable && [[ $running_status -lt 20 ]] && running_status=20

    [[ $(mount|grep -c "/proc/cmdline") -gt 0 ]] && \
        log_info "kernel custom cmdline is mounted." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __os-kparams_run {
    log_debug "Running ${DMNNAME}..."

    local kparams_cmdline="/etc/kernel_cmdline"
    umount /proc/cmdline &>/dev/null
    cat /proc/cmdline > ${kparams_cmdline}
    chmod 600 ${kparams_cmdline}
    local kcmdline
    kcmdline="$(cat ${kparams_cmdline}) slab_nomerge init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 pti=on randomize_kstack_offset=on vsyscall=none debugfs=off oops=panic module.sig_enforce=1 lockdown=confidentiality mce=0 quiet loglevel=0 random.trust_cpu=off intel_iommu=on amd_iommu=on efi=disable_early_pci_dma"
    echo "${kcmdline}" > ${kparams_cmdline}
    mount -n --bind -o ro ${kparams_cmdline} /proc/cmdline
    
    return 0
}

complete -F _blank os-kparams