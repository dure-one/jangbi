# shellcheck shell=bash
cite about-plugin
about-plugin 'custom os firmware install in kernel.'
# VARS : UPDATE_FIRMWARE

function os-firmware {
	about 'helper function for os firmware update'
	group 'os'
    param '1: command'
    param '2: params'
    example '$ os-firmware check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

	if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
		__os-firmware_install "$2"
	elif [[ $# -gt 0 ]] && [[ "$1" = "uninstall" ]]; then
		__os-firmware_uninstall "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
		__os-firmware_check "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
		__os-firmware_run "$2"
	else
		__os-firmware_help
	fi
}

function __os-firmware_help {
	echo -e "Usage: os-firmware [COMMAND] [profile]\n"
	echo -e "Helper to os firmware installation.\n"
	echo -e "Commands:\n"
	echo "   help      Show this help message"
	echo "   install   Install os firmware"
	echo "   uninstall Uninstall installed firmware(--force)"
	echo "   check     Check vars available"
	echo "   run       Run os-firmware task"
}

function __os-firmware_install {
	local update_firmware_file="./pkgs/$(basename ${UPDATE_FIRMWARE})"
    local update_proceed=0
    log_debug "Trying to install os-firmware."
    if [[ -f ${update_firmware_file} ]]; then
        # sha256sum -c ".firmware_original.sha256" && update_proceed=1
        if [[ ! -f ".firmware_original.tar.gz" ]]; then
            log_debug "Starting to backup firware from system"
            # backup original firmware from system
            tar czf .firmware_original.tar.gz -C /lib/firmware #--strip-components=1
            log_debug "original /lib/firmware backed up to .firmware_original.tar.gz."
            # save original firmware checksum
            sha256sum .firmware_original.tar.gz > ".firmware_original.sha256"
            log_debug "checksum saved to .firmware_original.sha256."
            # save current firmware size
            du -s /lib/firmware > .firmware_updated.size
        fi
        # unzip new firmware
        # unzip -d "/lib/firmware" "${update_firmware_file}" && f=("/lib/firmware"/*) && cp -rf "/lib/firmware"/*/* "/lib/firmware" && rm -rf "${f[@]}"
        tar xfv ${update_firmware_file} -C /lib/firmware --strip-components=1
        log_debug "new firmware file unzip to /lib/firmware."
        systemctl restart systemd-modules-load.service # reload kernel modules
        log_debug "new firmware has loaded."
    fi
}

function __os-firmware_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall os-firmware."
    local param="$1"
    sha256sum -c ".firmware_original.sha256" && update_proceed=1
    # [[ $(du -s /lib/firmware| cut -f1) -ne $(cat .firmware_updated.size|cut -f1) ]] && echo "/lib/firmware folder has changed since last firmware installed. please retry with --force argument." && update_proceed=0
    tar -zxf .firmware_original.tar.gz -C /lib/firmware --strip-components=2
    echo "original firmware file has extracted to /lib/firmware."
    systemctl restart systemd-modules-load.service # reload kernel modules
    echo "firmware reloaded."
}

function __os-firmware_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting os-firmware Check"
    [[ ${#UPDATE_FIRMWARE[@]} -lt 1 ]] && \
    log_info "UPDATE_FIRMWARE variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    # check old firmware backup not exists
    [[ ! -f .firmware_original.tar.gz ]] && \
    log_info "original firmware backup file(.firmware_original.tar.gz) does not exist" && [[ $running_status -lt 5 ]] && running_status=5
    # check new firmware file exists
    [[ ! -f ./pkgs/$(basename ${UPDATE_FIRMWARE}) ]] && \
    log_info "${UPDATE_FIRMWARE} file not exists in pkg directory." && [[ $running_status -lt 10 ]] && running_status=10
    # compare /lib/firmware with UPDATE_FIRMWARE size
    local exists_size=$(cat .firmware_updated.size 2>/dev/null|cut -f1)
    [[ -z ${exists_size} ]] && exists_size=0
    [[ $(( $(du -s /lib/firmware| cut -f1) - ${exists_size} )) -gt 0 ]] &&
        log_info "system firmware is updated on ${UPDATE_FIRMWARE}." && running_status=0
	return 0
}

function __os-firmware_run {
    # nothign to do
	return 0
}

complete -F __os-firmware_run os-firmware