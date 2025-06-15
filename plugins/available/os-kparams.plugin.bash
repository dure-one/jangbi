# shellcheck shell=bash
cite about-plugin
about-plugin 'custom kernel params in cmdline.'

function os-kparams {
	about 'helper function for os firmware update'
	group 'os'
    param '1: command'
    param '2: params'
    example '$ os-kparams check/install/uninstall/run'

	if [[ -z ${DURE_DEPLOY_PATH} ]]; then
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
    log_debug "Trying to install os-kparams."
}

function __os-kparams_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall os-kparams."
	local kernel_params_cmdline="/etc/kernel_cmdline"
	umount /root/cmdline
    rm ${kernel_params_cmdline}
}

function __os-kparams_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting os-kparams Check"

    [[ ${#KERNEL_PARAMS[@]} -lt 1 ]] && \
    log_info "KERNEL_PARAMS variable is not set." && [[ $running_status -lt 10 ]] && running_status=10

    [[ $(mount|grep /proc/cmdline|wc -l) -lt 1 ]] && \
    log_info "kernel custom cmdline has mounted." && [[ $running_status -lt 0 ]] && running_status=0

	return 0
}

function __os-kparams_run {
	local kernel_params_cmdline="/etc/kernel_cmdline"
	umount /proc/cmdline &>/dev/null
    cat /proc/cmdline > ${kernel_params_cmdline}
    chmod 600 ${kernel_params_cmdline}
    local kcmdline=$(cat ${kernel_params_cmdline})
    kcmdline="${kcmdline} slab_nomerge init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 pti=on randomize_kstack_offset=on vsyscall=none debugfs=off oops=panic module.sig_enforce=1 lockdown=confidentiality mce=0 quiet loglevel=0 random.trust_cpu=off intel_iommu=on amd_iommu=on efi=disable_early_pci_dma"
    echo "${kcmdline}" > ${kernel_params_cmdline}
    mount -n --bind -o ro ${kernel_params_cmdline} /proc/cmdline
	return 0
}

complete -F __os-kparams_run os-kparams