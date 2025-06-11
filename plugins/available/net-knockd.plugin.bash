# shellcheck shell=bash
cite about-plugin
about-plugin 'knockd install configurations.'

function net-knockd {
	about 'knockd install configurations'
	group 'net'
    param '1: command'
    param '2: params'
    example '$ net-knockd check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

	if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
		__net-knockd_install "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
		__net-knockd_uninstall "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
		__net-knockd_check "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
		__net-knockd_run "$2"
	else
		__net-knockd_help
	fi
}

function __net-knockd_help {
	echo -e "Usage: net-knockd [COMMAND] [profile]\n"
	echo -e "Helper to knockd install configurations.\n"
	echo -e "Commands:\n"
	echo "   help      Show this help message"
	echo "   install   Install knockd"
	echo "   uninstall Uninstall installed knockd"
	echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __net-knockd_install {
    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install net-knockd."
    apt install -qy knockd
    systemctl enable knockd
    mv /etc/knockd.conf /etc/knockd.old.conf
    cp ./configs/knockd.conf.default /etc/knockd.conf
    cp knock_otp_regen.sh /sbin/knock_otp_regen.sh
    chmod 600 /sbin/knock_otp_regen.sh
    chmod 600 /etc/knockd.conf
    echo "" > /tmp/mycron
    echo "*/10 * * * * /sbin/knock_otp_regen.sh # KNOCKD" >> /tmp/mycron
    crontab /tmp/mycron
rm /tmp/mycron
}

function __net-knockd_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall net-knockd."
    rm /sbin/knock_otp_regen.sh 2>/dev/null
    systemctl stop knockd
    systemctl disable knockd
}

function __net-knockd_check { ## running_status 0 installed, running_status 5 can install, running_status 10 can't install
    running_status=0
    log_debug "Starting net-knockd Check"
    [[ ${#RUN_KNOCKD[@]} -lt 1 ]] && \
        log_info "RUN_KNOCKD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10

    [[ $(dpkg -l|grep knockd|wc -l) -lt 1 ]] && \
        log_info "knockd is not installed." && [[ $running_status -lt 5 ]] && running_status=5

    [[ $(systemctl status knockd|grep Active|wc -l) -gt 0 ]] && \
        log_info "knockd is not running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-knockd_run {
    systemctl start knockd
	return 0
}

complete -F __net-knockd_run net-knockd