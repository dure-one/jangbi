## \brief Random MAC address changer for WAN interface. <div style="text-align: right"> group:**postnet** | runtype:**minmon** | deps: **net-ifupdown** | port: **-**</div><br/>
## \desc
## Monitors WAN external IP via icanhazip.com and changes the WAN MAC address
## if the current IP is in the configured avoided list, then restarts ifupdown to acquire a new IP.
## Internet connectivity is also verified on every check cycle.
##
## # Jangbi Configs
## ```bash title="/opt/jangbi/.config"
## RUN_NET_RANDOMMAC=1                          # enable random MAC changer
## RANDOMMAC_AVOIDED_IPS="1.2.3.4,5.6.0.0/16"  # comma-separated IPs/CIDRs to avoid
## RANDOMMAC_CHECK_INTERVAL=300                 # seconds between external IP checks (default: 300)
## ```
## # Check if running
## ```bash title="bash command"
## $ curl -s https://icanhazip.com
## 203.0.113.42
## $ cat /var/run/net-randommac.lastcheck
## 1719456000
## ```
## # Log files
## Status is written to the main jangbi output.log

# shellcheck shell=bash
cite about-plugin
about-plugin 'random MAC address changer for WAN interface.'

function net-randommac {
    about 'random MAC address changer for WAN interface'
    group 'postnet'
    runtype 'minmon'
    deps 'net-ifupdown'
    param '1: command'
    param '2: params'
    example '$ net-randommac subcommand'
    local PKGNAME="randommac"
    local DMNNAME="net-randommac"
    BASH_IT_LOG_PREFIX="net-randommac: "
    if _check_config_reload; then
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "help" ]]; then
        __net-randommac_help "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-randommac_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-randommac_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-randommac_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disable" ]]; then
        __net-randommac_disable "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-randommac_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-randommac_run "$2"
    else
        __net-randommac_help
    fi
}

## \usage net-randommac help|install|uninstall|download|disable|check|run
## $ net-randommac install - install dependencies for random MAC changer
## $ net-randommac uninstall - uninstall random MAC changer
## $ net-randommac download - download package files to pkg dir
## $ net-randommac disable - disable random MAC changer plugin
## $ net-randommac check - check plugin status and external IP
## $ net-randommac run - change WAN MAC address and restart networking
## $ net-randommac help - show this help message
function __net-randommac_help {
    echo -e "Usage: net-randommac [COMMAND]\n"
    echo -e "Random MAC address changer for WAN interface.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install dependencies (macchanger)"
    echo "   uninstall   Uninstall random MAC changer"
    echo "   download    Download pkg files to pkg dir"
    echo "   disable     Disable plugin"
    echo "   check       Check external IP against avoided list"
    echo "   run         Change WAN MAC to random and restart networking"
}

function __net-randommac_install {
    log_debug "Installing ${DMNNAME}..."
    if ! command -v macchanger &>/dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt install -qy macchanger || log_error "${DMNNAME} macchanger install failed."
    fi
    return 0
}

function __net-randommac_download {
    log_debug "Downloading ${DMNNAME}..."
    # macchanger is an apt package; no pre-downloaded binary needed
    return 0
}

function __net-randommac_disable {
    log_debug "Disabling ${DMNNAME}..."
    rm -f /var/run/net-randommac.lastcheck
    return 0
}

function __net-randommac_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    rm -f /var/run/net-randommac.lastcheck
    return 0
}

# Returns 0 if $1 (IP) falls within $2 (IP, CIDR, or prefix string).
function __net-randommac_ip_in_range {
    local ip="$1" range="$2"

    # Exact IP match
    [[ "$ip" == "$range" ]] && return 0

    if [[ "$range" == *"/"* ]]; then
        local net_ip mask_bits a b c d ip_int net_int mask
        net_ip=$(echo "$range" | cut -d'/' -f1)
        mask_bits=$(echo "$range" | cut -d'/' -f2)

        IFS='.' read -r a b c d <<< "$ip"
        ip_int=$(( (a<<24) + (b<<16) + (c<<8) + d ))
        IFS='.' read -r a b c d <<< "$net_ip"
        net_int=$(( (a<<24) + (b<<16) + (c<<8) + d ))
        mask=$(( ( 0xFFFFFFFF << (32 - mask_bits) ) & 0xFFFFFFFF ))

        [[ $(( ip_int & mask )) -eq $(( net_int & mask )) ]] && return 0
        return 1
    fi

    # Prefix string match (e.g. "203.0.113." matches "203.0.113.42")
    [[ "$ip" == "${range}"* ]] && return 0

    return 1
}

function __net-randommac_check {
    running_status=0
    log_debug "Checking ${DMNNAME}..."

    # Check config variable present
    [[ -z ${RUN_NET_RANDOMMAC} ]] && \
        log_info "RUN_NET_RANDOMMAC variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_RANDOMMAC} != 1 ]] && \
        log_info "RUN_NET_RANDOMMAC is not enabled." && [[ $running_status -lt 20 ]] && running_status=20

    # Check required interface variable
    [[ -z ${JB_WANINF} ]] && \
        log_error "JB_WANINF is not set." && [[ $running_status -lt 10 ]] && running_status=10

    # Stop here if misconfigured or disabled
    [[ $running_status -ge 10 ]] && return 0

    # Rate-limit external IP checks to avoid hammering icanhazip.com
    local lockfile="/var/run/net-randommac.lastcheck"
    local interval="${RANDOMMAC_CHECK_INTERVAL:-300}"
    if [[ -f "$lockfile" ]]; then
        local last_check now
        last_check=$(cat "$lockfile" 2>/dev/null)
        now=$(date +%s)
        if [[ -n "$last_check" ]] && [[ $(( now - last_check )) -lt $interval ]]; then
            log_info "Last check was less than ${interval}s ago, IP assumed clean."
            running_status=1
            return 0
        fi
    fi

    # Verify internet connectivity and get external IP in one request
    local ext_ip
    ext_ip=$(curl -s --max-time 10 -4 https://icanhazip.com 2>/dev/null | xargs)

    if [[ -z "$ext_ip" ]]; then
        log_warning "Internet not reachable or icanhazip.com unavailable — will trigger MAC rotation."
        running_status=0
        return 0
    fi
    log_info "External IP: ${ext_ip}"

    # Record the timestamp of this successful check
    date +%s > "$lockfile"

    # Check external IP against avoided list
    if [[ -n "${RANDOMMAC_AVOIDED_IPS}" ]]; then
        local avoided_list avoided
        IFS=',' read -ra avoided_list <<< "${RANDOMMAC_AVOIDED_IPS}"
        for avoided in "${avoided_list[@]}"; do
            avoided="${avoided// /}"  # strip whitespace
            if __net-randommac_ip_in_range "$ext_ip" "$avoided"; then
                log_warning "External IP ${ext_ip} matches avoided entry '${avoided}' — will rotate MAC."
                # Clear timestamp so next check re-verifies after rotation
                rm -f "$lockfile"
                running_status=0
                return 0
            fi
        done
    fi

    log_info "External IP ${ext_ip} is not in the avoided list — OK."
    running_status=1
    return 0
}

function __net-randommac_run {
    log_debug "Running ${DMNNAME}..."

    if [[ -z "${JB_WANINF}" ]]; then
        log_error "JB_WANINF is not set, cannot change MAC."
        return 1
    fi

    # Bring WAN interface down
    ifdown "${JB_WANINF}" 2>/dev/null || ip link set "${JB_WANINF}" down

    # Randomize MAC address
    change_mac "${JB_WANINF}" "random"

    # Clear last-check timestamp so the next cycle re-verifies the new IP
    rm -f /var/run/net-randommac.lastcheck

    # Bring WAN interface back up to acquire a new DHCP lease with the new MAC
    if ifup "${JB_WANINF}" 2>&1 | tee -a "${BASH_IT_LOG_FILE}"; then
        log_info "WAN interface ${JB_WANINF} restarted with new MAC address."
        return 0
    else
        log_error "Failed to bring up ${JB_WANINF} after MAC change."
        return 1
    fi
}

complete -F _blank net-randommac
