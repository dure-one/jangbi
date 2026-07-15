## \brief wactws network monitoring tool. <div style="text-align: right"> group:**postnet** | runtype:**minmon** | deps: **-** | port: **-**</div><br/>
## \desc
## [wactws](https://github.com/nikescar/wactws){:target="_blank"} is a CLI utility for displaying current network utilization by process, connection and remote IP/hostname.
# It provides real-time network bandwidth monitoring and logging capabilities with company-based traffic analysis.
# wactws offers detailed network statistics for monitoring and troubleshooting network activity.
##
## # Jangbi Configs
## ```bash title="/opt/jangbi/.config"
## RUN_NET_WACTWS=1 # enable wactws monitoring
## NETWORK_INTERFACE="eth0" # network interface to monitor (default: auto-detect)
## ```
## # Check if running
## ```bash title="bash command"
## $ ps aux|grep wactws
## root     12345  0.0  0.0 123456 12345 ?        S    00:00   0:00 wactws -m by-company --log-mode
## $ pidof wactws
## 12345
## ```
## # Log files
## Network traffic logs are stored in `/var/log/wactws/YYYYMMDDHH.log` with hourly rotation
## Example: `/var/log/wactws/2026061203.log` for June 12, 2026, 3:00 AM

# shellcheck shell=bash
cite about-plugin
about-plugin 'wactws network monitoring tool.'

function net-wactws {
    about 'wactws network monitoring tool'
    group 'postnet'
    runtype 'minmon'
    deps ''
    param '1: command'
    param '2: params'
    example '$ net-wactws subcommand'
    local PKGNAME="wactws"
    local DMNNAME="net-wactws"
    BASH_IT_LOG_PREFIX="net-wactws: "
    if _check_config_reload; then
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "help" ]]; then
        __net-wactws_help "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-wactws_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-wactws_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __net-wactws_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disable" ]]; then
        __net-wactws_disable "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-wactws_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-wactws_run "$2"
    else
        __net-wactws_help
    fi
}

## \usage net-wactws help|install|uninstall|download|disable|check|run
## $ net-wactws install - install wactws network monitoring tool
## $ net-wactws uninstall - uninstall wactws
## $ net-wactws download - download wactws package files to pkg dir
## $ net-wactws disable - disable wactws plugin
## $ net-wactws check - check wactws plugin status
## $ net-wactws run - run wactws monitoring service
## $ net-wactws help - show this help message
function __net-wactws_help {
    echo -e "Usage: net-wactws [COMMAND]\n"
    echo -e "Helper to wactws network monitoring tool.\n"
    echo -e "Commands:\n"
    echo "   help        Show this help message"
    echo "   install     Install wactws"
    echo "   uninstall   Uninstall installed wactws"
    echo "   download    Download pkg files to pkg dir"
    echo "   disable     Disable wactws service"
    echo "   check       Check vars available"
    echo "   run         run"
}

function __net-wactws_install {
    log_debug "Installing ${DMNNAME}..."

    local filepat="./pkgs/wactws-*-unknown-linux-musl.tar.gz"
    local tmpdir="/tmp/wactws"
    rm -rf ${tmpdir} 1>/dev/null 2>&1
    mkdir -p ${tmpdir} 1>/dev/null 2>&1

    [[ $(find ${filepat} 2>/dev/null|wc -l) -lt 1 ]] && __net-wactws_download
    tar -zxf ${filepat} -C ${tmpdir} 2>/dev/null
    if [[ ! -f /tmp/wactws/wactws ]]; then
        log_error "wactws binary not found in package."
        return 1
    fi

    # copy to /usr/sbin
    cp ${tmpdir}/wactws /usr/sbin/wactws
    chmod 755 /usr/sbin/wactws
    rm -rf ${tmpdir} 1>/dev/null 2>&1

    # create log directory
    mkdir -p /var/log/wactws
    touch /var/log/wactws/wactws.log
}

function __net-wactws_download {
    log_debug "Downloading ${DMNNAME}..."
    arch1_=$(dpkg --print-architecture)
    arch1=${3:-${arch1_}}
    [[ ${arch1} == "amd64" ]] && comparch="x86_64"
    [[ ${arch1} == "arm64" ]] && comparch="aarch64"

    _download_github_pkgs nikescar/wactws wactws-*-unknown-linux-musl.tar.gz "${comparch}" || log_error "${DMNNAME} download failed."
    return 0
}

function __net-wactws_disable {
    log_debug "Disabling ${DMNNAME}..."

    local PIDFILE="/var/run/wactws-monitor.pid"

    # Kill the monitoring loop by its unique process name
    pkill -9 -f "wactws-monitor-loop" &>/dev/null || true

    # Find and kill all bash subshells running the wactws monitoring loop
    for timeout_pid in $(pgrep -f "timeout.*wactws -m by-company"); do
        parent_pid=$(ps -o ppid= -p ${timeout_pid} 2>/dev/null | tr -d ' ')
        if [ -n "${parent_pid}" ] && [ "${parent_pid}" != "1" ]; then
            kill -9 ${parent_pid} &>/dev/null || true
        fi
    done

    # Kill all wactws and timeout processes
    pkill -9 -f "timeout.*wactws" &>/dev/null || true
    pkill -9 -f "wactws -m by-company" &>/dev/null || true
    pkill -9 wactws &>/dev/null || true

    # Clean up PID file
    rm -f "${PIDFILE}"

    return 0
}

function __net-wactws_uninstall {
    log_debug "Uninstalling ${DMNNAME}..."
    pidof wactws | xargs kill -9 2>/dev/null
    rm -rf /usr/sbin/wactws
}

function __net-wactws_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_check_ok "Checking ${DMNNAME}..."

    # check package file exists
    [[ $(find ./pkgs/wactws-*-unknown-linux-musl.tar.gz 2>/dev/null|wc -l) -lt 1 ]] && \
        log_check "wactws package file does not exist." && [[ $running_status -lt 15 ]] && running_status=15
    # check global variable
    [[ -z ${RUN_NET_WACTWS} ]] && \
        log_check "RUN_NET_WACTWS variable is not set." && __net-wactws_disable && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_WACTWS} != 1 ]] && \
        log_check "RUN_NET_WACTWS is not enabled." && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which wactws 2>/dev/null|wc -l) -lt 1 ]] && \
        log_check "wactws is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ -n $(pidof wactws) ]] && \
        log_check_ok "wactws is running." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-wactws_run {
    log_debug "Running ${DMNNAME}..."

    local PIDFILE="/var/run/wactws-monitor.pid"

    # Step 1: Find and kill all bash subshells running the wactws monitoring loop
    # These are the parent processes of "timeout...wactws" commands
    for timeout_pid in $(pgrep -f "timeout.*wactws -m by-company"); do
        parent_pid=$(ps -o ppid= -p ${timeout_pid} 2>/dev/null | tr -d ' ')
        if [ -n "${parent_pid}" ] && [ "${parent_pid}" != "1" ]; then
            kill -9 ${parent_pid} &>/dev/null || true
        fi
    done

    # Step 2: Kill all wactws and timeout processes
    pkill -9 -f "timeout.*wactws" &>/dev/null || true
    pkill -9 -f "wactws -m by-company" &>/dev/null || true
    pkill -9 wactws &>/dev/null || true

    # Step 3: Clean up PID file
    rm -f "${PIDFILE}"

    # Wait to ensure all processes are fully terminated
    sleep 1

    log_debug "Starting wactws monitoring with by-company mode"

    # Run wactws with hourly log rotation in a subshell
    (
        # Mark this process with a unique identifier
        exec -a "wactws-monitor-loop" bash -c '
            echo $$ > /var/run/wactws-monitor.pid

            while true; do
                # Generate hourly log filename: YYYYMMDDHH.log
                LOGFILE="/var/log/wactws/$(date +%Y%m%d%H).log"

                # Calculate seconds until next hour
                CURRENT_MIN=$(date +%M)
                CURRENT_SEC=$(date +%S)
                SECONDS_TO_NEXT_HOUR=$((3600 - CURRENT_MIN * 60 - CURRENT_SEC))

                # Run wactws with timeout for this hour, redirect to hourly log
                timeout ${SECONDS_TO_NEXT_HOUR}s wactws -m by-company --log-mode >> "${LOGFILE}" 2>&1

                # If wactws exits with non-timeout error, restart after 1 second
                EXIT_CODE=$?
                if [ ${EXIT_CODE} -ne 0 ] && [ ${EXIT_CODE} -ne 124 ]; then
                    echo "ERROR: wactws exited unexpectedly with code ${EXIT_CODE}, restarting..." >&2
                    sleep 1
                fi
            done
        '
    ) &

    sleep 1
    pidof wactws && return 0 || \
        log_error "wactws failed to run." && return 0
}

complete -F _blank net-wactws
