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

    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-kparams_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-kparams_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-kparams_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-kparams_run "$2"
    else
        __os-kparams_help
    fi
}

function __os-kparams_help {
    echo -e "Usage: os-kparams [COMMAND] [profile]\n"
    echo -e "Helper to kernel params installation.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os firmware"
    echo "   uninstall Uninstall installed firmware"
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