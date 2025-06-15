# shellcheck shell=bash
cite about-plugin
about-plugin 'anydnsdqy install configurations.'

function net-anydnsdqy {
	about 'anydnsdqy install configurations'
	group 'net'
    param '1: command'
    param '2: params'
    example '$ net-anydnsdqy check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

	if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
		__net-anydnsdqy_install "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
		__net-anydnsdqy_uninstall "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
		__net-anydnsdqy_check "$2"
	elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
		__net-anydnsdqy_run "$2"
	else
		__net-anydnsdqy_help
	fi
}

function __net-anydnsdqy_help {
	echo -e "Usage: net-anydnsdqy [COMMAND] [profile]\n"
	echo -e "Helper to anydnsdqy install configurations.\n"
	echo -e "Commands:\n"
	echo "   help      Show this help message"
	echo "   install   Install anydnsdqy"
	echo "   uninstall Uninstall installed anydnsdqy"
	echo "   check     Check vars available"
    echo "   run       run"
}

function __net-anydnsdqy_install {
    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install net-anydnsdqy."

	cp ./pkgs/anydnsdqy-x86_64* /usr/sbin/anydnsdqy
	chmod 755 /sbin/anydnsdqy
}

function __net-anydnsdqy_uninstall {
    log_debug "Trying to uninstall net-anydnsdqy."
    echo $(pidof anydnsdqy) | xargs kill -9 2>/dev/null
    rm -rf /usr/sbin/anydnsdqy
}

function __net-anydnsdqy_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
	local return_code=0
    log_debug "Starting net-anydnsdqy Check"
    # check variable exists
    [[ -z ${RUN_ANYDNSDQY} ]] && log_info "RUN_ANYDNSDQY variable is not set." && return 1
    # check pkg installed
    [[ $(which anydnsdqy|wc -l) -lt 1 ]] && log_info "anydnsdqy is not installed." && return 0
    # check dnsmasq started
    [[ $(pidof anydnsdqy) -gt 1 ]] && log_info "anydnsdqy is started." && return 2

    return 0
}

function __net-anydnsdqy_run { # run socks proxy $NET
    anydnsdqy @quic://dns.adguard.com &
	return 0
}

complete -F __net-anydnsdqy_run net-anydnsdqy