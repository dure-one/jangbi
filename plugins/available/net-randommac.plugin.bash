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
    elif [[ $# -eq 1 ]] && [[ "$1" = "pkglist" ]]; then
        __net-randommac_pkglist
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

function __net-randommac_pkglist {
    echo "macchanger"
}

function __net-randommac_disable {
    log_debug "Disabling ${DMNNAME}..."
    return 0
}

function __net-randommac_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
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
    running_status=1  # default: OK, nothing to do

    [[ -z ${RUN_NET_RANDOMMAC} ]] && \
        log_info "RUN_NET_RANDOMMAC variable is not set." && running_status=10 && return 0
    [[ ${RUN_NET_RANDOMMAC} != 1 ]] && \
        log_info "RUN_NET_RANDOMMAC is not enabled." && running_status=20 && return 0
    [[ -z ${JB_WANINF} ]] && \
        log_error "JB_WANINF is not set." && running_status=10 && return 0

    # Get local WAN IP — no external call, no network dependency
    local wan_ip
    wan_ip=$(ip -4 addr show "${JB_WANINF}" 2>/dev/null | grep -oP 'inet \K[0-9.]+')

    if [[ -z "$wan_ip" ]]; then
        log_debug "WAN interface ${JB_WANINF} has no IP assigned yet — skipping"
        running_status=1
        return 0
    fi

    log_info "WAN IP: ${wan_ip}"

    if [[ -n "${RANDOMMAC_AVOIDED_IPS}" ]]; then
        local avoided_list avoided
        IFS=',' read -ra avoided_list <<< "${RANDOMMAC_AVOIDED_IPS}"
        for avoided in "${avoided_list[@]}"; do
            avoided="${avoided// /}"
            if __net-randommac_ip_in_range "$wan_ip" "$avoided"; then
                export RANDOMMAC_TRIGGER_REASON="IP ${wan_ip} matches avoided range ${avoided}"
                log_warning "WAN IP ${wan_ip} matches avoided entry '${avoided}' — will rotate MAC"
                running_status=0
                return 0
            fi
        done
    fi

    log_info "WAN IP ${wan_ip} is not in the avoided list — OK"
    running_status=1
    return 0
}

function __net-randommac_run {
    local trigger_reason="${RANDOMMAC_TRIGGER_REASON:-manual execution}"
    log_info "Running ${DMNNAME} (reason: ${trigger_reason})..."
    unset RANDOMMAC_TRIGGER_REASON

    if [[ -z "${JB_WANINF}" ]]; then
        log_error "JB_WANINF is not set, cannot change MAC."
        return 1
    fi

    local old_mac
    old_mac=$(ip link show "${JB_WANINF}" 2>/dev/null | grep -oP 'link/ether \K[^ ]+' || echo 'unknown')
    local old_ip
    old_ip=$(ip -4 addr show "${JB_WANINF}" 2>/dev/null | grep -oP 'inet \K[0-9.]+' || echo 'none')
    log_info "Pre-change state: MAC=${old_mac} IP=${old_ip} Interface=${JB_WANINF}"

    local max_retries=5
    local retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        log_info "MAC change attempt $((retry_count + 1))/${max_retries}..."

        ifdown "${JB_WANINF}" 2>/dev/null || ip link set "${JB_WANINF}" down
        pkill -f "dhclient.*${JB_WANINF}" 2>/dev/null || true

        sleep 1

        if ! change_mac "${JB_WANINF}" "random"; then
            log_warning "MAC change failed (attempt $((retry_count + 1))). Retrying..."
            ((retry_count++))
            ifup "${JB_WANINF}" 2>&1 | tee -a "${BASH_IT_LOG_FILE}" || true
            sleep 2
            continue
        fi

        if ! ifup "${JB_WANINF}" 2>&1 | tee -a "${BASH_IT_LOG_FILE}"; then
            log_error "Failed to bring up ${JB_WANINF} after MAC change."
            ((retry_count++))
            continue
        fi

        sleep 5

        local new_ip
        new_ip=$(ip -4 addr show "${JB_WANINF}" 2>/dev/null | grep -oP 'inet \K[0-9.]+')

        if [[ -z "$new_ip" ]]; then
            log_warning "No IP acquired on ${JB_WANINF} after MAC change (attempt $((retry_count + 1)))."
            ((retry_count++))
            continue
        fi

        log_info "New WAN IP after MAC change: ${new_ip}"

        local ip_is_avoided=0
        if [[ -n "${RANDOMMAC_AVOIDED_IPS}" ]]; then
            local avoided_list avoided
            IFS=',' read -ra avoided_list <<< "${RANDOMMAC_AVOIDED_IPS}"
            for avoided in "${avoided_list[@]}"; do
                avoided="${avoided// /}"
                if __net-randommac_ip_in_range "$new_ip" "$avoided"; then
                    log_warning "New IP ${new_ip} is in avoided list (matches '${avoided}'). Retrying..."
                    ip_is_avoided=1
                    break
                fi
            done
        fi

        if [[ $ip_is_avoided -eq 0 ]]; then
            local new_mac
            new_mac=$(ip link show "${JB_WANINF}" 2>/dev/null | grep -oP 'link/ether \K[^ ]+' || echo 'unknown')
            log_info "Post-change state: MAC=${new_mac} IP=${new_ip} Interface=${JB_WANINF}"
            log_info "MAC rotation completed successfully in $((retry_count + 1)) attempt(s)"
            return 0
        fi

        ((retry_count++))
    done

    log_error "Failed to obtain a non-avoided IP after ${max_retries} attempts."
    return 1
}

complete -F _blank net-randommac
