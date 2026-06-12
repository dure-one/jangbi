## \brief OmniEdge mesh VPN tool. <div style="text-align: right"> group:**postnet** | runtype:**minmon** | deps: **-** | port: **configurable**</div><br/>
## \desc
## [OmniEdge](https://github.com/omniedgeio/omniedge){:target="_blank"} is a decentralized VPN and SD-WAN solution that creates secure mesh networks.
# It supports edge (client), nucleus (signaling server), and dual (hub+participant) modes.
# OmniEdge operates in L3 mode for IP routing with encrypted signaling.
##
## # Jangbi Configs
## ```bash title="/opt/jangbi/.config"
## RUN_NET_OMNIEDGE=1 # enable omniedge
## OMNIEDGE_MODE="edge" # edge, nucleus, or dual
## OMNIEDGE_NETWORK_ID="" # network ID for edge/dual mode
## OMNIEDGE_PORT="51821" # port for nucleus/dual mode
## OMNIEDGE_SECRET="" # secret for nucleus/dual mode
## OMNIEDGE_ENABLE_RELAY=0 # enable relay fallback (0=off, 1=on)
## ```
## # Check if running
## ```bash title="bash command"
## $ ps aux|grep omniedge
## root     12345  0.0  0.0 123456 12345 ?        S    00:00   0:00 omniedge start -n abc123
## $ pidof omniedge
## 12345
## $ omniedge status
## ```
## # Log files
## OmniEdge logs are stored in `/var/log/omniedge/YYYYMMDDHH.log` with hourly rotation

# shellcheck shell=bash
cite about-plugin
about-plugin 'OmniEdge mesh VPN tool.'

function net-omniedge {
    about 'OmniEdge mesh VPN tool'
    group 'postnet'
    runtype 'minmon'
    deps ''
    param '1: command'
    param '2: params'
    example '$ net-omniedge subcommand'
    local PKGNAME="omniedge"
    local DMNNAME="net-omniedge"
    BASH_IT_LOG_PREFIX="net-omniedge: "
    if _check_config_reload; then
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "help" ]]; then
        __net-omniedge_help "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-omniedge_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-omniedge_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-omniedge_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disable" ]]; then
        __net-omniedge_disable "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-omniedge_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-omniedge_run "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "status" ]]; then
        __net-omniedge_status "$2"
    else
        __net-omniedge_help
    fi
}

## \usage net-omniedge help|install|uninstall|download|disable|check|run|status
## $ net-omniedge install     - install OmniEdge
## $ net-omniedge uninstall   - uninstall OmniEdge
## $ net-omniedge download    - download OmniEdge package files to pkg dir
## $ net-omniedge disable     - disable OmniEdge service
## $ net-omniedge check       - check OmniEdge plugin status
## $ net-omniedge run         - run OmniEdge service
## $ net-omniedge status      - show OmniEdge status and NAT info
## $ net-omniedge help        - show this help message
function __net-omniedge_help {
    echo -e "Usage: net-omniedge [COMMAND]\n"
    echo -e "Helper to OmniEdge mesh VPN tool.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install OmniEdge"
    echo "   uninstall   Uninstall installed OmniEdge"
    echo "   download    Download pkg files to pkg dir"
    echo "   disable     Disable OmniEdge service"
    echo "   check       Check vars available"
    echo "   run         Run OmniEdge service"
    echo "   status      Show OmniEdge status and NAT info"
    echo ""
    echo -e "Configuration (set in .config):\n"
    echo "   OMNIEDGE_MODE          - edge, nucleus, or dual (default: edge)"
    echo "   OMNIEDGE_NETWORK_ID    - network ID for edge/dual mode"
    echo "   OMNIEDGE_PORT          - port for nucleus/dual mode (default: 51821)"
    echo "   OMNIEDGE_SECRET        - secret for nucleus/dual mode"
    echo "   OMNIEDGE_ENABLE_RELAY  - enable relay fallback (default: 0)"
}

function __net-omniedge_install {
    log_debug "Installing ${DMNNAME}..."

    local filepat="./pkgs/omniedge-*-linux-*.tar.gz"
    local tmpdir="/tmp/omniedge"
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    mkdir -p ${tmpdir} 1>/dev/null 2>&1

    [[ $(find ${filepat} 2>/dev/null|wc -l) -lt 1 ]] && __net-omniedge_download
    tar -zxf ${filepat} -C ${tmpdir} 2>/dev/null

    # Find the omniedge binary in extracted files
    # The tarball contains a single binary file named omniedge-cli-*-linux-*
    local omniedge_bin=$(find ${tmpdir} -type f -name "omniedge-cli-*-linux-*" | head -1)
    if [[ ! -f "${omniedge_bin}" ]]; then
        log_error "omniedge binary not found in package."
        return 1
    fi

    # copy to /usr/sbin
    cp "${omniedge_bin}" /usr/sbin/omniedge
    chmod 755 /usr/sbin/omniedge
    rm -rf ${tmpdir} 1>/dev/null 2>&1

    # create log directory
    mkdir -p /var/log/omniedge

    # Configure default settings: disable upnp, ipv6, enable encrypt
    omniedge config portmap off 2>/dev/null || true
    omniedge config ipv6 off 2>/dev/null || true
    omniedge config encrypt on 2>/dev/null || true

    log_debug "OmniEdge installed with defaults: upnp=off, ipv6=off, encrypt=on"
}

function __net-omniedge_download {
    log_debug "Downloading ${DMNNAME}..."
    arch1_=$(dpkg --print-architecture)
    arch1=${3:-${arch1_}}
    # OmniEdge uses 'x64' for amd64/x86_64 and 'arm64' for arm64
    [[ ${arch1} == "amd64" ]] && comparch="x64"
    [[ ${arch1} == "arm64" ]] && comparch="arm64"

    _download_github_pkgs omniedgeio/omniedge omniedge-cli-*-linux-${comparch}.tar.gz "${comparch}" || log_error "${DMNNAME} download failed."
    return 0
}

function __net-omniedge_disable {
    log_debug "Disabling ${DMNNAME}..."
    omniedge stop 2>/dev/null || true
    pidof omniedge | xargs kill -9 2>/dev/null || true
    return 0
}

function __net-omniedge_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    omniedge stop 2>/dev/null || true
    pidof omniedge | xargs kill -9 2>/dev/null || true
    rm -rf /usr/sbin/omniedge
    rm -rf /var/log/omniedge
}

function __net-omniedge_check {
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # check package file exists
    [[ $(find ./pkgs/omniedge-*-linux-*.tar.gz 2>/dev/null|wc -l) -lt 1 ]] && \
        log_info "omniedge package file does not exist." && [[ $running_status -lt 15 ]] && running_status=15
    # check global variable
    [[ -z ${RUN_NET_OMNIEDGE} ]] && \
        log_info "RUN_NET_OMNIEDGE variable is not set." && __net-omniedge_disable && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_OMNIEDGE} != 1 ]] && \
        log_info "RUN_NET_OMNIEDGE is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which omniedge 2>/dev/null|wc -l) -lt 1 ]] && \
        log_info "omniedge is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check mode-specific requirements
    local mode=${OMNIEDGE_MODE:-edge}
    if [[ "$mode" == "edge" ]] || [[ "$mode" == "dual" ]]; then
        [[ -z ${OMNIEDGE_NETWORK_ID} ]] && \
            log_info "OMNIEDGE_NETWORK_ID is required for ${mode} mode." && [[ $running_status -lt 10 ]] && running_status=10
    fi
    # check if running
    [[ -n $(pidof omniedge) ]] && \
        log_info "omniedge is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-omniedge_status {
    log_debug "Checking ${DMNNAME} status..."

    if [[ -x /usr/sbin/omniedge ]]; then
        omniedge status
    else
        log_error "omniedge is not installed"
        return 1
    fi
}

function __net-omniedge_run {
    log_debug "Running ${DMNNAME}..."

    omniedge stop 2>/dev/null || true
    pidof omniedge | xargs kill -9 &>/dev/null

    # Get configuration
    local mode=${OMNIEDGE_MODE:-edge}
    local network_id=${OMNIEDGE_NETWORK_ID:-}
    local port=${OMNIEDGE_PORT:-51821}
    local secret=${OMNIEDGE_SECRET:-}
    local enable_relay=${OMNIEDGE_ENABLE_RELAY:-0}

    log_debug "Starting OmniEdge in ${mode} mode"

    # Build command based on mode
    local cmd="omniedge start"

    case "$mode" in
        edge)
            if [[ -z "$network_id" ]]; then
                log_error "OMNIEDGE_NETWORK_ID is required for edge mode"
                return 1
            fi
            cmd="$cmd -n $network_id --transport-mode l3"
            ;;
        nucleus)
            cmd="$cmd --mode nucleus --port $port --transport-mode l3"
            if [[ -n "$secret" ]]; then
                cmd="$cmd --secret \"$secret\""
            fi
            ;;
        dual)
            if [[ -z "$network_id" ]]; then
                log_error "OMNIEDGE_NETWORK_ID is required for dual mode"
                return 1
            fi
            cmd="$cmd -n $network_id --mode dual --transport-mode l3"
            if [[ -n "$secret" ]]; then
                cmd="$cmd --secret \"$secret\""
            fi
            ;;
        *)
            log_error "Invalid OMNIEDGE_MODE: $mode (must be edge, nucleus, or dual)"
            return 1
            ;;
    esac

    # Optional relay configuration
    if [[ "$enable_relay" == "1" ]]; then
        omniedge config relay on 2>/dev/null || true
    else
        omniedge config relay off 2>/dev/null || true
    fi

    log_debug "Running: $cmd"

    # Run omniedge with hourly log rotation
    (
        while true; do
            # Generate hourly log filename: YYYYMMDDHH.log
            LOGFILE="/var/log/omniedge/$(date +%Y%m%d%H).log"

            # Calculate seconds until next hour
            CURRENT_MIN=$(date +%M)
            CURRENT_SEC=$(date +%S)
            SECONDS_TO_NEXT_HOUR=$((3600 - CURRENT_MIN * 60 - CURRENT_SEC))

            # Run omniedge with timeout for this hour, redirect to hourly log
            eval "timeout ${SECONDS_TO_NEXT_HOUR}s $cmd >> \"${LOGFILE}\" 2>&1"

            # If omniedge exits with non-timeout error, restart after 1 second
            EXIT_CODE=$?
            if [ ${EXIT_CODE} -ne 0 ] && [ ${EXIT_CODE} -ne 124 ]; then
                echo "$(date): omniedge exited with code ${EXIT_CODE}, restarting..." >> "${LOGFILE}"
                log_error "omniedge exited unexpectedly with code ${EXIT_CODE}, restarting..."
                sleep 1
            fi
        done
    ) &

    sleep 2
    pidof omniedge && return 0 || \
        log_error "omniedge failed to run." && return 0
}

complete -F _blank net-omniedge
