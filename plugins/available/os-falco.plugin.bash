# shellcheck shell=bash
cite about-plugin
about-plugin 'falco install configurations.'
# VARS :

function os-falco {
	about 'falco install configurations'
	group 'os'
    param '1: command'
    param '2: params'
    example '$ os-falco check/install/uninstall/run'

	if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

	if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
		__os-falco_install "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
		__os-falco_uninstall "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
		__os-falco_check "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
		__os-falco_run "$2"
	else
		__os-falco_help
	fi
}

function __os-falco_help {
	echo -e "Usage: os-falco [COMMAND] [profile]\n"
	echo -e "Helper to falco install configurations.\n"
	echo -e "Commands:\n"
	echo "   help      Show this help message"
	echo "   install   Install os falco"
	echo "   uninstall Uninstall installed falco"
	echo "   check     Check vars available"
	echo "   run       Run tasks"
}

function __os-falco_install {
	export DEBIAN_FRONTEND=noninteractive
	log_debug "Trying to install os-falco."
	apt install -qy ./pkgs/falco*.deb

	FALCO_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=ebpf FALCOCTL_ENABLED=no apt install ./pkgs/falco-0.41.1-x86_64.deb
	# falco hardening dynamic
	systemctl enable falco
	auditctl -l
	# do on everyboot
	systemctl start falco
	auditctl -R /etc/audit/audit.rules
}

function __os-falco_uninstall {
	log_debug "Trying to uninstall os-falco."
	apt purge -qy falco
#	systemctl stop falco
#	systemctl disable falco
}

function __os-falco_check {  # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
	running_status=0
    log_debug "Starting os-falco Check"
    [[ ${#RUN_FALCO[@]} -lt 1 ]] && \
        log_info "RUN_FALCO variable is not set." && [[ $running_status -lt 10 ]] && running_status=10

    [[ $(dpkg -l|grep falco|wc -l) -lt 1 ]] && \
        log_info "falco is not installed." && [[ $running_status -lt 5 ]] && running_status=5

    return 0
}

function __os-falco_run {
    :
	return 0
}

complete -F __os-falco_run os-falco
