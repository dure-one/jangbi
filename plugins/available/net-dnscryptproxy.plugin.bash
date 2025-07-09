# shellcheck shell=bash
cite about-plugin
about-plugin 'dnscryptproxy install configurations.'

function net-dnscryptproxy {
    about 'dnscryptproxy install configurations'
    group 'net'
    param '1: command'
    param '2: params'
    example '$ net-dnscryptproxy check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-dnscryptproxy_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-dnscryptproxy_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-dnscryptproxy_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-dnscryptproxy_run "$2"
    else
        __net-dnscryptproxy_help
    fi
}

function __net-dnscryptproxy_help {
    echo -e "Usage: net-dnscryptproxy [COMMAND] [profile]\n"
    echo -e "Helper to dnscryptproxy install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install dnscryptproxy"
    echo "   uninstall Uninstall installed dnscryptproxy"
    echo "   check     Check vars available"
    echo "   run       run"
}

function __net-dnscryptproxy_install {
    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install net-dnscryptproxy."
    mkdir -p /tmp/dnscryptproxy
    tar -zxvf ./pkgs/dnscrypt-proxy-linux*.tar.gz -C /tmp/dnscryptproxy --strip-components=1 2>/dev/null 2>&1
    if [[ ! -f /tmp/dnscryptproxy/dnscrypt-proxy ]]; then
        log_error "dnscryptproxy binary not found in package."
        return 1
    fi
    cp /tmp/dnscryptproxy/dnscrypt-proxy /usr/sbin/dnscrypt-proxy
    chmod 755 /sbin/dnscrypt-proxy

    mkdir -p /etc/dnscrypt-proxy
    cp ./configs/dnscrypt-proxy/* /etc/dnscrypt-proxy/
    
    touch /var/log/dnscrypt-proxy.log
}

function __net-dnscryptproxy_disable {
    pidof dnscrypt-proxy | xargs kill -9 2>/dev/null
    return 0
}

function __net-dnscryptproxy_uninstall {
    log_debug "Trying to uninstall net-dnscryptproxy."
    pidof dnscrypt-proxy | xargs kill -9 2>/dev/null
    rm -rf /usr/sbin/dnscrypt-proxy
}

function __net-dnscryptproxy_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-dnscryptproxy Check"
    # check package file exists
    [[ $(find ./pkgs/dnscrypt-proxy-linux*|wc -l) -lt 1 ]] && \
        log_info "dnscryptproxy package file does not exist." && [[ $running_status -lt 10 ]] && running_status=10
    # check global variable
    [[ -z ${RUN_DNSCRYPTPROXY} ]] && \
        log_info "RUN_DNSCRYPTPROXY variable is not set." && __net-dnscryptproxy_disable && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_DNSCRYPTPROXY} != 1 ]] && \
        log_info "RUN_DNSCRYPTPROXY is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which dnscrypt-proxy|wc -l) -lt 1 ]] && \
        log_info "dnscryptproxy is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof dnscrypt-proxy) -gt 0 ]] && \
        log_info "dnscryptproxy is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-dnscryptproxy_run {
    log_debug "Running dnscryptproxy..."
    
    pidof dnscrypt-proxy | xargs kill &>/dev/null
    
    log_debug "Starting dnscrypt-proxy" 
    dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml -logfile /var/log/dnscrypt-proxy.log &
    
    # if dnsmasq is disabled set default dns resolver to dnscrypt-proxy.
    if [[ ${RUN_NET_DNSMASQ} -lt 1 ]]; then
        log_debug "Set dns resolve to 127.0.0.2." 
        echo "nameserver 127.0.0.2"|tee /etc/resolv.conf
    fi

    # if dnsmasq is enabled set upstream dns for dnsmasq to dnscrypt-proxy
    if [[ ${RUN_NET_DNSMASQ} -gt 0 ]]; then
        log_debug "Set dnsmasq upstream to 127.0.0.2." 
        sed -i "s|server=.*|server=127.0.0.2|g" "/etc/dnsmasq.d/dnsmasq.conf"
        __net-dnsmasq_run # rerun dnsmasq
    fi

    pidof dnscrypt-proxy && return 0 || \
        log_error "dnscryptproxy failed to run." && return 1
}

complete -F __net-dnscryptproxy_run net-dnscryptproxy