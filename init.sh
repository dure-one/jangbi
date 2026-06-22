#!/usr/bin/env bash
export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
export HOME=${HOME:-/root} # ensure HOME is set when invoked from rc.local (systemd SetLoginEnvironment=no)
cd $(dirname $0)
source jangbi_it.sh
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
  printf "Usage: %s %s [options]" "${CYAN}" "$(basename "${BASH_SOURCE[0]}")${NORMAL}"
  echo
  echo "  bootstraping scripts for jangbi system"
  echo
  printf "%s\\n" "  ${YELLOW}--help                          |-h${NORMAL}   display this help and exit"
  printf "%s\\n" "  ${YELLOW}--check enabled|net-darkstat    |-c${NORMAL}   check enabled|single plugin"
  printf "%s\\n" "  ${YELLOW}--launch enabled|net-darkstat   |-l${NORMAL}   run enabled|single plugin"
  printf "%s\\n" "  ${YELLOW}--sync                          |-s${NORMAL}   sync janbit config to plugin"
  printf "%s\\n" "  ${YELLOW}--download enabled|net-darkstat |-d${NORMAL}   download enabled|single plugin pkgs"
  printf "%s\\n" "  ${YELLOW}--install enabled|net-darkstat  |-i${NORMAL}   install enabled|single plugin pkgs"
  printf "%s\\n" "  ${YELLOW}--doctor                        |-t${NORMAL}   doctor network issues"
  echo
}
# setup log
BASH_IT_LOG_LEVEL=5 # 0 - no log, 1 - fatal, 3 - error, 4 - warning, 5 - debug, 6 - info, 6 - all, 7 - trace,
BASH_IT_LOG_FILE="${BASH_IT_LOG_FILE:-${JANGBI_IT}/output.log}"

if _check_config_reload; then
    _root_only || exit 1
    _distname_check || exit 1
else
    log_fatal "JB_DEPLOY_PATH configure is not set. please make .config file."
    exit 1
fi

POSITIONAL_ARGS=()
SYNC_AND_BREAK=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --help | -h)
      usage
      exit 0
      ;;
    --check | -c)
      CH_OPTION="$2"
      shift
      shift
      ;;
    --launch | -l)
      RN_OPTION="$2"
      shift
      shift
      ;;
    --sync | -s)
      SYNC_AND_BREAK=1
      shift
      ;;
    --download | -d)
      DN_OPTION="$2"
      shift
      shift
      ;;
    --install | -i)
      IN_OPTION="$2"
      shift
      shift
      ;;
    --doctor | -t)
      # doctor network issues
      log_info "Running network doctor..."
      if _check_network; then
          log_info "Network looks good."
      else
          log_error "Network issues detected. Please check your configuration."
      fi
      exit 0
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

# pkgs imgs preparations
[[ ! -d ./pkgs ]] && mkdir -p ./pkgs
[[ ! -d ./imgs ]] && mkdir -p ./imgs
[[ ! -d ./enabled ]] && mkdir -p ./enabled

# install required packages
required_pkgs=("curl" "wget" "unzip" "patch" "ipcalc-ng" "git" "extrepo" "ipset" "iproute2")
missing_pkgs=()
for pkg in "${required_pkgs[@]}"; do
    if ! dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii"; then
        missing_pkgs+=("${pkg}")
    fi
done
if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    log_debug "Installing missing packages: ${missing_pkgs[*]}"
    apt install -qy "${missing_pkgs[@]}" > /dev/null 2>&1
else
    log_debug "All required packages are already installed."
fi
# remove debian official repository for security reason
rm -rf /etc/apt/sources.list.d/extrepo_debian_official.sources

# install jq binary
if [[ -x /usr/sbin/jq ]]; then
    log_debug "jq binary already exists at /usr/sbin/jq. Skipping download."
else
    log_debug "jq binary not found. Downloading..."
    arch1_=$(dpkg --print-architecture)
    arch1=${3:-${arch1_}}
    [[ ${arch1} == "amd64" ]] && comparch="-64-"
    [[ ${arch1} == "arm64" ]] && comparch="-arm64-v8a-"

    # Try to download jq
    if _download_github_pkgs jqlang/jq jq-linux-* "${arch1}" > /dev/null 2>&1; then
        # Find the downloaded jq file and copy it
        jq_file=$(find ${JANGBI_IT}/pkgs -name "jq-linux-*${arch1}*" -type f 2>/dev/null | head -1)
        if [[ -n "${jq_file}" ]]; then
            cp "${jq_file}" /usr/sbin/jq
            chmod +x /usr/sbin/jq
            log_debug "jq binary installed successfully."
        else
            log_error "jq binary file not found after download."
        fi
    else
        # Download failed - try installing from package manager as fallback
        log_warning "jq download from GitHub failed (possibly rate limited). Trying apt install..."
        if apt install -qy jq > /dev/null 2>&1; then
            log_debug "jq installed from apt repository."
        else
            log_error "Failed to install jq from both GitHub and apt. Some features may not work."
        fi
    fi
fi

# printing loaded config && sync .config value to jangbi-it plugin enable
# Save config to .config.last instead of printing to log
rm ./enabled/* 2>/dev/null # remove all enabled plugins
prenet=("os-systemd") prenetdeps=() postnet=() postnetdeps=() processed=()
ln -s "../plugins/available/os-systemd.plugin.bash" "./enabled/250---os-systemd.plugin.bash" 2>/dev/null
plugin_file=$(find ./enabled -type l -name "*os-systemd.plugin.bash" 2>/dev/null | head -1)
[[ -n "${plugin_file}" && -f "${plugin_file}" ]] && source "${plugin_file}" # load plugin
if [[ ${RUN_OS_SYSTEMD} == 0 || ${RUN_OS_SYSTEMD} == 2 ]]; then # case 0 - disable completely, 2 - only journald
    postnet+=("net-ifupdown" "net-iptables")
    ln -s "../plugins/available/net-ifupdown.plugin.bash" "./enabled/250---net-ifupdown.plugin.bash" 2>/dev/null
    plugin_file=$(find ./enabled -type l -name "*net-ifupdown.plugin.bash" 2>/dev/null | head -1)
    [[ -n "${plugin_file}" && -f "${plugin_file}" ]] && source "${plugin_file}" # load plugin
else # case 1 full systemd
    postnet+=("net-netplan" "net-iptables")
    ln -s "../plugins/available/net-netplan.plugin.bash" "./enabled/250---net-netplan.plugin.bash" 2>/dev/null
    plugin_file=$(find ./enabled -type l -name "*net-netplan.plugin.bash" 2>/dev/null | head -1)
    [[ -n "${plugin_file}" && -f "${plugin_file}" ]] && source "${plugin_file}" # load plugin
fi
ln -s "../plugins/available/net-iptables.plugin.bash" "./enabled/250---net-iptables.plugin.bash" 2>/dev/null
plugin_file=$(find ./enabled -type l -name "*net-iptables.plugin.bash" 2>/dev/null | head -1)
[[ -n "${plugin_file}" && -f "${plugin_file}" ]] && source "${plugin_file}" # load plugin
predefined=("os-systemd" "net-ifupdown" "net-netplan" "net-iptables")
JB_VARS=($(printf "%s\n" "${JB_VARS[@]}" | sort -u))
# shellcheck disable=SC1102
loaded_vars=$(( set -o posix ; set )|grep -v "^JB_VARS")
IFS=$'\n' read -d "" -ra lvars <<< "${loaded_vars}" # split

# Initialize .config.last file
echo "# Complete rendered configuration with parent hierarchy" > .config.last
echo "# Generated at: $(date)" >> .config.last
echo "" >> .config.last

for((j=0;j<${#JB_VARS[@]};j++)){
    for((k=0;k<${#lvars[@]};k++)){
        if [[ ${lvars[k]} == *"${JB_VARS[j]}"* ]]; then
            group_txt=""
            if [[ (${JB_VARS[j]} == "RUN_NET"* || ${JB_VARS[j]} == "RUN_OS"*) && ${lvars[k]} == *"=1" ]]; then
                load_plugin=${JB_VARS[j]##RUN_}
                load_plugin=${load_plugin,,}
                load_plugin=${load_plugin//_/-}
                case "${predefined[@]}" in  *"${load_plugin}"*) continue ;; esac
                [[ $(find ./enabled|grep -c ${load_plugin}) -lt 1 ]] && \
                    ln -s "../plugins/available/${load_plugin}.plugin.bash" "./enabled/250---${load_plugin}.plugin.bash"

                plugin_file=$(find ./enabled -type l -name "*${load_plugin}.plugin.bash" 2>/dev/null | head -1)
                if [[ -n "${plugin_file}" && -f "${plugin_file}" ]]; then
                    source "${plugin_file}" # load plugin
                else
                    log_error "Plugin file not found for ${load_plugin}"
                    continue
                fi
                group_txt=$(typeset -f -- "${load_plugin}"|metafor group)
                deps_txt=$(typeset -f -- "${load_plugin}"|metafor deps)
                [[ ${group_txt// /} == "postnet" && ${#deps_txt[@]} -eq 0 ]] && postnet+=(${load_plugin})
                [[ ${group_txt// /} == "postnet" && ${#deps_txt[@]} -gt 0 ]] && postnetdeps+=(${load_plugin})
                [[ ${group_txt// /} == "prenet" && ${#deps_txt[@]} -eq 0 ]] && prenet+=(${load_plugin})
                [[ ${group_txt// /} == "prenet" && ${#deps_txt[@]} -gt 0 ]] && prenetdeps+=(${load_plugin})

                # skip if processed array has ${load_plugin}
                case "${processed[@]}" in  *"${load_plugin}"*) continue ;; esac

                # --check
                [[ ${CH_OPTION} = "enabled" ]] || [[ ${CH_OPTION} = "${load_plugin}" ]] && ${load_plugin} check && processed+=(${load_plugin})
                # --launch
                [[ ${RN_OPTION} = "enabled" ]] || [[ ${RN_OPTION} = "${load_plugin}" ]] && ${load_plugin} run && processed+=(${load_plugin})
                # --download
                [[ ${DN_OPTION} = "enabled" ]] || [[ ${DN_OPTION} = "${load_plugin}" ]] && ${load_plugin} download && processed+=(${load_plugin})
                # --install
                [[ ${IN_OPTION} = "enabled" ]] || [[ ${IN_OPTION} = "${load_plugin}" ]] && ${load_plugin} install && processed+=(${load_plugin})
            fi
            # Save to .config.last instead of logging
            echo "${lvars[k]} $group_txt" >> .config.last
            unset group_txt
            break
        fi
    }
}

# Log that config was saved to file
log_debug "Configuration saved to .config.last ($(wc -l < .config.last) lines)"

# Validate interface names against system interfaces
_validate_interfaces

[[ ${SYNC_AND_BREAK} == 1 ]] && exit 0
# exit on check, run, download, install
if [[ ${CH_OPTION} = "enabled" || ${RN_OPTION} = "enabled" || ${DN_OPTION} = "enabled" || ${IN_OPTION} = "enabled" || \
    $(echo "${CH_OPTION}"|grep -o "-"|wc -l) = 1 || $(echo "${RN_OPTION}"|grep -o "-"|wc -l) = 1 || \
    $(echo "${DN_OPTION}"|grep -o "-"|wc -l) = 1 || $(echo "${IN_OPTION}"|grep -o "-"|wc -l) = 1 ]]; then
    exit 0
fi

# append deps array to orig array
prenet+=("${prenetdeps[@]}")
postnet+=("${postnetdeps[@]}")

# add to rclocal
if [[ ${ADDTO_RCLOCAL} -gt 0 ]]; then
    [ ! -f "/etc/rc.local" ] && cp ./configs/rc.local /etc/rc.local
    if [[ $(grep -c "JB_INIT_SCRIPT" < "/etc/rc.local") -lt 1 ]]; then
        log_debug "Installing jangbi init script to rc.local(ADDTO_RCLOCAL)."
        add_cmd="bash ${JB_DEPLOY_PATH}/init.sh # JB_INIT_SCRIPT"
        cp /etc/rc.local /etc/rc.local_"$(date +%Y%m%d%H%M%S).bak"
        sed -i "s|^exit 0|${add_cmd}\nexit 0|" /etc/rc.local
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

    # Get the config variable name (e.g., net-sshd -> RUN_NET_SSHD)
    local plugin_name="${command}"
    local var_name="RUN_${plugin_name//-/_}"
    var_name="${var_name^^}"  # Convert to uppercase
    local config_status="${!var_name:-unset}"

    # Determine enabled/disabled status
    local enabled_status
    if [[ "${config_status}" == "1" ]]; then
        enabled_status="enabled"
    elif [[ "${config_status}" == "0" ]]; then
        enabled_status="disabled"
    else
        enabled_status="unset"
    fi

    # Convert status code to readable message
    local status_msg
    case ${running_status} in
        0)  status_msg="installed but not running" ;;
        1)  status_msg="running" ;;
        5)  status_msg="ready to install" ;;
        10) status_msg="variable not set" ;;
        15) status_msg="pkg file not downloaded" ;;
        20) status_msg="not enabled/skipped" ;;
        *)  status_msg="unknown status (${running_status})" ;;
    esac
    log_debug "${step} [config:${enabled_status}] ${status_msg} (${running_status})"

    case ${running_status} in # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
        5)
            run_ok_with_reason "${command} install" "${command}(${step}) Installing..." "Installing"
            log_debug "$!"
            run_ok_with_reason "${command} run" "${command}(${step}) Running..." "Running"
            log_debug "$!"
            ;; # package is not installed, install it
        0)
            run_ok_with_reason "${command} run" "${command}(${step}) Running..." "Running"
            log_debug "$!"
            ;; # package is not running, run it
        10)
            log_fatal "Something went wrong. Exiting."
            exit 1
            ;;
        15)
            run_ok_with_reason "${command} download" "${command}(${step}) Downloading..." "Downloading"
            local download_result=$?
            log_debug "$!"
            if [[ ${download_result} -ne 0 ]]; then
                log_error "${command}(${step}) Download failed. Skipping install and run."
            else
                run_ok_with_reason "${command} install" "${command}(${step}) Installing..." "Installing"
                log_debug "$!"
                run_ok_with_reason "${command} run" "${command}(${step}) Running..." "Running"
                log_debug "$!"
            fi
            ;; # package file does not exist, download and install it
        20)
            log_info "${command}(${step}) Skiped..."
            log_debug "$!"
            ;;
    esac
    BASH_IT_LOG_PREFIX="core: main: "
}
INTERNET_AVAIL=0

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
if [[ -z $(curl google.com 2>/dev/null|grep 301\ Moved) ]]; then
    log_error "not connected. proceed with offline install."
else
    # set date and add to crontab
    log_debug "Trying to sync time with DNS Server ${DNS_UPSTREAM}"
    _time_sync "${DNS_UPSTREAM}"
    INTERNET_AVAIL=1
fi

# allow forwarding when gateway
if [[ ${JB_ROLE} = "gateway" ]]; then
    log_debug "Enabling forwarding on kernel."
    echo "1" > /proc/sys/net/ipv4/ip_forward
else
    log_debug "Not gateway, disabling forwarding on kernel."
    echo "0" > /proc/sys/net/ipv4/ip_forward
fi
