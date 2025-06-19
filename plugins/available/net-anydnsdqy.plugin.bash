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
    mkdir -p /tmp/anydnsdqy
    tar -zxvf ./pkgs/anydnsdqy-x86_64*.tar.gz -C /tmp/anydnsdqy 2>/dev/null 2>&1
    if [[ ! -f /tmp/anydnsdqy/anydnsdqy ]]; then
        log_error "anydnsdqy binary not found in package."
        return 1
    fi
    cp /tmp/anydnsdqy/anydnsdqy /usr/sbin/anydnsdqy
    chmod 755 /sbin/anydnsdqy
}

function __net-anydnsdqy_disable {
    pidof anydnsdqy | xargs kill -9 2>/dev/null
    return 0
}

function __net-anydnsdqy_uninstall {
    log_debug "Trying to uninstall net-anydnsdqy."
    pidof anydnsdqy | xargs kill -9 2>/dev/null
    rm -rf /usr/sbin/anydnsdqy
}

function __net-anydnsdqy_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-anydnsdqy Check"
    # check package file exists
    [[ $(find ./pkgs/anydnsdqy-x86_64*|wc -l) -lt 1 ]] && \
        log_info "anydnsdqy package file does not exist." && [[ $running_status -lt 10 ]] && running_status=10
    # check global variable
    [[ -z ${RUN_ANYDNSDQY} ]] && \
        log_info "RUN_ANYDNSDQY variable is not set." && __net-anydnsdqy_disable && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_ANYDNSDQY} != 1 ]] && \
        log_info "RUN_ANYDNSDQY is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which anydnsdqy|wc -l) -lt 1 ]] && \
        log_info "anydnsdqy is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof anydnsdqy) -gt 0 ]] && \
        log_info "anydnsdqy is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-anydnsdqy_run {
    log_debug "Running anydnsdqy..."
    
    echo "nameserver ${DNS_UPSTREAM}"|tee /etc/resolv.conf
    pidof anydnsdqy | xargs kill &>/dev/null
    
    if [[ ${RUN_ANYDNSDQY} -gt 0 ]]; then
        # anydnsdqy @quic://dns.adguard.com -b 127.0.0.2:53 &>/var/log/anydnsdqy.log &
        log_debug "Starting anyndsdqy on 127.0.0.2:53 to @quic://dns.adguard.com" 
        anydnsdqy @quic://dns.adguard.com --bindaddress 127.0.0.2:53 1>/var/log/anydnsdqy.log &
        sleep 3
        
        log_debug "Set dns resolve to 127.0.0.2." 
        echo "nameserver 127.0.0.2"|tee /etc/resolv.conf
    else
        log_debug "Set dns resolve to ${DNS_UPSTREAM}." 
        echo "nameserver ${DNS_UPSTREAM}"|tee /etc/resolv.conf
    fi 

    pidof anydnsdqy && return 0 || \
        log_error "anydnsdqy failed to run." && return 1
}

complete -F __net-anydnsdqy_run net-anydnsdqy