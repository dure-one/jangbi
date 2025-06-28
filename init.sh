#!/usr/bin/env bash
# init.sh - bootstraping scripts for dure system
export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
cd $(dirname $0)
source functions.sh
echo -e "${ORANGE}" # https://www.avonture.be/blog/bash-ascii-art/
echo '   |\  \|\   __  \|\   ___  \|\   ____\|\   __  \|\  \                                    ';
echo '   \ \  \ \  \|\  \ \  \\ \  \ \  \___|\ \  \|\ /\ \  \                                   ';
echo ' __ \ \  \ \   __  \ \  \\ \  \ \  \  __\ \   __  \ \  \                                  ';
echo '|\  \\_\  \ \  \ \  \ \  \\ \  \ \  \|\  \ \  \|\  \ \  \                                 ';
echo '\ \________\ \__\ \__\ \__\\ \__\ \_______\ \_______\ \__\                                ';
echo ' \|________|\|__|\|__|\|__| \|__|\|_______|\|_______|\|__|                                ';
echo '                                   https://dure.one/jangbi  ';
echo -e '                                                       ' "${NORMAL}"

# setup slog
LOGFILE=${LOGFILE:="jangbi.log"}
LOG_PATH="$LOGFILE"
RUN_LOG="$LOGFILE"
RUN_ERRORS_FATAL=${RUN_ERRORS_FATAL:=1}
LOG_LEVEL_STDOUT=${LOG_LEVEL_STDOUT:="INFO"}
LOG_LEVEL_LOG=${LOG_LEVEL_LOG:="DEBUG"}

if [[ -z ${DURE_DEPLOY_PATH} ]]; then
    _load_config
    _root_only
    _distname_check
else
    log_fatal "DURE_DEPLOY_PATH configure is not set. please make .config file."
    return 1
fi

[[ $(which ipcalc-ng|wc -l) -lt 1 ]] && \
    log_info "ipcacl-ng command does not exist. please install it." && exit 1

log_debug "Printing Loaded Configs..."
_disable-thing "plugins" "plugin" "all" # disable all plugins for apply configs
prenet=() postnet=()
DURE_VARS=($(printf "%s\n" "${DURE_VARS[@]}" | sort -u))
loaded_vars=$(( set -o posix ; set )|grep -v "^DURE_VARS")
IFS=$'\n' read -d "" -ra lvars <<< "${loaded_vars}" # split
for((j=0;j<${#DURE_VARS[@]};j++)){
    for((k=0;k<${#lvars[@]};k++)){
        if [[ ${lvars[k]} == *"${DURE_VARS[j]}"* ]]; then
            log_debug "${lvars[k]}"
            if [[ (${DURE_VARS[j]} == "RUN_NET"* || ${DURE_VARS[j]} == "RUN_OS"*) && ${lvars[k]} == *"=1" ]]; then
                load_plugin=${DURE_VARS[j]##RUN_}
                load_plugin=${load_plugin,,}
                load_plugin=${load_plugin//_/-}
                _enable-thing "plugins" "plugin" "${load_plugin}" "250" # enable which is set 1 on config
            fi
            break
        fi
    }
}
log_debug "=========================="

if [[ ${ADDTO_RCLOCAL} -gt 0 ]]; then
    if [[ $(grep -c "DURE_INIT_SCRIPT" < "/etc/rc.local") -lt 1 ]]; then
        log_debug "Installing jangbi init script to rc.local(ADDTO_RCLOCAL)."
        add_cmd="bash ${DURE_DEPLOY_PATH}/init.sh # DURE_INIT_SCRIPT"
        cp /etc/rc.local /etc/rc.local."$(date +%Y%m%d%H%M%S)".bak
        sed -i "s|^\(.*\)exit 0|${add_cmd}\nexit 0|" /etc/rc.local
        chmod +x /etc/rc.local
        chmod +x ./init.sh
    fi
else
    log_debug "Removing jangbi init script from rc.local(ADDTO_RCLOCAL)"
    sed -i "s|^\(.*\)# DURE_INIT_SCRIPT||" /etc/rc.local
fi

# block forwarding
log_debug "Block forwarding on kernel during installation."
echo "0" > /proc/sys/net/ipv4/ip_forward

process_each_step() {
    local command="$1"
    local step="$2"
    local running_status=0
    run_ok "${command} check" "${command}(${step}) Checking..."
    [[ ${FORCE_INSTALL} == 1 ]] && log_info "FORCE_INSTALL enabled, Override to install." && running_status=5
    log_debug "${step} Check Result : ${running_status}"
    case ${running_status} in # running_status 0 installed, running_status 5 can install, running_status 10 can't install
        5)
            run_ok "${command} install" "${command}(${step}) Installing..."
            log_debug "$!"
            run_ok "${command} run" "${command}(${step}) Running..."
            log_debug "$!"
        ;;
        0)
            run_ok "${command} run" "${command}(${step}) Running..."
            log_debug "$!"
        ;; # nothing to do
        10)
            log_fatal "Something went wrong. Exiting."
            exit 1
        ;;
        20)
            log_info "${command}(${step}) Skiped..."
            log_debug "$!"
        ;;
    esac
}

log_debug "Starting tasks."
processes=("os-sysctl" "os-kparams" "os-repos" "os-systemd" "os-disablebins" "os-conf" "os-auditd" "os-crond" "os-aide")
for (( n=0; n<${#processes[@]}; n++ )); do
    process_each_step "${processes[n]}" "$(expr $n + 1)/${#processes[@]}"
done
processes=()

# disable ipv6 from sysctl
if [[ ${DISABLE_IPV6} -gt 0 ]]; then # disable ipv6
    log_debug "Disable IPv6"
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 &>/dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 &>/dev/null
else # enable ipv6
    log_debug "Enable IPv6"
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 &>/dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 &>/dev/null
fi

if [[ ${RUN_OS_SYSTEMD} == 0 || ${RUN_OS_SYSTEMD} == 2 ]]; then # case 0 - disable completely, 2 - only journald
    processes=("net-ifupdown")
else # case 0 full systemd
    processes=("net-netplan")
fi

processes+=("net-iptables" "net-knockd" "net-dnsmasq" "net-hostapd" "net-sshd" "net-darkstat") # misc-step os-falco os-sysdig # todo
for (( n=0; n<${#processes[@]}; n++ )); do
    process_each_step "${processes[n]}" "$(expr $n + 1)/${#processes[@]}"
done

# check network
INTERNET_AVAIL=0
if [[ -z $(curl google.com 2>/dev/null|grep 301\ Moved) ]]; then
    log_error "not connected. please check network settings"
    exit 1
else
    # set date and add to crontab
    log_debug "Trying to sync time with DNS Server ${DNS_UPSTREAM}"
    _time_sync "${DNS_UPSTREAM}"
    INTERNET_AVAIL=1
fi

# allow forwarding when gateway
# echo "1" > /proc/sys/net/ipv4/ip_forward

# disable offline repository
#if [[ ${RUN_OS_REPOS} -gt 0 ]]; then
#    umount /opt/jangbi/imgs/debian
#fi
