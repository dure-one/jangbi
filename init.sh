#!/usr/bin/env bash
export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
SCRIPT_FILENAME=$(basename "$self")
cd $(dirname $0)
source functions.sh
echo -e "${ORANGE}" # https://patorjk.com/software/taag/#p=display&f=3D-ASCII&t=JANGBI
echo '    ___  ________  ________   ________  ________  ___     ';
echo '   |\  \|\   __  \|\   ___  \|\   ____\|\   __  \|\  \    ';
echo '   \ \  \ \  \|\  \ \  \\ \  \ \  \___|\ \  \|\ /\ \  \   ';
echo ' __ \ \  \ \   __  \ \  \\ \  \ \  \  __\ \   __  \ \  \  ';
echo '|\  \\_\  \ \  \ \  \ \  \\ \  \ \  \|\  \ \  \|\  \ \  \ ';
echo '\ \________\ \__\ \__\ \__\\ \__\ \_______\ \_______\ \__\';
echo ' \|________|\|__|\|__|\|__| \|__|\|_______|\|_______|\|__|';
echo '                                   https://dure.one/jangbi';
echo -e '                                           ' "${NORMAL}"

usage() {
  #header
  ## shellcheck disable=SC2046
  printf "Usage: %s %s [options]" "${CYAN}" "${SCRIPT_FILENAME}${NORMAL}"
  echo
  echo "  bootstraping scripts for jangbi system"
  echo
  printf "%s\\n" "  ${YELLOW}--help                 |-h${NORMAL}   display this help and exit"
  printf "%s\\n" "  ${YELLOW}--check net-darkstat   |-c${NORMAL}   check single plugin"
  printf "%s\\n" "  ${YELLOW}--launch net-darkstat  |-l${NORMAL}   run single plugin"
  printf "%s\\n" "  ${YELLOW}--sync                 |-s${NORMAL}   sync enabled plugin in config to jangbi-it and exit"
  echo
}

POSITIONAL_ARGS=()
SYNC_AND_BREAK=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --help | -h)
      usage
      exit 0
      ;;
    --check | -c)
      TRPROC=$2
      ${TRPROC} check
      exit ${running_status}
      ;;
    --launch | -l)
      TRPROC=$2
      ${TRPROC} run
      exit 0
      ;;
    --sync | -s)
      SYNC_AND_BREAK=1
      shift
      ;;
    -* | --*)
      printf "%s\\n\\n" "Unrecognized option: $1"
      usage
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# setup slog
LOGFILE=${LOGFILE:="jangbi.log"}
LOG_PATH="$LOGFILE"
RUN_LOG="$LOGFILE"
RUN_ERRORS_FATAL=${RUN_ERRORS_FATAL:=1}
LOG_LEVEL_STDOUT=${LOG_LEVEL_STDOUT:="INFO"}
LOG_LEVEL_LOG=${LOG_LEVEL_LOG:="DEBUG"}

if [[ -z ${JB_DEPLOY_PATH} ]]; then
    _load_config
    _root_only
    _distname_check
else
    log_fatal "JB_DEPLOY_PATH configure is not set. please make .config file."
    return 1
fi

[[ $(which ipcalc-ng|wc -l) -lt 1 ]] && \
    log_info "ipcacl-ng command does not exist. please install it." && exit 1

# printing loaded config && sync .config value to jangbi-it plugin enable
log_debug "Printing Loaded Configs..."
_disable-thing "plugins" "plugin" "all" # disable all plugins for apply configs
prenet=() postnet=()
if [[ ${RUN_OS_SYSTEMD} == 0 || ${RUN_OS_SYSTEMD} == 2 ]]; then # case 0 - disable completely, 2 - only journald
    postnet+=("net-ifupdown")
    _enable-thing "plugins" "plugin" "net-ifupdown" "250"
else # case 1 full systemd
    postnet+=("net-netplan")
    _enable-thing "plugins" "plugin" "net-netplan" "250"
fi
JB_VARS=($(printf "%s\n" "${JB_VARS[@]}" | sort -u))
loaded_vars=$(( set -o posix ; set )|grep -v "^JB_VARS")
IFS=$'\n' read -d "" -ra lvars <<< "${loaded_vars}" # split
for((j=0;j<${#JB_VARS[@]};j++)){
    for((k=0;k<${#lvars[@]};k++)){
        if [[ ${lvars[k]} == *"${JB_VARS[j]}"* ]]; then
            group_txt=""
            if [[ (${JB_VARS[j]} == "RUN_NET"* || ${JB_VARS[j]} == "RUN_OS"*) && ${lvars[k]} == *"=1" ]]; then
                load_plugin=${JB_VARS[j]##RUN_}
                load_plugin=${load_plugin,,}
                load_plugin=${load_plugin//_/-}
                _enable-thing "plugins" "plugin" "${load_plugin}" "250" # enable which is set 1 on config
                group_txt=$(typeset -f -- "${load_plugin}"|metafor group)
                [[ ${group_txt// /} == "postnet" ]] && postnet+=(${load_plugin})
                [[ ${group_txt// /} == "prenet" ]] && prenet+=(${load_plugin})
            fi
            log_debug "${lvars[k]} $group_txt" # log loaded vars
            unset group_txt
            break
        fi
    }
}

[[ ${SYNC_AND_BREAK} == 1 ]] && exit 0
source 'reloader.bash' 'plugin' 'plugins'
log_debug "====="

#####
# add to rclocal
if [[ ${ADDTO_RCLOCAL} -gt 0 ]]; then
    [ ! -f "/etc/rc.local" ] && cp ./configs/rc.local /etc/rc.local
    if [[ $(grep -c "JB_INIT_SCRIPT" < "/etc/rc.local") -lt 1 ]]; then
        log_debug "Installing jangbi init script to rc.local(ADDTO_RCLOCAL)."
        add_cmd="bash ${JB_DEPLOY_PATH}/init.sh # JB_INIT_SCRIPT"
        cp /etc/rc.local /etc/rc.local_"$(date +%Y%m%d%H%M%S).bak"
        sed -i "s|^\(.*\)exit 0|${add_cmd}\nexit 0|" /etc/rc.local
        chmod +x /etc/rc.local
        chmod +x ./init.sh
    fi
else
    log_debug "Removing jangbi init script from rc.local(ADDTO_RCLOCAL)"
    sed -i "s|^\(.*\)# JB_INIT_SCRIPT||" /etc/rc.local
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
    case ${running_status} in # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
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

log_debug "Starting prenet tasks..."
for (( n=0; n<${#prenet[@]}; n++ )); do
    process_each_step "${prenet[n]}" "$(expr $n + 1)/${#prenet[@]}"
done

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

for (( n=0; n<${#postnet[@]}; n++ )); do
    process_each_step "${postnet[n]}" "$(expr $n + 1)/${#postnet[@]}"
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
