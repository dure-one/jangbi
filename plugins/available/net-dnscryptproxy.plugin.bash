## \brief dnscryptproxy install configurations.
## \desc This tool helps install, configure, and manage DNSCrypt-proxy
## for secure DNS resolution. It provides automated installation, configuration management,
## and service control capabilities. DNSCrypt-proxy encrypts DNS queries and can protect
## against DNS spoofing and surveillance by routing queries through secure resolvers.

## \example Install and configure DNSCrypt-proxy:
## \example-code bash
##   net-dnscryptproxy install
##   net-dnscryptproxy configgen
##   net-dnscryptproxy configapply
## \example-description
## In this example, we install DNSCrypt-proxy, generate the configuration files,
## and apply them to the system for secure DNS resolution.

## \example Download package and run service:
## \example-code bash
##   net-dnscryptproxy download
##   net-dnscryptproxy run
##   net-dnscryptproxy check
## \example-description
## In this example, we download the DNSCrypt-proxy package,
## start the service, and verify its running status.

## \exit 1 Invalid command or parameters provided.


# shellcheck shell=bash
cite about-plugin
about-plugin 'dnscryptproxy install configurations.'

function net-dnscryptproxy {
    about 'dnscryptproxy install configurations'
    group 'postnet'
    runtype 'minmon'
    deps ''
    param '1: command'
    param '2: params'
    example '$ net-dnscryptproxy subcommand'
    local PKGNAME="dnscryptproxy"
    local DMNNAME="net-dnscryptproxy"
    BASH_IT_LOG_PREFIX="net-dnscryptproxy: "
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
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __net-dnscryptproxy_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __net-dnscryptproxy_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-dnscryptproxy_download "$2"
    else
        __net-dnscryptproxy_help
    fi
}

## \usage net-dnscryptproxy [COMMAND] [profile]
## \usage net-dnscryptproxy install|uninstall|configgen|configapply
## \usage net-dnscryptproxy check|run|download
function __net-dnscryptproxy_help {
    echo -e "Usage: net-dnscryptproxy [COMMAND] [profile]\n"
    echo -e "Helper to dnscryptproxy install configurations.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install dnscryptproxy"
    echo "   uninstall   Uninstall installed dnscryptproxy"
    echo "   configgen   Configs Generator"
    echo "   configapply Apply Configs"
    echo "   download    Download pkg files to pkg dir"
    echo "   check       Check vars available"
    echo "   run         run"
}

function __net-dnscryptproxy_install {
    log_debug "Installing ${DMNNAME}..."

    local filepat="./pkgs/dnscrypt-proxy-linux*.tar.gz"
    local tmpdir="/tmp/dnscryptproxy"
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    mkdir -p ${tmpdir} 1>/dev/null 2>&1

    [[ $(find ${filepat}|wc -l) -lt 1 ]] && __net-dnscryptproxy_download 
    tar -zxvf ${filepat} -C ${tmpdir} --strip-components=1 1>/dev/null 2>&1
    if [[ ! -f /tmp/dnscryptproxy/dnscrypt-proxy ]]; then
        log_error "dnscrypt-proxy binary not found in package."
        return 1
    fi
    cp ${tmpdir}/dnscrypt-proxy /usr/sbin/dnscrypt-proxy
    chmod 755 /sbin/dnscrypt-proxy
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    touch /var/log/dnscryptproxy.log

    if ! __net-dnscryptproxy_configgen; then # if gen config is different do apply
        __net-dnscryptproxy_configapply
        rm -rf ${tmpdir}
    fi
}

function __net-dnscryptproxy_configgen { # config generator and diff
    log_debug "Generating config for ${DMNNAME}..."
    rm -rf /tmp/${PKGNAME} 1>/dev/null 2>&1
    mkdir -p /tmp/${PKGNAME} /etc/${PKGNAME} 1>/dev/null 2>&1
    cp ./configs/${PKGNAME}/* /tmp/${PKGNAME}/
    # diff check
    diff -Naur /etc/${PKGNAME} /tmp/${PKGNAME} > /tmp/${PKGNAME}.diff
    [[ $(stat -c %s /tmp/${PKGNAME}.diff) = 0 ]] && return 0 || return 1
}

function __net-dnscryptproxy_configapply {
    [[ ! -f /tmp/${PKGNAME}.diff ]] && log_error "/tmp/${PKGNAME}.diff file doesnt exist. please run configgen."
    log_debug "Applying config ${DMNNAME}..."
    local dtnow=$(date +%Y%m%d_%H%M%S)
    [[ -d "/etc/${PKGNAME}" ]] && cp -rf "/etc/${PKGNAME}" "/etc/.${PKGNAME}.${dtnow}"
    pushd /etc/${PKGNAME} 1>/dev/null 2>&1
    patch -i /tmp/${PKGNAME}.diff
    popd 1>/dev/null 2>&1
    rm /tmp/${PKGNAME}.diff
    return 0
}

function __net-dnscryptproxy_download {
    log_debug "Downloading ${DMNNAME}..."
    _download_github_pkgs DNSCrypt/dnscrypt-proxy dnscrypt-proxy-linux_*.tar.gz || log_error "${DMNNAME} download failed."
    return 0
}

function __net-dnscryptproxy_disable {
    log_debug "Disabling ${DMNNAME}..."
    pidof dnscrypt-proxy | xargs kill -9 2>/dev/null
    return 0
}

function __net-dnscryptproxy_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    pidof dnscrypt-proxy | xargs kill -9 2>/dev/null
    rm -rf /usr/sbin/dnscrypt-proxy
}

function __net-dnscryptproxy_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check package file exists
    [[ $(find ./pkgs/dnscrypt-proxy-linux*|wc -l) -lt 1 ]] && \
        log_info "dnscryptproxy package file does not exist." && [[ $running_status -lt 10 ]] && running_status=10
    # check global variable
    [[ -z ${RUN_NET_DNSCRYPTPROXY} ]] && \
        log_info "RUN_NET_DNSCRYPTPROXY variable is not set." && __net-dnscryptproxy_disable && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_DNSCRYPTPROXY} != 1 ]] && \
        log_info "RUN_NET_DNSCRYPTPROXY is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which dnscrypt-proxy|wc -l) -lt 1 ]] && \
        log_info "dnscryptproxy is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof dnscrypt-proxy) -gt 0 ]] && \
        log_info "dnscryptproxy is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-dnscryptproxy_run {
    log_debug "Running ${DMNNAME}..."
    
    pidof dnscrypt-proxy | xargs kill &>/dev/null
    
    log_debug "Starting dnscrypt-proxy" 
    systemd-run -r dnscrypt-proxy -config /etc/dnscryptproxy/dnscrypt-proxy.toml -logfile /var/log/dnscryptproxy.log
    
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

complete -F _blank net-dnscryptproxy